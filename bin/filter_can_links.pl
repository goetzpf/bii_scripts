eval 'exec perl -S $0 ${1+"$@"}' # -*- Mode: perl -*-
    if 0;
# the above is a more portable way to find perl
# ! /usr/bin/perl

#  This software is copyrighted by the BERLINER SPEICHERRING
#  GESELLSCHAFT FUER SYNCHROTRONSTRAHLUNG M.B.H., BERLIN, GERMANY.
#  The following terms apply to all files associated with the software.
#  
#  BESSY hereby grants permission to use, copy and modify this
#  software and its documentation for non-commercial, educational or
#  research purposes provided that existing copyright notices are
#  retained in all copies.
#  
#  The receiver of the software provides BESSY with all enhancements, 
#  including complete translations, made by the receiver.
#  
#  IN NO EVENT SHALL BESSY BE LIABLE TO ANY PARTY FOR DIRECT, INDIRECT,
#  SPECIAL, INCIDENTIAL OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE
#  OF THIS SOFTWARE, ITS DOCUMENTATION OR ANY DERIVATIVES THEREOF, EVEN 
#  IF BESSY HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#  
#  BESSY SPECIFICALLY DISCLAIMS ANY WARRANTIES, INCLUDING, BUT NOT LIMITED
#  TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
#  PURPOSE, AND NON-INFRINGEMENT. THIS SOFTWARE IS PROVIDED ON AN "AS IS"
#  BASIS, AND BESSY HAS NO OBLIGATION TO PROVIDE MAINTENANCE, SUPPORT,
#  UPDATES, ENHANCEMENTS OF MODIFICATIONS.


# @STATUS: release
# @PLATFORM: home bessy
# @CATEGORY: search


# [scriptname] -- describe the function here

use strict;

use FindBin;
use Getopt::Long;

use parse_db;
use canlink;

use vars qw($opt_help $opt_summary $opt_file $opt_port 
            $opt_in_cob $opt_out_cob $opt_pretty);


my $sc_version= "0.9";

my $sc_name= $FindBin::Script;
my $sc_summary= "filters lowcal can-links from a db-file";
my $sc_author= "Goetz Pfeiffer";
my $sc_year= "2005";

my $debug= 0; # global debug-switch


#Getopt::Long::config(qw(no_ignore_case));

if (!GetOptions("help|h","summary", "file|f=s", 
                "port|p=i", "in_cob=i", "out_cob=i", "pretty"
                ))
  { die "parameter error!\n"; };

if ($opt_help)
  { help();
    exit;
  };
if ($opt_summary)
  { print_summary();
    exit;
  };

# ------------------------------------------------

#die "no command-line options given!";

die "-f option missing" if (!defined $opt_file);

my $r_records= parsedb($opt_file);
#parse_db::dump($r_records);
#die;

my @can_records= can_records($r_records);

if (defined $opt_port)
  { @can_records= filter_port($opt_port, $r_records, @can_records); };

if (defined $opt_in_cob)
  { @can_records= filter_in_cob($opt_in_cob, $r_records, @can_records); };

if (defined $opt_out_cob)
  { @can_records= filter_out_cob($opt_out_cob, $r_records, @can_records); };


list_records($r_records,@can_records);

# fit in program text here

sub filter_port
  { my($port, $r_records, @can_records)= @_;

    return( grep { $r_records->{$_}->{CAN_STRUC}->{port}==$port } @can_records);
  }

sub filter_in_cob
  { my($cob, $r_records, @can_records)= @_;

    return( grep { $r_records->{$_}->{CAN_STRUC}->{in_cob}==$cob } @can_records);
  }

sub filter_out_cob
  { my($cob, $r_records, @can_records)= @_;

    return( grep { $r_records->{$_}->{CAN_STRUC}->{out_cob}==$cob } @can_records);
  }



sub list_records
  { my($r_records, @list)= @_;

    if (!defined $opt_pretty)
      { foreach my $rec (sort @list)
          { printf "%-25s -> %s\n", $rec, $r_records->{$rec}->{CAN_LINK}; };
      }
    else
      { foreach my $rec (sort @list)
          { my $st=canlink::pretty_print( %{$r_records->{$rec}->{CAN_STRUC}} );
	    print $rec," ->\n";
	    $st=~ s/^/\t/gm;
	    print $st;
	  };

      };
  }

sub can_records
  { my($r_records)= @_;
    my @can_records;

    foreach my $rec (keys %$r_records)
      { my $rs= $r_records->{$rec};
        my $dtyp= $rs->{FIELDS}->{DTYP};
	next if (!defined $dtyp);
        next if ($dtyp ne 'lowcal');
        my $linkstring= find_canlink($rs);
	if (!defined $linkstring)
	  { warn "canlink in record $rec not found " .
	         "but it should be there !";
	    next;
	  };
	$rs->{CAN_STRUC}=  
	  { canlink::decode($linkstring) };
	$rs->{CAN_LINK}= $linkstring;

        push @can_records, $rec;
      };
    return(@can_records);
  }

sub find_canlink
  { my($rec)= @_;

    my $r_fields= $rec->{FIELDS};
    foreach my $field (qw(INP OUT))
      { my $f= $r_fields->{$field};
        next if (!defined $f);
        if ($f =~ /^\@/)
	  { return($f); };
      };
    return;  
  }

sub parsedb
  { my($filename)= @_;
    local(*F);
    local($/);

    open(F,$filename) or die "unable to open $filename";
    my $st= <F>;
    close(F);
    my $r_records= parse_db::parse($st);
    return($r_records);
  }

# ------------------------------------------------

sub print_summary
  { printf("%-20s: $sc_summary\n",
           $sc_name);
  }

sub h_center
  { my($st)= @_;
    return( (' ' x (38 - length($st)/2)) . $st );
  }

sub help
  { my $l1= h_center("**** $sc_name $sc_version -- $sc_summary ****");
    my $l2= h_center("$sc_author $sc_year");
    print <<END;

$l1
$l2

Syntax:
  $sc_name {options} [arg1] [arg2]

  options:
    -h: help
    -f [file]: name of the db-file
    -p [port]: port to filter
    --in_cob [cob] in-cob to filter
    --out_cob [cob] out-cob to filter
    --pretty : format the output in a human-readble 
       form, otherwise the CAN link is printed
    --summary: give a summary of the script
END
  }

