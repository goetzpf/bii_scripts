eval 'exec perl -S $0 ${1+"$@"}' # -*- Mode: perl -*-
    if 0;
# the above is a more portable way to find perl
# ! /usr/bin/perl

# Copyright 2022 Helmholtz-Zentrum Berlin für Materialien und Energie GmbH
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

