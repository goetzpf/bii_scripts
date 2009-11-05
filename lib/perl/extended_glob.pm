package extended_glob;

# This software is copyrighted by the
# Helmholtz-Zentrum Berlin fuer Materialien und Energie GmbH (HZB),
# Berlin, Germany.
# The following terms apply to all files associated with the software.
# 
# HZB hereby grants permission to use, copy and modify this
# software and its documentation for non-commercial, educational or
# research purposes provided that existing copyright notices are
# retained in all copies.
# 
# The receiver of the software provides HZB with all enhancements, 
# including complete translations, made by the receiver.
# 
# IN NO EVENT SHALL HZB BE LIABLE TO ANY PARTY FOR DIRECT, INDIRECT,
# SPECIAL, INCIDENTAL OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE
# OF THIS SOFTWARE, ITS DOCUMENTATION OR ANY DERIVATIVES THEREOF, EVEN 
# IF HZB HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
# 
# HZB SPECIFICALLY DISCLAIMS ANY WARRANTIES, INCLUDING, BUT NOT LIMITED
# TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
# PURPOSE, AND NON-INFRINGEMENT. THIS SOFTWARE IS PROVIDED ON AN "AS IS"
# BASIS, AND HZB HAS NO OBLIGATION TO PROVIDE MAINTENANCE, SUPPORT,
# UPDATES, ENHANCEMENTS OR MODIFICATIONS.


# ===========================================================
# note: to quickly see the man-page enter:
# pod2usage -verbose 3 extended_glob.pm
# ===========================================================


use strict;

BEGIN {
    use Exporter   ();
    use vars       qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
    # set the version for version checking
    $VERSION     = 1.0;

    @ISA         = qw(Exporter);
    @EXPORT      = qw();
    %EXPORT_TAGS = ( );     # eg: TAG => [ qw!name1 name2! ],

    # your exported package globals go here,
    # as well as any optionally exported functions
    @EXPORT_OK   = qw();
}
use vars      @EXPORT_OK;

our $debug=0;

# used modules
use Cwd;
use File::Spec;
use File::Find;

#use abc::def;

# non-exported package globals go here
# use vars      qw(a b c);

# functions -------------------------------------------------

sub quote
# just create a string consisting of the array elements
  { my @l= map { '"' . $_ . '"' } @_;
    return(join(",",@l));
  }

sub chdir_safe
# die if chdir fails
  { my ($dir)= @_;
    chdir($dir) or die "unable to chdir to \"$dir\"\n"; 
  }

sub glob_files
# expand glob-pattern but only for files
  { my($pattern)= @_;
    my @files;

    foreach my $f (glob($pattern))
      { push @files, $f if (-f $f); };
    return(\@files);
  }

sub is_glob
# return 1 when a string is probably a glob
  { my($str)= @_;

    if ($str=~ /[\?\*\[\]]/)
      { 
        return 1; 
      };
    return;
  }

