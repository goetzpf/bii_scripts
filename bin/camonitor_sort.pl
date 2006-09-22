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

use vars qw($opt_help $opt_summary
            $opt_file $opt_regexp
	    $opt_time $opt_val);


my $sc_version= "0.9";

my $sc_name= $FindBin::Script;
my $sc_summary= "sorts a log-file created by camonitor by timestamp"; 
my $sc_author= "Goetz Pfeiffer";
my $sc_year= "2005";

my $debug= 0; # global debug-switch


#Getopt::Long::config(qw(no_ignore_case));

if (!GetOptions("help|h","summary", "file|f=s", 
                "regexp|r=s", "time|t=s", "val|v=s"
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

mk_regexp("n_regexp",$opt_regexp);
mk_regexp("t_regexp",$opt_time);
mk_regexp("v_regexp",$opt_val);

my $r_lines= slurp($opt_file);
my $r_h= mk_hash($r_lines,$opt_regexp,$opt_time,$opt_val);
print_sorted($r_h);
exit(0);

# ------------------------------------------------

#die "no command-line options given!";

# fit in program text here

# ------------------------------------------------

sub mk_regexp
  { my($funcname,$regexp)= @_;

    return if (!defined $regexp);

    if ($regexp !~ /^\//)
      { $regexp= '/' . $regexp . '/'; };

#die "eval:\"sub n_regexp { return(\$_[0]=~ $regexp); }\""; 
    eval("sub $funcname { return(\$_[0]=~ $regexp); }");
    if ($@)
      { die "error: eval() failed, error-message:\n" . $@ . " "  };
  }

sub slurp
  { my($file)= @_;
#    local $/;
#    undef $/;
    local(*F);
    my @lines;
    
    if (defined $file)
      { open(F,$file) || die "unable to open $file"; }
    else
      { *F= *STDIN; };
    
    while(my $st=<F>)
      { chomp($st);
        push @lines,$st;
      };

    if (defined $file)
      { close(F); }; 	
    
    return(\@lines);
  }

sub mk_hash
  { my($r_lines,$regexp,$t_regexp,$v_regexp)= @_;
    my %h;
    
    for(my $i=0; $i<=$#$r_lines; $i++)
      {
        my $line= $r_lines->[$i];
        my @a= split(/\s+/,$line);
        
	if (defined $regexp)
	  {
	    next if (!n_regexp($a[0])); 
	  };
	  
	if (defined $t_regexp)
	  { next if (!t_regexp($a[1] . " " . $a[2])); };  

	if (defined $v_regexp)
	  { next if (!v_regexp($a[3])); };  
	
	my $key= $a[1] . "," . $a[2] . "," . $a[0];
#print "$key->",$line,"\n";
	$h{$key}= $line;
      };
    return(\%h);
  }
  
sub print_sorted
  { my($r_h)= @_;
  
    foreach my $k (sort keys %$r_h)
      { print $r_h->{$k},"\n"; };
  }      
    

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
  $sc_name {options} 

  options:
    -h: help
    --summary: give a summary of the script
    -f [file]: read that file, otherwise read STDIN
    -r [regexp]: filter record names (records must match this)
    -t [regexp]: filter times (times must match this)
      examples:
        -t 2006-09-14
	  print only from that date
	-t '2006-09-14 23'
	  print only from 2006-09-14, 23:00 to 23:59
	-t '2006-09-14 (22|23)'
	  print only from 2006-09-14, 22:00 to 23:59
    -v [regexp]: filter values (values must match this)	 
      examples
        -v '\d+'
	  print only records where the value is an integer
	-v '(enabled|disabled)'
	  print only records where the value is "enabled" or "disabled"     
END
  }

