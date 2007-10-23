eval 'exec perl -S $0 ${1+"$@"}' # -*- Mode: perl -*-
if 0;

#  This software is copyrighted by the BERLINER SPEICHERRING
#  GESELLSCHAFT FUER SYNCHROTRONSTRAHLUNG M.B.H., BERLIN, GERMANY.
#  The following terms apply to all files associated with the software.
#  
#  BESSY hereby grants permission to use, copy and modify this
#  software and its documentation for non-commercial, educational or
#  research purposes provided that existing copyright notices are
#  retained in all copies.
#  
#  The receiver of the software provides BESSY with all enhancements, 
#  including complete translations, made by the receiver.
#  
#  IN NO EVENT SHALL BESSY BE LIABLE TO ANY PARTY FOR DIRECT, INDIRECT,
#  SPECIAL, INCIDENTIAL OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE
#  OF THIS SOFTWARE, ITS DOCUMENTATION OR ANY DERIVATIVES THEREOF, EVEN 
#  IF BESSY HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#  
#  BESSY SPECIFICALLY DISCLAIMS ANY WARRANTIES, INCLUDING, BUT NOT LIMITED
#  TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
#  PURPOSE, AND NON-INFRINGEMENT. THIS SOFTWARE IS PROVIDED ON AN "AS IS"
#  BASIS, AND BESSY HAS NO OBLIGATION TO PROVIDE MAINTENANCE, SUPPORT,
#  UPDATES, ENHANCEMENTS OF MODIFICATIONS.


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
use ODB;
use Data::Dumper;

Options::register(
	['dbase',  				'd', 	'=s', "Database instance (e.g. devices)", "database", $ENV{'ORACLE_SID'}],
	['user',   					'u', 	'=s', "User name",  'user',     "anonymous"],
	['passwd', 				'p', 	'=s', "Password",   "password", "", 1],
	['force', 					'f',   	'', 	"use force query with the default database account"],
	['verbose',  				'v',   '', 	"print a lot more informations"],
	['output', 					'o', 	'=s', "output format as a selection of list, table, htmltable, csvtable, set, htmlset, xmlset or dump"],
	['outputbody',			'b', 	'', 	"removing to output header"],
	['outputindex',			'i', 	'', 	"insert indexcount to output"],
	['extract', 				'x', 	'', 	"concat the extracted name parts"],
	['description',			't', 	'', 	"concat the textual descriptions"],
	['groups', 				'g', 	'', 	"concat the grouping names"],
	['lattice', 					'l', 	'', 	"concat the lattice values"],
	['sort', 						's', 	'=s', "supported: key/revkey, \n\tnamerevname (default), \n\tfamily (only if -x option is set), \n\tdomain/revdomain (only if -x option is set), \n\tgroups(only if -g option is set)\n\tlattice sorted automatically"],
	['revertsort', 			'S', 	'', 	"revert/desc sort, without lattice order"],
	['facility', 					'F', 	'=s', "filter facility, like  bii, mls, fel"],
	['family', 					'T', 	'=s', "type of device, better the family"],
	['subdomain', 			'L', 	'=s', "location of the device or better the subdomain"],
);

my $usage = "parse bessy device name service for the given list of names or patterns (% as any and more, ? one unspecified character)
usage: bdns_lookup [options] names...
options:
";

my $config = Options::parse($usage, 1);

$usage = $usage . $Options::help;

die $usage if $#ARGV< 0;

ODB::verbose() == 1 if $config->{'verbose'};

if (! defined $config->{'output'} or ! $config->{'output'} =~ /(table|csvtable|htmltable|list|set|htmlset|xmlset|dump)/) {
	$config->{'output'} = 'list';
}

die $usage if not $config or $config->{"help"};

if ($config->{"force"}) {
	$config->{'dbase'} = "devices";
	$config->{'user'} = "anonymous";
	$config->{'passwd'} = "bessyguest";
	if (lc ($config->{"dbase"}) eq "mirror") {
		$config->{"user"} = "guest"
	}
}

my @names = @ARGV;

die $usage if not @names;

Options::ask_out();

my $dbschema = "";
if ($config->{"dbase"} ne "mirror") {
	$dbschema = "DEVICE.";
}

