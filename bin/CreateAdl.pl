  eval 'exec perl -S $0 ${1+"$@"}'  # -*- Mode: perl -*-
	if $running_under_some_shell;
#
#   Understanding the data structure
# ========================================
# 
# The .substitution File:            the created data structure:
#                                    ----------------
# file Scraper.template {   $r_substData[0] = @group  =  [ $fileName = Scraper.template
#   { NAME="dummy"}                                        %item = ( NAME=>"dummy ) ]
# }                                  ----------------
# file Axis.template {      $r_substData[1] = @group  =  [ $fileName = Axis.template
#   { NAME="SCRPX2ZR",SNAME="motor"}                       %item = (NAME=>"SCRPX2ZR",SNAME=>"motor")
#   { NAME="SCRPY2ZR",SNAME="motor"}                       %item = (NAME=>"SCRPY2ZR",SNAME=>"motor")]
# }                                  ----------------
# file Axis.template {      $r_substData[2] = @group  =  [ $fileName = Axis.template
#   { NAME="SCRPX1ZR",SNAME="motor"}                       %item = (NAME=>"SCRPX2ZR") ]
# }                                  ----------------


    use strict;
    no strict "refs";
    use Text::ParseWords;
    use parse_subst;
    use Getopt::Long;
    $|=1;   # print unbuffred

    my $usage = "Usage: CreateAdl.pl [options] inFilename outFilename\n
     Options:
      -x pixel      		       X-Position of the panel (default=100)
      -y pixel      		       Y-Position of the panel (default=100)
      -w pixel       		       Panel width (default=900)
      -I searchPath                    Search paht(s) for panel widgets
      -M                               Create make dependencies
      -v                               Verbose, debug output
     ";

    my $displayWidth;
    my $displayHeight;
    my @searchDlPath;
    our($opt_v,$opt_x,$opt_y,$opt_M) = (0, 100, 100,"");
    die $usage unless GetOptions( "v","x","y","M","I=s"=>\@searchDlPath,"w=i"=>\$displayWidth);

    my ($inFileName, $outFileName) = @ARGV;
    die $usage unless defined $inFileName && defined $outFileName;

    $displayWidth = 900 unless( defined($displayWidth));

    my @dependencies;

