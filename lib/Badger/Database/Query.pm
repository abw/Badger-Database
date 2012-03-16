#========================================================================
#
# Badger::Database::Query
#
# DESCRIPTION
#   Object class representing database queries.
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
#========================================================================

package Badger::Database::Query;

use Badger::Class
    version => 0.01,
    debug   => 0,
    base    => 'Badger::Database::Base',
    config  => 'engine! queries sql|class:SQL sth',
    words   => 'not_found';


sub init {
    my ($self, $config) = @_;
    $self->configure($config);
    return $self;
}


sub sth {
    my $self = shift;
    return $self->{ sth } 
       ||= $self->{ engine }->prepare( $self->sql );
}


sub sql {
    my $self = shift;
    return $self->{ sql } 
       ||= $self->prepare_sql;
}


sub prepare_sql {
    # hook for future expansion where SQL is generated on demand
    shift->todo;
}


sub prepare {
    my $self = shift;
    $self->debug('Preparing query: ', $self->sql) if DEBUG;
    return ($self->{ sth } = $self->{ engine }->prepare( $self->sql, @_ ));
}


sub execute {
    my $self = shift;
    $self->debug("Executing query via engine: $self->{ engine } : \n", $self->sql) if DEBUG;

# This was where the bug was - we bypass the reconnection code in query()
#    $self->{ engine }->execute( $self->sth, @_ );
    $self->debug("execute args: [", join(', ', map { defined $_ ? $_ : '<undef>' } @_), "]\n") if DEBUG;

    $self->{ engine }->execute_query( $self, @_ );
}


sub row {
    my $self = shift;
    my $sth  = $self->execute(@_);

    $self->debug("query row() fetched ", $sth->rows, " row(s)\n") if DEBUG;

    return  $sth->fetchrow_hashref()
        || ($sth->err 
            ? $self->error_msg( dbi => fetchrow_hashref => $sth->errstr )
            : undef);
}


sub rows {
    my $self = shift;
    my $sth  = $self->execute(@_);

    $self->debug("rows() fetched ", $sth->rows, " row(s)\n") if DEBUG;

    return $sth->fetchall_arrayref({ })
        || ($sth->err 
            ? $self->error_msg( dbi => fetchall_arrayref => $sth->errstr)
            : undef );
}


sub column {
    my $self = shift;
    my $sth  = $self->execute(@_);
    my (@values, $value);

    $sth->bind_col(1, \$value) 
        || return $self->error_msg( dbi => bind_param => $sth->errstr );

    push(@values, $value) 
        while $sth->fetch;

    $self->debug("column() fetched ", scalar(@values), " value(s)\n") if DEBUG;

    return wantarray
        ?  @values
        : \@values;
}


sub destroy {
    my $self = shift;
    $self->debug("destroying query") if DEBUG;
    delete $self->{ engine };
}


1;


