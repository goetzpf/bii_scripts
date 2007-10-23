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
#  SPECIAL, INCIDENTAL OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE
#  OF THIS SOFTWARE, ITS DOCUMENTATION OR ANY DERIVATIVES THEREOF, EVEN 
#  IF BESSY HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#  
#  BESSY SPECIFICALLY DISCLAIMS ANY WARRANTIES, INCLUDING, BUT NOT LIMITED
#  TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
#  PURPOSE, AND NON-INFRINGEMENT. THIS SOFTWARE IS PROVIDED ON AN "AS IS"
#  BASIS, AND BESSY HAS NO OBLIGATION TO PROVIDE MAINTENANCE, SUPPORT,
#  UPDATES, ENHANCEMENTS OR MODIFICATIONS.


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
