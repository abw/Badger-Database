#========================================================================
#
# Makefile.PL
#
# DESCRIPTION
#   Configuration script for Badger::Database.  Run with -h for help.
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
#========================================================================

use ExtUtils::MakeMaker;
use Badger::Filesystem '$Bin Dir';
use Badger::Constants 'DELIMITER';
use constant {
    TEST_DIR    => 't',
    TMP_DIR     => 'tmp',
    SQLITE      => 'SQLite',
    SQLITE_DB   => 'sqlite.test.db',
    CONFIG_FILE => 'database.cfg',
};

our @ENGINES   = qw( mysql SQLite Pg );
our @INSULTS   = (
    # Installing software can be such a boring process, but not as boring
    # as writing installation software.  Insulting users makes it more fun.
    "You entered an invalid driver name.  Please try again.",
    "You muppet!  That's not a valid DBD driver name.  Try again.",
    "Don't be silly.  That's not a valid choice.  Keep trying.",
    "You're not very good at this are you?  Have another go.",
    "Look, I'm a dumb computer.  If you can't get it right then I can't help you.",
    "I can go on all night.  I'm made of silicon.  I don't get bored.",
);

make_data_subs();

eval "use DBI";
die no_dbi()   if $@;                                   # must have DBI
die help()     if grep /--?h(elp)?/, @ARGV;             # -h / --help 
my $picky       = grep /--?c(onfig)?/, @ARGV;           # -c / --config
my $dir         = Dir($Bin);                            # where are we?
my $tmp_dir     = $dir->dir(TMP_DIR)->must_exist(1);    # create tmp dir
my $test_dir    = $dir->dir(TEST_DIR)->must_exist;      # must have test dir
my $sqlite_file = $tmp_dir->file(SQLITE_DB);            # file for SQLite sb
my $config_file = $test_dir->file(CONFIG_FILE);         # file for DB config
my $db_config   = db_config();                          # grok DB config from user
my $makefile    = {
    NAME         => 'Badger-Database',
    VERSION_FROM => 'lib/Badger/Database.pm',
    PMLIBDIRS    => [ 'lib' ], 
    PREREQ_PM    => {
        Badger   => 0.03,
        DBI      => 1.604,
    },
    dist         => {
        COMPRESS => 'gzip',
        SUFFIX   => 'gz',
    },
    test         => {
        TESTS    => 't/*.t t/*/*.t',
    },
};

if ($ExtUtils::MakeMaker::VERSION >= 5.43) {
    $makefile->{ AUTHOR   } = 'Andy Wardley <abw@wardley.org>';
    $makefile->{ ABSTRACT } = 'Database programming toolkit';
}

if ($ExtUtils::MakeMaker::VERSION >= 6.3002) {
    $makefile->{ LICENSE  } = 'perl';
}


WriteMakefile(%$makefile);
write_db_config($config_file, $db_config);


#-----------------------------------------------------------------------
# generate subroutines from templates in DATA section (after __END__)
#-----------------------------------------------------------------------

sub make_data_subs {
    my @data = <DATA>;
    my $subs = { };
    my $args = { };
    my $sub;
    
    while (@data) {
        my $line = shift @data;
        chomp $line;
        if ($line =~ /^__([^\n]+?)__$/) {
            my $name = $1;
            my @args;
            if ($name =~ s/\((.*?)\)//) {
                @args = split(DELIMITER, $1);
            }
            $args->{ $name } = \@args;
            $sub = $subs->{ $name } = [];
        }
        elsif ($sub) {
            push(@$sub, $line);
        }
        elsif ($line =~ /^\s*$/) {
            # ignore leading whitespace
            next;
        }
        else {
            die "Found text in DATA section outside sub definition: $line\n";
        }
    }
    
    while (my ($name, $lines) = each %$subs) {
        no strict 'refs';
        my $text = join("\n", @$lines) . "\n";
        my $args = $args->{ $name };
        *{$name} = sub {
            foreach my $arg (@$args) {
                my $value = shift;
                $text =~ s/\$$arg/$value/g;
            }
            return $text;
        };
    }
}


#-----------------------------------------------------------------------
# see what drivers/engines we've got to play with
#-----------------------------------------------------------------------

