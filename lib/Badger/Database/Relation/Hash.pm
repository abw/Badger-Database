#========================================================================
#
# Badger::Database::Relation::Hash
#
# DESCRIPTION
#   Subclass of Badger::Relation::Map which adds a value field, which
#   means we can provide a more convenient way to get/set attribute 
#   values (for example).
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
#========================================================================

package Badger::Database::Relation::Hash;

use strict;
use warnings;
use base 'Badger::Database::Relation::Map';

our $VERSION   = 0.02;
our $DEBUG     = 0 unless defined $DEBUG;
our $MESSAGES  = { 
    no_index => 'No index field defined',
};

sub init {
    my ($hash, $config) = @_;
    my $self = $hash->self();

    $self->{ id } = $config->{ id }
        || return $hash->error_msg('no_id');

    $self->{ table } = $config->{ table }
        || return $hash->error_msg('no_table');
        
    $self->{ fkey } = $config->{ fkey }
        || $self->{ table }->key();

    $self->{ index } = $config->{ index }
        || $self->error_msg('no_index');

    $self->{ value } = $config->{ value }
        || $self->error_msg( no_field => 'value' );

    $hash->fetch() if $config->{ fetch };
}

sub create {
    my $hash  = shift;
    my $self  = $hash->self();
    my $args  = @_ && ref $_[0] eq 'HASH' ? shift : { @_ };
    my $index = $self->{ index };
    if (keys %$args == 1) {
        # SUGAR: create( foo => 'bar') as short-hand for create( name => 'foo', value => 'bar' )
        $args = {
            $self->{ index } => (keys %$args)[0],
            $self->{ value } => (values %$args)[0],
        };
    }

    # add the foreign key value pointing back to our parent id
    $args->{ $self->{ fkey } } = $self->{ id };
    my $item = $self->{ table }->create($args);
    $hash->{ $item->$index } = $item;
    return $item
}

sub get {
    my ($hash, $key) = @_;
    return $hash->{ $key };
}

sub set {
    my ($hash, $key, $value) = @_;
    my $self = $hash->self();
    my $attr = $hash->{ $key };
    if ($attr) {
        $attr->update( $self->{ value } => $value );
        return $attr;
    }
    else {
        return $hash->create( $key, $value );
    }
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

