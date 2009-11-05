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


# [cvs_diff.pl] -- compare logs between two cvs revisions

use strict;

use FindBin;
use Data::Dumper;

use Getopt::Long;
use Config;
use File::Spec;
use Text::Tabs;

use vars qw($opt_help $opt_file
            $opt_summary $opt_revision $opt_revision2 $opt_list
	    $opt_taglist $opt_quiet $opt_branches);


my $sc_version= "0.9";

my $sc_name= $FindBin::Script;
my $sc_summary= "compare logs between two cvs revisions"; 
my $sc_author= "Goetz Pfeiffer";
my $sc_year= "2006";

my $debug= 1; # global debug-switch

my $tmpdir= "/tmp";


#Getopt::Long::config(qw(no_ignore_case));

if (!GetOptions("help|h","summary", "file|f=s",
                "revision|r=s","revision2|s=s",
		"list|l", "taglist:i", "quiet|q",
		"branches|b"
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

# ------------------------------------------------

if ((!defined $opt_taglist) && (!defined $opt_revision))
  { die "-r is mandatory"; };

if (defined $opt_list)
  { if (!defined $opt_revision2)
      { die "-s is mandatory when -l is used"; };
  }  

my($r_files,$r_logs)= cvs_log();
#print Dumper $r_logs;

if (defined $opt_taglist)
  { cvs_taglist($r_files,$r_logs,$opt_taglist);
    exit(0);
  };

if (defined $opt_list)
  { cvs_tag_change_display($r_files,$r_logs,$opt_revision,$opt_revision2);
    exit(0);
  };


my @files;
if (!defined $opt_file)
  { @files= @$r_files; }
else
  { @files= ($opt_file); };

foreach my $file (@files)
  { cvs_log_display($r_logs,$file,
                    $opt_revision,$opt_revision2,$opt_branches); }

exit(0);


my($r_files,$r_taginfo)= cvs_tags();

foreach my $f (@$r_files)
  { my $rep= cvs_logs($r_taginfo->{$f},$f,$opt_revision,$opt_revision2);
    print $$rep,"\n"; 
  }


sub cvs_log
  { local(*STATUS);
    my $file;
    my $lineno= 0;

    my %h;
    my $r_file;
    my $r_tags;
    my $r_desc;

    my $desc_rev;
    my $r_desc_text;
    my @files;


    open(STATUS, "cvs log 2>&1 |")
      || die "can't fork: $!";
    my $status= 'initial';
    while (my $line=<STATUS>) 
      { $lineno++;
        if ($status eq 'initial')
          { next if ($line=~ /^\s*$/);
            if ($line=~/^\s*Working file:\s+(.*)$/)
	      { $file= $1;
	        $status= 'file';
		$r_file= {};
		$h{$file}= $r_file;
		push @files,$file;
	        next;
              };
	    next; # maybe a warning here ?  
	  };

	if ($status eq 'symbolic names')
          { 
#die "line: $line";
	    if ($line=~ /^\s*([^:]+):\s+([\d\.]+)/)
	      { 
#die;
	        $r_tags->{$1}= $2;
	        next;
	      };
	    $status= 'file';  
	  }

	if ($status eq 'description')
          { if ($line=~ /^-----/)
	      { next; };
	    if ($line=~ /^revision\s+([\d\.]+)/)
	      { $desc_rev= $1;
	        my $t= "";
	        $r_desc_text= \$t;
	        $r_desc->{$desc_rev}= $r_desc_text;
		# $r_desc->{$rev}  
	        $status= 'desc-text';
		next;
              };
	    die "parse error in line $lineno:\n$line\n ";  
	  }      

	if ($status eq 'desc-text')
	  { if ($line=~ /^-----/)
	      { $status= 'description';
	        next;
	      };
	    if ($line=~ /^====/)  
	      { $status= 'initial';
	        next;
              };
	    $$r_desc_text.= $line;
	    next;
	  }

	if ($status eq 'file')
	  { next if ($line=~ /^\s*$/);
            if ($line=~ /^symbolic names:/)
	      { $status= 'symbolic names';
	        $r_tags= {};
		$r_file->{TAGS}= $r_tags;
	        next;
	      };
	    if ($line=~ /^description:/)
	      { $status= 'description';
	        $r_desc= {};
		$r_file->{DESC}= $r_desc;
	        next;
	      };
            if ($line=~ /^====/)  
	      { $status= 'initial';
	        next;
              };
   	    next;
	  }  
      } # while

    close STATUS || die "bad netstat: $! $?";
    return(\@files,\%h);
  }

sub sortcmp_versions
  { cmp_versions($a,$b); }

sub cmp_versions
  { my($a,$b)= @_;
    my @x= split(/\./,$a);
    my @y= split(/\./,$b);
    my $x;
    my $y;
    for(;;)
      { $x= shift @x;
        $y= shift @y;
	if (!defined $x)
	  { return 0 if (!defined $y);
	    return -1;
	  };
	if (!defined $y)
	  { return 1; };
	if ($x<$y)
	  { return -1; };
	if ($x>$y)
	  { return 1; };
      }
  }	    

sub version_dots
  { my($v)= @_;
    my $w= $v;
    $w=~ s/\.//g;
    return(length($v)-length($w));
  }      

sub cvs_log_display
  { my($r_logs,$file,$from_tag,$to_tag,$use_branches)= @_;
    my $dots;

    my $r_file_logs= $r_logs->{$file};

    if (!defined $r_file_logs)
      { die "no log information about \"$file\"\n "; };  

    my $r_tags= $r_file_logs->{TAGS};
    my $r_desc= $r_file_logs->{DESC};

    my $from_rev= $r_tags->{$from_tag};

    if (!defined $from_rev)
      { warn "tag $from_tag not known for file $file\n" if (!$opt_quiet);
	return;
      };

    $dots= version_dots($from_rev);

#die "from: $from_rev"; 

    my $to_rev;
    if (defined $to_tag)
      { $to_rev= $r_tags->{$to_tag};
        if (!defined $to_rev)
          { warn "tag $to_tag not known for file $file\n" if (!$opt_quiet);
	    return;
          };
	my $x= version_dots($to_rev);
	if ($x>$dots)
	  { $dots= $x; };
      };

    my @revs= sort sortcmp_versions (keys %$r_desc);

#print "$file FROM: $from_rev\n"; 
    my $first=1;
    for(my $i=0; $i<=$#revs; $i++)
      { 

#print "REV: $revs[$i]\n";      
        next if (cmp_versions($revs[$i],$from_rev)<=0);
        if (defined $to_rev)
	  { next if (cmp_versions($to_rev,$revs[$i])<0); 

	  };
#warn;
        if (!$use_branches)
	  { next if (version_dots($revs[$i])>$dots); };

	if ($first)
	  { $first=0; 
	    print "=" x 60,"\n";
	    print "file $file:\n\n";
	  }
	else
	  { print "-" x 30,"\n"; 
	  };

	print "revision $revs[$i]\n";
	print ${$r_desc->{$revs[$i]}}; 
      };
  }

sub cvs_tag_change_display
  { my($r_files,$r_logs,$from_tag,$to_tag)= @_;

    foreach my $file (@$r_files)
      { my $r_file_logs= $r_logs->{$file};

	if (!defined $r_file_logs)
	  { die "no log information about \"$file\"\n "; };  

        my $r_tags= $r_file_logs->{TAGS};

        my $from_rev= $r_tags->{$from_tag};
	if (!defined $from_rev)
	  { warn "tag $from_tag not known for file $file\n" if (!$opt_quiet);
	    next;
	  };

        my $to_rev= $r_tags->{$to_tag};
	if (!defined $to_rev)
	  { warn "tag $to_tag not known for file $file\n" if (!$opt_quiet);
	    next;
	  };

	next if ($from_rev eq $to_rev);

	print $file,"\n";
      } 
  }	

sub cvs_taglist
  { my($r_files,$r_logs,$min_no)= @_;
    my %tags;

    if ($min_no<=0)
      { $min_no= $#$r_files + $min_no + 1; };
    foreach my $file (@$r_files)
      { my $r_file_logs= $r_logs->{$file};

	if (!defined $r_file_logs)
	  { die "no log information about \"$file\"\n "; };  

        my $r_tags= $r_file_logs->{TAGS};
	foreach my $t (keys %$r_tags)
	  { $tags{$t}+=1; };

      } 
#print Dumper \%tags;
#print "min:$min_no\n";  
#die;
    my @found= grep { $tags{$_}>=$min_no } (keys %tags);  

    print join("\n",(sort @found)),"\n"; 
  }	

sub sys
  { my($cmd,$nowarn)= @_;

    print "$cmd\n" if ($debug);
    if (system($cmd) && !$nowarn)
      { warn "\"$cmd\" failed : $?"; 
        return;
      };
    return(1);
  }

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
  $sc_name {options} [file]

  options:
    -h: help
    --summary: give a summary of the script
    -r --revision  [cvs-tag1] (mandatory)
    -s --revision2 [cvs-tag2] (optional)
    -s [2nd cvs revision] (optional)
    -f [file] show logs only for a single file
    -l list only files that changed from tag1 to tag2
    --taglist [no] 
      no positive: list all tags found in at least [no] files
      no negative: list all tags found in at least [fileno+no] files
        e.g -taglist -2 with 100 files: must be found in at least 98 files
    -q : suppress "tag [TAG] not known..." warnings	
    -b --branches: include branches into log-display   
END
  }

