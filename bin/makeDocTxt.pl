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


## txt2html.pl
#  ************
#  
#  translate a textfile written in the makeDocs format to html
#  
#    USAGE: txt2html.pl txtFileName.txt $(TOP) [installPath/outFileName]
#  
#    txtFileName: the input file
#    outFileName: optional, name and path where to write the output, default: './txtFileName.html'
#

  use strict;
  use makeDocStyle;
  use POSIX qw(strftime);

  use Options;

Options::register(
  ["nocontents", "c", "",      "leave out table-of-contents"],
);

my $usage = "makeDocTxt.pl [OPTIONS] infile.txt [outfile.html]\n".
    "  Create an html-document from a .txt-file with special format style\n".
    "  for details see http://www-csr.bessy.de/control/Docs/MLT/kuner/autoDocs/makeDocs/makeDocEn.html\n".
    "OPTIONS: \n";


my $config = Options::parse($usage, 1);

  my $inFileName = shift @ARGV;
  chomp $inFileName;

  my $outFileName;  	# outfilename an optional 2'nd parameter, 
  if( @ARGV )
  { 
    $outFileName = shift @ARGV;
  }
  else
  { 
    $outFileName = $inFileName;
    if($outFileName =~ /(.*)\.\w+$/)	# make some infile.txt -> infile.html
    {
      $outFileName = "$1.html"
    }
    else
    {
      $outFileName .= ".html"	    	# without extension: infile -> infile.html
    }
  } 

  print "Create html from: '$inFileName' write '$outFileName'\n";
  my $file;
  open(IN_FILE, "<$inFileName") or die "can't open input file $inFileName: $!";
  { local $/;
    undef $/; # ignoriere /n in der Datei als Trenner
    $file = <IN_FILE>;
  }  
  close IN_FILE;

 my($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,
   $atime,$mtime,$ctime,$blksize,$blocks) = stat($inFileName);

  my $filetime = strftime("%Y-%m-%d %H:%M:%S", localtime($mtime));

