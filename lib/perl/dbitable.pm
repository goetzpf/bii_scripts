#########################################################################
#   dbitable - a object oriented package for managing database tables
#
#   To learn more: enter "perldoc dbitable.pm" at the command prompt,
#   or search in this file for =head1 and read the text below it
#
#########################################################################

package dbitable;

use v5.6.0;

use strict;

use DBI;
use Data::Dumper;
use Text::Wrap;
use Text::ParseWords;

# use DBD::AnyData;

our $VERSION     = '1.0';

our $export_version= "1.0";

our $sql_trace= 0;
our $db_trace=0;
our $prelim_key=0;

my $slim_format=0; # do not save all elements of "table" element

my $key_fact= 100000; # for pseudo-random key generation
                      # the primary keys in the table should not
		      # be greater than this value !

my $std_dbh; # internal standard database-handle

# variables for the gen_sort function:
my $gen_sort_href;
my @gen_sort_cols;
my $gen_sort_r_coltypes;

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

#print "*** DBNAme: ",$dbname," dbh: $dbh\n"; #@@@
    if (!defined $dbh)
      { warn "unable to connect to database, error-code: \n$DBI::errstr"; 
        return;
      };
      
    $std_dbh= $dbh;
    return($dbh);
  }
   
sub disconnect_database
  { my($dbh)= @_;
  
    if (!defined $dbh)
      { $dbh= $std_dbh; }
    elsif ($dbh eq "")
      { $dbh= $std_dbh; };
  
    if (!$dbh->disconnect()) 
      { warn "disconnect returned an error, error-code: \n$DBI::errstr"; };
  }

sub new
  { # perl-Kochbuch, S. 486 "Klassen,Objekte und Ties
    my $proto= shift;
    
    my $class;
    my $parent;
    
    if (ref($proto)) # a parent object is given
      { $parent= $proto;
        $class = ref($proto);
      }
    else             # no parent, just the class-name is given
      { $class= $proto; }; # parent remains undef
    
    my $self; 

    # the base-class mechanism is not yet tested!
#    if (@ISA && $class->SUPER::can('new')
#      { $self= $class->SUPER::new(@_); }
#    else
      { $self= {}; };
      
    bless($self, $class);
    
    if (defined $parent)                 
      { my $newtype= shift; # this is optional
      
        # deep copy of the parent data-structure
	foreach my $k (keys %$parent)
          { 
	    if ($k eq '_lines')
	      { 
	        my %h;
	        my $r_src_lines= $parent->{$k};
	        foreach my $pk (keys %{$r_src_lines})
		  { my @a= @{$r_src_lines->{$pk}};
		    $h{$pk}= \@a;
		  };
	        $self->{$k}= \%h;
		next;
	      };
	    my $ref= ref($self->{$k});
	    if (!$ref)
	      { $self->{$k}= $parent->{$k}; 
	        next; 
	      };
	    if ($ref eq 'HASH')
	      { my %h= %{$parent->{$k}};
	        $self->{$k}= \%h;
		next;
	      };
	    if ($ref eq 'ARRAY')
	      { my @l= @{$parent->{$k}};
	        $self->{$k}= \@l;
		next;
              };
	  };

#warn "XXXstab: " . $self->{_table};
	if (defined $newtype)
	  {
#print "HERE: ",__LINE__,"\n"; #@@@
# the following is better done always, regardless wether the 
# type is changed. For example, the user might simply want to change
# the database-handle, not the type
	    if ($newtype ne $self->{_type})
	      { 
	        if ($newtype eq 'file')
		  { $self->init_filetype($newtype,@_); }

		elsif (($newtype eq 'table') || ($newtype eq 'view') ||
		      ($newtype eq 'new_table')
		      )
		  { $self->init_tableviewtype($newtype,@_); }
		else
		  { die "unknown type: $newtype"; };   
              };
	  };
	return($self);
      }
    else
      { # direct initialization
	my $type= shift; $type= lc($type);
        $self->{_type}= $type;
	
	if   ($type eq 'file')
	  { $self->init_filetype('file',@_); 
	    
	  }
	  
	elsif (($type eq 'table') || ($type eq 'view'))
	  { $self->init_tableviewtype($type,@_);
          }
	else
	  { die "unknown dbitable-type: \"$type\""; };
	return($self);
      };  
    return($self);  
  }  

sub init_filetype
#internal
  { my $self= shift;
    

#print "INIT FILETYPE\n"; # @@@
    $self->{_type}= shift;
    my $filename= shift;
    die "type \'file\': filename parameter missing"
      if (!defined $filename);
    $self->{_filename}= $filename;
    my $tag= shift;
    die "type \'file\': tag parameter missing"
      if (!defined $tag);
    $self->{_tag}= $tag;
    return if (!@_); # optional, primary key + column-list

    $self->init_columns(@_);
  }   

sub init_tableviewtype    
#internal
# the type-parameter was already checked
  { my $self= shift;
    my $type= shift;
    $self->{_type}= $type;

    my $dbh= shift;
    # die if (!defined $dbh);
    
    # test wether to use internal standard database handle
    if (!defined $dbh)
      { $dbh= $std_dbh; }
    elsif ($dbh eq "") 
      { $dbh= $std_dbh; };
    
    if (ref($dbh) !~ /^DBI::/)
      { die "error: parameter is not a DBI handle!"; };
    $self->{_dbh}= $dbh; 
    
    # if self->{_table} already exists, take this if no table
    # parameter is found in the argument-list    
    my $table= shift;
    if ((!defined $table) || ($table eq ""))
      { if (exists $self->{_table})
          { $table= $self->{_table}; }
      };
    die "table name missing" if (!defined $table);
 
    # if self->{_pk} already exists, take this if no primary-key
    # parameter is found in the argument-list    
    my $primary_key= shift; $primary_key= uc($primary_key);
    if ((!defined $primary_key) || ($primary_key eq ""))
      { if (exists $self->{_pk})
          { $primary_key= $self->{_pk}; }
	else
	  { # try to determine primary key by a tricky SQL statement:
	    $primary_key= db_get_primary_key($dbh,$table);
	    
	    #die "primary_key: $primary_key";
	  };  
      };
    die "primary key name missing" if (!defined $primary_key);

    $self->{_table}= $table;
    $self->{_pk}   = $primary_key;
    
    my $sql_statement= "select * from $table";
    if ($type eq 'view')
      { $sql_statement= shift; 
	die "sql-statement missing" if (!defined $sql_statement);
      };
    $self->{_fetch_cmd}= $sql_statement;
    
    if ($type eq 'new_table') # no column-lookup in this case
      { $self->{_type}= 'table'; # change type to 'table'
        return; 
      };
    # no SQL Trace here:

    my $sth= $dbh->prepare($self->{_fetch_cmd})
        or die "prepare failed," .
               " error-code: \n$DBI::errstr";

    my $colcount=0;
#print "***KEYS: ",join("|",(keys %$sth)),"\n"; # @@@
#print "XXX $sth->{NAME_uc}\n"; # @@@
    my @column_list= @{$sth->{NAME_uc}};
    
    my $type_no2string= db_types_no2string($dbh);
    
    my @x= map { $type_no2string->{$_} } @{$sth->{TYPE}};
    db_simplify_types(\@x);
    $self->{_types}= \@x;
    
#warn join("|",@x);
#print Dumper($dbh->type_info_all);


    $self->init_columns($primary_key,@column_list);
  }   

sub init_columns
#internal
  { my $self= shift;
    my ($pk,@columns)= @_;

    $pk= uc($pk);
    foreach my $c (@columns)
      { $c= uc($c); };

    my $exist_columns= $self->{_column_list};
    my $exist_pk= $self->{_pk}; 
    if (defined $exist_pk)
      { if ($pk!= $exist_pk)
          { die "error: existing primary key != new primary key,\n" .
	        "$exist_pk != $pk";
	  };
      }
    else
      { $self->{_pk}= $pk; };
       
    if (defined $exist_columns)
      { my $st1= join(",",(@$exist_columns));
        my $st2= join(",",(@columns));
        if ($st1 != $st2)
          { die "error: existing columns != new columns,\n" .
	        "$st1\n  !=\n$st2";
	  };
      }
    else
      { $self->{_column_list}= \@columns;
	my $i=0;
	my %h= map { $_ => $i++ } @columns;
	$self->{_columns}= \%h; 
      };
    $self->{_pki}= $self->{_columns}->{$self->{_pk}};
  }            
     