# main object string, will be completed iprportionally of arguments
my $dbobject = $dbschema.'V_NAMES vn';
# array of the database columnnames
my @columns = ('vn.KEY', 'vn.NAME');
# array of the given names in the select statement
my @head = ('KEY', 'NAME');
# maybe the whereclause and teh sortorder
my $dbjoin = "vn.KEY > 0";
my %dborder = ();
if ($config->{'sort'}) {
	$config->{'sort'} = lc($config->{'sort'});
} else {
	$config->{'sort'} = "name";
}
$dborder{"key"} = "vn.KEY";
$dborder{"name"} = "vn.NAME";
$dborder{"revkey"} = "vn.KEY DESC";
$dborder{"revname"} = "vn.NAME DESC";

# columnwidth maximal
my $colmax = 12;

if (defined $config->{'extract'}) {
	push @columns, ('MEMBER','IND', 'SUBIND', 'FAMILY', 'COUNTER', 'SUBDOMAIN', 'DOMAIN', 'FACILITY');
	push @head, ('MEMBER','IND', 'SUBIND', 'FAMILY', 'COUNTER', 'SUBDOMAIN', 'DOMAIN', 'FACILITY');
	$dborder{"family"} = "FAMILY";
	$dborder{"domain"} = "FACILITY, DOMAIN, SUBSTR(SUBDOMAIN, 1, 1), TO_NUMBER(SUBSTR(SUBDOMAIN, 2))";
	$dborder{"revdomain"} = "FACILITY DESC, DOMAIN DESC, SUBSTR(SUBDOMAIN, 1, 1) DESC, TO_NUMBER(SUBSTR(SUBDOMAIN, 2)) DESC";
}

if (defined $config->{'description'}) {
	$dbobject .= ', '.$dbschema.'V_NAME_DESCRIPTIONS vnd';
	push @columns, ('DESCRIPTION');
	push @head, ('DESCRIPTION');
	$dbjoin .= " AND vn.key = vnd.key(+)";
}

if (defined $config->{'family'}) {
	$dbjoin .= " AND vn.family_key = device.pkg_bdns.get_family_key('".$config->{'family'}."')";
}

if (defined $config->{'subdomain'}) {
	$dbjoin .= " AND vn.subdomain_key = device.pkg_bdns.get_subdomain_key('".$config->{'subdomain'}."')";
}

if (defined $config->{'lattice'}) {
	$dbobject .= ', '.$dbschema.'V_LATTICE vl';
	push @columns, ('DS', 'LENGTH');
	push @head, ('DS', 'LENGTH');
	$dbjoin .= " AND vn.key = vl.key";
	$config->{'sort'} = "lattice";
	$dborder{"lattice"} = "TO_NUMBER(vl.DS)";
}

if (defined $config->{'facility'}) {
	if (uc($config->{'facility'}) eq "MLS") {
		if (defined $config->{"extract"}) {
			$dbjoin .= " AND vn.facility = 'P'";
		} else {
			$dbjoin .= " AND vn.name LIKE '%P'";
		}
	} elsif (uc($config->{'facility'}) eq "FEL") {
		if (defined $config->{"extract"}) {
			$dbjoin .= " AND vn.facility = 'F'";
		} else {
		$dbjoin .= " AND vn.name LIKE '%F'";
		}
	} else {
		if (defined $config->{"extract"}) {
			$dbjoin .= " AND vn.facility = ' '";
		} else {
			$dbjoin .= " AND (vn.name NOT LIKE '%F' OR vn.name NOT LIKE '%F')";
		}
	}
}

if (! $dborder{$config->{'sort'}}) {
	$config->{'sort'} = "name";
}

print "Output formatted as ".$config->{'output'}.." and sorted by ".$config->{"sort"}."\n" if ($config->{"verbose"});

my $handle = ODB::login($config);

delete ($config->{'passwd'});

Options::print_out("Connected as ".$config->{'user'}."@".$config->{'dbase'}."\n") if $config->{"verbose"};

print &getHeader();

# counter for rows
my $indexed = 0;
# getting the aliased colstring for select
my $colstr = ODB::col_aliases(\@columns, \@head);
# calculation linelength
my $linelength = 80;

