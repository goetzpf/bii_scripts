package BDNS;

require Exporter;

our @ISA = qw(Exporter);
our @EXPORT_OK = qw(parse);
our $VERSION = 1.00;

$pmem = "[A-Z]{1,6}";
$pind = "([0-9]{1,3})(-([0-9]{1,2}))?";

$pfam{B} = "BCFGHIKLMNOPQRVWYZ";
$pfam{F} = "BCFGHIKLMNOPQRSTVWYZ";
$pfam{P} = "BCFGHIKLMNOPQRVWYZ";

$pcnt = "[0-9]{0,2}";

$psdom{B} = "DSTX";
$psdom{F} = "LCEGMSUX";
$psdom{P} = "KLSX";

$psdnum = "[0-9]{0,3}";

$pdom{B} = "BIMRTCGLV";
$pdom{F} = "ACDEFGLSV";
$pdom{P} = "BIMRTCGLV";

$re = "\\A($pmem)"
    . "($pind)?"
    . "((([$pfam{B}])($pcnt)([$psdom{B}]$psdnum)?([$pdom{B}]))|"
    .  "(([$pfam{F}])($pcnt)([$psdom{F}]$psdnum)([$pdom{F}])F?)|"
    .  "(([$pfam{P}])($pcnt)([$psdom{P}]$psdnum)([$pdom{P}])P))\\Z";

sub parse {
  my $devname = shift;
  my $facility;
  $devname =~ tr/a-z/A-Z/;
  my (
    $member,
    $allindex, 
      $index,
      $dashsubindex,
        $subindex,
    $fcsd
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

  if ("$subdomain$domain" =~ /^[RB]$/) {
    $subdomain = $counter;
    $counter = undef;
  }

  my $allsubdomain = $subdomain . $domain;

  return ($member, $allindex, $index, $subindex, $family, $counter,
    $allsubdomain, $subdomain, $subdompre, $subdomnumber, $domain, $facility);
}

1;
