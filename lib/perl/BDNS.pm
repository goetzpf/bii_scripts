package BDNS;

require Exporter;

our @ISA = qw(Exporter);
our @EXPORT_OK = qw(parse);
our $VERSION = 1.00;

use strict;

my $re = "\\A([A-Z]{1,6})"
    . "(([0-9]{1,3})(-([0-9]{1,2}))?)?"
    . "(([BCFGHIKLMNOPQRVWYZ])([0-9]{0,2})([DSTX][0-9]{0,3})?([BIMRTCGLV])|"
    .  "([BCFGHIKLMNOPQRVWYZT])([0-9]{0,2})([LCEMSUX][0-9]{0,3})([ADEFSP]))\\Z";

# member
# all-index
#  index
#  dash-subindex
#   subindex
# fcsd
#  family
#  counter
#  subdomain
#  domain

sub parse {
  my $devname = shift;
  $devname =~ tr/a-z/A-Z/;
  if ("$devname" =~ /$re/) {
    my ($member, $allindex, $index, $subindex, $f1, $c1, $sd1, $d1, $f2, $c2, $sd2, $d2) = 
      ($1, $2, $3, $5, $7, $8, $9, $10, $11, $12, $13, $14, $15);

    my ($family, $counter, $subdomain, $domain) = ("", "", "", "");

    if ( "$d1" =~ "^\$" ) {
      ($family, $counter, $subdomain, $domain) = ($f2, $c2, $sd2, $d2);
    } else {
      ($family, $counter, $subdomain, $domain) = ($f1, $c1, $sd1, $d1);
    }

    $subdomain = "" if not defined $subdomain;
    $counter = "" if not defined $counter;
    $allindex = "" if not defined $allindex;
    $index = "" if not defined $index;
    $subindex = "" if not defined $subindex;

    my ($subdompre, $subdomnumber) = ("", "");

    if ("$subdomain" =~ /([A-Z])(.*)/) {
      ($subdompre, $subdomnumber) = ($1, $2);
    }

    if ("$subdomain$domain" =~ "^[RB]\$") {
      $subdomain = $counter;
      $counter = "";
    }

    my $allsubdomain = $subdomain . $domain;

    return (1, $member, $allindex, $index, $subindex, $family, $counter,
      $allsubdomain, $subdomain, $subdompre, $subdomnumber, $domain);
  }
  else {
    return;
  }
}

1;
