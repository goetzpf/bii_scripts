package makeDocStyle;

# Copyright 2022 Helmholtz-Zentrum Berlin für Materialien und Energie GmbH
# <https://www.helmholtz-berlin.de>
#
# Author: Bernhard Kuner <bernhard.kuner@helmholtz-berlin.de>
# Contributions by:
#         Thomas Birke <Thomas.Birke@helmholtz-berlin.de>
#         Benjamin Franksen <Benjamin.Franksen@helmholtz-berlin.de>
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
{   my ($title,$filetime,$user,$css) = @_;

  my $user_html = defined $user ? "	<META NAME=\"AUTHOR\" CONTENT=\"$user\">\n" : "";
  my $filetime_html = defined $filetime ? "	<META NAME=\"CREATED\" CONTENT=\"$filetime\">\n" : "";
  if (!defined $css)
    { $css="http://www-old.bessy.de/~kuner/makeDocs/docStyle.css"; };
    
  my $fileHeader = "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 3.2//EN\">\n".
    "<HTML>\n".
    "<HEAD>\n".
    "	<TITLE>$title</TITLE>\n".$user_html.$filetime_html.
    "   <link rel=stylesheet type=\"text/css\" href=\"$css\">\n".
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
