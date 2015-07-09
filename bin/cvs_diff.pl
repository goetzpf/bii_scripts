eval 'exec perl -S $0 ${1+"$@"}' # -*- Mode: perl -*-
    if 0;
# the above is a more portable way to find perl
# ! /usr/bin/perl

# Copyright 2015 Helmholtz-Zentrum Berlin für Materialien und Energie GmbH
# <https://www.helmholtz-berlin.de>
#
# Author: Goetz Pfeiffer <Goetz.Pfeiffer@helmholtz-berlin.de>
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


# @STATUS: release
# @PLATFORM: home bessy
# @CATEGORY: search


# [cvs_diff.pl] -- compare c-files against the repository

use strict;

use FindBin;
use Getopt::Long;
use Config;
use File::Spec;
use Text::Tabs;

use vars qw($opt_help 
            $opt_no_comments $opt_no_multiple_empty_lines
            $opt_summary $opt_revision $opt_revision2 $opt_type);


my $sc_version= "0.9";

my $sc_name= $FindBin::Script;
my $sc_summary= "compare c-files against the repository"; 
my $sc_author= "Goetz Pfeiffer";
my $sc_year= "2006";

my %type= (c => 1,
           any => 2);

my $type= 'c';	    

my $debug= 1; # global debug-switch

my $tmpdir= "/tmp";


#Getopt::Long::config(qw(no_ignore_case));

if (!GetOptions("help|h","summary",
                "revision|r=s","revision2|s=s",
		"no_comments|c",
		"no_multiple_empty_lines|m",
		"type|t=s"

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

if (defined $opt_type)
  { if (!exists $type{$opt_type})
      { die "unknown type: $opt_type"; };
    $type= $opt_type;
  };

# ------------------------------------------------

my $filename= shift(@ARGV);

if (!defined $filename)
  { die "error: name of the file is missing!\n"; };

print "file $filename:\ncomparing ";

my $file1= process($filename,$opt_revision,1,
                   $opt_no_comments,$opt_no_multiple_empty_lines);

if (!defined $file1)
  { die; };

print " against ";

$opt_revision2= "local" if (!defined $opt_revision2);
my $file2= process($filename,$opt_revision2,2,
                   $opt_no_comments,$opt_no_multiple_empty_lines);

if (!defined $file2)
  { unlink($file1);  
    die; 
  };

print "\n";

show_diff($file1,$file2);
unlink($file1);
unlink($file2);

exit(0);

# fit in program text here

sub basename
  { my($path)= @_;

    my ($volume,$directories,$file) = File::Spec->splitpath( $path );

    if ($type eq 'c')
      { if ($file!~ /(.*)\.(c|cc|cpp|CC)$/)
          { die "error: file $file is not a c file\n"; };
      };

    return($1);
  }

sub process
  { my($filename,$rev,$no,$rm_comments,$rm_spc_lines)= @_;

    if ($rev eq "local")
      { print "working copy";
        return(local_process($filename,$no,$rm_comments,$rm_spc_lines)); 
      }
    else
      { my $opt;
        if (!defined $rev)
          { print "trunk"; }
	else
	  { print "revision $rev";
	    $opt= "-r $rev"; 
	  };
        return(cvs_process($filename,$opt,$no,$rm_comments,$rm_spc_lines)); 
      }
  }

sub slurp
  { my($filename)= @_;
    local(*F);
    local($/);
    undef $/;
    open(F, $filename) or die "unable to open $filename";


    my $content= <F>;
    close(F);
    return(\$content);
  }

sub unslurp  
  { my($filename,$r_content)= @_;

    local(*F);
    open(F, ">$filename") or die "unable to create $filename";
    print F $$r_content;
    close(F);
  }


sub rm_comments
  { my($r_content)= @_;

    if ($type eq 'c')
      { # handle "<c-commands> // comment"
	$$r_content=~ s/^(\S+?)\/\/(.*?)/$1/gm;

	# handle " // comment"
	$$r_content=~ s/^\s*\/\/(.*?)\n//gm;

	# handle " /*  comment  */"
	$$r_content=~ s/\/\*.*?\*\///g;
      };
  }

sub rm_mult_spc_lines  
  { my($r_content)= @_;

    $$r_content=~ s/^\s+$//gm;
    $$r_content=~ s/\n+/\n/g;
  }


sub expand_it
  { my($r_content)= @_;

    my @lines= split(/\n/,$$r_content);

    for(my $i=0; $i<= $#lines; $i++)
      { $lines[$i]= expand($lines[$i]); };

    $$r_content= join("\n",@lines);
  }   


sub local_process
  { my($filename,$no,$rm_comments,$rm_spc_lines)= @_;
    my $cmd;

    my $base= basename($filename) . ".$no.db";
    $base= File::Spec->catfile($tmpdir,$base);

    my $r= slurp($filename);
    rm_comments($r) if ($rm_comments);
    rm_mult_spc_lines($r) if ($rm_spc_lines);
    expand_it($r);
    unslurp($base,$r);

    return($base);
  }

sub cvs_process
  { my($filename,$cvs_options,$no,$rm_comments,$rm_spc_lines)= @_;
    my $cmd;

    my $base= basename($filename) . ".$no.db";
    $base= File::Spec->catfile($tmpdir,$base);

    if (!sys("cvs update $cvs_options -p $filename 2> /dev/null > " .
             "$base"))
      { return; };
    my $r= slurp($base);
    rm_comments($r) if ($rm_comments);
    rm_mult_spc_lines($r) if ($rm_spc_lines);
    expand_it($r);
    unslurp($base,$r);

    return($base);
  }

sub show_diff
  { my($f1,$f2)= @_;

    my $cmd= "tkdiff $f1 $f2 2> /dev/null";
    sys($cmd,1);
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
    my $types= join(" ",keys %type);
    print <<END;

$l1
$l2

Syntax:
  $sc_name {options} [file]

  options:
    -h: help
    --summary: give a summary of the script
    -r [cvs-revision] (mandatory)
    -s [2nd cvs revision] (optional)
    -c --no_comments
    -m --no_multiple_empty_lines
    --type [type] :
      known types $types 

END
  }