#print header
  my $index;	# index of all headlines
  my $idxFile;	# extra index file of all headlines
  my $indexNr;	# index tag counter
  my $docContens;	# buffer for the html to be printed

  my $title = $outFileName;
  $title =~ s/.*\/(.*)$/$1/;

  my $parse=$file;
  my $setImgToEnd = 0;
  my $firstLine=1;
  my $isPre=0;
  my $preBlockCont;

  my $paragraph;

  while( getParagraph(\$parse, \$paragraph) )
  {

# is PRE (code) ?
    if( $paragraph =~ /^\s\s/i )
    { #print "is Preformated\n";
      if( ! $isPre )
      { $isPre = 1 ; # begin preformated block
        $preBlockCont = $paragraph;
      } else
      { 
        $preBlockCont .= $paragraph;
      }
      next;
    }
# isPre, but paragraph is no longer PRE -> so print the PRE block to document
    if( $isPre )			# end preformated block
    { $preBlockCont =~ s/\n*$//gi;	# skip last newline
      #print "end Preformated\n";
      $preBlockCont =~ s|<|&lt;|g; # <,> quoted also in preformated text!
      $preBlockCont =~ s|>|&gt;|g;
      $docContens .= "<PRE>\n$preBlockCont\n</PRE>\n";
      $preBlockCont = "";
      $isPre = 0;
    }  

# remove trash: leading \n, trailing \s, skip empty paragraphs
    #print "remove leading/trailing \\s, \\n\n";
    $paragraph =~ s/^\n*// ;		# remove leading \n
    $paragraph =~ s/\s*$//g ;		# remove trailing \s
    next if( $paragraph eq "" );	# skip empty paragraphs

# set SPECIAL CHARACTERS for all paragraphs that are not preformated
    $paragraph =~ s|<|&lt;|g;
    $paragraph =~ s|>|&gt;|g;
    $paragraph =~ s|Ö|&Ouml;|g;
    $paragraph =~ s|ö|&ouml;|g;
    $paragraph =~ s|Ü|&Uuml;|g;
    $paragraph =~ s|ü|&uuml;|g;
    $paragraph =~ s|Ä|&Auml;|g;
    $paragraph =~ s|ä|&auml;|g;
    $paragraph =~ s|ß|&szlig;|g;
    $paragraph =~ s|€|&euro;|g;
    $paragraph =~ s|µ|&mu;|g;
    $paragraph =~ s|\"|&quot;|g;
  
# same for utf-8 encoded umlauts:
    $paragraph =~ s|\xc3\x96|&Ouml;|g;
    $paragraph =~ s|\xc3\xb6|&ouml;|g;
    $paragraph =~ s|\xc3\x9c|&Uuml;|g;
    $paragraph =~ s|\xc3\xbc|&uuml;|g;
    $paragraph =~ s|\xc3\x84|&Auml;|g;
    $paragraph =~ s|\xc3\xa4|&auml;|g;
    $paragraph =~ s|\xc3\x9f|&szlig;|g;
    $paragraph =~ s|\xe2\x82\xac|&euro;|g;

# recognise ANCHORS in the document:  (anchor: #AnchorName)
    $paragraph =~ s|\(anchor:\s*\#(.*?)\)|<A NAME=\"$1\"></A> |g;

# recognise html tags:

# (displayed text: http://something)
    $paragraph =~ s|\((.*?):\s*http://(.*?)\)|<A HREF=\"http://$2\">$1</A>|g;

# (displayed text: URL=path/to/something)
    $paragraph =~ s|\((.*?):\s*URL=\s*(.*?)\)|<A HREF=\"$2\">$1</A>|g;

# (http://path/to/something) - show just the path
    $paragraph =~ s|\(\s*http://(.*?)\)|<A HREF=\"http://$1\">http://$1</A>|g;

# (URL=path/to/something) - for local paths, show just the path
    $paragraph =~ s|\(\s*URL=\s*(.*?)\)|<A HREF=\"$1\">$1</A>|g;

# (displayed text: #something) - for local references
    $paragraph =~ s|\((.*?):\s*\#(.*?)\)|<A HREF=\"#$2\">$1</A>|g;

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
    elsif( $paragraph =~ s/\s*\*{4,}//i )	
    { #print "is H1\n";
      if( $firstLine )	#create Site header if first line is a H1 tag
      { 
        $idxFile .="<DT><a href=\"$outFileName#cont_$indexNr\"target=\"Wtext\"><B>$paragraph</B></a></DT><hr>\n";	# set reference in .idx.html file
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
    elsif( $paragraph =~ s/\s*={4,}//i )
    { #print "is H2\n";
      $index .="<DT style=\"margin-left:20px\"><a href=\"#cont_$indexNr\">$paragraph</a></DT>\n";	# set reference contents
      $idxFile .="<DT>&bull;<a href=\"$outFileName#cont_$indexNr\" target=\"Wtext\">$paragraph</a></DT>\n";	# set reference in .idx.html file
      $paragraph = "\n<A NAME=\"cont_$indexNr\"></A>\n<H2>"."$paragraph"."</H2>\n";
      $indexNr += 1;
    }
# is H3
    elsif( $paragraph =~ s/\s*-{4,}//i )
    { #print "is H3\n";
      $index .="<DT style=\"margin-left:40px\"><a href=\"#cont_$indexNr\">$paragraph</a></DT>\n";	# set reference in .idx.html file
      $idxFile .="<DT style=\"margin-left:20px\">&bull;<a href=\"$outFileName#cont_$indexNr\" target=\"Wtext\">$paragraph</a></DT>\n";	# set reference in .idx.html file
      $paragraph = "\n<A NAME=\"cont_$indexNr\"></A>\n<H3>"."$paragraph"."</H3>\n";
      $indexNr += 1;
    }
# is HR
    elsif( $paragraph =~ /^-{4,}/ )
    { 
      $paragraph = "\n<HR>\n";
    }
# is H4 ?
    elsif( $paragraph =~ s/\s*\.{4,}//i )
    { #print "is H4\n";
      $index .="<DT style=\"margin-left:60px\"><a href=\"#cont_$indexNr\">$paragraph</a></DT>\n";	# set reference in .idx.html file
      $idxFile .="<DT style=\"margin-left:40px\">&bull;<a href=\"$outFileName#cont_$indexNr\" target=\"Wtext\">$paragraph</a></DT>\n";	# set reference in .idx.html file
      $paragraph = "\n<A NAME=\"cont_$indexNr\"></A>\n<H4>"."$paragraph"."</H4>\n";
      $indexNr += 1;
    }
# is LIST ?
    elsif( $paragraph =~ /(^\s{0,1}-\s*)/i )
    { #print "is 2nd list or HR\n";
      my $indent = length $1;
      $paragraph =~ s/\n {$indent}/\n/g;
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
    $paragraph =~ s|  (.*?)  | <B>$1</B> |g;	# bold-text quoted with double spaces 
    $paragraph =~ s{(\W|^)'(.*?)'(\W)}{$1<I>$2</I>$3}g;	# italic-text quoted with sinlge quotes
    $paragraph =~ s/\\\\(.*?)\\\\/<$1>/sg;
#    print "para\t($1)|$paragraph|\n";

# reformate tables html
    $paragraph =~ s|\n<TH|\n    <TH|g;
    $paragraph =~ s|<\/TH><TH>|<\/TH>\t<TH>|g;
    $paragraph =~ s|\n<TD|\n    <TD|g;
    $paragraph =~ s|<\/TD><TD>|<\/TD>\t<TD>|g;
    $paragraph =~ s|<TR|  <TR|g;
    $paragraph =~ s|<\/TR|  <\/TR|g;

    $docContens .= "$paragraph\n";
    #print "**html:\n$paragraph\n";

    $firstLine=0;
  }  # end while

#  print "is END |$parse|\n";

# end of file but in preformated block
  if( $isPre )
  { 
    $preBlockCont =~ s/\n*$//gi;	# skip last newline
    $preBlockCont =~ s|<|&lt;|g; # <,> quoted also in preformated text!
    $preBlockCont =~ s|>|&gt;|g;
    $docContens .= "<PRE>\n$preBlockCont\n</PRE>\n";
    $isPre = 0;
  }  
  else
  {
    $docContens .= "$preBlockCont\n";
  }

  my ($fileHeader,$fileFooter) = makeDocStyle::blabla($title,$filetime,$ENV{USER});

  open(OUT_FILE, ">$outFileName") or die "can't open output file: $outFileName: $!";
  print OUT_FILE $fileHeader;

  if((!$config->{"nocontents"} || $config->{"nocontents"} eq "") && length($index) > 0)
  { $index = "<H2>Contents</H2>\n<DL>$index</DL><hr>\n";
    print OUT_FILE $index;
  }

  print OUT_FILE $docContens;
  print OUT_FILE $fileFooter;
  close OUT_FILE;


# get next paragraph from the text. A paragraph is either something that ends with '/n/n' - a
# 'blank line' or the 'end of file'.
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
