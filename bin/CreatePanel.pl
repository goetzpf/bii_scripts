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
#    Options:
#      -title  TitleString | Title.type  Title of the panel (string or file). Default=no title
#      -baseW filename                  base panel name for layout=xy
#      -x pixel      		       X-Position of the panel (default=100)
#      -y pixel      		       Y-Position of the panel (default=100)
#      -w pixel       		       Panel width (default=900)
#      -I searchPath                    Search paht(s) for panel widgets
#      -M                               Create make dependencies
#      -layout xy | grid | table        placement of the widgets, (default = by line) 
#      -type adl|edl                    Create edl or mfp file (default is edl)
#      -sort NAME                       Sort a group of signals. NAME is the name of a 
#                                       Name-Value pair in the substitution data.
#                                       this is done only for the layouts: 'line', 'table'
# 
# Overview
# ========
# 
# This script provides for a way to create more complex edm or dm2k displayes from adl/edl-template widgets and 
# a definition file. The adl/edl-templates are dm2k/edm displays that contain variables for PVs, strings or 
# whatever. The variables are defined in '.substitution' files, same syntax as EPICS substitution files.
# 
# - There are generic adl/edl-templates for analog values, bits and strings.
# - For panesl of list form there may be user defined panels for EPICS .template files.
# 
# For edm panels there is the feature scaling. All widgets may contain the variable WIDTH in one or more edm objects, to scale the
# object and the total width of the edl-template. The '.substitution' file may have the parameter SCALE="pixel", that 
# scales the width of each object of an  edl-template. 
#
# There are several panel layouts available - see below.
#
#
# The substitution files
# ======================
# 
# The substitution files have the same notation as EPICS database substitution files.
# So they may be used for a prototype panels in EPICS database development. 
# For each EPICS template file there has to exist an edl-template display with the same name.
# 
# Notation in .substitution file | Panel Template
# -------------------------------+---------------
# file EPICS_db.template {       | EPICS_db.edl
# file panel.edl {               | panel.edl
# 
  eval 'exec perl -S $0 ${1+"$@"}'  # -*- Mode: perl -*-
	if $running_under_some_shell;

    use strict;
    no strict "refs";
    use Text::ParseWords;
    use parse_subst;
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
    my $usage = "Usage: CreatePanel.pl [options] inFilename outFilename\n
     Options:
      -title  TitleString | Title.type  Title of the panel (string or file). Default=no title
      -baseW filename                  base panel name for layout=xy
      -x pixel      		       X-Position of the panel (default=100)
      -y pixel      		       Y-Position of the panel (default=100)
      -w pixel       		       Panel width (default=900)
      -I searchPath                    Search paht(s) for panel widgets
      -M                               Create make dependencies
      -layout xy | grid | table        placement of the widgets, (default = by line) 
      -type adl|edl                    Create edl or mfp file (default is edl)
      -sort NAME                       Sort a group of signals. NAME is the name of a 
                                       Name-Value pair in the substitution data.
				       this is ignored unless for layouts: 'line', 'table'
     ";
    my %dependencies;
    die unless GetOptions("M","I=s"=>\@searchDlPath,"v","x=i","w=i"=>\$panelWidth,"y=i",
    	    	    	  "type=s"=>\$type,"title=s"=>\$title,"layout=s"=>\$layout, 
			  "sort=s"=>\$opt_sort,"baseW=s"=>\$baseW);

    die $usage unless scalar(@ARGV) > 1;
    die "Illegal Panel type: '$type'" unless ( ($type eq 'edl') || ($type eq 'adl') );
    
    my( $inFileName, $outFileName) = @ARGV;
    $panelWidth = 900 unless( $panelWidth > 0);

    print "Create Panel in: $inFileName out: $outFileName, width = $panelWidth \n" if $opt_v == 1;
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
    	

    my( $file, $r_substData);
    open(IN_FILE, "<$inFileName") or die "can't open input file: $inFileName";
    { local $/;
      undef $/; # ignoriere /n in der Datei als Trenner
      $file = <IN_FILE>;
    }  
    close IN_FILE;
    die "Empty file: '$inFileName'" unless length($file) > 0;

    $file = $title.$file if( defined $title);

    $r_substData = parse_subst::parse($file,'templateList');
    

