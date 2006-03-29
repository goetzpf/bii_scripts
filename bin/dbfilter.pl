eval 'exec perl -S $0 ${1+"$@"}' # -*- Mode: perl -*-
    if 0;
# the above is a more portable way to find perl
# ! /usr/bin/perl

# @STATUS: release
# @PLATFORM: home bessy
# @CATEGORY: search


# [scriptname] -- describe the function here

use strict;

use FindBin;
use Getopt::Long;
use Data::Dumper;

use parse_db;

use vars qw($opt_help $opt_summary
            $opt_dump_internal $opt_recreate
	    $opt_val_regexp @opt_field 
	    $opt_name 
	    $opt_notname 
	    $opt_type
	    $opt_value
	    $opt_DTYP
	    $opt_fields
	    $opt_list
	    $opt_percent
	    $opt_list_unresolved
	   );


my $sc_version= "0.9";

my $sc_name= $FindBin::Script;
my $sc_summary= "parse db files"; 
my $sc_author= "Goetz Pfeiffer";
my $sc_year= "2005";

my $debug= 0; # global debug-switch


#Getopt::Long::config(qw(no_ignore_case));

if (!@ARGV)
  { help();
    exit;
  };

if (!GetOptions("help|h","summary",
                "dump_internal|i", "recreate|r", "val_regexp|v=s",
		"field=s@", 
		"name|NAME|n=s", "notname|NOTNAME=s", 
		"value=s",
		"DTYP=s",
		"type|TYPE|t=s", 
		"fields|FIELDS=s",
		"list|l",
		"percent=s",
		"list_unresolved"
		
                ))
  { die "parameter error!\n"; };


if ($opt_help)
  { help();
    exit;
  };

if ($opt_summary)
  { print_summary();
    exit;
  };

