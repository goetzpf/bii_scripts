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


# [multi-commit] -- perform multiple commits 
#                   (cvs, subversion, darcs, mercurial, mercurial patch queue)
#                   with a prepared command-file

use strict;

use FindBin;
use Getopt::Long;
use File::Temp;
use Text::ParseWords;

use constant { 
  CVS   => 1,
  SVN   => 2,
  DARCS => 3,
  HG    => 4,
  HGMQ  => 5,
};

use vars qw($opt_help $opt_summary $opt_man 
            $opt_commit
            $opt_generate
            $opt_edit
            $opt_status
            $opt_svn_log_gen
            $opt_darcs $opt_cvs $opt_svn $opt_hg $opt_hgmq
            $opt_dry_run);

# the following options are also recognized without
# a leading "--" since they are commands.
my %gbl_arg_lst= (generate=> '--generate',
                  status  => '--status',
                  edit    => '--edit',
                  commit  => '--commit',
                  );


my $mail_domain= "helmholtz-berlin.de";

my $description_file= "DIFFS";

my $sc_version= "1.0";

my $sc_name= $FindBin::Script;
my $sc_summary= "perform multiple commits (cvs|svn|darcs|hg) with a prepared command-file"; 
my $sc_author= "Goetz Pfeiffer";
my $sc_year= "2010";

my $debug= 0; # global debug-switch

my $vcs;

#Getopt::Long::config(qw(no_ignore_case));

if (!@ARGV)
  { $opt_man= 1; };

preproc_args();

if (!GetOptions("help|h","summary","man","commit:s","generate:s",
                "edit:s",
                "status",
                "svn_log_gen|svn-log-gen=s", 
                "dry_run|dry-run","darcs","cvs","svn", "hg", "hgmq"
                ))
  { die "parameter error!\n"; };

if ($opt_help)
  { help();
    exit;
  };

if ($opt_man)
  { exec("perldoc $0"); };

if ($opt_summary)
  { print_summary();
    exit;
  };

if (defined $opt_cvs)
  { $vcs= CVS; }

if (defined $opt_svn)
  { if (defined $vcs)
      { die "contradicting options\n"; };
    $vcs= SVN;
  };

if (defined $opt_darcs)
  { if (defined $vcs)
      { die "contradicting options\n"; };
    $vcs= DARCS;
  };

if (defined $opt_hg)
  { if (defined $vcs)
      { die "contradicting options\n"; };
    $vcs= HG;
  };

if (defined $opt_hgmq)
  { if (defined $vcs)
      { die "contradicting options\n"; };
    $vcs= HGMQ;
  };

if (!defined $vcs)
  { $vcs= SVN; };  

my $cmd_cnt=0;
if (defined $opt_generate)
  { $cmd_cnt++; };
if (defined $opt_edit)
  { $cmd_cnt++; };
if (defined $opt_status)
  { $cmd_cnt++; };
if (defined $opt_commit)
  { $cmd_cnt++; };

if ($cmd_cnt>1)
  { die "contradicting options\n"; };

if (defined $opt_svn_log_gen)
  { scan_svn_log($opt_svn_log_gen); }
elsif ((defined $opt_generate) || (defined $opt_status) || (defined $opt_edit))
  { 
    my $editor= undef;
    my $filepar= undef;
    if (defined $opt_generate)
      { $filepar= ($opt_generate eq "") ? $description_file : $opt_generate; }
    if (defined $opt_edit)
      { 
        $editor= $ENV{EDITOR};
        if (defined $ENV{MULTICOMMIT_EDITOR})
          { $editor= $ENV{MULTICOMMIT_EDITOR}; };
        $filepar= ($opt_edit eq "") ? $description_file : $opt_edit; 
      }
    generate_file($vcs, $filepar, $editor);
  }
elsif (defined $opt_commit)
  {
    my $filepar= ($opt_commit eq "") ? $description_file : $opt_commit;
    scan_file($vcs, $filepar);
  };


exit(0);

# ------------------------------------------------

