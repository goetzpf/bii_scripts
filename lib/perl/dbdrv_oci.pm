
# Copyright 2022 Helmholtz-Zentrum Berlin für Materialien und Energie GmbH
# <https://www.helmholtz-berlin.de>
#
# Author: Goetz Pfeiffer <Goetz.Pfeiffer@helmholtz-berlin.de>
# Contributions by:
#         Victoria Laux <victoria.laux@helmholtz-berlin.de>
#
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later
# version.
# 
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
# details.
# 
# You should have received a copy of the GNU General Public License along with
# this program.  If not, see <http://www.gnu.org/licenses/>.


# this is not a real perl-package
# it is loaded via "do" into dbdrv.pm !!

use strict;
#use Data::Dumper;

our $sql_trace;
our $r_db_objects;
our $r_db_reverse_synonyms;

my $mod_l= "dbdrv_oci";

# object types known to oracle with their oracle abbreviation
my @db_object_types= qw(TABLE VIEW PROCEDURE FUNCTION SEQUENCE);

my %db_object_types = map{ $_ => 1 } @db_object_types;

our $sql_capabilities;

$sql_capabilities->{"generic"}=
  {
    "alias"=>
      {
        "objects"=>      "SELECT object_name, status, object_type, owner 
                                    FROM sys.all_objects 
                                    WHERE object_name LIKE UPPER('##1##') AND
                                    NOT object_type = 'SYNONYM'",
        "describe"=>     "SELECT column_name, table_name, owner, data_type, 
                                        data_length, data_precision, data_scale, nullable, 
                                        column_id, default_length, data_default, num_distinct, 
                                        low_value, high_value
                                    FROM all_tab_columns 
                                    WHERE table_name = UPPER('##1##') 
                                    ORDER BY column_id",
        "lookup"=>        "SELECT object_name, object_owner, object_type 
                                    FROM all_objects
                                    WHERE object_name like '##1##''",
      },
  };
