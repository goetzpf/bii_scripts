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


# [sch_cvs_diff.pl] -- compare a vdb file against the repository

use strict;

use FindBin;
use Getopt::Long;
use Config;
use File::Spec;

use vars qw($opt_help 
            $opt_summary 
	    $opt_cvs
	    $opt_svn
	    $opt_hg
	    $opt_darcs
	    @opt_revision
	    @opt_match
	    @opt_patch
	    $opt_textmode);


my $sc_version= "1.0";

my $sc_name= $FindBin::Script;
my $sc_summary= "compare a vdb file against the repository"; 
my $sc_author= "Goetz Pfeiffer";
my $sc_year= "2009";

my $debug= 0; # global debug-switch

my $tmpdir= "/tmp";


#Getopt::Long::config(qw(no_ignore_case));

if (!GetOptions("help|h","summary",
                "cvs","svn","hg","darcs",
                "revision|r=s@",
		"match=s@",
		"patch=s@",
		"textmode|t",
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

check_version_control_opt();

my $filename= shift(@ARGV);

if (!defined $filename)
  { die "error: name of the vdb file is missing!\n"; };

print "file $filename:\ncomparing ";

if (defined $opt_darcs)
  { $opt_revision[0]= process_darcs_revision($opt_revision[0], 
                                             $opt_match[0],$opt_patch[0]);
    $opt_revision[1]= process_darcs_revision($opt_revision[1],
                                             $opt_match[1],$opt_patch[1]);
  }

my $file1= process($filename,$opt_revision[0],1);

if (!defined $file1)
  { die; };

print " against ";

my $file2= process($filename,defined($opt_revision[1]) ? $opt_revision[1] : "local",2);

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

    if ($file!~ /(.*)\.(vdb|db)$/)
      { die "error: file $file is not a vdb file\n"; };

    return($1);
  }

sub check_version_control_opt
  { my $no= 0;
    if ($opt_cvs)
      { $no++; };
    if ($opt_svn)
      { $no++; };
    if ($opt_hg)
      { $no++; };
    if ($opt_darcs)
      { $no++; };
    if ($no==0)
      { die "error: version control system must be specified\n"; }
    if ($no>1)
      { die "error: more than one version control system is specified\n"; }
  }

sub process_darcs_revision
  { my($rev,$match,$patch)= @_;
   
    if (defined $match)
      { return ["match",$match]; }
    if (defined $patch)
      { return ["patch",$patch]; }
    if (defined $rev)
      { return ["patch",$rev]; }
    return;
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
	  { if (ref($rev) eq "")
	      { print "revision $rev"; }
	    else
	      { if (!defined $rev->[1])
	          { print "trunk"; }
		else
		  { print $rev->[0],": ",$rev->[1]; }
	      }
	  };
        if (defined ($opt_svn))
	  { return(svn_process($filename,$rev,$no)); }
        elsif (defined ($opt_hg))
	  { return(hg_process($filename,$rev,$no)); }
        elsif (defined ($opt_darcs))
	  { return(darcs_process($filename,$rev,$no)); }
        elsif (defined($opt_cvs))
	  { return(cvs_process($filename,$rev,$no)); }
	else
	  { die "assertion"; }
      }
  }

sub local_process
  { my($filename,$no)= @_;
    my $cmd;

    my $base= basename($filename) . ".$no.db";
    $base= File::Spec->catfile($tmpdir,$base);

    if (!sys("dbfilter.pl -e $filename > $base"))
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
             "dbfilter.pl -e > $base"))
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
             "dbfilter.pl -e > $base"))
      { return; };
    return($base);
  }

sub hg_process
  { my($filename,$rev,$no)= @_;
    my $cmd;

    if (!defined $rev)
      { $rev= 'tip'; }; 
    # else: leave revision number 

    my $base= basename($filename) . ".$no.db";
    $base= File::Spec->catfile($tmpdir,$base);

    if (!sys("hg cat -r $rev $filename 2> /dev/null | " .
             "dbfilter.pl -e > $base"))
      { return; };
    return($base);
  }

sub darcs_process
  { my($filename,$rev,$no)= @_;
    my $cmd;
    my ($type,$rev_exp)= @$rev;
    my $opt;

    if (!defined $rev_exp)
      { $opt= ""; }
    elsif ($type eq "match")
      { $opt= "--match \"$rev_exp\""; }
    else
      { $opt= "--patch \"$rev_exp\""; }
      
    my $base= basename($filename) . ".$no.db";
    $base= File::Spec->catfile($tmpdir,$base);

    if (!sys("darcs show contents $opt $filename 2> /dev/null | " .
             "dbfilter.pl -e > $base"))
      { return; };
    return($base);
  }

sub show_diff
  { my($f1,$f2)= @_;

    my $opt;
    if (defined $opt_textmode)
      { $opt= "-t"; };
    my $cmd= "dbdiff $opt $f1 $f2 2>/dev/null";
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

graphical compare of vdb files with or within a repository

Syntax:
  $sc_name {options} [file]

  generic options:
    -h: help
    --summary: give a summary of the script
    -t --textmode : show differences as text

  selection of version control system:
    --cvs: use cvs
    --svn: use subversion 
    --hg: use mercurial 
    --darcs: use darcs 

  specification of revisions (or "match/patch" with darcs):

    if no revisions are specified, compare the working copy
    with the trunk (top version in the repository)

    If a single revision is specified, compare the working copy
    with that version of the repository:

    -r [revision]

    or with darcs:
    -r [patch-string]
    --patch [patch-string]
    --match [match-string]

    If two revisions are specified, compare these two 
    revisions of the repository:

    -r [revision1] -r [revision2]

    or with darcs:
    -r [patch-string] -r [patch-string2]
    --patch [patch-string] --patch [patch-string2]
    --match [match-string] --match [match-string2]

END
  }

