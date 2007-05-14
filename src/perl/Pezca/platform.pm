package platform;

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
    @EXPORT_OK   = qw(&pl_includes &pl_defines &pl_dir 
                      &pl_libdirs &pl_libs &pl_objects 
                      &pl_mk_includes
                      &pl_platform_includes &pl_libcom_subdirs
                      &pl_dump);
}
use vars      @EXPORT_OK;

use strict;

use myutils;
use Data::Dumper;

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
my %libs =    ( 'linux-x86' => '-lm ',
                'win32-x86' => 'ws2_32.lib',
                'hpux'      => '-lm ',
                'hpux-11'   => '-lm ',
                'solaris'   => '-lm ',
              );


# all sub-directories with c-sources
my @subdirs= qw(libCom ca ezca);

# all include directories:       
my @include_dirs= qw(include libCom ca db ezca);


my %platform_includes=(
        'hpux'      => [['include','os','hp700'],['include','O.hp700']],
        'hpux-11'   => [['include','os','hp700'],['include','O.hp700']],
        'solaris'   => [['include','os','solaris'],['include','O.solaris']],
        'linux-x86' => [['include','os','Linux'],['include','O.Linux']],
        'win32-x86' => [['include','os','WIN32'],['include','O.WIN32']] 
                      );


# note: the generic format for a file-path is a list of lists
# e.g (['A','B','C'],['D','E','F']) expands under Linux to:
# "A/B/C","D/E/F"

# --------------------------------------------------------------
# all files of libCom that are in the 'libCom' directory:
my @generic_libcomFiles= map{ ['libCom',$_] } 
  qw(
  aToIPAddr.c    dbmf.c         fdmgr.c        pal.c           sun4ansi.c
  adjustment.c   ellLib.c       freeListLib.c  paldef.c        truncateFile.c
  assertUNIX.c   envSubr.c      gpHashLib.c    postfix.c       tsSubr.c
  bucketLib.c    epicsString.c  macCore.c      realpath.c
  calcPerform.c  errSymLib.c    macUtil.c      sCalcPerform.c
  cvtFast.c      errlogUNIX.c   memDebugLib.c  sCalcPostfix.c
  );

# all files of libCom that are platform-dependant:
my %platform_libcomFiles= 
      ( 
        'hpux'      => [ ['libCom','os','generic','bsdSockResource.c'],
                         ['libCom','os','generic','osiSleep.c'],
                         ['libCom','os','generic','sigPipeIgnore.c'],   
                         ['libCom','O.hp700','envData.c'],
                         ['libCom','O.hp700','errSymTbl.c' ],       
                       ],
        'hpux-11'   => [ ['libCom','os','generic','bsdSockResource.c'],
                         ['libCom','os','generic','osiSleep.c'],
                         ['libCom','os','generic','sigPipeIgnore.c'],   
                         ['libCom','O.hp700','envData.c'],
                         ['libCom','O.hp700','errSymTbl.c' ],       
                       ],
        'solaris'   => [ ['libCom','os','generic','bsdSockResource.c'],
                         ['libCom','os','generic','osiSleep.c'],
                         ['libCom','os','generic','sigPipeIgnore.c'],
                         ['libCom','O.solaris','envData.c'],
                         ['libCom','O.solaris','errSymTbl.c' ],        
                       ],
        'linux-x86' => [ ['libCom','os','generic','bsdSockResource.c'],
                         ['libCom','os','generic','osiSleep.c'],
                         ['libCom','os','generic','sigPipeIgnore.c'],
                         ['libCom','O.Linux','envData.c'],
                         ['libCom','O.Linux','errSymTbl.c' ],
                       ],
        'win32-x86' => [ ['libCom','os','WIN32','bsdSockResource.c'],          
                         ['libCom','os','WIN32','getopt.c'], 
                         ['libCom','os','WIN32','sigPipeIgnore.c'], 
                         ['libCom','os','WIN32','getLastWSAErrorAsString.c'],  
                         ['libCom','os','WIN32','osiSleep.c'], 
                       ],
      );

