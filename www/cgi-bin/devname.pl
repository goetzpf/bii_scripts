#!/usr/bin/env perl

# -*- perl-*-
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
#  SPECIAL, INCIDENTAL OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE
#  OF THIS SOFTWARE, ITS DOCUMENTATION OR ANY DERIVATIVES THEREOF, EVEN
#  IF BESSY HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
#  BESSY SPECIFICALLY DISCLAIMS ANY WARRANTIES, INCLUDING, BUT NOT LIMITED
#  TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
#  PURPOSE, AND NON-INFRINGEMENT. THIS SOFTWARE IS PROVIDED ON AN "AS IS"
#  BASIS, AND BESSY HAS NO OBLIGATION TO PROVIDE MAINTENANCE, SUPPORT,
#  UPDATES, ENHANCEMENTS OR MODIFICATIONS.

use strict;
use lib ("/opt/csr/lib/perl");
use BDNS;
use CGI;
use CGI::Carp qw(fatalsToBrowser);

my %fam;
$fam{B} = "parameter";
$fam{C}	= "control-system";
$fam{F}	= "frontend diagnostics";
$fam{G}	= "geodesy";
$fam{H}	= "high (radio) frequency";
$fam{I}	= "insertion device";
$fam{K}	= "kicker / septum";
$fam{L}	= "length (drift)";
$fam{M}	= "magnet";
$fam{N}	= "panel (wiring)";
$fam{O}	= "monochromator";
$fam{P}	= "power supply";
$fam{Q}	= "feedback system";
$fam{R}	= "radiation safety";
$fam{S}	= "laser system";
$fam{T} = "cryogenics";
$fam{V}	= "vacuum";
$fam{W}	= "trigger-delay etc.";
$fam{Y}	= "technical";
$fam{Z}	= "diagnostics";

my %sdom;
$sdom{C} = "bunch compressor";
$sdom{D} = "doublet section";
$sdom{E} = "extraction";
$sdom{G} = "gun";
$sdom{K} = "short section";
$sdom{LF} = "accelerating linac";
$sdom{LP} = "long section";
$sdom{M} = "monochromator/seeding";
$sdom{S} = "segment/drift";
$sdom{T} = "triplet section";
$sdom{U} = "undulator";
$sdom{X} = "room";

my %dom;
$dom{B}	= "booster synchrotron";
$dom{I}	= "injecton-line";
$dom{M}	= "microtron";
$dom{R}	= "storage ring";
$dom{T}	= "transfer-line";

$dom{A} = "accelerator";
$dom{D} = "beam dump, energy recovery";
$dom{E} = "experiment";
$dom{F} = "FEL amplifier section";
$dom{S} = "electron source";

$dom{C}	= "main control-room";
$dom{G}	= "gallery / supply area";
$dom{L}	= "beamline";
$dom{V}	= "virtual device domain (e.g. non-existent)";

my %fac;
$fac{B} = "BESSY-II";
$fac{F} = "BESSY-FEL";
$fac{P} = "PTB-MLS";

