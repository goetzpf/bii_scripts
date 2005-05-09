=head1 NAME

CreateX - Routines that help to write CreateX.pl scripts

=cut

require Exporter;

our @ISA = qw(Exporter);
our @EXPORT = qw(
  std_create_subst_and_req
  std_create_subst
  std_open_target
  std_dbi_connect_args
  with_dbi_handle
  with_target_file
  app_ioc
  write_subst_line
  write_template
  write_template_sql
);
our $VERSION = sprintf "%d.%03d", q$Revision: 1.4 $ =~ /(\d+)/g;

use strict;
use Carp;
use DBI;

## Initialization helpers

# Split argument into exactly two '.'-separated parts
sub app_ioc {
  my $arg = shift;
  my @app_ioc = split /\./, $arg;
  @app_ioc == 2 or confess "Bad argument '$arg'!";
  return @app_ioc;
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

# Execute the first argument (a code block) with an open file handle
# as first argument.
# The handle is opened using the remaining arguments as parameters
# to std_open_target.
# The handle is closed after the code has been executed.
sub with_target_file (&@) {
  my $code = shift;
  my $fh = &std_open_target;
  $code->($fh);
  close $fh;
}

# Execute the first argument (a code block) with an open dbi handle
# as first argument.
# The handle is opened using the remaining arguments as parameters
# to DBI->connect.
# The handle is closed after the code has been executed.
sub with_dbi_handle (&@) {
  my $code = shift;
  my $dbh = DBI->connect(@_);
  $code->($dbh);
  $dbh->disconnect;
}

# The usual BESSY-II standard arguments for DBI->connect
use constant std_dbi_connect_args => (
    "dbi:Oracle:$ENV{ORACLE_SID}",
    "guest",
    "bessyguest",
    {RaiseError => 1, ShowErrorStatement => 1, AutoCommit => 0}
  );

# Standard 'main' routine to create a substitution and a request file
sub std_create_subst_and_req {
  # 1st arg: string of the form "application.ioc"; usually $ARGV[0]
  # 2nd arg: routine that actually writes stuff to the subst file
  # 3rd arg: optional routine that actually writes stuff to the req file
  # The routines passed as 2nd and 3rd arg should take as arguments
  #   1) the application name
  #   2) the ioc name
  #   3) a file handle
  #   4) a database handle
  my ($arg,$write_subst,$write_req) = @_;

  my ($app,$ioc) = app_ioc($arg);

  with_dbi_handle {
    my $dbh = shift;
    with_target_file {
      my $fh = shift;
      $write_subst->($app,$ioc,$fh,$dbh);
    } $app,$ioc,"substitutions";
    with_target_file {
      my $fh = shift;
      $write_req->($app,$ioc,$fh,$dbh);
    } $app,$ioc,"req" if defined $write_req;
  } std_dbi_connect_args;
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
  my ($arg,$write_subst) = @_;
  std_create_subst_and_req($arg,$write_subst);
}

# Generic routine to handle a single row returned by a
# SQL query on a database handle. It is parameterized on
# database handle, SQL query, and row/colname handler routines,
# that perform the real work.
sub perform_query {
  # 1st arg: database handle to perform query on
  # 2nd arg: sql query
  # 3rd arg: reference to a row handler routine that takes
  #   (1) a reference to a hash containing name/value pairs
  #       (such as returned by DBI::fetchrow_hashref), and
  #   (2) a reference to an array of column names
  # 4th arg [optional]: reference to a colname handler routine that takes
  #   a reference to an array of column names
  my ($dbh,$query,$row_handler,$colname_handler) = @_;

  my $sth = $dbh->prepare($query);
  $sth->execute;
  my $colnames = $sth->{NAME};
  $colname_handler->($colnames) if defined $colname_handler;

  while (my $row = $sth->fetchrow_hashref) {
    $row_handler->($row,$colnames);
  }
}

## Routines to generate (parts of) a substitution file

# Write one instantiation line inside some file-section of a substitution file.
sub write_subst_line {
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
  my ($fh,$template,$write_subst_lines) = @_;
  print $fh "file $template {\n";
  $write_subst_lines->($fh);
  print $fh "}\n";
}

# Write a complete file-section in a substitution file, based on sql query.
sub write_template_sql {
  # 1st arg: file handle to write to
  # 2nd arg: name of the template file to instantiate
  # 3rd arg: database handle to perform query on
  # 4th arg: sql query
  # 5th arg [optional]: reference to a row patch routine that takes
  #   (1) a reference to a hash containing name/value pairs
  #       (such as returned by DBI::fetchrow_hashref), and
  #   (2) a reference to an array of column names
  # 6th arg [optional]: reference to a colnames patch routine that takes
  #   a reference to an array of colnames
  my ($fh,$template,$dbh,$query,$patch_row,$patch_colnames) = @_;
  write_template($fh,$template,
    sub {
      my $fh = shift;
      perform_query($dbh,$query,
        sub {
          my ($row,$colnames) = @_;
          $patch_row->($row,$colnames) if defined $patch_row;
          write_subst_line($fh, join(",", map("$_=\"$row->{$_}\"", @$colnames)));
        },
        $patch_colnames
      );
    }
  );
}

1;
