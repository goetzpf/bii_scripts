package ODB;

# Copyright 2022 Helmholtz-Zentrum Berlin für Materialien und Energie GmbH
# <https://www.helmholtz-berlin.de>
#
# Author: Benjamin Franksen <Benjamin.Franksen@helmholtz-berlin.de>
# Contributions by:
#         Victoria Laux <victoria.laux@helmholtz-berlin.de>
#         Goetz Pfeiffer <Goetz.Pfeiffer@helmholtz-berlin.de>
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


require Exporter;

our @ISA = qw(Exporter);
our $VERSION = 1.00;

use DBI;
use Options;
use strict;

our $dbh;
my $config={'verbose'=>0};

#------------------------------------------------------------------------------
# login - connect
#------------------------------------------------------------------------------
sub login {
  $config = shift;

  if (ref($config) ne 'HASH')
    { die "error: \$config is not a hash or not set"; };

  return $dbh if defined $dbh;

  $dbh = DBI->connect("dbi:Oracle:".$config->{"dbase"}, $config->{"user"}, $config->{"passwd"},
    {RaiseError => 1, PrintError => 0, AutoCommit => 0, ShowErrorStatement => $config->{'verbose'}});
  return $dbh;
}

#------------------------------------------------------------------------------
# logoff - disconnect
#------------------------------------------------------------------------------
sub logoff {
  if (defined $dbh) {
    $dbh->rollback if $config->{"not"};
    $dbh->disconnect;
  }
}

#------------------------------------------------------------------------------
# debug - trace and debug into /tmp/
#------------------------------------------------------------------------------
sub debug {
 $dbh->trace(2, "/tmp/ODB-".$ENV{"USER"}.".log");
 verbose();
}

#------------------------------------------------------------------------------
# logoff - lessoutput/debug
#------------------------------------------------------------------------------
sub silent {
 $config->{'verbose'} = 0;
 $dbh->trace(0);
}

#------------------------------------------------------------------------------
# verbose - more output/debug
#------------------------------------------------------------------------------
sub verbose {
 $config->{'verbose'} = 1;
}

#------------------------------------------------------------------------------
# logoff - lessoutput/debug
#------------------------------------------------------------------------------
sub silent {
 $config->{'verbose'} = 0;
}

#------------------------------------------------------------------------------
# END - abort
#------------------------------------------------------------------------------
END {
  logoff;
}

#------------------------------------------------------------------------------
# ins - insert rows
#------------------------------------------------------------------------------
sub ins {
  my ($table, %row) = @_;
  my $sql = "insert into $table (".join(",",keys(%row)).") values (".join(",",map("'$_'", values(%row))).")";
  Options::print_out("$sql;\n") if $config->{"verbose"};
  $dbh->do($sql);
}

#------------------------------------------------------------------------------
# del - delete rows
#------------------------------------------------------------------------------
sub del {
  my ($table, $keycolumn, @keys) = @_;
  if (length($keycolumn) > 0) {
  	my $sql = "delete from $table where $keycolumn in (".join(",", @keys).")";
  	Options::print_out("$sql;\n") if $config->{"verbose"};
  	$dbh->do($sql);
  }
}

#------------------------------------------------------------------------------
# selone - select dataset
#------------------------------------------------------------------------------
sub col_aliases {
	my ($r_columns, $r_aliases) = shift;
	my $colstr = "*";
	if ($#$r_columns > 0) {
		$colstr = "";
		for (my $colindex = 0; $colindex <= $#$r_columns; $colindex++) {
			if (length($$r_aliases[$colindex]) > 0) {
				$colstr .= sprintf("%s \"%s\",", $$r_columns[$colindex], $$r_aliases[$colindex]) ;
			} else {
				$colstr .= $$r_columns[$colindex]."," ;
			}
		# erase empty aliases
		}
		$colstr = substr($colstr, 0, -1);
	}
	Options::print_out("columns=($colstr);\n") if $config->{"verbose"};
	return $colstr;
}

#------------------------------------------------------------------------------
# sel_one - select dataset
#------------------------------------------------------------------------------
sub sel_one {
  my $result = sel(@_);
  if (@$result == 1) {
    return $result->[0];
  }
  else {
    return undef;
  }
}