my @files= @ARGV;
my $single_file= ($#ARGV==0);
if ($#ARGV<0)
  { # no file given, read from STDIN
    $single_file= 1;
    @files= (undef); 
  };

foreach my $file (@files)
  { my $filename;
    if (!$single_file)
      { $filename= $file; };
      
    my $recs= parse_file($file);

    if (defined $opt_name)
      { filter_name($recs,$opt_name); };

    if (defined $opt_notname)
      { filter_name($recs,$opt_notname,1); };

    if (defined $opt_type)
      { filter_type($recs,$opt_type); };

    if ($opt_DTYP)
      { filter_records($recs,"DTYP",$opt_DTYP);
      };

    if (@opt_field)
      { foreach my $fil (@opt_field)
	  { my($field,$regexp)= split(",",$fil);

            filter_records($recs,$field,$regexp);
	  };	
      };

    if (defined $opt_val_regexp)
      { find_val($filename,$recs,$opt_val_regexp,0);
      };

    if (defined $opt_fields)
      { my @fields= split(",",$opt_fields);
	filter_fields($recs,\@fields);
      };

    if (defined $opt_percent)
      { filter_percent($recs,$opt_percent); };

    if ((!defined $opt_dump_internal) && 
	(!defined $opt_recreate) &&
	(!defined $opt_value) &&
	(!defined $opt_list)
       )
      { $opt_recreate=1; };

    if (defined $opt_value)
      { find_val($filename,$recs,$opt_val_regexp,1);
	next;
      };

    if (defined $opt_list_unresolved)
      { list_unresolved($filename,$recs,1);
        next;
      };
    
    if (defined $opt_list)
      { foreach my $r (sort keys %$recs)
	  { if (defined $filename)
	      { print "\nFILE $filename:\n";
	        $filename= undef; 
	      };
	    print $r,"\n"; 
	  };
	next;
      };

    if (defined $opt_dump_internal)
      { dump_recs($filename,$recs);
	next;
      };

    if (defined $opt_recreate)
      { if ((defined $filename) && (%$recs))
          { print "\nFILE $filename:\n"; };
	parse_db::create($recs);
	next;
      };
  };


exit(0);

sub parse_file
# parse the db file and return the record hash
  { my($filename)= @_;
    local(*F);
    local($/);
    my $st;
    
    undef $/;
    
    if (!defined $filename) # read from STDIN
      { *F=*STDIN; }
    else
      { open(F,$filename) or die "unable to open $filename"; };
    $st= <F>;
    
    close(F) if (defined $filename);
    
    return(parse_db::parse($st));
    #parse_db::dump($r_records);
    #parse_db::create($r_records);
  }

sub dump_recs
# dump the internal record-hash structure
  { my($filename,$r_rec)= @_;
    
    print "\nFILE $filename:\n" if (defined $filename);
    parse_db::dump($r_rec);
  }

sub dump_rec_fields
# print a simple fdump of a given list of fields in a record
  { my($rec,$r_fields)= @_;

    my $r_values= $rec->{FIELDS};
    foreach my $v (@$r_fields)
      { print "\t",$v," -> \"",$r_values->{$v},"\"\n"; };
  }
  

sub find_val_in_rec
# return all fields in a record that match a 
# regular expression
  { my($rec)= @_;
    my @matches;
  
    my $r_values= $rec->{FIELDS};
    foreach my $v (sort keys %$r_values)
      { 
        next if (!value_filter($r_values->{$v}));
        push @matches, $v;
      };
    return(@matches);
  }

sub filter_rec_fields
# remove all fields in a record that are not
# part of a given hash
  { my($rec, $r_field_hash)= @_;
    my @rem;
  
    my $r_values= $rec->{FIELDS};
    foreach my $v (sort keys %$r_values)
      { if (!exists $r_field_hash->{lc($v)})
          { push @rem, $v; };
      };
    foreach my $v (@rem)
      { delete $r_values->{$v}; };
  }
    
sub filter_fields
# remove all fields in all records that
# are part of a given list
  { my($r_rec,$r_fields)= @_;
    my %h= map { lc($_)=>1 } @$r_fields;
    
    foreach my $rec (keys %$r_rec)
      { filter_rec_fields($r_rec->{$rec}, \%h); };
  }
    
sub match_fields
# return all fields of a record that
# match a given regexp, note: 
# this function calls "field_matcher"
  { my($rec,$r_fields)= @_;
    my @matched;

    my $r_values= $rec->{FIELDS};
    foreach my $v (sort keys %$r_values)
      { if (field_matcher($v))
          { push @matched, $v; };
      };
    return(@matched);  
  }  

sub list_unresolved
  { my ($filename,$recs,$do_list)= @_;
    my $res;
    my %mac;
    my %recs;
    
    foreach my $recname (keys %$recs)
      { $res= add_macros(\%mac, $recname);
        my $r_fields= $recs->{$recname}->{FIELDS};
	foreach my $fieldname (keys %$r_fields)
	  { $res|= add_macros(\%mac, $r_fields->{$fieldname}); };
	if ($res && $do_list)
	  { $recs{$recname}= 1; };
      };
    print "unresolved macros in these records:\n";
    print "-" x 40,"\n";
    print join("\n",sort keys %recs);
    print "\n\nList of unresolved macros:\n";
    print "-" x 40,"\n";
    print join("\n",sort keys %mac),"\n";  
  } 
 
sub add_macros
  { my($r_h, $st)= @_;
    my @l= collect_macros($st);
    return if (!@l);
    foreach my $m (@l)
      { $r_h->{$m}=1; };
    return(1);  
  }

sub collect_macros
  { my($st)= @_;
    my @l;
  
    while ($st=~ /\$\(([^\)]*)\)/g) 
      { push @l,$1; }; 
    return(@l);  
  }

sub filter_records
# remove all records where a field does not
# match a given regular expression
  { my($r_rec,$field,$regexp)= @_;
    my @nomatch;
    my $field_is_regexp;
    
#die "$field,$regexp";
    if ($field=~ /\//)
      { # field is a regular expression
        create_regexp_func("field_matcher",$field);
	$field_is_regexp= 1;
      };	
    
    create_regexp_func("field_filter",$regexp);

    foreach my $rec (sort keys %$r_rec)
      {
        if (!$field_is_regexp) 
	  { if (!field_filter( $r_rec->{$rec}->{FIELDS}->{$field} ))
              { push @nomatch, $rec ;
	      };
	  }
	else
	  { my @f= match_fields($r_rec->{$rec});
#print "F: " . join("|",@f) . "\n";
	    my $match;
	    foreach my $f (@f)
	      { if (field_filter( $r_rec->{$rec}->{FIELDS}->{$f}))
	          { $match=1; last; };
	      };
	    if (!$match)
              { push @nomatch, $rec ;
	      };
	  }    
      };
    foreach my $r (@nomatch)
      { 
        delete $r_rec->{$r}; 
      };
  }
 
sub filter_type
# remove all records whose type does not
# match a given regular expression
  { my($r_rec,$regexp)= @_;
    my @nomatch;
  
#die "$r_rec,$regexp";
    create_regexp_func("type_filter",$regexp);

    foreach my $rec (sort keys %$r_rec)
      { if (!type_filter($r_rec->{$rec}->{TYPE}))
          { push @nomatch, $rec ;
	  };
      };
    foreach my $r (@nomatch)
      { 
        delete $r_rec->{$r}; 
      };
  }
      
sub filter_name 
# remove all records whose name does not match a
# given regular expression
  { my($r_rec,$regexp,$invert)= @_;
    my @nomatch;
  
    create_regexp_func("name_filter",$regexp,$invert);

    foreach my $rec (sort keys %$r_rec)
      { if (!name_filter($rec))
          { push @nomatch, $rec ;
	  };
      };
    foreach my $r (@nomatch)
      { 
        delete $r_rec->{$r}; 
      };
  }

sub filter_percent
  { my($r_rec,$percent)= @_;
  
    my @rem_recs= (sort keys %$r_rec);
    my $len= $#rem_recs+1;
    
    if ($percent>0) # remove last <no> percent
      { my $n= int($percent/100*$len+0.5); # one more for safety reasons
        @rem_recs= splice @rem_recs,$n+1,($len-$n);
      }
    else
      { my $n= int((100+$percent)/100*$len+0.5);
        @rem_recs= splice @rem_recs,0,$n+1;
      };
    foreach my $r (@rem_recs)
      { 
        delete $r_rec->{$r}; 
      };
  }
         
    
sub find_val
# remove all records where not one of the
# fields matches a given regular expression
  { my($filename,$r_rec,$regexp,$do_print)= @_;
    my @fields;
    my @delete;
  
    create_regexp_func("value_filter",$regexp);
    
    foreach my $rec (sort keys %$r_rec)
      { 
        @fields= find_val_in_rec( $r_rec->{$rec});
        if (!@fields)
	  { push @delete, $rec; };
	if ($do_print)
	  { if (defined $filename)
	      { print "\nFILE $filename:\n";
	        $filename= undef;
	      };
	    print "\"$rec\": \n";
	    dump_rec_fields($r_rec->{$rec}, \@fields);
	  };  
      };
    foreach my $r (@delete)
      { 
        delete $r_rec->{$r}; 
      };
  }	
    
 
sub create_regexp_func
# create a function for regular expression
# matching
  { my($funcname,$regexp,$invert)= @_;
  
    if (!defined $regexp)
      { $regexp= '//'; };
    
    if ($regexp !~ /\//)
      { $regexp= "/$regexp/"; };
    
#    warn "func created:\n" . 
#          "sub $funcname " .
#          " { return( scalar (\$_[0]=~$regexp) ); }";
	  
    if ($regexp eq '//')
      { eval( "sub $funcname " .
           " { return( defined(\$_[0]) ); }" );
      }
    else
      { if (!defined $invert)
          { eval( "sub $funcname " .
                  " { return( scalar (\$_[0]=~$regexp) ); }" );
	  }
	else	  
          { eval( "sub $funcname " .
                  " { return( scalar (\$_[0]!~$regexp) ); }" );
	  };
      };
    if ($@)
      { die "error: eval() failed, error-message:\n" . $@ . " "  };
  }

    
# fit in program text here

# ------------------------------------------------

sub print_summary
  { printf("%-20s: $sc_summary\n",
           $sc_name);
  }

sub h_center
  { my($st)= @_;
    return( (' ' x (38 - length($st)/2)) . $st );
  }

sub help
  { my $l1= h_center("**** $sc_name $sc_version -- $sc_summary ****");
    my $l2= h_center("$sc_author $sc_year");
    print <<END;

$l1
$l2

Syntax:
  $sc_name {options} [file1] [file2...]

  options:
    -h: help
    --summary: give a summary of the script
    -i dump internal hash structure
    -r print results in db-file format (default)
    -l just list the names of the matching records
    
    --value [regexp] : print a list of all fields in records where
       the field-value matches a regular expression, 
    -v [regexp] filter records where at least one field matches
       the given regular expression
    --field [field,regexp]|[field] : process only records where
      field matches regexp  
      if regexp is omitted just test for the existence of that field
      if field is a perl-regular expression starting enclosed in
      '//' it is treated as a regular expression
    --NAME|--name|-n [regexp] filter records whose name match the given
      regular expression 
    --NOTNAME|--notname [regexp] : same as above but filter records whose names DO NOT
      match the regular expression  
    --DTYP [regexp] : filter DTYP field
    --TYPE|-t [regexp] : filter record type
    --fields|--FIELDS [field1,field2...] print only these fields
    --percent [+-number] keep the first or last n percent 
      of all records
      if number is negative, filter the LAST n percent of all
      records, otherwise filter the FIRST n percent of all records
    --list_unresolved list all unresolved variables like \$(VARNAME)
      in the db file
      
    if no file is given $sc_name reads from standard-input  
END
  }

