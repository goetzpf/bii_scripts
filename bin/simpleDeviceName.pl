#!/usr/bin/perl
while (<>) {
  chomp;
  if (
    /
    ([A-Z]+)                  # member
    ([0-9]+(-[0-9]+)?)?       # index and subindex
    ([BCFGHIKLMNOPQRSTVWYZ])  # family
    ([0-9]*)                  # counter
    ([BCDEGKLMSTUX][0-9]*)    # subdomain
    ([BCDEGHILMRSTV])         # domain
    ([FP]?)                   # facility
    /x
  ) {
    print "input=$_ member=$1 index=$2 subindex=$3 family=$4 counter=$5 subdomain=$6 domain=$7 facility=$8\n";
  }
}
