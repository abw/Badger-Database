#========================================================================
#
# Badger::Database::Record
#
# DESCRIPTION
#   Base class object for representing a record in a database table.
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
#========================================================================

package Badger::Database::Record;

use Badger::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Badger::Base',
    constants => 'ARRAY HASH DELIMITER REFS PKG',
    import    => 'class',
    throws    => 'database.record',  # IMPORTANT because we redefine id()
    words     => 'TODO';


our $RECORD     = 'Badger::Database::Record';
our $RELATION   = 'Badger::Database::Relation';
our $KEY        = 'id';       # default key name
our $KEY_FORMAT = '%s_id';
our $KEY_RE     = qr/\((\w+)\)/;
our $OPT_KEY_RE = qr/(?:$KEY_RE)?/;
our $MESSAGES   = {
    no_model        => 'Database model not specified',
    no_table        => 'Database table not specified',
    no_update       => 'No UPDATE fields are defined for %s objects',
    bad_table       => "Invalid table name specified: %s",
    bad_method      => "Invalid method '%s' called on %s at %s line %s",
    bad_method_type => "Invalid type defined for %s method: %s",
    bad_method_args => "Invalid argument specified for %s method: %s",
    bad_rel_type    => "Invalid relation type defined for %s method: %s",
    class_autoload  => "Cannot AUTOLOAD class method %s called at %s line %s",
};

our $RELATIONS  = {
    map { lc($_) => "Badger::Database::Relation::$_" }
    qw( Many List Hash Map )
};

our $GENERATORS = {
    read     => \&generate_read_method,     # a read-only method
    write    => \&generate_write_method,    # a read/write method for object data only (no db auto-update)
    update   => \&generate_update_method,   # update method which changes object and writes back to db
    delete   => \&generate_delete_method,   # have the record delete itself from the table
    link     => \&generate_link_method,     # a direct one-to-one link (e.g. child -> parent)
    relation => \&generate_relation_method, # other relations handled by $RELATIONS modules
};


our $AUTOLOAD;

# all internal data items are prefixed with '_' to prevent collision
# with any record fields.  So '_table' is our Badger::Table
# reference and 'table' is a field that's come from a database row

sub init {
    my ($self, $config) = @_;
    # base class record simply copies everything in $config into hash,
    # subclasses are free to do something different
    @$self{ keys %$config } = values %$config;
    return $self;
}

sub model {
    return $_[0]->{ _model }
        || $_[0]->error_msg('no_model');
}

sub hub {
    return $_[0]->{ _hub }
       ||= $_[0]->table->hub;
}

sub database {
    return $_[0]->{ _database }
       ||= $_[0]->table->database;
}

sub table {
    my $self = shift;
    if (@_) {
        # fetch the table named by an argument
        my $name = shift;
        return $self->model->has_table($name, @_)
            || $self->model->has_record($name, @_)
            || $self->error_msg( bad_table => $name );
    }
    else {
        # otherwise fetch our own table
        return $self->{ _table }
            || $self->error_msg('no_table');
    }
}

sub table_name {
    return $_[0]->{ _table_name }
       ||= $_[0]->table->name;
}

sub schema {
    return $_[0]->{ _schema }
       ||= $_[0]->table->schema;
}

sub key {
    return $_[0]->{ _key }
       ||= $_[0]->table->key;
}

sub id {
    my $self = shift;
    return $self->{ _id }
       ||= $self->{ $self->table->key };
}

sub method_args {
    # table can provide args handling utility sub    # TODO
    shift->table->method_args(@_);
}

sub update {
    my $self = shift;
    my $args = @_ && ref $_[0] eq 'HASH' ? shift : { @_ };
    my $key  = $self->key;

    # add our key                       # TODO: composite keys
    $args->{ $key } = $self->{ $key };

    # NOTE: table update() method will remove any items in $args that are not
    # listed in the table $SCHEMA->{ update } hash and will do so WITHOUT
    # WARNING!  I *think* this is the best thing, but it may need some rethink
    $self->table->update($args)
        || return $self->error($self->table->error());

    # copy all the new values that have been updated into $self
    @$self{ keys %$args } = values %$args;

    return $self;
}

