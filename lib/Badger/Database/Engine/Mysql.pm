package Badger::Database::Engine::Mysql;

use Badger::Class
    version  => 0.01,
    debug    => 0,
    base     => 'Badger::Database::Engine',
    words    => 'no_dbh timeouts gone_no_sql no_query',
    config   => 'reconnect=1',
    constant => {
        DRIVER            => 'mysql',
        MYSQL_SERVER_GONE => 2006,  # MySQL server has gone away
        MYSQL_SERVER_LOST => 2013,  # No error, but missing/incomplete answer
        GET_WAIT_TIMEOUT  => 'SELECT @@global.wait_timeout AS gtime, @@session.wait_timeout AS stime',
        UNDEF             => '<undef>',
        SERIAL_TYPE       => 'SERIAL',
        SERIAL_REF        => 'BIGINT UNSIGNED',
    },
    messages => {
        timeouts    => 'GLOBAL wait_timeout = %s   SESSION wait_timeout = %s',
        gone_no_sql => "MySQL server went away and we don't have the source to reconstruct the query",
    };

our $OPTIONS = {
    mysql_auto_reconnect => 1,
    mysql_enable_utf8    => 1,
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


sub connect {
    my $self = shift;
    $self->SUPER::connect || return;

    $self->debug("process $$ connecting to MySQL") if DEBUG;

    # check the wait_timeout parameter on the server (used to debug MySQL server
    # going away)
    if (DEBUG) {
        my $row = $self->query( GET_WAIT_TIMEOUT )->fetchrow_hashref;
        $self->debug_msg( timeouts => $row->{ gtime }, $row->{ stime } );
    }

    #-----------------------------------------------------------------------------
    # NOTE: I believe this is the cause of the MySQL reconnect problem.
    # I disabled the mysql auto-reconnect feature and then coded my own
    # fallback out of the loop, by having Badger::Database::Query call
    # the engine execute() method instead of query()
    #
    # usual behaviour is to reconnect automatically, but we might want to
    # disable it (e.g. for testing/debugging)
    #
    #    $self->{ dbh }->{ mysql_auto_reconnect } = 0
    #        unless $self->{ reconnect };
    #
    # turn this on once I'm convinced that I can reproduce and squash the bug
    # UPDATE: doesn't seem to help. Still kill processes
    #
    #    $self->{ dbh }->{ mysql_auto_reconnect } = 1;
    #-----------------------------------------------------------------------------

    return $self;
}

sub execute_query {
    my $self  = shift;
    my $query = shift          || return $self->error_msg(no_query);
    my $dbh   = $self->{ dbh } || $self->connect;
    my $sth   = $query->sth;

    $self->debug(
        "query: ", $query->sql, "\n",
        " args: ", join(', ', map { defined $_? $_ : UNDEF } @_), "\n",
        "  sth: $sth\n"
    ) if DEBUG;

     # work around MySQL server going away when using TCP/IP socket
    unless ($self->try( execute => $sth, @_ )) {
        my $error = $sth->err;
#        local $DEBUG = 1;

        $self->debug("DBI execute failed: $error\n") if $DEBUG;

        # The MySQL server connection went away
        if (($error == MYSQL_SERVER_GONE) || ($error == MYSQL_SERVER_LOST)) {
            $self->debug("MySQL server went away - reconnecting\n") if $DEBUG;
            $self->reconnect();
            $self->debug("Re-preparing query\n") if $DEBUG;
            $sth = $query->prepare;
            $self->debug("Re-submitting query\n") if $DEBUG;
            $self->execute($sth, @_)
                || return $self->error_msg( dbi => execute => $sth->errstr );
        }
        else {
            $self->debug("DBI execute failed") if $DEBUG;
            return $self->error_msg( dbi => execute => $sth->errstr, $query->sql );
        }
    }

    return $sth;
}


sub insert_id {
    my ($self, $table, $field, $sth) = @_;

    return $sth->{ mysql_insertid }
        if $sth && $sth->{ mysql_insertid };

    my $dbh = $self->{ dbh }
        || return $self->error_msg(no_dbh);

    return $dbh->{ mysql_insertid }
        || $self->error_msg( insert_id => $table, $field, $dbh->errstr );
}


1;


=head1 NAME

Badger::Database::Engine::Mysql - database engine for MySQL

=head1 SYNOPSIS

    use Badger::Database::Mysql;

    my $db = Badger::Database::Engine::Mysql->new(
        database => 'badger',
        username => 'nigel',
        password => 'topsecret',
    );

    # ...everything as per Badger::Database::Engine

=head1 DESCRIPTION

This module implements a subclass of the L<Badger::Database::Engine> module,
providing methods specific to the MySQL database.

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

=head2 connect()

This method connects the engine to the database.  It adds some extra
functionality to handle reconnection to the MySQL server if necessary.

=head2 dsn()

This methods generates the L<DBI> connection string (DSN: Data Source
Notation) in the required format for MySQL.

=head2 query()

This method overrides the default method in the base class.  It adds
additional checking for the case where the MySQL server can "go away"
after a period of inactivity across a TCP/IP connection.  If the query
fails to execute due to the "MySQL server has gone away" problem, then
the method will automatically reconnect the engine to the server and
re-submit the query.

=head2 insert_id()

Custom method for MySQL to return the insert ID of the most recently
inserted record.

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>.

=head1 COPYRIGHT

Copyright (C) 2005-2014 Andy Wardley.  All Rights Reserved.

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
