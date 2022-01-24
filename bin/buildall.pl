#!/usr/bin/perl

# Copyright 2022 Helmholtz-Zentrum Berlin für Materialien und Energie GmbH
# <https://www.helmholtz-berlin.de>
#
# Author: Benjamin Franksen <Benjamin.Franksen@helmholtz-berlin.de>
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

use strict;
use lib "/opt/Epics/R3.14.12/base/3-14-12-1-1/lib/perl";
use Getopt::Long;
use EPICS::Release;

my $startdir = $ENV{PWD};
my $mindepth = 2;
my $maxdepth = 3;
my $include = '.*/\([0-9]+-\)+\(bessy\|snapshot\)?[0-9]+';
my $exclude = '*/mba-templates/*';
my $opt_clean = 0;
my $opt_clean_only = 0;
my $jobs;
my $opt_list = 0;
my $opt_dryrun = 0;
my $opt_quiet = 0;
my $opt_debug = 0;
my $opt_help = 0;

sub HELP_MESSAGE {
    print STDERR <<EOF;
Usage: build.pl options
Find EPICS support modules and build them in the correct dependency order.
Options are:
 -s --startdir=DIR  Start directory (default: $startdir)
 -m --mindepth=NUM  Minimum depth to search directory tree (default: $mindepth)
 -M --maxdepth=NUM  Maximum depth to search directory tree (default: $maxdepth)
 -i --include=REGEX Include (only) paths matching this regex pattern
                    (default: $include)
 -e --exclude=GLOB  Exclude paths matching this glob pattern
                    (default: $exclude)
 -c --clean         Make clean before building
 -C --clean-only    Only make clean, don't build
 -j --jobs[=NUM]    Number of jobs to run simultaneously
 -l --list          List directories in dependency order
 -n --dryrun        Do nothing, just say what would be done
 -q --quiet         Don't say what is being done
 -d --debug         Output debug messages
 -h --help          Display this help message
EOF
}

Getopt::Long::Configure ("bundling");
Getopt::Long::Configure ("no_ignore_case");
GetOptions(
  "s|startdir=s"  => \$startdir,
  "m|mindepth=i"  => \$mindepth,
  "M|maxdepth=i"  => \$maxdepth,
  "i|include=s"   => \$include,
  "e|exclude=s"   => \$exclude,
  "c|clean"       => \$opt_clean,
  "C|clean-only"  => \$opt_clean_only,
  "j|jobs:s"      => \$jobs,
  "l|list"        => \$opt_list,
  "n|dryrun"      => \$opt_dryrun,
  "q|quiet"       => \$opt_quiet,
  "d|debug"       => \$opt_debug,
  "h|help"        => \$opt_help,
) or HELP_MESSAGE() && exit 2;

HELP_MESSAGE() && exit 0 if ($opt_help);

if (defined $jobs and ($jobs > 0 or $jobs eq "")) {
  $jobs = "j$jobs";
} else {
  $jobs = "";
}

our $pipe;

open($pipe,'-|',"find",$startdir,
  "-mindepth",$mindepth,"-maxdepth",$maxdepth,"-regex",$include,
  "-not","-path",$exclude,"-type","d");

my @tops = <$pipe>;

print for (@tops);
exit;

die unless $? == 0;

my %deps = ();

foreach my $top (@tops) {
  chomp $top;
  #print "top = $top\n";

  my %macros = ();
  my @apps   = ();

  my $relfile = "$top/configure/RELEASE";
  unless (-f $relfile) {
    @tops = grep !/$top/, @tops;
    warn "Can't find $relfile\n";
    next;
  }
  readReleaseFiles($relfile, \%macros, \@apps, undef);
  expandRelease(\%macros, \@apps);

  delete $macros{TOP};
  delete $macros{TEMPLATE_TOP};
  delete $macros{SUPPORT};
  delete $macros{EPICS_SUPPORT};
  delete $macros{EPICS_BASE};

  # initialize in case there are no dependencies
  $deps{$top} = {};
  print "$top:\n" if $opt_debug;

  # build dependency graph
  foreach my $app (@apps) {
    my $dep = $macros{$app};
    if (-d $dep) {
      print "  $dep\n" if $opt_debug;
      $deps{$top}->{$dep} = 1;
    }
  }
}

my %mark = ();
my %done = ();

sub make {
  my ($top) = @_;
  if (not $done{$top}) {
    if ($mark{$top}) {
      die "circular dependency: $top";
    }
    $mark{$top} = 1;
    my $topdeps = $deps{$top};
    foreach my $dep (sort(keys(%$topdeps))) {
        make($dep);
    }
    my $cmd = "make -s$jobs -C $top";
    if ($opt_clean) {
      $cmd = "make -s$jobs -C $top distclean && $cmd";
    }
    if ($opt_clean_only) {
      $cmd = "make -s$jobs -C $top distclean";
    }
    if ($opt_list) {
      print "$top\n";
    } elsif ($opt_dryrun) {
      print "$cmd\n";
    } else {
      print "building $top ...\n" if not $opt_quiet;
      system($cmd);
      die unless $? == 0;
    }
    $done{$top} = 1;
  }
}

foreach my $tgt (@tops) {
  make($tgt);
  %mark = ();
}