#parse_subst::dump($r_substData);
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
    else
    {
        ($printEdl,$panelWidth, $panelHeight) = layoutLine($r_substData,$panelWidth);
    }
    

    print "\nDisplay: width=$panelWidth, height=$panelHeight\n" if $opt_v == 1;
    open(FILE, ">$outFileName") or die "  can't open output file: $outFileName";
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
    close FILE;

## Layout of the created display
#  =============================
#
#  The commandline option '-layout' determines which way the edl templates are placed in the Display
#
#  Create by line (Default)
#  ........................
#
#  - The total width of the panel is set by the argument '-width', or set to 900 by default.
#    The Widgets are placed from the left to the right as written in a line as long as the display width
#    is not exceeded. Then a new line begins.
#  - A new edl-template type results in the begin of a new line.
#  - The option '-sort NAME' is available
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

##  Create by table
#  ........................
#
#  - The total width of the panel is set by the argument '-width', or set to 900 by default.
#  The Widgets are placed in rows an collumns. 
#  - The option '-sort NAME' is available
#  - A new edl-template type results in the begin of a new table.
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

#    $yPos += $yDispSize if $xPos > 0;
    return ($prEdl,$displayWidth, $yPos);
}    

## Place each widget to a fixed position
#  ........................
#
#  The option '-layout xy'  will place each item of the '.substitutions' file to the position defined by
#  the parameter 'PANEL_POS'. This parameter defines the x/y position in pixel and has to be set for each 
#  edl-tempolate instance.
#
#  As base widget to print the edl-templates in there has to exist a edl file with the same name as the 
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

## Place each widget to a table by grid parameters
#  ........................
#
#  The option '-layout GRID'  will place each item of the '.substitutions' file to the position defined by
#  the parameter 'GRID="COL,ROW"'. This parameter defines the column and row and has to be set for each edl-template
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

## The edl templates are searched in this order:
# 
# - local: './'
# - one up: '../'
# - as comes from the GenericTemplateApp: '$(TOP)/share'
# - as installed: '$(TOP)/dl'
#
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
# *  Attention  : variables are not substituted for .adl files, but given as macro substitutions 
#    to the widget instance in the '.mfp' file.
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

## Special processing of the PV variable
#  =====================================
# 
# Don't ask why, but it is useful! What happens: A PV substitution may be truncated if 
# it contains a a field.
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

##  Scaling the widgets
#   ====================
#
# There are the values 'SCALE="width"' and 'WIDTH="width"' in the substitution file that control the width of a widget.
#
# If the parameter 'WIDTH' is defined the whole widget width is set to 'WIDTH'. All variables '$(WIDTH)' in the 
# edl-template are substituted to a calculated width: 'w=WIDTH-x' to take care of the x-position of the object. 
#
# If the parameter 'SCALE' is defined it means the whole edl-template is scaled from its original width 
# to the size of the parameter 'SCALE'. The 'x' and 'w' values and the x values of all points of each object are scaled.
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
sub cmpFunc 
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
    if( $widgetFileName =~ /^(.*)\.template/ )
    {
    	$widgetFileName=$1.".adl";
	$adlFile = 0;
    }
    
# .template files has to have at least a NAME substitution. All other substitutions but 
# NAME and SNAME are ignored they are supposed to be database substitutions
    if( $adlFile==0 && $$rH_Attr{NAME} )	
    {   #print "$widgetFileName, $adlFile: $$rH_Attr{NAME}\n";
	$facePlate.="faceplateAdl=$widgetFileName";
	if( length( $$rH_Attr{NAME} ))
	{   $facePlate.="\nfaceplateMacro=NAME=$$rH_Attr{NAME}"
	}
	if( length( $$rH_Attr{SNAME}) )
	{   $facePlate.=",SNAME=$$rH_Attr{SNAME}";
	}
    }

# for .adl files all substitutions are expanded
    elsif( $adlFile==1 )
    { 	#print "$widgetFileName, $adlFile: ",join(',',keys(%$rH_Attr)),"\n";
    	$facePlate.="faceplateAdl=$widgetFileName";
        if( scalar( keys(%$rH_Attr) ) )
	{   my $str = join(',', map{"$_=$rH_Attr->{$_}"} keys(%$rH_Attr));
	    $facePlate.="\nfaceplateMacro=$str";
	}
  }
  $facePlate.="\n";
  return $facePlate;
}