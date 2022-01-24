eval 'exec perl -S $0 ${1+"$@"}' # -*- Mode: perl -*-
if 0;

# Copyright 2022 Helmholtz-Zentrum Berlin für Materialien und Energie GmbH
# <https://www.helmholtz-berlin.de>
#
# Authors:
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


use strict;

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
use PgDB;
use Data::Dumper;

Options::register(
	['dbase',  				'd', 	'=s', "Database instance (e.g. devices)", "database", $ENV{'PGDATABASE'}],
	['dbport',  				'P', 	'=s', "Port of instance on server", "database", $ENV{'PGPORT'}],
	['dbhost',  				'H', 	'=s', "Hostname of database instance", "database", $ENV{'PGHOST'}],
	['user',   				'u', 	'=s', "User name",  'user',     "anonymous"],
	['passwd', 				'p', 	'=s', "Password",   "password", "", 1],
	['force', 				'f',   	'',   "use force query with the default database account"],
	['Verbose',  			'V',   '',    "print a lot more informations"],
	['output', 				'o', 	'=s', "output format as a selection of \n\tlist, \n\ttable, \n\thtmltable, \n\tcsvtable, \n\tset, \n\thtmlset, \n\txmlset or \n\tdump"],
	['outputbody',			'b', 	'',   "removing to output header"],
	['outputindex',			'i', 	'',   "insert indexcount to output"],
	['wwwform',				'w',	'',	  "returns the formular for webrequests" ],
	['extract', 			'x', 	'',   "concat the extracted name parts"],
	['description',			't', 	'',   "concat the textual descriptions"],
	['sort', 				's', 	'=s', "supported: key/revkey, \n\tnamerevname (default), \n\tfamily (only if -x option is set), \n\tdomain/revdomain (only if -x option is set)"],
	['revertsort', 			'S', 	'',   "revert/desc sort"],
	['facility', 			'F', 	'=s', "filter facility, like  bii, mls, fel"],
	['family', 				'T', 	'=s', "type of device, better the family"],
	['subdomain', 			'L', 	'=s', "location of the device or better the subdomain"],
);

my $usage = "parse bessy device name service for the given list of names or patterns (% as any and more, ? one unspecified character)
usage: bdns_lookup.pl [options] names...
% ... on ore more unspecified characters
_ ... one or no unspecified characters
options:
";

my $config = Options::parse($usage, 1);

$usage = $usage . $Options::help;

#warn Dumper($config);

die $usage if $#ARGV < 0 and not ($config->{"wwwform"}  or $config->{"help"});
PgDB::verbose() == 1 if $config->{'verbose'};

if (! defined $config->{'output'} or ! $config->{'output'} =~ /(table|csvtable|htmltable|list|set|htmlset|xmlset|dump)/) {
	$config->{'output'} = 'list';
}
$config->{"verbose"} = undef if ($config->{"wwwform"} or $config->{"output"} =~ /(htmltable|xmlset|htmlset)/);

my $dbschema = "inventory";

if ($config->{"force"} or $config->{"wwwform"}) {
	$config->{'dbase'} = "devices_2015";
	$config->{'user'} = "anonymous";
	$config->{'passwd'} = "bessyguest";
	$config->{'dbhost'} = "dbnode1.trs.bessy.de";
	$config->{'dbport'} = "5432";
}

my @names = @ARGV;

die $usage if $#names = 0 or undef ($config->{"wwwform"});

Options::ask_out();

# main object string, will be completed iprportionally of arguments
my $dbobject = '';
# array of the database columnnames
my @columns = ('vn.key AS "KEY"', 'vn.name AS "NAME"');
# array of the given names in the select statement
my @head = ('KEY', 'NAME');
# maybe the whereclause and teh sortorder
my $dbjoin = "vn.KEY > 0";
my %dborder = ();
my %dbtables = ();
if ($config->{'sort'}) {
	$config->{'sort'} = lc($config->{'sort'});
} else {
	$config->{'sort'} = "name";
}
my %dbselectionlists = ();
my %dboptionfield = ();

