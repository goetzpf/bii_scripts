package parse_subst;

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
use Carp;

our $old_parser=0;

sub parse
  { my($db, $mode)= @_;
  
    $mode= "templateHash" if (!defined $mode);
  
    my $level= 'top';

# mode: default 
    my %templates;
# mode: templateList
    my @templateList;
    my $templateIdx;
    
    my $r_this_template_instance;
    my $r_this_instance_no; # old mechanism
    my $r_this_instance_fields;
    
    my @column_names;

    for(;;)
      { 
    #print $i++, " ";  

	# comments
	if ($db=~/\G\s*#[^\r\n]*/gsc) # end of file
          { 
	    next; 
	  };

	if ($level eq 'top')
	  { 
            if ($db=~/\G[\s\r\n]*$/gsc) # end of file
              { 
		last; 
	      };
            if ($db=~ /\G\s*file\s+([\w\.]+)[\s\r\n]*\{/gsc)
              { my($name)= ($1);

		if( $mode eq "templateHash" )
		{
		  $r_this_template_instance = $templates{$name};
		  if (!defined $r_this_template_instance)
		    { if ($old_parser)
			{ $r_this_template_instance= {};
			  $r_this_instance_no= 0; # old mechanism
			}
		      else
			{ $r_this_template_instance= []; }; 
		      $templates{$name}= $r_this_template_instance;
		    };
		}
		elsif( $mode eq 'templateList' )
		{ 
		  $r_this_template_instance= [$name]; 
	          $templateList[$templateIdx] = $r_this_template_instance;
                  $templateIdx++;
		}
		else
		  { die "unknown mode $mode (assertion)"; };

		
		$level='file';
		next;
	      };
	    croak "parse error 1 at byte ",pos($db)," of input stream";   
	  };
	if ($level eq 'file')
	  { 
            if ($db=~ /\G[\s\r\n]*\}/gsc)
              { 
	        $level='top';
		next;
	      };
	      
	    if ($db=~ /\G[\s\r\n]*pattern[\s\r\n]*\{/gsc)
	      { @column_names= ();
	        while ($db=~ /\G[,\s\r\n]*\"?([^\s\r\n\=\",\{\}]+)\"?/gsc)
	          { push @column_names,$1; };
		if ($db!~/\G[\s\r\n]*\}/gsc)
		  { croak "parse error 2 at byte ",pos($db),
		          " of input stream";   
                  };
	        $level='pattern_instance';
		next;
              };
	      
            if ($db=~ /\G[\s\r\n]*\{/gsc)
              { $level='file_instance';
	        $r_this_instance_fields= {};
		
		# old mechanism
		if ($old_parser)
		  { $r_this_template_instance->{$r_this_instance_no++}=
		       $r_this_instance_fields;
		  }
		else
		  { push @$r_this_template_instance,
		            $r_this_instance_fields
		  };	    
		next;
	      };
	    croak "parse error 1a at byte ",pos($db)," of input stream";   
	  }; 
	  
	if ($level eq 'pattern_instance')
	  { 
            if ($db=~ /\G[\s\r\n]*\}/gsc)
              { 
	        $level='top';
		next;
	      };
	    if ($db=~ /\G[\s\r\n]*\{/gsc)
	      { $r_this_instance_fields= {};
	      
	        # old mechanism
		if ($old_parser)
		  { $r_this_template_instance->{$r_this_instance_no++}=
		       $r_this_instance_fields;
		  }
		else
		  { push @$r_this_template_instance,
		            $r_this_instance_fields
		  };	    
		     
	        my $cnt=0;
		while ($db=~ /\G[,\s\r\n]*\"([^\"]*)\"/gsc)
	          { my $value= $1;
		    $value= "" if (!defined $value);
		    my $field= $column_names[$cnt++];
		    if (!defined $field)
		      { croak "parse 3 error at byte ",pos($db),
		              " of input stream";   
                      };
		    $r_this_instance_fields->{$field}= $value;
                  }; 
                if ($db!~ /\G[\s\r\n]*\}/gsc)
		  { croak "parse 4 error at byte ",pos($db),
		          " of input stream";   
                  };
                next;
               };       
          };
	  
	if ($level eq 'file_instance')
	  { 
            if ($db=~ /\G[\s\r\n]*\}/gsc)
              { $level='file';
		next;
	      };

            if ($db=~ /\G[\s\r\n]*(\"?[^\s\r\n\=\",\{\}]+)\"?\s*=\s*\"([^\"]*)\"\s*,?/gsc)
              { my($field,$value)= ($1,$2);
		$value= "" if (!defined $value);
		$r_this_instance_fields->{$field}= $value;
		next;
	      };
	    carp "ERROR: string: \"" . substr($db,pos($db)) . "\"\n";
	    croak "parse error 5 at byte ",pos($db)," of input stream";   
	  };
      };

#warn "am  ende der liste ist ein leerer Eintrag, häßlich, warum ???\n";
    if( $mode eq "templateHash" )
      { return(\%templates); };
    if( $mode eq 'templateList' )
      { return(\@templateList); };
    die "unknown mode $mode (assertion)";        

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
an array that contains the data for that template. 

The array contains a reference to a hash for each instantiation of that
template.

Each instantiation hash contains a key for each field name that 
gives the value of that field. Note that undefined fields-values are 
empty strings (""), not the perl undef-value.

Example of a hash that parse() returns:
  
  $r_templates= { 'acsm.template' => 
                          [  {
                               'MCHAN' => 'A',
                               'MNAME' => 'PVBU49ID8R:',
                               'MNUM' => '0',
                               'BASE' => 'U49ID8R:'
                             },
                             {
                               'MCHAN' => 'B',
                               'MNAME' => 'PHBU49ID8R:',
                               'MNUM' => '1',
                               'BASE' => 'U49ID8R:'
                             },
		          ]
			  
=head2 backwards compability:

Version 1.0 of the parser used a hash instead of the array as explained
above, with keys from "0" to .. "n". If you want a template-hash 
structure that is still compatible to this, set C<$old_parser> to 1 like
this:
	
  $parse_subst::old_parser=1;
	

=head1 AUTHOR

Goetz Pfeiffer,  goetzp@gmx.net

=head1 SEE ALSO

perl-documentation

=cut


