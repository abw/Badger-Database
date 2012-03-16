#========================================================================
#
# Badger::Test::Table
#
# DESCRIPTION
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
#========================================================================

package Badger::Test::Table;

use Badger::Class
    version => 0.01,
    debug   => 0,
    base    => 'Badger::Database::Table';

our $SCHEMA = { 
    table    => 'badger_test',
    id       => 'id',
    fields   => 'username password name',
    update   => 'name password',
    delete   => 1,
};

1;
