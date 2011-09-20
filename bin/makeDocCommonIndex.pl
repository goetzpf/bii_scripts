eval 'exec perl -S $0 ${1+"$@"}'  # -*- Mode: perl -*-
	if $running_under_some_shell;

#  This software is copyrighted by the
#  Helmholtz-Zentrum Berlin fuer Materialien und Energie GmbH (HZB),
#  Berlin, Germany.
#  The following terms apply to all files associated with the software.
#  
#  HZB hereby grants permission to use, copy and modify this
#  software and its documentation for non-commercial, educational or
#  research purposes provided that existing copyright notices are
#  retained in all copies.
#  
#  The receiver of the software provides HZB with all enhancements, 
#  including complete translations, made by the receiver.
#  
#  IN NO EVENT SHALL HZB BE LIABLE TO ANY PARTY FOR DIRECT, INDIRECT,
#  SPECIAL, INCIDENTAL OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE
#  OF THIS SOFTWARE, ITS DOCUMENTATION OR ANY DERIVATIVES THEREOF, EVEN 
#  IF HZB HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#  
#  HZB SPECIFICALLY DISCLAIMS ANY WARRANTIES, INCLUDING, BUT NOT LIMITED
#  TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
#  PURPOSE, AND NON-INFRINGEMENT. THIS SOFTWARE IS PROVIDED ON AN "AS IS"
#  BASIS, AND HZB HAS NO OBLIGATION TO PROVIDE MAINTENANCE, SUPPORT,
#  UPDATES, ENHANCEMENTS OR MODIFICATIONS.


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

  #print "Create index for path: \'$installPath\'\n";
  my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime(time()); $mon +=1; $year+=1900;
  my $filetime ="$mday.$mon.$year $hour:$min\'$sec";
  my $files =  `find $installPath -name '*html'`;
#  $files .=  `find $installPath -name *pdf`;
  my @files = split(/\n/,$files);
#print "FILES find $installPath -name *html: $files\n";
  my $docContens = "<UL>\n";
  my $isInApplication;
  my $firstone=1;

#  foreach my $entryFile (sort(keys(%allEntries)))
  foreach my $entryFile (sort(@files))
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
        $application = "$1";
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
          if( /<TITLE>(.*)<\/TITLE>/i )
          {
            $title = $1;
          }
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

  my ($fileHeader,$fileFooter) = makeDocStyle::blabla($indexTitle,$filetime,$ENV{USER});

  open(OUT_FILE, ">$outFileName") or die "can't open output file: $outFileName: $!";

  print OUT_FILE $fileHeader;

  print OUT_FILE $docContens;
  print OUT_FILE $fileFooter;
  close OUT_FILE;
