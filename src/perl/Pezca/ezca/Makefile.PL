use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

# Makefile.PL for ezca

use platform 
  qw(pl_includes pl_defines pl_dir pl_libdirs
     pl_libs pl_objects
     pl_mk_includes
     pl_platform_includes pl_libcom_subdirs);

WriteMakefile(
    'NAME'    => 'ezca',
    'SKIP'    => [qw(all static static_lib dynamic dynamic_lib
                     test test_dynamic test_static)],
    'DEFINE'  => pl_defines(),
    'INC'     => pl_mk_includes('../include','../db','../ca','../libCom','.'),
);

sub MY::top_targets {
'
all :: $(O_FILES)
';
}

