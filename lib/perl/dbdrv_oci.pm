# this is not a real perl-package
# it is loaded via "do" into dbdrv.pm !!


my $mod_l= "dbdrv_oci";

sub primary_keys
# returns the one primary key or the list of columns
# that form the primary key
  { my($dbh,$table_name)= @_;
  
    $dbh= check_dbi_handle($dbh);
    return if (!defined $dbh);

    $table_name= uc($table_name);
    
    my $SQL= "SELECT a.owner, a.table_name, b.column_name " .
             "FROM all_constraints a, all_cons_columns b " .
	     "WHERE a.constraint_type='P' AND " .
		  " a.constraint_name=b.constraint_name AND " .
		  " a.table_name = \'$table_name\'";
    
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
  { my($dbh,$table_name)= @_;

    $dbh= check_dbi_handle($dbh);
    return if (!defined $dbh);

    $table_name= uc($table_name);
    my $SQL="select ST.TABLE_NAME, CL.COLUMN_NAME, " .
                   "ST.CONSTRAINT_NAME, ST.R_CONSTRAINT_NAME, " .
		   "CL2.TABLE_NAME AS FOREIGN_TABLE, " .
		   "CL2.COLUMN_NAME AS FOREIGN_COLUMN, " .
		   "ST.OWNER, ST2.OWNER " .
		   "FROM " .
		   "all_cons_columns CL, all_cons_columns CL2, " .
		   "all_constraints ST, all_constraints ST2 " .
		   "WHERE " .
		   "ST.TABLE_NAME=\'$table_name\' AND ".
		   "ST.CONSTRAINT_TYPE=\'R\' AND " .
		   "ST.CONSTRAINT_NAME=CL.CONSTRAINT_NAME AND " .
		   "ST.R_CONSTRAINT_NAME= ST2.CONSTRAINT_NAME AND " .
		   "CL2.CONSTRAINT_NAME=ST2.CONSTRAINT_NAME AND ".
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
    # col_name => [foreign_table,foreign_column]
    my %foreign_keys;
    foreach my $r_line (@$res)
      { # owner mismatch
        next if ($r_line->[6] ne $r_line->[7]);
      
        $foreign_keys{ $r_line->[1] } = [ $r_line->[4],$r_line->[5] ]; 
      };

    return( \%foreign_keys);
  }


sub resident_keys
# the opposite of foreign keys,
# find where the primary key of this table is used as foreign key
  { my($dbh,$table_name)= @_;

    $dbh= check_dbi_handle($dbh);
    return if (!defined $dbh);

    $table_name= uc($table_name);
    my $SQL= "select ST.TABLE_NAME, CL.COLUMN_NAME, ST.CONSTRAINT_NAME, " .
		   " ST2.TABLE_NAME AS R_TABLE, " .
		   " CL2.COLUMN_NAME AS R_COLUMN, " .
		   " ST2.CONSTRAINT_NAME AS R_CONSTRAINT_NAME " .
	     "from  " .
	     "all_constraints ST, all_constraints ST2,  " .
	     "all_cons_columns CL, all_cons_columns CL2 " .
	     "where  ST.TABLE_NAME=\'$table_name\' AND " .
		   " ST.CONSTRAINT_TYPE='P' AND " .
		   " ST.CONSTRAINT_NAME=ST2.R_CONSTRAINT_NAME AND " .
		   " ST2.CONSTRAINT_TYPE='R' AND " .
		   " ST.CONSTRAINT_NAME=CL.CONSTRAINT_NAME AND " .
		   " ST2.CONSTRAINT_NAME=CL2.CONSTRAINT_NAME ";

    sql_trace($SQL) if ($sql_trace);
    my $res=
      $dbh->selectall_arrayref($SQL);
    # gives:
    # TABLE_NAME COLUMN_NAME CONSTRAINT_NAME R_TABLE R_COLUMN R_CONSTRAINT_NAME 
	
    if (!defined $res)
      { dberror($mod_l,'db_get_resident_keys',__LINE__,
                "selectall_arrayref failed, errcode:\n$DBI::errstr"); 
        return;
      };

    # build a hash,
    # col_name => [ [resident_table1,resident_column1],
    #               [resident_table2,resident_column2], 
    #                    ...
    #             ]
    #      resident_table may occur more than once
    if ($#$res < 0)
      { # no resident keys found, just return "undef"
        return;
      };
      
    my %resident_keys;
    foreach my $r_line (@$res)
      { 
        push @{ $resident_keys{ $r_line->[1] } },
	         [ $r_line->[3],$r_line->[4] ]; 
      };

    return( \%resident_keys);
  }


sub get_user_objects
# INTERNAL
# returns a ref to a hash : obj_name => [$type, $own]
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
      { $r_tab->{ $line->[0] } = ['T',$user ]; };
      
    $sql= "SELECT view_name from user_views";
      
    sql_trace($sql) if ($sql_trace);

    my $res= $dbh->selectall_arrayref($sql);

    if (!defined $res)
      { dberror($mod_l,'sql_request_to_hash',__LINE__,
                "selectall_arrayref failed, errcode:\n$DBI::errstr"); 
        return;
      };
      
    # hash: [type('T'or'V'),owner,table-name,table-owner
    foreach my $line (@$res)
      { $r_tab{ $line->[0] } = ['V',$user ]; 
      };
     
    #print Dumper($r_tab);
    return(1);
  } 
     
sub get_synonyms
# INTERNAL
# returns a ref to a hash : syn_name => [$type, $own, $t_name, $t_own]
# type is 'T' (table) or 'V' (view)
# $t_name: table or view referred to
# $t_own: owner of referred table or view
  { my($dbh,$r_syn)= @_;
    
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
      { $r_syn->{ $line->[0] } = 
                    ['T',$line->[1], $line->[2], $line->[3] ]; };


    $sql= "SELECT asyn.synonym_name,asyn.owner, " .
                  "asyn.table_name,asyn.table_owner " . 
          "FROM all_synonyms asyn, all_views av " .
          "WHERE " . 
                   "asyn.table_owner NOT IN ('SYS', 'SYSTEM') AND " .
                   "asyn.table_name=av.view_name AND " . 
                   "asyn.table_owner=av.owner" ;
		      
    sql_trace($sql) if ($sql_trace);

    my $res= $dbh->selectall_arrayref($sql);

    if (!defined $res)
      { dberror($mod_l,'sql_request_to_hash',__LINE__,
                "selectall_arrayref failed, errcode:\n$DBI::errstr"); 
        return;
      };

    # hash: [type('T'or'V'),owner,table-name,table-owner
    foreach my $line (@$res)
      { $r_syn->{ $line->[0] } 
                 = ['V',$line->[1], $line->[2], $line->[3] ]; };

    #print Dumper($r_syn);
    return(1);
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
                                                                                  