my %member;
$member{ADIDAS} = "misc. I/O";
$member{AI} = "";
$member{B} = "dipole magnet";
$member{BCONTL} = "left contrapole";
$member{BCONTR} = "right contrapole";
$member{BAC} = "dipole magnet AC";
$member{BDC} = "dipole magnet DC";
$member{CQS} = "skew quadrupole";
#$member{CTBUM} = "";
#$member{CTC} = "";
#$member{DIPS} = "";
$member{EC} = "embedded controller";
$member{FOM} = "foil monitor";
$member{GPN} = "getter pump";
$member{GV} = "gate valve";
$member{HB} = "horiz. steerer in bend";
#$member{HEINZ} = "";
#$member{HFB} = "";
#$member{HORST} = "";
$member{HS} = "horiz. Steerer";
#$member{ICTI} = "";
$member{IO} = "I/O controller";
$member{KDV} = "diagnostic kicker";
$member{KNOG} = "knockout generator";
$member{LAS} = "FSS-laser";
$member{LC} = "landau cavity";
$member{MCLK} = "master clock";
#$member{MI} = "";
#$member{MULTI} = "";
#$member{MUXV} = "";
$member{O} = "octopole";
#$member{ORBIT} = "";
#$member{PB} = "";
#$member{PBUMP} = "";
#$member{PHB} = "";
#$member{PHW} = "";
#$member{PKDV} = "";
#$member{PKE} = "";
#$member{PKI} = "";
#$member{PLUNG} = "";
$member{PPTMOD} = "PPT-modulator";
$member{PRESS} = "pressure";
#$member{PSE} = "";
#$member{PSI} = "";
#$member{PSW} = "";
#$member{PVW} = "";
#$member{PW} = "";
$member{Q} = "quadrupole";
$member{QD} = "defocussing quadrupole";
$member{QFAC} = "focussing quadrupole AC";
$member{QFDC} = "focussing quadrupole DC";
#$member{QSD} = "";
#$member{QSRSV} = "";
#$member{QST} = "";
#$member{RTMS} = "";
$member{S} = "sextupole";
$member{SCXMOD} = "Scanditronix modulator";
#$member{SM} = "";
$member{TEMP} = "temperature";
#$member{TH} = "";
#$member{TRMUX} = "";
#$member{U} = "";
#$member{UE} = "";
#$member{VFB} = "";
#$member{VMI} = "";
$member{VS} = "vert. steerer";
#$member{W} = "";
$member{WFILT} = "water filter";

my $document = new CGI;
#print $document->header();
print "Content-type: text/html\n\n";

my $devname = $document->param("search");
my $output = $document->param("format");
my $lookup = 0;
if ($document->param("lookup") eq "on") { $lookup = 1; };
my $modus = 0;
if ($output  eq "htmlwizard" && $document->param("modus") > 0 && $document->param("modus") < 3 ) {
	$modus = $document->param("modus");
} else {
	$modus = 0;
}
my $style = $document->param("style");
my $eg;
my @protocol = split("/", $ENV{'SERVER_PROTOCOL'});

if ( "$devname" eq "") {
	$devname = "Q1P2D3R";
	$eg = "e.g. the";
}
if ($output ne "htmltable" && $output ne "htmlwizard" && $output ne "htmlsnippet") {
	$output = "html";
}

$devname =~ tr/a-z/A-Z/;

if ($output eq "html" || $output eq "htmlwizard") {
	print "<html>\n"
		. "<head>\n"
		. "\t<title>Devicename-Parser</title>\n"
		. "\t<meta http-equiv=\"content-type\" content=\"text/html; charset=ISO-8859-1\">\n"
		. "\t<meta http-equiv=\"content-language\" content=\"en\">\n"
		. "\t<meta name=\"description\" content=\"BESSY names parser for devices.\">\n"
		. "\t<meta name=\"keywords\" content=\"name, device, parser, bdns, bessy, epics, identification\">\n";
	if ($style ne "") {
		print "\t<link rel=\"stylesheet\" href=\"".$style."\" type=\"text/css\">";
	}
	print "\n"
		. "\t<script language=\"JavaScript\">\n"
		. "\t<!-- \n"
		. "\t\tfunction setfocus()\n"
		. "\t\t{\n"
		. "\t\t\tdocument.devname.search.focus();\n"
		. "\t\t\tdocument.devname.search.select();\n"
		. "\t\t}\n"
		. "\t// -->\n"
		. "\t</script>\n"
		. "</head>\n"
		. "\n"
		. "<body onLoad=\"setfocus()\">\n";
}

if ($output ne "htmlsnippet") {
	print "\t<h1>Devicename-Parser</h1>\n";
}

