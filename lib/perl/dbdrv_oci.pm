# this is not a real perl-package
# it is loaded via "do" into dbdrv.pm !!

my $mod_l= "dbdrv_oci";

%sql_aliases = (
    "dependants" =>     "SELECT o.object_id, o.created, o.status, o.object_type, \
                                o.object_name, o.owner \
                            FROM sys.all_dependencies d, sys.all_objects o \
                            WHERE d.referenced_name = UPPER('##1##') AND\
                                d.owner = o.owner AND \
                                d.name = o.object_name AND \
                                o.object_type = 'VIEW' ORDER BY o.owner, o.object_name",
    "depends" =>        "SELECT o.object_id, o.created, o.status, o.object_name, o.owner \
                            FROM all_dependencies d, all_objects o \
                            WHERE d.name = UPPER('##1##') AND \
                                d.referenced_owner = o.owner AND \
                                d.referenced_name = o.object_name \
                            ORDER BY o.object_name",
    "viewtext" =>       "SELECT text \
                            FROM all_views \
                            WHERE view_name = UPPER('##1##')",
    "triggertext" =>    "SELECT trigger_type, triggering_event, trigger_body \
                            FROM dba_triggers \
                            WHERE trigger_name = UPPER('##1##')",
    "describe" =>       "SELECT column_name, table_name, owner, data_type, \
                                data_length, data_precision, data_scale, nullable, \
                                column_id, default_length, data_default, num_distinct, \
                                low_value, high_value
                            FROM all_tab_columns \
                            WHERE table_name = UPPER('##1##') \
                            ORDER BY column_id",
    "constraints" =>    "SELECT constraint_name, table_name, owner,constraint_type, \
                                r_owner, r_constraint_name, search_condition \
                            FROM all_constraints \
                            WHERE table_name = UPPER('##1##') \
                            ORDER BY constraint_name, r_owner, r_constraint_name",
    "triggers" =>       "SELECT DISTINCT trigger_name, owner, table_owner, table_name, \
                                trigger_type, triggering_event, status, referencing_names \
                            FROM dba_triggers \
                            WHERE table_name = UPPER('##1##') \
                            ORDER BY trigger_name, table_owner, table_name",
    "objects" =>        "SELECT object_name, status, object_type, owner \
                            FROM sys.all_objects \
                            WHERE object_name LIKE UPPER('##1##') AND\
                                NOT object_type = 'SYNONYM'",
    );

sub query_limit_rows_str
# limit number of returned rows in a query
  { my($no)= @_;
    return("rownum<=$no","add_after_where");
  }

sub get_simple_column_types
# returns for each column:
# 'number', 'string' or undef 
  { my($dbh,$sth,$tablename)= @_;
  
    my $type_no2string= db_types_no2string($dbh);

    my @x= map { $type_no2string->{$_} } @{$sth->{TYPE}};

    db_simplify_types(\@x);
    return(@x);
  }

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
#	      BOOL     =>  'number',
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

