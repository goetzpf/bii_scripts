package ODB;

require Exporter;

our @ISA = qw(Exporter);
our $VERSION = 1.00;

use DBI;
use Options;
use strict;

our $dbh;
my $config;

sub login {
  $config = shift;
  return $dbh if defined $dbh;
  $dbh = DBI->connect("dbi:Oracle:".$config->{"dbase"}, $config->{"user"}, $config->{"passwd"},
    {RaiseError => 1, PrintError => 0, AutoCommit => 0, ShowErrorStatement => 1});
  return $dbh;
}

sub logoff {
  if (defined $dbh) {
    $dbh->rollback if $config->{"not"};
    $dbh->disconnect;
  }
}

END {
  logoff;
}

sub ins {
  my ($table, %row) = @_;
  my $sql = "insert into $table (".join(",",keys(%row)).") values (".join(",",map("'$_'", values(%row))).")";
  Options::print_out("$sql;\n") if $config->{"verbose"};
  $dbh->do($sql);
}

sub sel_one {
  my $result = sel(@_);
  if (@$result == 1) {
    return $result->[0];
  }
  else {
    return undef;
  }
}

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

sub new_key {
  my ($table, $pk) = @_;
  $table =~tr/[a-z]/[A-Z]/;
  my $seq = $table;
  $seq =~ s/^P_/S_/;
  my $new_key = sel_one("dual", "$seq.nextval as new_key")->{NEW_KEY};
  return $new_key;
}

sub new_row {
  my ($table, $pk, %rest) = @_;
  if (not exists $rest{$pk}) {
    # got no primary key in %rest: generate a new one
    $rest{$pk} = new_key($table, $pk);
  }
  ins($table, %rest);
  return sel_one($table, "*", "$pk=$rest{$pk}");
}

1;
