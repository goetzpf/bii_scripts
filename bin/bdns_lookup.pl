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
  ["dbase",  "d", "=s", "Database instance (e.g. bii_par)", "database", $ENV{'ORACLE_SID'}],
  ["user",   "u", "=s", "User name",  "user",     "guest"],
  ["passwd", "p", "=s", "Password",   "password", "bessyguest", 1],
  ["file",   "f", "=s", "write to file <tablename>.<part>.sql"],
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
# warn "Result parsed $devname";
  my $result = ODB::sel("NAMES", "*", "NAME like '$devname'");

  foreach my $row (@$result) {
    print "================================================================================\n";
    print join("\n",map(sprintf("%12s = '%s'",$_,$row->{$_}),
      ('NAME','DESCRIPTION','KEY','MEMBER','IND','FAMILY','COUNTER','SUBDOMAIN','DOMAIN')))."\n";
  }
}

exit;
