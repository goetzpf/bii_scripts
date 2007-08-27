package analyse_db;

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
    @EXPORT_OK   = qw();
}

use vars      @EXPORT_OK;

# used modules
use Carp;

use parse_db;
use capfast_defaults;

my @dtyp_link_fields= qw(INP OUT);

my @link_fields= qw(
DOL
FLNK
INP
INPA
INPB
INPC
INPD
INPE
INPF
INPG
INPH
INPI
INPJ
INPK
INPL
LNK1
LNK2
LNK3
LNK4
LNK5
LNK6
LNK7
OUT
SDIS
SELL);

my %dtyp_link_fields= map{ $_ => 1 } @dtyp_link_fields;
my %link_fields     = map{ $_ => 1 } @link_fields;

my $unquoted_rec_name   = qr/^([\w\-:\[\]<>;]+)/;
my $number              = qr/^\s*[+-]?\d+\.?\d*(|[eE][+-]?\d+)$/;

sub rec_link_fields
# $r_fields is a list of fields of a record
# return a hash-reference of field->value pairs 
# where the values
# are the names of referenced other records 
  { my($recs, $recname)= @_;
  
    error(__LINE__,"1st param must be a hash ref") if (ref($recs) ne 'HASH');

    my $r_fields= $recs->{$recname}->{FIELDS};
    my %h;
    
    foreach my $fieldname (keys %$r_fields)
      { next if (!exists $link_fields{$fieldname});
	my $val= $r_fields->{$fieldname};
	# is it empty ?
	next if ($val =~ /^\s*$/);
	# is it a number ?
	next if ($val =~ qr/$number/);
	if (exists ($dtyp_link_fields{$fieldname}))
	  { # maybe a hardware link ?
	    if ($r_fields->{DTYP} ne 'Soft Channel')
	      { next; };
	  };
	next if ($val !~ qr/$unquoted_rec_name/);
	  	  
        $val=~ s/[\. ]?(CA|CPP|NPP|NMS|MS|PP)\s*//g;	    
	$val=~ s/\s+$//;
	# remove field-names:
	$val=~ s/\.\w+$//;
	$h{$fieldname}= $val;
      };
    return(\%h);
  }

#use parse_db;
#use analyse_db;
#$r=parse_db::parse_file("idcp13.db");
#analyse_db::add_link_info($r);
#$s= analyse_db::linkset_hash($r,"UE112ID7R:AdiVDrvDstSet") 
#$ls=analyse_db::linkset_sorted_keys($s);
#print join("|",@$ls),"\n";

sub add_link_info
# adds a "LINKS" sub-hash to the record-hash
# thus hash contains tha sub-hashes
# "REFERENCES" and "REFERENCED_BY" which contain the
# record-names of the referenced records
  { my($recs)= @_;
  
    error(__LINE__,"1st param must be a hash ref") if (ref($recs) ne 'HASH');
    # delete the "LINKS" sub-hash for each record if 
    # it already exists
    foreach my $recname (keys %$recs)
      { if (exists $recs->{$recname}->{LINKS})
          { delete $recs->{$recname}->{LINKS}; };
	# create the "LINKS" entry:
	$recs->{$recname}->{LINKS}={};  
      }
    foreach my $recname (keys %$recs)
      { my $r_h= rec_link_fields($recs, $recname);
        next if (!%$r_h);
	# get a list of referenced records:
	my @f_recs= sort(map { $r_h->{$_} } (keys %$r_h));
	$recs->{$recname}->{LINKS}->{REFERENCES}= {map{$_=>1} @f_recs};
        foreach my $r (@f_recs)
	  { $recs->{$r}->{LINKS}->{REFERENCED_BY}->{$recname}= 1; };
      }
  }     

sub references_list
# returns a sorted list of records this record references
# add_link_info must have been called before
  { my($recs, $recname)= @_;
  
    error(__LINE__,"1st param must be a hash ref") if (ref($recs) ne 'HASH');
    my $r_lh= $recs->{$recname}->{LINKS};
    #if (!defined $r_lh)
    #   { parse_db::dump($recs->{$recname}); };
    error(__LINE__,"no link info found, add_link_info() was not called")
    	if (!defined $r_lh);
    my $r_h= $r_lh->{REFERENCES};
    return(sort keys %$r_h);
  }

