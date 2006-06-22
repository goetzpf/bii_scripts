eval 'exec perl -S $0 ${1+"$@"}'  # -*- Mode: perl -*-
	if $running_under_some_shell;
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
  my $installPath = shift @ARGV;
  my $indexTitle =  shift @ARGV;

  chomp $installPath;
  my $outFileName = $installPath."/index.html";

  print "Create index for path: \'$installPath\'\n";
  my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime(time()); $mon +=1; $year+=1900;
  my $filetime ="$mday.$mon.$year $hour:$min\'$sec";
  my $files =  `find $installPath -name '*html'`;
#  $files .=  `find $installPath -name *pdf`;
  my @files = split(/\n/,$files);
print "FILES find $installPath -name *html: $files\n";
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
        while(<ENTRY_FILE>)
        {
          if( /<TITLE>(.*)<\/TITLE>/ )
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
  
  my $fileHeader = "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 3.2//EN\">\n".
    "<HTML>\n".
    "<HEAD>\n".
    "	<TITLE>$indexTitle</TITLE>\n".
    "	<META NAME=\"AUTHOR\" CONTENT=\"$ENV{USER}\">\n".
    "	<META NAME=\"CREATED\" CONTENT=\"$filetime\">\n".
# old style
#    "	<STYLE>\n".
#    "	<!--\n".
#    " pre, table {background-color:#F0F0F0;}\n".
#    " body{background-color:#FFFFFF;margin-left:60px;}\n".
#    " hr{margin-left:-60px;}\n".
#    " h1, h2, h3, h4, h5, h6 { font-family:Tahoma, Arial; margin-left:-50px;}\n".
#    " a:visited { text-decoration:none; color:#000088; }\n".
#    " a:link    { text-decoration:none; color:#000088;}\n".
#    " a:active  { text-decoration:none; color:#000088; }\n".
#    " a:hover   { text-decoration:underline; color:#000088;}\n".
#    "	-->\n".
#    "	</STYLE>\n".
# Now: take twiki style
    "  <style type=\"text/css\" media=\"all\">\n".
    "	\@import url(\"http://twiki.bessy.de/pub/TWiki/PatternSkin/layout.css\");\n".
    "	\@import url(\"http://twiki.bessy.de/pub/TWiki/PatternSkin/style.css\");\n".
    "	\@import url(\"http://www-csr.bessy.de/control/Docs/MLT/kuner/autoDocs/DocumentationApp/overwrite.css\");\n".
    "  </style>\n".
    "</HEAD>\n<BODY style=\"color: rgb(0, 0, 0);\" class=\"twikiViewPage\" alink=\"#ee0000\" link=\"#0000ee\" vlink=\"#551a8b\">\n".
    "<H1>$indexTitle</H1>\n".
    "<P ><FONT SIZE=\"-1\" >created: by $ENV{'USER'} $filetime </FONT></P>\n".
    "<DIV CLASS=\"twikiMain\">\n";

  my $fileFooter = "<\DIV></BODY>\n</HTML>\n";

  open(OUT_FILE, ">$outFileName") or die "can't open output file: $outFileName: $!";

  print OUT_FILE $fileHeader;

  print OUT_FILE $docContens;
  print OUT_FILE $fileFooter;
  close OUT_FILE;
