eval 'exec perl -S $0 ${1+"$@"}' # -*- Mode: perl -*-
    if 0;
# the above is a more portable way to find perl
# ! /usr/bin/perl

# Copyright 2022 Helmholtz-Zentrum Berlin für Materialien und Energie GmbH
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


# [adl_cvs_diff.pl] -- compare an adl file against the repository

use strict;

use FindBin;
use Getopt::Long;
use Config;
use File::Spec;

use vars qw($opt_help 
            $opt_summary 
	    $opt_svn
	    $opt_revision $opt_revision2
	    $opt_legacy);


my $sc_version= "1.0";

my $sc_name= $FindBin::Script;
my $sc_summary= "compare an adl file against the repository"; 
my $sc_author= "Goetz Pfeiffer";
my $sc_year= "2007";

my $debug= 0; # global debug-switch

my $tmpdir= "/tmp";
my $adlsort= "adlsort.pl";


#Getopt::Long::config(qw(no_ignore_case));

if (!GetOptions("help|h","summary",
                "svn",
                "revision|r=s","revision2|s=s","legacy"
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

if ($opt_legacy)
  { $adlsort.= " --legacy"; };

# ------------------------------------------------

my $filename= shift(@ARGV);

if (!defined $filename)
  { die "error: name of the capfast file is missing!\n"; };

print "file $filename:\ncomparing ";

my $file1= process($filename,$opt_revision,1);

if (!defined $file1)
  { die; };

print " against ";

$opt_revision2= "local" if (!defined $opt_revision2);
my $file2= process($filename,$opt_revision2,2);

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

    if ($file!~ /(.*)\.(?:adl|cdl)$/)
      { die "error: file $file is not a capfast file\n"; };

    return($1);
  }

sub process
  { my($filename,$rev,$no)= @_;

    if ($rev eq "local")
      { print "working copy";
        return(local_process($filename,$no)); 
      }
    else
      { if (!defined $rev)
          { print "trunk"; }
	else
	  { print "revision $rev";
	  };
        if (!defined ($opt_svn))
	  { return(cvs_process($filename,$rev,$no)); }
	else
	  { return(svn_process($filename,$rev,$no)); }
      }
  }

sub local_process
  { my($filename,$no)= @_;
    my $cmd;

    my $base= basename($filename) . ".$no.db";
    $base= File::Spec->catfile($tmpdir,$base);

    if (!sys("$adlsort -f $filename > $base"))
      { return; };
    return($base);
  }

sub cvs_process
  { my($filename,$rev,$no)= @_;
    my $cmd;

    my $cvs_options;
    if (defined $rev)
      { $cvs_options= "-r $rev"; 
      };

    my $base= basename($filename) . ".$no.db";
    $base= File::Spec->catfile($tmpdir,$base);

    if (!sys("cvs update $cvs_options -p $filename 2> /dev/null | " .
             "$adlsort > $base"))
      { return; };
    return($base);
  }

sub svn_process
  { my($filename,$rev,$no)= @_;
    my $cmd;

    if (!defined $rev)
      { $rev= 'HEAD'; }; 
    # else: leave revision number 

    my $base= basename($filename) . ".$no.db";
    $base= File::Spec->catfile($tmpdir,$base);

    if (!sys("svn cat -r $rev $filename 2> /dev/null | " .
             "$adlsort > $base"))
      { return; };
    return($base);
  }

sub show_diff
  { my($f1,$f2)= @_;

    my $cmd= "tkdiff $f1 $f2 2>/dev/null";
    sys($cmd);
  }

sub sys
  { my($cmd)= @_;

    print "\n$cmd\n" if ($debug);
    if (system($cmd))
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
    --svn: use subversion instead of cvs
    -r [cvs-revision] (mandatory)
    -s [2nd cvs revision] (optional)
    --legacy: allow old-style meta-commands in *.cdl files
      (like #if and #endif)    
END
  }

