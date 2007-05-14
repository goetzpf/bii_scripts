use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

# Makefile.PL for libCom/O.hp700

use platform 
  qw(pl_includes pl_defines pl_dir pl_libdirs
     pl_libs pl_objects
     pl_mk_includes
     pl_platform_includes pl_libcom_subdirs);

WriteMakefile(
    'NAME'    => 'libCom/O.hp700', # perhaps leave this undefined ?
    'SKIP'    => [qw(all static static_lib dynamic dynamic_lib
                     test test_dynamic test_static)],
    'DEFINE'  => pl_defines(),
#    'INC'    => '-I../../../include -I../..' . 
#                base_includes(" -I../../../") . '-I.  ',
    'INC'    => join(" ",
                     pl_mk_includes('../../include','..','.'),
                     pl_platform_includes(["..",".."])),
);

sub MY::top_targets {
'
all :: $(O_FILES)
';
}

