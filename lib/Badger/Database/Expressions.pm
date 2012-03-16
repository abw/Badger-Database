package Badger::Database::Expressions;

use lib '/home/abw/projects/badger/lib';
use Badger::Class
    version => 0.01,
    debug   => 0,
    base    => 'Badger::Modules';

our $ITEM = 'expression';
our $EXPRESSION_PATH = [
    'Badger::Database::Expression',
    'BadgerX::Database::Expression',
];

sub attach {
    shift->todo;
}

sub expression {
    my $self   = shift;
    my $name   = shift;
    my $module = $self->{ expression }->{ $name }
        || $self->module($name);
    
#    $self->debug("module for $name is $module");
    
    return $module->new( $self, $name, @_ );
}


1;