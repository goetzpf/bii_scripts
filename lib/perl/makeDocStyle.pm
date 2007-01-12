package makeDocStyle;
BEGIN {

use Exporter   ( 
);
use vars       qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

# set the version number of the module to enable version checking
$VERSION     = 1.0;

@ISA       = qw(Exporter);
@EXPORT_OK = qw(    
                 );
%EXPORT_TAGS = ( );     # eg: TAG => [ qw!name1 name2! ],
@EXPORT = qw(blabla);
};

sub blabla
{   my ($title,$filetime,$user) = @_;

  my $fileHeader = "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 3.2//EN\">\n".
    "<HTML>\n".
    "<HEAD>\n".
    "	<TITLE>$title</TITLE>\n".
    "	<META NAME=\"AUTHOR\" CONTENT=\"$user\">\n".
    "	<META NAME=\"CREATED\" CONTENT=\"$filetime\">\n".
    "<STYLE>\n".
    "html{\n".
    "       background-color:#FFFFFF;\n".
    "       color:#000; /*T1*/\n".
    "	    margin-left:2%;\n".
    "	    margin-right:2%;\n".
    "}\n".
    "body {\n".
    "       color:#000; /*T1*/\n".
    "}\n".
    "hr {\n".
    "       color:#ccc; /*BO7*/\n".
    "       background-color:#ccc; /*BO7*/\n".
    "	    height:1px;\n".
    "	    border:none;\n".
    "}\n".
    "pre, code, tt {\n".
    "       background-color:#FDFAF1;\n".
    "       color:#7A4707; /*T6*/\n".
    "	    margin-left:4%;\n".
    "	    margin-right:4%;\n".
    "}\n".
    "h1, h2, h3, h4, h5, h6 {\n".
    "       color:#a00; /*T5*/\n".
    "       background-color:#FDFAF1;\n".
    "       border-color:#E9E4D2; /*BO5*/\n".
    "	    border-width:0 0 2px 1px;\n".
    "	    border-style:solid;\n".
    "}\n".
    "h1{\n".
    "       line-height:200%;\n".
    "	    font-size:120%;\n".
    "	    text-align:center;\n".
    "}\n".
    "h1 a:link,\n".
    "h1 a:visited {\n".
    "       color:#a00; /*T5*/\n".
    "}\n".
    "h1 a:hover {\n".
    "       color:#FBF7E8; /*T3*/\n".
    "}\n".
    ".grayText {\n".
    "	color:#8E9195; /*T8*/\n".
    "}\n".
    ".grayText a:link,\n".
    ".grayText a:visited {\n".
    "	color:#8E9195; /*T8*/\n".
    "}\n".
    ".grayText a:hover {\n".
    "	color:#FBF7E8; /*C3*/\n".
    "}\n".
    "p {\n".
    "	 margin:1em 0 0 0;\n".
    "}\n".
    "table {\n".
    "    border-collapse:separate;\n".
    "}\n".
    "th {\n".
    "	 line-height:1.15em;\n".
    "}\n".
    "strong, b {\n".
    "	 font-weight:bold;\n".
    "}\n".
    "\n".
    "/* put overflow pre in a scroll area */\n".
    "pre {\n".
    "    width:100%;\n".
    "}\n".
    "html>body pre { /* hide from IE */\n".
    "	 /*\*/ overflow:auto !important; /* */ overflow:scroll; width:auto; /* for Mac Safari */\n".
    "}\n".
    "/* IE behavior for pre is defined in twiki.pattern.tmpl in conditional comment */\n".
    "ol, ul {\n".
    "	 margin-top:0;\n".
    "}\n".
    "ol li, ul li {\n".
    "	 line-height:1.4em; /*S1*/\n".
    "}\n".
    "\n".
    ".twikiRight {\n".
    "	 position:relative;\n".
    "	 float:right;\n".
    "	 display:inline;\n".
    "	 margin:0;\n".
    "}\n".
    "</STYLE>\n".
    "</HEAD>\n".
    "<BODY>\n".
    "<H1>$title</H1>\n".
    "<P> last update: $filetime by $user</P>\n\n";


  my $fileFooter = "<\DIV><span class=\"twikiRight twikiPageNav grayText\"></span>\n".
    "<br class=\"twikiClear\"></div><div class=\"twikiHidden\">\n".
    "<hr>End of topic<br><hr></div></div></div><div class=\"twikiBottomBar\">\n".
    "<div class=\"twikiBottomBarContents\"><span class=\"grayText\">\n".
    "<P><font size\"-1\">Bessy System Documentation for </font><font size=\"+1\">$title</font>\n".
    "</span></div></div>\n".
    "</BODY>\n</HTML>\n";
    return ($fileHeader,$fileFooter);
}
1;
