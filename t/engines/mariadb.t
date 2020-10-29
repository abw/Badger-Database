#============================================================= -*-perl-*-
#
# t/engines/mysql.t
#
# Test the Badger::Database::Engine::Mariadb module.
#
# Written by Andy Wardley <abw@wardley.org>
#
# Copyright (C) 2008-2020 Andy Wardley.  All Rights Reserved.
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
#========================================================================

use strict;
use warnings;
use lib qw( ./lib ../../lib );
use Badger::Filesystem '$Bin Dir File';
use Badger::Test
    debug => 'Badger::Database::Engine
              Badger::Database::Engine::MariaDB',
    args  => \@ARGV;

use Badger::Database 'DB';
use Badger::Test::DBConfig;     # imports $ENGINE, $DATABASE, $USERNAME, etc...

BEGIN {
    eval "use DBD::MariaDB";
    skip_all("You don't have DBD::MariaDB installed") if $@;
    skip_all("You said you didn't want to run the extended tests") unless $DB_TESTS;
    skip_all("You're not using MariaDB for the extended tests") unless $ENGINE =~ /^mariadb$/i;
    plan(8);
}

my $engine;
my $table  = 'badger_test_users';
my $creds  = {
    database => $DATABASE,
    username => $USERNAME,
    password => $PASSWORD,
};

$engine = DB->engine( mariadb => $creds );
ok( $engine, 'got a mariadb engine' );

$engine = DB->engine( MariaDB => $creds );
ok( $engine, 'got a MariaDB engine' );

ok( $engine->query("DROP TABLE IF EXISTS $table"), 'dropped users table' );

$engine->query(<<EOF);
  CREATE TABLE $table (
      id    SERIAL,
      name  CHAR(64),
      email VARCHAR(128)
  )
EOF

my $query = $engine->prepare(
    "INSERT INTO $table (name,email) VALUES (?, ?)"
);
ok( $query, 'prepared insert query' );

ok( $engine->execute($query, 'Mr Badger', 'badger@badgerpower.com'),
    'added first user' );
is( $engine->insert_id($table,'id'), 1, "inserted id 1" );

ok( $engine->execute($query, 'Mr Stoat', 'stoat@badgerpower.com'),
    'added second user' );
is( $engine->insert_id($table,'id'), 2, "inserted id 2" );

