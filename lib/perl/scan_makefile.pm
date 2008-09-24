package scan_makefile;

# This software is copyrighted by the BERLINER SPEICHERRING
# GESELLSCHAFT FUER SYNCHROTRONSTRAHLUNG M.B.H., BERLIN, GERMANY.
# The following terms apply to all files associated with the software.
# 
# BESSY hereby grants permission to use, copy and modify this
# software and its documentation for non-commercial, educational or
# research purposes provided that existing copyright notices are
# retained in all copies.
# 
# The receiver of the software provides BESSY with all enhancements, 
# including complete translations, made by the receiver.
# 
# IN NO EVENT SHALL BESSY BE LIABLE TO ANY PARTY FOR DIRECT, INDIRECT,
# SPECIAL, INCIDENTAL OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE
# OF THIS SOFTWARE, ITS DOCUMENTATION OR ANY DERIVATIVES THEREOF, EVEN 
# IF BESSY HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
# 
# BESSY SPECIFICALLY DISCLAIMS ANY WARRANTIES, INCLUDING, BUT NOT LIMITED
# TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
# PURPOSE, AND NON-INFRINGEMENT. THIS SOFTWARE IS PROVIDED ON AN "AS IS"
# BASIS, AND BESSY HAS NO OBLIGATION TO PROVIDE MAINTENANCE, SUPPORT,
# UPDATES, ENHANCEMENTS OR MODIFICATIONS.


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
    @EXPORT_OK   = qw(&scan &cache_scan);
}

use vars      @EXPORT_OK;

use Config;
use Data::Dumper;
use File::Spec;
use Cwd;
use Carp;


our %id_config_h;
my $global_hash_name= "id_config_h";

sub filetime
# private function
  { my($filename)= @_;

    return((stat($filename))[9]);
  }

sub must_create_cache
# private function
  { my($cache,@filenames)= @_;

    if (!-e $cache)
      { return(1); };

    my $t= filetime($cache);

    foreach my $f (@filenames)
      { if (filetime($f)>= $t)
          { return(1); };
      };
    return(0);
  }

sub files_exist
# private function
  { my(@files)= @_;

    foreach my $f (@files)
      { if (!-f $f)
          { return; };
      };
    return(1);
  }


sub scan
  { my(@filenames)= @_;

    if (!files_exist(@filenames))
      { croak "error: not all of the filenames exist"; };

    my %h;
    my $includes= join(" ",@filenames);
    my $eopt=" -e";
    if ($Config{"osname"} eq 'hpux')
      { # echo on hpux doesn't know of an "-e" option
        $eopt= "";
      };

    my $cmd= "echo $eopt \"include $includes\\n" .
                      ".EXPORT_ALL_VARIABLES:\\n" .
		      "scan_makefile_pe:\\n" .
		        "\\t\@printenv\\n\" | " .
	     "make -e -f - scan_makefile_pe";

    $cmd.= " 2>&1 |";

    # -e: environment overrides make
    open(F, $cmd) || die "can\'t fork: $!";
    while (my $line=<F>) 
      { 
#print $line; 
       chomp($line);
        if ($line!~ /^(\w+)=(.*)$/)
	  { carp "line not parsable: \"$line\"\n"; 
	    next;
	  };
	$h{$1}= $2;  
      }
    close(F) || croak "bad netstat: $! $?";

    return(\%h);
  }

sub write_cache
# private function
  { my($cache,$r_h)= @_;
    local(*F);

    open(F,">$cache") or die "unable to create $cache"; 
    print F Data::Dumper->Dump([$r_h], ["*$global_hash_name"]);
    close(F) or croak "error while closing $cache";
  }

sub read_cache    
# private function
  { my($cache)= @_;

    my $return= do $cache;

    if (!$return)
      { croak "couldn't parse $cache: $@" if $@;
        croak "couldn't do $cache: $!"  unless defined $return;
        croak "couldn't run $cache"     unless $return;
        die "unexpected error";
      };
    my %h= %id_config_h;
    return(\%h);
  }    

sub cache_scan
  { my($cache,@filenames)= @_;

    if (must_create_cache($cache,@filenames))
      { my $r_h= scan(@filenames);
        write_cache($cache,$r_h);
	return($r_h);
      };
    return(read_cache($cache));
  }

1;  

__END__
# Below is the short of documentation of the module.

=head1 NAME

scan_makefile - a Perl module to scan makefiles

=head1 SYNOPSIS

  use scan_makefile;

  my $r_h= scan_makefile::cache_scan("mycache","Makefile"); 

=head1 DESCRIPTION

=head2 Preface

This module scans one or more than one makefile and returns 
a hash reference containing all variables that are set within
the makefile together with all environment variables.

In order to speed up the scanning of the makefile, the program
also provides a function that creates and manages a cache-file
that can be read more quickly than scanning the makefile again
and again.

=head2 Implemented Functions:

=over 4

=item *

B<scan()>

  my $r_h= scan_makefile::scan(@makefiles); 

This function scans a list of makefiles and returns a hash-reference  
containing all resolved settings of variables in the makefiles.
Note that the all environment variables are part of that hash too.

=item *

B<cache_scan()>

  my $r_h= scan_makefile::cache_scan($cache_file,@makefiles); 

This function is similar to C<scan()> but it uses or creates a 
cache file speeding up further calls of the same function. If the
cache-file doesn't exist or if the cache-file is older than
one of the makefiles, it is re-created. When the cache file exists
and it is newer than all of the makefiles, it is read directly 
instead of scanning the makefiles again, speeding up the process.

=back

=head1 AUTHOR

Goetz Pfeiffer,  goetzp@gmx.net

=head1 SEE ALSO

perl-documentation

=cut



 scans a list of makefiles and returns a hash-reference  
containing all resolved settings of variables in the makefiles.
Note that the all environment variables are part of that hash too.
