#========================================================================
#
# Badger::Database::Base
#
# DESCRIPTION
#   Common base class for all L<Badger::Database> modules.
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
#========================================================================

package Badger::Database::Base;

use Badger::Debug ':dump';
use Badger::Class
    version  => 0.01,
    base     => 'Badger::Base',
    constant => {
        ENGINE  => 'Badger::Database::Engine',
        QUERY   => 'Badger::Database::Query',
        RECORD  => 'Badger::Database::Record',
    },
    messages => {
        dbi          => 'DBI %s failed: %s',
        no_id        => 'The %s table does not have an auto-generated id column',
        no_dbh       => 'Database is not connected',
        no_engine    => 'No engine specified for the %s table',
        no_table     => 'No table specified',
        no_query     => 'No query specified', 
        no_keys      => 'No keys are defined for the %s table',
        no_ident     => 'No identifying key(s) specified to %s for the %s table',
        no_fields    => 'No valid fields were specified to %s for %s table',
        no_param     => "No '%s' parameter specified to %s for the %s table",
        multi_keys   => 'Multiple keys are defined for the %s table',
        bad_args     => 'Invalid argument(s) specified to %s: %s',
        bad_query    => 'Invalid query name specified: %s', 
        bad_meta     => 'Invalid meta-query name specified: %s', 
        bad_table    => 'The %s table is not defined in the database model',
        bad_record   => 'Invalid record specification for %s table: %s',
        new_record   => 'Failed to create new %s record object: %s',
        bad_sql_frag => 'Invalid SQL fragment <%s> in query: %s',
        insert_id    => 'Insert id for %s.%s is not available (%s)',
        not_found    => 'Not found in %s table',
    };


sub debug_method {
    my ($self, $method, @args) = @_;
    $self->debug_up(
        2,
        $method, '(', 
        join(', ', map { $self->dump_data($_) } @args),
        ')'
    );
}


1;

=head1 NAME

Badger::Database::Base - base class for Badger::Database modules

=head1 SYNOPSIS

See L<Badger::Base>.

=head1 DESCRIPTION

This module is a base class for all other L<Badger::Database> modules.
It is implemented as a very thin subclass of L<Badger::Base>.  

The main thing it does is to define a number of custom message formats for
other L<Badger::Database> modules to use (see
L<$MESSAGES|Badger::Base/$MESSAGES> in L<Badger::Base> for further
information).  It also acts as a convenient place to define any methods
common to all L<Badger::Database> modules either now or at some point in
the future when the occasion may arise.

=head1 METHODS

=head2 debug_method()

This is an internal method used for debugging.

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 2005-2009 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<Badger::Base>

=cut

# Local Variables:
# mode: Perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
