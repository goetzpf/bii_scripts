eval 'exec perl -S $0 ${1+"$@"}' # -*- Mode: perl -*-
  if 0;

use strict;
use DBI;
use BDNS;
use Options;
use ODB;

Options::register(
  ["file", "f", "=s", "Read (additional) names from a file"]
);

my $usage = "import a list of names into the bessy device name service
usage: bdns_import [options] names...
options:
";

my $config = Options::parse($usage);

$usage = $usage . $Options::help;

die $usage if not $config or $config->{"help"};

my @names = @ARGV;

my $handle = ODB::login($config);

Options::print_out("connected as ".$config->{"user"}."@".$config->{"dbase"}."\n");

my $subdomain_keys = get_subdomains($handle);
my $family_keys = get_families($handle);

if (exists $config->{"file"}) {
  open INPUT, $config->{"file"} or die "Cannot open file $config->{'file'}";
  push @names, <INPUT>;
  close INPUT
}

die $usage if not @names;

foreach my $devname (@names) {
  my ($done, $member, $allindex, $index, $subindex, $family, $counter, $allsubdomain,
    $subdomain, $subdompre, $subdompost, $domain) = BDNS::parse($devname);

  if (not $done) {
    warn "Warning: $devname is not a valid device name!\n";
    next;
  };

  $allindex = "'$allindex'";
  $member = "'$member'";

  $counter = "NULL" if "$counter" eq "";
  $allindex = "NULL" if "$allindex" eq "''";

  my $sql = "insert into p_name "
    . "(NAME_KEY, PART_NAME, PART_INDEX, FAMILY_KEY, PART_COUNTER, SUBDOMAIN_KEY) "
    . "values "
    . "(s_name.nextval, $member, $allindex, $family_keys->{$family},"
    . " $counter, $subdomain_keys->{$allsubdomain})";

  print "$sql\n" if $config->{"verbose"};
  $handle->do($sql);
  $handle->rollback if $config->{"not"};
}
exit;

sub get_subdomains {
  my $result = ODB::sel("SUBDOMAINS", "KEY, NAME||POSTFIX||DOMAIN as VALUE");
#   my $handle = shift;
#   my $result = $handle->selectall_hashref("select key, name||postfix||domain as value from subdomains");
  my $keys;
  foreach my $row (@$result) {
    $keys->{$row->{VALUE}} = $row->{KEY};
  }
  if ($config->{"verbose"}) {
    print "subdomains: " . join(",", map("$_=\"$keys->{$_}\"", keys %$keys)) . "\n";
  }
  return $keys;
}

sub get_families {
  my $handle = shift;
  my $result = $handle->selectall_hashref("select family_key as key, part_family as value from p_family");
  my $keys;
  foreach my $row (@$result) {
    $keys->{$row->{VALUE}} = $row->{KEY};
  }
  #print "families: " . join(",", map("$_=\"$family_keys->{$_}\"", keys %$family_keys)) . "\n";
  return $keys;
}