# read and parse .substitution file
    my( $file, $r_substData);
    open(IN_FILE, "<$inFileName") or die "can't open input file: $inFileName";
    { local $/;
      undef $/; # ignoriere /n in der Datei als Trenner
      $file = <IN_FILE>;
    }  
    close IN_FILE;
    $r_substData = parse_subst::parse($file,'templateList');
    #parse_subst::dump($r_substData);

    my $facePlate;
    $facePlate = "groupX=0\ngroupY=0\ngroupWidth=$displayWidth\ngroupHeight=\n";

    my( $xNow, $yNow);	# put next part of display here 
    my ($widgetWidth, $widgetHeight);	# width height of actual display (.adl)
    foreach my $group (@$r_substData)
    { 	
	my $widgetName = shift @$group;	# the name of the .template/.adl file 
	my $adlFile;
	my $adlFlag;			# 0 if line is  nn.temlate, 1 if line is nn.adl!

	if( $widgetName =~ /^(.*)\.template/ )
	{ 
	    $adlFile = "$1.adl";
	    $adlFlag = 0;
	}
	elsif( $widgetName =~ /^.*\.adl/ )
	{ 
	    $adlFile = $widgetName;
	    $adlFlag = 1;
	}
        print "Item: $widgetName -> Widget:$adlFile, $adlFlag\n" if $opt_v == 1;
	my $adlPathFile;
	foreach(@searchDlPath)
	{
	    if(-e "$_/$adlFile")
	    {
		$adlPathFile = "$_/$adlFile";
		last;
	    }
	}

    	if( not defined $adlPathFile )
	{
	    warn "Skip '$widgetName':  no adl-file '$adlFile' found in: '",join(':',@searchDlPath),"'\n";
	    next;
	}
	elsif( $opt_M == 1)
	{
	    push @dependencies, $adlPathFile;
	    next;
	}
	    

	$xNow=0;
	$yNow+= $widgetHeight;	# add old y-size to get a new line for a new Disp
	($widgetWidth, $widgetHeight) = getDisplaySize($adlPathFile);

	foreach my $item (@$group)
	{ 
	    print "\t$$item{NAME}:\t " if $opt_v == 1;
	    setXy();

  # .template files has to have at least a NAME substitution all substitution but 
  # NAME and SNAME are ignored they are supposed to be database substitutions
	    if( $adlFlag==0 && $$item{NAME} )	
	    {   ##print "$adlFile: $$item{NAME}\n";
		$facePlate.="faceplateAdl=$adlFile";
		if( defined $$item{NAME} )
		{   $facePlate.="\nfaceplateMacro=NAME=$$item{NAME}"
		}
		if( defined $$item{SNAME} )
		{   $facePlate.=",SNAME=$$item{SNAME}";
		}
	    }

  # .adl files all substitutions are expanded
	    elsif( $adlFlag==1 )
	    { 	##print "$adlFile: \n";
    	    	$facePlate.="faceplateAdl=$adlFile";
        	if( scalar( keys(%$item) ) )
		{  
		    $facePlate.="\nfaceplateMacro=";
 		    foreach my $subst (keys(%$item) )
		    { $facePlate.="$subst=$$item{$subst},";
		    }
  		    chomp $facePlate; 	# remove last ','
		}
	  }
	  $facePlate.="\n";
    	}
    }

    if( ! $displayHeight ) {$displayHeight=$yNow + $widgetHeight;}
    $facePlate =~ s/groupHeight=/groupHeight=$displayHeight/;

    open(FILE, ">$outFileName") or die "  can't open output file: $outFileName";
    if( $opt_M == 1 )
    {
    	$inFileName = "../O.Common/$1.mfp" if $inFileName =~ /.*\/(.*)\..*$/;
	print FILE "$inFileName: ",join(' ',@dependencies),"\n\nDL += ";
	
    	foreach (@dependencies)
	{
	    if(/.*\/(.*\.adl)$/)
	    {
	    	print FILE "$1 ";
	    }
	}
	print FILE "\n";
	
    }
    else
    {
    	print FILE $facePlate;
    }
    close FILE;

#-------------------------------------------------------------------------------   
sub getDisplaySize
{   my($filename) = @_;

    my $x;
    my $width;
    my $hight;
    local $/;
#  print "Function getdisplaySize of $filename ";  
    die "sub getDisplaySize: can't open \'$filename\'\n" unless( open( ADL_FILE, "$filename") );
    undef $/;
    $_=<ADL_FILE>;
    if(/display\s+{.*?width=(\d+).*?height=(\d+)/s) 
    { 
	print "  Display $filename has width=$1 height=$2\n" if $opt_v == 1;
	$hight=$2; 
	$width=$1;
    }
    else
    { $hight=undef; 
      $$width=undef;
    }
#print "size x=$$r_width y=$$r_hight\n";
    close ADL_FILE;
    return ($width,$hight);
}
#-------------------------------------------------------------------------------   
sub setXy
{ 
    if( $xNow + $widgetWidth > $displayWidth )
    { $xNow = 0;
      $yNow += $widgetHeight;
    }
    print "  setXy to\tx=$xNow\ty=$yNow\tw=$widgetWidth\th=$widgetHeight\n" if $opt_v == 1;
    $facePlate.= "faceplateX=$xNow\n";
    $facePlate.="faceplateY=$yNow\n";
    $facePlate.="faceplateWidth=$widgetWidth\n";
    $facePlate.="faceplateHeight=$widgetHeight\n";
    $xNow += $widgetWidth;
}
