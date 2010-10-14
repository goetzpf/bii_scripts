#!/usr/bin/perl


use strict;
use BDNS;

my @pvs;

while(my $l=<>)
  { 
    chomp($l);
    push @pvs, $l;
  }

print "parse test:\n";
for my $pv (@pvs)
  {
    my @x= BDNS::parse($pv);
    print $pv,":",join("|",@x),"\n";
  }

print "\ntest of default sort:\n";

my @sort_pvs= BDNS::sortNames(\@pvs);
for my $pv (@sort_pvs)
  {
    print $pv,"\n";
  }

my @order=qw(SUBDOMPRE COUNTER INDEX MEMBER FACILITY);
print "\ntest of sort ",join(" ",@order),"\n";
BDNS::setOrder(\@order);
my @sort_pvs= BDNS::sortNames(\@pvs);
for my $pv (@sort_pvs)
  {
    print $pv,"\n";
  }

# test of new functions
eval{BDNS::mkOrder("DEFAULT")};
if ($@)
  { exit(0); };

print "\ntest of sort by ",join(" ",@order),"\n";
BDNS::setOrder("DEFAULT");
my $r_o= BDNS::mkOrder(\@order);
my @sort_pvs= BDNS::sortNamesBy(\@pvs,$r_o);
for my $pv (@sort_pvs)
  {
    print $pv,"\n";
  }