$dborder{"key"} = "vn.KEY";
$dborder{"name"} = "vn.NAME";
$dborder{"revkey"} = "vn.KEY DESC";
$dborder{"revname"} = "vn.NAME DESC";
$dbtables{'facilities'} = "location.v_facilities f";
$dbtables{'names'} = "inventory.v_names vn";
$dbtables{'subdomains'} = "inventory.v_named_subdomains vns";
$dbtables{'families'} = "inventory.v_device_families vdf";
$dbtables{'descriptions'} = "inventory.v_name_descriptionsi vnd";
$dbtables{'-'} = "";

$dbobject = $dbtables{'names'};

# columnwidth maximal
my $colmax = 12;

if ($config->{'extract'} == 1) {
	if ($config->{'wwwform'} == 1) {
		$dboptionfield{"Extraction"} = "extract";
	} else {
		push @columns, ('MEMBER','IND', 'SUBIND', 'FAMILY', 'COUNTER', 'SUBDOMAIN', 'DOMAIN', 'FACILITY');
		push @head, ('MEMBER','IND', 'SUBIND', 'FAMILY', 'COUNTER', 'SUBDOMAIN', 'DOMAIN', 'FACILITY');
		$dborder{"family"} = "FAMILY";
		$dborder{"domain"} = "FACILITY, DOMAIN, SUBSTR(SUBDOMAIN, 1, 1), TO_NUMBER(SUBSTR(SUBDOMAIN, 2))";
		$dborder{"revdomain"} = "FACILITY DESC, DOMAIN DESC, SUBSTR(SUBDOMAIN, 1, 1) DESC, TO_NUMBER(SUBSTR(SUBDOMAIN, 2)) DESC";
	}
}

if ($config->{'description'} == 1) {
	if ($config->{"wwwform"} == 1) {
		$dboptionfield{"Description"} = "description";
	} else {
		$dbobject .= ', '.$dbtables{'descriptions'};
		push @columns, ('DESCRIPTION');
		push @head, ('DESCRIPTION');
		$dbjoin .= " AND vn.key = vnd.key(+)";
	}
}

if ($config->{'family'} == 1) {
	if ($config->{"wwwform"} == 1) {
		$dbselectionlists{"Families"} = [$dbtables{'families'}, "KEY, NAME||' ('||DESCRIPTION||')' VALUE", "NAME IS NOT NULL"];
	} else {
		$dbjoin .= " AND vn.family_key IN (SELECT family_key FROM ".$dbtables{'families'}." WHERE name='".$config->{'family'}."')";
	}
}

if ($config->{'subdomain'} == 1) {
	if ($config->{"wwwform"} == 1) {
		$dbselectionlists{"Subdomains"} = [$dbtables{'subdomains'}, "KEY, NAME||' ('||DESCRIPTION||')' VALUE", "NAME IS NOT NULL"];
	} else {
		$dbjoin .= " AND vn.name_subdomain_key IN (SELECT name_subdomain_key FROM ".$dbtables{'subdomains'}." WHERE name = '".$config->{'subdomain'}."'";
	}
}

if ($config->{'facility'} == 1) {
	if ($config->{"wwwform"} == 1) {
		$dbselectionlists{"Facilities"} = [$dbtables{'facilities'}, "KEY, NAME||' ('||PART_FACILITY||')' VALUE", "NAME IS NOT NULL"];
	} else {
		if (uc($config->{'facility'}) eq "MLS") {
			if ($config->{"extract"} == 1) {
				$dbjoin .= " AND vn.facility = 'P'";
			} else {
				$dbjoin .= " AND vn.name LIKE '%P'";
			}
		} elsif (uc($config->{'facility'}) eq "Future") {
			if ($config->{"extract"} == 1) {
				$dbjoin .= " AND vn.facility = 'F'";
			} else {
				$dbjoin .= " AND vn.name LIKE '%F'";
			}
		} else {
			if ($config->{"extract"} == 1) {
				$dbjoin .= " AND vn.facility = ' '";
			} else {
				$dbjoin .= " AND (vn.name NOT LIKE '%F' OR vn.name NOT LIKE '%F')";
			}
		}
	}
}

