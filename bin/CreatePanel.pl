## CreatePanel.pl - List Panel Generation
# ************************************
# 
# *  Author:  Kuner
# 
# USAGE  :
# ========
#
#    Usage: CreatePanel.pl [options] inFilename outFilename\n
#
#     if inFilename  is '-', data is read from standard-in
#     if outFilename is '-', data is written to standard-out
#
#    Options:
#      -title  TitleString | Title.type Title of the panel (string or file). Default=no title
#      -baseW filename                  Base panel name for layout=xy
#      -x pixel      		        X-Position of the panel (default=100)
#      -y pixel      		        Y-Position of the panel (default=100)
#      -w pixel       		        Panel width (default=900)
#      -I searchPath                    Search paht(s) for panel widgets
#      -M                               Create make dependencies
#      -layout line|xy|grid|table       placement of the widgets, (default = by line) 
#      -type adl|edl                    Create edl or mfp file (default is edl)
#      -sort NAME                       Sort a group of signals. NAME is the name of a 
#                                       Name-Value pair in the substitution data.
#                                       this is done only for the layouts: 'line', 'table'
#      -subst 'NAME=\"VALUE\",...'      Panel substitutions from commandline
#      -v    	    	    	        verbose
#  
#
# Overview
# ========
# 
# This script provides for a way to create more complex edm or dm2k-mfp displayes from adl/edl-template widgets and 
# a definition file. The adl/edl-widgets are dm2k/edm displays that contain variables for PVs, strings or 
# whatever. The variables are defined in '.substitution' files, same syntax as EPICS substitution files.
#
# * There are generic adl/edl-templates for analog values, bits and strings.
#
# * There is the feature of (scaling: #scale) each widget in horizontal direction.
#
# * There are several panel (layouts: #layout) available: Table, Grid or Place to xy coordinates.
#
# * For EPICS.db or EPICS.template files there is a debug panel created to show each field of all records.
#
# 
# The substitution files
# ======================
# 
# The substitution files to create a panel have the same notation as EPICS database substitution files.
#
# For each EPICS template file there has to exist an edl/adl-template display with the same name. Unknown files 
# are skipped to give a chance to use just a subset of the substitution file for the panel. 
#
# The -I options define the search path for the widgets
#
# So the EPICS database substitution file may be used for a prototype panel in EPICS database development
# or if there is a generic panel and a EPICS template for a device
# 
# Notation in .substitution file | Panel Template
# -------------------------------+---------------
# file EPICS_db.template {       | EPICS_db.edl
# file panel.edl {               | panel.edl
# file panel.adl {               | panel.adl
# 
# Debug Panels
# ===========
#
# For EPICS.db or EPICS.template files there is a debug panel created to show each field of all records in
# the same order as in theEPICS.db file.
#
# *  Example:  Create a panel for each record of the template and set the Devicname with '-subst' option
#
# CreatePanel.pl -w 1030 -subst 'NAME="FOMZ1M:motor"' -I . -I ~/ctl/apps/genericTemplate/head/dl motorRdb.template test.edl
#
#

  eval 'exec perl -S $0 ${1+"$@"}'  # -*- Mode: perl -*-
	if $running_under_some_shell;

    use strict;
    no strict "refs";
    use Text::ParseWords;
    use parse_subst;
    use parse_db;
    use Getopt::Long;
    use Data::Dumper;
    $|=1;   # print unbuffred

    our($opt_v,$opt_x,$opt_y,$opt_M) = (0, 100, 100,"");
    my $type = "edl";
    my $title;
    my $layout;
    my $baseW;
    my $opt_sort;
    my $usage =
    my @searchDlPath;
    my $panelWidth;
    my $substPar;
    my $usage = 
"Usage: CreatePanel.pl [options] inFilename outFilename\n
       if inFilename  is '-', data is read from standard-in
       if outFilename is '-', data is written to standard-out
     Options:
      -title  TitleString | Title.type  Title of the panel (string or file). 
                                       Default=no title
      -baseW filename                  base panel name for layout=xy
      -x pixel      		       X-Position of the panel (default=100)
      -y pixel      		       Y-Position of the panel (default=100)
      -w pixel       		       Panel width (default=900)
      -I searchPath                    Search paht(s) for panel widgets
      -M                               Create make dependencies
      -layout xy | grid | table        placement of the widgets, 
                                       (default = by line) 
      -type adl|edl                    Create edl or mfp file (default is edl)
      -sort NAME                       Sort a group of signals. NAME is the 
                                       name of a Name-Value pair in the 
				       substitution data. This is ignored 
				       unless for layouts: 'line', 'table'
      -subst 'NAME=\"VALUE\",...'      Panel substitutions from commandline
      -v    	    	    	       verbose
     \n";
    my %dependencies;
    die unless GetOptions("M","I=s"=>\@searchDlPath,"v","x=i","w=i"=>\$panelWidth,"y=i",
    	    	    	  "type=s"=>\$type,"title=s"=>\$title,"layout=s"=>\$layout, 
			  "subst=s"=>\$substPar,"sort=s"=>\$opt_sort,"baseW=s"=>\$baseW);

    die $usage unless scalar(@ARGV) > 1;
    die "Illegal Panel type: '$type'" unless ( ($type eq 'edl') || ($type eq 'adl') );
    my $rH_subst = getSubstitutions($substPar) if defined $substPar;
    my( $inFileName, $outFileName) = @ARGV;
    $panelWidth = 900 unless( $panelWidth > 0);

    print "Create Panel in <- $inFileName out -> $outFileName, width = $panelWidth \n" if $opt_v == 1;
    if( $title =~ /\.$type$/ )
    {
        $title = "file $title {\n  {SCALE=\"$panelWidth\"}\n}\n";
	print "Title: '$title'\n" if $opt_v == 1;
    }
    elsif( defined $title )
    {
	print "Title: '$title' use file: 'text.$type'\n" if $opt_v == 1;
    	$title = "file text.$type {\n  {TEXT=\"$title\",WIDTH=\"$panelWidth\",COLOR=\"28\",TXTCOLOR=\"0\"}\n}\n";
    }
    	
