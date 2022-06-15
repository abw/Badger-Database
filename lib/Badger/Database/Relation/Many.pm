#========================================================================
#
# Badger::Database::Relation::Many
#
# DESCRIPTION
#   Implements a one-to-many relation, storing the list of records as
#   an unordered set.
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
#========================================================================

package Badger::Database::Relation::Many;

use Badger::Class
    version  => 0.01,
    debug    => 0,
    base     => 'Badger::Database::Relation',
    words    => 'HASH',
    messages => {
        out_of_bounds => 'There is no item %s in the set',
        no_ident      => 'No id or (local_)key field specified',
    };


*as_list = \&list;
*create  = \&insert;
*refresh = \&fetch;


sub new {
    my $class  = shift;
    my $config = @_ && ref $_[0] eq HASH ? shift : { @_ };
    my $list   = bless [ ], $class;
    $list->init($config);
    return $list;
}


sub init {
    my ($self, $config) = @_;
    my $meta = $self->meta;

    $meta->{ table } = $config->{ table }
        || return $self->error_msg('no_table');

    $meta->{ id        } = $self->init_local_key($config);
    $meta->{ fkey      } = $self->init_remote_key($config);
    $meta->{ where     } = $config->{ where };
    $meta->{ order     } = $config->{ order } || $config->{ order_by };
    $meta->{ on_change } = $config->{ on_change };
    $self->fetch if $config->{ fetch };
}

sub init_local_key {
    my ($self, $config) = @_;
    return $config->{ id }
        || $config->{ key }
        || $config->{ lkey }
        || $config->{ local_key }
        || $self->error_msg('no_ident');
}

sub init_remote_key {
    my ($self, $config) = @_;
    return $config->{ fkey }
        || $config->{ rkey }
        || $config->{ remote_key }
        || $self->meta->{ table }->key;
}


sub fetch {
    my $self = shift;
    my $meta = $self->meta;
    my $conf = {
        $meta->{ fkey  } => $meta->{ id },
        $meta->{ where } ? %{ $meta->{ where } } : (),
        $meta->{ order } ? (order => $self->backquote_order($meta->{ order })) : ()
    };

    $self->debug("Fetching many relation from $meta->{ table }->{ table } [$meta->{ fkey } => $meta->{ id }]\n") if DEBUG;
    #$self->debug("fetch spec: ", $self->dump_data($conf)) if DEBUG;

    my $items = $meta->{ table }->fetch_all($conf);
    @$self = @$items;

    $self->debug("fetched ", scalar(@$items), " items") if DEBUG;

    return $self;
}


sub insert {
    my $self = shift;
    my $meta = $self->meta;
    my $args = @_ && ref $_[0] eq HASH ? shift : { @_ };

    $self->debug("Inserting new record in many relation [$meta->{ fkey } => $meta->{ id }]\n") if DEBUG;

    # add local id to arguments as a foreign key
    $args->{ $meta->{ fkey } } = $meta->{ id };

    # add any where => { ... } constraints to args
    if (my $where = $meta->{ where }) {
        @$args{ keys %$where } = values %$where;
    }

    # insert record and add to $self relation list
    my $item = $meta->{ table }->insert($args);
    push(@$self, $item);

    # fire any callback
    $meta->{ on_change }->($self)
        if $meta->{ on_change };

    return $item;
}


sub add {
    my $self = shift;
    my $node = shift;
    my $meta = $self->meta;

    $self->debug("Adding new record in many relation [$meta->{ fkey } => $meta->{ id }]\n") if DEBUG;

    # update new record to have foreign key pointing back to our id
    $node->update( $meta->{ fkey } => $meta->{ id } );
    push(@$self, $node);

    # fire any callback
    $meta->{ on_change }->($self)
        if $meta->{ on_change };

    return $self;
}


# I'm not sure how useful it is to extract/delete/remove items using
# the list offset of the child items, when this is supposed to be an
# unordered list...

sub extract {
    my $self = shift;
    my ($n, $node, @nodes);

    while (@_) {
        $n = shift;
        $n += @$self if $n < 0;     # negative indices count back from end

        return $self->meta->error_msg( out_of_bounds => $n )
            if ($n < 0 || $n >= @$self);

        push(@nodes, splice(@$self, $n, 1));
    }

    return wantarray
        ?  @nodes
        : \@nodes;
}


sub remove {
    my $self  = shift;
    my $meta  = $self->meta;

    $self->debug("removing from many relation: ", join(', ', @_)) if DEBUG;

    my @nodes = map {
        # TODO: optimise this into a single DB query
        $_->update( $meta->{ fkey } => undef )
    } $self->extract(@_);

    # fire any callback
    $meta->{ on_change }->($self)
        if $meta->{ on_change };

    return wantarray
        ?  @nodes
        : \@nodes;
}


sub delete {
    my $self = shift;
    my $meta = $self->meta;

    $self->debug("deleting from many relation: ", join(', ', @_)) if DEBUG;

    my @nodes = map {
        # TODO: optimise this into a single DB query
        $_->delete
    } $self->extract(@_);

    # fire any callback

    $meta->{ on_change }->($self)
        if $meta->{ on_change };

    return wantarray
        ?  @nodes
        : \@nodes;
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


sub first {
    $_[0][0];
}

sub last {
    $_[0][-1];
}

sub size {
    return scalar @{$_[0]};
}

sub list {
    return [ @{$_[0]} ];
}


1;
__END__
=head1 NAME

Badger::Database::Relation::Many - one-to-many database relation object

=head1 DESCRIPTION

This module implements a base class for a one-to-many database relation.

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 2007-2022 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<Badger::Database::Relation>, L<Badger::Database::Table>.

=cut

