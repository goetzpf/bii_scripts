package PgDB;

# This software is copyrighted by the
# Helmholtz-Zentrum Berlin fuer Materialien und Energie GmbH (HZB),
# Berlin, Germany.
# The following terms apply to all files associated with the software.
# 
# HZB hereby grants permission to use, copy and modify this
# software and its documentation for non-commercial, educational or
# research purposes provided that existing copyright notices are
# retained in all copies.
# 
# The receiver of the software provides HZB with all enhancements, 
# including complete translations, made by the receiver.
# 
# IN NO EVENT SHALL HZB BE LIABLE TO ANY PARTY FOR DIRECT, INDIRECT,
# SPECIAL, INCIDENTAL OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE
# OF THIS SOFTWARE, ITS DOCUMENTATION OR ANY DERIVATIVES THEREOF, EVEN 
# IF HZB HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
# 
# HZB SPECIFICALLY DISCLAIMS ANY WARRANTIES, INCLUDING, BUT NOT LIMITED
# TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
# PURPOSE, AND NON-INFRINGEMENT. THIS SOFTWARE IS PROVIDED ON AN "AS IS"
# BASIS, AND HZB HAS NO OBLIGATION TO PROVIDE MAINTENANCE, SUPPORT,
# UPDATES, ENHANCEMENTS OR MODIFICATIONS.


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

  $dbh = DBI->connect("DBI::Pg:".$config->{"dbase"}, $config->{"user"}, $config->{"passwd"},
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
 $dbh->trace(2, "/tmp/PgDB-".$ENV{"USER"}.".log");
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
# silent - lessoutput/debug
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

PgDB - a Perl module for accessing database via DBI.
Means easier handling of the DBI routines via this layer.

=head1 SYNOPSIS

  use PgDB;

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

  $dbhandle = PgDB::login(%config{
  			"dbase"=>ORACLE_SID,
  			"user"=>dbuser,
  			"passwd"=>dbuserpasswd},
  			);

This function connect to a Oracle database instance and give back the
database handle.

=item *

B<interview>

  PgDB::logoff();

This function disconnect fairly a Oracle database handle

=item *

B<interview>

  PgDB::END();

This function abort the database connection. No rollback!

=item *

B<interview>

  PgDB::debug();

This function sets trace level to 2 and wrote a logfile to /tmp including the verbose option.

=item *

B<interview>

  PgDB::verbose();

Set info output on.

=item *

B<interview>

  PgDB::silent();

Set debugging output off.

=item *

B<interview>

  $colstr = PgDB::col_aliases($@columns,
  	$@aliases);

Give the list of real selected columnnames and the aliases as
refernces of lists. Every column name will be expanded with
quoted aliases at the same list position.

=item *

B<interview>

  PgDB::ins($table,
  	%row{
  		columnname=>columnvalue,
  	...}
  	);

Insert a new row into the given table on the database handle
is connected. The hash contains the named list as name to
value association.

=item *

B<interview>

  PgDB::del($table,
  	$keycolumn,
  	@keys
  );

Delete one or more rows from table of the connected handle
where the keycolumn values in the keys list as select secures
the content more.

=item *

B<interview>

  PgDB::selone($result);

Returns the single dataset of a resultset.

=item *

B<interview>

  %resultset = PgDB::sel($table,
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

  %resultset = PgDB::new_row($table,
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