if ($output eq "html" || ($output eq "htmlwizard" && $modus == 0)) {
	print "\n"
		. "<div name=\"bdnsparser\" id=\"parserform\">\n"
		. "\t<form method=\"GET\" action=\"".$ENV{'REQUEST_URI'}."\" name=\"devname\">\n"
		. "\t<table class=\"bdns\">"
		. "\t<thead><tr>\n"
		. "\t\t<th>Please enter a devicename (max. allowed <br />length currently is ${BDNS::MAXLENGTH} chars):</th>\n"
		. "\t</tr></thead>\n"
		. "\t<tbody><tr>\n"
		. "\t\t<td colspan=\"2\">Name: <input name=\"search\" value=\"$devname\" size=\"30\"></td>\n"
		. "\t</tr>\n"
		. "\t<tr>\n";
	if ($output ne "htmlwizard")
	{
		if ($lookup == 1) {
			print "\t\t<td colspan=\"2\"><input name=\"lookup\" checked type=\"checkbox\">Database Lookup</td>\n";
		} else {
			print "\t\t<td colspan=\"2\"><input name=\"lookup\" type=\"checkbox\">Database Lookup</td>\n";
		}
	} else {
		print "\t\t<input name=\"modus\" value=\"1\" type=\"hidden\">\n";
	}
	print "\t\t<input name=\"format\" value=\"$output\" type=\"hidden\">\n";
	print "\t</tr></tbody>\n"
		. "\t<tfoot><tr>\n"
		. "\t\t<td id=\"bdnsparser.buttons\" align=\"right\"><input type=\"submit\" value=\"Submit\">\n"
		. "\t\t\t<input type=\"reset\" value=\"Reset\"></td>\n"
		. "\t</tr></tfoot>\n"
		. "\t</table>\n"
		. "\t</form>\n"
		. "</div>\n";
}