#-- Read and parse input --

    my( $file, $r_substData);
    
    if ($inFileName eq '-') # read from stdin
      { *IN_FILE= *STDIN; }
    else
      { open(IN_FILE, "<$inFileName") or die "can't open input file: $inFileName"; }
      
    { local $/;
      undef $/; # ignoriere /n in der Datei als Trenner
      $file = <IN_FILE>;
    }  
    close IN_FILE if ($inFileName ne '-');
    die "Empty file: '$inFileName'" unless length($file) > 0;

    $file = $title.$file if( defined $title);

    $inFileName =~ /\.(\w+)\s*$/;
    my $fileType = $1;
    if($fileType eq 'substitutions') {
    	$r_substData = parse_subst::parse($file,'templateList');
    }
    elsif($fileType eq 'db' || $fileType eq 'template' ) {
    	$layout = 'dbDbg';
    	$r_substData = parse_db::parse($file,$inFileName,'asArray');
    }
#print "inFileName '$inFileName', fileType '$fileType', ",Dumper($r_substData),"\nSubstitutions '$substPar'):";print Dumper($rH_subst);die;

#-- Create layout dependant panel data --

    my $printEdl;
    my $panelHeight;
    if($layout eq "xy")
    {
        ($printEdl,$panelWidth, $panelHeight) = layoutXY($r_substData);
    }
    elsif($layout eq "grid")
    {
        ($printEdl,$panelWidth, $panelHeight) = layoutGrid($r_substData);
    }
    elsif($layout eq "table")
    {
        ($printEdl,$panelWidth, $panelHeight) = layoutTable($r_substData,$panelWidth);
    }
    elsif($layout eq "dbDbg")
    {
        ($printEdl,$panelWidth, $panelHeight) = layoutDbDbg($r_substData,$panelWidth,$rH_subst);
    }
    else
    {
        ($printEdl,$panelWidth, $panelHeight) = layoutLine($r_substData,$panelWidth);
    }
    
#-- write output

    print "\nDisplay: width=$panelWidth, height=$panelHeight\n" if $opt_v == 1;

    if ($outFileName eq '-')
      { *FILE= *STDOUT; }
    else
      { open(FILE, ">$outFileName") or die "  can't open output file: $outFileName"; };
      
    if( $opt_M == 1)
    {
    	$inFileName = "../O.Common/$1.edl" if $inFileName =~ /.*\/(.*)\..*$/;
	print FILE "$inFileName: ",join(' ',keys(%dependencies)),"\n";
    }
    elsif($type eq 'adl')
    {
        print FILE "groupX=0\ngroupY=0\ngroupWidth=$panelWidth\ngroupHeight=$panelHeight\n$printEdl";
    }
    else
    {
	my $header = "4 0 1\n".
	"beginScreenProperties\n".
	"major 4\n".
	"minor 0\n".
	"release 1\n".
	"x $opt_x\n".
	"y $opt_y\n".
	"w $panelWidth\n".
	"h $panelHeight\n".
	"font \"helvetica-medium-r-18.0\"\n".
	"ctlFont \"helvetica-medium-r-12.0\"\n".
	"btnFont \"helvetica-medium-r-18.0\"\n".
	"fgColor index 14\n".
	"bgColor index 72\n".
	"textColor index 14\n".
	"ctlFgColor1 index 14\n".
	"ctlFgColor2 index 29\n".
	"ctlBgColor1 index 2\n".
	"ctlBgColor2 index 2\n".
	"topShadowColor index 1\n".
	"botShadowColor index 6\n".
	"endScreenProperties\n";
	print FILE $header;
	print FILE $printEdl;
    }
    close FILE if ($outFileName ne '-');


## (anchor: #layout)
#
#  Layout of the created display
#  =============================
#
#  The commandline option '-layout' determines which way the edl templates are placed in the Display
#
#  Layout by line (Default)
#  ........................
#
#  Widget1 | Widget2 | Widget3 
#  --------+--------------------
#  Widget4 | Widget5 | Widget6 
#  Widget7 | Widget8 | Widget9 
#
#
#  * The Widgets are placed from the left to the right - as written in a line - as long as the display 
#    width is not exceeded. Then a new line begins.
#
#  * The total width of the panel is set by the argument '-width', or set to 900 by default.
#
#  * A new line begins if there is a new  edl-template type.
#
#  * The order of widgets may be set ba the option '-sort NAME'. NAME is any name of a variable in 
#    the '.substitutions' file
# 
sub   layoutLine
{   my ($r_substData,$displayWidth) = @_;

    my $prEdl;

    my( $xPos, $yPos);	    	    # put next part of display here 
    print "layout: Line\n" if $opt_v == 1;

    $yPos=0;
    foreach my $group (@$r_substData)
    { 
    	
        my $edlFileName = shift @$group;	# the name of the .template/.edl file 
    	# get content, width and height of actual edl-template
	my ($edlContent, $xDispSize, $yDispSize) = getDisplay($edlFileName);
    	next unless defined $edlContent;

	$xPos=0;    # begin new display type with a new line
    	print "Display '$edlFileName': $xDispSize, $yDispSize\n" if $opt_v == 1;

        $group = sorted($group, $opt_sort,$edlFileName) if length($opt_sort)> 0;
	foreach my $rH_Attr (@$group)
	{ 
    	    print "'$edlFileName' $xPos,$yPos\n" if $opt_v == 1;
	    my $edl;

    	    my ($xDispWIDTH, $xScale) = getWidth($xDispSize,$rH_Attr);
	    $edl = setWidget($edlContent,$xDispWIDTH,$yDispSize,$rH_Attr, $xScale,$xPos,$yPos);
# setup next position
	    if( $xPos + 2*$xDispWIDTH > $displayWidth )
	    { 
    		$xPos = 0;
    		$yPos += $yDispSize;
	    }
	    else
	    {
    		$xPos += $xDispWIDTH;
	    }
#print "$xPos,$yPos\n";
	    die "Error in file \'$edlFileName\', data line:", Dumper($rH_Attr) unless defined $edl;
	    $prEdl .= "$edl" if defined $edl;
#print "=====>\n$edl\n=====\n";
	}
	$yPos += $yDispSize if $xPos > 0;
	
    }

    return ($prEdl,$displayWidth, $yPos);
}    

