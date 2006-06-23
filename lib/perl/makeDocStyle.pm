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
# OLD Style
#    "	<STYLE>\n".
#    "	<!--\n".
#    " pre, table {background-color:#F0F0F0;}\n".
#    " body{background-color:#FFFFFF;margin-left:60px;}\n".
#    " hr{margin-left:-60px;}\n".
#    " h1, h2, h3, h4, h5, h6 { font-family:Tahoma, Arial; margin-left:-50px;}\n".
#    " a:visited { text-decoration:none; color:#000088; }\n".
#    " a:link    { text-decoration:none; color:#000088;}\n".
#    " a:active  { text-decoration:none; color:#000088; }\n".
#    " a:hover   { text-decoration:underline; color:#000088;}\n".
#    "	-->\n".
#    "	</STYLE>\n</HEAD>\n<BODY>\n".
#    "<TABLE style=\"background-color:#FFFFFF\" WIDTH=\"100%\"><TR>\n".
#    "<TD><FONT><H1>$title</FONT></H1></TD>\n".
#    "<TD WIDTH=200><IMG WIDTH=200 SRC=\"/images/BESSYLogo_sw_rgb300.jpg\"></TD>".
#    "</TR></TABLE>\n".
#    "<P ALIGN=\"right\"><FONT SIZE=\"-1\" >last Modified: by $user $filetime </FONT></P>\n";
#
#  my $fileFooter = "</BODY>\n</HTML>\n";

# Now: take twiki style
    "  <style type=\"text/css\" media=\"all\">\n".
    "	\@import url(\"http://twiki.bessy.de/pub/TWiki/PatternSkin/layout.css\");\n".
    "	\@import url(\"http://twiki.bessy.de/pub/TWiki/PatternSkin/style.css\");\n".
    "	\@import url(\"http://www-csr.bessy.de/control/Docs/MLT/kuner/autoDocs/DocumentationApp/overwrite.css\");\n".
    "  </style>\n".
    "</HEAD>\n<BODY style=\"color: rgb(0, 0, 0);\" class=\"twikiViewPage\" alink=\"#ee0000\" link=\"#0000ee\" vlink=\"#551a8b\">\n".
    "<H1>$title</H1>\n".
    "<span class=\"twikiGrayText\"><FONT SIZE=\"-1\" ><P>Bessy System Documentation\n".
    " created: by $user $filetime</FONT></P></span>\n".
    "<DIV CLASS=\"twikiMain\">\n";

  my $fileFooter = "<\DIV><span class=\"twikiRight twikiPageNav twikiGrayText\"></span>\n".
    "<br class=\"twikiClear\"></div><div class=\"twikiHidden\">\n".
    "<hr>End of topic<br><hr></div></div></div><div class=\"twikiBottomBar\">\n".
    "<div class=\"twikiBottomBarContents\"><span class=\"twikiGrayText\">\n".
    "<P><font size\"-1\">Bessy System Documentation for </font><font size=\"+1\">$title</font>\n".
    "</span></div></div>\n".
    "</BODY>\n</HTML>\n";
    return ($fileHeader,$fileFooter);
}
1;
