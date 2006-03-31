package parse_db;

use strict;


BEGIN {
    use Exporter   ();
    use vars       qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
    # set the version for version checking
    $VERSION     = 1.1;

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

my $space_or_comment    = qr/\s*(?:\s*(?:|\#[^\r\n]*)[\r\n]+)*\s*/;

my $quoted_word         = qr/\"(\w+)\"/;
my $unquoted_word       = qr/(\w+)/;

my $quoted              = qr/\"(.*?)(?<!\\)\"/;
my $unquoted_rec_name   = qr/([\w\-:\[\]<>;]+)/;
my $unquoted_field_name = qr/([\w\-\+:\.\[\]<>;]+)/;

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

sub parse
  { my($db,$filename)= @_;
  
    my $level= 0;

    my %records;

    my $r_this_record;
    my $r_this_record_fields;

    
    for(;;)
      { 
	if ($level==0)
	  { 
            # skip comment-lines at level 0:
	    $db=~/\G$space_or_comment/ogscx;
	    
	    last if ($db=~/\G[\s\r\n]*$/gsc);
	    
            if ($db=~ /$record_head/ogscx)
              { 
	        my $type= ($2 eq "") ? $1 : $2;
		my $name= ($4 eq "") ? $3 : $4;
		
		$r_this_record_fields= {};
		$r_this_record= { TYPE => $type, 
	                	  FIELDS => $r_this_record_fields };
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
	        my $field= ($2 eq "") ? $1 : $2;
		my $value= ($4 eq "") ? $3 : $4;
		
		$r_this_record_fields->{$field}= $value;
		next;
	      };
	    parse_error(__LINE__,\$db,pos($db),$filename);
	  };
      };
    return(\%records);    
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
  { my($r_records)= @_;
  
    foreach my $rec (sort keys %$r_records)
      { create_record($rec,$r_records->{$rec}); };
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

  my $r_records= parse_db::parse($st,$filename);
  
This function parses a given scalar variable that must contain a 
complete db-file. It returns a reference to a hash, where the parsed data
is stored. The parameter $filename is optional and is just used for
printing error messages in case of a parse-error.

=item *

B<create_record()>

  parse_db::create_record($record_name,$r_records)
  
Print the contents of the given record in the standard db format to the
screen.

=item *

B<create()>

  parse_db::create($r_records)

Print the contents of all records in the standard db format to the
screen.
  
  

=back

=head2 hash-structure

Each record-name is a key in the record-hash. It is a reference to 
a sub-hash that contains the data for that record. 

The sub-hash contains two keys, "TYPE" is the record type (a string),
"FIELDS" is a reference to a hash that contains the record-fields.

The field-hash contains a key for each field name that gives the value of
that field. Note that undefined fields-values are empty strings (""), not
the perl undef-value.

Example of a hash that parse() returns:
  
  $r_records= { 'UE52ID5R:BaseCmdHome' => 
                   { 'TYPE'  => 'sub',
                     'FIELDS'=> { 'PRIO' => 'LOW',
		     		  'DESC' => 'subroutine',
				  'HIGH' => ''
			        }
                   } 
	      }

=head1 AUTHOR

Goetz Pfeiffer,  goetzp@gmx.net

=head1 SEE ALSO

perl-documentation

=cut