#main part
foreach my $devname (@names) {
	$indexed ++;
	my $where = "vn.NAME like \'$devname\'";
	if (length($dbjoin) > 0) {
		$where .= " AND ".$dbjoin;
	}
	$where .= " ORDER BY ".$dborder{$config->{"sort"}};
	my $result = ODB::sel($dbobject, $colstr, $where);
	print "\nResult of statement has ".$#$result."entries." if ($config->{'verbose'});
	my $out;
	foreach my $row (@$result) {
		$indexed++;
		if ($config->{"index"}) {
			printf ("%u", $indexed);
		}
		if ($config->{'output'} eq 'table') {
# table
			print "|".join(" |", map(sprintf("%".$colmax."s",$row->{$_}), @head))." |";
			if ($config->{"groups"}) {
				print sprintf("%s: %s", "GROUPS", &getGroups($row->{"KEY"}));
			}
			print "\n";
# htmltable
		} elsif ($config->{'output'} eq 'htmltable') {
			print "\n\t".sprintf("<tr id=\"%u\">", $indexed);
			print "\n\t\t".join("\n\t\t", map(sprintf("<td class=\"bdns\">%s</td>", $row->{$_}), @head));
			if ($config->{'groups'}) {
				print "\n\t\t".sprintf("<td class=\"bdns\">%s</td>", &getGroups($row->{'vn.KEY'}));
			}
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
			if ($config->{'groups'}) {
				print "\n".sprintf("%".$colmax."s: %s", "GROUPS", &getGroups($row->{'KEY'}));
			}
			print "\n";
# xmlset
		} elsif ($config->{'output'} eq 'htmlset') {
			print join("", map(sprintf("\n\t<tr class=\"bdns\" id =\"$indexed\"><th class=\"bdns\">%s</th><td class=\"bdns\">%s</td></tr>", $_, $row->{$_}), @head));
			if ($config->{'groups'}) {
				print sprintf("\n\t<tr class=\"bdns\" id =\"$indexed\"><th class=\"bdns\">GROUPS</th><td class=\"bdns\">%s</td></tr>", &getGroups($row->{'vn.KEY'}));
			}
			print "\n\t<tr class=\"bdns\" colspan=\"2\"><td><hr /></td>\n";
		} elsif ($config->{'output'} eq 'xmlset') {
			print "\n\t".sprintf("<entry index=\"%u\">", $indexed);
			print "\n\t\t".join("\n\t\t", map(sprintf("<%s>%s</%s>", lc($_), $row->{$_}, lc($_)), @head));
			if ($config->{'groups'}) {
				print "\n\t\t".sprintf("<groups>%s</groups>", &getGroups($row->{'vn.KEY'}));
			}
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

sub getGroups {
	my $key = shift @_;
	my $gresult = ODB::sel($dbschema.'V_NAME_GROUPS vng', "GROUP_NAME||' ('||NAME_GROUP_KEY||')' GROUPS", "n.NAME_KEY =".$key);
	my $gindexer = 0;
	my $grouplist = "";
	foreach my $grow (@$gresult) {
		$gindexer++;
		if ($gindexer  > 1) {
			$grouplist .= ", ";
		}
		$grouplist .=  join("/", map(sprintf("%s",$grow->{$_}), ('GROUPS')));
	}
	return $grouplist;
}

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
			if ($config->{'groups'}) {
				$ret .=   sprintf(" %".$colmax."s ","GROUPS")."|";
			}
			$ret .=  "\n".&printLine()."\n";
		} elsif ($config->{'output'} eq 'htmltable') {
			print "\n<table class=\"bdns\">\n\t<tr>";
			if ($config->{'index'}) {
				print "\n\t<th>#</th>";
			}
			$ret .=   "\n\t".join("\n\t",map(sprintf("<th class=\"bdns\">%".$colmax."s</th>",$_), @head));
			if ($config->{'groups'}) {
				$ret .=   "<th class=\"bdns\">GROUPS</th>";
			}
			print "\n\t</tr>";
		} elsif ($config->{'output'} eq 'csvtable') {
			if ($config->{'index'}) {
				$ret .=  sprintf( "#");
			}
			$ret .=  join(",",map(sprintf("\"%s\"",$_),@head)).",";
			if ($config->{'groups'}) {
				$ret .=   ",".sprintf("%s","GROUPS");
			}
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
			$ret .= "\n\t</table>";
		} elsif ($config->{'output'} eq "set") {
			$ret .= "\n";
			print &printLine();
			$ret .= "\n $rowindex Entries found";
		} elsif ($config->{'output'} eq "htmlset") {
			$ret .= "\n\t</table>";
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