sub primary_keys
# returns the one primary key or the list of columns
# that form the primary key
  { my($dbh,$user_name,$table_name,$table_owner)= @_;

    $dbh= check_dbi_handle($dbh);
    return if (!defined $dbh);

    $table_name= uc($table_name);

    if ($table_name =~ /\./)
      { ($table_owner,$table_name)= split(/\./,$table_name); };

    if (!defined $table_owner)
      { ($table_name,$table_owner)=
                    dbdrv::real_name($dbh,$user_name,$table_name);
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

sub foreign_keys
  { my($dbh,$user_name,$table_name,$table_owner)= @_;

    $dbh= check_dbi_handle($dbh);
    return if (!defined $dbh);

    $table_name= uc($table_name);

    if ($table_name =~ /\./)
      { ($table_owner,$table_name)= split(/\./,$table_name); };

    if (!defined $table_owner)
      { ($table_name,$table_owner)=
                    dbdrv::real_name($dbh,$user_name,$table_name);
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


sub resident_keys
# the opposite of foreign keys,
# find where the primary key of this table is used as foreign key
  { my($dbh,$user_name,$table_name,$table_owner)= @_;

    $dbh= check_dbi_handle($dbh);
    return if (!defined $dbh);

    $table_name= uc($table_name);

    if ($table_name =~ /\./)
      { ($table_owner,$table_name)= split(/\./,$table_name); };

    if (!defined $table_owner)
      { ($table_name,$table_owner)=
                    dbdrv::real_name($dbh,$user_name,$table_name);
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

sub get_help_topic
  {
    my($dbh)= @_;
    return if (! defined($dbh));
    my $fh;
    my $sth= dbdrv::prepare($fh, $dbh,
                         "SELECT DISTINCT topic FROM system.help " .
                          " ORDER BY topic");

    if (!dbdrv::execute($fh ,$dbh,$sth))
      {
        dbdrv::dbwarn($mod,'get_help_topic',__LINE__,
                 "execute() returned an error," .
                 " error-code: \n$DBI::errstr");
      }
    my $topic_list = $sth->fetchall_arrayref;
    $sth->finish;
    # $topic_list is a list of lists with one element
    # but we want to return a simple list:
    return(map{ $_->[0] } @$topic_list);
  }

sub get_user_objects
# INTERNAL to dbdrv_oci!!!
# returns a ref to a hash : own.obj_name => [$type]
# type is 'T' (table) or 'V' (view)
# $t_name: table or view referred to
# $t_own: owner of referred table or view (equal to the $user-parameter)
  { my($dbh,$user,$r_tab)= @_;

    die if (!defined $r_tab);
    die if (ref($r_tab) ne 'HASH');

    return if (!defined $user);
    return if ($user eq "");

    $dbh= check_dbi_handle($dbh);
    return if (!defined $dbh);

    my $sql;

    $sql= "SELECT table_name from user_tables";

    sql_trace($sql) if ($sql_trace);

    my $res= $dbh->selectall_arrayref($sql);

    if (!defined $res)
      { dberror($mod_l,'sql_request_to_hash',__LINE__,
                "selectall_arrayref failed, errcode:\n$DBI::errstr");
        return;
      };

    # hash: [type('T'or'V'),owner,table-name,table-owner
    foreach my $line (@$res)
      { $r_tab->{ $user . '.' . $line->[0] } = ['T']; };

    $sql= "SELECT view_name from user_views";

    sql_trace($sql) if ($sql_trace);

    $res= $dbh->selectall_arrayref($sql);

    if (!defined $res)
      { dberror($mod_l,'sql_request_to_hash',__LINE__,
                "selectall_arrayref failed, errcode:\n$DBI::errstr");
        return;
      };

    # hash: [type('T'or'V'),owner,table-name,table-owner
    foreach my $line (@$res)
      { $r_tab{ $user . '.' . $line->[0] } = ['V'];
      };

    #print Dumper($r_tab);
    return(1);
  }

sub get_synonyms
# INTERNAL to dbdrv_oci!!!
# returns a ref to a hash : syn_name => [$type, "$t_own.$t_name"]
# type is 'T' (table) or 'V' (view)
# $t_name: table or view referred to
# $t_own: owner of referred table or view
# $r_reverse_syn : a hash: owner.table => synonym
  { my($dbh,$r_syn,$r_reverse_syn)= @_;

    die if (!defined $r_syn);
    die if (ref($r_syn) ne 'HASH');

    $dbh= check_dbi_handle($dbh);
    return if (!defined $dbh);

    my $sql;

    $sql= "SELECT asyn.synonym_name,asyn.owner, " .
                  "asyn.table_name,asyn.table_owner " .
          "FROM all_synonyms asyn, all_tables at " .
          "WHERE " .
                   "asyn.table_owner NOT IN ('SYS', 'SYSTEM') AND " .
                   "asyn.table_name=at.table_name AND " .
                   "asyn.table_owner=at.owner" ;

    sql_trace($sql) if ($sql_trace);

    my $res= $dbh->selectall_arrayref($sql);

    if (!defined $res)
      { dberror($mod_l,'sql_request_to_hash',__LINE__,
                "selectall_arrayref failed, errcode:\n$DBI::errstr");
        return;
      };

    # hash: [type('T'or'V'),owner,table-name,table-owner
    foreach my $line (@$res)
      { my $syn= $line->[1] . '.' . $line->[0];
        my $obj= $line->[3] . '.' . $line->[2];

        $r_syn->{$syn} = ['T', $obj ];

        if (!exists $r_reverse_syn->{$obj})
          { $r_reverse_syn->{$obj}= [$syn]; }
        else
          { push @{$r_reverse_syn->{$obj}}, $syn; };
      };


    $sql= "SELECT asyn.synonym_name,asyn.owner, " .
                  "asyn.table_name,asyn.table_owner " .
          "FROM all_synonyms asyn, all_views av " .
          "WHERE " .
                   "asyn.table_owner NOT IN ('SYS', 'SYSTEM') AND " .
                   "asyn.table_name=av.view_name AND " .
                   "asyn.table_owner=av.owner" ;

    sql_trace($sql) if ($sql_trace);

    $res= $dbh->selectall_arrayref($sql);

    if (!defined $res)
      { dberror($mod_l,'sql_request_to_hash',__LINE__,
                "selectall_arrayref failed, errcode:\n$DBI::errstr");
        return;
      };

    # hash: [type('T'or'V'),synonym-owner,table-name,table-owner
    foreach my $line (@$res)
      { my $syn= $line->[1] . '.' . $line->[0];
        my $obj= $line->[3] . '.' . $line->[2];

        $r_syn->{$syn} = ['V', $obj ];

        if (!exists $r_reverse_syn->{$obj})
          { $r_reverse_syn->{$obj}= [$syn]; }
        else
          { push @{$r_reverse_syn->{$obj}}, $syn; };
      };

    #print Dumper($r_syn);
    return(1);
  }

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
          { dberror($mod,'load_object_dict',__LINE__,
                    'loading of user-objects failed');
            return;
          };
      };

    if (!get_synonyms($dbh,$r_db_objects,$r_db_reverse_synonyms))
      { dberror($mod,'load_object_dict',__LINE__,
                'loading of synonyms failed');
        return;
      };
  }

sub check_existence
  { my($dbh,$table_name,$user_name)= @_;

    # when the table has the form "owner.table", the check cannot
    # be made, since it's no public synonym and not in the
    # synonym list
    return(1) if ($table_name=~ /\./);

    $dbh= check_dbi_handle($dbh);
    return if (!defined $dbh);

    my $obj_name= "PUBLIC." . uc($table_name);

    load_object_dict($dbh,$user_name);

    return( exists $r_db_objects->{$obj_name} );
  }

sub accessible_objects
  { my($dbh,$user_name,$types,$access)= @_;
    my %known_types= (table => 'T', view => 'V');
    my %known_acc  = map { $_ =>1 } qw( user public );
    my %types;
    my %access;


    $dbh= check_dbi_handle($dbh);
    return if (!defined $dbh);

    if (!defined $types)
      { %types= (T=>1); }
    else
      { $types= lc($types);
        my @types= split(",",$types);
        foreach my $t (@types)
          { my $c= $known_types{$t};
            if (!defined $c)
              { dberror($mod,'accessible_objects',__LINE__,
                    "unknown object type: $t");
                return;
              };
            $types{$c}=1;
          };
      };

    load_object_dict($dbh,$user_name);
    my @keys= keys %$r_db_objects;

#print Dumper(\%types);

    if ((!exists $types{T}) || (!exists $types{V}))
      { # there are only tables and views, so only if not BOTH
        # are wanted, we have to filter
        if (exists $types{T})
          { @keys= grep { $r_db_objects->{$_}->[0] eq 'T' } @keys; }
        else
          { @keys= grep { $r_db_objects->{$_}->[0] eq 'V' } @keys; };
      };


    if (!defined $access)
      { %access= ("public" => 1); }
    else
      { $access= lc($access);
        %access= map { $_ => 1} split(",",$access);
        foreach my $t (keys %access)
          { if (!exists $known_acc{$t})
              { dberror($mod,'accessible_objects',__LINE__,
                    "unknown object access type: $t");
                return;
              };
          };
      };

    my @result;

    if (exists $access{public})
      { push @result,
             grep { /^PUBLIC\./ } @keys;
      };

    if (exists $access{user})
      { push @result,
             grep { /^$user_name\./ } @keys;
      };

    #warn join("|",@result) . "\n";

    map { $_=~ s/^[^\.]+\.// } @result; # remove "owner"

#print Dumper(\@result);

    return(sort @result);
  }

sub real_name
# resolves a given table-name or synonym,
# returns the table-owner and the table-name
# NOTE: user-name is not the owner of the table but the user
# that has logged in
  { my($dbh,$user_name,$object_name)= @_;

    $dbh= check_dbi_handle($dbh);
    return if (!defined $dbh);

    $user_name= uc($user_name);

    load_object_dict($dbh,$user_name);

    if ($object_name !~ /\./) # not in the form user.tablename
      { $object_name= "PUBLIC." . $object_name; };


    my $data= $r_db_objects->{$object_name};

    return if (!defined $data); # not in list of synonyms and
                                # user objects

    # user objects have only a type-field (why?)

    if ($#$data>0) # more than 2 objects in hash:synonym
      { my($owner,$name)= split(/\./, $data->[1]);

        return($name,$owner);
      };

    return( $object_name, $user_name );
  }

sub canonify_name
  { my($dbh,$user_name,$object_name,$object_owner)= @_;

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

    foreach my $n (@$r_list)
      { my($owner,$obj)= split(/\./,$n);
        if ($owner eq 'PUBLIC')
          { return($obj); };
      };

    return($name);
  }

sub object_is_table
# return 1 when it is a table
  { my($dbh,$table_name,$table_owner)= @_;

    $dbh= check_dbi_handle($dbh);
    return if (!defined $dbh);

    $table_name= uc($table_name);

    if ($table_name =~ /\./)
      { ($table_owner,$table_name)= split(/\./,$table_name); };

    if (!defined $table_owner)
      { ($table_name,$table_owner)=
                    dbdrv::real_name($dbh,$table_owner,$table_name);
      };

    return(0) if (!defined $table_owner);
    # shouldn't happen !

    my $SQL= "select OWNER,TABLE_NAME from " .
             "all_tables " .
             "where table_name=\'$table_name\' and owner=\'$table_owner\'";

    sql_trace($SQL) if ($sql_trace);
    my $res_r=
      $dbh->selectall_arrayref($SQL);

    if (!defined $res_r)
      { dberror($mod_l,'db_object_addicts',__LINE__,
                "selectall_arrayref failed, errcode:\n$DBI::errstr");
        return;
      };

    if (@$res_r)
      { return(1); };
    return(0);
  }



sub object_dependencies
# read the owner, name and of type dependend objects,
# type is either "TABLE" or "VIEW"
  { my($dbh,$table_name,$table_owner)= @_;

    $dbh= check_dbi_handle($dbh);
    return if (!defined $dbh);

    $table_name= uc($table_name);

    if ($table_name =~ /\./)
      { ($table_owner,$table_name)= split(/\./,$table_name); };

    if (!defined $table_owner)
      { ($table_name,$table_owner)=
                    dbdrv::real_name($dbh,$table_owner,$table_name);
      };

    if (!defined $table_owner) # assertion !
      { dbwarn($mod,'object_dependencies',__LINE__,
               "no table owner found for");
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

sub object_references
# read the owner, name  and of referenced objects
  { my($dbh,$table_name,$table_owner)= @_;

    $dbh= check_dbi_handle($dbh);
    return if (!defined $dbh);

    $table_name= uc($table_name);

    if ($table_name =~ /\./)
      { ($table_owner,$table_name)= split(/\./,$table_name); };

    if (!defined $table_owner)
      { ($table_name,$table_owner)=
                    dbdrv::real_name($dbh,$table_owner,$table_name);
      };

    die if (!defined $table_owner); # assertion !

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

sub object_addicts
# INTERNAL
# read all constraints and triggers for the given object
  { my($dbh,$table_name,$table_owner)= @_;

    $dbh= check_dbi_handle($dbh);
    return if (!defined $dbh);

    $table_name= uc($table_name);

    if ($table_name =~ /\./)
      { ($table_owner,$table_name)= split(/\./,$table_name); };

    if (!defined $table_owner)
      { ($table_name,$table_owner)=
                    dbdrv::real_name($dbh,$table_owner,$table_name);
      };

    die if (!defined $table_owner); # assertion !

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

sub read_viewtext
# INTERNAL
# read the text of a view
  { my($dbh,$table_name,$table_owner)= @_;

    $dbh= check_dbi_handle($dbh);
    return if (!defined $dbh);

    $table_name= uc($table_name);

    if ($table_name =~ /\./)
      { ($table_owner,$table_name)= split(/\./,$table_name); };

    if (!defined $table_owner)
      { ($table_name,$table_owner)=
                    dbdrv::real_name($dbh,$table_owner,$table_name);
      };

    die if (!defined $table_owner); # assertion !

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

sub read_checktext
# INTERNAL
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

sub read_triggertext
# INTERNAL
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


sub sql_request_to_hash
# internal
  { my($dbh,$sql,$r_h)= @_;

    sql_trace($sql) if ($sql_trace);

    my $res=
      $dbh->selectall_arrayref($sql);

    if (!defined $res)
      { dberror($mod_l,'sql_request_to_hash',__LINE__,
                "selectall_arrayref failed, errcode:\n$DBI::errstr");
        return;
      };
    foreach my $line (@$res)
      { $r_h->{$line->[0]}= 1;
      };
  };



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



 perl -e 'use lib "."; use dbdrv; dbdrv::load("Oracle"); \
          dbdrv::connect_database("DBI:Oracle:bii_par","pfeiffer","xxx");\
	  dbdrv::load_object_dict("","pfeiffer"); \
	  dbdrv::dump_object_dict(); \
	  dbdrv::disconnect_database(); print join("|",@a),"\n"; '

 perl -e 'use lib "."; use dbdrv; dbdrv::load("Oracle"); \
          dbdrv::connect_database("DBI:Oracle:bii_par","pfeiffer","xxx");\
	  dbdrv::load_object_dict("","pfeiffer"); \
	  print Data::Dumper($dbdrv::r_db_objects);\
	  dbdrv::disconnect_database(); '


