# this is not a real perl-package
# it is loaded via "do" into dbdrv.pm !!

use strict;
our %sql_aliases;
our $sql_trace;
our $r_db_objects;


my $mod_l= "dbdrv_lite";

my %curr_schemas;

my %possible_objects; # names without schema-name
my %object2schemaobject;
my $view_dependencies_examined=0;

my %db_object_types = (TABLE=>'T', VIEW=>'V', 'SYSTEM TABLE'=>'S',
                       PROCEDURE=>undef,
                       FUNCTION=>undef, 
		       SEQUENCE=>undef
		       # undef: SEQCENCE type is known, but there
		       # are no sequences
		      );

my %typemap= (
    
      # numeric types:
              smallint           => 'number',   # documented, found
              integer            => 'number',   # documented, found
              bigint             => 'number',   # documented, found
              decimal            => 'number',   # documented
              numeric            => 'number',   # documented, found
              real               => 'number',   # documented, found
              'double precision' => 'number',   # documented
              serial             => 'number',   # documented
              bigserial          => 'number',   # documented

      # monetary types
              money              => 'number',   # documented 

      # character types
              'character varying'=> 'string',   # documented, found
              character          => 'string',   # documented
              '"char"'           => 'string',   # documented, found
              text               => 'string',   # documented, found
                 
      # binary data types
              bytea              => 'number',   # documented, found

      # date/time types
              'timestamp'        => 'string',   # documented
              'timestamp without time zone'
                                 => 'string',   # documented
              'timestamp with time zone'
                                 => 'string',   # documented
              interval           => 'string',   # documented
              date               => 'string',   # documented, found
              'time'             => 'string',   # documented
              'time without time zone'
                                 => 'string',   # documented
              'time with time zone'
                                 => 'string',   # documented

      # boolean type
              boolean            => 'number',   # documented, found

      # geometric types
              point              => undef,      # documented
              line               => undef,      # documented
              lseg               => undef,      # documented
              box                => undef,      # documented
              path               => undef,      # documented
              polygon            => undef,      # documented
              circle             => undef,      # documented

      # network address types
              cidr               => undef,      # documented
              inet               => undef,      # documented
              macaddr            => undef,      # documented

      # bit string types
              bit                => undef,      # documented
              'bit varying'      => undef,      # documented

      # arrays
              ARRAY              => undef,      # documented, found

      # object identifier types
              oid                => 'number',   # documented, found
              regproc            => 'number',   # documented, found
              regprocedure       => undef,      # documented
              regoper            => undef,      # documented
              regoperator        => undef,      # documented
              regclass           => undef,      # documented
              regtype            => undef,      # documented
      
      # pdeudo types

              any                => undef,      # documented     
              anyarray           => undef,      # documented , found      
              anyelement         => undef,      # documented     
              cstring            => undef,      # documented     
              internal           => undef,      # documented     
              language_handler   => undef,      # documented     
              record             => undef,      # documented     
              trigger            => undef,      # documented     
              void               => undef,      # documented     
              opaque             => undef,      # documented     

      # types that were found but not documented (??)
      
              abstime            => undef,      # found
              int2vector         => undef,      # found
              name               => undef,      # found
              oidvector          => undef,      # found
              xid                => undef,      # found
          );


our $sql_capabilities;

$sql_capabilities->{"generic"}=
  {
    "alias"=>
      {
        "objects"=>      "SELECT object_name, status, object_type, owner \
                                    FROM sys.all_objects \
                                    WHERE object_name LIKE UPPER('##1##') AND\
                                    NOT object_type = 'SYNONYM'",
        "describe"=>     "SELECT column_name, table_name, owner, data_type, \
                                        data_length, data_precision, data_scale, nullable, \
                                        column_id, default_length, data_default, num_distinct, \
                                        low_value, high_value
                                    FROM all_tab_columns \
                                    WHERE table_name = UPPER('##1##') \
                                    ORDER BY column_id",
        "lookup"=>        "SELECT object_name, object_owner, object_type \
                                    FROM all_objects
                                    WHERE object_name like '##1##''",
      },
  };
