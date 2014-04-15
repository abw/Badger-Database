package Badger::Database::Engine::SQLite;

use Badger::Class
    version  => 0.01,
    debug    => 0,
    base     => 'Badger::Database::Engine',
    words    => 'no_dbh',
    constant => {
        DRIVER      => 'SQLite',
        SERIAL_TYPE => 'INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT',
        SERIAL_REF  => 'INTEGER',
    };


sub dsn {
    my $self = shift;
    return $self->{ dsn } ||= do {
        my $name = 'dbname=' . $self->{ database };
        join(':', 'DBI', $self->{ driver }, $name);
    };
}


sub insert_id {
    my ($self, $table, $field) = @_;

    my $dbh = $self->{ dbh }
        || return $self->error_msg(no_dbh);

    # default sequence name is <table>_<field>_seq, e.g. users_id_seq
    return $dbh->func('last_insert_rowid')
        || $self->error_msg( insert_id => $table, $field, $dbh->errstr );
}


1;

=head1 NAME

Badger::Database::Engine::SQLite - database engine for SQLite

=head1 SYNOPSIS

    use Badger::Database::SQLite;

    my $db = Badger::Database::Engine::SQLite->new(
        database => '/path/to/database.db',
    );

    # ...everything as per Badger::Database::Engine

=head1 DESCRIPTION

This module implements a subclass of the L<Badger::Database::Engine> module,
providing methods specific to the SQLite database.

=head1 METHODS

This module inherits all the method from the L<Badger::Database::Engine>
base class.  The following methods are redefined to implement behaviours
specific to SQLite.

=head2 dsn()

This methods generates the L<DBI> connection string (DSN: Data Source
Notation) in the required format for SQLite.

=head2 insert_id()

Custom method for SQLite to return the insert ID of the most recently
inserted record.

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>.

=head1 COPYRIGHT

Copyright (C) 2005-2009 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<Badger::Database>,
L<Badger::Database::Engine>,
L<Badger::Database::Engines>.

=cut

# Local Variables:
# mode: Perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