sub load 
  { my $self= shift;
    my $type= $self->{_type};
    
    if (($type eq 'table') || ($type eq 'view'))
      { return( $self->load_from_db(@_) ); }
    if ($type eq 'file')
      { return( $self->load_from_file(@_) ); };
    die "unknown type: $type";
  }
    

sub store
  { my $self= shift;
    my $type= $self->{_type};
    
    if (($type eq 'table') || ($type eq 'view'))
      { return( $self->store_to_db(@_) ); }
    if ($type eq 'file')
      { return( $self->store_to_file(@_) ); };
    die "unknown type: $type";
  }

sub import_table 
# options: mode=> 'add_lines' or 'set_lines
#          primary_key=> 'generate', 'preserve'
#          column_aliases=> hash reference
  { my $self= shift;
    my $other= shift;
    my %options= @_;
    my $v;

    $v= $options{mode};
    if    (!defined $v)
      { $options{mode}= 'add_lines'; }
    elsif (($v ne 'add_lines') && ($v ne 'set_lines'))
      { die "unknown import-mode:$v"; }; 

    $v= $options{primary_key};
    if    (!defined $v)
      { $options{primary_key}= 'generate'; }
    elsif (($v ne 'preserve') && ($v ne 'generate'))
      { die "unknown primary-key-mode:$v"; }; 
 
    my $r_column_aliases= $options{column_aliases};
      # self->other column mapping
      # may be omitted if tables have the same columns
    my $self_columns = $self->{_columns};
    my $other_columns= $other->{_columns};

    my $pki= $self->{_pki};
    my $self_column_no= $#{$self->{_column_list}} + 1;
    
    my %col_mapping;
    
    foreach my $scol (keys %$self_columns)
      { my $s_i= $self_columns->{$scol}; # self col-index
        my $o_i;
	$o_i= $other_columns->{$scol};   # other col-index
	if (defined $r_column_aliases) # if col-mapping exists
	  { # test wether a column-alias for this column exists
	    my $o= $r_column_aliases->{$scol}; 
	    if (defined $o)
	      { $o_i= $other_columns->{$o}; };
	  };
      
        if (defined $o_i)               # if an associated col was found:
          { $col_mapping{$s_i}= $o_i; };  
      };      
      
    my $mapped_pki= $col_mapping{ $pki };
    
    if (!defined $mapped_pki)
      { die "error: no mapping for primary key defined, cannot import"; };
    
    my $r_other_lines= $other->{_lines};
    my $r_self_lines  = $self->{_lines};
    my $r_self_aliases= $self->get_hash("_aliases");
    
    my %found_lines;

    foreach my $other_pk (keys %{$r_other_lines})
      { my $r_other_line= $r_other_lines->{$other_pk};
        my $self_pk= $r_other_line->[$mapped_pki]; 
	next if (!defined $self_pk);
        
        my $r_self_line= $r_self_lines->{$self_pk};
	my $operation;
	if (!defined $r_self_line)
	  { if ($options{primary_key} eq 'generate')
	      { $self_pk= $self->new_prelim_key(); };
	    my @l; 
	    $r_self_line= \@l;
	    $r_self_lines->{$self_pk}= \@l; 
	    $r_self_aliases->{$self_pk}= $self_pk;
	    $r_self_line->[$pki]= $self_pk;
	    $self->{_inserted}->{$self_pk}= 1;
	    $operation= 'inserted';
	  };
	$found_lines{$self_pk}=1;
	
	for(my $i=0; $i<$self_column_no; $i++)
	  { next if ($i==$pki);
	    my $other_val="";
	    my $index= $col_mapping{$i};
	    if (defined $index) # if a col-mapping exists
	      { $other_val= $r_other_line->[ $index ]; };
	    # $other_val= "" if (!defined $other_val);
	    if (!$operation)
	      { 
	        if ($r_self_line->[$i] ne $other_val)
	          { 
		    $operation= "updated"; 
		  };
	      };
	    $r_self_line->[$i]= $other_val;
	  };
	if ($operation eq "updated")
	  { $self->{_updated}->{$self_pk}= 1; };
      };
    # delete lines not found in the "other" table  
    if ($options{mode} eq 'set_lines')
      { foreach my $self_pk (keys %{$r_self_lines})
          { if (!exists $found_lines{$self_pk})
	      { delete $r_self_lines->{$self_pk};
	        $self->{_deleted}->{$self_pk}=1;
	      };
	  };
        my $r_aliases= $self->{_aliases};
	if (defined $r_aliases)
	  { foreach my $key (keys %$r_aliases)
              { if (!exists $found_lines{$r_aliases->{$key}})
	          { $r_aliases->{$key}; };
              };
	  };
      };	  	
#die;
  }	    

sub mark_inserted
  { my $self= shift;
    my $pk= shift;
    my $r_l= $self->{_lines};
    
    return if (!defined $r_l);
    
    if (defined $pk)
      { if (exists $r_l->{$pk})
          { $self->{_inserted}->{$pk}=1; };
      }
    else
      { my %h;
        foreach my $pk (keys %{$r_l})
          { $h{$pk}= 1; };
	$self->{_inserted}= \%h; 
	# since everything is marked, the old "inserted" hash can
	# safely be deleted
      };
  } 

sub primary_keys
  { my $self= shift;
    return(keys %{$self->{_lines}} );
  }
           
sub value 
# get or set a value
  { my $self= shift;
    my $key = shift;
    my $column= shift; $column= uc($column);
    my $newval= shift;
    
    my $pk= $self->{_aliases}->{$key};
    return if (!defined $pk);
    
    my $line= $self->{_lines}->{$pk};
    return if (!defined $line);

    if (!defined $newval)
      { return $line->[ $self->{_columns}->{$column} ]; }
    else
      { my $i= $self->{_columns}->{$column};
        if ($i == $self->{_pki})
	  { die "error: primary key must not be changed!"; };
        $line->[ $self->{_columns}->{$column} ] =$newval; 
        $self->{_updated}->{$pk}=1;
      };
  }
 
sub add_line
  { my $self= shift;
    my $dbh= $self->{_dbh};
    my %values= @_;

    # usually this key should be unique, even if several instances of
    # dbitable are running, they shouldn't 'collide'
    my $pk= $self->{_pk};
    my $new_key= $values{$pk};
    if (!defined $new_key)
      { # if the primary key is not given, create one
        $new_key= $self->new_prelim_key();
      };
    
    my $r_lines  = $self->get_hash("_lines");
    my $r_aliases= $self->get_hash("_aliases");
    
    die "internal error, assertion failed\n" 
       if (exists $r_lines->{$new_key});
    
    my @line;
    
    $r_aliases->{ $new_key }= $new_key;
    foreach my $col (@{$self->{_column_list}})
      { if ($col eq $pk)
          { push @line, $new_key; next; };
        if (!exists $values{$col})
	  { die "add_line: field \"$col\" is missing"; };
	push @line, $values{$col};
      };
    $r_lines->{$new_key}= \@line;
    $self->{_inserted}->{$new_key}=1;
    return($new_key);
  }            

sub delete_line
  { my $self= shift;
    my $pk= shift;
    my $r_lines= $self->{_lines};
    my $r_aliases= $self->{_aliases};
    
    return if (!exists $r_lines->{$pk});
    if (defined $r_aliases)
      { foreach my $key (keys %$r_aliases)
          { delete $r_aliases->{$key} if ($r_aliases->{$key} eq $pk); };
      };
    delete $r_lines->{$pk};
    $self->{_deleted}->{$pk}=1;
  } 
	  
