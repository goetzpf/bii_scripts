package BDNS;

require Exporter;

our @ISA = qw(Exporter);
our @EXPORT_OK = qw(parse $MAXLENGTH %pfam %psdom %pdom);
our $VERSION = 1.00;

use strict;

our $MAXLENGTH = 22;

my $pmem = "[A-Z]+?";
my $pind = "([0-9]+)(-([0-9]+))?";

our %pfam;
$pfam{global} = "BCFGHIKLMNOPQRVWYZ";
$pfam{B} = $pfam{global};
$pfam{F} = $pfam{global} . "ST";
$pfam{P} = $pfam{global};

my $pcnt = "[0-9]*";

our %psdom;
$psdom{global} = "X";
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
    $facility = "B";
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

  # problem with fac=P and fam~[KL] or sdom~[KL]
#  if ( ( $facility eq "P" ) &&
#       ( ( ( $family =~ /[KL]/ ) && ( $subdomain eq "" ) ) ||
#	 ( $subdomain =~ /[KL].*/ ) && ( $allindex eq "" ) ) ) {
#    return;
#  }

#  if ("$subdomain$domain" =~ /^[RB]$/) {
#    $subdomain = $counter;
#    $counter = undef;
#  }

  my $allsubdomain = $subdomain . $domain;

  return ($member, $allindex, $index, $subindex, $family, $counter,
    $allsubdomain, $subdomain, $subdompre, $subdomnumber, $domain, $facility);
}

1;
