eval 'exec perl -S $0 ${1+"$@"}' # -*- Mode: perl -*-
    if 0;                         
# the above is a more portable way to find perl
# ! /usr/bin/perl

# @STATUS: release
# @PLATFORM: bessy 
# @CATEGORY: can


use strict;
#activate perl-extensions:
#use lib "$ENV{HOME}/pmodules";
use perl_site;

use Getopt::Long;
use FindBin;

use canlink;

use vars qw($opt_help $opt_decode $opt_encode);

my $version= "1.0";


if (!GetOptions("help|h", "decode|d=s", "encode|e"))
  { die "parameter error!\n"; };		


if ($opt_help)
  { help();
    exit;
  };  

if ($opt_decode)
  { while ($#ARGV>=0)
      { $opt_decode.= ' ' . shift(@ARGV); };
    
    my %h= canlink::decode($opt_decode);
    die if (!%h);
    print canlink::pretty_print(%h),"\n";
    exit(0);
  };

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
END
  }