$sql_capabilities->{"table"}=
  {
    "alias"=>
      {
        "depends" =>    "SELECT o.object_id, o.created, o.status, o.object_name, o.owner \
                                        FROM all_dependencies d, all_objects o \
                                        WHERE d.name = UPPER('##1##') AND \
                                            d.referenced_owner = o.owner AND \
                                            d.referenced_name = o.object_name \
                                        ORDER BY o.object_name",
        "triggertext" =>       "SELECT trigger_type, triggering_event, trigger_body \
                                            FROM dba_triggers \
                                            WHERE trigger_name = UPPER('##1##')",
        "constraints" =>    "SELECT constraint_name, table_name, owner,constraint_type, \
                                                r_owner, r_constraint_name, search_condition \
                                            FROM all_constraints \
                                            WHERE table_name = UPPER('##1##') \
                                            ORDER BY constraint_name, r_owner, r_constraint_name",
        "triggers" =>           "SELECT DISTINCT trigger_name, owner, table_owner, table_name, \
                                                trigger_type, triggering_event, status, referencing_names \
                                            FROM dba_triggers \
                                            WHERE table_name = UPPER('##1##') \
                                            ORDER BY trigger_name, table_owner, table_name",
      },
  };
$sql_capabilities->{"view"}=
  {
    "alias"=>
      {
        "dependants" =>     "SELECT o.object_id, o.created, o.status, o.object_type, \
                                                o.object_name, o.owner \
                                            FROM sys.all_dependencies d, sys.all_objects o \
                                            WHERE d.referenced_name = UPPER('##1##') AND\
                                                d.owner = o.owner AND \
                                                d.name = o.object_name AND \
                                                o.object_type = 'VIEW' ORDER BY o.owner, o.object_name",
        "viewtext" =>           "SELECT text \
                                                FROM all_views \
                                                WHERE view_name = UPPER('##1##')",
      },
  };


our %sql_aliases;

foreach my $cap_aliases (keys %$sql_capabilities)
  {
    my $cap_entry =$sql_capabilities->{$cap_aliases}->{alias};
    if (defined($cap_entry))
      {
        foreach my $aliasname ( keys %$cap_entry )
          { $sql_aliases{$aliasname} = $cap_entry->{$aliasname}; }
      }
  }

# select * from pg_tables; shows all tables, including the
# system tables

# select schemaname, viewname, viewowner from pg_views;
# shows interesting views

#=============================================================
# name conversions, name spaces, schemas 
#=============================================================

sub real_name
# EXPORTED 
# resolves a given table-name
# returns: full-qualified-name,owner,unqualified-name,schema
# returns the table-name and the table-owner
# NOTE: user-name is not the owner of the table but the user
# that has logged in
# the user_name is not evaluated, just returned
  { my($dbh,$user_name,$object_name)= @_;
  
    return($object_name,$user_name,$object_name);
  }

sub canonify_name
# EXPORTED 
# returns a "nice" name, here:
# removes the schema-name if its one of the current schemas
  { my($dbh,$user_name,$object_name,$object_owner)= @_;

    return($object_name);
  }

#=============================================================
# object catalogs
#=============================================================

#-------------------------------------------------------------
# Object dictionary (INTERNAL)
#-------------------------------------------------------------

sub load_object_dict
# INTERNAL to dbdrv_pg!!!
# WRITES TO GLOBAL VARIABLES:
#  $r_db_objects and %possible_objects
# returns a hash-reference: object-name -> [Type,creation-command]
#  type is either "T" or "V" or "P"
  { my($dbh)= @_;
    my %lt_objs;

    return if (defined $r_db_objects);
    
    $dbh= check_dbi_handle($dbh);
    return if (!defined $dbh);

    $r_db_objects= \%lt_objs;

    my $sth= $dbh->table_info("","","%");
    if (!defined $sth)
      { dberror($mod_l,'load_object_dict',__LINE__,
                "table_info failed, errcode:\n$DBI::errstr");
        return;
      };
    my $data = $sth->fetchall_arrayref; 
    if (!defined $data)
      { dberror($mod_l,'load_object_dict',__LINE__,
                "fetchall_arrayref failed, errcode:\n$DBI::errstr");
        return;
      };
    die "assertion" if (ref($data) ne 'ARRAY');
    
    foreach my $elm (@$data)
      { # CATALOG
        # SCHEMA
	# NAME
	# TYPE ('SYSTEM TABLE''TABLE'"VIEW")
	# REMARKS
	# CREATION-Command
	my $t= $db_object_types{$elm->[3]};
	if (!defined $t)
	  { dbwarn($mod_l,'load_object_dict',__LINE__,
               "object type $elm->[3] is unknown");
            next;       
          };
	$lt_objs{$elm->[2]}= [$t,$elm->[5]];
      };

    return(\%lt_objs);
  }

#-------------------------------------------------------------
# get catalog of accessible objects
#-------------------------------------------------------------

