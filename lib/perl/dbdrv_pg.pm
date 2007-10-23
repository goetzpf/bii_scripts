
# This software is copyrighted by the BERLINER SPEICHERRING
# GESELLSCHAFT FUER SYNCHROTRONSTRAHLUNG M.B.H., BERLIN, GERMANY.
# The following terms apply to all files associated with the software.
# 
# BESSY hereby grants permission to use, copy and modify this
# software and its documentation for non-commercial, educational or
# research purposes provided that existing copyright notices are
# retained in all copies.
# 
# The receiver of the software provides BESSY with all enhancements, 
# including complete translations, made by the receiver.
# 
# IN NO EVENT SHALL BESSY BE LIABLE TO ANY PARTY FOR DIRECT, INDIRECT,
# SPECIAL, INCIDENTAL OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE
# OF THIS SOFTWARE, ITS DOCUMENTATION OR ANY DERIVATIVES THEREOF, EVEN 
# IF BESSY HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
# 
# BESSY SPECIFICALLY DISCLAIMS ANY WARRANTIES, INCLUDING, BUT NOT LIMITED
# TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
# PURPOSE, AND NON-INFRINGEMENT. THIS SOFTWARE IS PROVIDED ON AN "AS IS"
# BASIS, AND BESSY HAS NO OBLIGATION TO PROVIDE MAINTENANCE, SUPPORT,
# UPDATES, ENHANCEMENTS OR MODIFICATIONS.


# this is not a real perl-package
# it is loaded via "do" into dbdrv.pm !!

use strict;
our %sql_aliases;
our $sql_trace;
our $r_db_objects;


my $mod_l= "dbdrv_pg";

my %curr_schemas;

my %possible_objects; # names without schema-name
my %object2schemaobject;
my $view_dependencies_examined=0;

my %db_object_types = (TABLE=>'T', VIEW=>'V', PROCEDURE=>'P',
                       FUNCTION=>'P', 
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

    $user_name  = lc($user_name);
    $object_name= lc($object_name);

    $dbh= check_dbi_handle($dbh);
    return if (!defined $dbh);

    load_object_dict($dbh,$user_name);

    my $full_object_name= add_schema($dbh,$object_name);

    my $data= $r_db_objects->{$full_object_name};

    return if (!defined $data); # not in list of objects

    my($schema,$short_object_name)= split(/\./,$full_object_name);
    die "assertion!" if (!defined $short_object_name);

    # $data->[1] is the object-owner
    return( $full_object_name, $data->[1],$short_object_name,$schema );
  }

sub canonify_name
# EXPORTED 
# returns a "nice" name, here:
# removes the schema-name if its one of the current schemas
  { my($dbh,$user_name,$object_name,$object_owner)= @_;

    $object_name= lc($object_name);

    if ($object_name !~ /\./)
      { return($object_name); };

    my %curr_schemas= current_schemas($dbh);

    my ($schema,$obj)= split(/\./,$object_name); 
    if (!exists($curr_schemas{$schema}))
      { return($object_name); };

    return($obj);
  }

# INTERNAL-------------------