sub dbh {
    shift->table->dbh;
}

sub begin_work {
    shift->dbh->begin_work
}

sub commit {
    shift->dbh->commit
}

sub rollback {
    shift->dbh->rollback
}

sub transaction {
    my $self = shift;
    return $self->table->transaction($self);
}

sub destroy {
    my $self = shift;
    $self->debug("destroying record: $self\n") if $DEBUG;
    %$self = ();
}

sub DESTROY {
    $_[0]->destroy;
}

sub AUTOLOAD {
    my ($self, @args) = @_;
    my ($name) = ($AUTOLOAD =~ /([^:]+)$/ );

    return if $name eq 'DESTROY';

    # don't AUTOLOAD class methods
    return __PACKAGE__->error_msg( class_autoload => $name, (caller())[1,2])
        unless ref $self;

    # if we've got a table then we can ask it if it can generate a method
    # appropriate for a humble record such as ourselves to use - the table
    # consults the schema so we get back an appropriate method that can
    # read/write/update/etc based on what the schema says.
    if ($self->{ _table }) {
        my $schema = $self->{ _table }->schema;
        my $method;

        if ($DEBUG) {
            use Badger::Debug;
            $self->debug("AUTOLOAD asking schema for $name method\n");
        }

        # TODO: ask the table instead?

        if (defined ($method = $schema->{ methods }->{ $name })) {
            if ($method) {                          # set method => 0 to disable method
                $self->debug("Found method in schema: $name\n") if $DEBUG;
                $self->generate_method($name => $method);
                $self->debug("Calling $self->$name(", join(',', @args), ")\n") if $DEBUG;
                return $self->$name(@args);
            }
        }
        elsif ($schema->{ update }->{ $name }) {
            $self->debug("Found update method in schema: $name\n") if $DEBUG;
            # TODO: change this, or make it configurable - it's too dangerous
            $self->generate_update_method($name);
            return $self->$name(@args);
        }
        elsif ($schema->{ key }->{ $name }) {
            $self->debug("Found key in schema: $name\n") if $DEBUG;
            $self->generate_read_method($name);
            return $self->{ $name };
        }
        elsif ($schema->{ field }->{ $name }) {
            # might want to generate a read/write method?
            $self->debug("Found field in schema: $name\n") if $DEBUG;
            $self->generate_read_method($name);
            return $self->{ $name };
        }
    }

    my ($pkg, $file, $line) = caller();
    return $self->error_msg( bad_method => $name, ref $self, $file, $line );
}


#-----------------------------------------------------------------------
# This is the New-Skool stuff for generating methods
#-----------------------------------------------------------------------

sub generate_method {
    my $self = shift;
    my $name = shift;
    my $args;
    if (@_ == 1) {
        # SUGAR: 'delete' ==> (delete => 1) ==> (delete => { type => 'delete' })
        if    (ref $_[0] eq HASH) { $args = shift }
        elsif (    $_[0] eq '1')  { $args = { type => $name } }
        else                      { $args = { type => $_[0] } }
#       else  { return $self->error_msg( bad_method_args => $name, shift ) }
    }
    else {
        $args = { @_ };
    }

    my $type = $args->{ type } || 'read';
    $type = 'relation' if $RELATIONS->{ $type };
    my $genr = $GENERATORS->{ $type }
        || return $self->error_msg( bad_method_type => $name, $type );

    $genr->($self, $name, $args);
}

sub generate_read_method {
    my $self  = shift;
    my $name  = shift;
    my $args  = @_ && ref $_[0] eq HASH ? shift : { @_ };
    my $item  = $args->{ item } || $name;
    my $class = ref $self || $self;
    no strict REFS;

    unless (defined &{ $class.PKG.$name }) {
        $class->debug("generating $name() to get $item\n") if DEBUG;
        *{ $class.PKG.$name } = sub {
            $_[0]->{ $item }
        };
    }
}

