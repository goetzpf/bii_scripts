
# This software is copyrighted by the BERLINER SPEICHERRING
# GESELLSCHAFT FUER SYNCHROTRONSTRAHLUNG M.B.H., BERLIN, GERMANY.
# The following terms apply to all files associated with the software.
# 
# BESSY hereby grants permission to use, copy and modify this
# software and its documentation for non-commercial, educational or
# research purposes provided that existing copyright notices are
# retained in all copies.
# 
# The receiver of the software provides BESSY with all enhancements, 
# including complete translations, made by the receiver.
# 
# IN NO EVENT SHALL BESSY BE LIABLE TO ANY PARTY FOR DIRECT, INDIRECT,
# SPECIAL, INCIDENTAL OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE
# OF THIS SOFTWARE, ITS DOCUMENTATION OR ANY DERIVATIVES THEREOF, EVEN 
# IF BESSY HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
# 
# BESSY SPECIFICALLY DISCLAIMS ANY WARRANTIES, INCLUDING, BUT NOT LIMITED
# TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
# PURPOSE, AND NON-INFRINGEMENT. THIS SOFTWARE IS PROVIDED ON AN "AS IS"
# BASIS, AND BESSY HAS NO OBLIGATION TO PROVIDE MAINTENANCE, SUPPORT,
# UPDATES, ENHANCEMENTS OR MODIFICATIONS.


=head1 NAME

CreateX - Routines that help to write CreateX.pl scripts

=head1 SYNOPSIS

  use CreateX;

  ($app,$ioc) = app_ioc(ARGV[0]);

  $fh = std_open_target $app, $ioc, "substitutions";

  with_target_file {
    my $fh = shift;
    #...use $fh for writing...
  } $app, $ioc, "substitutions";

  with_dbi_handle {
    my $dbh = shift;
  } std_dbi_connect_args;

  use DBI; $dbh = DBI->connect(std_dbi_connect_args);

  std_create_subst_and_req(ARGV[0],
    sub {
      my ($app,$ioc,$fh,$dbh) = @_;
      #...write stuff obtained using db handle $dbh into subst file $fh
    }
    sub {
      my ($app,$ioc,$fh,$dbh) = @_;
      #...write stuff obtained using db handle $dbh into req file $fh
    }
  }

  std_create_subst(ARGV[0],
    sub {
      my ($app,$ioc,$fh,$dbh) = @_;
      #...write stuff obtained using db handle $dbh into subst file $fh
    }
  }

  write_subst_line($fh, "NAME=\"VALUE\"");

  write_template($fh,"xyz.template",
    sub {
      my $fh = shift;
      print $fh " { NAME=DEVICE1, ADDR=0 }\n"
      print $fh " { NAME=DEVICE2, ADDR=1 }\n"
    }
  );

  perform_query($dbh,$query,
    sub {
      my ($row,$colnames) = @_;
      $row->{MY_NEW_COLUMN} = "a value for my new column";
      print $fh join(",", map("$_=\"$row->{$_}\"", @$colnames));
    },
    sub {
      my ($colnames) = @_;
      push(@$colnames, "MY_NEW_COLUMN");
    }
  )

  write_template_sql($fh,$template,$dbh,$query,
    sub {
      my ($row,$colnames) = @_;
      $row->{MY_NEW_COLUMN} = "a value for my new column";
      print $fh join(",", map("$_=\"$row->{$_}\"", @$colnames));
    },
    sub {
      my ($colnames) = @_;
      push(@$colnames, "MY_NEW_COLUMN");
    }
  }

=head1 DESCRIPTION

=cut

require Exporter;

our @ISA = qw(Exporter);
our @EXPORT = qw(
  std_create_subst_and_req
  std_create_subst
  std_open_target
  std_open_target_with_path
  std_dbi_connect_args
  with_dbi_handle
  with_target_file
  with_target_file_with_path
  app_ioc
  path_app_ioc
  write_subst_line
  write_template
  write_template_sql
  perform_query
);
our $VERSION = sprintf "%d.%03d", q$Revision: 1.9 $ =~ /(\d+)/g;

use strict;
use Carp;
use DBI;

=over

=item app_ioc EXPR

Split argument string into exactly two '.'-separated parts. Useful for
CreateSubst scipts, where the first argument is often "appname.iocname".

=cut

sub app_ioc {
  my $arg = shift;
  my @app_ioc = split /\./, $arg;
  @app_ioc == 2 or @app_ioc == 1 or confess "Bad argument '$arg'!";
  return @app_ioc;
}

sub path_app_ioc {
  my $arg = shift;
  my @path_app_ioc = ($arg =~ m/^(.*\/)?([^.\/]+)(?:.([^.\/]+))?$/);
  return @path_app_ioc;
}

=item std_open_target STRING STRING STRING

Open a target file for writing and return the file handle. The rest of the
arguments are (1) an application name (2) an optional IOC name, and (3) the file
name suffix. The file name to be opened is constructed by joining these parts
with dots in between. If an IOC name is not part of teh file name, an undefined
value must be given instead. The routine also prints a message indicating that
the a file of the given type (=suffix) is created for the given application name
and IOC name.

=cut

