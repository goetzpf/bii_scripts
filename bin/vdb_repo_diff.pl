eval 'exec perl -S $0 ${1+"$@"}' # -*- Mode: perl -*-
    if 0;
# the above is a more portable way to find perl
# ! /usr/bin/perl

#  This software is copyrighted by the BERLINER SPEICHERRING
#  GESELLSCHAFT FUER SYNCHROTRONSTRAHLUNG M.B.H., BERLIN, GERMANY.
#  The following terms apply to all files associated with the software.
#  
#  BESSY hereby grants permission to use, copy and modify this
#  software and its documentation for non-commercial, educational or
#  research purposes provided that existing copyright notices are
#  retained in all copies.
#  
#  The receiver of the software provides BESSY with all enhancements, 
#  including complete translations, made by the receiver.
#  
#  IN NO EVENT SHALL BESSY BE LIABLE TO ANY PARTY FOR DIRECT, INDIRECT,
#  SPECIAL, INCIDENTAL OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE
#  OF THIS SOFTWARE, ITS DOCUMENTATION OR ANY DERIVATIVES THEREOF, EVEN 
#  IF BESSY HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#  
#  BESSY SPECIFICALLY DISCLAIMS ANY WARRANTIES, INCLUDING, BUT NOT LIMITED
#  TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
#  PURPOSE, AND NON-INFRINGEMENT. THIS SOFTWARE IS PROVIDED ON AN "AS IS"
#  BASIS, AND BESSY HAS NO OBLIGATION TO PROVIDE MAINTENANCE, SUPPORT,
#  UPDATES, ENHANCEMENTS OR MODIFICATIONS.


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
	    $opt_svn
	    $opt_hg
	    $opt_revision $opt_revision2
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
                "svn","hg",
                "revision|r=s","revision2|s=s",
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

my $filename= shift(@ARGV);

if (!defined $filename)
  { die "error: name of the vdb file is missing!\n"; };

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

    if ($file!~ /(.*)\.(vdb|db)$/)
      { die "error: file $file is not a vdb file\n"; };

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
        if (defined ($opt_svn))
	  { return(svn_process($filename,$rev,$no)); }
        elsif (defined ($opt_hg))
	  { return(hg_process($filename,$rev,$no)); }
        else
	  { return(cvs_process($filename,$rev,$no)); }
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

Syntax:
  $sc_name {options} [file]

  options:
    -h: help
    --summary: give a summary of the script
    --svn: use subversion instead of cvs
    --hg: use mercurial instead of cvs
    -r [revision] (mandatory)
    -s [2nd revision] (optional)
    -t --textmode : show differences as text
END
  }