sub generate_write_method {
    my $self  = shift;
    my $name  = shift;
    my $class = ref $self || $self;
    no strict REFS;

    unless (defined &{ $class.PKG.$name }) {
        my $args  = @_ && ref $_[0] eq HASH ? shift : { @_ };
        my $item  = $args->{ item } || $name;
        $class->debug("generating $name() to get/set $item\n") if DEBUG;
        $self->class->method(
            $name => sub {
                return @_ == 2
                    ? ($_[0]->{ $item } = $_[1])
                    :  $_[0]->{ $item };
            }
        );
    }
}

sub generate_link_method {
    my $self  = shift;
    my $name  = shift;
    my $args  = @_ && ref $_[0] eq 'HASH' ? shift : { @_ };
    my $item  = $args->{ key    } || sprintf($KEY_FORMAT, $name);
    my $table = $args->{ table  } || $name;
    my $fkey  = $args->{ fkey   };
    my $where = $args->{ where  };
    my $class = ref $self || $self;
    no strict REFS;

    unless (defined &{ $class.PKG.$name }) {
        $self->debug("generating $name() to link to $table table via $item key\n") if $DEBUG;
        $self->debug("where: {", join(', ', map { "$_ => $where->{ $_ } }" } keys %$where), " }")
            if $DEBUG && $where;

        *{ $class.PKG.$name } = sub {
            $self->debug("linking $item to $table: $_[0]->{ $item }\n") if $DEBUG;

            return $_[0]->{"${name}_record"}  # cache object returned
               ||= $_[0]->table($table)->fetch(
                        $fkey  ? ($fkey => $_[0]->{ $item }) : $_[0]->{ $item },
                        $where ? %$where : ()
                   );
        };
    }
}

sub relation_module {
    my ($self, $type, $name) = @_;
    my $module = $RELATIONS->{ $type }
        || return $self->error_msg( bad_rel_type => $name || '', $type );
    class($module)->load;
    return $module;
}

sub generate_relation_method {
    my $self  = shift;
    my $name  = shift;
    my $class = ref $self || $self;
    no strict REFS;

    unless (defined &{ $class.PKG.$name }) {
        my $args   = @_ && ref $_[0] eq HASH ? shift : { @_ };
        my $type   = $args->{ type  };
        my $tname  = $args->{ table } ||= $name;
        my $key    = $args->{ key   } ||= $self->key();
        my $module = $self->relation_module($type, $name);

        $self->debug(
            "generating $name() as $type relation to $tname table from local '$key' key",
            $args->{ fkey } ? " to remote '$args->{ fkey }' key\n" : "\n"
        ) if $DEBUG;

        *{ $class.PKG.$name } = sub {
            my $self = shift;
            my $id   = $self->{ $key };
            $self->debug(
                "called $name() to fetch $type from $tname ",
                $args->{ fkey } ? "with $args->{ fkey } " : '',
                "matching our $key=$id\n"
            ) if $DEBUG;
            my $table = $self->table($tname)
                || return $self->error_msg( bad_table => $tname );

            return $self->{"${name}_relation"}  # cache object returned
                ||= $module->new({
                    %$args,
                    table => $table,
                    id    => $id,
                    fetch => 1,
                });
        };
    }
}

sub generate_update_method {
    my $self  = shift;
    my $name  = shift;
    my $class = ref $self || $self;
    no strict REFS;

    unless (defined &{ $class.PKG.$name }) {
        my $args = @_ && ref $_[0] eq 'HASH' ? shift : { @_ };
        my $item = $args->{ item } || $name;
        $self->debug("generating $name() in $class to update $item\n") if $DEBUG;

        *{ $class.PKG.$name } = sub {
            my $self = shift;
            if (@_) {
                # TODO: assert not read_only
                my $key   = $self->key;
                my $value = shift;
                $self->debug("update WHERE $key => $self->{ $key }   VALUE: $item => $value\n") if DEBUG;
                $self->table->update( $key => $self->{ $key }, $item => $value );
                $self->{ $item } = $value;
                return $value;
            }
            else {
                return $self->{ $item };
            }
        };
    }
}

