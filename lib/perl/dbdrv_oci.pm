# this is not a real perl-package
# it is loaded via "do" into dbdrv.pm !!


my $mod_l= "dbdrv_oci";

sub check_existence
# returns the one primary key or the list of columns
# that form the primary key
  { my($dbh,$table_name)= @_;
  
    $dbh= check_dbi_handle($dbh);
    return if (!defined $dbh);
      
    $table_name= uc($table_name);
    

    my $SQL= "SELECT * from all_objects " .
             "WHERE object_name=\'$table_name\' " .
	           " AND object_type IN (\'TABLE\',\'VIEW\')";

    sql_trace($SQL) if ($sql_trace);
    
    my $res=
      $dbh->selectall_arrayref($SQL);
		      	   
    if (!defined $res)
      { dberror($mod_l,'db_check_existence',__LINE__,
                "selectall_arrayref failed, errcode:\n$DBI::errstr"); 
        return;
      };

    # returns  OWNER TABLE_NAME COLUMN_NAME  

    # NOTE: in some tables, only the combination of several rows is
    # the primary key, in this case, the SQL statement above returns
    # more than a single line. 
    
    if (!@$res)
      { return; }; # doesn't exist
    return(1);
  }

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
		   "CL2.COLUMN_NAME AS FOREIGN_COLUMN " .
		   "FROM " .
		   "all_cons_columns CL, all_cons_columns CL2, " .
		   "all_constraints ST, all_constraints ST2 " .
		   "WHERE " .
		   "ST.TABLE_NAME=\'$table_name\' AND ".
		   "ST.CONSTRAINT_TYPE=\'R\' AND " .
		   "ST.CONSTRAINT_NAME=CL.CONSTRAINT_NAME AND " .
		   "ST.R_CONSTRAINT_NAME= ST2.CONSTRAINT_NAME AND " .
		   "CL2.CONSTRAINT_NAME=ST2.CONSTRAINT_NAME";   
    sql_trace($SQL) if ($sql_trace);
    my $res=
      $dbh->selectall_arrayref($SQL);
    # gives:
    # TABLE_NAME COLUMN_NAME CONSTRAINT_NAME R_CONSTRAINT_NAME 
    #          FOREIGN_TABLE FOREIGN_COLUMN 
	
		      	   
    if (!defined $res)
      { dberror($mod_l,'db_get_foreign_keys',__LINE__,
                "selectall_arrayref failed, errcode:\n$DBI::errstr"); 
        return;
      };

    # build a hash,
    # col_name => [foreign_table,foreign_column]
    my %foreign_keys;
    foreach my $r_line (@$res)
      { $foreign_keys{ $r_line->[1] } = [ $r_line->[4],$r_line->[5] ]; };

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

sub accessible_public_objects
# returns the one primary key or the list of columns
# that form the primary key
  { my($dbh,$type,$user_name)= @_;
  
    $dbh= check_dbi_handle($dbh);
    return if (!defined $dbh);
      
    if (!defined $type)
      { $type= "table"; }
    else
      { $type= lc($type);
        if (($type ne "table") && ($type ne "view"))
	  { dberror($mod_l,'accessible_objects',__LINE__,
                "unknown object type: $type"); 
            return;
          };
      };
      
    my @users= ('PUBLIC');
    if (defined $user_name)
      { push @users, $user_name; };
    
    my $owner_filter;
    if ($#users<=0)
      { $owner_filter= "asyn.owner=\'$users[0]\'"; }
    else
      { $owner_filter= "asyn.owner IN (" .
                        join(", ", map { "\'$_\'" } @users) .
		       ")";
      };		       
     
#$sql_trace=1; 

    my $SQL= "SELECT asyn.synonym_name " .
             "FROM all_synonyms asyn, all_${type}s aobj " .
	     "WHERE $owner_filter AND " .

	     "asyn.table_owner NOT IN (\'SYS\', \'SYSTEM\') AND " .

  	     "asyn.table_name=aobj.${type}_name AND " .
	     "asyn.table_owner=aobj.owner";
    
    sql_trace($SQL) if ($sql_trace);
    
    my $res=
      $dbh->selectall_arrayref($SQL);
		      	   
    if (!defined $res)
      { dberror($mod_l,'accessible_tables',__LINE__,
                "selectall_arrayref failed, errcode:\n$DBI::errstr"); 
        return;
      };
    my @list;
    foreach my $line (@$res)
      { push @list, $line->[0];
      };

    #print join(",",@list),"\n";
    return( sort @list );
  }

sub accessible_user_objects
# returns the one primary key or the list of columns
# that form the primary key
  { my($dbh,$type)= @_;
  
    $dbh= check_dbi_handle($dbh);
    return if (!defined $dbh);
      
    if (!defined $type)
      { $type= "table"; }
    else
      { $type= lc($type);
        if (($type ne "table") && ($type ne "view"))
	  { dberror($mod_l,'accessible_objects',__LINE__,
                "unknown object type: $type"); 
            return;
          };
      };
    
#$sql_trace=1; 

    my $SQL= "SELECT ${type}_name " .
             "FROM user_${type}s aobj";

    sql_trace($SQL) if ($sql_trace);
    
    my $res=
      $dbh->selectall_arrayref($SQL);
		      	   
    if (!defined $res)
      { dberror($mod_l,'accessible_user_objects',__LINE__,
                "selectall_arrayref failed, errcode:\n$DBI::errstr"); 
        return;
      };
    my @list;
    foreach my $line (@$res)
      { push @list, $line->[0];
      };

    #print join(",",@list),"\n";
    return( sort @list );
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
                                                                                  
