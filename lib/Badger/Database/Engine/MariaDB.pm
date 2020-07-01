package Badger::Database::Engine::MariaDB;

use Badger::Class
    version  => 0.01,
    debug    => 0,
    base     => 'Badger::Database::Engine',
    constant => {
        DRIVER => 'MariaDB',
    };

our $OPTIONS = {
};

sub dsn {
    my $self = shift;

    return $self->{ dsn } ||= do {
        my ($name, $host, $port) = @$self{ qw( database host port ) };
        $name = "database=$name"    if ($port || $host);
        $name = "port=$port;$name"  if $port;
        $name = "host=$host;$name"  if $host;
        join(':', 'DBI', $self->{ driver }, $name);
    };
}

1;


=head1 NAME

Badger::Database::Engine::MariaDB - database engine for MariaDB

=head1 DESCRIPTION

This module implements a subclass of the L<Badger::Database::Engine> module,
providing methods specific to the MariaDB database.

=head1 CONFIGURATION OPTIONS

The following configuration option is available in addition to those
inherited from the L<Badger::Database::Engine> base class.

=head2 reconnect

The option indicates that the engine should attempt to reconnect to the
MySQL database in the case that the connection is dropped (the infamous
"MySQL server has gone away" problem).  It is set to C<1> by default.
You can explicitly set it to C<0> if you don't want the engine to reconnect
automatically for some reason.

=head1 METHODS

This module inherits all the method from the L<Badger::Database::Engine>
base class.  The following methods are redefined to implement behaviours
specific to MySQL.

=head2 dsn()

This methods generates the L<DBI> connection string (DSN: Data Source
Notation) in the required format for MySQL.

=head2 insert_id()

Custom method for MariaDB to return the insert ID of the most recently
inserted record.

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>.

=head1 COPYRIGHT

Copyright (C) 2005-2020 Andy Wardley.  All Rights Reserved.

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