sub generate_delete_method {
    my $self  = shift;
    my $name  = shift;
    my $class = ref $self || $self;
    no strict REFS;

    unless (defined &{ $class.PKG.$name }) {
        my $args = @_ && ref $_[0] eq 'HASH' ? shift : { @_ };
        my $key  = $self->key();

        $class->debug("generating $name() to delete record\n") if $DEBUG;

        *{ $class.PKG.$name } = sub {
            my $self = shift;
            my $key  = $self->key();
            # TODO: chained delete
            # TODO: assert not read_only
            $self->debug("deleting record $self\n") if $DEBUG;
            $self->table->delete( $key => $self->{ $key } );
        };
    }
}


1;

=head1 NAME

Badger::Database::Record - base class database record object

=head1 SYNOPSIS

    package Badger::Widget;
    use base 'Badger::Database::Record';

    __PACKAGE__->generate_methods({
        read  => 'id, name, title, price'
        write => 'stock',
        link  => 'merchant',
    });

=head1 DESCRIPTION

This module implements a base class object for representing active
database records.  It is designed to be subclassed to create objects
to represent records from different database tables.

    package Badger::Widget;
    use base 'Badger::Database::Record';

You can add your own methods to implement whatever functionality your
entities require.

    sub flibble {
        my $self = shift;
        # ...your code here...
    }

For methods that are simply returning or updating internal values, or referencing
other entities in the data model, you can use the L<generate_methods()> method to
generate the methods for you.

    __PACKAGE__->generate_methods({
        read  => 'id, name, title, price'
        write => 'stock',
        link  => 'merchant',
    });

This is described in detail below.

L<Badger::Database::Record> objects are closely related to
L<Badger::Database::Table> objects.

So if you're writing a subclass of L<Badger::Database::Record> then you
almost certainly want to write the corresponding subclass of
L<Badger::Database::Table> to manage them for you.

=head1 METHODS

=head2 new()

Constructor method.  Accepts any number of named parameters all of
which are stored internally for later use.

    use Badger;
    my $model  = Badger->model;
    my $widget = Badger::Widget->new({
        model    => $model,
        table    => 'widgets',
        id       => 12345,
        name     => 'foo',
        title    => 'The foo widget',
        price    => 12.99,
        stock    => 42,
        merchant => 98765,
    });

The only parameters that must be specified are C<model> and C<table>.
The C<model> parameter provides a reference to the L<Badger::Database::Model>
object that is the overall manager for all the tables in the data model.
The C<table> parameter gives the table name by which the record can
fetch the corresponding L<Badger::Database::Table> object from the
model.

Objects that are subclasses of C<Badger::Database::Record> are created
by their corresponding L<Badger::Database::Table> modules which take
care of all this for you.

So unless you have particular reason to do otherwise, always use the relevant
table object (e.g. C<Your::Table::Users>) to create the individual record
objects (e.g. C<Your::Record::User>) for you.

    # get the data model object
    my $model = Badger->model();

    # get the users table object
    my $users = $model->users();

    # create a new user record
    my $user = $users->create( %data );

=head2 model()

Returns a reference to the L<Badger::Database::Model> in use.

=head2 table()

Returns a reference to the subclass of L<Badger::Database::Table>
responsible for managing these record objects.

=head2 database()

Returns a reference to the L<Badger::Database> in use. This simply delegates
to the C<database()> method of the L<Badger::Database::Model> returned by the
L<model()> method.

=head2 commit()

Not yet implemented.  Will eventually provide the mechanism for
commiting changes to the object back to the database.

=head2 rollback()

Not yet implemented.  Will eventually provide the mechanism for
reverting an object back to the values stored in the database.

=head2 generate_read_method($name,$item)

Generates a method called C<$name> which provides read-only access to the
internal C<$item>.  For example, consider the following method call.

    $record->generate_read_method( foo => 'the_foo_item' );

