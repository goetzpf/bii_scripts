use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

# Makefile.PL for libCom

require "platform.p";

WriteMakefile(
    'NAME'    => 'libCom',
    'SKIP'    => [qw(all static static_lib dynamic dynamic_lib
                     test test_dynamic test_static)],
    'DEFINE'  => $defines{$platform},
    'INC'     => '-I../include ' . base_includes(" -I../") . '-I. ',
    'DIR'     => $lc_dirs{$platform}, 
);

sub MY::top_targets {
'
all :: $(O_FILES) subdirs
';
}

