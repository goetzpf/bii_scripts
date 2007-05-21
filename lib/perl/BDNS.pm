package BDNS;

require Exporter;

our @ISA = qw(Exporter);
our @EXPORT_OK = qw(parse $MAXLENGTH %pfam %psdom %pdom);
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
$psdom{B} = $psdom{global} . "DST";
$psdom{F} = $psdom{global} . "LCEGMSU";
$psdom{P} = $psdom{global} . "KLS";

my $psdnum = "[0-9]*";

our %pdom;
$pdom{global} = "CGLV";
$pdom{B} = $pdom{global} . "BIMRT";
$pdom{F} = $pdom{global} . "ADEFS";
$pdom{P} = $pdom{global} . "TMR";

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

1;
