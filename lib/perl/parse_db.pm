package parse_db;

use strict;


BEGIN {
    use Exporter   ();
    use vars       qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
    # set the version for version checking
    $VERSION     = 1.0;

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
	if ($level==0)
	  { 
            if ($db=~/\G[\s\r\n]*$/gsc)
              { 
		last; 
	      };
            if ($db=~ /\G\s*record\s*\((\w*)\s*,\s*\"([^\"]*)\"\)[\s\r\n]*\{/gsc)
              { my($type,$name)= ($1,$2);
		$r_this_record_fields= {};
		$r_this_record= { TYPE => $type, 
	                	  FIELDS => $r_this_record_fields };
        	$records{$name}= $r_this_record; 
		$level=1;
		next;
	      };
	    croak "parse error at byte ",pos($db)," of input stream";   
	  };
	if ($level==1)
	  { 
            if ($db=~ /\G[\s\r\n]*\}/gsc)
              { $level=0;
		next;
	      };

            if ($db=~ /\G[\s\r\n]*field\s*\(\s*(\w*)\s*,\s*\"([^\"]*)\"\)/gsc)
              { my($field,$value)= ($1,$2);
		$value= "" if (!defined $value);
		$r_this_record_fields->{$field}= $value;
		next;
	      };
	    croak "parse error at byte ",pos($db)," of input stream";   
	  };
      };
    return(\%records);    
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


