# generic routines for creating substitution files
require Exporter;

our @ISA = qw(Exporter);
our @EXPORT = qw(
  std_create_subst_and_req
  std_create_subst
  std_write_target
  std_open_target
  std_dbi_connect
  std_dbi_connect_args
  with_dbi_handle
  app_ioc
  write_lines_sql
  write_line
  write_template
  write_template_sql
);
our $VERSION = 0.1;

use strict;
use Carp;
use DBI;

# Standard 'main' routine to create a substitution and a request file
sub std_create_subst_and_req {
  # 1st arg: string of the form "application.ioc"; usually $ARGV[0]
  # 2nd arg: routine that actually writes stuff to the subst file
  # 3rd arg: optional routine that actually writes stuff to the req file
  # The routines passed as 2nd and 3rd arg should take as arguments
  # 1) a database handle
  # 2) a file handle
  # 3) the application name
  # 4) the ioc name
  my ($arg,$subst_action,$req_action) = @_;

  my ($app,$ioc) = app_ioc($arg);
  with_dbi_handle(
    sub {
      my $dbh = shift;
      std_write_target($app,$ioc,"substitutions",
        sub {
          unshift @_, $dbh;
          &$subst_action(@_);
        }
      );
      std_write_target($app,$ioc,"req",
        sub {
          unshift @_, $dbh;
          &$req_action(@_);
        }
      ) if defined $req_action;
    },
    std_dbi_connect_args()
  );
}

# Standard 'main' routine to create a substitution file. This is just a special
# instance of std_create_subst_and_req.
sub std_create_subst {
  # 1st arg: a string of the form "application.ioc"; usually $ARGV[0]
  # 2nd arg: a routine that actually writes stuff to the file
  # The routines passed as 2nd arg should take as arguments
  # 1) a database handle
  # 2) a file handle
  # 3) the application name
  # 4) the ioc name
  my ($arg,$subst_action) = @_;
  std_create_subst_and_req($arg,$subst_action);
}

## Initialization helpers

# Split argument into exactly two '.'-separated parts
sub app_ioc {
  my ($arg) = @_;
  my @app_ioc = split /\./, $arg;
  @app_ioc == 2 or confess "Bad argument '$arg'!";
  return @app_ioc;
}

# Return usual BESSY-II standard arguments for DBI->connect.
sub std_dbi_connect_args {
  return (
    "dbi:Oracle:$ENV{ORACLE_SID}",
    "guest",
    "bessyguest",
    {RaiseError => 1, ShowErrorStatement => 1, AutoCommit => 0});
}

# Do a DBI->connect with the usual BESSY-II standard arguments.
# Returns the database handle.
sub std_dbi_connect {
  return DBI->connect(std_dbi_connect_args());
}

sub with_dbi_handle {
  my ($actions,@dbh_connect_args) = @_;
  my $dbh = DBI->connect(@dbh_connect_args);
  &$actions($dbh);
  $dbh->disconnect;
}

# Write target file
sub std_write_target {
  my ($app,$ioc,$suffix,$write_action) = @_;
  my $fh = std_open_target($app,$ioc,$suffix);
  &$write_action($fh,$app,$ioc);
  close $fh;
}

# Open a target file (i.e. writeable), given app name, ioc name, and suffix.
# Also prints a message to indicate what is going to be done.
sub std_open_target {
  my ($app,$ioc,$suffix) = @_;
  my $filename = "$app.$ioc.$suffix";
  open my $filehandle, ">", $filename or confess "Can't open $filename: $!\n";
  print "Creating $suffix file for $app on $ioc\n";
  return $filehandle;
}

## Routines to generate (parts of) a substitution file

# Write a complete file-section in a substitution file, based on sql query.
sub write_template_sql {
  # 1st arg: file handle to write to
  # 2nd arg: name of the template file to instantiate
  # 3rd arg: database handle to perform query on
  # 4th arg: sql query
  # 5th arg [optional]: reference to a row patch routine that takes
  #   a reference to a hash containing name/value pairs
  #   (such as returned by DBI::fetchrow_hashref)
  # 6th arg [optional]: reference to a titles patch routine that takes
  #   a reference to an array of titles
  my ($fh,$template,$dbh,$query,$patch_row,$patch_titles) = @_;
  write_template($fh,$template,
    write_lines_sql($dbh,$query,$patch_row,$patch_titles));
}

# Returns a routine that writes instantiation lines inside a file-section
# of a substitution file, based on a SQL query.
# The result can be used as 3rd parameter to write_template.
sub write_lines_sql {
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
