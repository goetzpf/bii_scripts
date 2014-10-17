package analyse_db;

# This software is copyrighted by the
# Helmholtz-Zentrum Berlin fuer Materialien und Energie GmbH (HZB),
# Berlin, Germany.
# The following terms apply to all files associated with the software.
# 
# HZB hereby grants permission to use, copy and modify this
# software and its documentation for non-commercial, educational or
# research purposes provided that existing copyright notices are
# retained in all copies.
# 
# The receiver of the software provides HZB with all enhancements, 
# including complete translations, made by the receiver.
# 
# IN NO EVENT SHALL HZB BE LIABLE TO ANY PARTY FOR DIRECT, INDIRECT,
# SPECIAL, INCIDENTAL OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE
# OF THIS SOFTWARE, ITS DOCUMENTATION OR ANY DERIVATIVES THEREOF, EVEN 
# IF HZB HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
# 
# HZB SPECIFICALLY DISCLAIMS ANY WARRANTIES, INCLUDING, BUT NOT LIMITED
# TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
# PURPOSE, AND NON-INFRINGEMENT. THIS SOFTWARE IS PROVIDED ON AN "AS IS"
# BASIS, AND HZB HAS NO OBLIGATION TO PROVIDE MAINTENANCE, SUPPORT,
# UPDATES, ENHANCEMENTS OR MODIFICATIONS.


use Data::Dumper;
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
DOL1
DOL2
DOL3
DOL4
DOL5
DOL6
DOL7
DOL8
DOL9
DOLA
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
INPM
INPN
INPO
INPP
INPQ
INPR
INPS
INPT
INPU
LNK1
LNK2
LNK3
LNK4
LNK5
LNK6
LNK7
LNK8
LNK9
LNKA
OUT
OUTA
OUTB
OUTC
OUTD
OUTE
OUTF
OUTG
OUTH
OUTI
OUTJ
OUTK
OUTL
OUTM
OUTN
OUTO
OUTP
OUTQ
OUTR
OUTS
OUTT
OUTU
SDIS
SELL
SUBL
TSEL
);

my %dtyp_link_fields= map{ $_ => 1 } @dtyp_link_fields;
my %link_fields     = map{ $_ => 1 } @link_fields;

# Number as taken from perl FAQ, modified to allow hexadecimals too
my $dec_number      = qr/([+-]?)(?=\d|\.\d)\d*(\.\d*)?([Ee]([+-]?\d+))?/;
my $hex_number      = qr/0x[0-9a-fA-F]+/;
my $number          = qr/^($hex_number|$dec_number)$/;

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
        # is it NaN or inf ?
        # definitions here taken from strtod documentation (see manpage)
        next if ($val =~ /^(?:inf|infinity|nan|nan\([^\(\)]*\))$/i);
	if (exists ($dtyp_link_fields{$fieldname}))
	  { # maybe a hardware link ?
	    if (str_defined_different($r_fields->{DTYP},'Soft Channel'))
	      { next; };
	  };

        $val=~ s/(\s+|\s*\.)(CPP|NPP|NMS|MS|PP|CP|CA)\b/ /g;	    
	$val=~ s/[\.\s]+$//;
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
  { my($lvl, $maxlvl, $r_set, $recs, $r_records, $r_match_func)= @_;

    die "recursion too deep" if ($lvl>250);
    if ($lvl>$maxlvl)
      { 
        return;
      }
    foreach my $record (@$r_records)
      {
        # the following ensures that "shorter" paths
        # to a record that was already by a longer path 
        # stepped on, are also examined
        if (defined $r_match_func)
          {
            if (!&$r_match_func($record))
              { 
                next;
              }
          }
        my $rec_level= $r_set->{$record};
        if (defined $rec_level)
          {
            if ($rec_level <= $lvl)
              {
                next;
              }
          }
        $r_set ->{$record} = $lvl;
        r_linkset($lvl+1, $maxlvl, $r_set, $recs, 
                  [references_list($recs, $record)], 
                  $r_match_func);
        r_linkset($lvl+1, $maxlvl, $r_set, $recs, 
                  [referenced_by_list($recs, $record)],
                  $r_match_func);
      }
  }

sub linkset_hash
# returns a set of all records that are directly and indirectly 
# connected to this record
# returns a sorted list
  { my($recs, $r_recnames, $maxlvl, $r_match_func)= @_;

    error(__LINE__,"1st param must be a hash ref") if (ref($recs) ne 'HASH');
    my %set;
    r_linkset(0, $maxlvl, \%set, $recs, $r_recnames, $r_match_func);
    return(\%set);
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

sub str_defined_different
# internal function
# returns 1 when $str is actually defined
# to be different from $compare_to
# returns undef when $str is empty or undefined
  { my($str,$compare_to)= @_;

    return if (!defined $str);
    return if ($str eq '');
    return($str ne $compare_to);
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

  my $r_h= linkset_hash($records,$r_recnames,$maxlevel)

This function returns a hash-reference containing all records that are related
to the records given in the list reference $r_recnames. $maxlevel is the maxmum
allowed distance.  The hash-value is the minimum distance to one of the records
given in $r_recnames.
Example:

  { "RECORD_START" => 0,
    "RECORDA"      => 1,
    "RECORDB"      => 2,
  }

In this example RECOORD_START is the record itself (level0), RECORDA has a
distance of 1 (level 1), RECORDB has a distance of 2 (level 2).

B<rem_capfast_defaults()>

  rem_capfast_defaults($records)

This function removes all fields that have the still their default 
value as it is defined in capfast.

=back

=head1 AUTHOR

Goetz Pfeiffer,  Goetz.Pfeiffer@helmholtz-berlin.de

=head1 SEE ALSO

perl-documentation

=cut


