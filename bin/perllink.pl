eval 'exec perl -S $0 ${1+"$@"}' # -*- Mode: perl -*-
    if 0;                         
# the above is a more portable way to find perl
# ! /usr/bin/perl

use strict;

use FindBin;
use Config;

use Getopt::Long;

use vars qw($opt_help $opt_script $opt_hw);

if (!GetOptions("help|h","script|s=s","hw")
                )
  { die "parameter error, use \"$0 -h\" to display the online-help\n"; };

if ($opt_help)
  { print_help();
    exit;
  };  

die if (!defined $opt_script);

#chdir("$FindBin::Bin") or die;

my $version= $Config{version};

my $src_path= "../../lib/perl_std/lib/site_perl/$version";

if ($opt_hw) # hardware-dependant scripts
  { $src_path.= "/$Config{archname}"; };

my $dst_path= "../../lib/perl";

print "ln -s $src_path/$opt_script $opt_script\n";

symlink("$src_path/$opt_script","$dst_path/$opt_script") or die;


sub print_help
  { 
    print <<END
************* $FindBin::Script $version *****************
useage: $FindBin::Script {options} 
options:
  -h : this help
  -s [script] : script-name
  --hw : this is a hw-dependant script
END
  }
  
