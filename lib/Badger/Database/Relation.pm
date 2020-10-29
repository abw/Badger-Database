#========================================================================
#
# Badger::Database::Relation
#
# DESCRIPTION
#   Base class object for representing relations between records in
#   database tables.
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
#========================================================================

package Badger::Database::Relation;

use Badger::Class
    version  => 0.01,
    debug    => 0,
    base     => 'Badger::Database::Base',
    constant => {
        METADATA => 'Badger::Database::Relation::Metadata',
    },
    messages => {
    };

our $INSTANCE = { };     # inside-out store for object instance data

sub meta {
    # Create a new $METADATA object to store the metadata (table name, key, etc)
    # for the relation and store it inside-out in $INSTANCE, using the object ref
    # id as the key.  This means we don't have to pollute our hashes with metadata
    # and can also use list-based objects
    $INSTANCE->{"$_[0]"} ||= METADATA->new;
}

sub unmeta {
    delete $INSTANCE->{"$_[0]"};
}

sub DESTROY {
    $_[0]->unmeta();
}

sub table {
    return $_[0]->meta->{ table };
}

sub id {
    return $_[0]->meta->{ id };
}

sub fkey {
    return $_[0]->meta->{ fkey };
}


#-----------------------------------------------------------------------
# stub object for stored metadata that we can use for error reporting,
# debugging, etc.
#-----------------------------------------------------------------------

package Badger::Database::Relation::Metadata;

use Badger::Class
    version => 0.01,
    debug   => 0,
    base    => 'Badger::Database::Relation',
    words   => 'HASH';

sub new {
    my $class = shift;
    my $args  = @_ && ref $_[0] eq HASH ? shift : { @_ };
    bless { %$args }, $class;
}


1;

=head1 NAME

Badger::Database::Relation - base class database relation object

=head1 SYNOPSIS

TODO

=head1 DESCRIPTION

TODO

=head1 METHODS

TODO

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 2007-2009 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<Badger::Database>, L<Badger::Database::Table>.

=cut

# Local Variables:
# mode: Perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:

