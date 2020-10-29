#============================================================= -*-perl-*-
#
# t/engine.t
#
# Test the Badger::Database::Engine module.
#
# Written by Andy Wardley
#
#========================================================================

use strict;
use warnings;
use lib qw( ./lib ../lib ../../lib );
use Badger::Test
    #tests => 6,
    debug => 'Badger::Database::Engine Badger::Config',
    args  => \@ARGV;

use Badger::Database::Engine;
use Badger::Test::DBConfig;     # imports $ENGINE, $DATABASE, $USERNAME, etc...
use constant Engine => 'Badger::Database::Engine';

BEGIN {
    eval "use DBD::mysql";
    skip_all("You don't have DBD::mysql installed") if $@;
    skip_all("You said you didn't want to run the extended tests") unless $DB_TESTS;
    skip_all("You're not using MySQL for the extended tests") unless $ENGINE =~ /^mysql$/i;
    plan(6);
}

my $engine = eval { Engine->new };
ok( ! $engine, 'failed to create default engine' );
is( Engine->reason, 'No database specified', 'got no database error' );

$engine = Engine->new(
    type => 'mysql',
    name => 'test',
    user => 'test',
    pass => 'test',
);
ok( $engine, 'connected engine' );
ok( $engine->reconnect, 'reconnected engine' );

is( $engine->type, 'mysql', 'got engine type' );
is( $engine->name, 'test', 'got engine name' );


__END__

#-----------------------------------------------------------------------
# create engine using named parameters
#-----------------------------------------------------------------------

$engine = Engine->new(
    type => 'mysql',
    name => 'example',
    user => 'tom',
    pass => 'secret',
    host => 'example.com'
);
ok( $engine, 'created engine with configuration params' );
is( $engine->type, 'mysql', 'got engine type' );
is( $engine->name, 'example', 'got engine name' );
is( $engine->user, 'tom', 'got engine user' );
is( $engine->pass, 'secret', 'got engine password' );
is( $engine->host, 'example.com', 'got engine host' );

__END__

#-----------------------------------------------------------------------
# create engine using aliases named parameters
#-----------------------------------------------------------------------

$engine = Engine->new(
    driver   => 'mysql',
    database => 'example',
    username => 'tom',
    password => 'secret',
);
ok( $engine, 'created engine with configuration param aliases' );
is( $engine->type, 'mysql', 'got engine type from alias' );
is( $engine->name, 'example', 'got engine name from alias' );
is( $engine->user, 'tom', 'got engine user from alias' );
is( $engine->pass, 'secret', 'got engine pass from alias' );


#-----------------------------------------------------------------------
# check we can access using alternate accessor names, too
#-----------------------------------------------------------------------

is( $engine->driver, 'mysql', 'got engine driver' );
is( $engine->database, 'example', 'got engine database' );
is( $engine->username, 'tom', 'got engine username' );
is( $engine->password, 'secret', 'got engine password' );
