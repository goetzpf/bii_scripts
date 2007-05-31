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
    "   <link rel=stylesheet type=\"text/css\" href=\"http://www-csr.bessy.de/control/Docs/MLT/kuner/autoDocs/makeDocs/docStyle.css\">\n".
    "</HEAD>\n".
    "<BODY>\n".
    "<H1>$title</H1>\n".
    "<P class=\"grayText\" ALIGN=\"RIGHT\"><FONT SIZE=\"-1\">last update: $filetime by $user</FONT></P>\n";

  my $fileFooter = "<hr class=\"footer\">\n".
    "<P class=\"footer\" ALIGN=\"CENTER\"><B>$title</B></P>\n".
    "</BODY>\n".
    "</HTML>\n";
    return ($fileHeader,$fileFooter);
}
1;
