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
use Data::Dumper;

Options::register(
  ["dbase",  "d", "=s", "Database instance (e.g. bii_par)", "database", $ENV{'ORACLE_SID'}],
  ["user",   "u", "=s", "User name",  "user",     "guest"],
  ["passwd", "p", "=s", "Password",   "password", "bessyguest", 1],
  ["file",   "f", "=s", "write to file <tablename>.<part>.sql"],
  ["output", "o", "=s", "output as a list, set, table or commataseparated"],
  ["raw",    "r",   "", "set raw output without any additionals (lines or descriptions"],
  ["groups", "g",   "", "extract all groups of device"],
);

my $usage = "parse bessy device name service for the given list of names or patterns (*, ?)
usage: bdns_lookup [options] names...
options:
";

my $config = Options::parse($usage);

$usage = $usage . $Options::help;

die $usage if not $config or $config->{"help"};

our $out = 1;
if (defined ($config->{"output"})) {
    if (lc($config->{"output"}) =~ /^list$/) {
        $out = 0;
    } elsif (lc($config->{"output"}) =~ /^set$/) {
        $out = 2;
    }
}

if ($out != 2 && $config->{"groups"}) {
    $config->{"groups"} = 1;
}

my @names = @ARGV;

my $handle = ODB::login($config);

delete ($config->{"passwd"});

Options::print_out("connected as ".$config->{"user"}."@".$config->{"dbase"}."\n");

die $usage if not @names;

#print Dumper $config;

foreach my $devname (@names) {
  $devname =~ s/\*/%/;
  $devname =~ s/\?/_/;
  my $result;
  my $raw;
  if ($config->{"raw"}) {
    $result = ODB::sel("NAMES", "KEY, NAME, MEMBER, IND, FAMILY, COUNTER, SUBDOMAIN||DOMAIN DOMAIN", "NAME like '$devname'");
  } else {
    $result = ODB::sel("BASE.V_NAMES vn, BASE.V_NAME_DESCRIPTIONS vnd", "vn.KEY, vn.NAME, vnd.DESCRIPTION, vn.MEMBER, vn.IND, vn.SUBIND, vn.FAMILY, vn.COUNTER, vn.SUBDOMAIN, vn.DOMAIN", "vn.NAME like '$devname' AND vn.KEY=vnd.KEY");
  }
  if ($config->{"groups"}) {
  }
  my $indexed = 0;
  if ($out == 1) {
    print "\t+".join("\t+", ('KEY', 'NAME', 'DESCRIPTION', 'MEMBER', 'IND', 'FAMILY', 'COUNTER', 'SUBDOMAIN','DOMAIN'))."\n";
  }
  foreach my $row (@$result) {
    $indexed++;
    if ($out == 2) {
        if ($config->{"raw"}) {
            print join("\n",map(sprintf("%12s: %s",$_,$row->{$_}),
                ('KEY', 'NAME', 'MEMBER', 'IND', 'FAMILY', 'COUNTER', 'SUBDOMAIN','DOMAIN')))."\n\n";
        } else {
            print "Entry #$indexed\n";
            print "--------------------------------------------------------------------------------\n";
            print join("\n",map(sprintf("%12s: %s",$_,$row->{$_}),
                ('KEY', 'NAME', 'MEMBER', 'IND', 'SUBIND', 'FAMILY', 'COUNTER', 'SUBDOMAIN','DOMAIN', 'DESCRIPTION')))."\n\n";
            if ($config->{"groups"}) {
                printf ("\n%12s: ", "GROUPS");
                my $gresult = ODB::sel("BASE.V_NAMES n, BASE.V_NAME_GROUPS vng", "GROUP_NAME||' ('||NAME_GROUP_KEY||'/'||OWNER||')' GROUPS", "n.NAME_KEY =".$row->{KEY}." AND n.KEY = vng.NAME_KEY");
                my $gindexer = 0;
                foreach my $grow (@$gresult) {
                    $gindexer++;
                    if ($gindexer  > 1) {
                        print ", ";
                    }
                    print map(sprintf("%s",$grow->{$_}), ('GROUPS'));
                }
            }
            print "\n================================================================================\n";

        }
    } elsif ($out == 0) {
        if ($config->{"raw"}) {
            if ($indexed > 1) {
                print ",";
            }
            print $row->{'NAME'};
        } else {
            print "\n".$row->{'NAME'};
        }
    } else {
        if ($config->{"raw"}) {
            print join("\t", map(sprintf(" %s ",$row->{$_}),
                ('KEY', 'NAME','MEMBER','IND','FAMILY','COUNTER','DOMAIN')))."\n";
        } else {
            print "#$indexed";
            print "|".join("\t|",map(sprintf(" %s ",$row->{$_}),
                ('KEY', 'NAME', 'MEMBER', 'IND', 'FAMILY', 'COUNTER', 'SUBDOMAIN','DOMAIN', 'DESCRIPTION')))."\n";
        }
    }
  }
  if ($indexed > 0 && ! $config->{"raw"} && $out == 2) {
    print "$indexed Entries found\n";
    print "================================================================================\n";
  }
  if ($indexed > 0 && ! $config->{"raw"} && $out == 1) {
    print "\n$indexed Entries found\n";
  }

}
exit;
