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
use Options;
use ODB;
use Data::Dumper;

Options::register(
  ["dbase",  "d", "=s", "Database instance (e.g. bii_par)", "database", $ENV{'ORACLE_SID'}],
  ["user",   "u", "=s", "User name",  "user",     "guest"],
  ["passwd", "p", "=s", "Password",   "password", "bessyguest", 1],
  ["index",  "i",   "", "write additionally an counting index"],
  ["output", "o", "=s", "output format as a selection of table, list, set, csv, perl (table as default)"],
  ["raw",    "r",   "", "set raw output without any descriptions and format lines or characters"],
  ["groups", "g",   "", "extract all groups of device active for table, list, set and csv"],
  ["force",  "f",   "", "use force query with the default database account"],
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
    } elsif (lc($config->{"output"}) =~ /^csv$/) {
        $out = 3;
    } elsif (lc($config->{"output"}) =~ /^perl$/) {
        $out = 4;
    }
}

if ($config->{"force"}) {
    $config->{"user"} = "guest";
    $config->{"passwd"} = "bessyguest";
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
  if (! $config->{raw}) {
    my $head = "";
    if ($config->{index}) {
        $head = sprintf ("|%6s ", "#");
    }
    if ($out == 1) {
        $head .=  "|".join("|",map(sprintf(" %12s ",$_),
            ('KEY', 'NAME', 'MEMBER', 'IND', 'FAMILY', 'COUNTER', 'SUBDOMAIN','DOMAIN')));
        $head .= "|".join("|",map(sprintf(" %s ",$_),
            ('DESCRIPTION')));
        if ($config->{"groups"}) {
            $head .= " & GROUPS";
        }
        for (my $index = 0; $index < length($head)+10; $index++) {
            print "-";
        }
        print "\n".$head."\n";
        for (my $index = 0; $index < length($head)+10; $index++) {
            print "-";
        }
    } elsif ($out == 3) {
        print join(",",map(sprintf("\"%s\"",$_),
            ('KEY', 'NAME', 'MEMBER', 'IND', 'SUBIND', 'FAMILY', 'COUNTER', 'SUBDOMAIN','DOMAIN', 'DESCRIPTION')));
    }
    print "\n";
  }
  foreach my $row (@$result) {
    $indexed++;
    my $grouplist;
    if ($config->{"groups"}) {
        my $gresult = ODB::sel("BASE.V_NAMES n, BASE.V_NAME_GROUPS vng", "GROUP_NAME||' ('||NAME_GROUP_KEY||'/'||OWNER||')' GROUPS", "n.NAME_KEY =".$row->{KEY}." AND n.KEY = vng.NAME_KEY");
        my $gindexer = 0;
        foreach my $grow (@$gresult) {
            $gindexer++;
            if ($gindexer  > 1) {
                 $grouplist .= ", ";
            }
            $grouplist .=  join("/", map(sprintf("%s",$grow->{$_}), ('GROUPS')));
        }
    }
    if ($out == 2) {
        if ($config->{"raw"}) {
            print "\n".join("\n",map(sprintf("%12s: %s",$_,$row->{$_}),
                ('KEY', 'NAME', 'MEMBER', 'IND', 'FAMILY', 'COUNTER', 'SUBDOMAIN','DOMAIN')))."\n";
        } else {
            if ($config->{index}) {
                printf ("%12s: #%u\n", "Entry", $indexed);
                print "--------------------------------------------------------------------------------\n";
            }
            print join("\n",map(sprintf("%12s: %s",$_,$row->{$_}),
                ('KEY', 'NAME', 'MEMBER', 'IND', 'SUBIND', 'FAMILY', 'COUNTER', 'SUBDOMAIN','DOMAIN', 'DESCRIPTION')))."\n\n";
            if ($config->{groups}) {
                printf("%12s: %s", "GROUPS", $grouplist);
            }
            print "\n================================================================================\n";
        }
    } elsif ($out == 3) {
        if ($config->{"raw"}) {
            print join(",", map(sprintf("%u",$row->{$_}),
                ('KEY'))).",";
            print join(",", map(sprintf("\"%s\"",$row->{$_}),
                ('NAME','MEMBER','IND','FAMILY'))).",";
            print join(",", map(sprintf("%u",$row->{$_}),
                ('COUNTER'))).",";
            print join(",", map(sprintf("\"%s\"",$row->{$_}),
                ('DOMAIN')))."\n";
        } else {
            print join(",", map(sprintf("%u",$row->{$_}),
                ('KEY'))).",";
            print join(",", map(sprintf("\"%s\"",$row->{$_}),
                ('NAME','MEMBER'))).",";
            print join(",", map(sprintf("%u",$row->{$_}),
                ('IND', 'SUBIND'))).",";
            print join(",", map(sprintf("\"%s\"",$row->{$_}),
                ('FAMILY'))).",";
            print join(",", map(sprintf("%u",$row->{$_}),
                ('COUNTER'))).",";
            print join(",", map(sprintf("\"%s\"",$row->{$_}),
                ('DOMAIN', 'DESCRIPTION')))."\n";
        }

    } elsif ($out == 0) {
        if ($config->{"raw"}) {
            if ($indexed > 1) {
                print ",";
            }
            print $row->{'NAME'};
        } else {
            print "\n";
            if ($config->{index}) {
                print "$indexed ";
            }
            print $row->{'NAME'};
        }
    } elsif ($out == 4) {
        if ($config->{"raw"}) {
            print Dumper $row;
        } else {
            print "#";
            if ($config->{index}) {
                print $indexed;
            }
            print "\t".$row->{'NAME'};
            print "\n".join("\n",map(sprintf("\$bdns->{".$row->{'NAME'}."}->{%s}=\"%s\";",$_,$row->{$_}),
                ('KEY', 'MEMBER', 'IND', 'SUBIND', 'FAMILY', 'COUNTER', 'SUBDOMAIN','DOMAIN', 'DESCRIPTION')))."\n";
        }
    } else {
        if ($config->{"raw"}) {
            print join("\t", map(sprintf(" %s ",$row->{$_}),
                ('KEY', 'NAME','MEMBER','IND','FAMILY','COUNTER','DOMAIN')))."\n";
        } else {
            if ($config->{index}) {
                printf ("|%6s ", $indexed);
            }
            print "|".join("|",map(sprintf(" %12s ",$row->{$_}),
                ('KEY', 'NAME', 'MEMBER', 'IND', 'SUBIND', 'FAMILY', 'COUNTER', 'SUBDOMAIN','DOMAIN')));
            print "|".join("|",map(sprintf(" %s ",$row->{$_}),
                ('DESCRIPTION')))."\n";
            if ($config->{groups}) {
                print $grouplist;
            }
            print "\n";
        }
    }
  }
  if ($indexed > 0 && ! $config->{"raw"}) {
    if ($out == 2) {
        print "$indexed Entries found\n";
        print "================================================================================\n";
    } elsif ($out == 1) {
        print "\n$indexed Entries found\n";
    } elsif ($out == 0) {
        print "\n";
    }
  }

}
exit;
