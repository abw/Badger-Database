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

#-----------------------------------------------------------------------------
# SQL methods
#-----------------------------------------------------------------------------

sub sql {
    my $self = shift;
    return $self->{ sql }
       ||= $self->prepare_sql;
}

sub prepare_sql {
    # hook for future expansion where SQL is generated on demand
    shift->not_implemented('in base class');
}


#-----------------------------------------------------------------------------
# SQL -> STH
#-----------------------------------------------------------------------------

sub prepare {
    # this method is required for backwards compatibility
    shift->sth;
}

sub sth {
    my $self = shift;
    return $self->{ sth }
        ||= $self->prepare_sth;
}

sub prepare_sth {
    my $self = shift;
    return $self->{ engine }->prepare(
        $self->sql,
        @_
    );
}


#-----------------------------------------------------------------------------
# Query execution and results
#-----------------------------------------------------------------------------

sub execute {
    my $self = shift;
    $self->debug("Executing query via engine: $self->{ engine } : \n", $self->sql) if DEBUG;
    $self->debug("execute args: [", join(', ', map { defined $_ ? $_ : '<undef>' } @_), "]\n") if DEBUG;

    # NOTE: we must call execute_query() rather than execute() because the
    # MySQL engine subclass (Badger::Database::Engine::MySQL) defines some
    # additional magic to work around the "Server has gone away" problem.
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



#-----------------------------------------------------------------------------
# Cleanup methods
#-----------------------------------------------------------------------------

sub destroy {
    my $self = shift;
    $self->debug("destroying query") if DEBUG;
    delete $self->{ engine };
}


1;

=head1 NAME

Badger::Database::Query - SQL query object base class

=head1 DESCRIPTION

This module defines a base class for object that generate SQL queries
programmatically.

=head1 METHODS

The following methods are defined in addition to those inherited from the
L<Badger::Database::Base> and L<Badger::Base> modules.

=head2 sql()

Returns the C<sql> query specified as a configuration option, or
calls the L<prepare_sql()> method to generate the SQL on demand.

=head2 prepare_sql()

This method should be redefined by subclasses that generate the SQL query
dynamically.  In this base class module it throws an error to warn the
developer that it hasn't been redefined.

=head2 sth()

Returns a L<DBI> statement handle for the SQL query returned by the
L<sql()> method.  It calls the L<prepare_sth()> method once and then caches
the result for any future invocations.

=head2 prepare_sth()

Internal method called by L<sth()> to prepare a statement handle for the
SQL query.

=head2 execute(@args)

Internal method called by the L<row()>, L<rows()> and L<column()> methods
to execute the query statement handle that is returned by the L<sth()>
method.

=head2 row(@args)

Returns the first row in the results returned by calling the
L<execute()> method.

=head2 rows(@args)

Returns all rows in the results returned by calling the
L<execute()> method.

=head2 column(@args)

Returns a single column of values returned by calling L<execute()>.

=head1 AUTHOR

Andy Wardley E<lt>abw@wardley.orgE<gt>.

=head1 COPYRIGHT

Copyright (C) 2008-2014 Andy Wardley.  All Rights Reserved.

=head1 SEE ALSO

L<Badger::Database::Query::Select>,
L<Badger::Database::Base>,
L<Badger::Base>.

=cut