if ($output ne "htmlwizard" || ($output eq "htmlwizard" && $modus > 0))
{

	my (
	$member, $allindex, $index, $subindex, $family, $counter,
	$allsubdomain, $subdomain, $subdompre, $subdomnumber, $domain, $facility
	) = BDNS::parse($devname);

	if ($facility eq "") {
	$facility = "B";
	}

	if (not defined $member) {
		printf( "<p class=\"bdns\" id=\"error\">Sorry, but <strong>$devname</strong> is not a valid devicename.</p>" );
	} else {
		my $vm;
		$vm = $member{$member,$family,$domain,$facility} or
			$vm = $member{$member,$family,$domain} or
			$vm = $member{$member,$family} or
		$vm = $member{$member} or
		$vm = $member . $allindex;

		$subindex = "" if not defined $subindex;
		$subdomain = "" if not defined $subdomain;
		$subdompre = "" if not defined $subdompre;
		$subdomnumber = "" if not defined $subdomnumber;

		my $sdomtext = $sdom{$subdompre};
		$sdomtext = $sdom{"$subdompre$facility"} if not defined $sdomtext;
		if ($output ne "htmlsnippet") {
			if (($output eq "htmlwizard" && $modus == 1) || $output ne "htmlwizard")
			{
				print "<div name=\"bdnsparser\" id=\"parserresult\">\n";
				print "<p>\n"
					. "$eg valid devicename <strong>$devname</strong> splits into:\n";
				print "\t<table class=\"bdns\" id=\"parserresult.table\">\n";
				print "\t<tr><th class=\"bdns\" align=\"right\">Member:</th>\n";
				print "\t    <td class=\"bdns\" id=\"parserresult.member\">$member</td><td>$vm</td><td><font size=\"-1\">min 1 char of '<strong>A</strong>'-'<strong>Z</strong>'</font></td></tr>\n";
				print "\t<tr><th class=\"bdns\" align=\"right\">Index:</th>\n";
				print "\t    <td class=\"bdns\" id=\"parserresult.index\">$index</td><td></td><td><font size=\"-1\">any number of digits</font></td></tr>\n";
				print "\t<tr><th class=\"bdns\" align=\"right\">Subindex:</th>\n";
				print "\t    <td class=\"bdns\" id=\"parserresult.subindex\">$subindex</td>$subindex<td></td><td><font size=\"-1\">any number of digits (index has at least 1 digit)</font></td></tr>\n";
				print "\t<tr><th class=\"bdns\" align=\"right\">Family:</th>\n";
				print "\t    <td class=\"bdns\" id=\"parserresult.family\">$family</td><td>$fam{$family}</td><td><font size=\"-1\">one char of '<strong>$BDNS::pfam{$facility}</strong>'</font></td></tr>\n";
				print "\t<tr><th class=\"bdns\" align=\"right\">Counter:</th>\n";
				print "\t    <td class=\"bdns\" id=\"parserresult.counter\">$counter</td><td>$counter</td><td><font size=\"-1\">any number of digits</font></td></tr>\n";
				print "\t<tr><th class=\"bdns\" align=\"right\">Subdomain:</th>\n";
				print "\t    <td class=\"bdns\" id=\"parserresult.subdomain\">$subdomain</td><td>$sdomtext $subdomnumber</td><td><font size=\"-1\">one char of '<strong>$BDNS::psdom{$facility}</strong>' followed by any number of digits digits</font></td></tr>\n";
				print "\t<tr><th class=\"bdns\" align=\"right\">Domain:</th>\n";
				print "\t    <td class=\"bdns\" id=\"parserresult.domain\">$domain</td><td>$dom{$domain}</td><td><font size=\"-1\">one char of '<strong>$BDNS::pdom{$facility}</strong>'</font></td></tr>\n";
				print "\t<tr><th class=\"bdns\" align=\"right\">Facility:</th>\n";
				print "\t    <td class=\"bdns\" id=\"parserresult.facility\"><b>" . ($facility eq "B" ? " " : $facility) . "</b></td><td><b>$fac{$facility}</b></td></tr>\n";
				print "\t</table>\n";
				print "</div>\n";
				if ($lookup == 1 && $modus != 1) {
					print "<h2>Database query result:</h2>\n";
					system ("PERL5LIB=/opt/csr/lib/perl /opt/csr/bin/bdns_lookup.pl --force --description --output=htmlset ".$devname );
				}
				if ($output eq "htmlwizard") {
					print "<a calss=\"bdns\" id=\"htmlwizard_back\" href=\"".$ENV{'SCRIPT_NAME'}."?search=$devname&$output=htmlwizard\">Back</a>";
				}
			}
		} else {
			print "\t<div name=\"bdnsparser\" id=\"parserresult\"><a href=\"".lc(shift(@protocol))."://".$ENV{'SERVER_NAME'}.$ENV{'SCRIPT_NAME'}."?search=$devname&lookup=on\" target=\"devname\">$devname</a>: $vm, $fam{$family}, ";
			if ($sdomtext ne "") { print " $sdomtext"; }
			if ($sdomtext ne "") { print " $subdomnumber"; }
			print " $dom{$domain} ". ($facility eq "B" ? " " : $facility). "</div>";
		}
		
	}
}

if ($output eq "html" || $output eq "htmlwizard") {
	print "<p>Please look at the <a href=\"http://www-csr.bessy.de/control/Docs/API/nam_conv.html\">Naming Convention for BESSY Components</a> for further information.\n";
	print "\n";
	print "<p>This URL is <pre>".lc(shift(@protocol))."://".$ENV{'SERVER_NAME'}.$ENV{'REQUEST_URI'}."</pre></p>\n";
	print "<p>To use the parser webrequest u can use the following options:\n"
		. "<ul>\n"
		. "\t<li>search - the name to pe parsed</li>\n"
		. "\t<li>lookup - the availability inside the database if set to 1</li>\n"
		. "\t<li>format - the returned format:\n"
		. "\t\t<ul>\n"
		. "\t\t\t<li>html - (default) a complete page</li>\n"
		. "\t\t\t<li>htmlwizard - splitted pag into two steps</li>\n"
		. "\t\t\t<li>htmltable - content without the page haeder and footer</li>\n"
		. "\t\t\t<li>htmlsnippet - short description and link to paged info</li>\n"
		. "\t\t</ul>\n"
		. "\t</li>\n"
		. "\t<li>style - url for the stylesheet</li>\n"
		. "\t</ul>\n"
		. "\n"
		. "</body>\n"
		. "</html>";
}

__END__