eval 'exec perl -S $0 ${1+"$@"}' # -*- Mode: perl -*-
  if 0;

# Copyright 2015 Helmholtz-Zentrum Berlin für Materialien und Energie GmbH
# <https://www.helmholtz-berlin.de>
#
# Author: Benjamin Franksen <Benjamin.Franksen@helmholtz-berlin.de>
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
