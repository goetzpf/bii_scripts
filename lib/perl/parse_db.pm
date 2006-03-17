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

sub parse
  { my($db)= @_;
  
    my $level= 0;

    my %records;

    my $r_this_record;
    my $r_this_record_fields;

    for(;;)
      { 
    #print $i++, " ";  

#print "scan at:---" . substr($db,pos($db),40) . "---\n";

	if ($level==0)
	  { 
            if ($db=~/\G[\s\r\n]*$/gsc)
              { 
		last; 
	      };
	    
	    # note:
	    # the regular expression 
	    # \s*(?:\s*(?:|\#[^\r\n]*)[\r\n]+)*\s* 
	    # matches any sequence of empty lines and comment-lines
	      
            if ($db=~ /\G
	              \s*(?:\s*(?:|\#[^\r\n]*)[\r\n]+)*\s*
		      record
		      \s*(?:\s*(?:|\#[^\r\n]*)[\r\n]+)*\s*
		               \(
			           \s*(?:\s*(?:|\#[^\r\n]*)[\r\n]+)*\s*
		                   (\w*)
				   \s*(?:\s*(?:|\#[^\r\n]*)[\r\n]+)*\s*
		                   ,
				   \s*(?:\s*(?:|\#[^\r\n]*)[\r\n]+)*\s*
			           (\"[^\"]*\"|[^\)\r\n]*)
				   \s*(?:\s*(?:|\#[^\r\n]*)[\r\n]+)*\s*
			       \)
		              \s*(?:\s*(?:|\#[^\r\n]*)[\r\n]+)*\s*
			      \{
		      /gscx
	       )
              { my($type,$name)= ($1,$2);
	      
	        $name=~ s/\s+$//;
		if ($name=~ /\"([^\"]*)\"/)
		  { $name= $1; };
	      
		$r_this_record_fields= {};
		$r_this_record= { TYPE => $type, 
	                	  FIELDS => $r_this_record_fields };
        	$records{$name}= $r_this_record; 
		$level=1;
		next;
	      };
	    parse_error(__LINE__,\$db,pos($db));
	  };
	  
	if ($level==1)
	  { 
            if ($db=~ /\G
	              \s*(?:\s*(?:|\#[^\r\n]*)[\r\n]+)*\s*
		      \}/gscx)
              { $level=0;
		next;
	      };

            if ($db=~ /\G
	              \s*(?:\s*(?:|\#[^\r\n]*)[\r\n]+)*\s*
		      field
	              \s*(?:\s*(?:|\#[^\r\n]*)[\r\n]+)*\s*
		           \(
			      \s*(?:\s*(?:|\#[^\r\n]*)[\r\n]+)*\s*
			      (\w*)
			      \s*(?:\s*(?:|\#[^\r\n]*)[\r\n]+)*\s*
			      ,
			      \s*(?:\s*(?:|\#[^\r\n]*)[\r\n]+)*\s*
			      (\"[^\"]*\"|[^\)\r\n]*)
			      \s*(?:\s*(?:|\#[^\r\n]*)[\r\n]+)*\s*
			   \)
		      /gscx)
              { my($field,$value)= ($1,$2);
		$value= "" if (!defined $value);
		$value=~ s/\"//g;

		$r_this_record_fields->{$field}= $value;
		next;
	      };
	    parse_error(__LINE__,\$db,pos($db));
	  };
      };
    return(\%records);    
  }

sub create_record
  { my($recname, $r_hash)= @_;
    my $r_fields= $r_hash->{FIELDS};
    
    print "record ",$r_hash->{TYPE},",\"$recname\" {\n";
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
  { my($prg_line,$r_st,$pos)= @_;
  
#    warn "short dump:\n" . substr($$r_st,$pos,40) . "\n";
    
    my($line,$column)= find_position_in_string($r_st,$pos);
    my $err= "Parse error at line $prg_line of parse_db.pm,\n" .
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
#    while($$r_str=~ /\G.*?^(.*?)$/gms)
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

  my $r_records= parse_db::parse($st);
  
This function parses a given scalar variable that must contain a 
complete db-file. It returns a reference to a hash, where the parsed data
is stored. 

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