##  Layout by table
#  ........................
#
#  Widget1 | Widget4 | Widget7 
#  --------+--------------------
#  Widget2 | Widget5 | Widget8 
#  Widget3 | Widget6 | Widget9 
#
#  * The widgets are placed in columns top down and rows right to left. 
#
#  * The total width of the panel is set by the argument '-width', or set to 900 by default.
#
#  * A new linene begins if there is a new  edl-template type.
#
#  * The order of widgets may be set ba the option '-sort NAME'. NAME is any name of a variable in 
#    the '.substitutions' file
# 
sub   layoutTable
{   my ($r_substData,$displayWidth) = @_;

    my $prEdl;

    my( $xPos, $yPos);	    	    # put next part of display here 
    print "layout: Table\n" if $opt_v == 1;

    $yPos=0;
    foreach my $group (@$r_substData)
    { 
    	
        my $edlFileName = shift @$group;	# the name of the .template/.edl file 
    	# get content, width and height of actual edl-template
	my ($edlContent, $xDispSize, $yDispSize) = getDisplay($edlFileName);
    	next unless defined $edlContent;

	$xPos=0;    # begin new display type with a new line
    	print "Display '$edlFileName': $xDispSize, $yDispSize, yPos = $yPos\n" if $opt_v == 1;

 
        $group = sorted($group, $opt_sort,$edlFileName) if length($opt_sort)> 0;
	my %pv_attr;
	my $widthMax;
	foreach my $rH_Attr (@$group)
	{
	    my ($xDispWIDTH, $xScale) = getWidth($xDispSize,$rH_Attr);
	    $widthMax = ($xDispWIDTH > $widthMax) ? $xDispWIDTH : $widthMax;
	}
    	print "\tTable   item widthMax=$widthMax, (display width=$displayWidth)\n" if $opt_v == 1;

	my $cols = int($displayWidth / $widthMax);
	my $rows = scalar(@$group) / $cols;
	$rows = int($rows+1) if( $rows - int( $rows) );

    	print "\t\tcols=$cols, rows=$rows\n" if $opt_v == 1;

	my $idx;
	foreach my $rH_Attr (@$group)
	{   
	    my $x = int ($idx / $rows) * $widthMax;
	    my $y = ($idx - int($idx / $rows) * $rows) * $yDispSize;
	    
	    my $edl;
    	    my ($xDispWIDTH, $xScale) = getWidth($xDispSize,$rH_Attr);
	    $edl = setWidget($edlContent,$xDispWIDTH,$yDispSize,$rH_Attr, $xScale,$x,$y+$yPos);
	    die "Error in file \'$edlFileName\', data line:", Dumper($rH_Attr) unless defined $edl;
	    $prEdl .= "$edl" if defined $edl;
	    
	    $idx++;
	}

	$yPos += $rows * $yDispSize;
    }

    return ($prEdl,$displayWidth, $yPos);
}    

## Layout XY: Place each widget to a fixed position
#  ........................
#
#  The option '-layout xy'  will place each item of the '.substitutions' file to the position defined by
#  the variable 'PANEL_POS'. This variable defines the x/y position in pixel and has to be set for each 
#  edl-template instance.
#
#  As base widget to print the edl-templates in there has to exist a '.edl' file with the same name as the 
# .substitutions file
#
sub    layoutXY
{   my ($r_substData) = @_;

    my $baseWidget = (defined $baseW) ? $baseW : $inFileName;
    $baseWidget =~s/\.substitutions/\.edl/;
    
    my ($prEdl, $displayWidth, $displayHeight) = getDisplay($baseWidget);
    die "can' find base widget: \'$baseWidget\'" unless defined $prEdl;
    print "layout XY: base panel: $baseWidget: w=$displayWidth, h=$displayHeight\n" if $opt_v == 1;


    foreach my $group (@$r_substData)
    { 
    	
        my $edlFileName = shift @$group;	# the name of the .template/.edl file 
	my ($edlContent, $xDispSize, $yDispSize) = getDisplay($edlFileName);
    	next unless defined $edlContent;

    	print "Display $edlFileName: $xDispSize, $yDispSize\n" if $opt_v == 1;

	foreach my $rH_Attr (@$group)
	{ 
	    my ($xPos,$yPos) = split(',',$rH_Attr->{PANEL_POS});
#print "Pos($xPos,$yPos) /$edlFileName/ ";
    	    if(not defined $xPos || not defined $yPos)
	    {
	    	warn "Can't find PANEL_POS in ", join(',', @$rH_Attr);
	    	next;
	    }
	    my $edl;
    	    my ($xDispWIDTH, $xScale) = getWidth($xDispSize,$rH_Attr);
	    $edl = setWidget($edlContent,$xDispWIDTH,$yDispSize,$rH_Attr, $xScale,$xPos,$yPos);
	    die "Error in file \'$edlFileName\', data line:", Dumper($rH_Attr) unless defined $edl;
	    $prEdl .= "$edl" if defined $edl;
	}
    }

    return ($prEdl,$displayWidth, $displayHeight);
}

