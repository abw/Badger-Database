#========================================================================
#
# Badger::Database::Query::Select
#
# DESCRIPTION
#    Specialised query module for performing SELECT queries.
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
#========================================================================

package Badger::Database::Query::Select;

use Badger::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Badger::Database::Query',
    import    => 'class',
    constants => 'DELIMITER ARRAY DOT',
    words     => 'AND OR SELECT FROM WHERE',
    constant  => {
        GROUP_BY => 'GROUP BY',
        ORDER_BY => 'ORDER BY',
        BEFORE   => '',
        AFTER    => '',
    },
    alias     => {
        table    => \&from,
        order_by => \&order,
        group_by => \&group,
        value    => \&values,
    },
    config    => [
        'select|class::SELECT',
        'columns|class::COLUMNS',
        'from|table|class:FROM|class:TABLE',
        'join|class:JOIN',
        'where|class:WHERE',
        'order|order_by|class:ORDER|class:ORDER_BY',
        'group|group_by|class:GROUP|class:GROUP_BY',
    ];

our $JOINTS = {
    select => ', ',
    from   => ', ',
    join   => ' ',
    where  => ' AND ',
    order  => ', ',
    group  => ', ',
};
our @FRAGMENTS = keys %$JOINTS;
our @LIST_ARGS = (@FRAGMENTS, qw( values ));

class->methods(
    map {
        my $key = $_;               # new lexical var for closure
        $key => sub {
            my $self = shift;
            my $list = $self->{ $key };
            push(@$list, @_) if @_;
            $self->debug("adding to $key: ", join(', ', @_)) if DEBUG && @_;
            return $self;
        }
    }
    @LIST_ARGS
);


sub init {
    my ($self, $config) = @_;

    $self->configure($config);

    foreach my $key (@LIST_ARGS) {
        my $value = $self->{ $key } || [ ];
        $value = [ $value ]
            unless ref $value eq ARRAY;
        $self->{ $key } = $value;
    }

    my $columns = delete $self->{ columns };

    if ($columns) {
        $columns = [ split(DELIMITER, $columns) ]
            unless ref $columns eq ARRAY;
        $self->columns($columns);
    }

    $self->{ tables } = {
        map { $_ => $_ }
        @{ $self->{ from } }
    };

    return $self;
}


sub columns {
    my $self    = shift;
    my $newcols = @_ == 1 && ref $_[0] eq ARRAY ? shift : [ @_ ];
    my $columns = $self->{ columns } ||= { };
    my $table   = $self->table_name;
    my $val;

    $self->debug("new columns(): ", $self->dump_data($newcols)) if DEBUG;

    $self->select(
        # prefix the column names with the name of the last table specified
        map  {
#            $self->debug("COLUMN: $_\n");
            if (ref $_ eq ARRAY) {
                $val = $columns->{ $_->[1] } = $_->[0] . ' AS ' . $_->[1];
            }
#            elsif ($_ =~ s/^=//) {
#		$self->debug("FIXED field: $_\n");
#                $val = $columns->{ $_ } = $_;
#	    }
            else {
                $val = $self->column_name($_);
            }
            $val;
        }
        # TODO: grep { ! already selected }
        grep { defined && length }
        @$newcols
    );

    return $self;
}

sub column_name {
    my ($self, $name) = @_;
    my $column = $self->{ columns }->{ $name } || $name;

    # If the table name is a single word column name then we prefix it
    # with the name of the current table name.  e.g name => user.name
    # Otherwise we leave it be
    if ($column =~ /\W/) {
        # name contains a non-word character so we assume it's a SQL
        # fragment, e.g. "SUM(blah)", "foo.bar", etc.
        return $column;
    }
    else {
        # single word gets table prefix
        return $self->table_name . DOT . $column;
    }
}

sub table_name {
    my $self = shift;
    return $self->{ from }->[-1];
}


sub sql_fragments {
    my $self  = shift;
    my $frags = {
        map {
            $_ => join(
                $JOINTS->{ $_ },
                grep { defined && length }
                @{ $self->{ $_ } }
            )
        }
        @FRAGMENTS
    };
    $frags->{ select } ||= '*';

    return $frags;
}


sub prepare_sql {
    my $self  = shift;
    my $frags = $self->sql_fragments;

    return $self->error_msg( missing => 'source table(s)' )
        unless $frags->{ from };

    my @sql;

    # TODO: determine signature for query so we can see if there's a
    # pre-cached metaquery

    $self->debug(
        "prepare_sql() frags: ",
        $self->dump_data($frags)
    ) if DEBUG;

    push(
        @sql,
        $self->BEFORE,
        $self->SELECT => $frags->{ select },
        $self->FROM   => $frags->{ from   },
        $frags->{ join },
    );

    push(
        @sql,
        $self->WHERE => $frags->{ where }
    ) if $frags->{ where };

    push(
        @sql,
        $self->GROUP_BY => $frags->{ group }
    ) if $frags->{ group };

    push(
        @sql,
        $self->ORDER_BY => $frags->{ order }
    ) if $frags->{ order };

    push(
        @sql,
        $self->AFTER,
    );

    # cleanup any excessive whitespace
    my $sql = join(' ', grep { defined && length } @sql);
    $sql =~ s/\n(\s*\n)+/\n/g;
    $sql =~ s/\n\s+/\n  /g;

    if (DEBUG or $self->DEBUG) {
        $self->debug('SQL: ', $sql);
    }

    return $sql;
}



sub execute {
    my $self = shift;
    my $vals = $self->{ values };
    # push any cached values onto arguments list
    return $self->{ engine }->execute_query( $self, @$vals, @_ );
}


1;
