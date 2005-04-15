# generic routines foe creating substitution files
require Exporter;

our @ISA = qw(Exporter);
our @EXPORT = qw(write_lines_sql write_line write_template);
our $VERSION = 1.00;

use strict;
use DBI;

# Returns a routine that writes instantiation lines inside a file-section
# of a substitution file, based on a SQL query.
# The result can be used as 3rd parameter to write_template.
sub write_lines_sql {
  # the arguments:
  # 1st arg: database handle to perform query on
  # 2nd arg: sql query
  # 3rd arg [optional]: reference to a row patch routine that takes
  #   a reference to a hash containing name/value pairs
  #   (such as returned by DBI::fetchrow_hashref)
  # 4th arg [optional]: reference to a titles patch routine that takes
  #   a reference to an array of titles
  my ($dbh,$query,$patch_row,$patch_titles) = @_;

  return sub {
    my ($fh) = @_;

    my $sth = $dbh->prepare($query);
    $sth->execute;
    my $titles = $sth->{NAME};
    &$patch_titles($titles) if defined $patch_titles;

    while (my $row = $sth->fetchrow_hashref) {
      &$patch_row($row) if defined $patch_row;
      write_line($fh, join(",", map("$_=\"$row->{$_}\"", @$titles)));
    }
  };
}

# Write one instantiation line inside some file-section of a substitution file.
sub write_line {
  # 1st arg: file handle to write to
  # 2nd arg: a string consisting of comma-separated NAME=VALUE definitions
  my ($fh,$line) = @_;
  print $fh " {" . $line . "}\n";
}

# Write a complete file-section in a substitution file.
sub write_template {
  # 1st arg: file handle to write to
  # 2nd arg: name of the template file to instantiate
  # 3rd arg: procedure that writes the substitution lines
  my ($fh,$template,$write_lines) = @_;
  print $fh "file $template {\n";
  &$write_lines($fh);
  print $fh "}\n";
}

1;
