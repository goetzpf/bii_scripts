use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

# Makefile.PL for libCom/O.hp700

require "platform.p";

WriteMakefile(
    'NAME'    => 'libCom/O.hp700', # perhaps leave this undefined ?
    'SKIP'    => [qw(all static static_lib dynamic dynamic_lib
                     test test_dynamic test_static)],
    'DEFINE'  => $defines{$platform},
#    'INC'    => '-I../../../include -I../..' . 
#                base_includes(" -I../../../") . '-I.  ',
    'INC'    => '-I../../include' . base_includes(" -I../../") . 
                '-I.. -I. ',
);

sub MY::top_targets {
'
all :: $(O_FILES)
';
}