## Layout GRID: Place each widget to a table by grid parameters
#  ........................
#
#  Widget1.1 | Widget1.2 | Widget1.3 
#  --------+--------------------
#  Widget2.1 | Widget2.2 | Widget2.3 
#  Widget3.1 | Widget3.2 | Widget3.3 
#
#  The option '-layout GRID'  will place each item of the '.substitutions' file to the position defined by
#  the variable 'GRID="COL,ROW"'. This parameter defines the column and row and has to be set for each edl-template
#  instance. Parameter SPAN="n-Cols"' may be set to span in horizontal direction.
#
sub    layoutGrid
{   my ($r_substData) = @_;

    print "layout Grid: \n" if $opt_v == 1;
    my @table;	    # rH_data = table[col]->[row]
    my @colMaxWidth;
    my @rowMaxWidth;
    foreach my $group (@$r_substData)
    { 
    	
        my $edlFileName = shift @$group;	# the name of the .template/.edl file 
	my ($edlContent, $xDispSize, $yDispSize) = getDisplay($edlFileName);
    	next unless defined $edlContent;
#print "Display $edlFileName: $xDispSize, $yDispSize\n";

	foreach my $rH_Attr (@$group)
	{ 
	    my ($xGrid,$yGrid) = split(',',$rH_Attr->{GRID});
    	    if(not defined $xGrid || not defined $yGrid)
	    {
	    	warn "Can't find PANEL_POS in ", join(',', @$rH_Attr);
	    	next;
	    }
	    my $edl;
    	    my ($xDispWIDTH, $xScale) = getWidth($xDispSize,$rH_Attr);
#print "  GRID($xGrid,$yGrid) /$edlFileName/ $xDispWIDTH/$yDispSize, $xScale\n";

	    if(defined $rH_Attr->{SPAN} )
	    {
	    	$table[$xGrid]->[$yGrid]->{SPAN} = $rH_Attr->{SPAN};
	    }
	    else
	    {
	    	$colMaxWidth[$xGrid] = ($xDispWIDTH > $colMaxWidth[$xGrid]) ? $xDispWIDTH : $colMaxWidth[$xGrid] ;
	    }
	    $rowMaxWidth[$yGrid] = ($yDispSize > $rowMaxWidth[$yGrid]) ? $yDispSize : $rowMaxWidth[$yGrid];

	    $table[$xGrid]->[$yGrid]->{xDispWIDTH} = $xDispWIDTH;
	    $table[$xGrid]->[$yGrid]->{xScale}     = $xScale;
	    $table[$xGrid]->[$yGrid]->{xGrid}      = $xGrid;
	    $table[$xGrid]->[$yGrid]->{yGrid}      = $yGrid;
	    $table[$xGrid]->[$yGrid]->{yDispSize}  = $yDispSize;
	    $table[$xGrid]->[$yGrid]->{rH_Attr}    = $rH_Attr;
	    $table[$xGrid]->[$yGrid]->{edlContent} = $edlContent;
	}
    }
    
#print "row [",join(',',@rowMaxWidth),"]\ncol [",join(',',@colMaxWidth),"]\n";
    my $prEdl;

    my($displayWidth, $displayHeight); # total display size
    my $col  = 0;
    my $xPos = 0;
    foreach (@table)
    {   
	my $row=0;
    	my $yPos = 0;
	foreach my $rH ( @{$table[$col]} )
	{
	    if( defined $rH )
	    {
    	    	my $span = $rH->{SPAN};
		my $colLast = $col+$span -1;
		if(defined $span)
		{
		    my @s = @colMaxWidth[$col..$colLast-1];
		    my $spanedWidth;
		    $spanedWidth += $_ foreach (@s);
#print "\tspan $col - $colLast = $rH->{xDispWIDTH} OR [",join('+',@s),",$colMaxWidth[$colLast]] => colMaxWidth[",$colLast,"] = ",$rH->{xDispWIDTH}  - $spanedWidth,"\n";

		    if( $spanedWidth + $colMaxWidth[$colLast] < $rH->{xDispWIDTH})
		    {
		     	$colMaxWidth[$colLast] = $rH->{xDispWIDTH}  - $spanedWidth;
		    }
		}
#print "[$col,$row]  $xPos,$yPos  $rH->{xDispWIDTH},$rH->{yDispSize}\n";
	    
		my $edl = setWidget($rH->{edlContent},$rH->{xDispWIDTH},$rH->{yDispSize},
	    	    	    	    $rH->{rH_Attr},$rH->{xScale},$xPos,$yPos);
		die "Error in GRID($col,$row), data line:", Dumper($rH->{rH_Attr}) unless defined $edl;
		$prEdl .= "$edl" if defined $edl;
#die if($col==1 && $row==1);
    	    }	    
	    
	    $yPos += $rowMaxWidth[$row];
	    # Set next Position
	    $row++;
	}
	$xPos += $colMaxWidth[$col];
    	$col++;
    }
    
    
    $displayHeight += $_ foreach(@rowMaxWidth);

#print "Panel Size:  $xPos, $displayHeight\n";   
    return ($prEdl,$xPos, $displayHeight);
}

