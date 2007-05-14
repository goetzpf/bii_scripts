package platform_ontop;

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
    @EXPORT_OK   = qw(&pl_includes &pl_defines &pl_dir &pl_libdirs 
                      &pl_libs &pl_objects &pl_dump);
}
use vars      @EXPORT_OK;

use strict;

use myutils;

# --------------------------------------------------------------
# definitions
# --------------------------------------------------------------

# platform dependant compiler options:
my %defines = ( 'linux-x86' => '-DUNIX -D_X86_ -Dlinux',
                'win32-x86' => '/nologo /D__STDC__=0 /W3 /MD ' .
                               '-D_NO_PROTO /D_WIN32 /D_X86_',
                'hpux'      => '-DUNIX -D_HPUX_SOURCE -DHP_UX -D__hpux',
                'hpux-11'   => '-DUNIX -D_HPUX_SOURCE -DHP_UX -D__hpux ' .
                               '-DHPUX11',
                'solaris'   => '-DUNIX -DSOLARIS',
              );

# library-options for the compiler
my %libs =    ( 'linux-x86' => '-lm -lezca',
                'win32-x86' => 'ezca.lib ca.lib Com.lib',
                'hpux'      => '-lezca -lm -lca',
                'hpux-11'   => '-lezca -lm -lca',
                'solaris'   => '-lezca -lm -lca',
              );


# location of the epics base, 
# note that the environment variables "EPICS_BASE" overrides this:
my %epics_base= ('linux-x86' => '/usr/local/epics/base',
                  'win32-x86' => 'c:\\usr\\local\\epics\\base',
                  'hpux-11'   => '/opt/csr/epics/R3.13.9/base/3-13-9',
                );

# location of the epics extensions (in order to find ezca)
# note that the environment variables "EPICS_EXTENSIONS" overrides this:
my %epics_extensions= ('linux-x86' => '/usr/local/epics/extensions',
                        'win32-x86' => 'c:\\usr\\local\\epics\\extensions',
                        'hpux-11'   => '/opt/csr/epics/extensions',
                      );

# platform dependant sub-directory for include files:
my %os_inc_subdir= ('linux-x86' => 'Linux',
                     'win32-x86' => 'WIN32',
                     'hpux-11'   => 'hp700',
                   );

# platform dependant sub-directory for libraries in the base:
my %os_b_lib_subdir= ('linux-x86' => 'linux-x86',
                       'win32-x86' => 'win32-x86',
                       'hpux-11'   => 'hp700',
                     );

# platform dependant sub-directory for libraries in the extensions directory:
my %os_e_lib_subdir= ('linux-x86' => 'linux-x86',
                       'win32-x86' => 'win32-x86',
                       'hpux-11'   => 'hp700',
                     );

# -----------------------------------------------------

# determine the current HOST architecture
my $platform= myutils::platform();

# determine location of the epics base:
my $epics_base = $ENV{EPICS_BASE};
if (myutils::empty($epics_base))
  { $epics_base= $epics_base{$platform}; };
  
# determine location of epics extensions:
my $epics_extensions= $ENV{EPICS_EXTENSIONS};
if (myutils::empty($epics_extensions))
  { $epics_extensions= $epics_extensions{$platform}; };

# --------------------------------------------------------------
# exported functions
# --------------------------------------------------------------
  
sub pl_includes 
# return a string that instructs the compiler where to look for additional
# include files. See further below for a description of compose_many()
  { return(myutils::compose_many( [ [$epics_base,"include"], 
                                  [$epics_base,"include","os",$os_inc_subdir{$platform}],
                                  [$epics_extensions,"include"]
                                ], 
                                "-I" ));
  }

sub pl_defines
  { return($defines{$platform}); }

sub pl_dir
  { return; }

sub pl_libdirs 
# return a string that instructs the compiler where to look for additional
# libraries. See further below for a description of compose_many()
  { my $is_win32= ($platform =~ /win32/i);
    return(myutils::compose_many( [ [$epics_base,"lib",$os_b_lib_subdir{$platform}],
                                    [$epics_extensions,"lib",$os_e_lib_subdir{$platform}]
                                  ],
                                  $is_win32 ? "-libpath:" : "-L",   
                                  $is_win32));
  }

sub pl_libs
  { return($libs{$platform}); }

sub pl_objects
  { return(myutils::c2obj("Pezca.c ")); } 

sub pl_dump
  { return(myutils::dump(@_)); }

1;

