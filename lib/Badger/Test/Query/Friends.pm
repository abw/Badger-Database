package Badger::Test::Query::Friends;

use Badger::Class
    version => 0.01,
    debug   => 0,
    base    => 'Badger::Database::Query';

our $SQL = 'SELECT * FROM friends WHERE friend_id=?';

1;


