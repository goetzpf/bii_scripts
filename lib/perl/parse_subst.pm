package parse_subst;

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

    my %templates;

    my $r_this_template_instance;
    my $r_this_instance_no;
    my $r_this_instance_fields;

    for(;;)
      { 
    #print $i++, " ";  
	if ($level==0)
	  { 
#print "[",__LINE__,"]\n";
            if ($db=~/\G[\s\r\n]*$/gsc)
              { 
		last; 
	      };
            if ($db=~ /\G\s*file\s+([\w\.]+)[\s\r\n]*\{/gsc)
              { my($name)= ($1);
		$r_this_template_instance= {};
		$r_this_instance_no= 0;
		
        	$templates{$name}= $r_this_template_instance; 
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
            if ($db=~ /\G[\s\r\n]*\{/gsc)
              { $level=2;
	        $r_this_instance_fields= {};
		$r_this_template_instance->{$r_this_instance_no++}=
		     $r_this_instance_fields;
		next;
	      };
	  }; 
	  
	if ($level==2)
	  { 
            if ($db=~ /\G[\s\r\n]*\}/gsc)
              { $level=1;
		next;
	      };

            if ($db=~ /\G[\s\r\n]*(\w+)\s*=\s*\"([^\"]*)\"\s*,?/gsc)
              { my($field,$value)= ($1,$2);
		$value= "" if (!defined $value);
		$r_this_instance_fields->{$field}= $value;
		next;
	      };
	    croak "parse error at byte ",pos($db)," of input stream";   
	  };
      };
    return(\%templates);    
  }

sub dump
  { my($r_templates)= @_;
  
    print Data::Dumper->Dump([$r_templates], [qw(templates)]);
  }

1;

__END__
# Below is the short of documentation of the module.

=head1 NAME

parse_subst - a Perl module to parse epics substitution-files

=head1 SYNOPSIS

  use parse_subst;
  undef $/;

  my $st= <>;

  my $r_templates= parse_subst::parse($st);
  parse_subst::dump($r_templates);

=head1 DESCRIPTION

=head2 Preface

This module contains a parser function for epics substitution-files. The
contents of the db-file are returned in a perl hash-structure that 
can then be used for further evaluation.

=head2 Implemented Functions:

=over 4

=item *
 
B<parse()>

  my $r_templates= parse_subst::parse($st);
  
This function parses a given scalar variable that must contain a 
complete substitution-file. It returns a reference to a hash, where 
the parsed datais stored. 

=back

=head2 hash-structure

Each template-name is a key in the template-hash. It is a reference to 
a sub-hash that contains the data for that template. 

The sub-hash contains numerical keys for each instantiation of that
template, starting with "0".

Each instantiation hash contains a key for each field name that 
gives the value of that field. Note that undefined fields-values are 
empty strings (""), not the perl undef-value.

Example of a hash that parse() returns:
  
  $r_templates= { 'acsm.template' => 
                          { '0' => {
                                     'MCHAN' => 'A',
                                     'MNAME' => 'PVBU49ID8R:',
                                     'MNUM' => '0',
                                     'BASE' => 'U49ID8R:'
                                   },
                            '1' => {
                                     'MCHAN' => 'B',
                                     'MNAME' => 'PHBU49ID8R:',
                                     'MNUM' => '1',
                                     'BASE' => 'U49ID8R:'
                                   },
		          }
			  
 
=head1 AUTHOR

Goetz Pfeiffer,  goetzp@gmx.net

=head1 SEE ALSO

perl-documentation

=cut


