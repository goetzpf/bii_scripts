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
  ["dbase",  			"d", "=s", 	"Database instance (e.g. bii_par)", "database", $ENV{'ORACLE_SID'}],
  ["user",   			"u", "=s", 	"User name", "user",     $ENV{'USER'}],
  ["passwd", 		"p", "=s", 	"Password", "password", "", 1],
  ["file",   				"f", "=s", 	"Read (additional) names from a file"],
  ["dump",   			"d", "", 		"Dont do database actions"],
);

my $usage = "import a list of names into the bessy device name service
usage: bdns_import [options] names...
options:
";

my $config = Options::parse($usage, 1);

$usage = $usage . $Options::help;

my @names = @ARGV;

if (exists $config->{"file"}) {
	open INPUT, $config->{"file"} or die "Cannot open file $config->{'file'}";
	push @names, <INPUT>;
	close INPUT
}

die $usage if not $config or $config->{"help"} or not @names;

my %allnames;
warn;
foreach my $devname (@names) {
	my @parts = BDNS::parse($devname);
	die "Error: $devname is not a valid device name!\n" if (not defined @parts);
	if (! defined @parts[2] or @parts[2] eq "" ) {
		@parts[2]  = "NULL";
		@parts[3]  = "NULL";
	}
	if (! defined $parts[3] or $parts[3] eq "" ) {
		@parts[3]  = "NULL";
	}
	if (! defined $parts[5] or $parts[5] eq "" ) {
		@parts[5]  = "NULL";
	}
	$allnames{$devname} = {
		"PART_NAME" => @parts[0],
		"PART_INDEX"  => @parts[2],
		"PART_SUBINDEX" => @parts[3],
		"FAMILY_KEY" => "device.pkg_bdns.get_family_key('".@parts[4]."')",
		"PART_COUNTER" => @parts[5],
		"SUBDOMAIN_KEY" => "device.pkg_bdns.get_subdomain_key('".@parts[6]."')",
	};
}

warn Dumper(%allnames);
my $config = Options::ask_out();

my $handle = ODB::login($config);
Options::print_out("Connected as ".$config->{"user"}."@".$config->{"dbase"}."\n");

foreach my $devname (@names) {
	my $sql = "insert into p_name "
		. "(PART_NAME, PART_INDEX, PART_SUBINDEX, FAMILY_KEY, PART_COUNTER, SUBDOMAIN_KEY) "
		. "values "
		. "(\'".$allnames{"PART_NAME"}."\', \'".$allnames{"PART_INDEX"}."\', \'".$allnames{"PART_SUBINDEX"}."\', ".$allnames{"FAMILY_KEY"}.", \'".$allnames{"PART_COUNTER"}."\', ".$allnames{"SUBDOMAIN_KEY"};
	print "$sql\n" if $config->{"verbose"};
	$handle->do($sql) if (! $config->{"dump"});
	$handle->rollback if $config->{"not"};
}

exit;