my %libcom_subdirs= ( 'hpux'      => [["os","generic"],["O.hp700"]],
                      'hpux-11'   => [["os","generic"],["O.hp700"]],
                      'solaris'   => [["os","generic"],["O.solaris"]],
                      'linux-x86' => [["os","generic"],["O.Linux"]],
                      'win32-x86' => [["O.Linux"],["os","WIN32"]],
                    );


# --------------------------------------------------------------

# all files of libca that are in the "ca" directory:
# ls *.c in ca
#   removed: windows_depen.c
my @generic_libcaFiles= map{ ['ca',$_] } 
  qw(
  access.c     convert.c       iocinf.c       service.c     windows_depen.c
  bsd_depen.c  flow_control.c  posix_depen.c  syncgrp.c
  conn.c       if_depen.c      repeater.c     test_event.c
  );

# all files of libca that are platform-dependant:
my %platform_libcaFiles= 
          (
                     'hpux'      => [],
                     'hpux-11'   => [],
                     'solaris'   => [], 
                     'linux-x86' => [], 
                     'win32-x86' => [ ['ca','windows_depen.c'],
                                    ],   
          );


# --------------------------------------------------------------


# ezca objects and their directory:
my @ezca_obj= (['ezca','ezca.c']);


# --------------------------------------------------------------
# determine platform
# --------------------------------------------------------------

# determine the current HOST architecture
my $platform= myutils::platform();

# --------------------------------------------------------------
# exported functions
# --------------------------------------------------------------

sub pl_includes 
  { my @l= map { [$_] } @include_dirs;
    my $str= myutils::compose_many(\@l,"-I"); 
    return($str); 
  }
  
sub pl_defines
  { $platform= myutils::platform() if (!defined $platform);
    return($defines{$platform}); 
  }

sub pl_dir
  { return(\@subdirs); }
  
sub pl_libdirs 
  { return; }

sub pl_libs 
  { $platform= myutils::platform() if (!defined $platform);
    return($libs{$platform});
  }

sub pl_objects
  { $platform= myutils::platform() if (!defined $platform);
    
    my $libcomstr = 
         myutils::compose_many(\@generic_libcomFiles,"",undef,1);

    my $lib2comstr= 
         myutils::compose_many($platform_libcomFiles{$platform},"",undef,1);

    my $libcastr  = 
         myutils::compose_many(\@generic_libcaFiles ,"",undef,1);

    my $lib2castr = 
         myutils::compose_many($platform_libcaFiles{$platform},"",undef,1);
  
    my $ezca_str  = 
         myutils::compose_many(\@ezca_obj,"",undef,1);

    return(myutils::c2obj("Pezca.c $ezca_str " . 
                          "$libcomstr $lib2comstr $libcastr $lib2castr"));
  }

sub pl_mk_includes
# generate the include-path parameters for the
# compiler call
# @dirs: a list of directories, all with '/' as path
# separator even under windows!
  { my(@dirs)= @_;
    my @list;
  
    foreach my $dir (@dirs)
      { my $r_l= myutils::mklist($dir);
        push @list,$r_l;
      };
#print Dumper(\@list);
#print "str:" . myutils::compose_many(\@list,"-I");
    return(myutils::compose_many(\@list,"-I"));
  }     
     
 
sub pl_platform_includes
  { my($prefix)= @_;
    my @new;
    
    if ($prefix=~/\//) # convert path to list
      { $prefix= mklist($prefix); }
    
    $platform= myutils::platform() if (!defined $platform);
    
    my $r_new= myutils::add_prefix($prefix,$platform_includes{$platform});

    my $str= myutils::compose_many($r_new,"-I"); 
    return($str); 
  }

sub pl_libcom_subdirs
  { $platform= myutils::platform() if (!defined $platform);
    my $r_subdirs= $libcom_subdirs{$platform};
    
    my @new= map { myutils::compose_many([$_],"") } (@$r_subdirs);
    
    return(\@new); 
  }

sub pl_dump
  { return(myutils::dump(@_)); }

1;