sub referenced_by_list
# returns a sorted list of records this record is referenced by
# add_link_info must have been called before
  { my($recs, $recname)= @_;
  
    error(__LINE__,"1st param must be a hash ref") if (ref($recs) ne 'HASH');
    my $r_lh= $recs->{$recname}->{LINKS};
    error(__LINE__,"no link info found, add_link_info() was not called")
    	if (!defined $r_lh);
    my $r_h= $r_lh->{REFERENCED_BY};
    return(sort keys %$r_h);
  }

sub r_linkset
# internal function for function linkset
  { my($cnt, $lvl, $maxlvl, $r_set, $r_seen, $recs, $record)= @_;
  
    die "recursion too deep" if ($lvl>250);

    #print "rec:$record lvl:$lvl\n";

    #return if ($r_seen->{$record});
    $r_seen->{$record} = $lvl;
    $r_set ->{$record} = sprintf "%03d:%03d", $lvl, $cnt;
    
    my $mycnt=0;
    my $seen;
    foreach my $r (references_list($recs, $record))
      { $seen= $r_seen->{$r};
        # the following ensures that "shorter" paths
	# to a record that was already by a longer path 
	# stepped on, are also examined
	next if ((defined $seen) && ($seen<$lvl+1));
        if ($maxlvl)
	  { next if ($lvl>=$maxlvl); }
	r_linkset($mycnt++, $lvl+1, $maxlvl, $r_set, $r_seen, $recs, $r);
      };
    foreach my $r (referenced_by_list($recs, $record))
      { $seen= $r_seen->{$r};
        # the following ensures that "shorter" paths
	# to a record that was already by a longer path 
	# stepped on, are also examined
        next if ((defined $seen) && ($seen<$lvl+1));
        if ($maxlvl)
	  { next if ($lvl>=$maxlvl); }
	r_linkset($mycnt++, $lvl+1, $maxlvl, $r_set, $r_seen, $recs, $r);
      };
  }

sub linkset_hash
# returns a set of all records that are directly and indirectly 
# connected to this record
# returns a sorted list
  { my($recs, $recname, $maxlvl)= @_;
  
    error(__LINE__,"1st param must be a hash ref") if (ref($recs) ne 'HASH');
    my %seen;
    my %set;
    r_linkset(0, 0, $maxlvl, \%set, \%seen, $recs, $recname);
    $set{$recname}= sprintf "%03d:%03d", 0, 0;
    return(\%set);
  }

sub linkset_list
# returns a set of all records that are directly and indirectly 
# connected to this record
# returns a sorted list
  { my($recs, $recname, $maxlvl)= @_;
  
    error(__LINE__,"1st param must be a hash ref") if (ref($recs) ne 'HASH');
    my %seen;
    my %set;
    r_linkset(0, 0, $maxlvl, \%set, \%seen, $recs, $recname);
    my @list= sort keys %set;
    return(\@list);
  }

sub linkset_filter_level
  { my($r_linkset, $maxlevel)= @_;
    my %new;
    
    error(__LINE__,"1st param must be a hash ref") 
      if (ref($r_linkset) ne 'HASH');
    foreach my $k (keys %$r_linkset)
      { my($lvl,$cnt)= split(/:/,$r_linkset->{$k});
        next if ($lvl>$maxlevel);
	$new{$k}= $r_linkset->{$k};
      };
    return(\%new);
  }

sub linkset_sorted_keys
  { my($r_linkset)= @_;
  
    error(__LINE__,"1st param must be a hash ref") 
      if (ref($r_linkset) ne 'HASH');
    my @l= sort { $r_linkset->{$a} cmp $r_linkset->{$b} } (keys %$r_linkset);
    return(\@l);
    #foreach my $k (@l)
    #  { print "$k => ",$r_linkset->{$k},"\n"; };
  }

sub rem_capfast_defaults
  { my($recs)= @_;
  
    foreach my $recname (keys %$recs)
      { my $r_f= $recs->{$recname}->{FIELDS};
        my $r_def= capfast_defaults::record_defaults("longout");
	foreach my $fieldname (keys %$r_f)
	  { if ($r_f->{$fieldname} eq $r_def->{$fieldname})
	      { delete $r_f->{$fieldname}; };
	  }
      }
  }	  

