package dbdrv;

# miscellenaious low level database routines

# ===========================================================
# note: to quickly see the man-page enter:
# pod2usage -verbose 3 date.pm
# ===========================================================


use strict;

BEGIN {
    use Exporter   ();
    use vars       qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
    # set the version for version checking
    $VERSION     = 1.0;

    @ISA         = qw(Exporter);
    @EXPORT      = qw();
    %EXPORT_TAGS = ( );     # eg: TAG => [ qw!name1 name2! ],

    # your exported package globals go here,
    # as well as any optionally exported functions
    @EXPORT_OK   = qw();

    #use DBI;
    if (!$ENV{DBITABLE_NO_DBI})
      { require DBI;
	import DBI;
      };

}
use vars      @EXPORT_OK;
use Data::Dumper;

# used modules

# non-exported package globals go here

# initialize package globals

our %drivers= ( Oracle => 'dbdrv_oci.pm' );
our $std_dbh; # internal standard database-handle

our $errorfunc= \&my_err_func;
our $warnfunc = \&my_warn_func;
our $sql_trace_func= \&my_sql_trace;
our $sql_trace=0;
our $db_trace  =0;

my $mod= "dbdrv";

my $no_dbi= $ENV{DBITABLE_NO_DBI};


sub set_err_func
  { my($f_ref)= @_;
  
    if (!defined $f_ref)
      { # reset to old error-function
        $errorfunc= \&my_err_func;
	return;
      }
      
    if (ref($f_ref) ne "CODE")
      { dberror($mod,'set_err_func',__LINE__,
                'parameter is not a reference to a subroutine!');
      };
    $errorfunc= $f_ref;
  }  

sub set_warn_func
  { my($f_ref)= @_;
  
    if (!defined $f_ref)
      { # reset to old warn-function
        $warnfunc= \&my_warn_func;
	return;
      };

    if (ref($f_ref) ne "CODE")
      { dberror($mod,'set_warn_func',__LINE__,
                'parameter is not a reference to a subroutine!');
      };
    $errorfunc= $f_ref;
  }  

sub set_sql_trace_func
  { my($f_ref)= @_;
  
    if (!defined $f_ref)
      { # reset to old trace-function
        $sql_trace_func= \&my_sql_trace;
	return;
      };

    if (ref($f_ref) ne "CODE")
      { dberror($mod,'set_warn_func',__LINE__,
                'parameter is not a reference to a subroutine!');
      };
    $sql_trace_func= $f_ref;
  }  


sub my_err_func
  { die $_[0]; }

sub my_warn_func
  { warn $_[0]; }

sub my_sql_trace
  { print $_[0],"\n"; };

sub dberror
  { my($module,$func,$line,$msg)= @_;
    my $str= "${module}::$func [$module.pm:$line]:\n" . $msg;
    
    &$errorfunc($str);
  }
  
sub dbwarn
  { my($module,$func,$line,$msg)= @_;
    my $str= "${module}::$func [$module.pm:$line]:\n" . $msg;
    
    &$warnfunc($str);
  }

sub sql_trace
  { return if (!$sql_trace);
  
    &$sql_trace_func(@_);
  }
  
sub prepare
  { my($r_format,$dbh,$cmd)= @_;
        
    my $sth = $dbh->prepare($cmd);
    return if (!defined $sth);

    if ($sql_trace)
      { $$r_format= $cmd;
        $$r_format=~ s/\?/\%s/g; $$r_format.= "\n";
      }; 
    return($sth);
  }
  
sub execute
  { my($format,$dbh,$sth,@args)= @_;
  
    if ($sql_trace)
      { sql_trace( sprintf($format, @args) );
      };	   

    return( $sth->execute( @args));
  };    
  

sub load
  { my($driver_name)= @_;
  
    if (!exists $drivers{$driver_name})
      { dberror($mod,'load_driver',__LINE__,
                'unknown db driver:$driver_name');
	return;
      };
    if (!do($drivers{$driver_name}))
      { dberror($mod,'load_driver',__LINE__,
                "unable to load db driver $driver_name: $@");
	return;
      };
    return(1); 
  }     

  

sub connect_database
# if dbname=="", use DBD::AnyData
  { my($dbname,$username,$password)= @_;
  
    warn "connecting to database...\n" if ($db_trace);
    
#    if ($dbname eq "")
#      { $dbname= "DBI:AnyData:"; };
    
    my $dbh    = DBI->connect($dbname,
                              #"DBI:AnyData:",# driver-name 
                              $username,     # user-name
                              $password,     # password
                             {RaiseError=>0, # errors abort the script
			      PrintError=>0, # not needed bec. of RaiseError 
			      AutoCommit=>1} # automatically commit changes
			     );

    if (!defined $dbh)
      { dbwarn($mod,'connect_database',__LINE__,
               "unable to connect to database, error-code: \n$DBI::errstr");
        return;
      };
      
    if (!defined $std_dbh)
      { $std_dbh= $dbh; };
      
    return($dbh);
  }
   
sub disconnect_database
  { my($dbh)= @_;
  
    if (!defined $dbh)
      { $dbh= $std_dbh; }
    elsif ($dbh eq "")
      { $dbh= $std_dbh; };
  
    if (!$dbh->disconnect()) 
      { dbwarn($mod,'connect_database',__LINE__,
               "disconnect returned an error, error-code: \n$DBI::errstr");
      };
    
    $std_dbh= undef;
  }

sub check_dbi_handle
  { my($dbh)= @_;
  
    # test wether to use internal standard database handle
    if (!defined $dbh)
      { $dbh= $std_dbh; }
    elsif ($dbh eq "") 
      { $dbh= $std_dbh; };
    if (ref($dbh) !~ /^DBI::/)
      { dberror($mod,'check_dbi_handle',__LINE__,
                "error: parameter is not a DBI handle!"); 
        return;
      };
    if (!defined $dbh)
      { dberror($mod,'check_dbi_handle',__LINE__,
                "standard dbi handle not initialized!"); 
        return;
      };
    return($dbh);
  }

1;

# Below is the short of documentation of the module.

=head1 NAME

dbdrv - a Perl module for low-level utility function to access 
an SQL database.

=head1 SYNOPSIS

  use dbdrv;

  dbdrv::load("Oracle"); # load oracle driver
  
  my @all_tables= dbdrv::all_tables();
  

=head1 DESCRIPTION

=head2 Preface

This module contains low-level functions for accessing an SQL database
which are not part of the standard DBD database drivers. Examples
of such functions are getting a list of all tables, 
getting a list of all views or getting the primary key(s) of a 
certain table. 

Since the implementation of these functions is different for each database,
the module dbdrv provides a unified interface, just like DBI does.
And just like DBI knows driver modules like DBD::Oracle, this module
has driver modules, too, for example dbdrv:oci. 

=head2 initialization and database drivers

The module should I<always> be initialized with a call of 
C<dbdrv::load>. Before the call of this function, the other functions
to access the database are not defined. This is how C<dbdrv::load> is 
called:

  dbdrv::load($driver_name); 
  
Known driver names are:

=over 4

=item oracle

This loads the driver for the oracle database (dbdrv_oci.pm).

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

  if (dbdrv::check_existence($dbh,$table_name))
    { print "table exists\n"; }
  else
    { print "table does not exist\n"; }
  
This function performs a simple check wether a table exists. 
C<$dbh> is the database handle, C<$table_name> the name of the table.
The function returns C<1> when the table exists and C<undef> when not.

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
