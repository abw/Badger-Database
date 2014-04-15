package Badger::Database::Expressions;

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

    return $module->new( $self, $name, @_ );
}


1;