sub   layoutDbDbg
{   my($r_db,$panelWidth,$rH_Subst)=@_;

    my $prEdl;
    my $panelHeight;
    my ($recHeadContent, $widgetWidth, $recHeadHight) = getDisplay('recHead.template');
    my ($itemContent, $itemWidth, $itemHight) = getDisplay('item.template');
    
#print "layoutDbDbg(r_db,$panelWidth,subst), $recHeadHight, $itemHight attr=", Dumper($rH_Subst);

    $widgetWidth = $itemWidth if $itemWidth > $widgetWidth;
    my $colHight;
    my $colMaxHight;
    my $xPos=0;
    my $yPos=0;
    foreach (@$r_db)
    {
    	my $recName = $_->{NAME};
	$recName = parseVars($recName,$rH_Subst);
	my $rA_fields = $_->{ORDERDFIELDS};
	$rH_Subst->{DEVNAME} = $recName;
#print " record: $recName, \t",Dumper($rH_Subst);

	my $edl = setWidget($recHeadContent,$widgetWidth,$recHeadHight,$rH_Subst,undef,$xPos,$yPos);
	die "Error setWidget($recHeadContent,$widgetWidth,$recHeadHight,rH_Subst,undef,$xPos,$yPos)" unless defined $edl;
	$prEdl .= "$edl" if defined $edl;
	
	$colHight = $recHeadHight;
	
	foreach (@$rA_fields)
	{
	    $rH_Subst->{FIELD} = $_;
#print "\tFIELD: $_, y=$yPos, col=$colHight y=",$yPos+$colHight,"\t";
	    my $edl = setWidget($itemContent,$widgetWidth,$itemHight,$rH_Subst,undef,$xPos,$yPos+$colHight);
	    die "Error setWidget($recHeadContent,$widgetWidth,$recHeadHight,rH_Subst,undef,$xPos,$yPos+$colHight)" unless defined $edl;
	    $prEdl .= "$edl" if defined $edl;
	
	    $colHight += $itemHight;
	}
	$colMaxHight = $colHight if $colHight > $colMaxHight;
	$xPos += $widgetWidth;
	if($xPos + $widgetWidth > $panelWidth)
	{
	    $xPos = 0;
	    $yPos += $colMaxHight;
	    $colMaxHight = 0;
	}
    }
    return ($prEdl,$panelWidth, $yPos+$colMaxHight);
}