sub add_aliases
  { my $self= shift;
    my %aliases= @_;
    my $r_a= $self->{_aliases};
    my($alias,$pk);
    my $lines= $self->{_lines};
    
    while (($alias,$pk) = each %aliases) 
      { if (!exists $lines->{$pk})
          { warn "primary key $pk doesn\'t exist!"; next; };
        $r_a->{$alias}= $pk;
      };
  }    

sub resolve_alias
  { my $self= shift;
    my $alias= shift;
    
    my $r_aliases= $self->{_aliases};
    return if (!defined $r_aliases);
    return($r_aliases->{$alias});
  }

sub max_key
# 'capped' as parameter: return largest primary key below $key_fact
  { my $self= shift;    
    my $arg= shift;
    my $dbh= $self->{_dbh};

     

    if ($self->{_type} ne 'table')
      { die "sorry, \'maxkey\' is only allowed for type \'table\'"; };

    my $cmd= "select max( $self->{_pk} ) from $self->{_table}";
    if ($arg eq 'capped')
      { $cmd.= " where $self->{_pk}<$key_fact"; };
    
    print "$cmd\n" if ($sql_trace);
    
    my @array = $dbh->selectrow_array($cmd)
      or die "selectall_arrayref failed, errcode:\n$DBI::errstr";
    return($array[0]);
  }
     
#sub dump
#  { my $self= shift;    
#
#    my $obj= Data::Dumper->new([$self]); #,[$name]);
#    $obj->Terse(1);
#    $obj->Indent(1);
#    print $obj->Dump;
#  }

sub dump
  { my $self= shift;
    my $filename= shift;
    my $fh= \*STDOUT;
    local(*F);
    
    if (defined $filename)
      { open(F,">$filename") or die; 
        $fh= \*F;
      };
      
    my %h= %$self; 
  
    rdump($fh,\%h,0);
    if (defined $filename)
      { close(F) or die; };
  }  

