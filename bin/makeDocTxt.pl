eval 'exec perl -S $0 ${1+"$@"}'  # -*- Mode: perl -*-
	if $running_under_some_shell;
## txt2html.pl
#  ************
#  
#  translate a textfile written in the makeDocs format to html
#  
#    USAGE: txt2html.pl txtFileName.txt $(TOP) [installPath/outFileName]
#  
#    txtFileName: the input file
#    $(TOP)	: the path to the documentation top, something like  '../..'
#    outFileName: optional, name and path where to write the output, default: './txtFileName.html'
#

  use strict;
  my $inFileName = shift @ARGV;
  my $top =  shift @ARGV;
  $top =~ s/^\.\.\///;
  my $outFileName;
  if( @ARGV ){ $outFileName = shift @ARGV;}
  
# for creation of outfile name with installpath from infile name
#  my $installPath=".";
#  if( @ARGV ){ $installPath = shift @ARGV;}

  print "Create html from: $inFileName \n";
  chomp $inFileName;
  my $file;
  open(IN_FILE, "<$inFileName") or die "can't open input file $inFileName: $!";
  { local $/;
    undef $/; # ignoriere /n in der Datei als Trenner
    $file = <IN_FILE>;
  }  
  close IN_FILE;

 my($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,
   $atime,$mtime,$ctime,$blksize,$blocks) = stat($inFileName);
  my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime($mtime);
  $mon +=1; $year+=1900;
  my $filetime ="$mday.$mon.$year $hour:$min\'$sec";

# outfilename an optional 2'nd parameter, not used here, because 
# make copies the file to its destination
# if no outfilename is given, it becomes infilename.html withhout path

  if( ! $outFileName )
  { $outFileName = $inFileName;
#    $outFileName =~ s/(\w+)\.(\w+$)/$1.html/;  # omit path
    $outFileName =~ s/(.*)\.\w+$/$1.html/;     # with path
  } 

