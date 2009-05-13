package parse_db;

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


use strict;


BEGIN {
    use Exporter   ();
    use vars       qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
    # set the version for version checking
    $VERSION     = 1.3;

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

sub handle_double_names
  { my($mode)= @_;

    if (($mode!=0) && ($mode!=1) && ($mode!=2))
      { croak "invalid mode \"$mode\" in call to handle_double_names"; };

    $treat_double_records= $mode; 
  }

sub parse
  { my($db,$filename,$storeType)= @_;

    my $level= 0;

    my %records;

    my $r_this_record;
    my $r_this_record_fields;

    if ($storeType eq 'asArray')
    {
    	$treat_double_records = 0 ;
    	$r_this_record->{'ORDERDFIELDS'} =[];
    }
    my $rA_records; # [{'NAME'='recName', TYPE='recType', FIELDS=[[NAME,VALUE],..]},..]
    if (!defined $db)
      { simple_parse_error(__LINE__,$filename,"<undef> cannot be parsed"); }
    if ($db=~/^\s*$/)
      { simple_parse_error(__LINE__,$filename,"\"\" cannot be parsed"); }

    for(;;)
      { 
        if ($level==0)
          { 
            # skip comment-lines at level 0:
            $db=~/\G$space_or_comment/ogscx;

            last if ($db=~/\G[\s\r\n]*$/gsc);

            if ($db=~ /$template_def/ogscx)
              { 
                $level=2;
                next;
              }
            elsif ($db=~ /$record_head/ogscx)
              { 
                my $type= (empty($2)) ? $1 : $2;
                my $name= (empty($4)) ? $3 : $4;

                $r_this_record_fields= {};
                $r_this_record= { TYPE => $type, 
                                  FIELDS => $r_this_record_fields };
                if (exists $records{$name})
                  { if    ($treat_double_records==0)
		      { warn "warning: record \"$name\" is at least defined " .
		              "twice\n " .
			      "re-definitions are ignored\n"; 
                        $level=1;
			next;
		      }
		    elsif ($treat_double_records==1)
		      { $r_this_record= $records{$name};
		        $r_this_record_fields= $r_this_record->{FIELDS};
                        $level=1;
			next;
		      }
		    elsif ($treat_double_records==2)
		      { my $c=1; 
			while (exists $records{"$name:$c"})
			  { $c++; };
			$name.= ":$c";
		      }
		    else
		      { die "assertion (treat_double_records)"; };
		  };
                if($storeType eq 'asArray')
		{ 
		    $r_this_record->{'NAME'}=$name;
		    push @$rA_records, $r_this_record;
		}
		$records{$name}= $r_this_record; 
                $level=1;
                next;
              };
            parse_error(__LINE__,\$db,pos($db),$filename);
          };

        if ($level==1)
          { 
            if ($db=~ /\G
                      $space_or_comment
                      \}/ogscx)
              { $level=0;
                next;
              };

            if ($db=~ /$field_def/ogscx)
              { 
		my $field= (empty($2)) ? $1 : $2;
                my $value= (empty($4)) ? $3 : $4;

                $r_this_record_fields->{$field}= $value;
                push @{$r_this_record->{'ORDERDFIELDS'}}, $field if ($storeType eq 'asArray');
		next;
              };
            parse_error(__LINE__,\$db,pos($db),$filename);
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
            parse_error(__LINE__,\$db,pos($db),$filename);
          };
      };
    if($storeType eq 'asArray')
    { 
    	return $rA_records;
    }
    {
    	return(\%records);
    }
  }

sub parse_file
# parse the db file and return the record hash
  { my($filename)= @_;
    local(*F);
    local($/);
    my $st;

    undef $/;

    if (!defined $filename) # read from STDIN
      { *F=*STDIN; }
    else
      { open(F,$filename) or die "unable to open $filename"; };
    $st= <F>;

    close(F) if (defined $filename);

    return(parse($st));
    #dump($r_records);
    #create($r_records);
  }

