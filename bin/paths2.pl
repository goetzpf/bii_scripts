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


# a script to set PATH, PERL5LIB and MANPATH
# for usage of the bii_scripts perl-modules

# use with :  eval  `./paths.pl`

use FindBin;

use Cwd;

use Config;

my $std_install_prefix= $Config{prefix};
my $man3dir= $Config{man3dir};

$man3dir=~ s/$std_install_prefix//; # leaves '/' at the beginning
$man3dir=~ s/^\///;
$man3dir=~ s/\/man3//;

my $libdir= $Config{sitelib};
$libdir=~ s/$std_install_prefix//; # leaves '/' at the beginning
$libdir=~ s/^\///;
$libdir=~ s/\/[\d\.]+$//;

my $bin_path= guess_script_path();

my $bii_script_path= parent_dir($bin_path);

my $perl_lib_path= File::Spec->catdir($bii_script_path,
                                      $libdir);

my $man_path     = File::Spec->catdir($bii_script_path,$man3dir);


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
  { my $scrpath  = $FindBin::Bin;
    #my $scrpath  = $FindBin::RealBin;
    my $envpath = $ENV{PWD};

    # try to calc an alternative path
    if (!defined $envpath)
      { return($srcpath); };

    my $currpath= cwd;
    my $altpath= $scrpath;
    $altpath=~ s#^$currpath#$envpath#;

    # test wether chdir is possible
    if (!chdir($altpath))
      { return($scrpath); };

    chdir($currpath) or die "fatal: chdir back to original directory failed";

    if (slashes($altpath)<=slashes($scrpath))
      { return($altpath); };
    return($scrpath);
  }

sub parent_dir
  { my($path)= @_;

    my @dirs = File::Spec->splitdir($path);
    pop @dirs;
    return(File::Spec->join(@dirs));
  }

