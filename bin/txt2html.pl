eval 'exec perl -w -p00 -S $0 ${1+"$@"}' # -*- Mode: perl -*-
    if 0;
# the above is a more portable way to find perl
#!/usr/bin/perl -w -p00
# text2html - trivial html encoding of normal text
# -p means apply this script to each record.
# -00 mean that a record is now a paragraph

use HTML::Entities;
$_ = encode_entities($_, "\200-\377");

if (/^\s/) {
    # Paragraphs beginning with whitespace are wrapped in <PRE> 
    s{(.*)$}        {<PRE>\n$1</PRE>\n}s;           # indented verbatim
} else {
    s{^-{3,}\s*$} {<hr>}gm; # convert "---" to <hr>
    s{^([\w\.]+:)\s*$} {$1<br>}gm;   # add <br> after ":"
    
    s{^(>.*)}       {$1<BR>}gm;                    # quoted text
    s{<URL:(.*?)>}    {<A HREF="$1">$1</A>}gs         # embedded URL  (good)
                    ||
    s{(http:\S+)}   {<A HREF="$1">$1</A>}gs;        # guessed URL   (bad)
    s{\*(\S+)\*}    {<b>$1</b>}g;         # this is *bold* here
    s{\b_(\S+)\_\b} {<EM>$1</EM>}g;                 # this is _italics_ here
    s{^}            {<P>\n};                        # add paragraph tag
}