sub current_schemas
# INTERNAL to dbdrv_pg!!!
# returns a hash with the current schemas
# (default-schemas for the current user)
  { my($dbh)= @_;

    if (%curr_schemas)
      { return(%curr_schemas); };

    $dbh= check_dbi_handle($dbh);
    return if (!defined $dbh);

    # array_to_string is needed since DBD:Pg cannot
    # handle arrays yet. I currently get a segmentation fault... :-(
    my $SQL= "select array_to_string(current_schemas,'|') " .
              "from current_schemas(true);";

    my $res= $dbh->selectall_arrayref($SQL);

    if (!defined $res)
      { dberror($mod_l,'current_schemas',__LINE__,
                "selectall_arrayref failed, errcode:\n$DBI::errstr");
        return;
      };

    return if ($#$res<0);

    my @schemas= split(/\|/,$res->[0]->[0]);

    #print Dumper(\@schemas);

    %curr_schemas= map { $_=>1 } @schemas;
    return(%curr_schemas);
  }

sub schemas_for_object
# INTERNAL to dbdrv_pg!!!
# get the one schema or a list of possible schemas 
# for a given object(table or view)
  { my($dbh,$object_name)= @_; 
    my @schemas;

    $dbh= check_dbi_handle($dbh);
    return if (!defined $dbh);

    my $SQL= "SELECT c.relname, n.nspname " .
             "FROM pg_class c, pg_namespace n " .
             "WHERE c.relname='$object_name' AND " .
                   "c.relnamespace=n.oid";


    #returns:
    #      relname       |      nspname
    # -------------------+--------------------
    #  table_constraints | information_schema    

    my $res= $dbh->selectall_arrayref($SQL);

    if (!defined $res)
      { dberror($mod_l,'schemas_for_object',__LINE__,
                "selectall_arrayref failed, errcode:\n$DBI::errstr");
        return;
      };

    return if ($#$res<0);

    foreach my $r_line (@$res)
      { push @schemas, $r_line->[1]; };

    return(@schemas);
  }

sub add_schema  
# INTERNAL to dbdrv_pg!!!
# add schema-name prefix to an object_name
  { my($dbh,$object_name)= @_;
    my $obj;

    $object_name= lc($object_name);

    return($object_name) if ($object_name =~ /\./);

    $obj= $object2schemaobject{$object_name};
    return($obj) if (defined $obj);

    # the object is unknown, just return the string
    if (!exists $possible_objects{$object_name})
      { return($object_name) };

    my @schemas= schemas_for_object($dbh,$object_name);

    if ($#schemas<0)
      { dbwarn($mod_l,'add_schema',__LINE__,
               "no schemaname found for $object_name");
      }
    elsif ($#schemas>0)
      { dbwarn($mod_l,'add_schema',__LINE__,
               "more than one schemaname found for $object_name");
      }
    else
      { $obj= $schemas[0] . "." .$object_name; 
      };
    $object2schemaobject{$object_name}= $obj;  
    return($obj);
  };


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
# returns a hash-reference: object-name -> [Type,owner,readable-flag]
#  type is either "T" or "V" or "P"
  { my($dbh)= @_;

    return if (defined $r_db_objects);

    $dbh= check_dbi_handle($dbh);
    return if (!defined $dbh);

    my %pg_objs;
    $r_db_objects= \%pg_objs;
    my $sql;

    $sql= "SELECT schemaname,tablename,tableowner, " .
            "has_table_privilege(schemaname || '.' || tablename,'select') " . 
                 "AS readable " .
          "FROM pg_tables";
#returns:    
#     schemaname     |        tablename        | tableowner | readable
#--------------------+-------------------------+------------+----------
# information_schema | sql_features            | postgres   | t

     sql_trace($sql) if ($sql_trace);

    my $res= $dbh->selectall_arrayref($sql);

    if (!defined $res)
      { dberror($mod_l,'load_object_dict',__LINE__,
                "selectall_arrayref failed, errcode:\n$DBI::errstr");
        return;
      };
    my $n;
    foreach my $line (@$res)
      { $n= $line->[0] . '.' . $line->[1];
        # [type, owner, readable]
        $pg_objs{$n}= ['T', $line->[2], $line->[3] ];
        $possible_objects{$line->[1]}=1;
      };

    $sql= "SELECT schemaname,viewname,viewowner, " .
            "has_table_privilege(schemaname || '.' || viewname,'select') " . 
                 "AS readable " .
          "FROM pg_views";
    sql_trace($sql) if ($sql_trace);

    my $res= $dbh->selectall_arrayref($sql);

    if (!defined $res)
      { dberror($mod_l,'load_object_dict',__LINE__,
                "selectall_arrayref failed, errcode:\n$DBI::errstr");
        return;
      };
    foreach my $line (@$res)
      { $n= $line->[0] . '.' . $line->[1];
        # [type, owner, readable]
        $pg_objs{$n}= ['V', $line->[2], $line->[3] ];
        $possible_objects{$line->[1]}=1;
      };

    $sql= "SELECT n.nspname, p.proname, u.usename, " . 
                  "has_function_privilege(p.oid, \'EXECUTE\') AS priv " .
          "FROM pg_proc p, pg_namespace n, pg_user u " .
          "WHERE p.pronamespace=n.oid AND p.proowner=u.usesysid";

    sql_trace($sql) if ($sql_trace);

    my $res= $dbh->selectall_arrayref($sql);

    if (!defined $res)
      { dberror($mod_l,'load_object_dict',__LINE__,
                "selectall_arrayref failed, errcode:\n$DBI::errstr");
        return;
      };

    foreach my $line (@$res)
      { $n= $line->[0] . '.' . $line->[1];
        # [type, owner, executable]
        $pg_objs{$n}= ['P', $line->[2], $line->[3] ];
        $possible_objects{$line->[1]}=1;
      };

    return(\%pg_objs);
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

    if (!defined $access)
      { %access= ("public" => 1); }
    else
      { $access= lc($access);
        %access= map { $_ => 1} split(",",$access);
        foreach my $t (keys %access)
          { if (!exists $known_acc{$t})
              { dberror($mod_l,'accessible_objects',__LINE__,
                    "unknown object access type: $t");
                return;
              };
          };
      };

    my @result;

    if (exists $access{public})
      { # filter all objects that are readable
        push @result,
             grep { ($r_db_objects->{$_}->[2]) &&
                    ($r_db_objects->{$_}->[1] ne $user_name) 
                  } @keys;
      };

    if (exists $access{user})
      { push @result,
             grep { $r_db_objects->{$_}->[1] eq $user_name } @keys;
      };

    #warn join("|",@result) . "\n";

#@@@@@@@@@@@@@@@canonify
    @result= 
         map { canonify_name($dbh,$user_name,$_,$r_db_objects->{$_}->[1]) 
             } @result; 
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

    my($schema,$obj)= check_exists($dbh,$user_name,$table_name);
    return(defined $schema);
  }

# INTERNAL-------------------

sub check_exists  
# INTERNAL to dbdrv_pg!!!
  { my($dbh,$user_name,$table_name)= @_;

    $table_name= lc($table_name);

    $dbh= check_dbi_handle($dbh);
    return if (!defined $dbh);

    load_object_dict($dbh,$user_name);

    $table_name= add_schema($dbh,$table_name);

    return if (!exists $r_db_objects->{$table_name});

    # return schema and table-name separate:
    return( split(/\./,$table_name) );
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
    $table_name= add_schema($dbh,$table_name);

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

    my($schema,$table) = dbdrv::check_exists($dbh,"",$table_name);

    if (!defined $table)
      { dberror($mod_l,'get_simple_column_types',__LINE__,
                "table $table does not exist");
        return;
      };

    my $SQL= "SELECT column_name,ordinal_position,data_type " .
             "FROM information_schema.columns " .
             "WHERE table_name='$table' AND " .
                   "table_schema='$schema'" .
             "ORDER BY ordinal_position";

    # returns something like:
    # column_name | ordinal_position |     data_type
    #-------------+------------------+-------------------
    # city        |                1 | character varying
    # temp_lo     |                2 | integer
    # temp_hi     |                3 | integer
    # prcp        |                4 | real
    # date        |                5 | date



    sql_trace($SQL) if ($sql_trace);

    my $res=
      $dbh->selectall_arrayref($SQL);

#print Dumper($res);

    if (!defined $res)
      { dberror($mod_l,'get_simple_column_types',__LINE__,
                "selectall_arrayref failed, errcode:\n$DBI::errstr");
        return;
      };

    my @x;
    my $t;
    foreach my $r_line (@$res)
      { $t= $typemap{$r_line->[2]};
        if (!defined $t)
          { warn "internal error (assertion): col-type $t is unknown";
          };
        push @x, $t;
      };    

    return(@x);
  }

sub column_properties
# EXPORTED
# need handle, table_name, table_owner
# read the type, length, precision, null-condition of a check constraint
  { my($dbh, $user_name, $table_name)= @_;

    $dbh= check_dbi_handle($dbh);
    return if (!defined $dbh);

    my($schema,$table) = dbdrv::check_exists($dbh,"",$table_name);

    if (!defined $table)
      { dberror($mod_l,'get_simple_column_types',__LINE__,
                "table $table does not exist");
        return;
      };

    my $SQL= "SELECT column_name,ordinal_position,data_type, " .
                     "character_maximum_length, numeric_precision, " .
                     "is_nullable, column_default " .
             "FROM information_schema.columns " .
             "WHERE table_name='$table' AND " .
                   "table_schema='$schema'" .
             "ORDER BY ordinal_position";

  # returns something like:

# column_name | ordinal_position |     data_type     | character_maximum_length | numeric_precision | is_nullable | column_default
#-------------+------------------+-------------------+--------------------------+-------------------+-------------+----------------
# city        |                1 | character varying |                       80 |                   | YES         |
# temp_lo     |                2 | integer           |                          |                32 | YES         |
# temp_hi     |                3 | integer           |                          |                32 | YES         |
# prcp        |                4 | real              |                          |                24 | YES         |
# date        |                5 | date              |                          |                   | YES         |

    sql_trace($SQL) if ($sql_trace);

    my $res=
      $dbh->selectall_arrayref($SQL);

#print Dumper($res);

    if (!defined $res)
      { dberror($mod_l,'column_properties',__LINE__,
                "selectall_arrayref failed, errcode:\n$DBI::errstr");
        return;
      };

    my %ret;
    foreach my $line ( @$res )
      {
        $ret{uc($line->[0])} = { type=>$line->[2],          
                                 length=>$line->[3],    
                                 precision=>$line->[4], 
                                 null=>$line->[5],          
                                 default=>$line->[6],   
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

    my($schema,$table) = dbdrv::check_exists($dbh,$user_name,$table_name);
    if (!defined $table) # assertion !
      { dbwarn($mod_l,'primary_keys',__LINE__,
               "table $table_name not present or accessible");
        return;       
      };

    # a sub-expression to the the table-oid for a given table-name and
    # schema:
    my $table_oid= "(SELECT c.oid FROM pg_class c, pg_namespace n " .
                    "WHERE c.relname='$table' AND " .
                          "n.nspname='$schema' AND c.relnamespace=n.oid)";

    # table-owner is not taken into account here...
    my $SQL= 

             "SELECT pg_get_constraintdef(oid) " .
             "FROM pg_constraint " . 
             "WHERE contype = 'p' AND " .
                    "conrelid=$table_oid";

    # returns something like:
    # pg_get_constraintdef
    # ----------------------
    # PRIMARY KEY (city)

    sql_trace($SQL) if ($sql_trace);

    my $res=
      $dbh->selectall_arrayref($SQL);

    if (!defined $res)
      { dberror($mod_l,'db_get_primary_keys',__LINE__,
                "selectall_arrayref failed, errcode:\n$DBI::errstr");
        return;
      };

    # NOTE: in some tables, only the combination of several rows is
    # the primary key, in this case, the SQL statement above returns
    # a line like: PRIMARY KEY (a, c)

    my $line= $res->[0]->[0];

    return if ($line eq "");

#warn "line:$line\n";
    if ($line!~ /^\s*PRIMARY KEY\s*\(([\w\s,]+)\)/)
      { dberror($mod_l,'primary_keys',__LINE__,
                "line not understood:\n$line");
        return;
      };
    my $pk= uc($1);  
    if ($pk!~ /,/) # only a single primary key
      { return( $pk ); };

    my @pk_list= split(/[\s,]+/,$pk);
    return(@pk_list);

  }

#-------------------------------------------------------------
# foreign-key 
#-------------------------------------------------------------

sub foreign_keys
# EXPORTED function
# column-names are in UPPER CASE
  { my($dbh,$user_name,$table_name)= @_;
    my($full_name,$table_owner,$table,$schema);

    $dbh= check_dbi_handle($dbh);
    return if (!defined $dbh);

    # postgresql stores table-names in lower-case
    $table_name= lc($table_name);

    ($full_name,$table_owner,$table,$schema)=
       real_name($dbh,$user_name,$table_name);

    if (!defined $table) # assertion !
      { dbwarn($mod_l,'foreign_keys',__LINE__,
               "table $table_name not present or accessible");
        return;       
      };

    # a sub-expression to the the table-oid for a given table-name and
    # schema:
    my $table_oid= "(SELECT c.oid from pg_class c, pg_namespace n " .
                    "WHERE c.relname='$table' AND " .
                          "n.nspname='$schema' AND c.relnamespace=n.oid)";

    my $SQL= 
             "SELECT pg_get_constraintdef(oid) " .
             "FROM pg_constraint " . 
             "WHERE contype = 'f' AND " .
                    "conrelid=$table_oid";


    sql_trace($SQL) if ($sql_trace);
    my $res=
      $dbh->selectall_arrayref($SQL);
    # gives:
    # returns for example:
    #             pg_get_constraintdef
    #   ---------------------------------------------
    #   FOREIGN KEY (city1) REFERENCES cities(city)
    #   FOREIGN KEY (city2) REFERENCES cities(city)

    if (!defined $res)
      { dberror($mod_l,'db_get_foreign_keys',__LINE__,
                "selectall_arrayref failed, errcode:\n$DBI::errstr");
        return;
      };

    my %foreign_keys;
    # build a hash,
    # col_name => [foreign_table,foreign_column,foreign_table_owner]
    foreach my $r_line (@$res)
      { 
        if ($r_line->[0]!~ /^\s*FOREIGN KEY\s*\((\w+)\)\s*REFERENCES\s*(\w+)\s*\((\w+)\)/)
          { dberror($mod_l,'foreign_keys',__LINE__,
                    "line not understood:\n$$r_line");
            return;
          };
        $foreign_keys{uc($1)}= [ $2, uc($3), $table_owner];
        # a bit of a fake here, the table-owner 
        # is added without further check

      };

    return( \%foreign_keys);
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
    my($full_name,$table_owner,$table,$schema);

    $dbh= check_dbi_handle($dbh);
    return if (!defined $dbh);

    # postgresql stores table-names in lower-case
    $table_name= lc($table_name);

    ($full_name,$table_owner,$table,$schema)=
       real_name($dbh,$user_name,$table_name);

    if (!defined $table) # assertion !
      { dbwarn($mod_l,'resident_keys',__LINE__,
               "table $table_name not present or accessible");
        return;       
      };

    # a sub-expression to the the table-oid for a given table-name and
    # schema:
    my $table_oid= "(SELECT c.oid from pg_class c, pg_namespace n " .
                    "WHERE c.relname='$table' AND " .
                          "n.nspname='$schema' AND c.relnamespace=n.oid)";

    my $SQL= 
              "SELECT c.relname, n.nspname, pg_get_constraintdef(r.oid) " .
              "FROM pg_constraint r, pg_class c, pg_namespace n " .
              "WHERE r.contype='f' AND " .
                    "c.oid=conrelid AND " .
                    "n.oid=c.relnamespace AND " .
                    "r.confrelid=$table_oid";

    sql_trace($SQL) if ($sql_trace);
    my $res=
      $dbh->selectall_arrayref($SQL);

    # returns (example):
    # relname  | nspname |            pg_get_constraintdef
    #----------+---------+---------------------------------------------
    # weather2 | public  | FOREIGN KEY (city2) REFERENCES cities(city)
    # weather2 | public  | FOREIGN KEY (city1) REFERENCES cities(city)
    # weather  | public  | FOREIGN KEY (city) REFERENCES cities(city)

    if (!defined $res)
      { dberror($mod_l,'resident_keys',__LINE__,
                "selectall_arrayref failed, errcode:\n$DBI::errstr");
        return;
      };

    if ($#$res < 0)
      { # no resident keys found, just return "undef"
        return;
      };

    # build a hash,
    # col_name => [ [resident_table1,resident_column1,resident_owner],
    #               [resident_table2,resident_column2,resident_owner],
    #                    ...
    #             ]
    #      resident_table may occur more than once

    my %resident_keys;
    foreach my $r_line (@$res)
      { if ($r_line->[2]!~ 
               /^\s*FOREIGN KEY\s*\(([\w\s,]+)\)\s*REFERENCES\s*(\w+)\s*\(([\w\s,]+)\)/)
          { dberror($mod_l,'foreign_keys',__LINE__,
                    "line not understood:\n$r_line->[2]");
            return;
          };
        my($resident_col,$foreign_tab,$foreign_col)=(uc($1),$2,uc($3));

        if (($foreign_col=~ /,/) or ($resident_col=~ /,/))
          { dbwarn($mod_l,'foreign_keys',__LINE__,
                    "column-combinations are not supported, found relation was:\n" .
                    $r_line->[2]);
            next;
          };

        push @{ $resident_keys{$foreign_col} },
                [ canonify_name($dbh,$user_name,
                                $r_line->[1] . "." .$r_line->[0]),
                  $resident_col 
                ]; 
      };

    return( \%resident_keys);
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
    my($full_name,$table_owner,$table,$schema);

    $dbh= check_dbi_handle($dbh);
    return if (!defined $dbh);

    ($full_name,$table_owner,$table,$schema)=
       real_name($dbh,$user_name,$table_name);

#warn "schema,table: $schema,$table";
    if (!defined $table) # assertion !
      { dbwarn($mod_l,'primary_keys',__LINE__,
               "table $table_name not present or accessible");
        return;       
      };

    view_dependencies($dbh,$user_name);

    my @dependents;

    my $data= $r_db_objects->{"$schema.$table"};
    if (defined $data)
      { my $referencing= $data->[4]; 
        if (defined $referencing)
          { foreach my $obj (@$referencing)
              { my $d= $r_db_objects->{$obj};
                die "assertion!" if (!defined $d);

                push @dependents, [$d->[1],$obj,
                                   $d->[0] eq 'T' ? 'TABLE':'VIEW',
                                  ];
              };
          };
      };

    if (object_is_table($dbh,$full_name,$user_name))
      { my $res= resident_keys($dbh,$user_name,$table_name);
        # NOTE: the results are canonified!

        my %tabs;
        foreach my $col (keys %$res)
          { my $r_line= $res->{$col};
            foreach my $r_p (@$r_line)
              { # store name as "schema.name":
                $tabs{add_schema($dbh,$r_p->[0])}= 1; 
              };
          };
        foreach my $obj (keys %tabs)
          { 
#warn "obj:$obj";         
            my $d= $r_db_objects->{$obj};
            die "assertion!" if (!defined $d);

            push @dependents, [$d->[1],
                               canonify_name($dbh,"",$obj,""),
                               $d->[0] eq 'T' ? 'TABLE':'VIEW',
                              ];
          };
      };          
    return(@dependents);
  }  

# INTERNAL-------------------

sub sql_parse
# INTERNAL to dbdrv_pg!!!
# builds kind of a parse-tree, a list 
# with embedded lists
# recognizes numbers and strings starting with "'"
  { my($str,$r_list)= @_;


    #print "SQLPARSE:$str\n";
    my $ch;
    while($str=~/\G([+-]?\d+(?:\.\d+(?:[eE][+-]?\d+|)|)| # number
                    \w+\.\"[^\"]*?\"| # for: pr."type" 
                    [\w\.]+|       # token
                    \s+|           # spaces
                    \(|            # opening bracket
                    \)|            # closing bracket
                    \'[^\']*?\'|   # string
                    \"[^\"]*?\"|   # Postgres-string ?
                    ::|            # 
                    .)/gx)         # arbitrary single character
      { $ch= substr($1,0,1);
        if ($ch eq "\'")
          { 
            push @$r_list,$1;
            next;
          };
        if ($ch=~ /\s/)
          { next; };
        if ($ch eq '(')
          { my $curpos= pos($str);
            my @n;
            push @$r_list,\@n;
            $curpos+= sql_parse(substr($str,$curpos),\@n);
            pos($str)= $curpos;
            next;
          };
        if ($ch eq ')')
          { 
            return(pos($str)); 
          };
        push @$r_list,$1;
      };        
  }        

sub scan_FROM
# INTERNAL to dbdrv_pg!!!
  { my($dbh,$r_list,$r_objs,$r_known_objs)= @_;
    my $from_found;
    my $obj_found;


    #print "SCAN FROM *************************************\n";
    foreach my $elm (@$r_list)
      { if (ref($elm))
          { scan_FROM($dbh,$elm,$r_objs,$r_known_objs); 
            next;
          };
        if (!$from_found)
          { next if (uc($elm) ne 'FROM');
            $from_found=1;
            #print "FROM found, list: ",join("|",@$r_list),"\n"; 
            next;
          };
        if ($elm=~ /\b(WHERE|ORDER|ON|UNION|SELECT|AS|pr)\b/i)
          { $from_found=0;
            $obj_found=0;
            next;
          };
        if ($elm=~ /\bpr\b/i)
        # pr() seems to be a special function that sometimes
        # appears in the FROM part
          { next;
          };
        if (!$obj_found)
          { 
            #print "test $elm...\n";      
            $elm= add_schema($dbh,$elm);
            if (!exists $r_known_objs->{$elm})
              { next; };

            $r_objs->{$elm}=1;
            #print "PUSHED: $elm\n";
            $obj_found=1;
            # ^^^ needed in order to
            # ignore table aliases
            next;
          }
        else
          { if ($elm eq ',')
              { $obj_found=0; 
                #print "COMMA FOUND\n";
                next;
              };
            next;
          };
      };
  }  

sub view_dependencies
# INTERNAL to dbdrv_pg!!!
  { my($dbh,$username)= @_;

    return if ($view_dependencies_examined);

    $dbh= check_dbi_handle($dbh);
    return if (!defined $dbh);

    my $SQL= "SELECT * from pg_views WHERE " .
             "has_table_privilege(schemaname || '.' || viewname,'select')";

    # returns schemaname, viewname, viewowner, description

    my $res= $dbh->selectall_arrayref($SQL);

    if (!defined $res)
      { dberror($mod_l,'view_dependencies',__LINE__,
                "selectall_arrayref failed, errcode:\n$DBI::errstr");
        return;
      };

    return if ($#$res<0);

    # first we need a list of all tables and views
    # (and also schemaname.objectname)
    load_object_dict($dbh,$username);

#print Dumper($r_all);
#die;

    #my %viewrefs;
    my $n;
    foreach my $line (@$res)
      { my @parse_tree;
        my %referenced;
        sql_parse($line->[3],\@parse_tree);
        scan_FROM($dbh,\@parse_tree,\%referenced,$r_db_objects);

        next if (!%referenced);

        $n= $line->[0] . "." . $line->[1];

        # store information in data-dictionary
        $r_db_objects->{$n}->[3]= [sort keys %referenced];

        foreach my $obj (keys %referenced)
          { push @{ $r_db_objects->{$obj}->[4] }, $n; };  

        # in $r_db_objects: [3]: referenced objects
        #                   [4]: referencing objects
        #  --> but only with respect to views, no information
        #      about foreign-key relations!!

        #$viewrefs{$line->[0] . "." . $line->[1]}= \%referenced;
        #print Dumper(\@parse_tree);
        #print "-" x 20,"\n";
        #print Dumper(\%referenced);
        #die;
      };
    #print Dumper(\%viewrefs);  

    #print Dumper($r_db_objects);

    $view_dependencies_examined=1;

  };

#-------------------------------------------------------------
# object-references
#-------------------------------------------------------------

sub object_references
# EXPORTED
# read the owner, name  and of referenced objects
  { my($dbh,$table_name,$user_name)= @_;
    my($full_name,$table_owner,$table,$schema);

    $dbh= check_dbi_handle($dbh);
    return if (!defined $dbh);

    ($full_name,$table_owner,$table,$schema)=
       real_name($dbh,$user_name,$table_name);

#warn "schema,table: $schema,$table";
    if (!defined $table) # assertion !
      { dbwarn($mod_l,'primary_keys',__LINE__,
               "table $table_name not present or accessible");
        return;       
      };

    view_dependencies($dbh,$user_name);

    my @referenced;

    my $data= $r_db_objects->{$full_name};
    if (defined $data)
      { my $referenced= $data->[3]; 
        if (defined $referenced)
          { foreach my $obj (@$referenced)
              { my $d= $r_db_objects->{$obj};
                die "assertion!" if (!defined $d);

                push @referenced, [$d->[1],$obj,
                                   $d->[0] eq 'T' ? 'TABLE':'VIEW',
                                  ];
              };
          };
      };

    if (object_is_table($dbh,$full_name,$table_owner))
      { my $fk= foreign_keys($dbh,$user_name,$table_name);

#print Dumper($fk);
        # NOTE: the results are canonified!

        my %tabs;
        foreach my $col (keys %$fk)
          { my $r_line= $fk->{$col};

            $tabs{add_schema($dbh,$r_line->[0])}= 1;
          };
#print Dumper(\%tabs);
        foreach my $obj (keys %tabs)
          { 
#warn "obj:$obj";         
            my $d= $r_db_objects->{$obj};
            die "assertion!" if (!defined $d);

            push @referenced, [$d->[1],
                                canonify_name($dbh,"",$obj,""),
                                $d->[0] eq 'T' ? 'TABLE':'VIEW',
                               ];
          };
      };          
    return(@referenced);
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
    my($full_name,$table_owner,$table,$schema);

    $dbh= check_dbi_handle($dbh);
    return if (!defined $dbh);

    $table_name= lc($table_name);

    ($full_name,$table_owner,$table,$schema)=
       real_name($dbh,$user_name,$table_name);
    if (!defined $table) # assertion !
      { dbwarn($mod_l,'primary_keys',__LINE__,
               "table $table_name not present or accessible");
        return;       
      };

    my $SQL= "select definition from pg_views where" .
                   " viewname=\'$table\' AND " .
                   " schemaname=\'$schema\'";

    sql_trace($SQL) if ($sql_trace);
    my $res_r=
      $dbh->selectall_arrayref($SQL);

    if (!defined $res_r)
      { dberror($mod_l,'db_read_viewtext',__LINE__,
                "selectall_arrayref failed, errcode:\n$DBI::errstr");
        return;
      };

    my $r_line= $res_r->[0];
    if (!ref($r_line))
      { return; }; # empty

    my $text= $r_line->[0];
    return( $text );
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

sub type_to_typechar
# internal
  { my($type)= @_;
    return( $db_object_types{uc($type)});
  }



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
