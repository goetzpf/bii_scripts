package cfgfile;

# miscellenaious low level config routines

# ===========================================================
# note: to quickly see the man-page enter:
# pod2usage -verbose 3 date.pm
# ===========================================================


use strict;

use Data::Dumper;
use Config::General;
# used modules

# non-exported package globals go here

# initialize package globals

our $errorfunc= \&my_err_func;
our $warnfunc = \&my_warn_func;

my $mod= "cfgfile";

sub create_config
  {
    (my $r_glbl, my $dirname) = @_;
    if (length($dirname) > 0)
      {
        my $r_glbgl->{config_location}->$ENV{"HOME"}."/".$dirname;
        if (! -e $PrgDir)
        {
            mkdir($dirname, 00700) or die "Can not create configuration location at ".$dirname;
        }
        else
        {
            warn "Config directory $dirname exists.";
        }
      }
    else
      {
        die "Can not create configuration location at ".$dirname;
      }
  }

sub read_config
  {
    (my $r_glbl, my $filename) = @_;
    if (-r $filename)
      {
        $cfgh = new Config::General($filename);
        $r_glbl->{configuration} = $cfgh->getall;
      }
    else
      {
        warn ("Can not read configuration file ".$filename);
      }
    undef ($cfgh);
  }

sub save_config
  {
    (my $r_glbl, my $filename) = @_;
    if (-w $filename)
      {
        $cfgh = new Config::General($filename);
        $cfgh->save_file($filename, $r_glbl->{configuration} = );
      }
    else
      {
        warn ("Can not write to configuration file ".$filename);
      }
  }

1;

# Below is the short of documentation of the module.

=head1 NAME

cfgfile - a Perl module for low-level utility function to access
a config file.

=head1 SYNOPSIS

  use cfgfile;

=head1 DESCRIPTION

=head2 Preface

This module reads an write configuration files given by
Config::General module from CPAN.

=back

The function calls C<dbdrv::dberror()> if the loading of the driver
failed. See also L</error handling> further below.

=head2 error handling
  
dbdrv uses two error handling functions, for fatal and non-fatal 
errors. These functions are C<dbdrv::dberror()> and C<dbdrv::dbwarn()>,
you can use them for your application, too. This may be useful since 
it is easy to ovveride these functions and provide a method of 
your own to print out the error messages.

=over 4

=item dbdrv::dbwarn()

  if ($not_fatal_error)
    { dbdrv::dbwarn($module_name,$function,__LINE__,
                    "a non fatal error occured"); 
    }

This function takes 4 arguments. C<$module_name> is the name 
of your perl-module, C<$function> the name of your function 
where the error occured. The 3rd parameter is the line-number and
the fourth is the error-string. C<dbdrv::dbwarn()> returns after
it has printed the error-message.

=item dbdrv::dberror()

  if ($fatal_error)
    { dbdrv::dberror($module_name,$function,__LINE__,
                     "a fatal error occured, aborting the program"); 
    }
    
This function takes the same parameters as C<dbdrv::dbwarn()>, the
only difference is that it terminates your program by calling C<die>.

=back

Both functions mentioned above print messages to STDERR. 
You can, however override these two functions. This is useful when
your application is for example a graphical application and you
want error-messages to appear in a graphical error-box.

Overriding the error or warn-function is done by calling one
of the two following functions:

=over 4

=item set_warn_func()

  sub my_warn_func
    { my($err_message)= @_;
      warn "There was an error: $err_message";
    }

  $dbdrv::set_warn_func(\&my_warn_func)
  
This function has only one parameter which should be a reference
to a function or C<undef>. In the first case, the function you
supplied is used to print the error-message. It should expect
one single string as argument and show, in what way ever, this string
to the user. If the parameter of C<set_warn_func> is C<undef>
or missing, the original error printing function (a simple
call to C<warn>) is re-instated.

=item set_error_func()

  sub my_error_func
    { my($err_message)= @_;
      die "There was an error: $err_message";
    }

  $dbdrv::set_error_func(\&my_error_func)
  
This function is very similar to C<set_warn_func>. The only difference
is that the cases when your error-print function is called are usually
fatal errors that can not be recovered. So it is safe when your function
terminates the program with C<die>. In some cases however, your function
may not terminate the program and simply return. It is, however, your
responsibility to check when this makes sense.

=back  

=head2 tracing

dbdrv has an internal function in order to print SQL commands that 
are executed. This function does a simple C<print> with a final 
carriage return. This function may be overridden like this:

  sub my_trace_func
    { my($trace_message)= @_;
      print $trace_message,"\n";
    }

  dbdrv::set_sql_trace_func(\&my_error_func)

C<dbdrv::set_sql_trace_func> has only one parameter wich should be a 
reference to a function or C<undef>. In the first case, the function you
supplied is used to print the SQL statement. It should expect
one single string as argument and show, in what way ever, this string
to the user. If the parameter of C<set_sql_trace_func> is C<undef>
or missing, the original tracing function (a simple call to C<print>) 
is re-instated.

Tracing is switched on or of by writing 0 of one to the
variable C<$sql_trace>. This for example, switches SQL tracing on:

  $dbdrv::sql_trace=1;

