package BDNS;

## BDNS Name parser
# ******************
#

# Copyright 2015 Helmholtz-Zentrum Berlin für Materialien und Energie GmbH
# <https://www.helmholtz-berlin.de>
#
# Author: Benjamin Franksen <Benjamin.Franksen@helmholtz-berlin.de>
# Contributions by:
#         Thomas Birke <Thomas.Birke@helmholtz-berlin.de>
#         Bernhard Kuner <bernhard.kuner@helmholtz-berlin.de>
#         Goetz Pfeiffer <Goetz.Pfeiffer@helmholtz-berlin.de>
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


require Exporter;

our @ISA = qw(Exporter);
our @EXPORT_OK = qw(parse setOrder cmpNames sortNames $MAXLENGTH %pfam %psdom %pdom);
our $VERSION = 1.00;

use strict;

our $MAXLENGTH = 22;

## Es gibt ein Problem, wenn facility=P und entweder die Subdomain mit K beginnt oder
# die Subdomain leer ist, der letzte Buchstabe im Member einer gültigen Family
# entspricht und die family K ist. In diesem Fall ist ein eindeutiges Parsen nicht möglich!
#
# Beispiele:
#
# 1.AICK3RP kann sowohl
#   a. AI  AI                 - member im regexp hier "non-greedy"
#      C   family control-system
#      K3  subdomain K3
#      R   Ring
#      P   PTB
#   als auch
#   b. AIC AIC                - member im regexp hier "greedy"
#      K   family kicker/septa
#      3   counter 3
#      R   Ring
#      P   PTB
#   bedeuten
#
# 2.KIK1RP kann sowohl 
#   a. K   K                  - member im regexp hier "non-greedy"
#      I   family insertion-device
#      K1  subdomain K1
#      R   Ring
#      P   PTB
#   als auch
#   b. KI  KI                 - member im regexp hier "greedy"
#      K   family kicker/septa
#      1   counter 1
#      R   Ring
#      P   PTB
#   bedeuten
#
# Im ersten Beispiel war der erste Fall gewünscht (1.a.), im zweiten der zweite (2.b.)!
# Blödes Dilemma...
#
# Aktuell ist der Parser auf "non-greedy" gestellt, was zur Folge hat,
# daß im Fall KIK1RP eine subdomain angegeben werden muss(!) - also KIK1L4RP
# um den Namen korrekt aufzulösen. [sic]
#

my $pmem = "[A-Z]+?";
my $pind = "([0-9]+)(-([0-9]+))?";

our %pfam;
$pfam{global} = "BCEFGHIKLMNOPQRVWYZ";
$pfam{B} = $pfam{global};
$pfam{F} = $pfam{global} . "ST";
$pfam{P} = $pfam{global};

my $pcnt = "[0-9]*";

our %psdom;
$psdom{global} = "BUX";
$psdom{B} = $psdom{global} . "DLST";
$psdom{F} = $psdom{global} . "ALEGMS";
$psdom{P} = $psdom{global} . "KLS";

my $psdnum = "[0-9]*";

our %pdom;
$pdom{global} = "CGLRVX";
$pdom{B} = $pdom{global} . "BIMST";
#$pdom{F} = $pdom{global} . "DEIHLRS";
$pdom{F} = $pdom{global} . "AEHST";
$pdom{P} = $pdom{global} . "TM";

our $pfac;
$pfac = "FP";

our $re = "\\A($pmem)"
    . "($pind)?"
    . "((([$pfam{B}])($pcnt)([$psdom{B}]$psdnum)?([$pdom{B}]))|"
    .  "(([$pfam{F}])($pcnt)([$psdom{F}]$psdnum)([$pdom{F}])F)|"
    .  "(([$pfam{P}])($pcnt)([$psdom{P}]$psdnum)?([$pdom{P}])P))\\Z";

## Parse device name and return array of:
#
#    (member,allindex,index,subindex,family,counter,allsubdomain,subdomain,subdompre,subdomnumber,domain,facility)
sub parse 
{
  my $devname = shift;
  if (length($devname) > $MAXLENGTH) {
    return; # mismatch
  }
  my ($facility,$family,$counter,$subdomain,$domain);
  $devname =~ tr/a-z/A-Z/;
  my (
    $member,
    $allindex, 
      $index,
      $dashsubindex,
        $subindex,
    $fcsd,
      $ring,
        $rfamily,
        $rcounter,
        $rsubdomain,
        $rdomain,
      $fel,
        $ffamily,
        $fcounter,
        $fsubdomain,
        $fdomain,
      $ptb,
        $pfamily,
        $pcounter,
        $psubdomain,
        $pdomain
    ) = ($devname =~ /$re/);
  if (defined $ring) {
    ($family,$counter,$subdomain,$domain) = ($rfamily,$rcounter,$rsubdomain,$rdomain);
    $facility = "";
    if (($subdomain =~ /L[0-9]*/) && ($domain ne "I") ) {
      return;
    }
  }
  elsif (defined $fel) {
    ($family,$counter,$subdomain,$domain) = ($ffamily,$fcounter,$fsubdomain,$fdomain);
    $facility = "F";
  }
  elsif (defined $ptb) {
    ($family,$counter,$subdomain,$domain) = ($pfamily,$pcounter,$psubdomain,$pdomain);
    $facility = "P";
  }
  else {
    return; # mismatch
  }
  my ($subdompre, $subdomnumber) = ($subdomain =~ /([A-Z])(.*)/);

  my $allsubdomain = $subdomain . $domain;

  return ($member, $allindex, $index, $subindex, $family, $counter,
    $allsubdomain, $subdomain, $subdompre, $subdomnumber, $domain, $facility);
}