sub db_config {
    my $engines = {
        map { $_ => $_ }
        @ENGINES,
    };
    my $drivers = {
        map  { $_ => $_ }
        grep { $engines->{ $_ } }
        DBI->available_drivers
    };
    my $supported  = join(', ', sort keys %$drivers);
    my $ndrivers   = scalar keys %$drivers;
    my $sqlite_cfg = {
        db_tests => 1,
        engine   => SQLITE,
        database => $sqlite_file,
    };
    my $config;
    
    unless (%$drivers) {
        die got_none($supported);
    }

    if ($drivers->{ SQLite } && ($ndrivers == 1 || ! $picky)) {
        $config = $sqlite_cfg;
        print got_sqlite();
        print got_others() if $ndrivers > 1;
    }
    else {
        if ($drivers->{ SQLite }) {
            print got_sqlite_and_others();
        }
        else {
            print no_sqlite();
        }

        my $db_tests = prompt(
            "Do you want to run the extended tests?",
            'n'
        );
        $db_tests = ($db_tests =~ /y/i);
        
        if ($db_tests) {
            my ($driver, $database, $username, $password);
        
            print "\n", select_driver($supported);

            my $n = 0;
            while (! $driver) {
                $driver = prompt("Enter driver name:");
                unless ($drivers->{ $driver }) {
                    print("\n    ", $INSULTS[$n++ % @INSULTS], "\n\n    Valid drivers are: $supported\n\n");
                    $driver = undef;
                }
            }

            if ($driver eq SQLITE) {
                $config = $sqlite_cfg;
            }
            else {
                print "\n", warning(), connection(), "\n";

                while (! $database) {
                    $database = prompt("Enter database name:");
                }
        
                $config = {
                    db_tests => 1,
                    engine   => $driver,
                    database => $database,
                    username => prompt("Enter username (if required):"),
                    password => prompt("Enter password (if required):"),
                };
            }
        }
        else {
            $config = {
                db_tests => 0
            };
        }
    }
    
    return $config;
}


#-----------------------------------------------------------------------
# write database configuration to a file for test scripts to use
#-----------------------------------------------------------------------

sub write_db_config {
    my ($file, $config) = @_;
    my $text = join(
        "\n",
        "# WARNING: this file is generated when you run `perl Makefile.PL`",
        map { '$' . uc($_) . " = '" . $config->{ $_ } . "';" }
        keys %$config
    );
    $file->write($text, "\n\n1;\n");
}
    


__END__

__help__
Usage:
    $ perl Makefile.PL [options]

Options:
    -c / --config       Configure test options
    -h / --help         This help

__no_dbi__
FAIL!
    You don't appear to have the DBI module installed.
    You must install DBI first and one or more DBD driver
    modules.  See http://search.cpan.org/search?query=DBI

__got_none(supported)__
FAIL!
    Oh Crikey!  You don't appear to have any of the supported database
    drivers installed.  Right now, we have engines for the following 
    database drivers:
    
        $supported
    
    The Badger::Engine::* modules are very thin wrappers around the 
    respective DBI and DBD modules.  If your favourite database isn't
    supported then perhaps you could create a new engine module for it,
    or adapt an existing one to fit? 
    
    Sorry to get your hopes up and then dash them cruelly against the 
    rocks of unsupported software.  Rest assured that we won't sleep 
    well tonight, knowing that we've let you down so badly.

__got_sqlite__
NICE ONE!
    You've got SQLite installed.  That's good because it means we don't 
    have to pester you for the name of an existing database, username,
    password, and so on.  We'll create a local SQLite database in the 
    'tmp' sub-directory and use that for most of the live database tests.

__got_others__
    If you want to test Badger::Database against a different database 
    then re-run this script with the --config option, like this:
    
        $ perl Makefile.PL --config

__got_sqlite_and_others__
WAY TO GO!
    You've got SQLite installed.  That's the easiest option for running 
    the tests as it means we don't have to pester you for the name of an
    existing database, username, password, and so on.  We can create a 
    local SQLite database in the 'tmp' sub-directory and use that for most
    of the live database tests.
    
    You've also got other suitable database drivers installed.  If you 
    want to test Badger::Database against a database other than SQLite
    then enter the details below.

__no_sqlite__
SHAME!
    You don't appear to have SQLite installed.  That's a shame because it 
    means we now have to pester you for the name of an existing database, 
    username, password, and so on if you want to run the tests against a
    real database.  

__warning__
IMPORTANT!  LISTEN UP!
    You must provide the name of a database that already exists and is 
    suitable for destructive testing.  You must provide a username and 
    password to connect to the database (if required) with sufficient 
    permission to create and drop tables, and to insert, select, update 
    and delete records.
    
    For obvious reasons you SHOULD NOT provide the name of a database
    containing any data that you want to keep!  If necessary, go and 
    create a new test database now (e.g. `mysqladmin create test`).

__select_driver(supported)__
    Please enter the driver name for the test database.
    The DBD drivers installed on your system are

        $supported

__connection__
    Now enter the database name and the username and password that we
    should connect with (if required).
