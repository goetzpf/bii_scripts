eval 'exec perl -S $0 ${1+"$@"}' # -*- Mode: perl -*-
  if 0;

use strict;
use DBI;
use BDNS;
use Options;
use ODB;

Options::register(
  ["dbase",  "d", "=s", "database instance (e.g. bii_par)", "database", $ENV{'ORACLE_SID'}],
  ["user",   "u", "=s", "user name",                        "user",     $ENV{'USER'}],
  ["passwd", "p", "=s", "password",                         "password", "", 1],
);

my $usage = "set terminal_server and optionally port to connect to console of an ioc
usage: set_ioc_tsrv [options] ioc_name tsrv_name [port]
options:
";

my $config = Options::parse($usage);

$usage = $usage . $Options::help;

die $usage if not $config or $config->{"help"};

my ($ioc_name, $tsrv_name, $port) = @ARGV;

die $usage if not (defined $ioc_name and defined $tsrv_name);

my $handle = ODB::login($config);

Options::print_out("connected as ".$config->{"user"}."@".$config->{"dbase"}."\n");

my $sql_set_port = "";

$sql_set_port = ",
  port = $port" if defined $port;

my $sql = "
update p_ioc set
  terminal_server_key = (
    select terminal_server_key
    from p_terminal_server
    where name_key in (
      select key
      from names
      where name = upper('$tsrv_name')))
  $sql_set_port
where name_key in (
  select key from names where name = upper('$ioc_name'))";

print "$sql\n" if $config->{"verbose"};

$handle->do($sql);
$handle->rollback if $config->{"not"};
