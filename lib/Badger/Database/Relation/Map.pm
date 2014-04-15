#========================================================================
#
# Badger::Database::Relation::Maps
#
# DESCRIPTION
#   Relation mapping a set of related database records via a hash array.
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
#========================================================================

package Badger::Database::Relation::Map;

use Badger::Class
    version  => 0.01,
    debug    => 0,
    base     => 'Badger::Database::Relation::Many',
    words    => 'HASH',
    messages => {
        no_index  => 'No index field specified',
    };

*create  = \&insert;
*refresh = \&fetch;
*append  = \&add;


sub new {
    my $class  = shift;
    my $config = @_ && ref $_[0] eq HASH ? shift : { @_ };
    my $self   = bless { }, $class;
    $self->init($config);
    return $self;
}


sub init {
    my ($self, $config) = @_;
    my $meta = $self->meta;

    $meta->{ table } = $config->{ table }
        || return $self->error_msg('no_table');

    $meta->{ index } = $config->{ index }
        || return $self->error_msg('no_index');

    $meta->{ id    } = $self->init_local_key($config);
    $meta->{ fkey  } = $self->init_remote_key($config);
    $meta->{ where } = $config->{ where };

    $self->fetch if $config->{ fetch };
}


sub fetch {
    my $self  = shift;
    my $meta  = $self->meta;
    my $index = $meta->{ index };

    $self->debug("Fetching hash relation [$meta->{ fkey } => $meta->{ id }]\n") if $DEBUG;

    my $attrs = $meta->{ table }->fetch_all({
        $meta->{ fkey  } => $meta->{ id },
        $meta->{ where } ? %{ $meta->{ where } } : (),
    });
    foreach my $attr (@$attrs) {
        $self->{ $attr->$index } = $attr;
    }
    return $self;
}


sub insert {
    my $self  = shift;
    my $meta  = $self->meta;
    my $args  = @_ && ref $_[0] eq HASH ? shift : { @_ };
    my $index = $meta->{ index };

    # add the foreign key value pointing back to our parent id
    $args->{ $meta->{ fkey } } = $meta->{ id };

    # add any 'where' constraints
    if (my $where = $meta->{ where }) {
        @$args{ keys %$where } = values %$where;
    }

    $self->debug("insert: ", $self->dump_data($args), "\n") if DEBUG;

    my $item = $meta->{ table }->create($args);
    $self->{ $item->$index } = $item;

    return $item
}


sub remove {
    my ($self, $key) = @_;
    my $item = delete $self->{ $key } || return;
    $item->update( $self->meta->{ fkey } => undef );
    return $item;
}


sub delete {
    my ($self, $key) = @_;
    my $item = delete $self->{ $key } || return ;
    return $item->delete();
}


sub delete_all {
    my $self = shift;
    foreach my $item (values %$self) {
        $item->delete;
    }
    %$self = ();
    return $self;
}


sub size {
    return scalar keys %{$_[0]};
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
