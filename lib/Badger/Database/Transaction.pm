package Badger::Database::Transaction;

our $AUTOLOAD;


sub new {
    my ($class, $that, $commit) = @_;
    my $dbh = $that->dbh;
    $dbh->begin_work;
    bless {
        that   => $that, 
        dbh    => $dbh,
        commit => $commit
    }, ref $class || $class;
}


sub model {
    shift->{ that }->model;
}


sub table {
    shift->model->table(@_);
}


sub commit {
    my $self = shift;
    $self->{ done } = 'commit';
    $self->{ dbh  }->commit;
}


sub rollback {
    my $self = shift;
    $self->{ error } = shift;
    $self->{ done  } = 'rollback';
    $self->{ dbh   }->rollback;
}


sub auto_commit {
    my $self = shift;
    $self->{ commit } = @_ ? shift : 1;
}


sub AUTOLOAD {
    my $self    = shift;
    my $that    = $self->{ that };
    my ($name)  = ($AUTOLOAD =~ /([^:]+)$/ );

#   return if $name eq 'DESTROY';
    
    my $result = eval {                 # try
        $that->$name(@_) 
    };
    
    if ($@) {                           # catch
        $self->rollback($@);            # rollback transation
        return $that->error($@);
    }
    
    $self->commit if $self->{ commit }; # commit transation

    return $result;
}


sub DESTROY {
    my $self = shift;
    $self->rollback unless $self->{ done };
}

1;