## The edl templates are searched in the search paths as defined by the -I options
# 
sub   getTemplate
{   my ($itemName) = @_;

    my $widgetName;
    my $widgetPath;
    my $widgetContent;

    if( $itemName =~ /^(.*)\.template/ )
    { $widgetName = "$1.$type";
    }
    elsif( $itemName =~ /^.*\.$type/ )
    { $widgetName = $itemName;
    }

    foreach(@searchDlPath)
    {
	if(-e "$_/$widgetName")
	{
	    $widgetPath = "$_/$widgetName";
	    last;
	}
    }

    if( not defined $widgetPath )
    {
	warn "Skip '$itemName':  no ${type}-file '$widgetName' found in: '",join(':',@searchDlPath),"'\n";
	return undef;
    }
    elsif( $opt_M == 1)
    {
    	$dependencies{$widgetName} = 1;
#print "-M Widget = $widgetName\n";
	return undef;
    }

    open( DL_FILE, "$widgetPath") or die "getTemplate: can't open \'$widgetPath\'\n";
    local $/;
    undef $/;
    $widgetContent=<DL_FILE>;
    close DL_FILE;
    return $widgetContent;
}
# get the default size of a edl snippet. This size may be overwritten by a 'WIDTH' parameter.
# 
# *  Return:  ($widgetContent,$width,$height) the edl file without display section and the size of the panel
sub   getDisplay
{   my($widgetFileName) = @_;

    my $widgetContent = getTemplate($widgetFileName);;
    return undef unless defined $widgetContent;

    my $width;
    my $height;

    # strip Screen properties
    if( $type eq 'edl' && $widgetContent =~ /(beginScreenProperties.*endScreenProperties)/s)
    {
	my $match = $&; # text that matches
	$widgetContent = $';      # text after match 
	
	if($match =~ /\sw (\S+)\sh (\d+)\s/s)
	{
	    $width = $1;
	    $height = $2;
	}
	else
	{
    	    warn "Skip '$widgetFileName', Cann't find screen width/height";
	    return undef;
	}
    }
    elsif( $type eq 'adl' && $widgetContent =~ /^.*display\s*\{\s*object\s*\{.*?width=(\d+)\s*height=(\d+)/s)
    {
	$width = $1;
	$height = $2;
	$widgetContent = $widgetFileName; # don't need content for mfp files, but the filename for macros - see setAdlWidget
    }
    else
    {
    	warn "Skip '$widgetFileName', Can't find screen properties in ....",substr($widgetContent,80,100),"...";
	return undef;
    }

    return ($widgetContent,$width,$height);
}

## Variables in edl templates
# ======================
# 
# *  Notation:  '$(VARIABLE)'
# 
# Variables may occur in editable string fields of the edl-template, means in the edl in all 
# places where they may be typed. If variables are written by an editor to places where 
# edm expect a numeric value edl will fail to open the unsubstituted edl-template, but the 
# variables will be substituted by its values as defined in the '.substitution' file and edl 
# will run the substituted panel.
# 
# For the generic templates there is the convention to have this variable:
# 
# * $(PV) = proces variable name
# 
# *  Attention  : variables for .adl files are given as macro substitutions to the widget instance 
#    in the '.mfp' file. So variables may only occur on places where dm2k allows it. EDM panels are
#    a copy of the widgets, so variables may occur anywhere and are substituted in the output file.
#
sub   parseVars
{   my ($value,$rH_Attr) = @_;

    my $parseVal = $value;
    my $varName;
#print "\n******VALUE:\n$value******\n", Dumper($rH_Attr);
    while( $parseVal =~ /\$\((.*?)\)/ ) # check for all occuring varNames: $(VARNAME)
    {
        $varName = $1;
        $parseVal = $';
        my $varValue = $rH_Attr->{$varName};
        $value =~ s/\$\($varName\)/$varValue/g ;
#print "\t\$($varName)\t= /'$varValue/'";
    }
#print "\n";
    return $value;
}

## Special processing of the PV variable (.edl only)
#  ================================================
# 
# A PV substitution that contains a field is truncated to the PV name for PV definitions in the 
# widget that contains also fields. What is this usefull for?
#
# For bi/bo, MBBI/MBBO records it may be usefull to display the .DESC field and the status or the 
# Value of the record. The widget may define just the PV for text message and also the status as text.
# So the user of this widget is free to define the variable PV to PVNAME or PVNAME.DESC and 
# the status in the widget defined as "$(PV).STAT" will be substituted correct in both cases!
#
# Definition in .substitution file  | Definition in .edl-template| substitution result
# --------------------------------+--------------------------+---------------
# PV="DEVICE"                     | controlPv="$(PV)"        | controlPv="DEVICE"
# PV="DEVICE"                     | controlPv="$(PV).LLS"    | controlPv="DEVICE.LLS"
# PV="DEVICE"                     | controlPv="$(PV):sig"    | controlPv="DEVICE:sig"
# PV="DEVICE.DESC"                | controlPv="$(PV)"        | controlPv="DEVICE.DESC"
# PV="DEVICE.DESC"                | controlPv="$(PV).LLS"    | controlPv="DEVICE.LLS"
# PV="DEVICE.DESC"                | controlPv="$(PV):sig"    | controlPv="DEVICE:sig"
# PV="DEVICE:sig"                 | controlPv="$(PV)"        | controlPv="DEVICE:sig"
# PV="DEVICE:sig"                 | controlPv="$(PV).LLS"    | controlPv="DEVICE:sig.LLS"
# PV="DEVICE:sig"                 | controlPv="$(PV):sig"    | controlPv="DEVICE:sig:sig"
# 
sub   parsePV
{   my ($parseVal,$rH_Attr) = @_;

    my $pv = $rH_Attr->{PV};
# support the old NAME SNAME style in substitutions files for creation of a PV
    if( defined $rH_Attr->{NAME} && defined $rH_Attr->{SNAME} && not defined $rH_Attr->{PV})
    {
    	$pv = "$rH_Attr->{NAME}:$rH_Attr->{SNAME}" ;
    }
    
    my $pvTrunc;
    if( $pv =~/(.*)\./)
    {
    	$pvTrunc = $1;
    }
    else
    {
    	$pvTrunc = $pv;
    }
    my $value;	# holds the substituted $parseVal
    my $varName;
#print "\n******VALUE:\n$value******\n", Dumper($rH_Attr);
    while(  ) # check for all occuring varNames: $(PV)
    {
        if( $parseVal =~ /\$\(PV\)\./ ) # match a $(PV).FIELD notation
	{
	    $value .= "$`$pvTrunc.";
            $parseVal = $';
#print "set . pvTrunc=$pvTrunc\n";
	}
        if( $parseVal =~ /\$\(PV\):/ )  # match a $(PV):SIGNAL...  notation
	{
	    $value .= "$`$pvTrunc:";
            $parseVal = $';
#print "set : pvTrunc=$pvTrunc\n";
	}
        elsif( $parseVal =~ /\$\(PV\)/) # match a $(PV) notation
	{
            $parseVal = $';
	    $value .= "$`$pv";

#print "set pv=$pv\n";
            my $varValue = $rH_Attr->{$varName};
            $value =~ s/\$\($varName\)/$varValue/g ;
#print "\t\$($varName)\t= /'$varValue/'";
    	}
	else	    	    	    	 # exit if there is no more $(PV)
	{
	    $value .= $parseVal;
	    last;
	}
    }
#print "\n";
    return $value;
}

##  (anchor: #scale)
#
#  Scaling the widgets
#  ====================
#
# The variables 'SCALE="width"' and 'WIDTH="width"' may occur in the substitution file to control the width of a widget.
#
# If the variable 'WIDTH' is defined the whole widget width is set to 'WIDTH'. All variables '$(WIDTH)' in the 
# edl-template are substituted to a calculated width: 'w=WIDTH-x' to take care of the x-position of the object. 
#
# For .mfp files WIDTH works the same way as SCALE
#
# If the parameter 'SCALE' is defined it means the whole edl-template is scaled from its original width 
# to the size of the parameter 'SCALE'. The 'x' and 'w' values of all points of each object are scaled.
#
sub   getWidth
{   my ($xDispSize,$rH_Attr) = @_;

#    return $xDispSize if $type eq 'adl'; # adl doesn't support scaling!
    my $xScale;
    my $xDispWIDTH;
# parse for WIDTH parameter and set it
    if (defined $rH_Attr->{WIDTH} && not defined $rH_Attr->{SCALE} )
    {
    	$xDispWIDTH =$rH_Attr->{WIDTH};
    }
    #  scale all 'x' and 'w' in the objects of the panel
    elsif( defined $rH_Attr->{SCALE} && not defined $rH_Attr->{WIDTH})
    {
    	$xDispWIDTH = $rH_Attr->{SCALE};
    	$xScale = $rH_Attr->{SCALE} / $xDispSize ;
#print "Set scale: $rH_Attr->{SCALE} / $xDispSize = $xScale\n";	
    }
    elsif( not defined $rH_Attr->{SCALE} && not defined $rH_Attr->{WIDTH})
    {
    	$xDispWIDTH = $xDispSize;
    }
    else
    {
	warn "Illegal parameters in substitution file: can't define SCALE and WIDTH!";
	return; # 'undef' is the error condition
    }
#print "xDispWidth = $xDispWIDTH, ".(defined $xScale);
    return ($xDispWIDTH, $xScale)
}

sub   setWidget
{   my ($parse,$xDispWIDTH,$yDispSize,$rH_Attr, $xScale,$xPos,$yPos) = @_;

#print "setWidget(parse,$xDispWIDTH,$yDispSize,rH_Attr, $xScale,$xPos,$yPos)\n";
    my $edl;
    if($type eq 'adl')
    {
    	return setAdlWidget($parse,$xDispWIDTH,$yDispSize,$rH_Attr, $xScale,$xPos,$yPos);
    }
    
# ATTENTION make shure that this regexp matches only one object,means one x= ..y=  w= section!!
    while( $parse =~ /(.*?\n\n)/s )
    {
	$parse = $';
	my $object = $&;
	
    	my $x;
    	my $y;
    	my $width;

#print "Obj: $1\t=> " if $parse =~ /\#\s*\((.*)\)/;

# Substitute $(WIDTH) variable
	if(  $object =~ /\s*x\s+(\d+)\s*y\s+(\d+)\s*w\s+(\$\(WIDTH\))/ )
	{
	    if( defined $xScale)
	    {
	    	warn "Can't SCALE a display that has a \$(WIDTH) variable";
		return ;
	    }
	    $width = $xDispWIDTH - $1;
	    $x=$1 + $xPos;
	    $y=$2 + $yPos;
#print "  calc \$(WIDTH) = $width";
	}
# scale x, y, w
	elsif($object =~ /\s*x\s+(\d+)\s*y\s+(\d+)\s*w\s+(\d+)/ )
	{
	    $x = $1;
	    $y = $2;
	    $width = $3;
	    if( defined $xScale )
	    {
		$x = int($1 * $xScale);
		$width = int($width * $xScale);
#print "  SCALE: x=$1->$x, y=$y, w=$3->$width";
	    }
	    $y=$2 + $yPos;
	    $x=$x + $xPos;
	}
	else
	{
#warn "Can't find x, y, w section in Display\n******Begin******$object******End Object ******\n";
	    $edl .= $object;
	    next;
	}

# set x, y to position in panel
#print " set to: \t$x, $y\n";
	$edl .= "$`\nx $x\ny $y\nw $width\n";
	my $rest = $';

	if($rest =~ /\s*xPoints\s*\{\s*(.*?)\s*\}/s)
	{
	    $edl .= $`;
	    $rest = $';
	    my $points = processPoints($1,$xPos,$xScale);
#print "\tXpoint,$xPos:$points\n";
	    $edl .= "\nxPoints {\n$points}";
	    if($rest =~ /\s*yPoints\s*\{\s*(.*?)\s*\}/s)
	    {
		$edl .= $`;
		$rest = $';
		my $points = processPoints($1,$yPos);
#print "\tYpoint:$points\n";
		$edl .= "\nyPoints {\n$points}$rest";

	    }
	}
	else
	{
	    $edl .= "$rest";
	}

# substitute the PV variable
        $edl = parsePV($edl,$rH_Attr);

# substitute all other variables
    	$edl = parseVars($edl,$rH_Attr);
    }
    return $edl;   
}

sub   processPoints
{   my ($p,$add,$scale) = @_;

    $scale = 1.0 unless defined $scale;
    my $ret;
    my @pt = split(/\n/,$p);

    foreach my $p ( @pt )
    {
    	$p =~ /\s*(-*\d+)\s*(\d+)/s;
	my $p_scale = ($2+$add) * $scale;
	$ret .= "  $1 $p_scale\n";
#print "\t($2), $ret";
    }
    return $ret;
}

# lexical sort of the widgets
sub   sorted
{   my ($rA, $opt_sort,$grp)=@_;
    foreach (@$rA)
    {
    	unless( defined $_->{$opt_sort} )
	{
	    print "\tSorting: skip $grp: Can't find '$opt_sort' in: (",join(',',keys(%$_)),")\n" if $opt_v == 1;
	    return $rA;
	}
    }
    my @rSort = sort {
    	return 0 if $a->{$opt_sort} eq $b->{$opt_sort};
    	return 1 if $a->{$opt_sort} gt $b->{$opt_sort};
    	return -1 if $a->{$opt_sort} lt $b->{$opt_sort};
    
    } @$rA;

#    for(my $idx=0; $idx<scalar(@$rA); $idx++){print "$$rA[$idx]->{SNAME}\t$$rA[$idx]->{SNAME}\n" ;}
    return \@rSort;
}
sub   cmpFunc 
{ #print "ab:$a->{$opt_sort},$b->{$opt_sort}\n"; 
    $a->{$opt_sort} <=> $a->{$opt_sort} 
}

sub   setAdlWidget
{   my ($widgetFileName,$widgetWidth,$widgetHeight,$rH_Attr, $xScale,$xPos,$yPos) = @_;
    my $facePlate;
    $facePlate.= "faceplateX=$xPos\n";
    $facePlate.="faceplateY=$yPos\n";
    $facePlate.="faceplateWidth=$widgetWidth\n";
    $facePlate.="faceplateHeight=$widgetHeight\n";

    my $adlFile = 1;
    my $widgetFileStem;
    if( $widgetFileName =~ /^(.*)\.template/ )
    {
    	$widgetFileStem=$1;
	$adlFile = 0;
    }
#print "setAdlWidget($widgetFileName,$widgetWidth,$widgetHeight,rH_Attr, $xScale,$xPos,$yPos)",Dumper($rH_Attr) if $widgetFileName =~ /text/;

# .template files must have at least a substitution for the porcess variable name. 
# Possible identifiers are: NAME, NAME + SNAME, PV and TEXT for text.adl widget
# All other substitutions are ignored they are supposed to be database substitutions
    if( $adlFile==0)
    {   
	$facePlate.="faceplateAdl=$widgetFileStem.adl";
	if( length( $$rH_Attr{NAME} ))
	{   
	    $facePlate.="\nfaceplateMacro=NAME=$$rH_Attr{NAME}";
	    if( length( $$rH_Attr{SNAME}) )
	    {   $facePlate.=",SNAME=$$rH_Attr{SNAME}";
	    }
	}
	elsif( length( $$rH_Attr{PV} ))
	{   
	    $facePlate.="\nfaceplateMacro=PV=$$rH_Attr{PV}";
	}
	elsif( length( $$rH_Attr{TEXT}) && ($widgetFileName eq 'text.template'))
	{   
	    $facePlate.="\nfaceplateMacro=TEXT=$$rH_Attr{TEXT}";
	}
	else
	{
	    die "No PV substitutions found for:setAdlWidget($widgetFileName,$widgetWidth,$widgetHeight,rH_Attr, $xScale,$xPos,$yPos)",Dumper($rH_Attr)
	}
    }

# for .adl files all substitutions are expanded
    elsif( $adlFile==1 )
    { 	
	$facePlate.="faceplateAdl=$widgetFileName";
	if( scalar( keys(%$rH_Attr) ) )
	{   my $str = join(',', map{"$_=$rH_Attr->{$_}"} keys(%$rH_Attr));
	    $facePlate.="\nfaceplateMacro=$str";
	}
    }
    $facePlate.="\n";
    return $facePlate;
}

## Regexp token parser
#  ===================
#
#  The Tokens are processed in the defined order.
#
#  *  Token definition  : a list of regexp containing one or three elements:
#
#  - One element: The regexp to rekognize the token
#  - Three elements: Token begin , Token content, Token limiter
#
sub parse
{   my ($parse, $rA_tokDefList,$mode)=@_;
    
    my $errStr;
    my @tokList;
    unshift @$rA_tokDefList, ['FORGETT_SPACE_CHARACTERS',[qr(^\s+)]] if $mode eq 'ignoreSpace';
#print Dumper($rA_tokDefList); 
    while($parse)
    {
    	my $tokContent;
	my $tokName;
	foreach (@$rA_tokDefList)
	{
	    $tokName = $_->[0];
	    my $rA_tokDef = $_->[1];
	    my $tokRE = $rA_tokDef->[0];

	    if( $parse =~ $tokRE)
	    {	
#print "Found: token: '$tokName'='$tokRE' parse='$parse':";
	    	$parse=$';
    	    	$tokContent = $&;
	    	if( $tokName eq 'FORGETT_SPACE_CHARACTERS')
		{
#print "Ignore: token: '$tokName'='$tokRE' parse='$parse':";
		    $tokContent = undef;
		    last ;
		}
		$tokRE = $rA_tokDef->[1];
		if( defined $tokRE) # is a three RE token
		{
#print "\tTRY content: '$tokName', '$tokRE':";
		    if( $parse =~ $tokRE) # token content
		    {	
		    	$parse=$';
	    		$tokContent = $&;
		    	$tokRE = $rA_tokDef->[2];
#print "\t\tTRY delimiter: '$tokName', '$tokRE':";
			if( defined $tokRE && $parse =~ $tokRE) # token delimiter
			{
			    $parse=$';
			    last;
			}
			else
			{
			    $errStr .= "Can't find token delimiter for $tokContent***$parse";
			    last
			}
		    }
		    else
		    {
			$errStr .= "Can't find token Content for $parse";
		    }
		}
		else	# was a one RE token
		{
		    last;
		}
#print "END tokens";
	    }
	}
    	if( defined $tokContent && length($errStr)==0)
	{
#print "\nmatch '$tokName','$tokContent'\n";
	    push @tokList, [$tokName,$tokContent]
	}
	elsif( $tokName ne 'FORGETT_SPACE_CHARACTERS')
	{
	    $errStr = "Can't find token in: '$parse'" if( length($errStr)==0 );
	    warn "PARSE ERROR: ".$errStr;
	    return undef;
	}

    }
#print "TOK LIST = ",join(",",map{"$_->[0]='$_->[1]'"}@tokList),"\n";
    return \@tokList;
}

## Parse string for name value pairs.
#
#  * Syntax: NAME="VALUE",NAME2="VALUE2",...
#
#  *  Return  : Hash = {NAME=>"VALUE",NAME2=>"VALUE2"}
#
sub getSubstitutions
{   my($parse) = @_;

    my @token = (
        ['QSTR' , [qr(^"), qr(^(?:[^"\\\\]+|\\\\(?:.|\n))*), qr(")]],# matches a "quoted" string
    	['SEP_NV'  , [qr(^=)]],
    	['SEP_ITEM', [qr(^,)]],
        ['NAME' , [qr(^[a-zA-Z0-9_\-:\.\$]+)]]          # matches an unquoted string contains [a-zA-Z0-9_\-] followed by '='
	);

    my $rA_toks = parse($parse,\@token,'ignoreSpace');
    die "PARSE ERROR" unless defined $rA_toks;
#print " parse($parse) = ",Dumper($rA_toks);
    my %subst;
    while()
    {
	my ($tok,$tokVal) = @{shift @$rA_toks};
#print "\t1 ($tok,$tokVal) \tNAME || SEP_ITEM || undef\n";
	last unless defined $tok;
     	($tok,$tokVal) = @{shift @$rA_toks} if $tok eq 'SEP_ITEM';
	if($tok eq 'NAME')
	{
	    my $name = $tokVal ;
	    ($tok,$tokVal) = @{shift @$rA_toks};
#print "\t2 ($tok,$tokVal) \tSEP_NV \n";
    	    return undef unless $tok eq 'SEP_NV';
	    ($tok,$tokVal) = @{shift @$rA_toks};
#print "\t3 ($tok,$tokVal) \tQSTR\n";
    	    if($tok eq 'QSTR' || $tok eq 'NAME')
	    {
#print "FOUND: '$name' = '$tokVal'\n";
		$subst{$name} = $tokVal;
	    }
	    else
	    {
	    	return undef;
	    }
    	}
	else
	{
	    return undef;
	}
    }
    return \%subst;
}
