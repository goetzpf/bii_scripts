#!/usr/bin/env perl

# Copyright 2015 Helmholtz-Zentrum Berlin für Materialien und Energie GmbH
# <https://www.helmholtz-berlin.de>
#
# Author: Bernhard Kuner <bernhard.kuner@helmholtz-berlin.de>
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


## CreateCommonIndex.pl
#  **********************
#
#    Usage: CreateCommonIndex.pl installPath/filename [indexTitle]
#
#       filename   is a file that contains all files that have to be mentinoned
#                  in the indexcreated e.g by:
#
#                       find installPath -name *html > installPath/filename
#
#       indexTitle is optional, default is last part of pwd of installPath.
#
  use strict;
  use Data::Dumper;
  use makeDocStyle;
  my $installPath = shift @ARGV;
  my $indexTitle =  shift @ARGV;

  chomp $installPath;
  my $outFileName = $installPath."/index.html";

  #find files, sort files and put files from docRoot to front of the list
  my @files;
  for my $file (sort(split('\n',`find $installPath -name '*html'`))) { 
    $file =~ /$installPath\/(.*)/;
    scalar(split('/',$1))==1?unshift(@files,$file):push(@files,$file);
  }
  
  my $docContens = "<UL>\n";
  my $isInApplication;

  foreach my $entryFile (@files)
  { 

    next if $entryFile eq $outFileName;
    my $application;
    if( $entryFile =~ /.*\/(.*)App.*$/)
    {
        $application = "$1 Application";
    }
    elsif( $entryFile =~ /.*\/(.*)Doc.*$/)
    {
        $application = "$1 Documentation";
    }
    elsif( $entryFile =~ /(.*)\/.*$/) 
    {
        $application = "";
    }

    if( $isInApplication ne $application)
    { 
      $isInApplication = $application;
      $docContens .= "<H4><B>$application</B></H4>\n";
    }

    if( -e $entryFile )
    {

      $entryFile =~ /.*\/(.*)\.(.*)$/;
      my $filename = $1;
      my $extension = $2;
      my $title = "$filename.$extension";

      if($extension eq "html") # check for TITLE tag in html files
      {
	open(ENTRY_FILE, "<$entryFile") or die "can't open output file: $entryFile: $!";
  	{ local $/;
  	  undef $/;		# ignore /n as line delimiter
  	  my $parse = <ENTRY_FILE>;
          $title = $1 if( $parse =~/<TITLE>(.*)<\/TITLE>/i );
  	}  
  	close ENTRY_FILE;
      }

      $entryFile =~ /$installPath\/(.*)/;
      $docContens .= "  <LI><A HREF=\"$1\">$title</A></LI>\n";
    }
    else
    {
      print "ERROR: skip entry  \'$entryFile\' (doesn't exist)\n";
    }
  }
  $docContens .= "</UL>\n";

  if( not defined $indexTitle )	# if not allready set by argument
  {
    my $pwd = $ENV{'PWD'};
    $pwd =~ s/.*\/(.*)$/$1/;
    $indexTitle = "Documentation Index of $pwd";
  }

  my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime(time()); $mon +=1; $year+=1900;
  my $filetime ="$mday.$mon.$year $hour:$min\'$sec";
  my ($fileHeader,$fileFooter) = makeDocStyle::blabla($indexTitle,$filetime,$ENV{USER});

  open(OUT_FILE, ">$outFileName") or die "can't open output file: $outFileName: $!";
  print OUT_FILE $fileHeader,$docContens,$fileFooter;
  close OUT_FILE;
