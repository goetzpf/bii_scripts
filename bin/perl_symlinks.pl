eval 'exec perl -S $0 ${1+"$@"}' # -*- Mode: perl -*-
    if 0;                         
# the above is a more portable way to find perl
# ! /usr/bin/perl

use strict;

use FindBin;
use Config;

my $umask= '0755';

chdir("$FindBin::Bin") or die;

chdir("../lib/perl_std") or die;

symlink("../../bin","bin") or die;
symlink("../../doc/man","man") or die;

