eval 'exec perl -S $0 ${1+"$@"}' # -*- Mode: perl -*-
    if 0;
# the above is a more portable way to find perl
# ! /usr/bin/perl

#  This software is copyrighted by the
#  Helmholtz-Zentrum Berlin fuer Materialien und Energie GmbH (HZB),
#  Berlin, Germany.
#  The following terms apply to all files associated with the software.
#  
#  HZB hereby grants permission to use, copy and modify this
#  software and its documentation for non-commercial, educational or
#  research purposes provided that existing copyright notices are
#  retained in all copies.
#  
#  The receiver of the software provides HZB with all enhancements, 
#  including complete translations, made by the receiver.
#  
#  IN NO EVENT SHALL HZB BE LIABLE TO ANY PARTY FOR DIRECT, INDIRECT,
#  SPECIAL, INCIDENTAL OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE
#  OF THIS SOFTWARE, ITS DOCUMENTATION OR ANY DERIVATIVES THEREOF, EVEN 
#  IF HZB HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#  
#  HZB SPECIFICALLY DISCLAIMS ANY WARRANTIES, INCLUDING, BUT NOT LIMITED
#  TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
#  PURPOSE, AND NON-INFRINGEMENT. THIS SOFTWARE IS PROVIDED ON AN "AS IS"
#  BASIS, AND HZB HAS NO OBLIGATION TO PROVIDE MAINTENANCE, SUPPORT,
#  UPDATES, ENHANCEMENTS OR MODIFICATIONS.


# @STATUS: release
# @PLATFORM: home bessy
# @CATEGORY: search


# [scriptname] -- describe the function here

use strict;

use FindBin;
use Getopt::Long;
use IO::Handle;

use vars qw($opt_help $opt_summary
            $opt_file $opt_name
	    $opt_time $opt_val
	    $opt_regexp $opt_progress
	    $opt_rm_tmstamp
	    );


my $sc_version= "1.0";

my $sc_name= $FindBin::Script;
my $sc_summary= "sorts a log-file created by camonitor by timestamp"; 
my $sc_author= "Goetz Pfeiffer";
my $sc_year= "2005";

my $debug= 0; # global debug-switch


#Getopt::Long::config(qw(no_ignore_case));

if (!GetOptions("help|h","summary", "file|f=s", 
                "name|n=s", "time|t=s", "val|v=s",
		"regexp|r=s", "progress|p", "rm_tmstamp|rm-tmstamp",
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

STDERR->autoflush(1);  

mk_regexp("n_regexp",$opt_name);
mk_regexp("t_regexp",$opt_time);
mk_regexp("v_regexp",$opt_val);
mk_regexp("r_regexp",$opt_regexp);

my $r_lines= slurp($opt_file);
my $r_h= mk_hash($r_lines,
                 $opt_name,$opt_time,$opt_val,$opt_regexp);
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
    my $cnt=100;

    if (defined $file)
      { open(F,$file) || die "unable to open $file"; }
    else
      { *F= *STDIN; };

    while(my $st=<F>)
      { if ($opt_progress)
          { if (--$cnt==0)
	      { print STDERR '.';
	        $cnt= 100;
	      }; 
	  };    
        chomp($st);
        push @lines,$st;
      };

    if (defined $file)
      { close(F); }; 	

    print STDERR "\n" if ($opt_progress);

    return(\@lines);
  }

sub mk_hash
  { my($r_lines,$n_regexp,$t_regexp,$v_regexp,$r_regexp)= @_;
    my %h;
    my $cnt=100;

    for(my $i=0; $i<=$#$r_lines; $i++)
      { if ($opt_progress)
          { if (--$cnt==0)
	      { print STDERR ':';
	        $cnt= 100;
	      }; 
          };
        my $line= $r_lines->[$i];
        my @a= split(/\s+/,$line);

	if (defined $n_regexp)
	  { next if (!n_regexp($a[0]));  };

	next if ($a[1] eq '<undefined>');

	if (defined $t_regexp)
	  { next if (!t_regexp($a[1] . " " . $a[2])); };  

	if (defined $v_regexp)
	  { next if (!v_regexp($a[3])); };  

	if (defined $r_regexp)
	  { next if (!r_regexp($line)); };  

	my $key= $a[1] . "," . $a[2] . "," . $a[0];
#print "$key->",$line,"\n";

	if ($opt_rm_tmstamp)
	  { $line= sprintf "%-40s %s",$a[0],$a[3]; };

	$h{$key}= $line;
      };
    print STDERR "\n" if ($opt_progress);
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
    -n [regexp]: filter record names (records must match this)
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
    -r [regexp] print only lines where the LINE matches the regexp
    -p show progress on STDERR
    --rm-tmstamp remove timestamps in output
END
  }

