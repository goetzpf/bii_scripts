eval 'exec perl -S $0 ${1+"$@"}' # -*- Mode: perl -*-
  if 0;

# Copyright 2015 Helmholtz-Zentrum Berlin für Materialien und Energie GmbH
# <https://www.helmholtz-berlin.de>
#
# Author: Victoria Laux <victoria.laux@helmholtz-berlin.de>
#
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later
# version.
# 
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
# details.
# 
# You should have received a copy of the GNU General Public License along with
# this program.  If not, see <http://www.gnu.org/licenses/>.


use strict;

eval 'exec perl -S $0 ${1+"$@"}' # -*- Mode: perl -*-
    if 0;
# the above is a more portable way to find perl
# ! /usr/bin/perl

use strict;

use FindBin;

# enable this if you want to search modules like dbitable.pm
# relative to the location of THIS script:
# ------------------------------------------------------------
# use lib "$FindBin::RealBin/../lib/perl";

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

my @units = @ARGV;

my $handle = ODB::login($config);

delete ($config->{"passwd"});

Options::print_out("connected as ".$config->{"user"}."@".$config->{"dbase"}."\n");

die $usage if not @units;

#print Dumper $config;

foreach my $unitname (@units) {
  $unitname =~ s/\*/%/;
  $unitname =~ s/\?/_/;
  my $result;
  my $raw;
  if ($config->{"raw"}) {
    $result = ODB::sel("PHYSICAL_UNITS", "PHYSICAL_UNIT_LIST_KEY KEY, SIGN, VALUE_FACTOR, VALUE_BASE, NAME", "NAME like '$unitname'");
  } else {
    $result = ODB::sel("BASE.V_PHYSICAL_UNITS", "*", "NAME like '$unitname'");
  }
  my $indexed = 0;
  if (! $config->{raw}) {
    my $head = "";
    if ($config->{index}) {
        $head = sprintf ("|%6s ", "#");
    }
    if ($out == 1) {
        $head .=  "|".join("|",map(sprintf(" %12s ",$_),
            ('KEY', 'SIGN', 'WWW_SIGN', 'VALUE_FACTOR', 'VALUE_BASE', 'NAME', 'NAME_PLURAL', 'DESCRIPTION')));
        $head .= "|".join("|",map(sprintf(" %s ",$_),
            ('DESCRIPTION')));
        for (my $index = 0; $index < length($head)+10; $index++) {
            print "-";
        }
        print "\n".$head."\n";
        for (my $index = 0; $index < length($head)+10; $index++) {
            print "-";
        }
    } elsif ($out == 3) {
        print join(",",map(sprintf("\"%s\"",$_),
            ('KEY', 'SIGN', 'WWW_SIGN', 'VALUE_FACTOR', 'VALUE_BASE', 'NAME', 'NAME_PLURAL', 'DESCRIPTION')));
    }
    print "\n";
  }
  foreach my $row (@$result) {
    $indexed++;
    my $grouplist;
    if ($out == 2) {
        if ($config->{"raw"}) {
            print "\n".join("\n",map(sprintf("%12s: %s",$_,$row->{$_}),
                ('KEY', 'SIGN', 'VALUE_FACTOR', 'VALUE_BASE', 'NAME')))."\n";
        } else {
            if ($config->{index}) {
                printf ("%12s: #%u\n", "Entry", $indexed);
                print "--------------------------------------------------------------------------------\n";
            }
            print join("\n",map(sprintf("%12s: %s",$_,$row->{$_}),
                ('KEY', 'SIGN', 'WWW_SIGN', 'VALUE_FACTOR', 'VALUE_BASE', 'NAME', 'NAME_PLURAL', 'DESCRIPTION')))."\n\n";
            print "\n================================================================================\n";
        }
    } elsif ($out == 3) {
        if ($config->{"raw"}) {
            print join(",", map(sprintf("%u",$row->{$_}),
                ('KEY'))).",";
            print join(",", map(sprintf("\"%s\"",$row->{$_}),
                ('SIGN'))).",";
            print join(",", map(sprintf("%u",$row->{$_}),
                ('VALUE_FACTOR', 'VALUE_BASE'))).",";
            print join(",", map(sprintf("\"%s\"",$row->{$_}),
                ('NAME', 'DESCRIPTION')))."\n";
        } else {
            print join(",", map(sprintf("%u",$row->{$_}),
                ('KEY'))).",";
            print join(",", map(sprintf("\"%s\"",$row->{$_}),
                ('SIGN','WWW_SIGN'))).",";
            print join(",", map(sprintf("%u",$row->{$_}),
                ('VALUE_FACTOR', 'VALUE_BASE'))).",";
            print join(",", map(sprintf("\"%s\"",$row->{$_}),
                ('NAME', 'NAME_PLURAL', 'DESCRIPTION'))).",";
        }

    } elsif ($out == 0) {
        if ($config->{"raw"}) {
            if ($indexed > 1) {
                print ",";
            }
            print $row->{'SIGN'};
        } else {
            print "\n";
            if ($config->{index}) {
                print "$indexed ";
            }
            print $row->{'SIGN'};
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
                ('KEY', 'SIGN', 'VALUE_FACTOR', 'VALUE_BASE', 'NAME')))."\n";
        } else {
            if ($config->{index}) {
                printf ("|%6s ", $indexed);
            }
            print "|".join("|",map(sprintf(" %12s ",$row->{$_}),
                ('KEY', 'SIGN', 'WWW_SIGN', 'VALUE_FACTOR', 'VALUE_BASE', 'NAME', 'NAME_PLURAL', 'DESCRIPTION')));
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
