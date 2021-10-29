package parse_db;

# Copyright 2015 Helmholtz-Zentrum Berlin für Materialien und Energie GmbH
# <https://www.helmholtz-berlin.de>
#
# Author: Goetz Pfeiffer <Goetz.Pfeiffer@helmholtz-berlin.de>
# Contributions by:
#         Benjamin Franksen <Benjamin.Franksen@helmholtz-berlin.de>
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


BEGIN {
    use Exporter   ();
    use vars       qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
    # set the version for version checking
    $VERSION     = 1.4;

    @ISA         = qw(Exporter);
    @EXPORT      = qw();
    %EXPORT_TAGS = ( );     # eg: TAG => [ qw!name1 name2! ],

    # your exported package globals go here,
    # as well as any optionally exported functions
    @EXPORT_OK   = qw(&parse);
}

use vars      @EXPORT_OK;

# used modules
use Data::Dumper;
use Text::ParseWords;
use Carp;

our $treat_double_records=1;

our $space_or_comment    = qr/\s*(?:\s*(?:|\#[^\r\n]*)[\r\n]+)*\s*/;

our $quoted_word         = qr/\"(\w+)\"/;
our $quoted_filename     = qr/\"([\w\.]+)\"/;
our $unquoted_word       = qr/(\w+)/;

our $quoted              = qr/\"(.*?)(?<!\\)\"/;
our $unquoted_rec_name   = qr/([\w\-:\[\]<>;]+)/;
our $unquoted_field_name = qr/([\w\-\+:\.\[\]<>;]+)/;

my $template_def= qr/\G
                      template
                      $space_or_comment
                               \(
                                   $space_or_comment
                               \)
                              $space_or_comment
                              \{
                      /x;

my $port_def= qr/\G
                      $space_or_comment
                      port
                      $space_or_comment
                           \(
                              $space_or_comment
                              (?:$quoted_word|$unquoted_word)
                              $space_or_comment
                              ,
                              $space_or_comment
                              (?:$quoted|$unquoted_field_name)
                              $space_or_comment
                           \)
                      /x;

my $expand_def= qr/\G
                      expand
                      $space_or_comment
                               \(
                                   $space_or_comment
                                   $quoted_filename
                                   $space_or_comment
                                   ,
                                   $space_or_comment
                                   (?:$quoted_word|$unquoted_word)
                                   $space_or_comment
                               \)
                              $space_or_comment
                              \{
                      /x;

my $macro_def= qr/\G
                      $space_or_comment
                      macro
                      $space_or_comment
                           \(
                              $space_or_comment
                              (?:$quoted_word|$unquoted_word)
                              $space_or_comment
                              ,
                              $space_or_comment
                              (?:$quoted|$unquoted_field_name)
                              $space_or_comment
                           \)
                      /x;

my $record_head= qr/\G
                      record
                      $space_or_comment
                               \(
                                   $space_or_comment
                                   (?:$quoted_word|$unquoted_word)
                                   $space_or_comment
                                   ,
                                   $space_or_comment
                                   (?:$quoted|$unquoted_rec_name)
                                   $space_or_comment
                               \)
                              $space_or_comment
                              \{
                      /x;

my $alias_head= qr/\G
                      alias
                      $space_or_comment
                               \(
                                   $space_or_comment
                                   (?:$quoted|$unquoted_rec_name)
                                   $space_or_comment
                                   ,
                                   $space_or_comment
                                   (?:$quoted|$unquoted_rec_name)
                                   $space_or_comment
                               \)
                      /x;

my $field_def= qr/\G
                      $space_or_comment
                      field
                      $space_or_comment
                           \(
                              $space_or_comment
                              (?:$quoted_word|$unquoted_word)
                              $space_or_comment
                              ,
                              $space_or_comment
                              (?:$quoted|$unquoted_field_name)
                              $space_or_comment
                           \)
                      /x;

my $info_def= qr/\G
                      $space_or_comment
                      info
                      $space_or_comment
                           \(
                              $space_or_comment
                              (?:$quoted_word|$unquoted_word)
                              $space_or_comment
                              ,
                              $space_or_comment
                              (?:$quoted|$unquoted_field_name)
                              $space_or_comment
                           \)
                      /x;

my $alias_def= qr/\G
                      $space_or_comment
                      alias
                      $space_or_comment
                           \(
                              $space_or_comment
                              (?:$quoted|$unquoted_rec_name)
                              $space_or_comment
                           \)
                      /x;

my %_modes= ( undef      => "standard",
              ""         => "standard",
              "standard" => "standard",
              "asArray"  => "array",
              "array"    => "array",
              "extended" => "extended"
            );

sub parse
# the returned data depends on parameter mode. See also
# PERLPOD documentation for this function further below.
  { my($db,$filename,$mode)= @_;

    my $level= 0;
    my $_mode;

    my %record_alias_hash;
    my %real_records;

    my %records;
    my @record_array= ();

    my $this_record_name;
    my $r_this_record;
    my $r_this_record_fields;
    my $r_this_record_info;
    my $r_this_record_alias;
    
    my $_treat_double_records= $treat_double_records;

    $_mode= $_modes{$mode};
    if (!defined $_mode)
      { croak "invalid mode \"$mode\" in call to parse"; };

    if ($_mode eq 'array')
      {
        $_treat_double_records = 0 ;
      }

    if (!defined $db)
      { _simple_parse_error(__LINE__,$filename,"<undef> cannot be parsed"); }
    if ($db=~/^\s*$/)
      { _simple_parse_error(__LINE__,$filename,"\"\" cannot be parsed"); }

    my $len= length($db);
    for(;;)
      {
        if ($level==0)
          {
            # skip comment-lines at level 0:
            $db=~/\G$space_or_comment/ogscx;

            last if ($db=~/\G[\s\r\n]*$/gsc);
            last if (pos($db)>=$len); 
            # ^ needed for files without EOL at the end

            if ($db=~ /$template_def/ogscx)
              {
                $level=2;
                next;
              }
            if ($db=~ /$expand_def/ogscx)
              {
                $level=3;
                next;
              }
            elsif ($db=~ /$alias_head/ogscx)
              {
                my $record_name= (_empty($2)) ? $1 : $2;
                my $alias_name = (_empty($4)) ? $3 : $4;
                $record_alias_hash{$alias_name}= $record_name;
                next;
              }
            elsif ($db=~ /$record_head/ogscx)
              {
                my $type= (_empty($2)) ? $1 : $2;
                $this_record_name= (_empty($4)) ? $3 : $4;

                $r_this_record_fields= {};
                $r_this_record_info= {};
                $r_this_record_alias= [];
                $r_this_record= { TYPE => $type,
                                  FIELDS => $r_this_record_fields
                                };
                if ($_mode eq 'extended')
                  {
                    $r_this_record->{INFO}= $r_this_record_info;
                    $r_this_record->{ALIAS}= $r_this_record_alias;
                  };
                if (exists $records{$this_record_name})
                  { if    ($_treat_double_records==0)
                      { warn "warning: record \"$this_record_name\" is ".
                             "at least defined twice\n " .
                              "re-definitions are ignored\n";
                        $level=1;
                        next;
                      }
                    elsif ($_treat_double_records==1)
                      { $r_this_record= $records{$this_record_name};
                        $r_this_record_fields= $r_this_record->{FIELDS};
                        $r_this_record_info= $r_this_record->{INFO};
                        $level=1;
                        next;
                      }
                    elsif ($_treat_double_records==2)
                      { my $c=1;
                        while (exists $records{"$this_record_name:$c"})
                          { $c++; };
                        $this_record_name.= ":$c";
                      }
                    else
                      { die "assertion (treat_double_records)"; };
                  };
                if($_mode eq 'array')
                  {
                    $r_this_record->{'NAME'}=$this_record_name;
                    push @record_array, $r_this_record;
                  }
                $records{$this_record_name}= $r_this_record;
                $real_records{$this_record_name}= $r_this_record;
                $level=1;
                next;
              };
            _parse_error(__LINE__,\$db,pos($db),$filename);
          };

        if ($level==1)
          {
            if ($db=~ /\G
                      $space_or_comment
                      \}/ogscx)
              { $level=0;
                next;
              };

            if ($db=~ /$alias_def/ogscx)
              {
                my $alias_name= (_empty($2)) ? $1 : $2;
                $record_alias_hash{$alias_name}= $this_record_name;
                push @{$r_this_record->{'ALIAS'}}, $alias_name if ($_mode eq 'extended');
                next;
              };

            if ($db=~ /$info_def/ogscx)
              {
                my $info_name= (_empty($2)) ? $1 : $2;
                my $info_val = (_empty($4)) ? $3 : $4;

                $r_this_record_info->{$info_name}= $info_val;
                next;
              };

            if ($db=~ /$field_def/ogscx)
              {
                my $field= (_empty($2)) ? $1 : $2;
                my $value= (_empty($4)) ? $3 : $4;

                $r_this_record_fields->{$field}= $value;
                if ($_mode eq 'array')
                  {
                    push @{$r_this_record->{'ORDERDFIELDS'}}, $field;
                  };
                next;
              };
            _parse_error(__LINE__,\$db,pos($db),$filename);
          };
        if ($level==2)
          {
            if ($db=~ /\G
                      $space_or_comment
                      \}/ogscx)
              { $level=0;
                next;
              };

            if ($db=~ /$port_def/ogscx)
              {
                next;
              };
            _parse_error(__LINE__,\$db,pos($db),$filename);
          };
        if ($level==3)
          {
            if ($db=~ /\G
                      $space_or_comment
                      \}/ogscx)
              { $level=0;
                next;
              };

            if ($db=~ /$macro_def/ogscx)
              {
                next;
              };
            _parse_error(__LINE__,\$db,pos($db),$filename);
          };
      };
    if ($_mode eq 'array')
      {
        return \@record_array;
      }
    elsif ($_mode eq 'standard')
      {
        return(\%records);
      }
    elsif ($_mode eq 'extended')
      {
        # resolve aliases:
        while( my($alias,$realname)= each %record_alias_hash)
          {
            my $record_hash= $real_records{$realname};
            if (!defined $record_hash)
              {
                croak "alias '$alias' for '$realname': record doesn't exist";
                next;
              }
            $records{$alias}= $record_hash;
          }
        my %res= ('dbhash'=> \%records,
                  'aliasmap'=> \%record_alias_hash,
                  'realrecords'=> \%real_records
                 );
        return \%res;
      }
    else
      {
        die "assertion";
      }
  }

sub parse_file
# parse the db file and return the record hash
  { my($r_files, $mode)= @_;
    local(*F);
    local($/);
    my $name;
    my $st;

    undef $/;

    if (!ref($r_files))
      { # a simple scalar
        my @l= ($r_files);
        $r_files= \@l;
      }

    # name is just used for error messages
    if (($#$r_files==0) && ($r_files->[0]))
      { $name= $r_files->[0]; }

    foreach my $filename (@$r_files)
      {
        if (!defined $filename) # read from STDIN
          { *F=*STDIN; }
        else
          { open(F,$filename) or die "unable to open $filename"; };
        $st.= <F>;
        close(F) if (defined $filename);
      }

    return(parse($st,$name,$mode));
    #dump($r_records);
    #create($r_records);
  }

sub create_record
  { my($recname, $r_hash)= @_;
    my $r_fields= $r_hash->{FIELDS};
    my $r_infos= $r_hash->{INFO};
    my $r_alias= $r_hash->{ALIAS};

    print "record(",$r_hash->{TYPE},",\"$recname\") {\n";
    foreach my $f (sort keys %$r_infos)
      {
        print "\tinfo(",$f,",\"",$r_infos->{$f},"\")\n";
      };
    foreach my $f (sort @$r_alias)
      {
        print "\talias(\"",$f,"\")\n";
      };
    foreach my $f (sort keys %$r_fields)
      {
        print "\tfield(",$f,",\"",$r_fields->{$f},"\")\n";
      };
    print "}\n\n";
  }

sub create_aliases
  {
    my($r_alias_hash)= @_;

    foreach my $key (sort keys %$r_alias_hash)
      {
        print "alias(",$r_alias_hash->{$key},", ",$key,")\n";
      }
  }

sub create
  { my($r_records,$r_reclist)= @_;

    if (defined $r_reclist)
      { if (ref($r_reclist) ne 'ARRAY')
          { die "error: 2nd parameter must be an array reference"; }
      }
    else
      { $r_reclist= [sort keys %$r_records]; }

    foreach my $rec (@$r_reclist)
      { my $r_f= $r_records->{$rec};
        next if (!defined $r_f);
        create_record($rec,$r_f);
      };
  }

sub dump
  { my($r_records)= @_;

    print Data::Dumper->Dump([$r_records], [qw(records)]);
  }

sub dump_real
  { my($r_ext_recs)= @_;

    print Data::Dumper->Dump([$r_ext_recs->{realrecords},
                              $r_ext_recs->{aliasmap}],
                             [qw(realrecords aliasmap)]);
  }

sub handle_double_names
  { my($mode)= @_;

    if (($mode!=0) && ($mode!=1) && ($mode!=2))
      { croak "invalid mode \"$mode\" in call to handle_double_names"; };

    $treat_double_records= $mode;
  }

sub _simple_parse_error
  { my($prg_line, $filename, $msg)= @_;
    if (defined $filename)
      { $filename= "in file $filename "; };
    my $err= "Parse error ${filename}at line $prg_line of parse_db.pm,\n" .
             $msg . "\n";
    croak $err;
  }


sub _parse_error
  { my($prg_line,$r_st,$pos,$filename)= @_;

    my($line,$column)= _find_position_in_string($r_st,$pos);
    if (defined $filename)
      { $filename= "in file $filename "; };
    my $err= "Parse error ${filename}at line $prg_line of parse_db.pm,\n" .
             "byte-position $pos\n" .
             "line $line, column $column in file\n ";
    croak $err;
  }

sub _find_position_in_string
# gets a position as returned by pos(..) in a
# multi-line strings and returns a pair (row,column)
# the first row is 1, the first column is 0
  { my($r_str,$position)= @_;

    my $cnt=0;
    my $lineno=1;


    pos($$r_str)=0;
    my $oldpos=-1;

    while($$r_str=~ /\G(.*?)\r?\n/gms)
      {
        if (pos($$r_str)<$position)
          {
            $oldpos= pos($$r_str);
            $lineno++;
            next;
          };
        return($lineno,$position-$oldpos);
      };
    return($lineno,$position-$oldpos);
  }

sub _empty
# returns 1 for undefined or _empty strings
  { if (!defined $_[0])
      { return 1; };
    if ($_[0] eq "")
      { return 1; };
    return;
  }

1;

__END__
# Below is the short of documentation of the module.

=head1 NAME

parse_db - a Perl module to parse epics db-files

=head1 SYNOPSIS

  use parse_db;
  undef $/;

  my $st= <>;

  my $r_records= parse_db::parse($st);
  parse_db::dump($r_records);

=head1 DESCRIPTION

=head2 Preface

This module contains a parser function for epics DB-files. The
contents of the db-file are returned in a perl hash-structure that
can then be used for further evaluation.

=head2 Implemented Functions:

=over 4

=item *

B<parse()>

  my $r_records= parse_db::parse($st,$filename,$mode);

This function parses a given scalar variable that must contain a complete
db-file. It returns a perl data structure containing the parsed data. The way
the data structure is created depends on the $mode parameter. See also the
chapter "data structures" for some examples.

These are the possible values of $mode:

=over 4

=item "standard"

parse returns a reference to a db hash. This hash maps record names to
references of record hashes.

=item "array"

parse returns a reference to a db array. This array contains references to
record hashes.

=item "extended"

parse returns a reference to an extended db hash. This hash contains a db hash,
an alias map and a real record hash.

=back

For backwards compability, the following values for $mode are also allowed:

=over 4

=item undef

like mode "standard"

=item ""

like mode "standard"

=item "asArray"

like mode "array"

=back

=item *

B<parse_file()>

  my $r_records= parse_db::parse_file($filename,$mode);

This function parses the contents of the given file. If parameter C<$filename>
is C<undef> it tries to read form STDIN. If parameter C<$filename> is a list
reference, the function parses the contents of all files in the list.  If the
file cannot be opened, it dies with an appropriate error message. For the
meaning of parameter C<$mode> and the format of the returned data see
description of function "parse".

=item *

B<create_record()>

  parse_db::create_record($record_name,$r_records)

Print the contents of the given record in the standard db format to the screen.
The second parameter must be a reference to a record hash.

=item *

B<create_aliases()>

  parse_db::create_aliases($r_alias_hash)

Print alias statements from an alias hash to the screen. The parameter must be
a reference to an alias hash.

=item *

B<create()>

  parse_db::create($r_records,$r_record_list)

Print the contents of all records in the standard db format to the screen. The
first parameter must be a reference to a db hash. The parameter
C<$r_record_list> is optional. The default is that records are printed in
alphabetical order. If the second parameter is given, only records from this
list and in this order are printed.

=item *

B<dump()>

  parse_db::dump($r_records)

Dumps a db hash with Data::Dumper. The parameter must be a reference to a db
hash.

=item *

B<dump_real()>

  parse_db::dump_real($r_ext_recs)

Dumps the real records and the aliases from an extended db hash with
Data::Dumper. The parameter must be a reference to an extended db hash.

=item *

B<handle_double_names()>

  parse_db::handle_double_names($mode)

Determine how double record names are treated. The following
modes are known:

=over 4

=item "0"

With $mode=0, a warning is printed and the
second definition of the record is ignored.

=item "1"

With $mode=1 (the default), the second record definition is merged with the
first definition. Definitions of the same fields that come later
in the file overwrite earlier definitions. This is the standard
behaviour when the IOC loads a database file.

=item "2"

With $mode=2, the parse-module handles double record-names by
appending a number of each double name that
is encountered. This feature may be used to track down errors
in databases that were generated with double record names without
the intention to do so.

=back

=back

=head2 data structures

=head3 field hash

A field hash maps field names to field values, both are perl strings. Here is
an example:

  (
    'PRIO' => 'LOW',
    'DESC' => 'subroutine',
    'HIGH' => ''
  )

=head3 info hash

An info hash maps "info" names to "info" values. This is the information from
the "info" statement in a db file. Here is an example:

  (
    'Author'   => 'John Doe',
    'Revision' => '1.2',
    'Notes'    => 'not yet tested'
  )

=head3 record hash

A record hash contains all information about a single record. It is part of the
data structure created by the functions parse and parse_file. Depending on the
"mode" parameter of these functions, the record hash may be slightly different.

It always
includes a key "FIELDS" that maps to a reference of a field hash and a key
"TYPE" that maps to a string that is the record type. 

When parse or parse_file were called with mode "array", the hash also includes
a key "NAME" that maps to the record name and a key "ORDERDFIELDS" that maps to
a reference of a list of field names in the order they were found in the db
file. When parse or parse_file were is called with mode "extended" the record
includes a field "INFO" that maps to a reference to an info hash.

Here are some examples,

created in mode "standard":

  (
    'TYPE'  => 'sub',
    'FIELDS'=> { 'PRIO' => 'LOW',
                 'DESC' => 'subroutine',
                 'HIGH' => ''
               }
  )

created in mode "array":

  (
    'NAME'  => 'UE52ID5R:BaseCmdHome',
    'TYPE'  => 'sub',
    'FIELDS'=> {
                 'PRIO' => 'LOW',
                 'DESC' => 'subroutine',
                 'HIGH' => ''
               },
    'ORDERDFIELDS' => [ 'DESC', 'PRIO', 'HIGH' ]
  )

created in mode "extended":

  (
    'TYPE'  => 'sub',
    'INFO'  => {
                 'Author'   => 'John Doe',
                 'Revision' => '1.2',
                 'Notes'    => 'not yet tested'
               },
    'FIELDS'=> {
                 'PRIO' => 'LOW',
                 'DESC' => 'subroutine',
                 'HIGH' => ''
               }
  )

=head3 db hash

A db hash is created when function "parse" is called in mode "standard". It
maps record names to references of record hashes. Here is an example:

  (
    'UE52ID5R:BaseCmdHome' =>
       { 'TYPE'  => 'sub',
         'FIELDS'=> { 'PRIO' => 'LOW',
                      'DESC' => 'subroutine',
                      'HIGH' => ''
                    }
       }
    'UE52ID5R:BaseStatAStat' =>
       { 'TYPE'  => 'sub',
         'FIELDS'=> { 'PRIO' => 'HIGH',
                      'DESC' => 'subroutine',
                      'HIGH' => '1'
                    }
       }
  )

=head3 db array

A db array is created when function "parse" is called in mode "array". It is a
list of references to record hashes. Here is an example:

  [ {
      'NAME'  => 'UE52ID5R:BaseCmdHome',
      'TYPE'  => 'sub',
      'FIELDS'=> {
                   'PRIO' => 'LOW',
                   'DESC' => 'subroutine',
                   'HIGH' => ''
                 },
      'ORDERDFIELDS' => [ 'DESC', 'PRIO', 'HIGH' ]
    },
    {
      'NAME'  => 'UE52ID5R:BaseStatAStat',
      'TYPE'  => 'sub',
      'FIELDS'=> {
                   'PRIO' => 'HIGH',
                   'DESC' => 'subroutine',
                   'HIGH' => '1'
                 },
      'ORDERDFIELDS' => [ 'DESC', 'PRIO', 'HIGH' ]
    },


=head3 alias map

This is a hash that maps alias names of records to real names of records. There
is an example:

  (
    'HomeRecord' => 'UE52ID5R:BaseCmdHome',
    'StatRecord' => 'UE52ID5R:BaseStatAStat,
  )

=head3 real record hash

This is a hash that maps real names of records to record hashes. Here is an
example:

  (
    'UE52ID5R:BaseCmdHome' =>
       { 'TYPE'  => 'sub',
         'FIELDS'=> { 'PRIO' => 'LOW',
                      'DESC' => 'subroutine',
                      'HIGH' => ''
                    }
       }
    'UE52ID5R:BaseStatAStat' =>
       { 'TYPE'  => 'sub',
         'FIELDS'=> { 'PRIO' => 'HIGH',
                      'DESC' => 'subroutine',
                      'HIGH' => '1'
                    }
       }
  )

=head3 extended db hash

A db hash contains a db hash, an alias map and a real record hash. Note that
aliases to record names are resolver in the db hash, meaning that this hash may
contain keys that map to the same record hash. The well known Data::Dumper
module doesn't handle these cases well (at least in my opinion), here is a
quote from the Data::Dumper documentation:

  Any references that are the same as one of those passed in will 
  be named $VARn (where n is a numeric suffix), and other duplicate 
  references to substructures within $VARn will be appropriately 
  labeled using arrow notation.

Here is an example (not created by Data::Dumper) for a db hash:

  (
    'dbhash' => {
                  'UE52ID5R:BaseCmdHome' =>
                     { 'TYPE'  => 'sub',
                       'FIELDS'=> { 'PRIO' => 'LOW',
                                    'DESC' => 'subroutine',
                                    'HIGH' => ''
                                  }
                     }
                  'HomeRecord' =>
                     { 'TYPE'  => 'sub',
                       'FIELDS'=> { 'PRIO' => 'LOW',
                                    'DESC' => 'subroutine',
                                    'HIGH' => ''
                                  }
                     }
                  'UE52ID5R:BaseStatAStat' =>
                     { 'TYPE'  => 'sub',
                       'FIELDS'=> { 'PRIO' => 'HIGH',
                                    'DESC' => 'subroutine',
                                    'HIGH' => '1'
                                  }
                     }
                  'StatRecord' =>
                     { 'TYPE'  => 'sub',
                       'FIELDS'=> { 'PRIO' => 'HIGH',
                                    'DESC' => 'subroutine',
                                    'HIGH' => '1'
                                  }
                     }
                },
    'aliasmap' => {
                    'HomeRecord' => 'UE52ID5R:BaseCmdHome',
                    'StatRecord' => 'UE52ID5R:BaseStatAStat,
                  },
    'realrecords' =>
                {
                  'UE52ID5R:BaseCmdHome' =>
                     { 'TYPE'  => 'sub',
                       'FIELDS'=> { 'PRIO' => 'LOW',
                                    'DESC' => 'subroutine',
                                    'HIGH' => ''
                                  }
                     }
                  'UE52ID5R:BaseStatAStat' =>
                     { 'TYPE'  => 'sub',
                       'FIELDS'=> { 'PRIO' => 'HIGH',
                                    'DESC' => 'subroutine',
                                    'HIGH' => '1'
                                  }
                     }
                },
  )

=head1 AUTHOR

Goetz Pfeiffer,  Goetz.Pfeiffer@helmholtz-berlin.de

=head1 SEE ALSO

perl-documentation

=cut


