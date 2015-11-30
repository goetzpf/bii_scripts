eval 'exec perl -S $0 ${1+"$@"}' # -*- Mode: perl -*-
  if 0;
use strict;
use BDNS;
use Data::Dumper;

if ($#ARGV < 0) {
    print "USAGE: bdnsParse.pl DEVNAME1 ...\n";
    exit(1);
}
#my @tags = qw(Member Index-ALL Index SubIndex Family Counter Subdomain-All Subdomain Subdomain-Pre Subdomain-Number Domain Facility);

foreach my $devname (@ARGV) {
	my @parts = BDNS::parse($devname);
#    print map{"$_->[1]\t$_->[0]\n"} map {[$tags[$_], $parts[$_]]} (0 .. $#parts);


    print   "$devname:\n".
            "\tMember    $parts[0]\n".
            "\tIndex     $parts[1]\n".
            "\tFamily    $parts[4]\n".
            "\tCounter   $parts[5]\n".
            "\tSubdomain $parts[8]$parts[9]\n".
            "\tDomain    $parts[10]\n".
            "\tFacility  $parts[11]\n";
}
