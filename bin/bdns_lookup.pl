eval 'exec perl -S $0 ${1+"$@"}' # -*- Mode: perl -*-
  if 0;

use strict;

eval 'exec perl -S $0 ${1+"$@"}' # -*- Mode: perl -*-
    if 0;
# the above is a more portable way to find perl
# ! /usr/bin/perl

use strict;

use FindBin;

# search dbitable.pm ralative to the location of THIS script:
use lib "$FindBin::RealBin/../lib/perl";

use DBI;
use BDNS;
use Options;
use ODB;

Options::register(
  ["file", "f", "=s", "write to file <tablename>.<part>.sql"],
  ["groups", "g", "=s", "extract all groups of device"],
  ["output", "o", "=s", "output as a list, set, names"],
);

my $usage = "parse bessy device name service for the given list of names or patterns (*, ?)
usage: bdns_lookup [options] names...
options:
";

my $config = Options::parse($usage);

$usage = $usage . $Options::help;

die $usage if not $config or $config->{"help"};

my @names = @ARGV;

my $handle = ODB::login($config);

Options::print_out("connected as ".$config->{"user"}."@".$config->{"dbase"}."\n");

die $usage if not @names;

foreach my $devname (@names) {
  $devname =~ s/\*/%/;
  $devname =~ s/\?/_/;
warn "Result parsed $devname";
  my $result = ODB::sel("BASE.V_NAMES", "*", "NAME like '$devname'");

  print "\n$result\n";
}
exit;