sub accessible_objects
# EXPORTED 
  { my($dbh,$user_name,$types,$access)= @_;
#    my %known_types= (table => 'T', view => 'V');
    my %known_acc  = map { $_ =>1 } qw( user public );
    my %types;
    my %access;


    $dbh= check_dbi_handle($dbh);
    return if (!defined $dbh);

    if (!defined $types)
      { %types= (T=>1); }
    else
      { $types= uc($types);
        my @types= split(",",$types);
        my $c;
	foreach my $t (@types)
          { 
	    if (!exists $db_object_types{$t})
              { dberror($mod_l,'accessible_objects',__LINE__,
                    "unknown object type: $t");
                return;
              };
            $c= type_to_typechar($t);
	    $types{$c}= 1 if (defined $c); 
          };
      };

    load_object_dict($dbh,$user_name);
    my @keys= grep { exists $types{$r_db_objects->{$_}->[0]} } 
                     keys %$r_db_objects;


#print Dumper(\%types);


    #warn join("|",@result) . "\n";

#@@@@@@@@@@@@@@@canonify
    my @result= 
         map { canonify_name($dbh,$user_name,$_,$user_name,) 
             } @keys; 
    # remove "schemaname" if possible

#print Dumper(\@result);

    return(sort @result);
  }

#=============================================================
# object type and existence
#=============================================================

#-------------------------------------------------------------
# check existence
#-------------------------------------------------------------

sub check_existence
  { my($dbh,$table_name,$user_name)= @_;

    my($obj)= check_exists($dbh,$user_name,$table_name);
    return(defined $obj);
  }

# INTERNAL-------------------

sub check_exists  
# INTERNAL to dbdrv_pg!!!
  { my($dbh,$user_name,$table_name)= @_;
  
    $table_name= lc($table_name);

    $dbh= check_dbi_handle($dbh);
    return if (!defined $dbh);

    load_object_dict($dbh,$user_name);
    
    return if (!exists $r_db_objects->{$table_name});
    
    # return table-name 
    return( $table_name );
  }

#-------------------------------------------------------------
# object-type 
#-------------------------------------------------------------

sub object_is_table
# EXPORTED function
# return 1 when it is a table
  { my($dbh,$table_name,$user_name)= @_;

    $table_name= lc($table_name);

    $dbh= check_dbi_handle($dbh);
    return if (!defined $dbh);

    load_object_dict($dbh,$user_name);

#print Dumper($r_db_objects);

    my $data= $r_db_objects->{$table_name};
    if (!defined $data)
      { dbwarn($mod_l,'object_is_table',__LINE__,
               "object $table_name is unknown");
        return;       
      };

    return($data->[0] eq 'T');
  }

#=============================================================
# columns
#=============================================================

#-------------------------------------------------------------
# column-types 
#-------------------------------------------------------------
sub get_simple_column_types
# EXPORTED
# returns for each column:
# 'number', 'string' or undef 
  { my($dbh,$sth,$table_name)= @_;

    # the simple method described in DBI manpage doesn't work 
    # some special datatypes of postgres are not identified correct,
    # so we have to determine the column-types manually here

    # see also the definition of "%typemap" at the top of this file
  
    $dbh= check_dbi_handle($dbh);
    return if (!defined $dbh);
          
    my($table) = dbdrv::check_exists($dbh,"",$table_name);

    if (!defined $table)
      { dberror($mod_l,'get_simple_column_types',__LINE__,
                "table $table does not exist");
        return;
      };

    my $r_types= $sth->{TYPE};
    
    return( map{ $typemap{lc($_)} } @$r_types );

  }

