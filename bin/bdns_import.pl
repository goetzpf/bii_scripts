eval 'exec perl -S $0 ${1+"$@"}' # -*- Mode: perl -*-
  if 0;

use FindBin;

# enable this if you want to search modules like dbitable.pm
# relative to the location of THIS script:
# ------------------------------------------------------------
# use lib "$FindBin::RealBin/../lib/perl";

use strict;
use DBI;
use BDNS;
use Options;
use ODB;
use Data::Dumper;

Options::register(
  ["dbase",  			"d", "=s",	"Database instance (e.g. bii_par)", "database", $ENV{'ORACLE_SID'}],
  ["user",   			"u", "=s",	"User name", "user",     $ENV{'USER'}],
  ["passwd", 		"p", "=s",	"Password", "password", "", 1],
  ["file",   				"f", "=s", "Read (additional) names from a file"],
  ["dump",   			"o", "", 	"Dont do database actions, output commands"],
  ["separator",  	"s", "=s",	"Otherfiledescriptior than a whitespace as a string"],
  ["description",  	"d", "=i", 	"Description in file on column-number to name"],
  ["primarykey",  	"k", "=i", 	"Predefiined primary key in file on column-number to name"],
  ["commit",  		"c", "", 	"Wait at the end of inserting the names for the commit input"],
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
	if ($config->{"primarykey"} < 0) {
		delete ($config->{"primarykey"});
		print "Primary key will be ignored and given automatically.\n"
	}
	while (my $line = <INPUT>) {
		chop($line);
		if (length($line)>3) {
			my @lineparts = split ($config->{"separator"}, $line);
			push @names, @lineparts[0];
			if ($config->{"decription"} >= 0) {
				push @descs, $lineparts[$config->{"description"}];
			}
			if ($config->{"primarykey"} >= 0) {
				if ($lineparts[$config->{"primarykey"}] > 0) {
					push @pkeys, $lineparts[$config->{"primarykey"}];
				} else {
					push @pkeys, "NULL";
				}
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
	die "Error: $devname is not a valid device name!\n" if (not defined @parts);
	if (! defined @parts[2] or @parts[2] eq "" ) {
		@parts[2]  = "NULL";
		@parts[3]  = "NULL";
	} else {
		@parts[2]  = "'".@parts[2]."'";
	}
	if (! defined $parts[3] or $parts[3] eq "" ) {
		@parts[3]  = "NULL";
	} else {
		@parts[3]  = "'".@parts[3]."'";
	}
	if (! defined $parts[5] or $parts[5] eq "" ) {
		@parts[5]  = "NULL";
	} else {
		@parts[5]  = "'".@parts[5]."'";
	}
	$allnames{$devname} = {
		"PART_NAME" => "'".@parts[0]."'",
		"PART_INDEX"  => @parts[2],
		"PART_SUBINDEX" => @parts[3],
		"FAMILY_KEY" => "device.pkg_bdns.get_family_key('".@parts[4]."')",
		"PART_COUNTER" => @parts[5],
		"SUBDOMAIN_KEY" => "device.pkg_bdns.get_subdomain_key('".@parts[6]."')",
	};
	if ($config->{"description"} >= 0) {
		$allnames{$devname}{"DESCRIPTION"} = @descs[$counter];
	}
	if ($config->{"primarykey"} >= 0) {
		if (@pkeys[$counter] > 0) {
			$allnames{$devname}{"NAME_KEY"} = @pkeys[$counter];
		} else {
			$allnames{$devname}{"NAME_KEY"} = "NULL";
		}
	}
	$counter++;
}

my $handle;

if (! $config->{"dump"}) {
	Options::ask_out($config);
	$handle = ODB::login($config);
	Options::print_out("Connected as ".$config->{"user"}."@".$config->{"dbase"}."\n");
}

foreach my $devname (@names) {
	my $sql1 = "INSERT INTO device.tbl_name (",
	my $sql2 = " values (";
	my $verbose = "NAME:$devname " ;
	if ($config->{"primarykey"}) {
		$sql1 .= "name_key, ";
		$sql2 .= $allnames{$devname}{"NAME_KEY"}.", ";
		$verbose .= " KEY: ".$allnames{$devname}{"NAME_KEY"};
	}
	$sql1 .= "part_name, part_index, part_subindex, family_key, part_counter, subdomain_key";
	$sql2 .= $allnames{$devname}{"PART_NAME"}.", ".$allnames{$devname}{"PART_INDEX"}.", ".$allnames{$devname}{"PART_SUBINDEX"}.", "
		. $allnames{$devname}{"FAMILY_KEY"}.", ".$allnames{$devname}{"PART_COUNTER"}.", ".$allnames{$devname}{"SUBDOMAIN_KEY"};
	if ($config->{"primarykey"}) {
		$sql1 .= ", description";
		$sql2 .= ", '".$allnames{$devname}{"DESCRIPTION"}."'";
		$verbose .= " DESCRIPTION:".$allnames{$devname}{"DESCRIPTION"};
	}
	$sql1 .= ")";
	$sql2 .= ")";
	print $verbose."\n" if ($config->{"verbose"});
	if (! $config->{"dump"}) {
		$handle->do($sql1.$sql2);
	} else {
		print "$sql1 $sql2;\n";
	}
	$handle->rollback if $config->{"not"};
}

exit;