if (! $dborder{$config->{'sort'}}) {
	$config->{'sort'} = "name";
}
print "Sourcing from '$dbobject'\n" if ($config->{"Verbose"});
print "Selecting with '".join(",", @columns)."'\n" if ($config->{"Verbose"});
print "Filtering with '$dbjoin'\n" if ($config->{"Verbose"});

print "Output formatted as ".$config->{'output'}." and sorted by ".$config->{"sort"}."\n" if ($config->{"verbose"});

my $handle = PgDB::login($config);
delete ($config->{'passwd'});

if (defined $config->{'wwwform'}) {
	my $retform = "\n<!-- formbegin from bdns_param -->";
	$retform .= "\n<table class=\"bdns\" id=\"bdns_lookup_form\">";
	$retform .= "\n\t<input type=\"hidden\" name=\"table\" value=\"bdns_lookup\" />";
	$retform .= "\n\t<tr>\n\t\t<th class=\"bdns\" id=\"bdns_lookup_form.Name\">Name</th>\n\t\t<td class=\"bdns\" id=\"bdns_lookup_value.Name\"><input type=\"text\" id=\"bdns_lookup_value.name\" name=\"name\"></td>\n\t</th>";
	$retform .= "\n\t<tr>\n\t\t<th class=\"bdns\" id=\"bdns_lookup_form.Key\">Key</th>\n\t\t<td class=\"bdns\" id=\"bdns_lookup_value.Key\"><input type=\"text\" id=\"bdns_lookup_value.name_key\" name=\"name_key\"></td>\n\t</th>";
	foreach my $selopt (keys %dbselectionlists) {
		$retform .= "\n\t<tr>\n\t\t<th class=\"bdns\" id=\"bdns_lookup_form.".lc($selopt)."\">$selopt</th>\n\t\t<td class=\"bdns\" id=\"bdns_lookup_form.".lc($selopt)."\">\n\t\t\t<select name=\"".$selopt."\" id=\"bdns_lookup_form.".$selopt."\">";
		my $selresult = PgDB::sel($dbselectionlists{$selopt}[0], $dbselectionlists{$selopt}[1], $dbselectionlists{$selopt}[2]);
		if (defined $selresult) {
			#print Dumper($selresult);
			my $selidx = 0;
			foreach my $selrow (@$selresult) {
				$retform .= "\n\t\t\t\t<option value=\"".$selrow->{'KEY'}."\" id=\"bdns_lookup_form.".$selopt.".$selidx\">".$selrow->{'VALUE'}."</option>";
				$selidx++;
			}
		}
		$retform .= "\n\t\t\t</select>\n\t\t</td>\n\t</tr>";
	}
	# routine for facility, family
	$retform .= "\n</table>";
	$retform .= "\n<!-- formend from bdns_lookup -->\n";
	print $retform;
	exit 0;
}

Options::print_out("Connected as ".$config->{'user'}."@".$config->{'dbase'}."\n") if $config->{"Verbose"};

# counter for rows
my $indexed = 0;
# getting the aliased colstring for select
my $colstr = PgDB::col_aliases(\@columns, \@head);
# calculation linelength
my $linelength = 80;

print &getHeader();