#------------------------------------------------------------------------------
# sel - select rows
#------------------------------------------------------------------------------
sub sel {
  my ($table, $col_names, $cond, @bind_values) = @_;
  $cond = " where $cond" if $cond;
  my $sql = "select $col_names from $table$cond";
  my @rows;

  Options::print_out("$sql;\n") if $config->{"verbose"};

# in newer versions of DBI selectall_hashref has different semantics
# so we emulate it here
# my $rows = $dbh->selectall_hashref($sql);

  my $sth = $dbh->prepare($sql);
  $sth->execute(@bind_values);

  while (my $hash_ref = $sth->fetchrow_hashref) {
    push @rows, $hash_ref;
  }

  if ($config->{"verbose"}) {
    foreach my $row (@rows) {
      Options::print_out(join(",",map("$_='$row->{$_}'", keys %$row))."\n");
    }
  }
  return \@rows;
}

#------------------------------------------------------------------------------
# new_row - insert new row
#------------------------------------------------------------------------------
sub new_row {
  my ($table, $pk, %rest) = @_;
  ins($table, %rest);
  return sel_one($table, "*", "$pk=$rest{$pk}");
}

1;

__END__
# Below is the short of documentation of the module.

=head1 NAME

ODB - a Perl module for accessing database via DBI.
Means easier handling of the DBI routines via this layer.

=head1 SYNOPSIS

  use ODB;

=head1 DESCRIPTION

=head2 Preface

This module contains functions that are used to connect, disconnect,
select, insert and delete rows from database.
Note that HZB has the copyright on this software. It may not be used
or copied without permission from HZB.

=head2 Implemented Functions:

=over 4

=item *

B<interview>

  $dbhandle = ODB::login(%config{
  			"dbase"=>ORACLE_SID,
  			"user"=>dbuser,
  			"passwd"=>dbuserpasswd},
  			);

This function connect to a Oracle database instance and give back the
database handle.

=item *

B<interview>

  ODB::logoff();

This function disconnect fairly a Oracle database handle

=item *

B<interview>

  ODB::END();

This function abort the database connection. No rollback!

=item *

B<interview>

  ODB::debug();

This function sets trace level to 2 and wrote a logfile to /tmp including the verbose option.

=item *

B<interview>

  ODB::verbose();

Set info output on.

=item *

B<interview>

  ODB::silent();

Set debugging output off.

=item *

B<interview>

  $colstr = ODB::col_aliases($@columns,
  	$@aliases);

Give the list of real selected columnnames and the aliases as
refernces of lists. Every column name will be expanded with
quoted aliases at the same list position.

=item *

B<interview>

  ODB::ins($table,
  	%row{
  		columnname=>columnvalue,
  	...}
  	);

Insert a new row into the given table on the database handle
is connected. The hash contains the named list as name to
value association.

=item *

B<interview>

  ODB::del($table,
  	$keycolumn,
  	@keys
  );

Delete one or more rows from table of the connected handle
where the keycolumn values in the keys list as select secures
the content more.

=item *

B<interview>

  ODB::selone($result);

Returns the single dataset of a resultset.

=item *

B<interview>

  %resultset = ODB::sel($table,
  	$col_names,
  	$cond,
  	@bind_values
  );

Executing the generated select statement on the given handle by
using the $table as the object clause, columnnames for detecting
the returned tablecolumns, the filtering conditions and the binded
variables. In addition is a little buggy feature inside. The resultset
is returned do NOT return alised column table prefixes such as
"tbl_test.firstsign". Only "firstsign" will be set as hashkey! Use for
aliasing the function col_aliases.
The resultset is returned shows the content like that:

%resultset = (
	{ row1col1=>row1colval1, row1col2=>row1colval2 ...},
	{ row2col1=>row2colval1, row1col2=>row2colval2 ...},
	... )

=item *

B<interview>

  %resultset = ODB::new_row($table,
  	$pk,
  	%res,
  );

If you insert a new row you have to give the tablename the
primary key column and the content of the new row.
This function trusts to have a simple trigger for the given
table generated. For example:

  create trigger tbl_name_key_before_insert
  on tbl_name before insert
  for each row
  begin
    if :new.keycolumn is null or :new.keycolumn <= 0
    then
      select tbl_name_seq.nextval into :new.keycolumn from dual;
    end if;
  end;
  /
