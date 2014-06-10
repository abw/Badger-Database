# TODO: remove/delete

package Badger::Database::Relation::List;

use Badger::Class
    version  => 0.01,
    debug    => 0,
    base     => 'Badger::Database::Relation::Many',
    words    => 'HASH',
    messages => {
        no_index  => 'No index field specified',
        not_found => 'List relation item not found: %s',
    };


*create  = \&insert;
*refresh = \&fetch;
*append  = \&add;


sub init {
    my ($self, $config) = @_;
    my $meta = $self->meta;

    $meta->{ index } = $config->{ index } || $config->{ order }
        || return $self->error_msg('no_index');

    return $self->SUPER::init($config);
}


sub fetch {
    my $self = shift;
    my $meta = $self->meta;

    $self->debug("Fetching list relation [$meta->{ fkey } => $meta->{ id }] index: $meta->{ index })\n") if DEBUG;

    my $items = $meta->{ table }->fetch_all({
        $meta->{ fkey } => $meta->{ id },
        order           => $meta->{ index },
        $meta->{ where } ? %{ $meta->{ where } } : (),
    });

    @$self = @$items;

    return $self;
}


sub insert {
    my $self  = shift;
    my $meta  = $self->meta;
    my $args  = @_ && ref $_[0] eq HASH ? shift : { @_ };
    my $index = $meta->{ index };
    my ($offset, $item);

    # add the foreign key value pointing back to our parent id
    $args->{ $meta->{ fkey } } = $meta->{ id };

    # add any where => { ... } constraints to args
    if (my $where = $meta->{ where }) {
        @$args{ keys %$where } = values %$where;
    }

    if (defined ($offset = $args->{ $index })) {
        # handle negative offset
        $offset += @$self if $offset < 0;
        $offset = 0 if $offset < 0;
        if ($offset < @$self) {
            # renumber any items coming after it
            $args->{ $index } = $offset;
            $self->renumber(+1, $offset);
            $item = $meta->{ table }->insert($args);
            CORE::splice(@$self, $offset, 0, $item);

            # fire any callback
            $meta->{ on_change }->($self)
                if $meta->{ on_change };

            return $item;
        }
    }
    # otherwise we add it at the end of the list
    $args->{ $index } = @$self;

    $self->debug("inserting ", $meta->{ table }->table, " list item: ", $self->dump_data($args)) if DEBUG;
    $item = $meta->{ table }->insert($args);
    CORE::push(@$self, $item);

    # fire any callback
    $meta->{ on_change }->($self)
        if $meta->{ on_change };

    return $item;
}


sub add {
    my $self = shift;
    my $meta = $self->meta;
    my $args = {
        $meta->{ fkey } => $meta->{ id },
    };

    while (@_) {
        my $node = shift;
        $args->{ $meta->{ index } } = @$self;
        $node->update($args);
        push(@$self, $node);
    }

    # fire any callback
    $meta->{ on_change }->($self)
        if $meta->{ on_change };

    return $self;
}


sub remove {
    my ($self, $index) = @_;
    my @items = $self->splice($index, 1);
    return $items[0]
        || $self->error_msg( not_found => $index );
}


sub delete {
    my ($self, $index) = @_;
    my @items = map { $_->delete() } $self->splice($index, 1);
    return $items[0]
        || $self->error_msg( not_found => $index );
}


sub delete_all {
    my $self = shift;
    my $meta = $self->meta;

    foreach my $item (@$self) {
        $item->delete;
    }
    @$self = ();

    # fire any callback
    $meta->{ on_change }->($self)
        if $meta->{ on_change };

    return $self;
}


sub splice {
    my $self   = shift;
    my $meta   = $self->meta;
    my $start  = shift || 0;
    my $length = shift;
    my (@orphans, $orphan, $marker);

    # negative start counts back from the end
    $start = @$self + $start if $start < 0;

    # unspecified length removes everything to the end of the list
    $length = @$self unless defined $length;

    # length can't go past end of list
    $length = @$self - $start if $start + $length > @$self;

    $self->debug('splice([', join(', ', @$self), "], $start, $length", @_ ? join(', ', '', @_) : '', ")\n")
        if DEBUG;

    if ($start >= @$self) {
        # start point is past the end of the list... so that's easy
        $self->append(@_);
    }
    else {
        # otherwise the start point is somewhere within the list (i.e. not at the end) so
        # we're going to need to renumber any items in the list that come after our
        # delete/insert operation(s).  We increase their offset by $add to make room
        # for any items we're going to add, and decrease it by $length to cover up
        # the holes left by any items we're removing
        my $add = scalar(@_);
        $self->renumber($add - $length, $start + $length)
            if $start + $length < @$self;

        if ($length) {
            # we've been asked to delete $length items from $start onwards...
            $self->debug("remove item", $length == 1 ? " $start" : "s $start to ", $start + $length - 1, "\n")
                if DEBUG;

            @orphans = map {
                # update item to remove links to this parent
                $_->update( $meta->{ fkey } => undef, $meta->{ index } => undef )
            } CORE::splice(@$self, $start, $length);
        }

        if ($add) {
            # ...and add $add items from the same start position
            my $count = $start;
            $self->debug("adding $add items starting at $count\n") if $DEBUG;

            CORE::splice(@$self, $start, 0, map {
                $self->debug("adding [$_] at $count\n") if $DEBUG;
                $_->update( $meta->{ fkey } => $meta->{ id }, $meta->{ index } => $count++ )
            } @_);
        }
    }

    # fire any callback
    $meta->{ on_change }->($self)
        if $meta->{ on_change };

    $self->debug("    --> [", join(', ', @$self), "]\n") if $DEBUG;

    return wantarray ? @orphans : \@orphans;
}


sub renumber {
    my $self   = shift;
    my $delta  = shift || return;
    my $start  = shift || 0;
    my $meta   = $self->meta;
    my $index  = $meta->{ index };
    my $table  = $meta->{ table };
    my @where  = ($meta->{ fkey });
    my @values = ($delta, $start, $meta->{ id });
    my ($where, $qname, $query);

    # add any where => { ... } constraints to args
    if ($where = $meta->{ where }) {
        push(@where, keys %$where);
        push(@values, values %$where);
    }

    $where = join(' AND ', map { $_ . '=?' } @where);
    $qname = join('_', 'list_renumber', $index, @where);
    $query = "UPDATE <table> SET $index=$index+? WHERE $index>=? AND $where";

    # TODO: generate this from a meta-query
    # This is broken
    #$table->queries->{ $qname } ||= $query;

    $self->debug("renumber: $qname => $query [", join(', ', @values), ']') if DEBUG;

    $table->execute( $query => @values );

    foreach my $item (@$self[$start..$#$self]) {
        # I am a dirty slut - I hack data straight out of the object
        $item->{ $index } += $delta;
    }
}


# we can now implement the usual push(), pop(), unshift() and shift() list manipulation
# methods in terms of append() and splice()

*push = \&append;

sub pop {
    my $self = shift;
    my $size = shift || 1;
    my $kids = $self->splice(-$size);
    return $size == 1 ? @$kids : wantarray ? @$kids : $kids;
}

sub unshift {
    my $self = shift;
    $self->splice(0, 0, @_);
    return $self;    # be consistent with push()/append()
}

sub shift {
    my $self = CORE::shift;
    my $size = CORE::shift || 1;
    my $kids = $self->splice(0, $size);
    return $size == 1 ? @$kids : wantarray ? @$kids : $kids;
}




1;
__END__

# Local Variables:
# mode: Perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