#main part
foreach my $devname (@names) {
	$indexed ++;
        Options::print_out("\n>bdns_lookup Routine for ".$devname."\n") if not $config->{'silent'};
	my $where = "vn.NAME LIKE '$devname'";
	if (length($dbjoin) > 0) {
		$where .= " AND ".$dbjoin;
	}
	$where .= " ORDER BY ".$dborder{$config->{"sort"}};

        Options::print_out("\n>bdns_lookup Call PgDB::sel('".$dbobject."', '".$colstr."', '".$where."')") if $config->{"Verbose"};

	my $result = PgDB::sel($dbobject, $colstr, $where);

	Options::print_out("\n>bdns_lookup Result of statement has ".$#$result." entries.") if ($config->{'verbose'});

	my $out;
	foreach my $row (@$result) {
		$indexed++;
                Options::print_out("\n>bdns_lookup Row ".$indexed.": (".$row.")") if ($config->{'verbose'});
		if ($config->{"index"}) {
			printf ("%u", $indexed);
		}
		if ($config->{'output'} eq 'table') {
# table
			print "|".join(" |", map(sprintf("%".$colmax."s",$row->{$_}), @head))." |";
			print "\n";
# htmltable
		} elsif ($config->{'output'} eq 'htmltable') {
			print "\n\t".sprintf("<tr id=\"%u\">", $indexed);
			print "\n\t\t".join("\n\t\t", map(sprintf("<td class=\"bdns\" id=\"bdns_lookup_result.$_$indexed\">%s</td>", $row->{$_}), @head));
			print "\n\t".sprintf("</tr>");
# csvtable
		} elsif ($config->{'output'} eq 'csvtable') {
			print "\n".join(",",map(sprintf("\"%s\"",$row->{$_}), @head)).",";
# set
		} elsif ($config->{'output'} eq 'set') {
			print &printLine("=")."\n";
			if ($config->{'index'}) {
				print &printLine();
				print sprintf(" %12s: %s", "#", $indexed);
			}
			print join("\n",map(sprintf("%".$colmax."s: \"%s\"",$_,$row->{$_}), @head));
			print "\n";
# xmlset
		} elsif ($config->{'output'} eq 'htmlset') {
			print join("", map(sprintf("\n\t<tr class=\"bdns\" id=\"bdns_lookup_result.$_$indexed\"><th class=\"bdns\" align=\"right\" id=\"bdns_lookup_result.$_$indexed\">%s</th><td class=\"bdns\" id=\"bdns_lookup_result.$_$indexed\">%s</td></tr>", $_, $row->{$_}), @head));
			print "\n\t<tr class=\"bdns\" colspan=\"2\" id=\"bdns_lookup_result.separator\"><td class=\"bdns\" id=\"bdns_lookup_result.separator$indexed\"><hr /></td></tr>\n";
		} elsif ($config->{'output'} eq 'xmlset') {
			print "\n\t".sprintf("<entry index=\"%u\">", $indexed);
			print "\n\t\t".join("\n\t\t", map(sprintf("<%s>%s</%s>", lc($_), $row->{$_}, lc($_)), @head));
			print "\n\t".sprintf("</entry>");
# list
		} elsif ($config->{'output'} eq 'dump') {
			print "\n\t{".join(", ", map(sprintf("\'%s\'=>\'%s\'",$_, $row->{$_}), @head))."},";
# dump
		} else {
# list oputput or unknown
			print "\n".join("\t", map(sprintf("%s", $row->{$_}), @head));
		}
	}
}

print &getFooter($indexed);

# build header if not forbidden
sub getHeader {
	my $ret = "";
	if (! $config->{"outputbody"}) {
		if ($config->{'output'} eq 'table') {
			$linelength = ($colmax+2)*@columns+1;
			$ret .=  &printLine();
			if ($config->{'index'}) {
				$ret .=  sprintf(" %12s ", "#");
				$linelength += 12;
			}
			$ret .=  "\n|".join("|",map(sprintf("%".$colmax."s ",$_), @head))."|";
			$ret .=  "\n".&printLine()."\n";
		} elsif ($config->{'output'} eq 'htmltable') {
			print "\n<table class=\"bdns\">\n\t<tr>";
			if ($config->{'index'}) {
				print "\n\t<th>#</th>";
			}
			$ret .=   "\n\t".join("\n\t",map(sprintf("<th class=\"bdns\">%".$colmax."s</th>",$_), @head));
			print "\n\t</tr>";
		} elsif ($config->{'output'} eq 'csvtable') {
			if ($config->{'index'}) {
				$ret .=  sprintf( "#");
			}
			$ret .=  join(",",map(sprintf("\"%s\"",$_),@head)).",";
		}  elsif ($config->{'output'} eq 'set') {
			print &printLine()."\n";
		} elsif ($config->{'output'} eq 'htmlset') {
			print "\n<table class=\"bdns\">";
		} elsif ($config->{'output'} eq 'xmlset') {
			$ret .=  "<?xml version=\"1.0\"?>\n<bdns>";
		} elsif ($config->{'output'} eq 'dump') {
			$ret = "\@BDNS = ("
		} else {
			print join("\t", map(sprintf("%s", $_), @head));
		}
	};
	return $ret;
}

sub getFooter {
	my $rowindex = shift;
	my $ret = "";
	if (! $config->{'outputbody'}) {
		if ($config->{'output'} eq "table") {
			$linelength = ($colmax+2)*@columns+1;
			print &printLine();
			$ret .= "\n $rowindex Entries found";
		} elsif ($config->{'output'} eq "htmltable") {
			$ret .= "</table>";
		} elsif ($config->{'output'} eq "set") {
			$ret .= "\n";
			print &printLine();
			$ret .= "\n $rowindex Entries found";
		} elsif ($config->{'output'} eq "htmlset") {
			$ret .= "</table>";
		}
	}
	if ($config->{'output'} eq "xmlset") {
		$ret .= "\n</bdns>";
	} elsif ($config->{'output'} eq "dump") {
		$ret .= "\n);"
	}
	$ret .= "\n";
}

sub printLine {
	my $printchar = shift;
	my $ret = "";
	if (length($printchar) != 1) {
		$printchar = "-";
	}
	for (my $index = 0; $index < $linelength; $index++) {
		$ret .= "-";
	}
	return $ret;
}

exit;

__END__

=head1 NAME

bdns_lookup.pl - a Perl programm for querying the database for device names

=head2 INTRODUCTION

This program uses DBI for accessing the database. The Modules u needed to install:

 * FindBin
 * DBI
 * Options
 * PgDB
 * Data::Dumper;

The results can be presented different as formats and content.
In the following overview the most options are described.

=head2 SYNTAX

To call thte syntax the following short syntax is preferred:

	usage: bdns_lookup.pl [bdfFghilLnuopsStTvwx] names

Please suggest to configure the packages and have may be a look to your
PERL5LIB environment variable, that there is the path to the packages
is correctly set.

=head2 ACCESS

	-h, --help		display this help

	-v, --verbose		print verbose messages

	-V, --Verbose		print a lot more informations

	-l, --log[=STRING]	print messages to file instead of stdout

	-n, --not		do not perform any actual work

	-d, --dbase=STRING	Database instance (e.g. devices)

	-u, --user=STRING	User name for database access

	-p, --passwd=STRING	Password, not shown in TTY

	-f, --force		use force query with the default database account,

				ignoring user and password options

=head2 OUTPUT/FORMAT

	-o, --output=STRING		output format as a selection of
	
		* list - textual list of names,
		* table - ascii table,
		* set - ascii sets,
		* csvtable - csvtable,
		* htmltable - htmlbased table,
		* htmlset - separated html listentries,
		* xmlset - simpleformatted xml text
		* dump - perl dump

	-b, --outputbody		removing to output header

	-i, --outputindex		insert indexcount to output, formerly known as number of line

	-w, --wwwform			returns the formular for webrequests

	-x, --extract			concat the extracted name parts in to different columns,

								shows the complete partitioning splitted in the parsed parts

	-t, --description		concat the textual descriptions are given to all name parts

=head2 ORDERING AND SORTING

	-s, --sort=STRING			sort options supported:
		* namerevname (default),
		* key/revkey,
		* family (only if -x option is set),
		* domain/revdomain (only if -x option is set),

	-S, --revertsort			revert/desc sort of given sort order

	-F, --facility=STRING		filter facility, like  bii, mls, fel

	-T, --family=STRING			type of device, better the family

	-L, --subdomain=STRING		location of the device or better the subdomain

=head1 AUTHOR

Victoria Laux,  victoria.laux@helmholtz-berlin.de

=cut