Note that if your application executes SQL statements, too, it 
has to call the sql trace function in order to show all SQL statments
to the user:

  my $cmd= "select max( $pk ) from MY_TABLE";
  dbdrv::sql_trace($cmd);
    # ^^ this shows the SQL statement to the user
  my @array = $dbh->selectrow_array($cmd);
    # ^^ this executes the SQL statement
   
If your application uses C<prepare> or C<execute> from the DBI
module, you should use C<prepare> or C<execute> from dbdrv instead.

=over 4

=item prepare()

  my $format;
  my $sth= dbdrv::prepare(\$format,$dbh,
                	 "delete from $self->{_table} " .
        	          "where KEY = ? ");

The first parameter is a reference to a scalar variable. This
is used by C<dbdrv::execute> later. C<$dbh> is the database
handle and the 3rd parameter is the SQL statement with placeholders
("?") as described in the DBI manpage. The function returns a 
statement handle, just like it is described at C<prepare>
in the DBI module.

=item execute()

  if (!dbdrv::execute($format,$dbh,$sth,@params))
    { error ... }
    
The first parameter is the format scalar variable that was initialized
by C<dbdrv::prepare>. C<$dbh> is the database handle and 
C<$sth> is the statement handle that was returned with C<dbdrv::prepare>.
All following parameters (C<@params>) are used to fill the placeholders
that were given to C<dbdrv::prepare> in the SQL statement string.

=back

=head2 database utility functions

=over 4

=item dbitable::connect_database()

  my $dbh= dbitable::connect_database($dbname,$username,$password)
    
This method creates a connection to the database. The database corresponds
to the first parameter of the C<connect> function of the DBI module. See 
also the DBI manpage. The function returns the DBI-handle or C<undef>
in case of an error. The DBI-handle is also stored in the internal global
handle variable. This variable is used as default in all the other 
functions in this module when their DBI-handle parameter is an empty 
string ("") or C<undef>.

=item dbitable::disconnect_database()

  dbitable::disconnect_database($dbi_handle)
  
This function is used to disconnect from the database. If the parameter
C<$dbi_handle> is an empty string, the default DBI-handle is used (see
also description of C<connect_database>).  

=item dbitable::check_dbi_handle()

  $dbh= dbitable::check_dbi_handle($dbh);
  
This function does the checking of the dbi-handle in all functions of
this module. When C<$dbh> is empty ("") or C<undef>, it returns the
internal standard dbi-handle (C<dbdrv::std_dbh>), otherwise it 
returns the parameter C<$dbh>. When the given parameter 
is not a valid DBI handle, it returns C<undef>.

=item dbdrv::check_existence()

  if (dbdrv::check_existence($dbh,$table_name,$user_name))
    { print "table exists and can be accessed\n"; }
  else
    { print "table does not exist or is not accessible\n"; }
  
This function performs a simple check wether a table exists. 
C<$dbh> is the database handle, C<$table_name> the name of the table.
C<$user_name> is the username and optional. The username is
storedin the variable C<dbdrv::std_username> when C<connect_database()> 
is called. The function returns C<1> when the table is accessible and 
C<undef> when not.

=item dbdrv::primary_keys()

  my @pk_list= dbdrv::primary_keys($dbh,$table_name)

This function returns a list of primary keys of a given table. Note that
the list may be empty, and that the list may contain more than one
column name if a combination of columns forms the primary key.

=item dbdrv::foreign_keys()

  my %fk_hash= dbdrv::foreign_keys($dbh,$table_name)

This function returns all columns in a table that are foreign
keys in a hash. Note that foreign keys may have a different column
name in the foreign table they refer to.
The foreign key hash has the following format:

  my %fk_hash= ( $column_name1 => 
                       [$foreign_table1,$foreign_column_name1],
                 $column_name2 => 
		       [$foreign_table2,$foreign_column_name2],
                        ...
                 $column_nameN => 
		       [$foreign_tableN,$foreign_column_nameN],
	       )

=item dbdrv::resident_keys()

  my %rk_hash= dbdrv::resident_keys($dbh,$table_name)

This function returns all tables where one of the primary key 
columns in the given table C<$table_name> is used as foreign key.
It returns a hash of the following format 

  my %rk_hash= ( $primary_key1 => 
                        [$resident_table11,$resident_column11],
  			[$resident_table12,$resident_column12],
			   ...
  			[$resident_table1N,$resident_column1N],
				  
                 $primary_key2 => 
		        [$resident_table21,$resident_column21],
  			[$resident_table22,$resident_column22],
			   ...
  			[$resident_table2N,$resident_column2N],
                    ...
	        )


=item dbdrv::accessible_public_objects

  my @objects= accessible_public_objects($dbh,$type,$user_name)
  
This function returns all accessible public objects (tables and
views) for a given user.

--- to be continued ---

=item dbdrv::accessible_public_objects

--- to be continued ---

=back

=head1 AUTHOR

Goetz Pfeiffer,  pfeiffer@mail.bessy.de

=head1 SEE ALSO

perl-documentation, DBI manpage

=cut