This generates a method equivalent to:

    sub foo {
        return $_[0]->{ the_foo_item };
    }

=head2 generate_read_methods($methods)

Calls L<generate_read_method()>

=head2 generate_write_method($name,$item)

Generates a method called C<$name> which provides read/write access to the
internal C<$item>.  For example, consider the following method call.

    $record->generate_write_method( foo => 'the_foo_item' );

This generates a method equivalent to:

    sub foo {
        @_ > 1 ? ($_[0]->{ the_foo_item } = $_[1])
               :  $_[0]->{ the_foo_item };
    }

It is important to note that this method I<only> updates the object's internal
copy of the data.  It does I<not> commit any changes back to the database.

NOTE: we may want to change this to mark the item as 'dirty' so that a
subsequent commit() can commit any changed fields.

=head2 generate_link_method($name,$item,$table)

Generates a method called C<$name> which provides a link to a related record
in the same or a different table.  For example, consider the following method call.

    $record->generate_write_method('parent', 'parent_id', 'nodes' );

This generates a method equivalent to:

    sub foo {
        my $self = shift;
        $self->table('nodes')->fetch( $self->{ parent_id } );
    }

=head2 generate_update_method()

TODO: a method for generating methods that do flush changes back to the database.

=head2 generate_methods()

This method is provided for subclasses to automatically generate methods
to access their data items. It should be called as a class method, using
the name of the subclass (e.g. C<Badger::Widget>) rather than the base
class (e.g. C<Badger::Database::Record>). The most convenient way is to
use Perl's C<__PACKAGE__> token to correctly insert the package (i.e.
subclass) name.

    package Badger::Widget;
    use base 'Badger::Database::Record';

    # shorthand for Badger::Widget->generate_methods(...)
    __PACKAGE__->generate_methods({
        read  => 'id, name, title, price'
        write => 'stock',
        link  => 'merchant',
    });

There are three types of methods than can be generated. To illustrate the
different types, consider the following object data based on the class defined
above.

    my $widget = Badger::Widget->new({
        model    => $model,
        table    => 'widgets',
        id       => 12345,
        stock    => 42,
        merchant => 98765,
    });

C<read> methods (like C<id()>) simply return the value of the item stored in
the object.

    print $widget->id();            # 12345

C<write> methods (like C<stock()>) return the value when called without
arguments and update it when called with an argument. Note however that this
only updates the value inside the object and does not commit the change back
to the database.

    $widget->stock(41);
    print $widget->stock();         # 41

They also return the new value when called with an argument.

    print $widget->stock(40);       # 40

C<link> methods return a reference to a related object. For each C<link>
method specified (e.g. C<merchant()>), a second method is created to return
the identifier of the related object rather than a live object. This method
has the C<_id> suffix (e.g. C<merchant_id()>)

So in this example, the C<merchant_id()> method returns the merchant
identifier.

    print $widget->merchant_id();   # 98765

The C<merchant()> method returns a C<Badger::Merchant> object for the
merchant with id C<98765>.

    my $merchant = $widget->merchant();
    print $merchant->id();          # 98765
    print $merchant->name();        # e.g. Joe Bloggs Widgets Ltd.

If you want to create a method that has a different name to the internal item
that it references, then add the internal key name in parentheses immediately
after the method name.

For example, if the object has an item stored internally as C<date> that you
want to access via a C<timestamp()> read-only method then you would write the
following:

    __PACKAGE__->generate_methods({
        read  => 'timestamp(date)'
    });

Here's another example showing how we generate an C<order_no()> read-only
method along with C<order_id()> and C<order()> link methods. In this case, the
C<order_no()> and C<order_id()> methods both return the same thing, that is
the interal C<order_no> value. The C<order()> method returns C<Badger::Order>
object for the current C<order_no>.

    __PACKAGE__->generate_methods({
        read  => 'order_no',
        link  => order(order_no),
    });

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 2005-2009 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<Badger::Database::Model>, L<Badger::Database::Table>.

=cut

# Local Variables:
# mode: Perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
