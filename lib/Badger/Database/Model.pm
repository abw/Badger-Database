#========================================================================
#
# Badger::Database::Model
#
# DESCRIPTION
#   Base class object for representing a database model.
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
#========================================================================

package Badger::Database::Model;

use Badger::Class
    version      => 0.01,
    debug        => 0,
    base         => 'Badger::Database::Base',
    import       => 'class',
    dumps        => 'table_base tables record',
    accessors    => 'engine',
    utils        => 'refaddr plural',
    hash_methods => 'tables',
    constants    => 'ARRAY HASH DELIMITER REFS PKG',
    constant     => {
        TABLE    => 'Badger::Database::Table',
        AUTOGEN  => '_autogen',
    },
    messages     => {
        no_hub         => 'The database model does not have a hub defined',
        no_table       => 'The %s table is not defined in the data model',
        bad_table      => 'Invalid table specification for %s: %s',
        bad_method     => "Invalid method '%s' called on %s at %s line %s",
        class_autoload => "Cannot AUTOLOAD class method %s called at %s line %s",
    };

our $AUTOLOAD;


sub init {
    my ($self, $config) = @_;

    $self->{ hub } = $config->{ hub };

    $self->{ engine } = $config->{ engine }
        || return $self->error_msg( missing => 'engine' );

    $self->{ tables } = $self->class->hash_vars(
        TABLES => $config->{ tables }
    );

    $self->{ records } = $self->class->hash_vars(
        RECORDS => $config->{ records }
    );

    $self->debug(
        "model tables: ",
        $self->dump_data($self->{ tables }),
        "\n",
        "model records: ",
        $self->dump_data($self->{ records }),

    ) if DEBUG;

    $self->{ table_base } = $config->{ table_base } || $self->TABLE;

    return $self;
}

sub table {
    my $self = shift;
    my $name = shift || return $self->error_msg( missing => 'table' );

    # Look for the table in the cache or create it.

    return $self->{ table_cache }->{ $name } ||= do {
        my ($module, $config);

        $self->debug(
            "looking for $name in tables: ",
            $self->dump_data($self->{ tables }),
            "\n"
        ) if DEBUG;

        $module = $self->{ tables }->{ $name }
            || $self->{ tables }->{ plural $name }
            || return $self->error_msg( no_table => $name );

        # table entry can be a module name or hash ref of config params
        if (! ref $module) {
            $config = { };                  # got a module name, no config
        }
        elsif (ref $module eq HASH) {
            $config = { %$module };         # copy so we can safely add args
            $module = $config->{ module };  # may be undef, handled below
        }
        else {
            return $self->error_msg( bad_table => $name => $module );
        }

        if ($module) {
            # if we've got the name of a module then we just need to load it
            $self->debug("Loading $name table module: $module") if DEBUG;
            class($module)->load;
        }
        else {
            # otherwise we create a subclass of the table_base class
            $module = $self->table_subclass($name);
            $self->debug("Creating table subclass for $name: $module") if DEBUG;
            class($module)->base( $self->{ table_base } );
        }

        # add table name and references to model and engine, then instantiate
#       $config->{ table  } ||= $name;
        $config->{ model  }   = $self;
        $config->{ engine }   = $self->{ engine };
        $module->new( $config );
    };
}

sub table_subclass {
    my ($self, $table) = @_;

    # generate the name of a subclass of the table_base class with a unique
    # name based on the names of the database and table,
    #   e.g. Badger::Database::Table::_autogen::mydb::users

    join(
        PKG,
        $self->{ table_base },
        AUTOGEN,
        $self->{ engine }->safe_name,
        $table
    );
}