sub scan_filename
  { my($vcs,$line)= @_;

    return if ($line=~ /^\s*$/);

    if     ($vcs == CVS)
      { if ($line=~/^[A-Z]\s+(.*?)\s*$/) 
          { # possibly a filename
            return($1);
          };
      }
    elsif  ($vcs == SVN)
      { if ($line=~/^(?:[A-Z~] | [A-Z]|[A-Z~]{2})\s+(.*?)\s*$/) 
          { # possibly a filename
            return($1);
          };
      }
    elsif  ($vcs == DARCS)
      { if ($line=~/^[A-Z]\s+(.*?)\s*[\+\-0-9 ]*$/) 
          { # possibly a filename
            return($1);
          };
      }
    elsif  (($vcs == HG) || ($vcs == HGMQ))
      { if ($line=~/^[A-Z]\s+(.*?)\s*$/) 
          { # possibly a filename
            return($1);
          };
      }
    else
      { die "assertion"; };
    return;
  }


sub scan_file
  { my($vcs,$filename)=@_;
    local(*F);
    my @files;
    my $comment;  
    my %file_comments;
    my $last_file; 
    my $last_empty; 

#die "vcs:$vcs";

    my $lineno=0;
    open(F,$filename) or die "unable to open \"$filename\"";
    while(my $line=<F>)
      { $lineno++;
        chomp($line);
        if ($line=~ /^\s*$/)
          { next if (++$last_empty>1); }
        else
          { $last_empty=0; };

#warn "line:\"$line\"\n";

        my $matched_filename= scan_filename($vcs,$line);

        if (defined $matched_filename)
          { 
            my @w= quotewords(q(\s+), 1, $matched_filename);
            if ($#w==0) # a filename
              { 
                $last_file= $matched_filename;
                push @files, $matched_filename;
                next;
              };
          };      
        if ($line=~/^-{4,}\s*$/)
          { # a separation line
#warn "separation-line:\n";
            if (!@files)
              { if ($comment!~ /^[\s\r\n]*$/)
                  { warn "warning: empty section found in line $lineno, ignored\n"; };
              }
            else
              { # if there is only one file, we skip "file specific comments" and
                # merge this with the main comment
                if ($#files==0)
                  { $comment.= $file_comments{$files[0]}; }
                else
                  { build_comment(\$comment, \%file_comments, \@files); };

                $comment=~ s/^\s*\n//;
                commit($vcs,$comment,@files);
              };
            $comment= undef;
            @files=();
            $last_file= undef;
            %file_comments=();
            next; 
          };
        # else: a comment 
        $line=~ s/\s+$//; 
        $line.= "\n";
        if (!defined $last_file)
          { $comment.= $line; 
#warn "global comment:\"$line\"\n";       
          }
        else
          { $file_comments{$last_file}.= $line; 

          };
      };
    if (@files)
      { build_comment(\$comment, \%file_comments, \@files);
        commit($vcs,$comment,@files);
      };
    close(F);
  }

sub print_msg
  { my($r_files,$r_comments)= @_;

    for(my $i= $#$r_comments; $i>0; $i--)
      { if ($r_comments->[$i]=~ /^\s*$/)
          { $r_comments->[$i]= undef; }
        else
          { last; };
      }; 
    print "-" x 40,"\n";
    print join("\n",@$r_comments),"\n\n";
    print join("\n",@$r_files),"\n\n";
  }


sub scan_svn_log
  { my ($par)= @_;

    my $mode= "init";

    my @files;
    my @comments;
    my $lineno;

    my ($old, $new);

    if ($par=~/(.*),(.*)/)
      { $old= $1; $new= $2; }
    else
      { die "error: please specify \"old-path,new-path\"\n"; }; 

    while(my $line=<>)
      { $lineno++;
        chomp($line);

        if ($line=~ /^-{4,}/)
          { next if (!@files);
            print_msg(\@files,\@comments);
            @files=();
            @comments=();
            $mode= 'init';
            next;
          };

        if ($mode eq 'init')
          { if ($line=~/^\s*Changed paths/i)
              { $mode= 'filelist';
                @files=();
                @comments=();
                next;
              };
            next;
          }
        elsif ($mode eq 'filelist')
          { if ($line=~ /^\s*$/)
              { $mode= 'comment';
                next;
              };
            my $l= $line; 

            if ($l!~ /^\s*([A-Z]{1,2})\s+(.*)/)
              { die "file not parsable:\n\"$l\"\n"; }
            else
              { my $c= $1; 
                my $f= $2;
                $f=~ s/$old/$new/;
                push @files, "$c  $f"; 
              };
            next;
          }
        elsif ($mode eq 'comment')
          { if (!@comments)
              { next if ($line=~/^\s*$/); };
            push @comments, $line;
            next;
          }  
      }

    if (@files)
      { print_msg(\@files,\@comments); }                
  }     

sub build_comment
  { my($r_comment, $r_file_comments, $r_files)= @_;

    my $first;
    foreach my $file (@$r_files)
      { my $filecomment= $r_file_comments->{$file};
        next if (!defined $filecomment);
        next if ($filecomment =~ /^[\s\r\n]*$/);

        if ($$r_comment!~ /\n\s*\n$/)
              { $$r_comment.= "\n"; };

        if (!$first)
          { $first=1; 

            $$r_comment.= "File-specific comments:\n\n"; 
          };
        $$r_comment.= $file . ":\n";
        $filecomment=~ s/^/  /mg;
        $$r_comment.= $filecomment;
      };
  }

sub generate_file_cmd
  { my($vcs, $filename)= @_;
    my $cmd;

    if    ($vcs eq CVS)
      { $cmd= "cvs -n -q update"; }
    elsif ($vcs eq SVN)
      { $cmd= "svn status"; }
    elsif ($vcs eq DARCS)
      { $cmd= "darcs whatsnew -s | " .
              "sed -e 's/[+-][0-9][0-9]*//g' | " .
              "sort | uniq";
      }
    elsif ($vcs eq HG)
      { $cmd= "hg status"; }
    elsif ($vcs eq HGMQ)
      { $cmd= "(hg log -l 1 --template \"{desc}\\n\"; hg status --rev -2)"; 
      }
    else
      { die "assertion"; };
    if (defined $filename)
      { $cmd.= " > $filename"; }
    return($cmd);
  }

sub generate_file
  { my($vcs, $filename, $editor)= @_;

    my $cmd= generate_file_cmd($vcs, $filename);
    if ($opt_dry_run)
      { print "command: \"$cmd\"\n";
      }
    else
      { 
        if (-e $filename)
          { print "warning: file \"$filename\" already exists, overwrite (y/n)?";
            my $rep= <>;
            if ($rep!~ /^\s*(y|yes|ok|j|ja)\s*$/i)
              { die "aborting...\n"; }
          }
        if (!sys($cmd))
          { die "error: command failed!"; };
      };    
    $cmd= "$editor $filename";
    if ($opt_dry_run)
      { print "command: \"$cmd\"\n";
      }
    else
      { if (!sys($cmd))
          { die "error: command failed!"; };
      };    
  }    

sub commit_cmd
  { my($vcs,$files,$temp_file)= @_;

    my $cmd;
    if    ($vcs eq CVS)
      { $cmd= "cvs commit -F $temp_file $files"; }
    elsif ($vcs eq SVN)
      { $cmd= "svn commit $files -F $temp_file"; }
    elsif ($vcs eq DARCS)
      { my $mail= email(); 
        $cmd= "darcs record -A $mail -a --logfile=$temp_file $files"; 
      }
    elsif ($vcs eq HG)
      { $cmd= "hg commit -l $temp_file $files"; }
    elsif ($vcs eq HGMQ)
      { $cmd= "hg qrefresh -l $temp_file $files"; }
    else
      { die "assertion"; };
    return($cmd);
  }

sub commit
  { my($vcs,$comment, @files)= @_;

    my $cmd;
    my $temp_file= make_tempfile(\$comment);

    my $files= join(" ",@files);

    my $cmd= commit_cmd($vcs,$files,$temp_file);

    if ($opt_dry_run)
      { print "command: \"$cmd\"\n";
        print "content of $temp_file:\n";
        print "-" x 60,"\n";
        system("cat $temp_file");
        print "=" x 60,"\n";
      }
    else
      { if (!sys($cmd))
          { die "error: command failed!"; };
      };
    unlink($temp_file);
  }

sub make_tempfile
  { my($r_content)= @_;

    my $tmp = new File::Temp(UNLINK => 0,
                             TEMPLATE => 'svn_multi_commit-tempXXXXX',
                             DIR => '/tmp');
    print $tmp $$r_content;
    close($tmp);
    return($tmp->filename);
  }  

sub umlaut
  { my($s)= @_;
    
    $s=~s/ä/ae/g;
    $s=~s/Ä/Ae/g;
    $s=~s/ö/oe/g;
    $s=~s/Ö/Oe/g;
    $s=~s/ü/ue/g;
    $s=~s/Ü/Ue/g;
    $s=~s/ß/ss/g;
    return $s
  }

sub email
  { # get Name from /etc/passwd:
    my $n= (getpwuid($<))[6]; 

    $n= umlaut($n);
    if ($n!~/^([\w ]{3,})/) 
      { die "assertion, user name cannot be parsed"; }; 

    $n= $1; 
    $n=~ s/ /\./g; 

    my $mail= "$n\@$mail_domain"; 
    return($mail);
  }

sub sys
  { my($cmd)= @_;

    print STDERR $cmd,"\n";
    my $rc= system($cmd);
    return(1) if ($rc==0);
    return;
  }

sub preproc_args
  { 
    foreach my $arg (@ARGV)
      { if (exists $gbl_arg_lst{$arg})
          { $arg= $gbl_arg_lst{$arg}; };
      };
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
  $sc_name [command] {options}

  commands:
    edit {file}
        generate a file containing the changes. If {file} is missing
        generate a file with name "$description_file". After the file
        was generated, an editor is started with this file. The 
        editor program is taken from the "MULTICOMMIT_EDITOR" environment 
        variable and if this variable does not exist, from the "EDITOR"
        environment variable.
    generate {file}
        generate a file containing the changes. If {file} is missing
        generate a file with name "$description_file".
    status:
        print changes to the console.
    commit {file}
        commit changes described in {file} to the repository.
        If {file} is missing, generate a file with name "$description_file".

  options:
    -h: help
    --man: show embedded man-page
    --summary: give a summary of the script
    --dry-run: just simulate the action
    --svn  : use subversion (the default)
    --darcs: use darcs 
    --hg   : use mercurial 
    --hgmq : use mercurial with patch queue (mq) extension
             (apply "hg qrefresh -e" instead of commit)
    --cvs  : use cvs

Format of a commit-file:
-----------------------
global comment comes here...

M src/c_files/file0.c

M src/c_files/file1.c
Here comes a file-specific comment
for "file1.c"

A src/b_files/file2.b
Here comes another file-specific comment
for "file2.b"
-----------------------
Another commit-section like the one above
----------------------
Another commit-section like the one above

As a start you can create such a file with
"svn status" or "darcs whatsnew -s"
The append comments to the files and divide
it into sections.

END
  }

# Below is the short of documentation of the script

=head1 NAME

multi-commit.pl - perform multiple commits (cvs|svn|darcs|hg|hgmq) with a prepared command-file

=head1 SYNOPSIS

  multi-commit.pl --hg commit 

=head1 DESCRIPTION

=head2 Features

This script can be used to perform multiple commits of files
within a working copy directory. Among the programs features are:

=over 4

=item *

supports several version control systems, currently supported are: 
cvs, subversion, darcs, mercurial and mercurial with patch queue (mq) extension.

=item *

all log-messages for all files and commits can be specified in a single file

=item *

the user can specify which files are committed within a single command.
Such commits form an indivisable change-set in the repository (except for cvs).

=back

=head2 commands

The following commands are known:

=over 4

=item status

  multi-commit.pl status 

This command returns a list of all files in the current 
directory. For each file the first letter shows the status.
Usually "M" means modified, "D" deleted, "A" added and
"?" means that this file is unknown to the repository.

=item generate

  multi-commit.pl generate 

This command is usually used to create a first version of the 
message file. It simply writes the output of the status command
(see above) into a file. The default name for this file is "DIFFS"
but it can be specified differently as a parameter for "generate".

=item edit

  multi-commit.pl edit 

This command is similar to "generate" but is starts an editor
on the generated file. The editor is taken from the MULTICOMMIT_EDITOR
environment variable, and, if this is not defined, from the 
EDITOR environment variable.

=item commit

  multi-commit.pl commit 

This command performs the commit of all files mentioned in the 
description-file. For the details of the format of this file see below.
The name of the description file is "DIFFS" but it can be specified
differently as a parameter for "commit".

=back

=head2 options

The following options are known:

=over 4

=item --cvs

This option specifies that the "CVS" version control system is to be used.

=item --svn

This option specifies that the "subversion" version control system is to 
be used. This is also the default.

=item --darcs

This option specifies that the "darcs" version control system is to be used.

=item --hg

This option specifies that the "mercurial" version control system is to be used.

=item --hgmq

This option specifies that the "mercurial" version control system with patch
queues is to be used. The difference with respect to "--hg" is that the status
is generated with "hg status --rev -2" and that "hg qrefresh -e" is used instead
of "hg commit".

=item --dry-run

With this option, no version control command is performed, but the
program simply prints what it would do. Is is recommended that you
always look with  

  multi-commit.pl commit MESSAGE.TXT --dry-run | less

what the program would do before actually comitting changes in the
repository.

=back

=head2 the description file

The description file is usually created by taking the output of
the "status" command and adding comments for each changed, modified
or added file. This is an example of such a file, note that
(in contrast to this help text) the lines MUST NOT heave leading 
spaces:

  --------------------------------------------------------
  The inline documentation had to be changed: the 
  current version of doxygen doesn't seem to work with "\manonly" 

  M ./MultiCAN/src/tool/src/pmsg.c -6 +1
  M ./MultiCAN/src/tool/src/psem.c -7
  M ./MultiCAN/src/tool/src/ip_array.c -9 +4
  --------------------------------------------------------
  the "what" string now contains the settings of important
  compiler macros from the time the source was compiled

  M ./MultiCAN/src/tool/src/pth.c +13
  M ./MultiCAN/src/tool/src/pdbg.c +23
  some comments were changed here.

This file defines two commit-groups. Commit-groups are
separated by lines with at least 4 '-' characters. Each commit group
contains the original lines from the status-command and additional 
text for the log-messages. There are two kinds of comments,
generic and file-specific comments. Comments at the start of a group 
are generic, while comments that follow filenames are specific for 
that file. A generic comment should always be specified, while 
file-specific comments are optional. In the above example, the 
file-names and flags were created by darcs, but the numbers at the 
line-ends like "-6 +1" are ignored. 

=head2 example of a typical session

We assume that you are in the top-directory of your working copy. 
We also assume that you use mercurial. Replace "--hg" with 
"--darcs" if you use darcs or with "--svn" if you use subversion.

=over 4

=item generate the description file named "DIFFS" and edit it:

  multi-commit.pl --hg edit

Remove all lines marked with "?" here, these are files the repository
doesn't know of. For each file mentioned, look what has changed
(for example with "cvs diff <filename>", "svn diff <filename>"
or "darcs diff <filename>" or your favorite graphical diff program) 
and append a comment below the filename. Leave the line with the 
filename itself unchanged.

=item group log-messages in the description file:

You should now look which commits belong logically together. When
the log-messages for two files are identical, they belong together.
Changes that depend on each other should also be grouped. 
Groups must be separated with lines consisting of many (more that 4)
"-" characters. For each group, specify a generic log message that 
appears directly below the line with "-" characters. For all files
in that group where the generic log message suffices, remove the 
file-specific logmessage.

=item commit your changes:

  multi-commit.pl --hg commit 

That should be all!

=back

=head1 AUTHOR

Goetz Pfeiffer,  Goetz.Pfeiffer@helmholtz-berlin.de

=head1 SEE ALSO

cvs, subversion or darcs documentation

=cut