sub create_record
  { my($recname, $r_hash)= @_;
    my $r_fields= $r_hash->{FIELDS};

    print "record(",$r_hash->{TYPE},",\"$recname\") {\n";
    foreach my $f (sort keys %$r_fields)
      { print "\tfield(",$f,",\"",$r_fields->{$f},"\")\n";
      };
    print "}\n\n";
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

sub simple_parse_error
  { my($prg_line, $filename, $msg)= @_;
    if (defined $filename)
      { $filename= "in file $filename "; };
    my $err= "Parse error ${filename}at line $prg_line of parse_db.pm,\n" .
             $msg . "\n";
    croak $err;
  }
    

sub parse_error
  { my($prg_line,$r_st,$pos,$filename)= @_;

    my($line,$column)= find_position_in_string($r_st,$pos);
    if (defined $filename)
      { $filename= "in file $filename "; };
    my $err= "Parse error ${filename}at line $prg_line of parse_db.pm,\n" .
             "byte-position $pos\n" .
             "line $line, column $column in file\n ";
    croak $err;
  }



sub find_position_in_string
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


sub dump
  { my($r_records)= @_;

    print Data::Dumper->Dump([$r_records], [qw(records)]);
  }

sub empty
# returns 1 for undefined or empty strings
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

  my $r_records= parse_db::parse($st,$filename,$storeType);

This function parses a given scalar variable that must contain a 
complete db-file. It returns a reference to a hash, where the parsed data
is stored. The parameter $filename is optional and is just used for
printing error messages in case of a parse-error.

$storeType Parameter is also optional and specifies the format of the
returned data structure:

- undef: default {'NAME'=> { TYPE=>'recType', FIELDS => { FIELD1=> VALUE1, ...},..}
- asArray : [{'NAME'=>'recName', TYPE=>'recType', FIELDS => { FIELD1=> VALUE1, ...}, 
               'ORDERDFIELDS' => [FIELD1,..]},
	       ..
	    ]

=item *

B<parse_file()>

  my $r_records= parse_db::parse_file($filename);

This function parses the contents of the given filename. If the parameter
C<$filename> is not given it tries to read form STDIN. If the
file cannot be opened, it dies with an appropriate error message.
It returns a reference to a hash, where the parsed data
is stored.

=item *

B<create_record()>

  parse_db::create_record($record_name,$r_records)

Print the contents of the given record in the standard db format to the
screen.

=item *

B<create()>

  parse_db::create($r_records,$r_record_list)

Print the contents of all records in the standard db format to the
screen. The parameter C<$r_record_list> is optional. The default
is that records are printed in alphabetical order. If the second
parameter is given, only records from this list and in this
order are printed.

=item *

B<handle_double_names()>

  parse_db::handle_double_names($mode)

Determine how double record names are treated. The following
modes are known:

=over 4

=item 0

With $mode=0, a warning is printed and the
second definition of the record is ignored.

=item 1

With $mode=1 (the default), the second record definition is merged with the
first definition. Definitions of the same fields that come later
in the file overwrite earlier definitions. This is the standard
behaviour when the IOC loads a database file.

=item 2

With $mode=2, the parse-module handles double record-names by 
appending a number of each double name that 
is encountered. This feature may be used to track down errors 
in databases that were generated with double record names without
the intention to do so.

=back

=back

=head2 hash-structure

Each record-name is a key in the record-hash. It is a reference to 
a sub-hash that contains the data for that record. 

The sub-hash contains two keys, "TYPE" is the record type (a string),
"FIELDS" is a reference to a hash that contains the record-fields.

The field-hash contains a key for each field name that gives the value of
that field. Note that undefined fields-values are empty strings (""), not
the perl undef-value.

Example of a hash that parse() returns as default:

  $r_records= { 'UE52ID5R:BaseCmdHome' => 
                   { 'TYPE'  => 'sub',
                     'FIELDS'=> { 'PRIO' => 'LOW',
                                  'DESC' => 'subroutine',
                                  'HIGH' => ''
                                }
                   } 
              }
  Return 'asArray'
   $r_records= [ {'NAME'   =>'recName', 
                  'TYPE'   =>'recType', 
		  'FIELDS' => { FIELD1=> VALUE1, ...}, 
                  'ORDERDFIELDS' => [FIELD1,..]
	         }
	       ]

=head1 AUTHOR

Goetz Pfeiffer,  Goetz.Pfeiffer@helmholtz-berlin.de

=head1 SEE ALSO

perl-documentation

=cut


