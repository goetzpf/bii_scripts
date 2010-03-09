package BDNS;

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


require Exporter;

our @ISA = qw(Exporter);
our @EXPORT_OK = qw(parse setOrder cmpNames sortNames $MAXLENGTH %pfam %psdom %pdom);
our $VERSION = 1.00;

use strict;

our $MAXLENGTH = 22;

# Es gibt ein Problem, wenn facility=P und entweder die Subdomain mit K beginnt oder
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
$pfam{global} = "BCFGHIKLMNOPQRVWYZ";
$pfam{B} = $pfam{global};
$pfam{F} = $pfam{global} . "ST";
$pfam{P} = $pfam{global};

my $pcnt = "[0-9]*";

our %psdom;
$psdom{global} = "BUX";
$psdom{B} = $psdom{global} . "DLST";
$psdom{F} = $psdom{global} . "LCEGMSU";
$psdom{P} = $psdom{global} . "KLS";

my $psdnum = "[0-9]*";

our %pdom;
$pdom{global} = "CGLV";
$pdom{B} = $pdom{global} . "BIMRT";
$pdom{F} = $pdom{global} . "DEHLRS";
$pdom{P} = $pdom{global} . "TMR";

our $pfac;
$pfac = "FP";

my $re = "\\A($pmem)"
    . "($pind)?"
    . "((([$pfam{B}])($pcnt)([$psdom{B}]$psdnum)?([$pdom{B}]))|"
    .  "(([$pfam{F}])($pcnt)([$psdom{F}]$psdnum)([$pdom{F}])F)|"
    .  "(([$pfam{P}])($pcnt)([$psdom{P}]$psdnum)?([$pdom{P}])P))\\Z";

sub parse {
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
    if ($subdomain eq "L" && $domain ne "I" ) {
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

my %namePart2idx = (
    "MEMBER"=>0, 
    "INDEX"=>2,
    "SUBINDEX"=>3,
    "FAMILY"=>4,
    "COUNTER"=>5,
    "SUBDOMPRE"=>8,
    "SUBDOMNUMBER"=>9,
    "DOMAIN"=>10,
    "FACILITY"=>11
    );

my $rA_order = [11,10,8,9,0,2,3,4,5]; # default order
sub setOrder
{   my ($o) = @_;
    use Data::Dumper; print ref($o), Dumper($o);
    if( ref($o) eq 'ARRAY')
    {
    	$rA_order = [map{ $namePart2idx{$_}; } @$o];
    }
    else
    {
    	$rA_order = [map{ $namePart2idx{$_}; } split /[,\s]+/, $o];
    }
    warn "illegal order parameter" if(scalar(@$rA_order)<=0);
}

sub cmpNames
{   my($a,$b)=@_;

    $a =~ /([\w\d-]*)$/;    # this matches a DEVICENAME and a /GADGET/PATH/DEVICENAME 
    $a = $1;
    $b =~ /([\w\d-]*)$/;
    $b = $1;
#print "compare ($a,$b): ";
    my @A= parse($a);
    my @B= parse($b);
#print "compare ($a,$b): A=(",join(',',@A),") B=(",join(',',@B),") \n\t";
    my $cmp=0;
    foreach my $i (@$rA_order)
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

sub sortNames
{   my($rA_names) = @_;
    return sort {BDNS::cmpNames($a,$b)} @$rA_names;
}
1;