$sql_capabilities->{"table"}=
  {
    "alias"=>
      {
        "depends" =>    "SELECT o.object_id, o.created, o.status, o.object_name, o.owner 
                                        FROM all_dependencies d, all_objects o 
                                        WHERE d.name = UPPER('##1##') AND 
                                            d.referenced_owner = o.owner AND 
                                            d.referenced_name = o.object_name 
                                        ORDER BY o.object_name",
        "triggertext" =>       "SELECT trigger_type, triggering_event, trigger_body 
                                            FROM dba_triggers 
                                            WHERE trigger_name = UPPER('##1##')",
        "constraints" =>    "SELECT constraint_name, table_name, owner,constraint_type, 
                                                r_owner, r_constraint_name, search_condition 
                                            FROM all_constraints 
                                            WHERE table_name = UPPER('##1##') 
                                            ORDER BY constraint_name, r_owner, r_constraint_name",
        "triggers" =>           "SELECT DISTINCT trigger_name, owner, table_owner, table_name, 
                                                trigger_type, triggering_event, status, referencing_names 
                                            FROM dba_triggers 
                                            WHERE table_name = UPPER('##1##') 
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
# has to be exported to a config file
our @sql_none_users = qw(PUBLIC WEBCALENDAR WWW_LOCAL);
our @sql_public_users = qw(PUBLIC);

foreach my $cap_aliases (keys %$sql_capabilities)
  {
    my $cap_entry =$sql_capabilities->{$cap_aliases}->{alias};
    if (defined($cap_entry))
      {
        foreach my $aliasname ( keys %$cap_entry )
          { $sql_aliases{$aliasname} = $cap_entry->{$aliasname}; }
      }
  }

#=============================================================
# name conversions, name spaces, schemas 
#=============================================================

sub real_name
# EXPORTED 
# resolves a given table-name or synonym,
# returns: full-qualified-name,owner,unqualified-name,schema
# NOTE: user-name is not the owner of the table but the user
# that has logged in
  { my($dbh,$user_name,$obj)= @_;

    #my ($package, $filename, $line) = caller;
    #warn "$package, $filename, $line";

    #warn "realname called with:$user_name,$obj";

    my $object_name;

    $dbh= check_dbi_handle($dbh);
    return if (!defined $dbh);

    $user_name= uc($user_name);
    $obj= uc($obj);

    load_object_dict($dbh,$user_name);

    if ($obj !~ /\./) # not in the form user.tablename
      { $object_name= "PUBLIC." . $obj; }
    else
      { $object_name= $obj; };

    my $data= $r_db_objects->{$object_name};

    if ((!defined $data) && ($obj !~ /\./))
      { # try a 2nd lookup with the user-name as prefix:

        $object_name= "$user_name.$obj";
        $data= $r_db_objects->{$object_name};
      };

    if ((!defined $data) && ($obj=~/\./))
      {
        # object name contains a dot, assume
        # that we can access the table.
        # fake the $data object:
        $data= [undef,$obj];
      }
    if (!defined $data)
      { # not in list of synonyms and user objects
        # the object is probably not accessible
        dbwarn($mod_l,'real_name',__LINE__,
               "warning:no data found for user \"$user_name\" object \"$obj\"");
        return;
      };

    # user objects have only a type-field !

    if ($#$data>0) # more than 2 objects in hash: it's a synonym
      { my($owner,$name)= split(/\./, $data->[1]);

        #warn "realname returns: $data->[1],$owner,$name";
        return($data->[1],$owner,$name);
      };

    # no synonym, the table is probably owner by the current user:
    my($owner,$short_name)= split(/\./,$object_name);

    #warn "realname returns: $object_name,$owner,$short_name";
    return($object_name,$owner,$short_name);
  }

sub canonify_name
# EXPORTED 
# returns a "nice" name
  { my($dbh,$user_name,$object_name,$object_owner)= @_;

    $user_name= uc($user_name);

    if ($object_name =~ /\./)
      { ($object_owner,$object_name)= split(/\./,$object_name); };

    return($object_name) if (!defined $object_owner);

    $dbh= check_dbi_handle($dbh);
    return if (!defined $dbh);

    load_object_dict($dbh,$user_name);

    my $name= $object_owner . '.' . $object_name;

    my $r_list= $r_db_reverse_synonyms->{$name};
    if (!defined $r_list)
      { return($name); };

    my($public_syn,$user_syn,$other_syn);
    # scan the list of synonyms:
    foreach my $n (@$r_list)
      { my($owner,$obj)= split(/\./,$n);
        if ($owner eq 'PUBLIC')
          { $public_syn= $obj; 
            # for PUBLIC synonyms, we can omit 
            # the "owner" part in the name
            next;
          };
        if ($owner eq $user_name)
          { $user_syn= $obj; 
            # for user-synonyms, we can omit 
            # the "owner" part in the name
            next;
          };
        if ((defined $public_syn) && (defined $user_syn))
          { last;
          };
      };
    # a kind of priority here: return public-synonym when
    # it was found, else try user-synonym if it was found,
    return $public_syn if (defined $public_syn);
    return $user_syn   if (defined $user_syn);  
    return($name);
  }

# INTERNAL-------------------

sub get_synonyms
# INTERNAL to dbdrv_oci!!!
# returns a ref to a hash : syn_name => [$type, "$t_own.$t_name"]
# type is 'T' (table) or 'V' (view) or
#  'P' (procedure), 'F':function, 'S': sequence
# $t_name: table or view referred to
# $t_own: owner of referred table or view
# $r_reverse_syn : a hash: owner.table => synonym
  { my($dbh,$r_syn,$r_reverse_syn)= @_;

    die if (!defined $r_syn);
    die if (ref($r_syn) ne 'HASH');

    $dbh= check_dbi_handle($dbh);
    return if (!defined $dbh);

    my $sql;

    $sql= "SELECT asyn.synonym_name, asyn.owner, " .
                "asyn.table_name,asyn.table_owner, ao.object_type " .
        "FROM all_synonyms asyn, all_objects ao " .
        "WHERE " .
                "asyn.table_owner NOT IN ('SYS', 'SYSTEM') AND " .
                "asyn.table_name=ao.object_name AND " .
                "asyn.table_owner=ao.owner" ;
    #warn Dumper($sql);
    sql_trace($sql) if ($sql_trace);

    my $res= $dbh->selectall_arrayref($sql);

    if (!defined $res)
    { dberror($mod_l,'get_synonyms',__LINE__,
                "selectall_arrayref failed, errcode:\n$DBI::errstr");
        return;
    };

    foreach my $line (@$res)
    {
        my $syn= $line->[1] . '.' . $line->[0];
        my $obj= $line->[3] . '.' . $line->[2];
        $r_syn->{$syn} = [ type_to_typechar($line->[4]), $obj ];

        if (!exists $r_reverse_syn->{$obj})
        { $r_reverse_syn->{$obj}= [$syn]; }
        else
        { push @{$r_reverse_syn->{$obj}}, $syn; };
    };

    #warn Dumper($r_syn);
    return(1);
  }


#=============================================================
# object catalogs
#=============================================================

#-------------------------------------------------------------
# Object dictionary (INTERNAL)
#-------------------------------------------------------------

sub load_object_dict
# INTERNAL to dbdrv_oci!!!
# WRITES TO GLOBAL VARIABLES:
# $r_db_objects and $r_db_reverse_synonyms
  { my($dbh,$user)= @_;

    return if (defined $r_db_objects);
    my %h;
    $r_db_objects= \%h;
    my %r;
    $r_db_reverse_synonyms= \%r;
    if ((defined $user) && ($user ne ""))
      {
        if (!get_user_objects($dbh,$user,$r_db_objects))
          { dberror($mod_l,'load_object_dict',__LINE__,
                    'loading of user-objects failed');
            return;
          };
      };

    if (!get_synonyms($dbh,$r_db_objects,$r_db_reverse_synonyms))
      { dberror($mod_l,'load_object_dict',__LINE__,
                'loading of synonyms failed');
        return;
      };
  }

#-------------------------------------------------------------
# get known schemas
#-------------------------------------------------------------
#PLx 2011
sub get_foreign_schemata
  { my($dbh,$user_name)= @_;
    $dbh = check_dbi_handle($dbh);
    return if (!defined $dbh);
    my $user = uc($user_name);
    my $excludeusers = "";
    foreach my $noneuser (@sql_none_users)
      {
        if ($excludeusers ne "")
          {
            $excludeusers = $excludeusers.", ";
          }
        $excludeusers = $excludeusers."'".$noneuser."'";
      }
    my $sql = "SELECT username FROM all_users" .
              "    WHERE user_id > 100" .
              " AND username NOT IN (".$excludeusers.") AND NOT username = '".$user."'";
    sql_trace($sql) if ($sql_trace);

    my $res= $dbh->selectall_arrayref($sql);

    if (!defined $res)
      { dberror($mod_l,'known_schemas',__LINE__,
                "selectall_arrayref failed, errcode:\n$DBI::errstr");
        return;
      };

    my @return;
    foreach my $line (@$res)
    {
        push @return, $line->[0];
    };
    #warn Dumper(\@return),"\n";
    return @return;
  }

sub known_schemas
# EXPORTED
  {
    my($dbh,$user_name)= @_;
    my @schemas = get_foreign_schemata($dbh, $user_name);
    sort @schemas;
    unshift @schemas, uc($user_name);
    push @schemas, "PUBLIC";
    #warn Dumper(\@schemas),"\n";
    return @schemas;
  }

sub is_public_schema
# EXPORTED
  {
    my($schema) = @_;
    my $ret = 0;
    foreach my $reguser (@sql_public_users)
      {
        if (uc($schema) eq $reguser)
          {
            $ret = 1;
          }
      }
      return $ret;
  }
        
#-------------------------------------------------------------
# get catalog of accessible objects
#-------------------------------------------------------------

sub accessible_objects
# EXPORTED 
  {
    my($dbh,$user_name,$types,$access)= @_;
#    my %known_types= { table => 'T', view => 'V', 
#                       procedure => 'P', FUNCTION => 'F',
#                       sequence=> 'S');
#    my %known_acc  = map { $_ =>1 } qw( user public );
    my %types;
    my %access;


#warn "requested types: $types";
    $dbh= check_dbi_handle($dbh);
    return if (!defined $dbh);

    if (!defined $types)
      { %types= (T=>1); }
    else
      { $types= uc($types);
        my @types= split(",",$types);
        foreach my $t (@types)
          { if (!exists $db_object_types{$t})
              { dberror($mod_l,'accessible_objects',__LINE__,
                    "unknown object type: $t");
                return;
              };
            $types{type_to_typechar($t)}= 1; 
          };
      };

    my @schemata = known_schemas($dbh, $user_name);

    load_object_dict($dbh,$user_name);

    # loads also functions and procedures

    my @keys;
    foreach my $dbobj_type (keys %types)
      {
        push @keys, (grep { $r_db_objects->{$_}->[0] eq $dbobj_type } keys %$r_db_objects);
      }

    #warn Dumper(\@result),"\n";

    my %schemas_wanted=(); #"PUBLIC"=>1, uc($user_name)=>1);
    foreach my $schema (@schemata)
      {
        if ($access->{$schema})
          {
            $schemas_wanted{$schema}= 1;
          }
      }

    my %result;
    foreach my $key (@keys)
      {
        if ($key=~ /^([^\.]+)\.(.*)$/)
          {
            if (exists $schemas_wanted{$1})
              {
                $result{$key}= 1;
              }
          }
      }
    return sort (keys %result);

  }

# INTERNAL-------------------

sub get_user_objects
# INTERNAL to dbdrv_oci!!!
# returns a ref to a hash : own.obj_name => [$type]
# type is 'T' (table) or 'V' (view) or 'P' (procedure) or
#         'F' (function) or 'Q' (sequence)
# $t_name: table or view referred to
# $t_own: owner of referred table or view (equal to the $user-parameter)
  {
    my($dbh,$user,$r_tab)= @_;

    die if (!defined $r_tab);
    die if (ref($r_tab) ne 'HASH');

    return if (!defined $user);
    return if ($user eq "");

    $user= uc($user);

    $dbh= check_dbi_handle($dbh);
    return if (!defined $dbh);

    my $sql;
    # per database_object_type registration of all known objects
    my $schema_filter = "";
    my @schemata = known_schemas($dbh, $user);
    foreach my $schema (@schemata)
      {
        if ($schema_filter ne "")
          {
            $schema_filter = $schema_filter.", ";
          } 
        $schema_filter = $schema_filter." '$schema'";
      }
    foreach my $dbobj_type (keys %db_object_types)
      {
        $sql= "SELECT object_name, owner " .
              "FROM all_objects " .
              "WHERE object_type = '".$dbobj_type."'" .
              "  AND owner IN (" . $schema_filter . ")";

        #warn "\nget_obj $dbobj_type: $sql";
        sql_trace($sql) if ($sql_trace);

        my $res= $dbh->selectall_arrayref($sql);

        if (!defined $res)
          { dberror($mod_l,'get_user_objects',__LINE__,
                    "selectall_arrayref failed for $dbobj_type " .
                    "request, errcode:\n$DBI::errstr");
            return;
          };

        foreach my $line (@$res)
          {
            $r_tab->{ $line->[1] . '.' . $line->[0] } =
                                  [type_to_typechar($dbobj_type) ];
            };
      }

    #warn "rtab:".Dumper($r_tab);
    return(1);
  }

#=============================================================
# object type and existence
#=============================================================

#-------------------------------------------------------------
# check existence
#-------------------------------------------------------------

sub check_existence
  { my($dbh,$table_name,$user_name)= @_;

    # when the table has the form "owner.table", the check cannot
    # be made, since it's no public synonym and not in the
    # synonym list
    return(1) if ($table_name=~ /\./);
    

    $dbh= check_dbi_handle($dbh);
    return if (!defined $dbh);

    load_object_dict($dbh,$user_name);

    if (exists $r_db_objects->{uc($user_name) . '.' . uc($table_name)})
      { return(1); };
    if (exists $r_db_objects->{"PUBLIC." . uc($table_name)})
      { return(1); };

    return;
  }

#-------------------------------------------------------------
# object-type 
#-------------------------------------------------------------

sub object_is_table
# return 1 when it is a table
  { my($dbh,$table_name,$user_name)= @_;
    my $table_owner;

    $dbh= check_dbi_handle($dbh);
    return if (!defined $dbh);

    $table_name= uc($table_name);

    ($table_owner,$table_name)=
                (dbdrv::real_name($dbh,$user_name,$table_name))[1,2];

    if (!defined $table_name)
      { # not in list of synonyms and user objects
        # the object is probably not accessible
        dbwarn($mod_l,'object_is_table',__LINE__,
               "warning:no data found for object $table_name");
        return;
      };

    my $SQL= "select OWNER,TABLE_NAME from " .
             "all_tables " .
             "where table_name=\'$table_name\' and owner=\'$table_owner\'";

    sql_trace($SQL) if ($sql_trace);
    my $res_r=
      $dbh->selectall_arrayref($SQL);

    if (!defined $res_r)
      { dberror($mod_l,'object_is_table',__LINE__,
                "selectall_arrayref failed, errcode:\n$DBI::errstr");
        return;
      };

    if (@$res_r)
      { return(1); };
    return(0);
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
  { my($dbh,$sth,$tablename)= @_;

    my $type_no2string= db_types_no2string($dbh);

    my @x= map { $type_no2string->{$_} } @{$sth->{TYPE}};

    db_simplify_types(\@x);
    return(@x);
  }

sub column_properties
# EXPORTED
# need handle, table_name, table_owner
# read the type, length, precision, null-condition of a check constraint
  { my($dbh, $user_name, $table_name)= @_;
    my $table_owner;

    $dbh= check_dbi_handle($dbh);
    return if (!defined $dbh);

    $table_name= uc($table_name);
    ($table_owner,$table_name)=
                (dbdrv::real_name($dbh,$user_name,$table_name))[1,2];

    if (!defined $table_name)
      { # not in list of synonyms and user objects
        # the object is probably not accessible
        dbwarn($mod_l,'column_properties',__LINE__,
               "warning:no data found for object $table_name");
        return;
      };

    if (!defined $table_owner || !defined $table_name ||
        $table_owner eq '' || $table_name eq '')
      { dberror($mod_l,'column_properties',__LINE__,
                "arguments not complete (assertion) \n" .
                "args:\"$table_owner.$table_name\"");
        return;
      };

    my $SQL= "select AC.COLUMN_NAME, AC.DATA_TYPE, AC.DATA_LENGTH, ".
                "AC.DATA_PRECISION, AC.NULLABLE, AC.DATA_DEFAULT" .
                " from ALL_TAB_COLUMNS AC" .
                " where" .
                   " AC.OWNER=\'$table_owner\' AND " .
                   " AC.TABLE_NAME=\'$table_name\'";

#warn "get columndefs $SQL";

    sql_trace($SQL) if ($sql_trace);
    my $res_r=
      $dbh->selectall_arrayref($SQL);

    if (!defined $res_r)
      { dberror($mod_l,'db_column_properties',__LINE__,
                "selectall_arrayref failed, errcode:\n$DBI::errstr");
        return;
      };

    return if (!@$res_r);
    # no column-properties found

    my %ret;
    # caution: the hash may be empty !
    foreach my $line ( @$res_r )
      {
        $ret{$line->[0]} = {
            type=>$line->[1],
            length=>$line->[2],
            precision=>$line->[3],
            null=>$line->[4],
            default=>$line->[5],
        };
      };
#print Dumper(\%ret);      

    return( \%ret );
  }

# INTERNAL-------------------

sub db_simplify_types
# INTERNAL to dbdrv_oci!!!
  { my($r_types)= @_;
    my %map= (RAW        => undef,           # raw data ??
              CLOB       => undef,           # big alphanumeric object
              BFILE      => undef,           # pointer to file (??)
              'LONG RAW' => undef,           # big alphanumeric object (??)
              LONG       => undef,           # big alphanumeric object (??)
              CHAR       => 'string',        # CHAR
              NUMBER     => 'number',        # cardinal number
              DECIMAL    => 'number',        # cardinal number
              DATE       => 'string',        # date
              VARCHAR2   => 'string',        # string
              DOUBLE     => 'number',        # floating point
              'DOUBLE PRECISION' => 'number',# floating point

              # postgres-types:
#             BOOL     =>  'number',
#              TEXT     =>  'string',
#              BPCHAR   =>  'string',
#              VARCHAR  =>  'string',
#              INT2     =>  'number',
#              INT4     =>  'number',
#              INT8     =>  'number',
#              MONEY    =>  'number',
#              FLOAT4   =>  'number',
#              FLOAT8   =>  'number',
#              ABSTIME  =>  'string',
#              RELTIME  =>  'string',
#              TINTERVAL=>  'string',
#              DATE     =>  'string',
#              TIME     =>  'string',
#              DATETIME =>  'string',
#              TIMESPAN =>  'string',
#              TIMESTAMP=>  'string',

             );

    my $tag;
    foreach my $t (@$r_types)
      {

        $tag= uc($t);
#print "tag:$tag|\n"; # @@@@@@@
        $t= $map{uc($tag)};
        next if (defined $t);
        next if (exists $map{uc($tag)});
        warn "internal error (assertion): col-type $tag is unknown";
      };
  }

sub db_types_no2string
# INTERNAL to dbdrv_oci!!!
# creates a hash, mapping number to string,
# this is needed for $sth->{TYPE} !
# known datatypes in DBD::oracle:
# on host ocean:
#          '-3' => 'RAW',
#          '-4' => 'LONG RAW',
#          '1' => 'CHAR',
#          '3' => 'NUMBER',
#          '11' => 'DATE',
#          '12' => 'VARCHAR2',
#          '8' => 'DOUBLE',
#          '-1' => 'LONG'
# on the linux client:
#          '8' => 'DOUBLE PRECISION',
#          '1' => 'CHAR',
#          '93' => 'DATE',
#          '3' => 'DECIMAL',
#          '-4' => 'BFILE',
#          '12' => 'VARCHAR2',
#          '-1' => 'CLOB',
#          '-3' => 'RAW'
  { my($dbh)= @_;
    my %map;

    my $info= $dbh->type_info_all(); # ref. to an array
    # a DBI function, returns a list, 1st elm is a description-hash
    # like:    {   TYPE_NAME         => 0,
    #              DATA_TYPE         => 1,
    #              COLUMN_SIZE       => 2,
    #               ...
    #          }
    # following elements are lists describing each type like:
    #           [ 'VARCHAR', SQL_VARCHAR,
    #               undef, "'","'", undef,0, 1,1,0,0,0,undef,1,255, undef
    #           ],


    my $r_description= shift(@$info); # ref to a hash

    # get the indices for the TYPE_NAME and the DATA_TYPE property:

    my $TYPE_NAME_index= $r_description->{TYPE_NAME};
    my $DATA_TYPE_index= $r_description->{DATA_TYPE};


    foreach my $r_t (@$info)
      { $map{ $r_t->[$DATA_TYPE_index] } = $r_t->[$TYPE_NAME_index]; };

    return(\%map);
  }

#=============================================================
# relations: primary, foreign, resident keys
#=============================================================

#-------------------------------------------------------------
# primary key
#-------------------------------------------------------------

sub primary_keys
# EXPORTED
# returns the one primary key or the list of columns
# that form the primary key
  { my($dbh,$user_name,$table_name)= @_;
    my $table_owner;

    #my ($package, $filename, $line) = caller;
    #warn "$package, $filename, $line";

    #warn "primary_keys called with:$user_name,$table_name";

    $dbh= check_dbi_handle($dbh);
    return if (!defined $dbh);

    $table_name= uc($table_name);

    ($table_owner,$table_name)=
                (dbdrv::real_name($dbh,$user_name,$table_name))[1,2];

    if (!defined $table_name)
      { # not in list of synonyms and user objects
        # the object is probably not accessible
        dbwarn($mod_l,'primary_keys',__LINE__,
               "warning:no data found for object $table_name");
        return;
      };

    my $SQL= "SELECT a.owner, a.table_name, b.column_name " .
             "FROM all_constraints a, all_cons_columns b " .
             "WHERE a.constraint_type='P' AND " .
                  " a.constraint_name=b.constraint_name AND " .
                  " a.table_name = \'$table_name\'";

    # take table owner into account
    if (defined $table_owner)
      { $SQL.= " AND a.owner=\'$table_owner\'";
        $SQL.= " AND b.owner=\'$table_owner\'"; # @@@@@ NEW
      };

    sql_trace($SQL) if ($sql_trace);

    my $res=
      $dbh->selectall_arrayref($SQL);

    if (!defined $res)
      { dberror($mod_l,'db_get_primary_keys',__LINE__,
                "selectall_arrayref failed, errcode:\n$DBI::errstr");
        return;
      };

    # returns  OWNER TABLE_NAME COLUMN_NAME

    # NOTE: in some tables, only the combination of several rows is
    # the primary key, in this case, the SQL statement above returns
    # more than a single line.

    my @pks;
    foreach my $line (@$res)
      { push @pks, $line->[2]; };

    if (!@pks)
      { return; };
    return(@pks);
  }

#-------------------------------------------------------------
# foreign-key
#-------------------------------------------------------------

sub foreign_keys
# EXPORTED
  { my($dbh,$user_name,$table_name)= @_;
    my $table_owner;

    if ($table_name =~ "/\./")
      {
        ($table_owner, $table_name) = split ("/\./", $table_name);
      }
    else
      {
        $table_owner = $user_name;
      }
    $dbh= check_dbi_handle($dbh);
    return if (!defined $dbh);

    $table_name= uc($table_name);

    ($table_owner,$table_name)=
                  (dbdrv::real_name($dbh,$user_name,$table_name))[1,2];
    if (!defined $table_name)
      { # not in list of synonyms and user objects
        # the object is probably not accessible
        dbwarn($mod_l,'foreign_keys',__LINE__,
               "warning:no data found for object $table_name");
        return;
      };

    my $SQL= "select ST.TABLE_NAME, CL.COLUMN_NAME, " .
                    "ST.CONSTRAINT_NAME, ST.R_CONSTRAINT_NAME, " .
                    "CL2.TABLE_NAME AS FOREIGN_TABLE, " .
                    "CL2.COLUMN_NAME AS FOREIGN_COLUMN, " .
                    "ST.OWNER, ST2.OWNER " .
             "FROM " .
                    "all_cons_columns CL, all_cons_columns CL2, " .
                    "all_constraints ST, all_constraints ST2 " .
             "WHERE ";


    if (defined $table_owner)
      { $SQL.= "ST.OWNER=\'$table_owner\' AND "; };

    $SQL.=          "ST.TABLE_NAME=\'$table_name\' AND " .
                    "ST.CONSTRAINT_TYPE='R' AND " .
                    "ST.CONSTRAINT_NAME=CL.CONSTRAINT_NAME AND " .
                    "ST.OWNER=CL.OWNER AND " .
                    "ST.R_CONSTRAINT_NAME= ST2.CONSTRAINT_NAME AND " .
                    "ST.R_OWNER=ST2.OWNER AND " .
                    "ST2.CONSTRAINT_NAME=CL2.CONSTRAINT_NAME AND " .
                    "ST2.OWNER=CL2.OWNER";

    sql_trace($SQL) if ($sql_trace);
    my $res=
      $dbh->selectall_arrayref($SQL);
    # gives:
    # TABLE_NAME COLUMN_NAME CONSTRAINT_NAME R_CONSTRAINT_NAME
    #          FOREIGN_TABLE FOREIGN_COLUMN OWNER OWNER

    # do only take lines where both OWNERS match
    # if you adde "ST.OWNER=ST2.OWNER" to the SQL statement
    # it takes 4 minutes instead of 1 second !!!
    # perl is a bit faster... ;-)

    if (!defined $res)
      { dberror($mod_l,'db_get_foreign_keys',__LINE__,
                "selectall_arrayref failed, errcode:\n$DBI::errstr");
        return;
      };

    # build a hash,
    # col_name => [foreign_table,foreign_column,foreign_table_owner]
    my %foreign_keys;
    foreach my $r_line (@$res)
      { # owner mismatch
#        next if ($r_line->[6] ne $r_line->[7]);

# returns column-name -> FOREIGN_TABLE FOREIGN_COLUMN,FOREIGN_OWNER

        $foreign_keys{ $r_line->[1] } = [ $r_line->[4],
                                          $r_line->[5], $r_line->[7] ];

        #warn "$r_line->[1] -> ( $r_line->[4],$r_line->[5] )";
      };

    return( \%foreign_keys);
  }

#-------------------------------------------------------------
# resident-key
#-------------------------------------------------------------

sub resident_keys
# EXPORTED
# the opposite of foreign keys,
# find where the primary key of this table is used as foreign key
  { my($dbh,$user_name,$table_name)= @_;
    my $table_owner;

    if ($table_name =~ "/\./")
      {
        ($table_owner, $table_name) = split ("/\./", $table_name);
      }
    else
      {
        $table_owner = $user_name;
      }
    $dbh= check_dbi_handle($dbh);
    return if (!defined $dbh);

    $table_name= uc($table_name);

    ($table_owner,$table_name)=
                (dbdrv::real_name($dbh,$table_owner,$table_name))[1,2];
    if (!defined $table_name)
      { # not in list of synonyms and user objects
        # the object is probably not accessible
        dbwarn($mod_l,'resident_keys',__LINE__,
               "warning:no data found for object $table_name");
        return;
      };

    my $SQL= "select ST.TABLE_NAME, ST.OWNER, CL.COLUMN_NAME, " .
                   "ST.CONSTRAINT_NAME, " .
                   " ST2.TABLE_NAME AS R_TABLE, " .
                   " CL2.COLUMN_NAME AS R_COLUMN, " .
                   " ST2.CONSTRAINT_NAME AS R_CONSTRAINT_NAME, " .
                   " ST2.OWNER AS R_OWNER " .
             "from  " .
             "all_constraints ST, all_constraints ST2,  " .
             "all_cons_columns CL, all_cons_columns CL2 " .
             "where ";

# Oracle is too slow for this:
#    if (defined $table_owner)
#      { $SQL.=      "ST.OWNER=\'$table_owner\' AND "; };


    $SQL.=         " ST.TABLE_NAME=\'$table_name\' AND " .
                   " ST.CONSTRAINT_TYPE='P' AND " .
                   " ST.CONSTRAINT_NAME=ST2.R_CONSTRAINT_NAME AND " .
                   " ST2.CONSTRAINT_TYPE='R' AND " .
                   " ST.CONSTRAINT_NAME=CL.CONSTRAINT_NAME AND " .
                   " ST2.CONSTRAINT_NAME=CL2.CONSTRAINT_NAME ";

    sql_trace($SQL) if ($sql_trace);
    my $res_r=
      $dbh->selectall_arrayref($SQL);
    # gives:
    # TABLE_NAME TABLE_OWNER COLUMN_NAME CONSTRAINT_NAME
    #  R_TABLE R_COLUMN R_CONSTRAINT_NAME R_OWNER

    if (!defined $res_r)
      { dberror($mod_l,'db_get_resident_keys',__LINE__,
                "selectall_arrayref failed, errcode:\n$DBI::errstr");
        return;
      };

    # build a hash,
    # col_name => [ [resident_table1,resident_column1,resident_owner],
    #               [resident_table2,resident_column2,resident_owner],
    #                    ...
    #             ]
    #      resident_table may occur more than once

    my @res;
    if (defined $table_owner)
      { foreach my $r_line (@$res_r)
          { next if ($r_line->[1] ne $table_owner);
            push @res, $r_line;
          }
      }
    else
      { @res= @$res_r; };


    if ($#res < 0)
      { # no resident keys found, just return "undef"
        return;
      };

    my %resident_keys;
    foreach my $r_line (@res)
      {
        push @{ $resident_keys{ $r_line->[2] } },
                 [ $r_line->[4],$r_line->[5], $r_line->[7] ];
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
# read the owner, name and of type dependend objects,
# type is either "TABLE" or "VIEW"
  { my($dbh,$table_name,$user_name)= @_;
    my $table_owner;

    $dbh= check_dbi_handle($dbh);
    return if (!defined $dbh);

    $table_name= uc($table_name);

    ($table_owner,$table_name)=
                (dbdrv::real_name($dbh,$user_name,$table_name))[1,2];
    if (!defined $table_name)
      { # not in list of synonyms and user objects
        # the object is probably not accessible
        dbwarn($mod_l,'object_dependencies',__LINE__,
               "warning:no data found for object $table_name");
        return;
      };


    my $SQL= "select OWNER, NAME, TYPE ".
                   " from ALL_DEPENDENCIES AD where" .
                   " AD.REFERENCED_NAME=\'$table_name\' AND " .
                   " AD.REFERENCED_OWNER=\'$table_owner\'";

    sql_trace($SQL) if ($sql_trace);
    my $res_r=
      $dbh->selectall_arrayref($SQL);

    if (!defined $res_r)
      { dberror($mod_l,'db_object_dependencies',__LINE__,
                "selectall_arrayref failed, errcode:\n$DBI::errstr");
        return;
      };

    return( @$res_r );
  }

#-------------------------------------------------------------
# object-references
#-------------------------------------------------------------

sub object_references
# EXPORTED
# read the owner, name  and of referenced objects
  { my($dbh,$table_name,$user_name)= @_;
    my $table_owner;

    $dbh= check_dbi_handle($dbh);
    return if (!defined $dbh);

    $table_name= uc($table_name);

    ($table_owner,$table_name)=
                (dbdrv::real_name($dbh,$user_name,$table_name))[1,2];
    if (!defined $table_name)
      { # not in list of synonyms and user objects
        # the object is probably not accessible
        dberror($mod_l,'resident_keys',__LINE__,
                "error:no data found for object $table_name");
        return;
      };

    my $SQL= "select REFERENCED_OWNER OWNER, REFERENCED_NAME NAME, REFERENCED_TYPE TYPE".
                   " from ALL_DEPENDENCIES AD where" .
                   " AD.NAME=\'$table_name\' AND " .
                   " AD.OWNER=\'$table_owner\'";


    sql_trace($SQL) if ($sql_trace);
    my $res_r=
      $dbh->selectall_arrayref($SQL);

    if (!defined $res_r)
      { dberror($mod_l,'db_object_references',__LINE__,
                "selectall_arrayref failed, errcode:\n$DBI::errstr");
        return;
      };

    return( @$res_r );
  }

#-------------------------------------------------------------
# object-addicts
#-------------------------------------------------------------

sub object_addicts
# EXPORTED
# read all constraints and triggers for the given object
  { my($dbh,$table_name,$user_name)= @_;
    my $table_owner;

    $dbh= check_dbi_handle($dbh);
    return if (!defined $dbh);

    $table_name= uc($table_name);

    ($table_owner,$table_name)=
                (dbdrv::real_name($dbh,$user_name,$table_name))[1,2];

    if (!defined $table_name)
      { # not in list of synonyms and user objects
        # the object is probably not accessible
        dberror($mod_l,'object_addicts',__LINE__,
               "warning:no data found for object $table_name");
        return;
      };

    my $SQL= "select CONSTRAINT_NAME NAME, \'$table_owner\' OWNER, 'C' TYPE" .
                " from ALL_CONSTRAINTS" .
                " where OWNER = \'$table_owner\' and " .
                " CONSTRAINT_TYPE = 'C' AND " .
                " TABLE_NAME = \'$table_name\'" .
             " union " .
             "select TRIGGER_NAME NAME, \'$table_owner\' OWNER, 'T' TYPE" .
                " from ALL_TRIGGERS" .
                " where OWNER = \'$table_owner\' and " .
                " table_name = \'$table_name\'";

#warn "$SQL\n";

    sql_trace($SQL) if ($sql_trace);
    my $res_r=
      $dbh->selectall_arrayref($SQL);

#print Dumper($res_r),"\n";

    if (!defined $res_r)
      { dberror($mod_l,'db_object_addicts',__LINE__,
                "selectall_arrayref failed, errcode:\n$DBI::errstr");
        return;
      };

    return( @$res_r );
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
    my $table_owner;

    $dbh= check_dbi_handle($dbh);
    return if (!defined $dbh);

    $table_name= uc($table_name);

    ($table_owner,$table_name)=
                (dbdrv::real_name($dbh,$user_name,$table_name))[1,2];

    if (!defined $table_name)
      { # not in list of synonyms and user objects
        # the object is probably not accessible
        dberror($mod_l,'read_viewtext',__LINE__,
               "warning:no data found for object $table_name");
        return;
      };

    my $SQL= "select TEXT from ALL_VIEWS AV where" .
                   " AV.VIEW_NAME=\'$table_name\' AND " .
                   " AV.OWNER=\'$table_owner\'";

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

    $dbh= check_dbi_handle($dbh);
    return if (!defined $dbh);

    $constraint_name= uc($constraint_name);

    if ($constraint_name =~ /\./)
      { ($table_owner,$constraint_name)= split(/\./,$constraint_name); };

    die if (!defined $table_owner); # assertion !

    my $SQL= "select SEARCH_CONDITION CONDITION from ALL_CONSTRAINTS AC " .
               "where " .
                   " AC.CONSTRAINT_NAME=\'$constraint_name\' AND " .
                   " AC.OWNER=\'$table_owner\' AND " .
                   " AC.CONSTRAINT_TYPE = 'C'";

     sql_trace($SQL) if ($sql_trace);
    my $res_r=
      $dbh->selectall_arrayref($SQL);

    if (!defined $res_r)
      { dberror($mod_l,'db_read_checks',__LINE__,
                "selectall_arrayref failed, errcode:\n$DBI::errstr");
        return;
      };

    my $r_line= $res_r->[0];
    if (!ref($r_line))
      { return; }; # empty

    my $text= $r_line->[0];
    #return( $res_r );
    return( $text );

  }

#-------------------------------------------------------------
# read triggertext
#-------------------------------------------------------------

sub read_triggertext
# EXPORTED
# reads the name, type, event, referer, clause, status
# body and description of a trigger
  { my($dbh,$trigger_name,$table_owner)= @_;

    $dbh= check_dbi_handle($dbh);
    return if (!defined $dbh);

    $trigger_name= uc($trigger_name);

    if ($trigger_name =~ /\./)
      { ($table_owner,$trigger_name)= split(/\./,$trigger_name); };

    die if (!defined $table_owner); # assertion !

    my $SQL= "select TRIGGER_NAME NAME, TRIGGER_TYPE TYPE, TRIGGERING_EVENT EVENT, " .
                   " REFERENCING_NAMES REFERER, WHEN_CLAUSE CLAUSE, STATUS, " .
                   " TRIGGER_BODY BODY, DESCRIPTION " .
                   " from ALL_TRIGGERS AT where" .
                   " AT.TRIGGER_NAME=\'$trigger_name\' AND " .
                   " AT.TABLE_OWNER=\'$table_owner\'";

    sql_trace($SQL) if ($sql_trace);
    my $res_r=
      $dbh->selectall_arrayref($SQL);

    if (!defined $res_r)
      { dberror($mod_l,'db_read_triggertext',__LINE__,
                "selectall_arrayref failed, errcode:\n$DBI::errstr");
        return;
      };

    return( @$res_r );
  }

#-------------------------------------------------------------
# read scripttext
#-------------------------------------------------------------

sub read_scripttext
# EXPORTED
# reads the name, type, text
  { my($dbh,$script_name,$user_name)= @_;

    $dbh= check_dbi_handle($dbh);
    return if (!defined $dbh);

    $script_name= uc($script_name);
    if ($script_name =~ /\./)
      { ($user_name,$script_name)= split(/\./,$script_name); };
    (my $owner,$script_name)=
                (dbdrv::real_name($dbh,$user_name,$script_name))[1,2];

    if (!defined $script_name)
      {
        dbwarn($mod_l,'db_read_scripttext',__LINE__,
               "warning:no script found for object $script_name");
        return;
      };

    if (!defined $owner || !defined $script_name ||
        $owner eq '' || $script_name eq '')
      { dberror($mod_l,'db_read_scripttext',__LINE__,
                "arguments not complete (assertion) \n" .
                "args:\"$owner.$script_name\"");
        return;
      };

    die if (!defined $owner); # assertion !

    my $SQL= "select text" .
                   " from ALL_SOURCE src where" .
                   " src.name=\'".uc($script_name)."\' AND " .
                   " src.owner=\'".uc($owner)."\'" .
                   " ORDER BY LINE ASC";

    sql_trace($SQL) if ($sql_trace);
    my $res_r=
      $dbh->selectall_arrayref($SQL);

    if (!defined $res_r)
      { dberror($mod_l,'db_read_scripttext',__LINE__,
                "selectall_arrayref failed, errcode:\n$DBI::errstr");
        return;
      };
      my @ret;
      foreach my $cols ( @$res_r)
        {
            push @ret, $cols->[0];
        }
#print Dumper(@ret);
    return( @ret );
  }

#=============================================================
# misc
#=============================================================

#-------------------------------------------------------------
# online-help
#-------------------------------------------------------------

sub get_help_topic
# EXPORTED
  {
    my($dbh)= @_;
    return if (! defined($dbh));
    my $fh;
    my $sth= dbdrv::prepare($fh, $dbh,
                         "SELECT DISTINCT topic FROM system.help " .
                          " ORDER BY topic");

    if (!dbdrv::execute($fh ,$dbh,$sth))
      {
        dbdrv::dbwarn($mod_l,'get_help_topic',__LINE__,
                 "execute() returned an error," .
                 " error-code: \n$DBI::errstr");
      }
    my $topic_list = $sth->fetchall_arrayref;
    $sth->finish;
    # $topic_list is a list of lists with one element
    # but we want to return a simple list:
    return(map{ $_->[0] } @$topic_list);
  }

#-------------------------------------------------------------
# string for row limitation
#-------------------------------------------------------------

sub query_limit_rows_str
# EXPORTED
# limit number of returned rows in a query
  { my($no)= @_;
    return("rownum<=$no","add_after_where");
  }


#-------------------------------------------------------------
# misc internal functions
#-------------------------------------------------------------

sub type_to_typechar
# internal
  { my($type)= @_;
    return( uc(substr($type,0,1)) );
  }


1;

__END__

SELECT distinct(asyn.table_name) FROM all_synonyms asyn, all_tables aobj
WHERE asyn.owner NOT IN ('SYSTEM', 'SYS') AND
  asyn.owner IN ('PUBLIC', 'GUEST') AND
  asyn.table_name=aobj.table_name;

SELECT distinct(asyn.table_name) FROM all_synonyms asyn, all_views aobj
WHERE asyn.owner NOT IN ('SYSTEM', 'SYS') AND
  asyn.owner IN ('PUBLIC', 'GUEST') AND
  asyn.table_name=aobj.view_name;

 perl -e 'use lib "."; use dbdrv; dbdrv::load("Oracle"); 
          dbdrv::connect_database("DBI:Oracle:devices","test2","blalaber");
          dbdrv::known_schemas("", "test2");
          dbdrv::disconnect_database(); print join("|",@a),"\n"; '

 perl -e 'use lib "."; use dbdrv; dbdrv::load("Oracle"); 
          dbdrv::connect_database("DBI:Oracle:devices","test2","blalaber");
          dbdrv::load_object_dict("","test2");
          dbdrv::dump_object_dict(); 
          dbdrv::disconnect_database(); print join("|",@a),"\n"; '

 perl -e 'use lib "."; use dbdrv; dbdrv::load("Oracle"); 
          dbdrv::connect_database("DBI:Oracle:devices","test2","blalaber");
          dbdrv::load_object_dict("","test2");
          print Data::Dumper($dbdrv::r_db_objects);
          dbdrv::disconnect_database(); '


