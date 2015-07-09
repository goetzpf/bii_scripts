#!/usr/bin/env perl

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
# @CATEGORY: compare


use strict;
use File::Copy;
use Getopt::Long;
use File::Temp;

use vars qw($opt_help $opt_summary 
            $opt_prn_eq 
	    $opt_only_dirs 
	    $opt_nodirs
	    $opt_file_match
            $opt_file_nomatch $opt_msg_match $opt_msg_nomatch
	    $opt_patch $opt_simpatch $opt_verbose $opt_show_msg
	    $opt_nodate $opt_nosrc $opt_nodest $opt_tkdiff
	    $opt_filter_cvs $opt_filter_cr $opt_filter_empty_lines
            $opt_show_diff 
	    $opt_terse_mode
            $opt_terse_mode2
	    );

my $version= "1.2";

my $sepch=">"; # must be a char that is forbidden in path-names

my $regexp_flag =0; # 0: ignore 1: match-func 2:not-match func 3: both
my $fregexp_flag=0; # 0: ignore 1: match-func 2:not-match func 3: both

Getopt::Long::config("no_ignore_case");

if (!GetOptions("help|h","summary","prn_eq|prn-eq|e",
                "only_dirs|only-dirs|d",
		"nodirs|D",
                "file_match|file-match|f=s",
		"file_nomatch|file-nomatch|F=s",
                "msg_match|msg-match|m=s",
		"msg_nomatch|msg-nomatch|M=s",
		"patch|p","simpatch",
		"verbose|v", "show_msg|s", "nodate", "nosrc", "nodest",
		"tkdiff", "filter_cvs|filter-cvs",
		"filter_cr|filter-cr",
		"filter_empty_lines|filter-empty-lines",
		"show_diff|show-diff|show_diffs|show-diffs",
		"terse_mode|terse-mode|t",
		"terse_mode2|terse-mode2|T",
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

if (($opt_terse_mode) || ($opt_terse_mode2))
  { $opt_prn_eq=1; };

if (defined($opt_patch))
  { $opt_patch=1; };
if (defined($opt_simpatch))
  { $opt_patch=-1; };

if ($#ARGV<1)
  { die "error:path1 or path2 is missing!\n"; };

my($src) = $ARGV[0];
my($dest)= $ARGV[1];


if (defined($opt_file_match))
  { my $re= normalize_regexp($opt_file_match);
    $fregexp_flag|=1;
    eval 'sub fregexp { return($_[0]=~ ' . "$re) }";
  }
if (defined($opt_file_nomatch))
  { my $re= normalize_regexp($opt_file_nomatch);
    $fregexp_flag|=2; 
    eval 'sub nfregexp { return($_[0]!~ '. "$re) }";
  }
if (defined($opt_msg_match))
  { my $re= normalize_regexp($opt_msg_match);
    $regexp_flag|=1; 
    eval 'sub regexp { return($_[0]=~ '. "$re) }";
  }
if (defined($opt_msg_nomatch))
  { my $re= normalize_regexp($opt_msg_nomatch);
    $regexp_flag|=2; 
    eval 'sub nregexp { return($_[0]!~ '. "$re) }";
  }

all_files($src,$dest);



# ------------------ main procedure ------------------  

sub all_files
  { # $_[0]: dir 0, $_[1]: dir 1
    my($spath,$dpath)= @_;
    my @sdirs;
    my @sfiles;
    my @ddirs;
    my @dfiles;
    my $msg;

    get_dirs_files($spath,\@sdirs,\@sfiles);
    get_dirs_files($dpath,\@ddirs,\@dfiles);

    if (!defined($opt_only_dirs))
      { foreach my $file (join_lists(@sfiles,@dfiles))
          { my(%h)= compare_files( "$spath/$file", "$dpath/$file", 0);
# print "HASH: ",%h,"\n";	  ###
	   print_user_msg(%h);
	   if ($opt_patch)
	     { do_patch($opt_patch, %h); };
         };
      };
    @sdirs= join_lists(@sdirs,@ddirs);  
    if (!defined($opt_nodirs))
      {
	foreach my $dir (@sdirs)
	  { my(%h)= compare_files( "$spath/$dir", "$dpath/$dir", 1 );
	    print_user_msg(%h);
            if ($opt_patch)
	      { do_patch($opt_patch,%h); };
	  };
      };

    foreach my $dir (@sdirs)
      { 
        all_files("$spath/$dir", "$dpath/$dir"); 
      };
  }

# --------------- directory scanning -----------------  

sub get_dirs_files
# get sub-directories and files of a given directory
  { # $_[0] dir-name, $_[1]: reference on dir-array $_[2]: ref. on file-array
    my($dir_name,$dir_array_ref,$file_array_ref)= @_;
    local *DIRHANDLE;

    my $dir;

    if (!(-e $dir_name))
      { return; }; # the directory does not exist
    opendir(DIRHANDLE,$dir_name) || 
        die "unable to open directory \"$dir_name\"\n";

    while ($dir= readdir(DIRHANDLE))
      { next if ($dir eq ".");
        next if ($dir eq "..");
        if (!(-r "$dir_name/$dir"))
          { warn "$dir is not readable\n"; next; };
        if (-d "$dir_name/$dir")
	  { unshift @$dir_array_ref,$dir; }
	else
	  { unshift @$file_array_ref,$dir; };
      };
    closedir(DIRHANDLE);
    @$dir_array_ref = sort @$dir_array_ref;
    @$file_array_ref= sort @$file_array_ref;
  }

# ---------------- file comparision ------------------  

sub compare_files
  { # $_[0]: path1 $_[1]: path2, $_[2]:is_dir
    # returns: "identical": files are identical
    #          "size differs"          : files differ in size
    #          "source older"          : files differ in date
    #          "source newer"          : files differ in date
    #          "source missing"        : source-file is missing
    #          "source smaller"        : source-file is smaller
    #          "source larger"         : source-file is larger
    #          "destination missing"   : dest-file is missing
    #          "both missing"          : shouldn't happen :-)
    my($f1,$f2,$is_dir)=@_;
    my($message);
    my(%h);

    $h{'source'}= $f1;
    $h{'dest'}  = $f2;

    if (!comp_fnames($f1,$f2)) # user-defined regexp to select 
                               # files to compare
      { return(%h); };
    if (!(-e $f1))
      { if (!(-e $f2))
          { $h{'exist'}= "";
	    return(%h);
	  };
	if (!$opt_nosrc)  
	  { $h{'exist'}= "d"; };     # src missing 
        return(%h);  
      }
    else
      { if (!(-e $f2))
          { if (!$opt_nodest) 
	      { $h{'exist'}= "s"; }; # dest missing 
            return(%h);
	  }
	else
	  { $h{'exist'}= "sd"; } # both files are there  
      };

    if ($opt_nodate)
      { $h{'date'}= '='; } # ignore date-differences
    else
      { my $t1= (-M $f1);
	my $t2= (-M $f2);
	if ($t1<$t2)
	  { $h{'date'}= '>'; } # src newer
	elsif ($t1>$t2)
	  { $h{'date'}= '<'; } # src older  
	else
	  { $h{'date'}= '='; };
      };

    if (!$is_dir)
      {	my $fl1= $f1;
        my $fl2= $f2;
        if ((defined $opt_filter_cvs) || (defined $opt_filter_cr) || (defined $opt_filter_empty_lines))
          { $fl1= filter_file($f1,$opt_filter_cvs, $opt_filter_cr, $opt_filter_empty_lines);
	    $fl2= filter_file($f2,$opt_filter_cvs, $opt_filter_cr, $opt_filter_empty_lines);
	  };

        my $t1= (-s $fl1);  
	my $t2= (-s $fl2); 
	my $is_equal; 

	if    ($t1<$t2)
	  { $h{'size'}= '<'; 
	  } # src smaller
 	elsif ($t1>$t2) 
	  { $h{'size'}= '>'; 

	  } # src larger
        elsif (fcomp($fl1,$fl2))
	  { $is_equal= 1;
	    if (defined($opt_prn_eq))
	      { $h{'content'}= '=';  }
	  }
	else
	  { $h{'content'}= '!'; 
	  };

	if (defined $opt_show_diff)
	  { diff_file($fl1,$fl2,$f1,$f2) if (!$is_equal);
	  };

        if ((defined $opt_filter_cvs) || (defined $opt_filter_cr))
	  { unlink($fl1);
	    unlink($fl2);
	  };
	return(%h);  
      };

    return(%h);
  }

sub fcomp
  { # $_[0]: file 1, $_[1]: file2
    my($buf1,$buf2);
    my($l1,$l2);
    my($ret)= 1; 
    open(F1,$_[0]) || die "unable to open \"$_[0]\"\n";
    open(F2,$_[1]) || die "unable to open \"$_[1]\"\n";

    for(;;)
      { $l1=read(F1,$buf1,4096);
        $l2=read(F2,$buf2,4096);
	if (($l1==0) || ($l2==0))
	  { if (($l1==0) && ($l2==0))
	      { last; };
	    $ret= 0;
	    last;
	  };
	if ($buf1 ne $buf2)
	  { $ret= 0;
	    last;
	  };
      };
    close(F1); 
    close(F2);
    return $ret;
  }

sub diff_file
  { my($f1,$f2,$real_f1,$real_f2)= @_;

    print "-" x 60,"\n";
    print "diff $real_f1 $real_f2:\n";

    system("diff $f1 $f2");
  }


sub filter_file
  { my($filename,$cvs,$cr,$empty_lines)= @_;

    my $tmp = new File::Temp(UNLINK => 0,
                             TEMPLATE => 'pcomp-tempXXXXX',
                             DIR => '/tmp');

    # old File::Temp API (as installed on sioux.blc.bessy.de):
    # my(undef, $tmp) = File::Temp::tempfile('pcomp-tempXXXXX', 
    #		                             OPEN => 0,
    #			                     UNLINK => 0,
    #                                        DIR => '/tmp');

    file_filter($filename,$tmp,$cvs,$cr,$empty_lines);
    return($tmp);
  }

sub file_filter
  { my($in,$out,$cvs,$cr,$empty_lines)= @_;
    local(*F);
    local($/);
    undef $/;
    my $x;

    open(F, $in) or die "unable to open \"$in\"";
    $x= <F>;
    close(F);
    if ($cvs)
      { $x=~ s/\$(Author|Date|Header|Id|Name|Locker|Log|RCSfile|Revision|Source|State).*?\$//gs; };
    if ($cr)
      { $x=~ s/\r+//gs; };
    if ($empty_lines)
      { $x=~s/\r{2,}/\r/gs; $x=~s/\n{2,}/\n/gs; };
    open(F, ">$out") or die "unable to create \"$out\"";
    print F $x;
    close(F);
  }


# -------------- file selection logic ----------------  

sub comp_fnames
  { # regexp-handling for filenames
    # returns 1: must compare  0: must not compare 
    my($f1,$f2)= @_;

    if ($fregexp_flag==0)
      { return 1; };
    if ($fregexp_flag & 1)
      { return if (!( fregexp($f1) &&  fregexp($f2)))
      };
    if ($fregexp_flag & 2)
      { return if (!(nfregexp($f1) && nfregexp($f2)))
      };
    return(1);
  }


sub join_lists
  { my(@l1,@l2)= @_;
    my %h;
    foreach my $l (@l1)
      { $h{$l}=1; };
    foreach my $l (@l2)
      { $h{$l}=1; };
    return(sort keys %h);
  }


# ------------------ user messages -------------------  

sub print_user_msg
  { my(%h)= @_;
    my($st)= user_message($opt_terse_mode || $opt_terse_mode2,%h);
    my($f1)= $h{'source'};
    my($f2)= $h{'dest'};

    if (!$st)
      { return; };

    if ($regexp_flag & 1)
      { if (!regexp($st))
          { return; };
      };
    if ($regexp_flag & 2)
      { if (!nregexp($st))
          { return; };
      };

    if ($opt_tkdiff)
      { print "tkdiff $f1 $f2\n"; };
    if (defined($opt_verbose))
      { print "$f1\n$f2\n-->$st\n\n"; }
    else 
      { if ($opt_terse_mode)
          {
            print "$st $f2\n";
	  }
        elsif ($opt_terse_mode2)
          {
            print "$st $f1 $f2\n";
	  }
	else
	  { print "$f1 : $f2 : $st\n"; } 
      };
    return;
  }    

sub user_message
  { my($short_mode,%h)= @_;
    my($dmsg,$smsg,$cmsg);
    my($x);

#die if ($short_mode);
    if (!exists($h{'exist'}))
      { return; }; # used to skip files 
    $x= $h{'exist'};
    if ($x eq "")
      { return if ($short_mode);
        return("both missing"); 
      };

    if ($x eq "s")
      { return("D  ") if ($short_mode); 
        return("destination missing");
      };
    if ($x eq "d")
      { return("A  ") if ($short_mode); 
        return("source missing"); 
      };

    $x= $h{'date'};
    if    ($x eq '<')
      { if ($short_mode)
	  { $dmsg= "M"; }
	else
	  { $dmsg= "older"; }
      }
    elsif ($x eq '>')        
      { if ($short_mode)
	  { $dmsg= "U"; }
	else
	  { $dmsg= "newer"; } 
      }
    else
      { if ($short_mode)
	  { $dmsg= " "; }
      };         

    $x= $h{'size'};
    if ($x)
      {	if ($short_mode)
          { if (!$x)
	      { $smsg= " "; }
	    else
	      { $smsg= $x; 
	        $cmsg= '!';
	      }
	  }
	else
	  { if    ($x eq '<')
	      { $smsg= "smaller";
	      }
	    elsif ($x eq '>')        
	      { $smsg= "larger"; 
	      } 
	  };
      };
    $x= $h{'content'};
    if ($x)
      {	if ($short_mode)
          { $cmsg= $x; }
	else
	  {
            if    ($x eq '!')
	      { $cmsg= "files unequal"; }
	    elsif ($x eq '=')        
	      { $cmsg= "files equal"; };
          }
      }
    if ($short_mode)
      { if (!$cmsg && !$dmsg && !$smsg)
          { return; }
        if ($cmsg)
          { $dmsg= "?" if (!$dmsg); };
	$smsg= " " if (!$smsg);  
	$cmsg= " " if (!$cmsg);  
        return(sprintf ("%s%s%s",$dmsg,$smsg,$cmsg));
      }  

    $x= join(',',$dmsg,$smsg,$cmsg);
     $x=~ s/,\s*,/,/g;
    $x=~ s/,$//;
    $x=~ s/^,//;
    $x=~ s/,/ and /g;
    if (!$x)
      { return; };
    return("source " . $x);
  }    

# ------------------- patch logic --------------------  

sub do_patch
  { my($patch,%h)= @_;
    if (!should_patch(%h))
      { return; };
    if (-d $h{'source'})
      { if ($patch<0)
	  { print "would "; }
       else
	 { mkdir $h{'dest'}, 0740; };
	print "mkdir $h{dest}\n";
       return; 
      }
    else
      { if ($patch<0)
	  { print "would "; }
       else
	 { copy($h{'source'},$h{'dest'}); };
	print "copy $h{source} to $h{dest}\n";
      };
  }		   

sub should_patch
  { my(%h)= @_;
    if (!exists($h{'exist'}))
      { return(0); }; # used to skip files 
    if ($h{'exist'} eq 's')
      { return(1); };
    if ($h{'date'} eq '>')
      { return(1); };
    return(0);
  }

sub normalize_regexp
  { my($re)= @_;

    if ($re !~ /^\//)
      { return("/$re/"); };
    return($re);
  }


# ------------------- online-help --------------------  

sub show_messages
  { print <<END;
both missing (should never happen!)
source missing
destination missing
source newer
source older
source smaler
source larger
equal
unequal  

The date-messages (older/newer) and the content-messages
(larger/smaller/equal/unequal) my be combined.
END
  }

sub print_summary
  { my($p)= ($0=~ /([^\/\\]+)$/);
    printf("%-20s: compare two file-trees\n",$p);
  }

sub help
  { my($p)= ($0=~ /([^\/\\]+)$/);
    print <<END;

           **** $p $version -- the file-tree compare program ****

Syntax: $p {options} [path1] [path2]
  compares two directory-trees recursively
  options:
    --prn-eq -e     also give a message for files that are equal
    --only-dirs -d  compare only directories, not files
    --nodirs|-D     compare only files, not directories

    --file-match -f   [regexp] 
                    compare only files that match [regexp]

    --file-nomatch -F [regexp]
                    compare only files that do not match [regexp]

    --msg-match -m    [regexp]
                    show only messages that match [regexp]

    --msg-nomatch -M  [regexp]
                    show only messages that do not match [regexp]

    --nodate        ignore differences in the file-date
    --nosrc         ignore when the source is missing
    --nodest        ignore when the destination is missing
    --tkdiff        print a line suitable for tkdiff
    -v              produce a more verbose output
    -p              patch [dest] with [source]
    --simpatch      simulate patch [dest] with [source]
    -s              show all comparision messages the program can produce
    --filter-cvs    remove cvs keywords
    --filter-cr     remove <CR> characters
    --filter-empty-lines
                    remove empty lines
    --show-diff --show-diffs
                    execute "diff" on each pair of differing files
		    NOTE: diff appears ABOVE the line that shows which 
		          files differ
    -t --terse-mode
      print <flags> <path> 
      where: path: destination path except when flags are "D"
      flags: 1st char:
	       D: deleted      (destination missing)
               A: added        (source missing)
	       U: updated      (source newer)
	       M: modified     (destination newer)
	     2nd char:
	       <: source smaller
	       >: source larger
	     3rd char:
	       =: files equal
	       !: files unequal  

    -T --terse-mode2
      like --terse-mode, but this command prints the paths of both files
END
  }