sub rdump
#internal
  { my($fh,$val,$indent,$is_newline,$comma)= @_;
    my $r= ref($val);
    if (!$r)
      { print $fh " " x $indent if ($is_newline);
	print $fh "'",$val,"'",$comma,"\n"; 
        return;
      };
    if ($r eq 'ARRAY')
      { print $fh "\n"," " x $indent if ($is_newline);
        print $fh "[ \n"; $indent+=2;
        for(my $i=0; $i<= $#$val; $i++)
	  { rdump($fh,$val->[$i],$indent,1,($i==$#$val) ? "" : ",");
	  };
	$indent-=2; print $fh " " x $indent,"]$comma\n";
	return;
      };
    if ($r eq 'HASH')
      { print $fh "\n"," " x $indent if ($is_newline);
        print $fh "{ \n"; $indent+=2;
        my @k= sort keys %$val;
	for(my $i=0; $i<= $#k; $i++)
          { my $k= $k[$i];
	    my $st= (" " x $indent) . $k . " => ";
	    my $nindent= length($st); 
	    print $fh ($st); 
            rdump($fh,$val->{$k},$nindent,0,($i==$#k) ? "" : ",");
	  };
        $indent-=2; print $fh " " x $indent,"}$comma\n";
        return;
      };
    print $fh " " x $indent if ($is_newline);
    print $fh "REF TO: \'$r\'$comma\n"; 
  }
      
sub pretty_print
  { my $self= shift;
    my %options= @_;

    my @widths;
    my @lines;

    $self->gen_sort_prepare(\%options);

    my $s_lines= $self->{_lines};
    $gen_sort_href= $s_lines;
    my @keys= sort gen_sort (keys %$s_lines);
    
    push @lines, $self->{_column_list};
    
    push @lines, (map { $s_lines->{$_} } (@keys));
  
    @widths= col_widths(@lines);
    
    #foreach my $r_line (@lines)
    #  { for(my $i=0; $i<= $#$r_line; $i++)
    #      { my $l= length($r_line->[$i]);
    #	    $widths[$i]= $l if ($l>$widths[$i]);
    #      };
    #  };
    my $oolen;
    map { $oolen+= $_ + 1 } @widths; $oolen--;
    my $format= join(" ",(map{ '%-' . $_ . 's' } @widths)) . "\n"; 
    printf($format, @{$lines[0]});
    print "-" x $oolen,"\n";
    for(my $i=1; $i<=$#lines; $i++)
      { printf($format, @{$lines[$i]}); };
  }


# ------------------ database load and store

sub load_from_db
# internal
  { my $self= shift;
    my %options= @_;

    my $select_trailer;
    my $filter_field;
    my $filter_value;
    
    my $dbh= $self->{_dbh};
    my $pki= $self->{_pki};
    my $r;
    my $errstr= "selectall_arrayref() failed, errcode:\n";
    
    my $mode= $options{mode};
    if    (!defined $mode)
      { $mode= 'set'; }
    elsif (($mode ne 'add') && ($mode ne 'set') && ($mode ne 'overwrite'))
      { die "unknown load-mode:$mode"; }; 

 
    if (exists $options{filter})
      { if ($self->{_type} ne 'table')
          { die "sorry, filters are only allowed for type \'table\'"; };
      
        my $r_filter= $options{filter};
        if (ref($r_filter) ne 'ARRAY')
	  { die "err: \"filter\" is not an array reference"; };
	  
	my $filter_type= $r_filter->[0];
	if ($filter_type eq 'equal')
	  { my($filter_field,$filter_value)= @$r_filter[1..2];
	  
	    if (!defined($filter_value))
	      { die "err: filter specification is incomplete"; };
	    $filter_type= lc($filter_type);
	    $filter_field= uc($filter_field);
	    if ($filter_value!~ /^\'/)
	      { $filter_value= "\'$filter_value\'"; };
            die "unknown field" 
	         if (!exists $self->{_columns}->{$filter_field});
            $select_trailer= "where $filter_field = $filter_value";
	  }
	elsif ($filter_type eq 'SQL')
	  { $select_trailer= "WHERE " . $r_filter->[1]; }
	else
	  { die "unsupported filter-type: $filter_type"; };
      };	  
	   
    if ($self->{_type} eq 'table')
      { $self->{_fetch_cmd}= "select * from $self->{_table} " .
                             "$select_trailer"; 
      };
    
    my $cmd= $self->{_fetch_cmd};
    print "$cmd\n" if ($sql_trace);

#warn "|$cmd|\n";
    $r= $dbh->selectall_arrayref($cmd) or die $errstr . $DBI::errstr;


    my $r_lines;

    if ($mode eq 'set')
      { # delete all lines that are already there 
        delete $self->{_lines};
      }	
    
    $r_lines= $self->get_hash("_lines");


    my $r_aliases= $self->get_hash("_aliases");
    my $pk;
    
    
    my %updated;
    my %inserted;
    
    if ($mode ne 'set')
      { # 1: assume all lines to be inserted
        %inserted = map { $_ => 1 } (keys %$r_lines); 
      };
    
    foreach my $rl (@$r)
      { $pk= $rl->[$pki];
        if ($mode ne 'set')
	  {
            $inserted{$pk}=0; 
	    if (exists $r_lines->{$pk})
	      { if ($mode ne 'overwrite')
		  { 
	            if (!lists_equal($r_lines->{$pk},$rl))
	              { 
			$updated{$pk}= 1; 
		      };
		    next;  
		  };
              };
	  };  
      
        $r_lines->  { $rl->[$pki] } = $rl; 
        $r_aliases->{ $rl->[$pki] }= $rl->[$pki];
      };
      
    if ($mode eq 'set')
      { delete $self->{_updated};
        delete $self->{_inserted};
      }
    else
      { if (%updated)
          { $self->{_updated}= \%updated; }
        else
          { delete $self->{_updated}; };
	
	# all lines that were not found in the database are marked as inserted  
	my %n_inserted= map { $_ => 1} grep {$inserted{$_}} (keys %inserted);   
	if (%n_inserted)
	  { $self->{_inserted}= \%n_inserted; }
	else
	  { delete $self->{_inserted}; };
      
      };  
      
    return($self); 
  }	

sub store_to_db
#internal
# see comment on "%options" in insert()
  { my $self= shift;
  
    if ($self->{_type} ne 'table')
      { die "sorry, \'store\' is only allowed for type \'table\'"; };
      
    $self->delete_(@_);
    $self->update(@_);
    $self->insert(@_);
    return($self);
 }

sub delete_
# internal
 { my $self= shift;
    my $dbh= $self->{_dbh};
    my $lines= $self->{_lines};
  
    my $format;
    my $sth= db_prepare(\$format,$dbh,
                        "delete from $self->{_table} " .
        		"where $self->{_pk} = ? ")
        	or die "prepare failed," .
        	       " error-code: \n$DBI::errstr";

    # update :
    my $line;
    foreach my $pk (keys %{$self->{_deleted}})
      { db_execute($format,$dbh,$sth, $pk)
          or die "execute() returned an error," .
            " error-code: \n$DBI::errstr";
      }; 
    delete $self->{_deleted}; # all updates are finished 
  }  


sub update
#update
  { my $self= shift;
    my $dbh= $self->{_dbh};
    my $lines= $self->{_lines};
    my $pki= $self->{_pki};

    my @fields= @{$self->{_column_list}};
    
    my $format;
    my $sth= db_prepare(\$format,$dbh,
                        "update $self->{_table} set " . 
                	 join(" = ?, ",@fields) . " = ? " .
        		"where $self->{_pk} = ? ")
        	or die "prepare failed," .
        	       " error-code: \n$DBI::errstr";


    # update :
    my $line;
    foreach my $pk (keys %{$self->{_updated}})
      { $line= $lines->{$pk};
        next if (!defined $line); 
	# can happen with changing, then deleting a line
        db_execute($format,$dbh,$sth, 
	           @{$line}, $line->[$pki])
          or die "execute() returned an error," .
            " error-code: \n$DBI::errstr";
      }; 
    delete $self->{_updated}; # all updates are finished 
  }  

sub insert
#insert
# internal
  { my $self= shift;
    my %options= @_;

    my $dbh= $self->{_dbh};
    my $lines= $self->{_lines};
    my $pk= $self->{_pk};
    my $pki= $self->{_pki};

    my @fields= @{$self->{_column_list}};
    
    my $format;
    return if (!$self->{_inserted});
 
    my $v= $options{primary_key};
    if    (!defined $v)
      { $options{primary_key}= 'generate'; }
    elsif (($v ne 'preserve') && ($v ne 'generate'))
      { die "unknown primary-key-mode:$v"; }; 
 
    my $sth= db_prepare(\$format,$dbh,
                         "insert into $self->{_table} values( " .
			 ("?, " x $#fields) . " ? )" )
        	 or die "prepare failed," .
        		" error-code: \n$DBI::errstr";

    my $r_aliases= $self->get_hash("_aliases");

    # insert :
    my $failcount=0;
    my $line;
    foreach my $pk (keys %{$self->{_inserted}})
      { $line= $lines->{$pk};

        db_execute($format,$dbh,$sth, @{$line})
          or die "execute() returned an error," .
            " error-code: \n$DBI::errstr";
      };
      
    if ($options{primary_key} eq 'generate')
      { $sth=    db_prepare(\$format,$dbh,
                            "update $self->{_table} set $pk= ? " .
			    "where $pk= ?")
        	    or die "prepare failed," .
        		   " error-code: \n$DBI::errstr";

	my $max= $self->max_key('capped');

	foreach my $pk (keys %{$self->{_inserted}})
	  { $line= $lines->{$pk};

	    for(;;)
	      { if (!db_execute($format,$dbh,$sth, ++$max, $pk))
		  { if ($DBI::errstr=~ /constraint.*violated/i)
		      { # probably conflict with another task that was just adding
	        	# THAT key
			# give it another try
			if ($failcount++ < 5)
			  { next; };
			die "fatal: changing of primary key $pk failed\n" .
		            "again and again, giving up, last DBI error\n" .
			    "message was: $DBI::errstr";
		      }
		    else
		      { die "db_execute failed, errstring:\n$DBI::errstr"; };
        	  }
		else
		  { $failcount=0; 
	            last;
		  }; 
              };

	    # now change the primary key, retain the old one as an alias    
	    $r_aliases->{$pk} = $max;    
	    $r_aliases->{$max}= $max;    
	    $lines->{$max}= $lines->{$pk};
	    delete $lines->{$pk};    
	  }; 
      };
    delete $self->{_inserted}; # all updates are finished 
  }  

# ------------------ file load and store
sub load_from_file
# known options:
# pretty => 1 or 0  
#       1 removes spaces at the end of fields
#       needed for files that were created with the pretty-option
# primary_key=> 'generate', 'preserve', 
#           generate: only done where pk==0 !!!!
  { my $self= shift;
    my %options= @_;

    my $v= $options{primary_key};
    if    (!defined $v)
      { $options{primary_key}= 'preserve'; }
    elsif (($v ne 'preserve') && ($v ne 'generate'))
      { die "unknown import-mode:$v"; }; 


    if ($self->{_type} ne 'file')
      { die "sorry, \'store_to_file\' is only allowed for type" .
            " \'file\'"; };

    my $filename= $self->{_filename};
    my $tag= $self->{_tag};
    local(*F);
    
    open(F,"$filename") or die "unable to read to $filename";
    my $line;
    my $part;
    my $version;
    my $found;
    
    my @line_list;
    
    while($line=<F>)
      { chomp($line);
        next if ($line=~ /^\s*$/);
	next if ($line=~ /^#/);
	if (!defined $part)
          { next if ($line !~ /^\[Tag ([^\]\s]+)\s*\]\s*$/);
	    next if ($1 ne $tag);
	    $part= 'search_version';
	    $found=1;
	    next;
	  };
	
	if ($line =~ /^\[Tag ([^\]\s]+)\s*\]\s*$/)
	  { last; }; # stop when a new part begins
	  
	if ($part eq 'search_version')
          { next if ($line !~ /^\[Version ([^\]\s]+)\s*\]\s*$/); 
	    if ($export_version < $1)
	      { die "unsupported export-file version: $1"; };
	    $version= $1;
	    $part= 'scan';
	    next;
	  };
	
	if ($line =~ /^\[([^\]]+)\]\s*$/) # a new PART
          { $part= $1;
	    next;
	  };
	  
	if (($part eq 'Properties') && (!$slim_format))
	  { my @tokens = &parse_line('[\s=]+', 0, $line);
	    if (!($#tokens % 2))
	      { die "unrecognized line: \n\"$line\""; };
	    for(my $i=0; $i< $#tokens; $i+=2)
	      { my $t= $tokens[$i];
	        if    ($t eq 'TABLE')
	          { $self->{_table}= $tokens[$i+1]; }
		elsif ($t eq 'PK')
	          { $self->{_pk}   = $tokens[$i+1]; }
		elsif ($t eq 'TYPE')
	          { $self->{_type} = $tokens[$i+1]; }
		elsif ($t eq 'FETCH_CMD')
	          { $self->{_fetch_cmd} = $tokens[$i+1]; }
		else
		  { warn "unrecognized token: $t"; };
	      };
	    next;
	  };
	
	if (($part eq 'Aliases') && (!$slim_format))
	  { my @tokens = &parse_line('[\s,]+', 0, $line);
	    foreach my $t (@tokens)
	      { next if (!defined $t); # don't know why this happens
	        my($a,$pk)= ($t=~ /^\s*(.*?)\s*=>\s*(.*?)\s*$/);
	        if (!defined $pk)
		  { die "unrecognized line: \n\"$line\""; };
	        $self->{_aliases}->{$a}= $pk;
	      };
	    next;
	  };
	    	     
	if ($part eq 'Column-Types')
	  { my @tokens = &parse_line('[\s,]+', 0, $line);
	    my $r_t= $self->get_array("_types");
	    foreach my $t (@tokens)
	      { next if (!defined $t);
	        push @{$r_t}, $t;
              };
	    next;
	  };
	    
	if ($part eq 'Columns')
	  { my @tokens = &parse_line('[\s,]+', 0, $line);
	    my $r_t= $self->get_array("_column_list");
	    foreach my $t (@tokens)
	      { next if (!defined $t);
	        push @{$r_t}, $t;
              };
	    next;
	  };
	    
	if ($part eq 'Table')
	  { my @values;
	    if ($options{pretty}) 
	      { @values= split(/[;\|]/,$line); 
	        foreach my $v (@values)
		  { $v=~ s/\s+$//; };
	      }
	    else
	      { @values= split(/;/,$line); };
	      
	    die "format error" if ($#values != $#{$self->{_column_list}});
	    push @line_list,\@values;
	  };
      };
      
    close(F) or die "unable to close $filename";
    
    die "tag $tag not found in file $filename" if (!$found);
    
    # final clean-up work:
    # 1st: column-hash
    my $primary_key= $self->{_pk};
    my $r_c= $self->{_column_list};
    my %colindices;
    for(my $i=0; $i<= $#$r_c; $i++)
      { $colindices{ $r_c->[$i] } = $i; };
    $self->{_columns}= \%colindices;
    $self->{_pki}= $self->{_columns}->{$primary_key};
 
    # 2nd: lines
    my $pki= $self->{_pki};
    my $r_aliases= $self->{_aliases};
    my %lines_hash;
    my $pk;
    my $gen_pk= ($options{primary_key} eq 'generate');
    foreach my $rl (@line_list)
      { $pk= $rl->[$pki];
        if (($gen_pk) && ($pk==0))
	  { $pk= $self->new_prelim_key(); 
	    $rl->[$pki]= $pk;
	  }
	      
        $lines_hash{ $pk } = $rl;
        $r_aliases->{ $pk }= $pk;
      };
    $self->{_lines}= \%lines_hash;
    return($self);
  }    


sub store_to_file
#internal
# known options: 'order_by' => column-name
#            or  'order_by' => [column-name1,column-name2...]
#                'pretty' => 1 or 0
  { my $self= shift;
    my %options= @_;

    $self->gen_sort_prepare(\%options);

    if ($self->{_type} ne 'file')
      { die "sorry, \'store_to_file\' is only allowed for type" .
            " \'file\'"; };

    my $filename= $self->{_filename};
    my $tag= $self->{_tag};
    local(*F);
    local(*G);
    my $tempname;
    
    if (-e $filename)
      { $tempname= "dbitable-$$"; 
        open(F,$filename) or die "unable to read $filename";
	open(G,">$tempname") or die "unable to write $tempname";
	my $line;
	my $ftag;
	while($line=<F>)
          { if ($tag ne $ftag)
	      { 
		if ($line !~ /^\[Tag ([^\]\s]+)\s*\]\s*$/)
		  { print G $line; next; };
		$ftag= $1;  
		if ($tag ne $ftag)
		  { print G $line; };
		next;
              };
	    if ($line !~ /^\[Tag ([^\]\s]+)\s*\]\s*$/)
	      { next; };
	    $ftag= $1;
	    if ($tag ne $ftag)
	      { print G $line; };
	    next;
	  }
	close(F) or die "unable to close $filename";
      }
    else
      { open(G,">$filename") or die "unable to write $tempname"; };
    
    print G "[Tag $tag]\n"; 
    print G "[Version $export_version]\n";
    if (!$slim_format)
      { print G "[Properties]\n"; 
        print G "TABLE=",$self->{_table}," PK=",$self->{_pk},
                " TYPE=",$self->{_type},"\n";
        print G "FETCH_CMD=\"",$self->{_fetch_cmd},"\"\n";
        print G "[Aliases]\n";  
        my $r_a= $self->{_aliases};

	my @text;
	$Text::Wrap::columns = 72;
	foreach my $k (sort keys %$r_a)
	  { my $val= $r_a->{$k};
            next if ($val eq $k);
	    push @text, ($k . "=>" . $val);
	  };
	print G wrap('', '', join(", ",@text)),"\n"; 
      };
      
    print G "[Column-Types]\n"; 
    print G wrap('', '', join(", ",@{$self->{_types}})),"\n"; 

    print G "[Columns]\n"; 
    print G wrap('', '', join(", ",@{$self->{_column_list}})),"\n"; 
         
    print G "[Table]\n";
    my $r_l= $self->{_lines}; 

    $gen_sort_href= $r_l;
    my @keylist= sort gen_sort (keys %$r_l);
    
   		       
   #@@@@
    if ($options{'pretty'})
      { my @widths= col_widths( map { $r_l->{$_} } @keylist);
        my $oolen;
        map { $oolen+= $_ + 1 } @widths; $oolen--;
        my $format= join("|",(map{ '%-' . $_ . 's' } @widths)) . "\n"; 
        foreach my $pk (@keylist)
          { printf G ($format,@{$r_l->{$pk}}); }
      }
    else
      { foreach my $pk (@keylist)
          { print G join(";",@{$r_l->{$pk}}),"\n"; };
      };
    
    if ($options{'pretty'})
      { print G "#","=" x 70,"\n"; };

    if (defined $tempname)
      { close(G) or die "unable to close $tempname";
        if (1!=unlink($filename))
	  { die "unable to delete $filename"; };
	rename($tempname,$filename) or 
	  die "unable to rename $tempname to $filename";
      }
    else
      { close(G) or die "unable to close $tempname"; };
    return($self);
  } 

sub get_array
#internal
# returns the array-reference, creates it, if it's not already there
  { my $self= shift;
    my $arrayname= shift;
    
    my $r= $self->{$arrayname};
    return($r) if (defined $r);
    my @a;
    $self->{$arrayname}= \@a;
    return(\@a);
  }

sub get_hash
#internal
# returns the hash-reference, creates it, if it's not already there
  { my $self= shift;
    my $hashname= shift;
    
    my $r= $self->{$hashname};
    return($r) if (defined $r);
    my %h;
    $self->{$hashname}= \%h;
    return(\%h);
  }
    

sub new_prelim_key
#internal
  { my $self= shift;
    if (!$prelim_key)
      { my $max;
        if ($self->{_type} eq 'table')
	  { $max= $self->max_key(); }
	else
	  { # just guess
	    $max= $key_fact;
	  };
        $prelim_key= int($key_fact*rand())+$key_fact + $max; 
      }
    else
      { $prelim_key++; };
    return($prelim_key);
  }

sub col_widths
# internal
  { my (@line_list)= @_;
    my @widths;
    
    foreach my $r_line (@line_list)
      { for(my $i=0; $i<= $#$r_line; $i++)
          { my $l= length($r_line->[$i]);
	    $widths[$i]= $l if ($l>$widths[$i]);
	  };
      };
    return(@widths);    
  }

sub db_simplify_types
# internal
  { my($r_types)= @_;
    my %map= (RAW        => undef,
              'LONG RAW' => undef,
	      CHAR  => 'string',
	      NUMBER=> 'number',
	      DATE  => 'string',
	      VARCHAR2 => 'string',
	      DOUBLE => 'number',
	      LONG => 'number');
  
    foreach my $t (@$r_types)
      { $t= $map{uc($t)}; };
  }

sub db_types_no2string
# internal
# creates a hash, mapping number to string,
# this is needed for $sth->{TYPE} !
# known datatypes in DBD::oracle:
# '-3' => 'RAW',
# '-4' => 'LONG RAW',         
# '1' => 'CHAR',              
# '3' => 'NUMBER',            
# '11' => 'DATE',             
# '12' => 'VARCHAR2',         
# '8' => 'DOUBLE',            
# '-1' => 'LONG'              
  { my($dbh)= @_;
    my %map;
  
    my $info= $dbh->type_info_all(); # ref. to an array
    
    my $r_description= shift(@$info); # ref to a hash
    
    # TYPE_NAME is the string
    # DATA_TYPE is the number 
    
    my $TYPE_NAME_index= $r_description->{TYPE_NAME}; 
    my $DATA_TYPE_index= $r_description->{DATA_TYPE};  
    
    foreach my $r_t (@$info)
      { $map{ $r_t->[$DATA_TYPE_index] } = $r_t->[$TYPE_NAME_index]; };
     
#print Dumper(\%map);
    return(\%map);
  }
    
    

sub db_get_primary_key
# internal
  { my($dbh,$table_name)= @_;
  
    $table_name= uc($table_name);
    
    my $SQL= "SELECT a.owner, a.table_name, b.column_name " .
             "FROM all_constraints a, all_cons_columns b " .
	     "WHERE a.constraint_type='P' AND " .
		  " a.constraint_name=b.constraint_name AND " .
		  " a.table_name = \'$table_name\'";
    
    print $SQL,"\n" if ($sql_trace);
    
    my $res=
      $dbh->selectall_arrayref($SQL);
		      	   
    if (!defined $res)
      { die "selectall_arrayref failed, errcode:\n$DBI::errstr"; };

    if ($#$res!=0)
      { die "error: result is not unique"; };
    return( lc($res->[0]->[2]) );
  }
    

sub db_prepare
# internal
  { my($r_format,$dbh,$cmd)= @_;
        
    my $sth = $dbh->prepare($cmd);
    return if (!defined $sth);

    if ($sql_trace)
      { $$r_format= $cmd;
        $$r_format=~ s/\?/\%s/g; $$r_format.= "\n";
      }; 
    return($sth);
  }
  
sub db_execute
# internal
  { my($format,$dbh,$sth,@args)= @_;
  
    printf($format, map {quote($dbh,$_)} @args 
           ) if ($sql_trace);

    return( $sth->execute( map {quote($dbh,$_)} @args));
  };    
 
sub gen_sort_prepare
# internal
  { my $self= shift;
    my $r_options= shift;
    
    # @gen_sort_cols and $gen_sort_r_coltypes are global variables
    # used by gen_sort()
    @gen_sort_cols= ($self->{_pki});
    $gen_sort_r_coltypes= $self->{_types};

    if (exists $r_options->{order_by}) 
      { my $r= $r_options->{order_by};
        if (!ref($r)) # directly given
	  { my $ci= $self->{_columns}->{uc($r)};
	    if (!defined $ci)
	      { die "unknown column: $r"; };
	    unshift @gen_sort_cols, $ci; 
	  }
	else
	  { die "not an array" if (ref($r) ne 'ARRAY');
	    # an array is given
	    my $last= shift @gen_sort_cols; # save the last element
	    foreach my $c (@$r)
	      { my $ci= $self->{_columns}->{uc($c)};
	        if (!defined $ci)
	          { die "unknown column: $c"; };
 	        push @gen_sort_cols, $ci; 
	      };
	    push @gen_sort_cols,$last;
	  };
	
      };  
  }    

# given: gen_sort_href gen_sort_params
# gen_sort_cols   : a list of column-indices 
# gen_sort_r_coltypes: a ref to an array: [number,string....]

sub gen_sort
  { my($r,$col,$t);
    
    for(my $i=0; $i<= $#gen_sort_cols; $i++)
      { $col= $gen_sort_cols[$i];
        $t  = $gen_sort_r_coltypes->[$col];
    
	if ($t eq 'number')
	  { $r= $gen_sort_href->{$a}->[$col] <=> $gen_sort_href->{$b}->[$col];
            return($r) if ($r!=0);
	  }
	else  
	  { $r= $gen_sort_href->{$a}->[$col] cmp $gen_sort_href->{$b}->[$col];
            return($r) if ($r!=0);
	  };
      };
    return(0); # nothing else to do
  }      
    
    
sub lists_equal
  { my($r_l1,$r_l2)= @_;
  
    return if ($#$r_l1 != $#$r_l2); 
    
    for(my $i=0; $i<= $#$r_l1; $i++)
      { return if ($r_l1->[$i] ne $r_l2->[$i]); };
    return(1);
  }
    
sub quote
# internal
  { my($dbh,$val)= @_;
  
    #if ($val!~ /^\s*[+-]?\d+\.?\d*\s*$/) #not a number
    #  { return($dbh->quote($val)) };
    return($val);  
  }
    
1;

__END__

# Below is the short of documentation of the module.

=head1 NAME

dbitable - an object-oriented Perl module for handling 
single tables from an SQL database.

=head1 SYNOPSIS

  use dbitable;

  my $tab= dbitable->new('table', $database_handle,
                         $table_name, $primary_key)->load();
 
  $tab->value($key1,$column_name,$new_value);
  $tab->store();
  $tab->pretty_print();

=head1 DESCRIPTION

=head2 Preface


This module defines the dbitable - class. A dbitable-object can
hold some or all parts of a table of an SQL database. It is also
possible, to load the results of a user-defined view into a dbitable-object.
And a dbitable-object can also be used to read or write to an ASCII file 
in a (more or less) human-readable format. 
 
dbitable is based on the DBI module, see also the DBI manpage for more 
information.

Two basic methods for a table are C<load> and C<store>. These 
methods are used to load data from the database or store data
to the database or the file. 

The usual way of handling a dbitable-object is to create it,
fetch some data with C<load>, inspect or modify the data, and,
optionally, write the table back to the database using C<store>.

To do all this, the user of this module doesn't need to know
the SQL language. Knowledge on the basics of relational databases,
however, will be needed. 

=head2 utilities to access the database:

In order to access the database and create a database-handle, the 
following two functions can be used:

=over 4

=item dbitable::connect_database()

  my $dbh= dbitable::connect_database($dbname,$username,$password)
    
This method creates a connection to the database. The database corresponds
to the first parameter of the C<connect> function of the DBI module. See 
also the DBI manpage. The function returns the DBI-handle or C<undef>
in case of an error. The DBI-handle is also stored in the internal global
handle variable. This variable is used as default in the dbitable constructor 
function C<new()> when it's DBI-handle parameter is an empty string ("") or
C<undef>.

=item dbitable::disconnect_database()

  dbitable::disconnect_database($dbi_handle)
  
This function is used to disconnect from the database. If the parameter
C<$dbi_handle> is an empty string, the default DBI-handle is used (see
also description of C<connect_database>).  

=back

=head2 creation of a dbitable-object:

A dbitable object is created using the C<new> method:

  my $tab= dbitable->new('table',$database_handle,
                         $table_name, $primary_key);

  my $tab= dbitable->new('view',$database_handle,
                         $table_name, $primary_key, $sql_query);
  
  my $tab= dbitable->new('file',$filename,$tag);

  my $tab= dbitable->new('file',$filename,$tag,@column_list);

  # clone the existing structure:
  my $tab2= $tab->new();

  my $tab2= $tab->new('table',$database_handle,
                      $table_name, $primary_key);

  my $tab2= $tab->new('view',$database_handle,
                      $table_name, $primary_key, $sql_query);
  
  my $tab2= $tab->new('file',$filename,$tag);

The C<new> method currently knows three parameter formats. Note that,
if new is called as method of a parent dbitable-object, the parent object
is cloned and the type (table,view or file) is changed to the type
specified in the first parameter.

The C<$database_handle> parameter may be a valid database-handle, e.g.
created with the C<connect_database> function, or an empty string. In 
this case, the default database-handle is used (see description of
C<connect_database>).

The 1st parameter specifies the type of the dbitable-object

=over 4

=item *

"table"

With "table" the dbi-table object will hold a some or all parts of a
single table. The name of the table is given with the C<$table_name> parameter,
the name of the primary key is given with the C<$primary_key> parameter.
A primary key here is a column, which has a unique value for each line of
the table. Note that dbitable will not work correctly, if a column-name is
supplied, where this condition is not always true. Note too, that the
primary key must be a numeric (integer) field in the table.

=item *

"view"

With "view", the dbi-table object will hold the result of an arbitrary 
SQL-query. Note that in this query, each column must be named with a 
unique name. This means that for columns that are calculated or assembled,
they must be given a unique name with the "AS" SQL-statement. Of course,
a dbitable object, that was created as "view" cannot be written back to 
the database, so C<store> will return an error. The table-name parameter 
has in this case no special meaning.

=item *

"file"

With "file", the C<load> and C<store> functions on this object will
will not connect to the database, but work on an ASCII file instead. 
A single ASCII file can hold several dbitable-objects,
they are distinguished in the file by their "tag", basically a unique string
that identifies them. With C<store>, if there is already a section with the 
tag C<$tag> in the file, it will simply be overwritten.

Note that as an option, a list (C<@column_list>) can be specified for a
table-object that is created as an empty object with no data. The C<@column_list>
has to be a list consisting of the name of the primary key, and a list of
the names of all columns. 

This is not needed, if the table is loaded later (see C<load>) from a 
file, since the file already contains a list of all columns and the 
name of the primary key.

=back

=head2 loading:

  $table->load()
 
  $table->load(%options)

  my $tab= dbitable->new($database_handle,
                         'table',$table_name, $primary_key)->load();
    
This method loads the table from the database (for the type "table")
or from a file (type "file") or via a user-defined SQL statement
(type "view"). C<%options> is a hash that is used to pass optionial
parameters to the function. The function returns the object itself, 
so it can be cascaded with C<new> in a single call, as you can see in
the third example.

Known options are:

=over 4

=item *

"filter"

A filter can only be used for the type "table". It is a way to 
specify that only a part of the table shall be fetched. A typical
call of the C<load> function with a filter is:

  $table->load(filter=> ["equal",$column_name,$column_value])
  
As you can see, filter is a hash-key that has as a value a list-reference.
The list consists of at least one element, the filter-type. This
is possibly followed by a list of filter-parameters.

known filters:

=over 4

=item equal

  $table->load(filter=> ["equal",$column_name,$column_value])

In this case, only lines of the table, where column C<$column_name> has
a value that equals C<$column_value> are fetched.

=item SQL

  $table->load(filter=> ["SQL",$sql_statement])

This is used to specify the "WHERE" part of the SQL "SELECT" 
statement directly. Note that C<$sql_statement> must not contain 
the word "WHERE" itself, dbitable adds this automatically.

=back


=item *

"primary_key"

  $table->load(primary_key=>"preserve")

This option can only be used for the type "file" and defines the
primary_key mode. It must be either "preserve" or "generate". With "preserve", 
the column that is the primary key is simply taken from the file as it is. 
"preserve" is the default, if the primary_key mode is not specified.

With "generate" however, when the primary key is zero (0), a new
(for that table-line unique-) primary key is generated. This is useful,
when many lines are added to the file with a simple text editor. In this
case, the primary key field is set to zero. When the file is loaded with 
the C<load> method, a new unique primary key is created while loading the file. 
Otherwise, the user would have to count lines, and create unique numbers for each
new line he adds, which would be a rather dull task... ;)

=item *

"mode"

  $table->load(mode=>'overwrite')

This option can only be used for the type 'table'. It defines what
to do, if the table already contains data before C<load()> is executed.
Three modes are known, "set", "add" and "overwrite". "set" is 
the default. With "set", all
lines from the table are removed, before new lines are loaded from
the database. With "add", the lines from the database are added to the
lines already in the table. Lines that were not loaded from the
database are marked "inserted". Lines that found in the table already but
are different from that in the database are marked "updated". 
"overwrite" is similar to "add', but in this case lines that are 
found already in the table but also in the database are overwritten
with the values from the database. The internal marking of lines
as "inserted" or "updated" has a meaning when a C<store()> is executed
for that table-object later.

=item *

"pretty"

  $table->load(pretty=>1)

This option can only be used for the type "file". "pretty" must be
either "0" or "1". With "0", the file is just read as it is, this is the
default, when "pretty" is not defined. With "1", spaces at the end of fields 
are removed. This option is needed, when the file was created (via C<store>) 
with the "pretty" option also active (see C<store>).

=back

=head2 storing:

  $table->store()
 
  $table->store(%options)
    
This method writes the content of the table back to the 
database (for type "table") or to the file (for type "file"). 

Known options are:

=over 4

=item *

"primary_key"

  $table->store(primary_key=>"preserve")

This option can only be used for the type "table" and defines the
primary_key mode. This is only relevant for lines that were added to the table
and that are not yet in the database (C<store> uses the SQL command 
"INSERT" in this case). 

The primary-key mode must be either "preserve" or "generate", "generate"
is the default, when this option is not specified.

With "generate" , the primary key is calculated as a small unique number
for each new line in the table (note that it must be ensured that each
line in the table has a unique primary key). Before C<store>, each
added line in the table has a preliminary primary key (a rather large 
number). During store, the value of the primary key changes, the old,
preliminary one however, remains valid as an alias (see C<add_aliases>).

With "preserve", the value of the primary key in the table is just taken
as it is. The user must ensure, that this key is unique for the new
inserted lines in the table-object. This mode is only useful, when 
the primary key was directly set by the user.

=item *

"pretty"

  $table->store(pretty=>1)

This option can only be used for the type "file". "pretty" must be
either "0" or "1". With "0", the file is written in a space-saving
format. With "1", spaces are added at the end of fields, to make
the file more look like a real table. Files that were written
with the "pretty" option enabled, should only be read (via C<load>)
with the "pretty" option also enabled.

=item *

"order_by"

  $table->store(order_by=>[$column_name1,$column_name2])

This option can only be used for the type "file". It defines, wether lines
should be sorted by certain colums. The value may be the name of a single 
column or (as shown above) a reference to a list
of column names.

=back

=head2 importing a table:

  $dest_tab->import_table($source_tab,%options);

This method is used to import the contents of an existing table-object
into a new one. It is not necessary, that both tables are of the same type.
Known options are:

=over 4

=item *

"mode"

  $dest_tab->import_table($source_tab, mode=>"set_lines");

This is the import mode. Two modes are known, "add_lines" and "set_lines",
"add_lines" is the default. With "add_lines", the lines of the source-tables
are added to the lines that already exist in the destination table.
With "set_lines" however, the destination table is made equal to the
source-table. All lines that are not present in the source-table
(as defined by the primary-key) are deleted. 

=item *

"primary_key"

  $dest_tab->import_table($source_tab, primary_key=>"generate");

This option defines the primary_key mode. It must be either "preserve" or "generate",
"generate" is the default. 

It is only relevant for lines that were added to the table.

With "generate" , the primary key is calculated as a large unique number
for each new line in the table, called preliminary key. If the
table is written to the database (see "store"), this key is replaced with
a small unique number, the old one, however, remains valid as an alias 
(see C<add_aliases>).

With "preserve", the value of the primary key is just taken from the source-table
and remains unchanged. If the table-object is written to the database
(see C<store>), the user must ensure, that this key is unique for new
inserted lines. 

=item *

"column_aliases"

  $dest_tab->import_table($source_tab, 
                          column_aliases=> 
			         { $dest_col1 => $src_col1,
                                   $dest_col2 => $src_col2 });
			  
column-aliases are used to map colums of the source-table to columns
of the destination-table that have a different name. Note that for
columns, where a column-alias is not defined, columns of the source
are just mapped to columns of the destination that have the same name.

=back

=head2 miscelanious functions:

=over 4

=item primary_keys()

  my @keys= $table->primary_keys()
 
This method returns a list consisting of the primary key of each
line of the table.

=item value()

  my $value= $table->value($primary_key, $column_name)

  $table->value($primary_key, $column_name, $value)

This method is used to get or set a value, that means a single field of
a single line. In the first form, the value is returned, in the 2nd form,
the value is set. Note that changes do only take effect in the database 
or file, when C<store()> is called later on. 

=item add_line()

  my $primary_key= $table->add_line(%values)

This method is used add a line to the table. C<%values> is a hash, that 
contains "column-name" "value" -pairs for the line. Note that each
column must be specified. Currently there are no defaults supported.
Note that the method returns the primary key for the new line. Note
too, that this primary key changes with the next call of
C<store()>, see also C<store()>, but via aliasing (see C<add_aliases>)
it can then still be used to access the line.
If the value of the primary key is specified in the list of values,
it is taken as it is, and no new primary key is generated.

=item delete_line()

  $table->delete_line($primary_key)

This method deletes a line from the table. Note that this change is
made in the database or file only at the next call of C<store()>.

=item add_aliases()

  $table->add_aliases(%aliases)

This method is used to add aliases to the table. An alias is a key that is
different from the value of the primary key, that can be used to access
a single line. An arbitrary number of aliases can be defined for a line.
Note however, that each alias must be unique. The C<%aliases> parameter
is a hash, containing pairs of the alias and the corresponding
primary key.

=item resolve_alias()

  my $primary_key= $table->resolve_alias($alias)

This method returns the primary key that is associated with a given alias.

=item max_key()

  my $max= $table->max_key()

This function returns the maximum primary key for a given table. Note that
this value is obtained directly by an SQL query from the database, no
matter what the current content of the table-object is.

=item dump()

  $table->dump()

This method dumps the complete internal data-structure of a table-object
and is for debugging purposes only.

=item pretty_print()

  $table->pretty_print()

  $table->pretty_print(%options)

This method is used to pretty-print a given table. 

Known options are:

=over 4

=item *

"order_by"

  $table->pretty_print(order_by=>[$column_name1,$column_name2])

This option defines, wether lines should be sorted by certain colums. The 
value may be the name of a single column or (as shown above) a reference 
to a list of column names.

=back

=back

=head1 EXAMPLES

=head2 query a database (type "table") 

This example queries the p_insertion table here at BESSY. It connects to
the database and creates a "table" object. C<new> and C<load> are called
in one line:

  use strict;
  use dbitable;

  my $dbname= "DBI:Oracle:bii_par";

  my $user="guest";
  my $pass="bessyguest";

  dbitable::connect_database($dbname,$user,$pass) or die;
  
  my $tab= dbitable->new('table',"",'p_insertion',
                         'insertion_key')->load();

  $tab->pretty_print();
  
  dbitable::disconnect_database();

=head2 arbitrary SQL query (type "view")

In this example, the insertion-device name-key (a number) is mapped
to the insertion-device name. For this, the "view" type is used. The
device-name has to be constructed (a simple string concatenation) by
querying 5 tables. Note that the "constructed" column consists of a 
concatenation of "part_name", "part_index", "part_family", "part_subdomain",
"part_postfix" and "part_domain" and is named (naming is imperative!) to
"device_name" by the "... AS device_name" part of the statement.
The resulting table-object is just like any other table object, except
that a call of the store() method is not allowed.  

  use strict;
  use dbitable;

  my $dbname= "DBI:Oracle:bii_par";

  my $user="guest";
  my $pass="bessyguest";

  dbitable::connect_database($dbname,$user,$pass) or die;
  

  my $tab= dbitable->new('view',"",'v_names','name_key',
	"select N.name_key, " .
	"       part_name || part_index || part_family || " .
	"                    part_subdomain || part_postfix || " .
	"                    part_domain AS device_name " .
	"  from p_insertion I, p_name N, p_subdomain S, " .
	"       p_family F, p_domain D " .
	"  where I.name_key = N.name_key AND " .
	"        N.subdomain_key = S.subdomain_key AND " .
	"        N.family_key = F.family_key AND " .
	"        S.domain_key = D.domain_key"
                             )->load();


  $tab->pretty_print();
  
  dbitable::disconnect_database();

=head2 reading of a table and writing to a file (type "file")

The following example reads the table "p_insertion" and writes it to a file.
Since the original table-object is of the type "table", a new object of
the type "file" is created by calling the C<new> method on the first 
table-object. Using C<dbitable->new(...)> and calling <$ntab->import_table(..)>
would have been another possibility to achive this. After the program was
executed, you may have a look at the file "TEST.TXT", which is created by
this little application.

  use strict;
  use dbitable;

  my $dbname= "DBI:Oracle:bii_par";

  my $user="guest";
  my $pass="bessyguest";

  dbitable::connect_database($dbname,$user,$pass) or die;
  
  my $tab= dbitable->new('table',"",'p_insertion','insertion_key')->load();

  my $ntab= $tab->new('file',"TEST.TXT","TEST-TAG")->store();

  dbitable::disconnect_database();

=head2 modifying a table and writing back to the database (type "table")

This script reads the table, adds a line and writes back to the database.
Note that the primary key 'insertion_key' must not be specified when
C<add_line> is called, a new primary key is created automagically.
Note too, that if you really try to execute this script, it will fail,
since the guest-user has no write priviledges.
C<$dbitable::sql_trace=1> will force the dbitable module to print all
SQL commands to the screen, before they are executed.

  use strict;
  use dbitable;
  
  $dbitable::sql_trace=1;

  my $dbname= "DBI:Oracle:bii_par";

  my $user="guest";
  my $pass="bessyguest";

  dbitable::connect_database($dbname,$user,$pass) or die;
  
  my $tab= dbitable->new('table',"",'p_insertion','insertion_key')->load();

  $tab->add_line(NAME_KEY=> 1,
                 INTERNAL_NAME=> "XX",
		 IOC_KEY=> 2,
		 DESCRIPTION=>"test",
		 DEVICE_CONDITION=>1);

  $tab->pretty_print();
  
  $tab->store();
  
  dbitable::disconnect_database();

=head2 writing a file back to the database

This script reads a table from an existing file. Then it reads 
from the database and kind of compares this with the data from the
file. The changed lines are then stored back to the database. The advantage
of reading from the database before writing to it is that the
SQL "update" command is only executed for lines that have found to be
different from the lines stored in the database.

  use strict;
  use dbitable;
  
  $dbitable::sql_trace=1;

  my $dbname= "DBI:Oracle:bii_par";

  my $user="guest";
  my $pass="bessyguest";

  dbitable::connect_database($dbname,$user,$pass) or die;
  
  my $ftab= dbitable->new('file',"TEST.TXT","TEST-TAG")->load();
   
  my $tab = $ftab->new('table',"",'','');
  # 1st '': take table-name from $ftab
  # 2nd '': take primary key from $ftab
  
  $tab->load(mode=>"add");

  $tab->store();
  dbitable::disconnect_database();


=head1 AUTHOR

Goetz Pfeiffer,  pfeiffer@mail.bessy.de

=head1 SEE ALSO

perl-documentation, DBI manpage

=cut

internal data-structure
The table-Object is a hash. Summary of hash-keys:
_aliases:     ref of a hash, that contains aliases
_column_list: ref of a list of columns
_columns:     ref of a hash that maps column-names to column-numbers,
	      the first column has index 0
_dbh: 	      the DBI-handle the table object uses
_fetch_cmd:   the last SQL command,
_lines:       a ref to a hash, each primary key points to a reference
	      to a list. Each list contains the values in the order of the
	      columns (see also "_column_list")
_pk: 	      the column-name of the primary key
_pki: 	      the column-index of the primary key
_table:       the name of the table, as it's used in oracle
_type: 	      the type of the table, "table","view" or "file"
_types:	      the types of the columns, "number" or "string"

SELECT a.owner, a.table_name, b.column_name
  FROM all_constraints a, all_cons_columns b
 WHERE a.constraint_type='P'
   AND a.constraint_name=b.constraint_name
   AND a.table_name = 'P_INSERTION_VALUE';
