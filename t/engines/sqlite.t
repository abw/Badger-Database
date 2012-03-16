#============================================================= -*-perl-*-
#
# t/engines/sqlite.t
#
# Test the Badger::Database::Engine::SQLite module.
#
# Written by Andy Wardley <abw@wardley.org>
#
# Copyright (C) 2008 Andy Wardley.  All Rights Reserved.
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
              Badger::Database::Engine::SQLite',
    args  => \@ARGV;
use Badger::Database 'DB';

BEGIN {
    eval "use DBD::SQLite";
    skip_all("You don't have DBD::SQLite installed") if $@;
    plan(7);
}

my $file   = Dir($Bin)->up(1)->dir('tmp')->file('sqlite.test.db')->path;
my $engine = DB->engine( sqlite => $file );

ok( $engine, 'got an engine' );
ok( $engine->query('DROP TABLE IF EXISTS users'), 'dropped users table' );

$engine->query(<<EOF);
  CREATE TABLE users (
      id    INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      name  CHAR(64),
      email VARCHAR(128)
  )
EOF

my $query = $engine->prepare(
    "INSERT INTO users (name,email) VALUES (?, ?)"
);
ok( $query, 'prepared insert query' );

ok( $engine->execute($query, 'Mr Badger', 'badger@badgerpower.com'),
    'added first user' );
is( $engine->insert_id, 1, "inserted id 1" );

ok( $engine->execute($query, 'Mr Stoat', 'stoat@badgerpower.com'),
    'added second user' );
is( $engine->insert_id, 2, "inserted id 2" );

