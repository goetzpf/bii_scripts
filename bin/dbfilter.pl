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
use canlink;

use vars qw($opt_help $opt_summary
            $opt_dump_internal $opt_recreate
	    $opt_short
	    $opt_val_regexp @opt_field 
	    $opt_name 
	    $opt_notname 
	    $opt_type
	    $opt_value
	    $opt_dtyp
	    $opt_fields
	    $opt_empty
	    $opt_skip_empty_records
	    $opt_list
	    $opt_percent
	    $opt_unresolved_variables
	    $opt_unresolved_links
	    $opt_unresolved_links_plain
	    $opt_record_references
	    $opt_allow_double
	    $opt_single
	    $opt_lowcal
	    $opt_Lowcal
	    $opt_sdo
	    $opt_Sdo
	   );


my $sc_version= "1.5";

my $sc_name= $FindBin::Script;
my $sc_summary= "parse db files"; 
my $sc_author= "Goetz Pfeiffer";
my $sc_year= "2005";

my $debug= 0; # global debug-switch

my @dtyp_link_fields= qw(INP OUT);

my @link_fields= qw(
DOL
FLNK
INP
INPA
INPB
INPC
INPD
INPE
INPF
INPG
INPH
INPI
INPJ
INPK
INPL
LNK1
LNK2
LNK3
LNK4
LNK5
LNK6
LNK7
OUT
SDIS
SELL);

my %dtyp_link_fields; #initialized later
my %link_fields;      #initialized later


#Getopt::Long::config(qw(no_ignore_case));

if (!@ARGV)
  { help();
    exit;
  };

Getopt::Long::config(qw(no_ignore_case));