sub parse_named
  { my($devname)= @_;

    my @elms= parse($devname);
    if ($#elms<0)
      { return {}; };
    my %d= ( "member"          => $elms[0],
             "allindex"        => $elms[1],
             "index"           => $elms[2],
             "subindex"        => $elms[3],
             "family"          => $elms[4],
             "counter"         => $elms[5],
             "allsubdomain"    => $elms[6],
             "subdomain"       => $elms[7],
             "subdompre"       => $elms[8],
             "subdomnumber"    => $elms[9],
             "domain"          => $elms[10],
             "facility"        => $elms[11],
           );
   return(\%d);
  }

    

my %_namePart2idx = (
    "MEMBER"=>0, 
    "INDEX"=>2,
    "SUBINDEX"=>3,
    "FAMILY"=>4,
    "COUNTER"=>5,
    "SUBDOMPRE"=>8,
    "SUBDOMNUMBER"=>9,
    "DOMAIN"=>10,
    "FACILITY"=>11,
    "0" =>0, 
    "1" =>1, 
    "2" =>2, 
    "3" =>3, 
    "4" =>4, 
    "5" =>5, 
    "6" =>6, 
    "7" =>7, 
    "8" =>8, 
    "9" =>9, 
    "10"=>10,
    "11"=>11,
    );

my $rA_defaultOrder = [11,10,8,9,0,2,3,4,5]; # default order
my $rA_order = $rA_defaultOrder; # default order
## Sort list of names according to the sortorder defined in setOrder or default '[11,10,8,9,0,2,3,4,5]'
sub sortNamesBy
{   my($rA_names,$r_order)= @_;
    my $sortfunc= sub { return(cmpNamesBy(@_,$r_order)); };
    return sort {$sortfunc->($a,$b)} @$rA_names;
}

sub sortNames
{   my($rA_names) = @_;
    return sortNamesBy($rA_names,$rA_order);
}

## Set sortorder by index or namelist or string
#
#    0       1         2      3         4       5        6             7          8          9             10      11
#    MEMBER, ALLINDEX, INDEX, SUBINDEX, FAMILY, COUNTER, ALLSUBDOMAIN, SUBDOMAIN, SUBDOMPRE, SUBDOMNUMBER, DOMAIN, FACILITY
#    Name: VMI1-2V5S3M
#    VMI     1-2       1      2         V       5        S3M           S3         S          3             M
#
#  Example for order definition synatx:
#
# - BDNS::setOrder([qw(MEMBER ALLINDEX INDEX)])
# - BDNS::setOrder("0,1,2")
# - BDNS::setOrder([0,1,2])
#
#  Reset to default sortorder:
#
#    BDNS::setOrder("DEFAULT")
sub mkOrder
{   my ($order) = @_;
    my $r_order;
#use Data::Dumper; print ref($order), Dumper($order);
    if( $order eq 'DEFAULT')
    {
    	$r_order = $rA_defaultOrder;
    }
    elsif( ref($order) eq 'ARRAY')
    {
    	$r_order = [map{ $_namePart2idx{$_}; } @$order];
    }
    else
    {
    	$r_order = [map{ $_namePart2idx{$_}; } split /[,\s]+/, $order];
    }
#    print "Order: '",join("','",@$r_order),"'\n";
    warn "illegal order parameter" if(scalar(@$r_order)<=0);
    return $r_order;
}

sub setOrder
{   
    $rA_order= mkOrder(@_);
}

## Compare function, used in function 'sortNames()'
sub cmpNamesBy
{   my($a,$b,$r_order)=@_;

    $a =~ /([\w\d-]*)$/;    # this matches a DEVICENAME and a /GADGET/PATH/DEVICENAME 
    $a = $1;
    $b =~ /([\w\d-]*)$/;
    $b = $1;
#print "compare ($a,$b): ";
    my @A= parse($a);
    my @B= parse($b);
#print "compare ($a,$b): A=(",join(',',@A),") B=(",join(',',@B),") \n\t";
    my $cmp=0;
    foreach my $i (@$r_order)
    {
    	$a = $A[$i];
    	$b = $B[$i];
#print "($a,$b) ";
	$a = "" unless defined $a;
	$b = "" unless defined $b;
    	if( ($a=~ /\d+/) && ($b=~ /\d+/))
	{
	    $cmp = $a <=> $b;
	    last unless $cmp == 0;
	}
	else
	{
	    $cmp = $a cmp $b;
	    last unless $cmp == 0;
	}
    }
#print "return: $cmp\n";
    return $cmp;
}

sub cmpNames
{   my($a,$b)=@_;
    return cmpNamesBy($a,$b,$rA_order);
}

1;
