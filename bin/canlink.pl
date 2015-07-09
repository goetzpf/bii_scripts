eval 'exec perl -S $0 ${1+"$@"}' # -*- Mode: perl -*-
    if 0;                         
# the above is a more portable way to find perl
# ! /usr/bin/perl

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

# @STATUS: release
# @PLATFORM: bessy 
# @CATEGORY: can


use strict;
#activate perl-extensions:
#use lib "$ENV{HOME}/pmodules";
#use perl_site;

use Getopt::Long;
use FindBin;

use canlink;

use vars qw($opt_help $opt_decode $opt_encode $opt_short $opt_tab);

my $version= "1.0";


if (!GetOptions("help|h", "decode|d=s", "encode|e", 
                "short|s", "tab|t"))
  { die "parameter error!\n"; };		


if ($opt_help)
  { help();
    exit;
  };  

if ((!$opt_decode) && (!$opt_encode) && $opt_tab)
  { print canlink::tab_print(),"\n";
    exit(0);
  }    

if ($opt_decode)
  { while ($#ARGV>=0)
      { $opt_decode.= ' ' . shift(@ARGV); };

    my %h= canlink::decode($opt_decode);
    die if (!%h);

    if ($opt_tab)
      { print canlink::tab_print(%h),"\n";
      }
    else
      { my $st= canlink::pretty_print(%h);
	if ($opt_short)
	  { $st=~ s/\n/|/g;
            $st=~ s/\s+/ /g;
	  }
	print $st,"\n";
      }
    exit(0);
  };

#variable-type: client multiplex read-write |
#data-type : signed long|
#length : 5 bytes|
#port : 0|
#out-cob : 724|
#in-cob : 660|
#node-id : 20|
#channel-id : 5|
#in-sob : 10|
#out-sob : 11|
#multiplexor : 7|
#inhibit : 10.0 [ms]|
#timeout : 500 [ms]|

if ($opt_encode)
  {
    my %l= canlink::interview();
    print "encoded:\n";
    print canlink::encode(%l),"\n";
    exit(0);
  };

print "option missing, enter \"-h\" for help \n";

sub help
  { print <<END;

                  **** $FindBin::Script $version ****

Syntax: $FindBin::Script {options} 
  can link utility
  options:
    -h: this help
    -d [link-string]: decode a link-string
    -e: encode a link string, you have to specify the string
        interactively
    -s (together with -d): print result in a single line
    -t (together with -d): print result in a single line suitable 
       for printing a table
       -t alone prints the table-heading   

END
  }
