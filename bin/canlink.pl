eval 'exec perl -S $0 ${1+"$@"}' # -*- Mode: perl -*-
    if 0;                         
# the above is a more portable way to find perl
# ! /usr/bin/perl

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
#  SPECIAL, INCIDENTIAL OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE
#  OF THIS SOFTWARE, ITS DOCUMENTATION OR ANY DERIVATIVES THEREOF, EVEN 
#  IF BESSY HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#  
#  BESSY SPECIFICALLY DISCLAIMS ANY WARRANTIES, INCLUDING, BUT NOT LIMITED
#  TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
#  PURPOSE, AND NON-INFRINGEMENT. THIS SOFTWARE IS PROVIDED ON AN "AS IS"
#  BASIS, AND BESSY HAS NO OBLIGATION TO PROVIDE MAINTENANCE, SUPPORT,
#  UPDATES, ENHANCEMENTS OF MODIFICATIONS.


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