sub expand
# expand the first found glob in a pattern
# and return a list of paths
  { my($pattern)= @_;

    if ($debug)
      { warn "expand(\"$pattern\")\n"; };

    my @dirs= File::Spec->splitdir( $pattern );

    my @newdirs;

    for(my $i=0; $i<=$#dirs; $i++)
      { next if (!is_glob($dirs[$i]));
        my $old= cwd();

	my $subdir;
	if ($i>0)
	  { if (File::Spec->file_name_is_absolute( $dirs[0] ))
	      { $subdir= File::Spec->catfile(@dirs[0..($i-1)]); }
	    else
	      { $subdir= File::Spec->catfile(".",@dirs[0..($i-1)]); }
	    if (!-d $subdir)
	      { # is probably a file like:
	        # "filename/*.c" 
		# this cannot be expanded, return an empty list:
		return;
	      }
	    chdir_safe($subdir); 
	  }
	else
	  { $subdir="."; }

	if ($debug)
	  { warn "expand \"$dirs[$i]\" in \"$subdir\"\n"; }

	my @files= glob($dirs[$i]);

	if ($debug)
	  { warn "expanded: " . join(",",@files) . "\n"; };

	if ($i>0)
	  { chdir_safe($old); };

	foreach my $f (@files)
	  { push @newdirs, File::Spec->catfile($subdir,$f,@dirs[($i+1)..$#dirs]);
	  };

	return(@newdirs);
      };
    push @newdirs, $pattern;  
    return(@newdirs);
  }       

sub i_expand_list
# expand a globs in a pattern-list and store
# expanded paths in a given list-reference
  { my($r_result,@pattern_list)= @_;

    if ($debug)
      { warn "i_expand_list(\$r_result," . quote(@pattern_list) . ")\n"; };

    { my @pattern;
      foreach my $p (@pattern_list)
	{ if (!is_glob($p))
            { push @$r_result,$p; }
	  else
	    { push @pattern,$p; };
	};
      return if (!@pattern);
      @pattern_list= ();
      foreach my $p (@pattern)
        { my @a= expand($p);
	  push @pattern_list, @a; 
	}
    }

    i_expand_list($r_result,@pattern_list);
  }    

sub expand_list
# expand a list of globs and returns
# a list-reference
  { my(@pattern_list)= @_;

    if ($debug)
      { warn "expand_list(" . quote(@pattern_list) . ")\n"; };

    my @result;
    i_expand_list(\@result,@pattern_list);
    return(\@result);
  }

sub files_in_dir
# return all files in a given directory
  { my($dir)= @_;
    my $old= cwd();
    chdir_safe($dir);
    my $r_files= glob_files("* .*");
    chdir_safe($old);
    return($r_files);
  }

my @expand_to_filelist_list;

sub wanted
# wanted function for find_files_below()
  { next if (-d $_);
    push @expand_to_filelist_list, $File::Find::name;
  }

sub find_files_below
# find all files below a given list of directories
  { my (@directories)= @_;

    @expand_to_filelist_list= ();
    find({ wanted=> \&wanted,
           follow=> 1},
	  @directories);
    my @l= @expand_to_filelist_list;
    return(@l);
  }	  


sub expand_to_filelist
# take a list if files/directories and returns
# a ref to a list containing all directly mentioned files
# and all files in the given directories and their
# sub-directories
  { my($r_result)= @_;
    my @new;

    foreach my $f (@$r_result)
      { if (!-e $f)
          { next; };
        if (-f $f)
          { push @new, $f; 
	    next;
	  };
	my @files= find_files_below($f);
	push @new, @files;
      };
    @new= sort(@new);
    return(\@new);
  }

sub fglob
  { my(@patterns)= @_;

    my $r= expand_list(@patterns);
    my $k= expand_to_filelist($r);
    return($k);
  }


1;
__END__

# Below is the short of documentation of the module.

=head1 NAME

extended_glob - a Perl module for extended filename globbing

=head1 SYNOPSIS

 use extended_glob;

 my $r_files= extended_glob::fglob(@patterns)


=head1 DESCRIPTION

=head2 Preface

This module provides a more generic and powerful glob function
than the standard glob function. 

=head2 Implemented Functions:

=over 4

=item *

B<fglob()>

  my $r_files= extended_glob::fglob(@patterns)

This function returns a reference to a list of files according to a list
of patterns. Every part of a given path may contain the
typical glob-pattern.

=item *

B<is_glob()>

  if (extended_glob::is_glob($str))
    { ... }

This function returns 1 when a given string
is probably a glob-string. It simply checks wether the
string contains one of the following characters: "?*[]"

=back

=head2 examples

assume that the following directories and files are given:

  ls -lR a*
  a:
  total 16
  drwxrwxr-x 2 pfeiffer pfeiffer 4096 Mar 20 14:03 a_sub
  -rw-rw-r-- 1 pfeiffer pfeiffer    0 Mar 20 13:25 file_in_a
  -rw-rw-r-- 1 pfeiffer pfeiffer    0 Mar 20 13:40 xfile_in_a

  a/a_sub:
  total 4
  -rw-rw-r-- 1 pfeiffer pfeiffer 0 Mar 20 14:03 file_in_a_sub

  aa:
  total 8
  -rw-rw-r-- 1 pfeiffer pfeiffer 0 Mar 20 13:25 file_in_aa
  -rw-rw-r-- 1 pfeiffer pfeiffer 0 Mar 20 13:40 xfile_in_aa

=over 4

=item *

empty pattern

  perl -e 'use extended_glob;use Data::Dumper;\
           print Dumper(extended_glob::fglob("");'

prints

  $VAR1 = [];

No files match the empty pattern

=item *

pattern is a constant string

  perl -e 'use extended_glob;use Data::Dumper;\
           print Dumper(extended_glob::fglob("a");'

prints

  $VAR1 = [
            'a/a_sub/file_in_a_sub',
            'a/file_in_a',
            'a/xfile_in_a'
          ];

The directory "a" was matched and all files and files in
subdirectories of "a" are returned.

=item *

pattern matches several directories

  perl -e 'use extended_glob;use Data::Dumper;\
           print Dumper(extended_glob::fglob("a*");'

prints

  $VAR1 = [
            './a/a_sub/file_in_a_sub',
            './a/file_in_a',
            './a/xfile_in_a',
            './aa/file_in_aa',
            './aa/xfile_in_aa'
          ];

The directories "a" and "aa" matched the expression. Both directories
and their contents are returned.

=item *

pattern specifies directories and files within these

  perl -e 'use extended_glob;use Data::Dumper;\
           print Dumper(extended_glob::fglob("a*/x*");'

prints

  $VAR1 = [
            'a/xfile_in_a',
            'aa/xfile_in_aa'
          ];

The directories "a" and "aa" matched the expression. Only the contents
of these directories that match the sub-expression "x*" are
returned.

=item *

pattern specifies directories and files within these

  perl -e 'use extended_glob;use Data::Dumper;\
           print Dumper(extended_glob::fglob("a*/a*");'

prints

  $VAR1 = [
            'a/a_sub/file_in_a_sub'
          ];

The directories "a" and "aa" matched the expression. Only the 
sub-directory "a_sub" within "a" matches the sub-expression "a*"
and is returned.

=back

=head1 AUTHOR

Goetz Pfeiffer,  Goetz.Pfeiffer@helmholtz-berlin.de

=head1 SEE ALSO

perl-documentation

=cut