sub can {
    my ($self, $name) = @_;
    my $code;

    # upgrade class methods to calls on prototype
    $self = $self->prototype unless ref $self;

    # first see if the regular can() method can find the method we're after
    if ($code = $self->SUPER::can($name)) {
        return $code;
    }

    # otherwise see if the method name can be mapped onto the name of
    # a table or a record produced by a table.
    my $altname = $name;
    my ($table, $method);
    no strict REFS;

    $self->debug("Looking for $name\n") if DEBUG;

    if ($altname =~ s/_table$//) {
        # a method ending _table(), e.g. users_table() is mapped to the table
        $self->debug("$name has _table suffix, looking for $altname table") if DEBUG;
        if ($table = $self->has_table($altname)) {
            $self->debug("model has $altname table: $table") if DEBUG;
            $code = $self->_generate_table_method($altname, $table);
        }
        else {
            $self->debug("model does not have $altname table") if DEBUG;
        }
    }
    elsif ($altname =~ s/_record$//) {
        # a method ending _record() is mapped to the fetch() method on the
        # corresponding table, e.g. $model->users_record() does the same
        # thing as $model->users->fetch()
        $self->debug("$name has _record suffix, looking for $altname table/record") if DEBUG;
        if ($table = $self->has_table($altname) || $self->has_record($altname)) {
            $self->debug("model has $altname table/record: $table") if DEBUG;
            $code = $self->_generate_record_method($altname, $table);
        }
        else {
            $self->debug("model does not have $altname table/record") if DEBUG;
        }
    }
    elsif ($table = $self->has_table($name)) {
        # if the method is the name of a table, then return the table
        $self->debug("model has $name table") if DEBUG;
        $code = $self->_generate_table_method($name, $table);
    }
    elsif ($table = $self->has_record($name)) {
        # or if it's the name of a record then call fetch() for the table
        $self->debug("model has $name record") if DEBUG;
        $code = $self->_generate_record_method($name, $table);
    }
    else {
        $self->debug("nothing found for $name") if DEBUG;
    }

    # if we generated a new method then patch it into the symbol table
    $self->class->method( $name => $code )
        if $code;

    return $code;
}

sub has_table {
    my ($self, $name) = @_;
    return $self->{ tables }->{ $name }
        && $self->table($name);
}

sub has_record {
    my ($self, $name) = @_;
    my $table = $self->{ records }->{ $name };
    if ($table) {
        return $self->table($table);
    }
    else {
        # see if we've got a table with the plural name of this record
        return $self->has_table( plural $name );
    }
}

sub hub {
    return $_[0]->{ hub }
       ||= $_[0]->error_msg('no_hub');
}

sub _generate_table_method {
    my ($self, $name, $table) = @_;
    $self->debug("generate table: $name => $table") if DEBUG;
    return sub { shift->table($name) };
}

sub _generate_record_method {
    my ($self, $name, $table) = @_;
    $self->debug("generate record: $name => $table") if DEBUG;
    return sub {
        my $this  = shift;
        my $table = $self->table($name);
        return $table->fetch(@_)
            || $this->decline($table->reason);
    };
}

sub AUTOLOAD {
    my ($self, @args) = @_;
    my ($name) = ($AUTOLOAD =~ /([^:]+)$/ );

    return if $name eq 'DESTROY';

    # don't AUTOLOAD class methods
    return $self->error_msg( class_autoload => $name, (caller())[1,2])
        unless ref $self;

    my $method = $self->can($name);

    if ($method) {
        $self->debug("Got method for $name: $method") if DEBUG;
        return $self->$name(@args);
    }
    else {
        my ($pkg, $file, $line) = caller();
        return $self->error_msg( bad_method => $name, ref $self, $file, $line );
    }
}

sub destroy {
    my $self = shift;
    my $msg  = shift || '';
    my ($tables, $table);

    $self->debug(
        "Destroying model",
        length $msg ? " ($msg)" : ''
    ) if DEBUG;

    # notify any cached table objects that they have also lost the connection
    # and must clear any cached statement handles
    $tables = delete $self->{ table_cache };

    foreach $table (values %$tables) {
        $table->destroy if $table;
    }
    %$table = ();

    delete $self->{ engine };

    return $self;
}

sub DESTROY {
    shift->destroy('object destroyed');
}

1;

=head1 NAME

Badger::Database::Model - base class database model

=head1 SYNOPSIS

TODO

=head1 DESCRIPTION

TODO

=head1 METHODS

TODO

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 2005-2009 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<Badger::Database>, L<Badger::Database::Table>.

=cut

# Local Variables:
# mode: Perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
