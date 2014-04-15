package Badger::Database::Engine::Postgres;

use Badger::Class
    version  => 0.01,
    debug    => 0,
    base     => 'Badger::Database::Engine',
    words    => 'no_dbh',
    constant => {
        DRIVER      => 'Pg',
        SERIAL_TYPE => 'SERIAL',
        SERIAL_REF  => 'INTEGER',
    },
    vars     => {
        # these are merged into $OPTIONS in Badger::Database::Engine
        OPTIONS => {
            ChopBlanks => 1,
            PrintWarn  => 0,
        }
    };



sub dsn {
    my $self = shift;
    return $self->{ dsn } ||= do {
        my ($name, $host, $port) = @$self{ qw( database host port ) };
        $name  = "dbname=$name";
        $name .= ";host=$host" if $host;
        $name .= ";port=$port" if $port;
        join(':', 'DBI', $self->{ driver }, $name);
    };
}


sub insert_id {
    my ($self, $table, $field) = @_;

    my $dbh = $self->{ dbh }
        || return $self->error_msg(no_dbh);

    # default sequence name is <table>_<field>_seq, e.g. users_id_seq
    return $dbh->last_insert_id(
        undef, undef, undef, undef,
        { sequence => join('_', $table, $field, 'seq') }
    ) || $self->error_msg( insert_id => $table, $field, $dbh->errstr );
}


1;

=head1 NAME

Badger::Database::Engine::Postgres - database engine for Postgres

=head1 SYNOPSIS

    use Badger::Database::Postgres;

    my $db = Badger::Database::Engine::Postgres->new(
        database => 'badger',
        username => 'nigel',
        password => 'topsecret',
    );

    # ...everything as per Badger::Database::Engine

=head1 DESCRIPTION

This module implements a subclass of the L<Badger::Database::Engine> module,
providing methods specific to the Postgres database.

=head1 METHODS

This module inherits all the method from the L<Badger::Database::Engine>
base class.  The following methods are redefined to implement behaviours
specific to Postgres.

=head2 dsn()

This methods generates the L<DBI> connection string (DSN: Data Source
Notation) in the required format for Postgres.

=head2 insert_id()

Custom method for Postgres to return the insert ID of the most recently
inserted record.

=head1 WARNING

This engine hasn't been tested properly since being integrated into
the C<Badger::Database> distribution.  It worked the last time I used
it in anger a few years back now, but it's been repackaged and refactored
a bit since then so there could be lurking problems.

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
