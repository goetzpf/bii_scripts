use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

require "platform.p";

# "ls *.c in libCom: 
my @libcomFiles= qw(

aToIPAddr.c    dbmf.c         fdmgr.c        pal.c           sun4ansi.c
adjustment.c   ellLib.c       freeListLib.c  paldef.c        truncateFile.c
assertUNIX.c   envSubr.c      gpHashLib.c    postfix.c       tsSubr.c
bucketLib.c    epicsString.c  macCore.c      realpath.c
calcPerform.c  errSymLib.c    macUtil.c      sCalcPerform.c
cvtFast.c      errlogUNIX.c   memDebugLib.c  sCalcPostfix.c

);

if ($platform eq 'win32-msc')
  { # ls *.c in /libCom/os/WIN32
    my @f= qw( 
	       bsdSockResource.c          getopt.c    sigPipeIgnore.c
	       getLastWSAErrorAsString.c  osiSleep.c
	     );
  
    push @libcomFiles,  (map { "os/WIN32/$_" } @f)
  }
else
  { # ls *.c in /libCom/os/generic
    my @f= qw(
               bsdSockResource.c  osiSleep.c  sigPipeIgnore.c
             ); 
    push @libcomFiles,  (map { "os/generic/$_" } @f)
  };

# *****************************************************************

# ls *.c in ca
#   removed: windows_depen.c
my @libcaFiles=qw(
access.c     convert.c       iocinf.c       service.c     windows_depen.c
bsd_depen.c  flow_control.c  posix_depen.c  syncgrp.c
conn.c       if_depen.c      repeater.c     test_event.c
);

# add windows_depen.c to @libcaFiles when compiling for Windows:
#if ($platform eq 'win32-msc')
#  { push @libcaFiles,'windows_depen.c'; };

my $libcomstr= c2obj('libCom/' . join(' libCom/',@libcomFiles));

my $libcastr = c2obj('ca/' . join(' ca/',@libcaFiles));


my $libs= "-lm ";
if ($platform eq 'win32-msc')
  { $libs.= "ws2_32.lib"; };   

WriteMakefile(
    'NAME'         => 'Pezca',
    'VERSION_FROM' => 'Pezca.pm', # finds $VERSION
    'INC'    	   => '-Iinclude -IlibCom -Ica -Idb -Iezca',
    'DEFINE' 	   => $defines{$platform},
    'DIR'    	   => ['libCom', 'ca', 'ezca'],
    'LIBS'         => $libs,
    'OBJECT' 	   => "Pezca.o ezca/ezca.o $libcomstr $libcastr " .
                      add_obj(),
);

