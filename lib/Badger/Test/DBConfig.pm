package Badger::Test::DBConfig;

use Badger::Filesystem '$Bin Dir';
use Badger::Class
    debug    => 0,
    base     => 'Badger::Base',
    import   => 'CLASS',
    constant => {
        CONFIG_FILE => 'database.cfg',
        TEST_DIR    => 't',
    },
    exports  => {
        all  => '$ENGINE $DATABASE $USERNAME $PASSWORD $DB_TESTS',
    };

our ($ENGINE, $DATABASE, $USERNAME, $PASSWORD, $DB_TESTS);


BEGIN {
    # assumes that this is run from a test script in the t/ directory,
    # or a t/xxx directory underneath it.
    my $bin  = Dir($Bin);
    my ($dir, $cfg);

    if ($bin->name eq TEST_DIR) {
        $dir = $bin;
    }
    elsif (($bin = $bin->parent) && $bin->name eq TEST_DIR) {
        $dir = $bin;
    }
    else {
        die(
            "Can't locate the '", TEST_DIR, "' directory\n",
            "This module only works for test scripts run in\n",
            "the '", TEST_DIR, "' directory, or in an immediate\n",
            "sub-directory of it.\n"
        );
    }
    
    $cfg = $dir->file(CONFIG_FILE);

    die(
        "\n",
        "Can't find the '", CONFIG_FILE, "' configuration file in the '", TEST_DIR, "' directory.\n",
        "This file is created when you run `perl Makefile.PL`.  Go do that now.\n\n",
    ) unless $cfg->exists;
    
    CLASS->debug("requiring $cfg\n") if DEBUG;
    
    require $cfg;

    CLASS->debug(
        "Loaded configuration from ", $cfg->path, "\n",
        "    ENGINE: $ENGINE\n",
        "  DATABASE: $DATABASE\n",
        "  USERNAME: ", (defined $USERNAME ? $USERNAME : '<none>'), "\n",
        "  PASSWORD: ", (defined $PASSWORD ? $PASSWORD : '<none>'), "\n"
    ) if DEBUG;
}

1;
