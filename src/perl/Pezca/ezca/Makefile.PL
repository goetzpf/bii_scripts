use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

# Makefile.PL for ezca

require "platform.p";

WriteMakefile(
    'NAME'    => 'ezca',
    'SKIP'    => [qw(all static static_lib dynamic dynamic_lib
                     test test_dynamic test_static)],
    'DEFINE'  => $defines{$platform},
    'INC'     => '-I../include -I../db -I../ca -I../libCom -I.',
);

sub MY::top_targets {
'
all :: $(O_FILES)
';
}

