eval 'exec perl -S $0 ${1+"$@"}' # -*- Mode: perl -*-
  if 0;

# Copyright 2015 Helmholtz-Zentrum Berlin für Materialien und Energie GmbH
# <https://www.helmholtz-berlin.de>
#
# Authors:
#     Thomas Birke <Thomas.Birke@helmholtz-berlin.de>
#     Benjamin Franksen <Benjamin.Franksen@helmholtz-berlin.de>
#     Victoria Laux <victoria.laux@helmholtz-berlin.de>
#     Goetz Pfeiffer <Goetz.Pfeiffer@helmholtz-berlin.de>
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


use FindBin;

# enable this if you want to search modules like dbitable.pm
# relative to the location of THIS script:
# ------------------------------------------------------------
# use lib "$FindBin::RealBin/../lib/perl";

use strict;
use DBI;
use BDNS;
use Options;
use PgDB;
use Data::Dumper;

Options::register(
  ["dbase",       "d",  "=s", "Database instance (e.g. bii_par)", "database", $ENV{'PGDATABASE'}],
  ["user",        "u",  "=s", "User name", "user", $ENV{'USER'}],
  ["passwd",      "p",  "=s", "Password", "password", "", 1],
  ["dbhost",      "H",  "=s", "Database hostname", "host", $ENV{'PGHOST'}],
  ["dbport",      "P",  "=s", "Database port", "port", $ENV{'PGPORT'}],
  ["file",        "f",  "=s", "Read (additional) names from a file"],
  ["dump",        "o",  "",   "Dont do database actions, output commands"],
  ["separator",   "s",  "=s", "Name separator [default: whitespace]"],
  ["description", "d",  "=i", "Description in file on column-number to name"],
  ["yes",         "y",  "",   "Ignore failure prompt, print them out"],
  ["commit",      "c",  "",   "Wait at the end of inserting the names for the commit input"],
);

my $usage = "import a list of names into the bessy device name service
usage: bdns_import [options] names...
options:
";

my $config = Options::parse($usage, 1);

$usage = $usage . $Options::help;

my @names = @ARGV;
my @descs;
my @pkeys;

if ($config->{"file"}) {
	open INPUT, $config->{"file"} or die "Cannot open file $config->{'file'}";
	if (! $config->{"separator"} or $config->{"separator"} eq "") {
		$config->{"separator"} = " ";
	}
	if ($config->{"decription"} < 0) {
		delete ($config->{"decription"});
		print "Description will be ignored.\n"
	}
	while (my $line = <INPUT>) {
		chop($line);
		if (length($line)>3) {
			my @lineparts = split ($config->{"separator"}, $line);
			push @names, @lineparts[0];
			if ($config->{"decription"} >= 0) {
				push @descs, $lineparts[$config->{"description"}];
			}
		}
	}
	close INPUT;
}

die $usage if not $config or $config->{"help"} or not @names;

my %allnames;

my $counter = 0;
foreach my $devname (@names) {
	my @parts = BDNS::parse($devname);
	die "Error: $devname is not a valid device name!\n" if (not defined @parts or length(@parts[0]) < 1 or length(@parts[4]) != 1 or length(@parts[6].@parts[11]) < 1);
	@parts[0] = "'".@parts[0]."'";
	if (! defined @parts[2] or @parts[2] eq "" ) {
		@parts[2]  = "NULL";
		@parts[3]  = "NULL";
	} else {
		@parts[2]  = "'".@parts[2]."'";
	}
	if (! defined $parts[3] or $parts[3] eq "" ) {
		@parts[3]  = "NULL";
	} else {
		@parts[3]  = "'".@parts[3]."'" if @parts[3] ne "NULL";
	}
	if (! defined $parts[5] or $parts[5] eq "" ) {
		@parts[5]  = "NULL";
	} else {
		@parts[5]  = "'".@parts[5]."'";
	}
	$allnames{$devname} = {
		"PART_NAME" => @parts[0],
		"PART_INDEX"  => @parts[2],
		"PART_SUBINDEX" => @parts[3],
		"DEVICE_FAMILY_KEY" => "inventory.get_family_key('".@parts[4]."')",
		"PART_COUNTER" => @parts[5],
		"NAME_SUBDOMAIN_KEY" => "inventory.get_name_subdomain_key('".@parts[6].@parts[11]."')",
	};
	if ($config->{"description"} >= 0) {
		$allnames{$devname}{"DESCRIPTION"} = @descs[$counter];
	}
	$counter++;
}

my $handle;

if (! $config->{"dump"}) {
	Options::ask_out($config);
	$handle = PgDB::login($config);
	Options::print_out("Connected as ".$config->{"user"}."@".$config->{"dbase"}."\n");
}

foreach my $devname (@names) {
	my $sql1 = "INSERT INTO inventory.tbl_name (",
	my $sql2 = "VALUES (";
	my $verbose = "NAME:$devname " ;
	$sql1 .= "part_name, part_index, part_subindex, device_family_key, part_counter, name_subdomain_key";
	$sql2 .= $allnames{$devname}{"PART_NAME"}.", ".$allnames{$devname}{"PART_INDEX"}.", ".$allnames{$devname}{"PART_SUBINDEX"}.", "
		. $allnames{$devname}{"DEVICE_FAMILY_KEY"}.", ".$allnames{$devname}{"PART_COUNTER"}.", ".$allnames{$devname}{"NAME_SUBDOMAIN_KEY"};
	if ($config->{"description"}) {
		$sql1 .= ", description";
		$sql2 .= ", '".$allnames{$devname}{"DESCRIPTION"}."'";
		$verbose .= " DESCRIPTION:".$allnames{$devname}{"DESCRIPTION"};
	}
	$sql1 .= ") ";
	$sql2 .= ")";
	print $verbose."\n" if ($config->{"verbose"});
	if (! $config->{"dump"}) {
		eval {
			$handle->do($sql1.$sql2);
			$handle->commit;
		};
		print $sql1.$sql2."\n" if $config->{"verbose"};
		if ($config->{"not"}) {
			$handle->rollback;
		} elsif ($@) {
			print $@."\n";
			if ($config->{"yes"}) {
				print "$devname failed\n";
			} else {
				$handle->rollback if (lc(Options::get_stdin($devname." fails. continue?", "yes")) ne "yes");
			}
		}
	} else {
		print "$sql1 $sql2;\n";
	}
}

exit;
