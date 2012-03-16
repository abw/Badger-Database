# This is a quick hack to test out an idea for constructing complex database 
# queries as "nomadic" (not a monad, but similar) expressions.  e.g.
#
#    $db->from('users')
#       ->select('name, email')
#       ->where(id => 1234);
#
# The above expression generates a linked list of Badger::Database::Expression
# object to represent the query.  This is handled automagically by an 
# AUTOLOAD method working in concert with Badger::Expressions.

package Badger::Database::Expression;

use Badger::Debug ':dump';
use Badger::Class
    version  => 0.01,
    debug    => 0,
    base     => 'Badger::Base',
#   auto_can => 'auto_can',
    vars     => '$AUTOLOAD',
    constant => {
        FACTORY_SLOT => 0,
        NAME_SLOT    => 1,
        ARGS_SLOT    => 2,
        PARENT_SLOT  => 3,
    },
    messages => {
        no_factory      => 'No factory defined for constructing further expressions',
        class_autoload  => "Cannot AUTOLOAD class method %s called at %s line %s",
    };


sub new {
#   my ($class, $factory, $name, $args, $parent) = @_;
    my $class = shift;
    my $self  = bless [ @_ ], $class;
    return $self->init;
}

#sub TMP_HASH_init {
#    my ($self, $config) = @_;
#    %$self{ keys %$config } = values %$config;
#    return $self;
#}

sub init {
    $_[0];
}

sub factory {
    my $self = shift;
    return $self->[FACTORY_SLOT]
        || $self->error_msg('no_factory');
}

sub parent {
    $_[0]->[PARENT_SLOT];
}

sub provide {
    my ($self, $provider) = @_;
    my $method = 'provide_' . $self->[NAME_SLOT];
    return $provider->$method($self->[ARGS_SLOT]);
}


sub TMP_auto_can {
    my ($self, $name) = @_;
    $self->debug("auto_can($name)");

    # don't AUTOLOAD class methods
    #return $self->error_msg( class_autoload => $name, (caller())[1,2]) 
    #    unless ref $self;
    
    return $self->factory->expression($name, \@_, $self);
}

sub AUTOLOAD {
    my $self = shift;
    my ($name) = ($AUTOLOAD =~ /([^:]+)$/ );

    return if $name eq 'DESTROY';

    # don't AUTOLOAD class methods
    return $self->error_msg( class_autoload => $name, (caller())[1,2]) 
        unless ref $self;
    
    return $self->factory->expression($name, \@_, $self);
}

sub DUMP {
    my $self   = shift;
    my $parent = $self->[PARENT_SLOT];
    my $name   = $self->[NAME_SLOT];
    my $args   = $self->dump_data_inline($self->[ARGS_SLOT]);
    my $text   = $parent
        ? ($parent->DUMP . "\n  -> ")
        : '';
    return $text . "$name($args)";
}



1;