sub error
#internal error function
  { my($prg_line,$str)= @_;
  
    my $err= "$str\n" .
             "line $prg_line of analyse_db.pm\n ";
    croak $err;
  }
             


1;

__END__
# Below is the short of documentation of the module.

=head1 NAME

analyse_db - a Perl module to analyse databases parsed with parse_db

=head1 SYNOPSIS

  use parse_db;
  use analyse_db;

  my $r_records= parse_db::parse_file($my_db_file);
  analyse_db::add_link_info($r_records);
  print "references: ", 
        join("\n",references_list($r_records,"myrec")),"\n";

=head1 DESCRIPTION

=head2 Preface

This module contains functions that analyse a database that was 
parsed with parse_db.

=head2 Implemented Functions:

=over 4

=item *

B<rec_link_fields()>

  my $r_h= analyse_db::rec_link_fields($recs, $recname);

This function returns a reference to a hash that contains
field-value pairs where the values are the names of 
referenced other records. The first parameter is the structure
created by parse_db::parse(), the second parameter is the 
name of the record.

=item *

B<add_link_info()>

  analyse_db::add_link_info($records);
  
This function adds information about the connections of records
to the records datastructure. The C<$records> datastructure is 
a reference to a hash. Each key is a record name that points
to another hash-reference. This structure is described in the 
documentation of the perl module parse_db. The function add_link_info
adds a new key, "LINKS" to each record hash. It points to another
hash-reference with the keys "REFERENCES" and "REFERENCED_BY". These
contain hashes that show which records are connected with this one. 

Here is a short example (note that parse_db::dump() has almost the
same function as Data::Dumper):

  use parse_db;
  use analyse_db;
  my $records= parse_db::parse_file("idcp13.db"); 
  analyse_db::add_link_info($records);
  print Dumper($records->{"UE112ID7R:AdiVDrvDstSet"})

The now output shows this:

  $VAR1 = {
            'LINKS' => {
                	 'REFERENCED_BY' => {
                                              'UE112ID7R:BaseParGapselO' => 1,
                                              'UE112ID7R:AdiUnVDrvDstC' => 1
                                            },
                	 'REFERENCES' => {
                                           'UE112ID7R:AdiUnVDrvDstICnt' => 1
                                	 }
                       },
            'TYPE' => 'longin',
            'FIELDS' => {
                          'LOLO' => '',
                          'SIOL' => '',
                        ....
			}
	 }

The record 'UE112ID7R:AdiUnVDrvDstICnt' is referenced by 
"UE112ID7R:AdiVDrvDstSet". The records 'UE112ID7R:BaseParGapselO' and
'UE112ID7R:AdiUnVDrvDstC' do themselve reference "UE112ID7R:AdiVDrvDstSet". 

=item *

B<references_list()>

  print join("\n",analyse_db::references_list($records,$my_recname)),"\n";
  
This function returns a list of records that is referenced by 
the given record.
  
=item *

B<referenced_by_list()>

  print join("\n",analyse_db::referenced_by_list($records,$my_recname)),"\n";
  
This function returns a list of records that reference 
the given record.
  
=item *

B<linkset_hash()>

  my $r_h= linkset_hash($records,$my_recname,$maxlevel)
  
This function returns a hash-reference containing all records
that are related to the given record. $maxlevel (optional)
is the maxmum allowed distance.
The hash-value contains information
about the level (distance to the first record) and number 
within that level. Example:

  { "RECORD_START" => "000:000",
    "RECORDA"      => "001:002",
    "RECORDB"      => "002:003",
  }

In this example RECOORD_START is the record itself (level0),
RECORDA has a distance of 1 (level 1) and is the third within
that level, RECORDB has a distance of 2 (level 2) and is the
fourth within that level.

B<linkset_list()>

  my $r_h= linkset_hash($records,$my_recname,$maxlevel)
  
This function returns a hash-reference containing all records
that are related to the given record. $maxlevel (optional)
is the maxmum allowed distance.

B<rem_capfast_defaults()>

  rem_capfast_defaults($records)
  
This function removes all fields that have the still their default 
value as it is defined in capfast.

=back

=head1 AUTHOR

Goetz Pfeiffer,  goetzp@gmx.net

=head1 SEE ALSO

perl-documentation

=cut


