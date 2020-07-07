package Badger::Database::Engine::MariaDB;

use Badger::Class
    version  => 0.01,
    debug    => 0,
    base     => 'Badger::Database::Engine',
    constant => {
        DRIVER => 'MariaDB',
    };

sub dsn {
    my $self = shift;

    return $self->{ dsn } ||= do {
        my ($name, $host, $port) = @$self{ qw( database host port ) };
        $name = "database=$name"    if ($port || $host);
        $name = "port=$port;$name"  if $port && $host ne 'localhost';
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

=head1 METHODS

This module inherits all the method from the L<Badger::Database::Engine>
base class.  The following methods are redefined to implement behaviours
specific to MySQL.

=head2 dsn()

This methods generates the L<DBI> connection string (DSN: Data Source
Notation) in the required format for MySQL.

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
