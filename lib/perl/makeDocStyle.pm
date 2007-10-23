package makeDocStyle;

# This software is copyrighted by the BERLINER SPEICHERRING
# GESELLSCHAFT FUER SYNCHROTRONSTRAHLUNG M.B.H., BERLIN, GERMANY.
# The following terms apply to all files associated with the software.
# 
# BESSY hereby grants permission to use, copy and modify this
# software and its documentation for non-commercial, educational or
# research purposes provided that existing copyright notices are
# retained in all copies.
# 
# The receiver of the software provides BESSY with all enhancements, 
# including complete translations, made by the receiver.
# 
# IN NO EVENT SHALL BESSY BE LIABLE TO ANY PARTY FOR DIRECT, INDIRECT,
# SPECIAL, INCIDENTAL OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE
# OF THIS SOFTWARE, ITS DOCUMENTATION OR ANY DERIVATIVES THEREOF, EVEN 
# IF BESSY HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
# 
# BESSY SPECIFICALLY DISCLAIMS ANY WARRANTIES, INCLUDING, BUT NOT LIMITED
# TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
# PURPOSE, AND NON-INFRINGEMENT. THIS SOFTWARE IS PROVIDED ON AN "AS IS"
# BASIS, AND BESSY HAS NO OBLIGATION TO PROVIDE MAINTENANCE, SUPPORT,
# UPDATES, ENHANCEMENTS OR MODIFICATIONS.


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