sub column_properties
# EXPORTED
# need handle, table_name, table_owner
# read the type, length, precision, null-condition of a check constraint
  { my($dbh, $user_name, $table_name)= @_;

    $dbh= check_dbi_handle($dbh);
    return if (!defined $dbh);

    my($table) = dbdrv::check_exists($dbh,"",$table_name);

    if (!defined $table)
      { dberror($mod_l,'get_simple_column_types',__LINE__,
                "table $table does not exist");
        return;
      };
    
    my $sth= $dbh->prepare("select * from quotes");  
    my $r_colnames= $sth->{NAME_lc};
    my $r_coltypes= $sth->{TYPE};  

    my %ret;
    for(my $i=0; $i<= $#$r_colnames; $i++)
      {
        $ret{uc($r_colnames->[$i])} = { type=>$r_coltypes->[$i]      
                                      };
      };
    return( \%ret );
  }

#=============================================================
# relations: primary, foreign, resident keys
#=============================================================
  
#-------------------------------------------------------------
# primary key
#-------------------------------------------------------------

sub primary_keys
# EXPORTED function
# returns the one primary key or the list of columns
# that form the primary key
# column-names are in UPPER CASE
  { my($dbh,$user_name,$table_name)= @_;

    $dbh= check_dbi_handle($dbh);
    return if (!defined $dbh);

    my($table) = dbdrv::check_exists($dbh,$user_name,$table_name);
    if (!defined $table) # assertion !
      { dbwarn($mod_l,'primary_keys',__LINE__,
               "table $table_name not present or accessible");
        return;       
      };

    return( $dbh->primary_key("","",$table) );
  }
  
#-------------------------------------------------------------
# foreign-key 
#-------------------------------------------------------------

sub foreign_keys
# EXPORTED function
# column-names are in UPPER CASE
  { my($dbh,$user_name,$table_name)= @_;
    return;
  }

#-------------------------------------------------------------
# resident-key
#-------------------------------------------------------------

sub resident_keys
# EXPORTED function
# the opposite of foreign keys,
# find where the primary key of this table is used as foreign key
# column-names are in UPPER CASE
  { my($dbh,$user_name,$table_name)= @_;
    return;
  }

#=============================================================
# relations: dependent and referenced objects 
#=============================================================

#-------------------------------------------------------------
# object-dependencies
#-------------------------------------------------------------

sub object_dependencies
# EXPORTED
# read the owner, name and of dependend objects
# type is either "TABLE" or "VIEW"
  { my($dbh,$table_name,$user_name)= @_;
    return;
  }  

# INTERNAL-------------------

#-------------------------------------------------------------
# object-references
#-------------------------------------------------------------

sub object_references
# EXPORTED
# read the owner, name  and of referenced objects
  { my($dbh,$table_name,$user_name)= @_;
    return;
  }

#-------------------------------------------------------------
# object-addicts
#-------------------------------------------------------------

sub object_addicts
# EXPORTED
# read all constraints and triggers for the given object
  { my($dbh,$table_name,$user_name)= @_;

    return();
  }

#=============================================================
# definitions of views, triggers and scripts
#=============================================================

#-------------------------------------------------------------
# read viewtext
#-------------------------------------------------------------

sub read_viewtext
# EXPORTED
# read the text of a view
  { my($dbh,$table_name,$user_name)= @_;
    return;
  }

#-------------------------------------------------------------
# read checktext
#-------------------------------------------------------------

sub read_checktext
# EXPORTED
# read the name, condition of a check constraint
  { my($dbh,$constraint_name,$table_owner)= @_;

    return;
  }

#-------------------------------------------------------------
# read triggertext
#-------------------------------------------------------------
  
sub read_triggertext
# EXPORTED
# reads the name, type, event, referer, clause, status
# body and description of a trigger
  { my($dbh,$trigger_name,$table_owner)= @_;

    return;
  }

#-------------------------------------------------------------
# read scripttext
#-------------------------------------------------------------

sub read_scripttext
# EXPORTED
# read the name, type, text of a script
  { my($dbh,$constraint_name,$table_owner)= @_;

    return;
  }

#=============================================================
# misc
#=============================================================

#-------------------------------------------------------------
# misc internal functions
#-------------------------------------------------------------

sub type_to_typechar
# internal
  { my($type)= @_;
    return( $db_object_types{uc($type)});
  }

#-------------------------------------------------------------
# online-help
#-------------------------------------------------------------

sub get_help_topic
# EXPORTED
  { my($dbh)= @_;
    return;
  }

#-------------------------------------------------------------
# string for row limitation
#-------------------------------------------------------------

sub query_limit_rows_str
# EXPORTED
# limit number of returned rows in a query
  { my($no)= @_;
    return("LIMIT $no","add_before_where");
  }

#-------------------------------------------------------------
# misc internal functions
#-------------------------------------------------------------


1;

__END__

perl -e 'use lib "."; use dbdrv; $dbdrv::sql_trace=1; 
         dbdrv::load("Postgresql");
         dbdrv::connect_database("DBI:Pg:dbname=gpdb","pfeiffer","");
         my @a= dbdrv::primary_keys("","pfeiffer","cities","");


perl -e 'use lib "."; use Data::Dumper; use dbdrv; dbdrv::load("Postgresql");
         dbdrv::connect_database("DBI:Pg:dbname=gpdb","pfeiffer",""); 
         my $r= dbdrv::foreign_keys("","pfeiffer","weather2",""); 
         dbdrv::disconnect_database(); print Dumper($r); '

perl -e 'use lib "."; use Data::Dumper; use dbdrv; dbdrv::load("Postgresql");
         dbdrv::connect_database("DBI:Pg:dbname=gpdb","pfeiffer",""); 
         my $r= dbdrv::view_dependencies("","pfeiffer"); 
         dbdrv::disconnect_database(); '


perl -e 'use lib "."; use Data::Dumper; use dbdrv; dbdrv::load("Postgresql");
         dbdrv::connect_database("DBI:Pg:dbname=gpdb","pfeiffer","");
         my $r= dbdrv::view_dependencies("","pfeiffer");
         dbdrv::disconnect_database();'