if (!GetOptions("help|h","summary",
                "dump_internal|i", "recreate|r", "val_regexp|v=s",
		"short|s",
		"field=s@", 
		"name|NAME|n=s", "notname|NOTNAME=s", 
		"value=s",
		"dtyp|DTYP=s",
		"type|TYPE|t=s", 
		"fields|FIELDS=s",
		"empty|e",
		"skip_empty_records|E",
		"list|l",
		"percent=s",
		"unresolved_variables",
		"unresolved_links",
		"unresolved_links_plain",
		"record_references|R=s",
		"allow_double|A",
		"single|S",
		"lowcal", "Lowcal",
		"sdo", "Sdo",
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

if    (defined $opt_allow_double)
  { parse_db::handle_double_names(2); }
elsif (defined $opt_single)
  { parse_db::handle_double_names(0); }
else
  { # merging of double record-names is the default
    parse_db::handle_double_names(1); 
  }

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

    if ($opt_dtyp)
      { filter_records($recs,"DTYP",$opt_dtyp);
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

    if (defined $opt_empty)
      { remove_empty_fields($recs); 
      };

    if (defined $opt_percent)
      { filter_percent($recs,$opt_percent); };

    if ((!defined $opt_dump_internal) && 
	(!defined $opt_lowcal) &&
	(!defined $opt_Lowcal) &&
	(!defined $opt_sdo) &&
	(!defined $opt_Sdo) &&
	(!defined $opt_short) &&
	(!defined $opt_recreate) &&
	(!defined $opt_value) &&
	(!defined $opt_list) &&
	(!defined $opt_unresolved_variables) &&
	(!defined $opt_unresolved_links) &&
	(!defined $opt_unresolved_links_plain) &&
	(!defined $opt_record_references)
       )
      { $opt_recreate=1; };

    if (defined $opt_value)
      { find_val($filename,$recs,$opt_val_regexp,1);
	next;
      };

    if (defined $opt_unresolved_variables)
      { list_unresolved_variables($filename,$recs,1);
        next;
      };
    
    if (defined $opt_unresolved_links)
      { list_unresolved_links($filename,$recs,1);
        next;
      };
    
    if (defined $opt_unresolved_links_plain)
      { list_unresolved_links($filename,$recs,1,1);
        next;
      };
      
    if (defined $opt_record_references)
      { 
        list_record_references($filename,$recs,
	                       $opt_record_references,
			       $opt_recreate);
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

    if ((defined $opt_lowcal) || (defined $opt_Lowcal))
      { lowcal($filename,$recs,(defined $opt_Lowcal));
	next;
      };

    if ((defined $opt_sdo) || (defined $opt_Sdo))
      { sdo($filename,$recs,(defined $opt_Sdo));
	next;
      };

    if (defined $opt_skip_empty_records)
      { rem_empty_records($recs); };

    if (defined $opt_dump_internal)
      { dump_recs($filename,$recs);
	next;
      };

    if (defined $opt_short)
      { one_line_dump_recs($filename,$recs);
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

sub rem_empty_records
  { my($r_rec)= @_;
    
    foreach my $recname (keys %$r_rec)
      { my $r_f= $r_rec->{$recname}->{FIELDS};
	if (!%$r_f)
	  { delete $r_rec->{$recname}; };
      };
  }

sub one_line_dump_recs
# dump all records, one record per line
  { my($filename,$r_rec)= @_;
    
    print "\nFILE $filename:\n" if (defined $filename);
    
    foreach my $recname (sort keys %$r_rec)
      { print "$recname";
        my $r_f= $r_rec->{$recname};
	print ",",$r_f->{TYPE},",";
	my $r= $r_f->{FIELDS};
	my $comma;
	foreach my $f (sort keys %$r)
	  { print $comma,$f,"=",$r->{$f}; 
	    $comma= ",";
	  }
        print "\n";  
      };
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

sub remove_empty_fields
# remove empty fields in all records
  { my($r_rec)= @_;
  
    foreach my $rec (keys %$r_rec)
      { my $r_values= $r_rec->{$rec}->{FIELDS};
        foreach my $f (keys %$r_values)
	  { if ($r_values->{$f}=~ /^\s*$/)
	      { delete $r_values->{$f}; };
	  };
      };
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

sub list_unresolved_variables
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
    if (defined $filename)
      { print "\nFILE $filename:\n"; };
    print "=" x 40,"\n";
    if ($do_list)
      { print "unresolved macros in these records:\n";
        print "-" x 40,"\n";
        print join("\n",sort keys %recs);
      };
    print "\n\nList of unresolved macros:\n";
    print "-" x 40,"\n";
    print join("\n",sort keys %mac),"\n";  
  } 

sub list_record_references
  { my ($filename,$recs,$record_name,$recreate)= @_;

    my %references;
    my %referenced_by;
    my @reclist;
    my %to_print;

    foreach my $recname (keys %$recs)
      { my @references   = find_referenced_records($recs,$recname);
        next if (!@references);
	$references{$recname}= { map { $_ => 1 } @references };
        foreach my $r (@references)
	  { $referenced_by{$r}->{$recname}= 1; }; 
      };
    
    
    if ($record_name !~ /^(all|\/\/)$/i)
      { create_regexp_func("ref_name_filter",$record_name);
        foreach my $rec (sort keys %$recs)
          { 
	    if (ref_name_filter($rec))
	      {
	        push @reclist,$rec; 
	      };
	  };
	if (!@reclist)
	  { die "no record-names match the given pattern: $record_name\n"; };  
      }
    else
      { @reclist=(sort keys %$recs); };
    
    if (defined $filename)
      { print "\nFILE $filename:\n"; 
	print "=" x 40,"\n";
      };

    if ($recreate)
      { %to_print= map { $_ => 1 } @reclist; };
    
    foreach my $recname (@reclist)
      { my $r_references   = $references{$recname};
        my $r_referenced_by= $referenced_by{$recname};
      
        if ((!defined $r_references) && (!defined $r_referenced_by))
	  { next; };
	
	print "$recname\n";
	if (defined $r_references)
	  { if ($recreate)
	      { foreach my $r (keys %$r_references)
	          { $to_print{$r}= 1; };
	      };	  
	    print "  references:\n\t",join("\n\t",sort keys %$r_references),"\n"; 
	  };
	if (defined $r_referenced_by)
	  { if ($recreate)
	      { foreach my $r (keys %$r_referenced_by)
	          { $to_print{$r}= 1; };
	      };	  
	    print "  referenced by:\n\t",join("\n\t",sort keys %$r_referenced_by),"\n"; 
	  };
      };
    if ($recreate)
      { print "=" x 40,"\nRecords:\n";
        my %my_recs= map { $_ => $recs->{$_} } (keys %to_print);
        parse_db::create(\%my_recs);
      };  
  } 
 
sub find_record_references
# find all records that do reference <$recname>  
  { my($recs, $recname)= @_;
    my %recs_found;
  
    foreach my $n_recname (keys %$recs)
      { 
        my $r_recs= rec_link_fields($recs->{$recname}->{FIELDS},'rechash');
	if (exists $r_recs->{$recname})
	  { $recs_found{$n_recname}= 1; };
      };
    return(sort keys %recs_found);
  }	  
	      
sub find_referenced_records
# give a list of all records that a given record references
  { my($recs, $recname)= @_;
    
    return( rec_link_fields($recs->{$recname}->{FIELDS},'reclist') );
  }

sub list_unresolved_links
  { my ($filename,$recs,$do_list,$plain_list)= @_;
    my $res;
    my %mac;
    my %found_recs;
    
    foreach my $recname (keys %$recs)
      { 
        my $r_ref_fields= rec_link_fields($recs->{$recname}->{FIELDS},'hash');
        foreach my $f (keys %$r_ref_fields)
	  { if (exists $recs->{$r_ref_fields->{$f}})
	      { delete $r_ref_fields->{$f}; };
	  };
	if (!%$r_ref_fields)
	  { next; };
	$found_recs{$recname}= $r_ref_fields;
      };
    if (defined $filename)
      { print "\nFILE $filename:\n"; };
    if ($plain_list)
      { # just list all items (values) that are missing
        my %values;
        foreach my $recname (keys %found_recs)
	  { my $r_f= $found_recs{$recname};
            foreach my $field (keys %$r_f)
	      { $values{$r_f->{$field}}= 1; };
	  };
	print join("\n",sort keys %values),"\n";
	return;
      };
    
    print "=" x 40,"\n";
    if ($do_list)
      { print "unresolved links in these records:\n";
        print "-" x 40,"\n";
        print join("\n",sort keys %found_recs);
      };
    print "\n\nList of fields with unresolved links\n";
    print "-" x 40,"\n";
    foreach my $recname (sort keys %found_recs)
      { my $r_f= $found_recs{$recname};
        print "record: $recname\n";
        foreach my $field (sort keys %$r_f)
	  { print "\t$field : ",$r_f->{$field},"\n"; };
      };
  } 

sub rec_link_fields
# return a hash-reference of field->value pairs 
# where the values
# are the names of referenced other records 
  { my($r_fields,$mode)= @_;
  
    if (!%dtyp_link_fields)
      { %dtyp_link_fields= map{ $_ => 1 } @dtyp_link_fields; };
    if (!%link_fields)
      { %link_fields= map{ $_ => 1 } @link_fields; };
  
    my %h;
    
    foreach my $fieldname (keys %$r_fields)
      { next if (!exists $link_fields{$fieldname});
	my $val= $r_fields->{$fieldname};
	# is it empty ?
	next if ($val =~ /^\s*$/);
	# is it a number ?
	next if ($val =~ /^\s*[+-]?\d+\.?\d*(|[eE][+-]?\d+)$/);
	if (exists ($dtyp_link_fields{$fieldname}))
	  { # maybe a hardware link ?
	    if ($r_fields->{DTYP} ne 'Soft Channel')
	      { next; };
	  };	  
        $val=~ s/[\. ]?(CA|CPP|NPP|NMS|MS|PP)\s*//g;	    
	$val=~ s/\s+$//;
	# remove field-names:
	$val=~ s/\.\w+$//;
	if    ($mode eq 'hash')
	  { $h{$fieldname}= $val; }
	else
	  { $h{$val}= 1; };
      };
    if    ($mode eq 'hash')
      { return(\%h); }
    elsif ($mode eq 'reclist')
      { return(sort keys %h); }
    elsif ($mode eq 'rechash') 
      { return(\%h); }
    else
      { die; };
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
 
sub lowcal
  { my($filename,$r_rec,$reverse)= @_;
  
    filter_records($r_rec,"DTYP","lowcal"); 
    filter_fields($r_rec,['INP','OUT']);
    
    if (!$reverse)
      { printf "%-25s%-3s %s\n","recordname","dir",canlink::tab_print(); }
    else
      { printf "%s %-3s %-25s\n",canlink::tab_print(),"dir","recordname"; }
    
    foreach my $recname (sort keys %$r_rec)
      { my $r= $r_rec->{$recname}->{FIELDS};
        my $link= $r->{OUT};
	my $dir= "OUT";
	if (!defined $link)
	  { $link= $r->{INP}; 
	    $dir="INP";
	  };

        my %h= canlink::decode($link);
      
        if (!$reverse)
          { printf "%-25s%-3s %s\n",$recname,$dir,canlink::tab_print(%h); }
	else
          { printf "%s %-3s %-25s\n",canlink::tab_print(%h),$dir,$recname; }
      };
  }
 
sub sdo
  { my($filename,$r_rec,$reverse)= @_;
  
    filter_records($r_rec,"DTYP","SDO"); 
    filter_fields($r_rec,['INP','OUT']);
    
    if (!$reverse)
      { printf "%-28s%-3s %s\n","recordname","dir",sdo_tab_print(); }
    else
      { printf "%s %-3s %-28s\n",sdo_tab_print(),"dir","recordname"; }
    
    foreach my $recname (sort keys %$r_rec)
      { my $r= $r_rec->{$recname}->{FIELDS};
        my $link= $r->{OUT};
	my $dir= "OUT";
	if (!defined $link)
	  { $link= $r->{INP}; 
	    $dir="INP";
	  };

        my %h= sdo_decode($link);
      
        if (!$reverse)
          { printf "%-28s%-3s %s\n",$recname,$dir,sdo_tab_print(%h); }
	else
          { printf "%s %-3s %-28s\n",sdo_tab_print(%h),$dir,$recname; }
      };
  }

sub sdo_decode
  { my($str)= @_;
    my($connection_char,$port,$node,$index,
       $subindex,$datasize,$conversion_char,$timeout);
    
    my %h;
    
    if   ($str=~/^\@C:(.)\s+A:(\d+),(\d+),(\d+),(\d+)\s+
                 V:(\d+),(.)\s+T:(\d+)\s*$/x)
      { $connection_char= $1;
        $port           = $2;
	$node           = $3;
	$index          = $4;
	$subindex       = $5;
	$datasize       = $6;
	$conversion_char= $7;
	$timeout        = $8;
      }
    elsif ($str=~/^\@C:(.)\s+
                  X:([0-9A-Fa-f]+),([0-9A-Fa-f]+),
		    ([0-9A-Fa-f]+),([0-9A-Fa-f]+)\s+
                  V:(\d+),(.)\s+T:(\d+)\s*$/x)
      { $connection_char= $1;
        $port           = hex($2);
	$node           = hex($3);
	$index          = hex($4);
	$subindex       = hex($5);
	$datasize       = $6;
	$conversion_char= $7;
	$timeout        = $8;
      } 
    else
      { die "link not parsable:\"$str\""; };

    if    (lc($connection_char) eq 's') 
      { $h{HOSTTYPE}= "SERVER"; }
    elsif (lc($connection_char) eq 'c') 
      { $h{HOSTTYPE}= "CLIENT"; }
    else
      { die "link tot parsable:\"$str\""; };
      
    if    (lc($conversion_char) eq 'r') 
      { $h{DATATYPE}= "RAW"; }
    elsif (lc($conversion_char) eq 'i') 
      { $h{DATATYPE}= "INT"; }
    else
      { die "link not parsable (conv.char):\"$str\""; };
    
    if ($subindex>255)
      { die "link not parsable (subindex range):\"$str\""; };
      
    $h{PORT}    = $port;
    $h{NODE}    = $node;
    $h{INDEX}   = $index;
    $h{SUBINDEX}= $subindex;
    $h{DATASIZE}= $datasize;
    $h{TIMEOUT} = $timeout;
    return(%h);
  }
 
sub sdo_tab_print
  { my(%p)= @_;
       
    # HOSTTYPE, PORT, NODE, INDEX, SUBINDEX, DATASIZE, DATATYPE, TIMEOUT
    if (!@_)
      { my $st= sprintf "%-7s %3s %3s %5s %4s %3s %3s %5s", 
                        "hosttp",
			"prt",
			"nod",
			"idx",
			"sidx",
			"dsz",
			"dtp",
			"tmo";
        return($st);
      };
 
    my $st= sprintf "%-7s %3d %3d %5d %4d %3d %3s %5d", 
               lc($p{HOSTTYPE}),
	       $p{PORT},
	       $p{NODE},
	       $p{INDEX}, 
	       $p{SUBINDEX}, 
	       $p{DATASIZE},
	       lc($p{DATATYPE}),
	       $p{TIMEOUT};
 
    return($st);
  }            
   
sub create_regexp_func
# create a function for regular expression
# matching
  { my($funcname,$regexp,$invert)= @_;
    my $str;
  
    if (!defined $regexp)
      { $regexp= '//'; };
    
    if ($regexp !~ /\//)
      { $regexp= "/$regexp/"; };
    
    if ($regexp eq '//')
      { $str= "sub $funcname " .
           " { return( defined(\$_[0]) ); }";
        eval( $str );
      }
    else
      { if (!$invert)
          { $str= "sub $funcname " .
                  " { return( scalar (\$_[0]=~$regexp) ); }";
	    eval( $str );
	  }
	else	  
          { $str= "sub $funcname " .
                  " { return( scalar (\$_[0]!~$regexp) ); }"; 
	    eval( $str );
	  };
      };

    #warn "func created:\n$str\n"; 

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
    my $l= $#link_fields/2;
    my $links1= join(",",@link_fields[0..$l]);
    my $links2= join(",",@link_fields[($l+1)..$#link_fields]);
    print <<END;

$l1
$l2

Syntax:
  $sc_name {options} [file1] [file2...]

  options:
  
    -h: help
    --summary: give a summary of the script

  specify the type of output:
  
    -i dump internal hash structure
    -r print results in db-file format (default)
    -s print results, one line per record
    -l just list the names of the matching records
   
  remove/filter records: 
    -E|--skip_empty_records: records that have no fields (due to
       filtering options that remove fields) are not printed
    
  remove/filter fields: 
    --fields --FIELDS [field1,field2...] 
      print only these fields

    -e --empty remove empty fields
   
  special options:
  
    --percent [+-number] 
      keep the first or last n percent of all records
      if number is negative, filter the LAST n percent of all
      records, otherwise filter the FIRST n percent of all records

    --unresolved_variables 
      list all unresolved variables like \$(VARNAME) in the db file

    --unresolved_links 
      try to find unresolved links in the db-file.
      list all links that cannot be resolved within the
      db file. Currently the followings list of fields is expected to
      contain links:
      $links1
      $links2
      All values that seem to be a number or an empty string are ignored

    --unresolved_links_plain
      like --unresolved_links but list only the values themselves, 
      nothing else 

    --record_references -R [regexp]
      list which record (whose name matches regexp) is connected 
      to which other record. regexp may be "all" or "//" in which 
      case all records that are connected to other records are
      shown. This option can be combined with "-r", in this case
      all the contents of the shown records are printed in 
      db-file format       

    --allow_double -A : allow double record names 
      (for debugging faulty databases)

    --single -S : forbid double record names 
      (for debugging faulty databases)

    --lowcal: print records with DTYP=lowcal and decode
      the CAN link. Record names and can-link properties are
      printed in a table format 

    --Lowcal: identical to --lowcal except that the record
      names are in the last, not in the first column  

    --sdo: print records with DTYP=SDO and decode
      the CAN link. Record names and can-link properties are
      printed in a table format 

    --Sdo: identical to --sdo except that the record
      names are in the last, not in the first column  

   filter field values:
    
    --value [regexp] 
       print a list of all fields in records where
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

    --NOTNAME|--notname [regexp] : same as above but filter records 
      whose names DO NOT match the regular expression  

    --DTYP [regexp] : filter DTYP field

    --TYPE|-t [regexp] : filter record type
    
    if no file is given $sc_name reads from standard-input  
END
  }

