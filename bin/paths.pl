eval 'exec perl -S $0 ${1+"$@"}' # -*- Mode: perl -*-
    if 0;                         
# the above is a more portable way to find perl
# ! /usr/bin/perl

# a script to set PATH, PERL5LIB and MANPATH
# for usage of the bii_scripts perl-modules

# use with :  eval  `./paths.pl`

use FindBin;

use Cwd;

my $bin_path= guess_script_path();

my $bii_script_path= parent_dir($bin_path);

my $perl_lib_path= File::Spec->catdir($bii_script_path,"lib/perl");

my $man_path     = File::Spec->catdir($bii_script_path,"man");


print 'export PATH=${PATH}:',$bin_path,"\n";

if ($ENV{PERL5LIB})
  { print 'export PERL5LIB=${PERL5LIB}:',$perl_lib_path,"\n"; }
else
  { print 'export PERL5LIB=',$perl_lib_path,"\n"; };
  
print 'export MANPATH=${MANPATH}:',$man_path,"\n"; 

sub slashes
  { my($st)= @_;
    my $s;
  
    while($st=~ /\//g)
      { $s++; };
    return($s);
  }
  
sub guess_script_path
  { my $path1= $FindBin::Bin;
    my $curr= cwd;
    
    if (!chdir($path1))
      { return($path1); };
      
    my $path2= $ENV{PWD};
    chdir($curr) or die "fatal: chdir back to original directory failed";
      
    if (slashes($path2)<=slashes($path1))
      { return($path2); };
    return($path1);
  }  
  
sub parent_dir
  { my($path)= @_;
  
    my @dirs = File::Spec->splitdir($path);
    pop @dirs;
    return(File::Spec->join(@dirs));
  }
      
