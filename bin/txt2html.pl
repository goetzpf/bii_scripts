eval 'exec perl -w -p00 -S $0 ${1+"$@"}' # -*- Mode: perl -*-
    if 0;
# the above is a more portable way to find perl

# Copyright 2015 Helmholtz-Zentrum Berlin für Materialien und Energie GmbH
# <https://www.helmholtz-berlin.de>
#
# Author: Goetz Pfeiffer <Goetz.Pfeiffer@helmholtz-berlin.de>
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

#!/usr/bin/perl -w -p00

# taken from perl cookbook with slight modifications

# text2html - trivial html encoding of normal text
# -p means apply this script to each record.
# -00 mean that a record is now a paragraph
use HTML::Entities;
$_ = encode_entities($_, "\200-\377");
if (/^\s+\S+/) {
    # Paragraphs beginning with whitespace are wrapped in <PRE> 
    s{(.*)$}        {<PRE>\n$1</PRE>\n}gs;           # indented verbatim
} else {
    s{^-{3,}\s*$} {<hr>}gm; # convert "---" to <hr>
    s{^([\w\.]+:)\s*$} {$1<br>}gm;   # add <br> after ":"
    s{^(>.*)}       {$1<BR>}gm;                    # quoted text
    s{<URL:(.*?)>}    {<A HREF="$1">$1</A>}gs         # embedded URL  (good)
                    ||
    s{(http:\S+)}   {<A HREF="$1">$1</A>}gs;        # guessed URL   (bad)
    s{\*([\w\. -]+)\*}    {<b>$1</b>}g;         # this is *bold* here
    s{\b_(\S+)\_\b} {<EM>$1</EM>}g;                 # this is _italics_ here
    s{^}            {<P>\n};                        # add paragraph tag
}