sub std_open_target {
  my ($app,$ioc,$suffix) = @_;
  my $filename = (defined $ioc) ? "$app.$ioc.$suffix" : "$app.$suffix";
  open my $filehandle, ">", $filename or confess "Can't open $filename: $!\n";
  my $onioc = " on $ioc" if defined $ioc;
  print "Creating $suffix file for $app$onioc\n";
  return $filehandle;
}

sub std_open_target_with_path {
  my ($path,$app,$ioc,$suffix) = @_;
  my $filename = (defined $ioc) ? "$path$app.$ioc.$suffix" : "$path$app.$suffix";
  print "filename = $filename\n";
  open my $filehandle, ">", $filename or confess "Can't open $filename: $!\n";
  my $onioc = " on $ioc" if defined $ioc;
  print "Creating $suffix file for $app$onioc\n";
  return $filehandle;
}

=item with_target_file BLOCK ARGS

Execute the first argument (a code block) with an open file handle as first
argument. The handle is opened using the remaining arguments as parameters to
L</std_open_target>. The handle is closed after the code block has been
executed.

=cut

sub with_target_file (&@) {
  my $code = shift;
  my $fh = &std_open_target;
  $code->($fh);
  close $fh;
}

sub with_target_file_with_path (&@) {
  my $code = shift;
  my $fh = &std_open_target_with_path;
  $code->($fh);
  close $fh;
}

=item with_dbi_handle BLOCK LIST

Execute the first argument (a code block) with an open dbi handle as first
argument. The handle is opened using the remaining arguments as parameters to
DBI->connect. The handle is closed after the code has been executed.

=cut

sub with_dbi_handle (&@) {
  my $code = shift;
  my $dbh = DBI->connect(@_);
  $code->($dbh);
  $dbh->disconnect;
}

=item std_dbi_connect_args

Standard arguments for DBI->connect, i.e.

    ("dbi:Oracle:$ENV{ORACLE_SID}",
    "guest",
    "bessyguest",
    {RaiseError => 1, ShowErrorStatement => 1, AutoCommit => 0})

=cut

use constant std_dbi_connect_args => (
    "dbi:Oracle:mirror",
    "guest",
    "bessyguest",
    {RaiseError => 1, ShowErrorStatement => 1, AutoCommit => 0}
  );

=item std_create_subst_and_req STRING SUB SUB

Standard 'main' routine to create a substitution and optionally a request file.
The first argument is a string of the form "application.ioc", usually $ARGV[0].
The second and third arguments must be subroutines that perform the actual work
of writing some stuff to the substition (2nd arg) resp. request file (3rd arg,
optional).

The passed subroutines in turn both get passed the following four arguments:

   1. application name
   2. ioc name
   3. file handle, opened via L</with_target_file>
   4. database handle, opened via L</with_dbi_handle>

=cut

sub std_create_subst_and_req {
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

=item std_create_subst STRING SUB

Standard 'main' routine to create a substitution file. This is just calls
L</std_create_subst_and_req> with the given two arguments.

=cut

sub std_create_subst {
  my ($arg,$write_subst) = @_;
  std_create_subst_and_req($arg,$write_subst);
}

=item perform_query DB_HANDLE QUERY ROW_HANDLER COLNAME_HANDLER

Generic routine to handle a single row returned by a SQL query on a database
handle. It is parameterized on database handle, SQL query, and row/colname
handler routines, that perform the real work. The arguments to perform_query
are:

   1. database handle to perform query on
   2. sql query (a string)
   3. a row handler routine that takes
      1. a reference to a hash containing name/value pairs
         (such as returned by DBI::fetchrow_hashref), and
      2. a reference to an array of column names

   4. a colname handler routine that takes a reference to an
      array of column names

=cut

sub perform_query {
  my ($dbh,$query,$row_handler,$colname_handler) = @_;

  my $sth = $dbh->prepare($query);
  $sth->execute;
  my $colnames = $sth->{NAME};
  $colname_handler->($colnames) if defined $colname_handler;

  while (my $row = $sth->fetchrow_hashref) {
    $row_handler->($row,$colnames);
  }
}

=item write_subst_line FILE STRING

Write one instantiation line inside some file-section of a substitution file.

=cut

sub write_subst_line {
  # 1st arg: file handle to write to
  # 2nd arg: a string consisting of comma-separated NAME=VALUE definitions
  my ($fh,$line) = @_;
  print $fh " {" . $line . "}\n";
}

=item write_template FILE STRING SUB

Write a complete file-section in a substitution file. The arguments are:

   1. file handle to write to
   2. name of the template file to instantiate
   3. procedure that writes the substitution lines

=cut

sub write_template {
  my ($fh,$template,$write_subst_lines) = @_;
  print $fh "file $template {\n";
  $write_subst_lines->($fh);
  print $fh "}\n";
}

=item write_template_sql

Write a complete file-section in a substitution file, based on sql query. The
arguments are:

   1: file handle to write to
   2: name of the template file to instantiate
   3: database handle to perform query on
   4: sql query
   5: [optional] reference to a row patch routine that takes
      1: a reference to a hash containing name/value pairs
         (such as returned by DBI::fetchrow_hashref), and
      2: a reference to an array of column names
   6: [optional] reference to a colnames patch routine that takes
      a reference to an array of colnames

=cut

sub write_template_sql {
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

=back

=cut