#print header
  my $index;	# index of all headlines
  my $idxFile;	# extra index file of all headlines
  my $indexNr;	# index tag counter
  my $docContens;	# buffer for the html to be printed

  my $title = $outFileName;
  $title =~ s/.*\/(.*)$/$1/;
  
  my $createTime = $filetime;#sprintf ("%4d%2d%2d;%2d%2d%2d",$year,$mon,$mday,$hour,$min,$sec);

  my $parse=$file;
  my $setImgToEnd = 0;
  my $firstLIne=1;
  my $isPre=0;
  my $paragraphBefore;

  my $paragraph;

  while( getParagraph(\$parse, \$paragraph) )
  {
# is PRE (code) ?
    if( $paragraph =~ /^\s\s/i )
    { #print "is Preformated\n";
      $docContens .= "$paragraphBefore";
      #print "**html:\n$paragraphBefore\n";
      if( ! $isPre )
      { $isPre = 1 ; # begin preformated block
        $paragraphBefore = "<PRE>\n$paragraph";
      } else
      { $paragraphBefore = $paragraph;
      }
      next;
    }

    if( $isPre )			# end preformated block
    { $paragraphBefore =~ s/\n*$//gi;	# skip last newline
      #print "end Preformated\n";
      $docContens .= "$paragraphBefore\n</PRE>\n";
      $paragraphBefore = "";
      $isPre = 0;
    }  

    #print "remove leading/trailing \\s, \\n\n";
    $paragraph =~ s/^\n*// ;		# remove leading \n
    $paragraph =~ s/\s*$//g ;		# remove trailing \s
    next if( $paragraph eq "" );	# skip empty paragraphs
    
# set SPECIAL CHARACTERS for all paragraphs that are not preformated
    $paragraph =~ s|&|&amp;|g;
    $paragraph =~ s|Ö|&Ouml;|g;
    $paragraph =~ s|ö|&ouml;|g;
    $paragraph =~ s|Ü|&Uuml;|g;
    $paragraph =~ s|ü|&uuml;|g;
    $paragraph =~ s|Ä|&Auml;|g;
    $paragraph =~ s|ä|&auml;|g;
    $paragraph =~ s|ß|&szlig;|g;
    $paragraph =~ s|€|&euro;|g;
    $paragraph =~ s|µ|&mu;|g;
    $paragraph =~ s|<|&lt;|g;
    $paragraph =~ s|>|&gt;|g;
    $paragraph =~ s|\"|&quot;|g;

# recognise ANCHORS in the document:  (anchor: #AnchorName)
    $paragraph =~ s|\(anchor:\s*\#(.*?)\)|<A NAME=\"$1\"></A> |g;

# recognise html tags:
# (displayed text: http://something)
    $paragraph =~ s|\((.*?):\s*http://(.*?)\)|<A HREF=\"http://$2\">$1</A> |g;

# (displayed text: #something) for local references
    $paragraph =~ s|\((.*?):\s*\#(.*?)\)|<A HREF=\"#$2\">$1</A> |g;
    $paragraph =~ s|http://(.*?)\)|<A HREF=\"http://$1\">http://$1</A> |g;

# get pictures
   # $paragraph =~ s|\((.*?):\s*([\w\d]+)\.JPG\)|$1 <A HREF=\"$2.JPG\" TARGET="Wimg"><IMG SRC=\"TN_$2.JPG\" ALT="$2"></A>|gi;

    $paragraph =~ s|([\w-\d]+)\.gif|<IMG SRC=\"$1.gif\" ALT="$1">|g;
    $paragraph =~ s|([\w-\d]+)\.GIF|<IMG SRC=\"$1.GIF\" ALT="$1">|g;
    $paragraph =~ s|([\w-\d]+)\.png|<IMG SRC=\"$1.png\" ALT="$1">|g;
    $paragraph =~ s|([\w-\d]+)\.PNG|<IMG SRC=\"$1.PNG\" ALT="$1">|g;
    $paragraph =~ s|([\w-\d]+)\.bmp|<IMG SRC=\"$1.bmp\" ALT="$1">|g;
    $paragraph =~ s|([\w-\d]+)\.BMP|<IMG SRC=\"$1.BMP\" ALT="$1">|g;

# .jpg is to be considered as thumbnail and image!
    $paragraph =~ s|([\w-\d]+)\.jpg|<A HREF=\"$1.jpg\" TARGET="Wimg"><IMG SRC=\"TN$1.jpg\" ALT="$1.jpg"></A>|g;
    $paragraph =~ s|([\w-\d]+)\.JPG|<A HREF=\"$1.JPG\" TARGET="Wimg"><IMG SRC=\"TN$1.JPG\" ALT="$1.JPG"></A>|g;

# is TABLE ?
    if( $paragraph =~ /\|/i )
    { 
      #print "is Table\n";
      $paragraph =~ s/\n*$//;	# remove \n's at end of table
      my $th;
      if( $paragraph =~ /(.*?)\n*\s*[-+]+\s*\n/i )	# is header rule: \n ------+----------+----- \n
      { #print "with header line: \'$1\'\n";
        $paragraph = $';
        my $tableHeader = $1;
        $tableHeader =~ s/\s*\|\s*/<\/TH><TH>/gi;
        $th = "<TABLE border=1 cellpadding=\"2\">\n<TR valign=\"top\">\n<TH>$tableHeader</TH>\n</TR>\n<TR>\n<TD>";
        
      }
      else
      { #print "without header line\n";
        $th = "<TABLE border=0 cellpadding=\"2\">\n<TR>\n<TD>";
      }
      $paragraph =~ s/\s*\|\s*/<\/TD><TD>/gi;
      $paragraph =~ s/\n/<\/TD>\n<\/TR>\n<TR VALIGN=\"TOP\">\n<TD>/gi;
      $paragraph = "$th$paragraph</TD>\n</TR>\n</TABLE>\n";
    }
# is H1 ?
    elsif( $paragraph =~ /\*\*\*+/i )	
    { #print "is H1\n";
      $paragraph =~ s/\n*\*\*\*+//i;
      if( $firstLIne )	#create Site header if first line is a H1 tag
      { 
        $idxFile .="<DT><a href=\"$outFileName#cont_$indexNr\"target=\"Wtext\"><B>$paragraph</B></a></DT><hr>\n";	# set reference in .idx.html file
#        $header .= "<TABLE CELLPADDING=0 CELLSPACING=0 width=100%>\n".
#	  "<TR>\n<TD colspan=2 WIDTH=80%><H1 ALIGN=\"center\">$paragraph</H1>\n</TD>\n".
#	  "<TD><P><FONT SIZE=\"-1\" >last Modified: by $ENV{'USER'}<br>$filetime </FONT></P>\n    </TD>\n".
#	  "</TR>\n</TABLE>\n\n<HR>\n";

        $title = $paragraph;
        next;
      }
      else
      { $index .= "<DT><a href=\"#cont_$indexNr\">$paragraph</a></DT>\n";
        $idxFile .="<br><DT><a href=\"$outFileName#cont_$indexNr\"target=\"Wtext\"><B>$paragraph</B></a></DT><hr>\n";	# set reference in .idx.html file
	$paragraph = "\n<A NAME=\"cont_$indexNr\"></A>\n<br><H1>"."$paragraph"."</H1><hr>";
        $indexNr += 1;
      }
    }
# is H2 ?
    elsif( $paragraph =~ /=======+/i )
    { #print "is H2\n";
      $paragraph =~ s/\s*======+//i;
      $index .="<DT style=\"margin-left:20px\"><a href=\"#cont_$indexNr\">$paragraph</a></DT>\n";	# set reference contents
      $idxFile .="<DT>&bull;<a href=\"$outFileName#cont_$indexNr\" target=\"Wtext\">$paragraph</a></DT>\n";	# set reference in .idx.html file
      $paragraph = "\n<A NAME=\"cont_$indexNr\"></A>\n<H2>"."$paragraph"."</H2>\n";
      $indexNr += 1;
    }
# is H3 or HR ?
    elsif( $paragraph =~ /-------+/i )
    { #print "is H3\n";
      if( $paragraph =~ /^---+/ )
      { $paragraph = "\n<HR>\n";
      }
      else
      {
      $paragraph =~ s/\s*---+//i;
      $index .="<DT style=\"margin-left:40px\"><a href=\"#cont_$indexNr\">$paragraph</a></DT>\n";	# set reference in .idx.html file
      $idxFile .="<DT style=\"margin-left:20px\">&bull;<a href=\"$outFileName#cont_$indexNr\" target=\"Wtext\">$paragraph</a></DT>\n";	# set reference in .idx.html file
      $paragraph = "\n<A NAME=\"cont_$indexNr\"></A>\n<H3>"."$paragraph"."</H3>\n";
      $indexNr += 1;
      }
    }
# is H4 ?
    elsif( $paragraph =~ /\.\.\.\.\./i )
    { #print "is H4\n";
      $paragraph =~ s/\s*\.\.\.\.(\.)*//i;
      $index .="<DT style=\"margin-left:60px\"><a href=\"#cont_$indexNr\">$paragraph</a></DT>\n";	# set reference in .idx.html file
      $idxFile .="<DT style=\"margin-left:40px\">&bull;<a href=\"$outFileName#cont_$indexNr\" target=\"Wtext\">$paragraph</a></DT>\n";	# set reference in .idx.html file
      $paragraph = "\n<A NAME=\"cont_$indexNr\"></A>\n<H4>"."$paragraph"."</H4>\n";
      $indexNr += 1;
    }
# is LIST ?
    elsif( $paragraph =~ /^\s*-\s*/i )
    { #print "is 2nd list or HR\n";
      $paragraph =~ s/^\s*-\s*/<UL>\n  <LI>/i;
      $paragraph =~ s/\n\s*-\s*/<\/LI>\n  <LI>/gi;
      $paragraph = "$paragraph"."</LI>\n</UL>\n";
    }
# all other seems to be P 
    else
    { #print "is Paragraph\n";
      $paragraph =~ s/^\*/&bull;/;
#      $paragraph =~ s/\n\s*\n$/<\/P>\n/i;
      $paragraph = "<P>"."$paragraph"."\n<\/P>\n";
    }

# set BOLD and italic
#    $paragraph =~ s|  (.*?)  | <B>$1</B> |g;	# bold-text quoted with double spaces 
#    $paragraph =~ s|\s\'(.*?)\'\s| <I>$1</I> |g;	# italic-text quoted with sinlge quotes
    $paragraph = substParagraph($paragraph,'  (.*?)  ',"B>");	    # bold-text quoted with double spaces 
    $paragraph = substParagraph($paragraph,'\W\'(.*?)\'\W',"I>","s");   # italic-text quoted with sinlge quotes
#    print "para\t|$paragraph|\n";
    
# reformate tables html
    $paragraph =~ s|\n<TH|\n    <TH|g;
    $paragraph =~ s|<\/TH><TH>|<\/TH>\t<TH>|g;
    $paragraph =~ s|\n<TD|\n    <TD|g;
    $paragraph =~ s|<\/TD><TD>|<\/TD>\t<TD>|g;
    $paragraph =~ s|<TR|  <TR|g;
    $paragraph =~ s|<\/TR|  <\/TR|g;

    $docContens .= "$paragraph\n";
    #print "**html:\n$paragraph\n";

    $firstLIne=0;
  }  # end while

#  print "is END |$parse|\n";
  if( $isPre )			# end of file but in preformated block
  { $paragraphBefore =~ s/\n*$//gi;	# skip last newline
    $docContens .= "$paragraphBefore</PRE>\n";
    $isPre = 0;
  }  
  else
  {
    $docContens .= "$paragraphBefore\n";
  }

  my $fileHeader = "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 3.2//EN\">\n".
    "<HTML>\n".
    "<HEAD>\n".
    "	<TITLE>$title</TITLE>\n".
    "	<META NAME=\"AUTHOR\" CONTENT=\"$ENV{USER}\">\n".
    "	<META NAME=\"CREATED\" CONTENT=\"$createTime\">\n".
    "	<STYLE>\n".
    "	<!--\n".
#    " body{background-color:#FFFFF4;margin-left:60px;}\n".
#    " pre, table {background-color:#F4F4F0;}\n".
    " pre, table {background-color:#F0F0F0;}\n".
    " body{background-color:#FFFFFF;margin-left:60px;}\n".
    " hr{margin-left:-60px;}\n".
    " h1, h2, h3, h4, h5, h6 { font-family:Tahoma, Arial; margin-left:-50px;}\n".
    " a:visited { text-decoration:none; color:#000088; }\n".
    " a:link    { text-decoration:none; color:#000088;}\n".
    " a:active  { text-decoration:none; color:#000088; }\n".
    " a:hover   { text-decoration:underline; color:#000088;}\n".
    "	-->\n".
    "	</STYLE>\n</HEAD>\n<BODY>\n".
#    "<H1 ALIGN=\"center\">$title</H1>\n".
    "<TABLE style=\"background-color:#FFFFFF\" WIDTH=\"100%\"><TR>\n".
    "<TD><FONT><H1>$title</FONT></H1></TD>\n".
    "<TD WIDTH=200><IMG WIDTH=200 SRC=\"/images/BESSYLogo_sw_rgb300.jpg\"></TD>".
    "</TR></TABLE>\n".
    "<P ALIGN=\"right\"><FONT SIZE=\"-1\" >last Modified: by $ENV{'USER'} $filetime </FONT></P>\n";

  my $fileFooter = "</BODY>\n</HTML>\n";

#  print "write $outFileName\n";
  open(OUT_FILE, ">$outFileName") or die "can't open output file: $outFileName: $!";
  print OUT_FILE $fileHeader;

  if( length($index) > 0)
  { $index = "<H2>Contents</H2>\n$index<hr>\n";
    print OUT_FILE $index;
  }

  print OUT_FILE $docContens;
  print OUT_FILE $fileFooter;
  close OUT_FILE;

  
# Create external idx file
#  $outFileName = $inFileName;
#  $outFileName =~ s/(.*)\.\w+$/$1.idx.html/;     # with path
#  (IDX_FILE, ">$outFileName") or die "can't open idx file: $outFileName: $!";
#  print IDX_FILE "<HTML>\n<HEAD>\n".
#    "<META HTTP-EQUIV=\"CONTENT-TYPE\" CONTENT=\"text/html; charset=iso-8859-1\">\n".
#    "<link rel=stylesheet type=\"text/css\" href=\"../Windex.css\">\n".
#    "</HEAD>\n<BODY>\n".
#    $idxFile;"</BODY>\n</HTML>\n";
 
 
# get next paragraph from the text. A paragraph is either something that ends with '/n/n' - a
# lbank line or the end of file.
sub   getParagraph
{ my( $r_parse, $r_paragraph) = @_;
  if($$r_parse =~ /.*?\n\s*\n/is )	#one paragraph ends with two newlines \n\n
  { 
    $$r_parse=$';
    $$r_paragraph=$&;
    return 1;
  }
  elsif($$r_parse =~ /.+?$/is )	#last paragraph ends with end of file
  { 
    $$r_parse=$';
    $$r_paragraph=$&;
    return 1;
  }
  else
  {
    return undef;
  }
}

# check for all occurencies of the pattern $searchPat in $value and enclose with html tags.
sub   substParagraph
{   my ($value,$searchPat,$htmlTag,$mod) = @_;

    my $parseVal = $value;

    my $parsed;
    
#print "substParagraph parse: ($*)\'$value'\n";
    while( $parseVal =~ /$searchPat/) # check for all occuring variables: $(VARNAME)
    {
#print "\tbefore:\t\'$`\'\n\tmatch\t\'$1\'\n\tremain\t\'$'\'\n";
        $parsed .= "$` <${htmlTag}$1</${htmlTag} ";
        $parseVal = $';
    }
    $parsed .= $parseVal; # add the not matching remainder

#print "return: \'$parsed'\n";
    return $parsed;
}
