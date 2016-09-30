#!/usr/bin/env perl
## asynErrorsFromLog.pl:
# *****************
#
# *  Author  : Kuner
#
#

$usage = "USAGE: asynErrorsFromLog.pl sioc_N_.log\n\nparse logfile and show statistic of timouts\n";
use Data::Dumper;

if($ARGV[0] eq "-h") {
    print $usage;
    exit(0);
}

print "asynErrorsFromLog.pl: $ARGV[0]\n";
open(IN_FILE, "<$ARGV[0]") or die "can't open input file '$ARGV[0]': $!";

%conn;
%dev;
while(<IN_FILE>) {
    if($_=~/ (IP\d+||L\d+) (.*?): No reply from device/) {
        $dev{$1}{$2} += 1;
        $conn{$1} += 1;
    }
}
print "Device Errors:\n",Dumper(\%dev),"\nConnection Errors:\n";
foreach $con (sort(keys(%conn))) {
    print "$con\t$conn{$con}\n";
}
