use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

# Makefile.PL for libCom/solaris

require "platform.p";

WriteMakefile(
    'NAME'    => 'libCom/solaris', # perhaps leave this undefined ?
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

