#!/usr/bin/python3
# -*- coding: utf-8 -*-

# Copyright 2021 Helmholtz-Zentrum Berlin für Materialien und Energie GmbH
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


from optparse import OptionParser
import sys
import re
import os
import copy
import xml.etree.ElementTree as ET
import xml.dom.minidom 
from bii_scripts3 import parse_subst
# version of the program:
__version__= "0.10" #VERSION#

def splitQuotedParam(fieldPar,delim=';'):
    parse = []
    beg = 0     # begin of a field
    end = 0     # end of a field - by unquoted delimiter
    nextStr = ""
    while end >= 0:
        
        end = fieldPar.find(delim,beg)
        if end < 0:
            nextStr = nextStr + fieldPar[beg:]
            parse.append(nextStr)
        else:
            if fieldPar[end-1] == "\\":
                nextStr = nextStr + fieldPar[beg:end-1] + delim
            else:
                nextStr = nextStr + fieldPar[beg:end]
                parse.append(nextStr)
                nextStr = ""
        beg = end+1
    return parse

def parseParam(fieldPar,delim='|'):
    """
    Parse parameter string:

    * just one word or something without delimiter '|'

        >>> x = "eins"
        >>> print epicsUtils.parseParam(x)
        eins
        >>> x = "eins,zwei"
        >>> print epicsUtils.parseParam(x)
        eins,zwei

    * a string of names seperated by '|' delimiter: Return it as list

        >>> x = "eins|zwei"
        >>> print epicsUtils.parseParam(x)
        ['eins', 'zwei']

    * name value pairs: returned as dictionary

        >>> x = "eins=1|zwei=2"
        >>> print epicsUtils.parseParam(x)
        {'eins': '1', 'zwei': '2'}
        
    * raise ValueError for inconsistent data
    """
    commFields = {}
    valList = splitQuotedParam(fieldPar,delim) # split parameters
    if len(valList) == 0 or valList[0] == '':
        return {}
    first = valList[0]
    n = first.find('=')
    if n == -1:
        if len(valList) == 1:   # is just a value
            return first
        else:
            return valList      # is a list
    else:
        commFields[first[:n]] = first[(n+1):]
    
    # is a dictionary
    if len(valList) == 0:
        return commFields
    for v in valList[1:]:
        n = v.find('=')
        if n == -1:
            raise ValueError("Inconsistent dictionary data in parse parameter: %s"%(fieldPar))
        else:
            commFields[v[:n]] = v[(n+1):]
    return commFields

def printTable(rT,header=None,sortIdx=None) :
    """
    Print formated table

    Parameter:

    - rT,       # The table, a array reference (rows) of an array reference (columns)
    - header,   # (optional) Header, list of strings for each collumn
    - sortIdx   # (optional) Index of the column the table should be sorted to
    """
    lines = header
    formatMax = []          # max item length of a collumn
    rTable = rT
    if (sortIdx is not None) and sortIdx < len(rT[0]):
        rTable = sorted(rT,key=lambda x: x[sortIdx])
    if header is not None:
        formatMax = [len(x) for x in lines]
    #print "header: ",formatMax
    def choose(x):
        if x[0] < x[1]: return x[1]
        else: return x[0]
    def length(x):
        if x is not None:
            return len(str(x))
        else:
            sys.stderr.write( str(x) )
            return 0
    for row in rTable:
        fLen = [length(x) for x in row]
        formatMax = [choose(x) for x in zip(formatMax,fLen)]
    sys.stderr.write( " | ".join(["{0:>{1}}".format(h,l) for (l,h) in zip(formatMax,header)] )+"\n" )
    sys.stderr.write( "-+-".join([x*'-' for x in formatMax] )+"\n" )
    for line in rTable:
        sys.stderr.write( " | ".join(["{0:>{1}}".format(h,l) for (l,h)in zip(formatMax,line)] )+"\n" )

class Dbg:
    def __init__(self,head=None): 
        self.header = head
        self.data   = []
    def print(self): printTable(self.data,self.header)
    def add(self,lineData): self.data.append(lineData)
    def clear(self): self.data = []
regPretty=re.compile("\n\t+\n",re.M)
def prettyXml(uglyxml):
    xx = xml.dom.minidom.parseString(uglyxml)
    xStr = xx.toprettyxml()
    return regPretty.sub("",xStr)

regFileExtension=re.compile(r"(.*)\.(\w+)$")
def getFileExt(fName):
    m = regFileExtension.match(fName)
    if len(m.groups()) != 2:
        raise ValueError("Illegal widget name: '"+widgetname+"'")
    return (m.groups())

def newElemToTree(parent,new,value=None,attrib={}):
    x = ET.SubElement(parent,new,attrib)
    if value != None:
        x.text = value
    return x

def getWidgetFile(fileName,opts):
    (widget,ext) = getFileExt(fileName)
    widgetFileName = ".".join( (widget,opts.type) )
    for path in opts.searchDlPath:
        wdgFile = path+"/"+widgetFileName
        if os.path.isfile(wdgFile) == True:
            return (widget,wdgFile)
    return (None,None)

def createLableStr(text,width,height,x,y,size,style="REGULAR"):
    lable = ("""<widget type="label" version="2.0.0">    
    <name>lable</name>    
    <text>{}</text>    
	<width>{}</width>    
	<height>{}</height>    
	<x>{}</x>    
	<y>{}</y>    
	<font>      
		<font family="Liberation Sans" size="{}" style="REGULAR"></font>    
	</font>    
	<foreground_color>      
		<color blue="0" green="0" name="Black" red="0"></color>    
	</foreground_color>    
	<background_color>      
		<color blue="218" green="218" name="DM2K 2" red="218"></color>    
	</background_color>    
	<transparent>false</transparent>    
	<vertical_alignment>1</vertical_alignment>  
</widget>

    """).format(text,width,height,x,y,size,style)
    return lable
#---------------------------------
# replace <display> of the widget file by <group>:
# - <group> items may be set by its <x>, <y> positions at load time and 
#   the <widget> items within are set relativ to this, so they need no proccessing!
# - <group> item store the substitution parameters in 
#   the <macro> section and they are filled at load time.
class ParsedWidget:
  def __init__(self,**args):
    self.regPvField=re.compile(r"(.*)\.")
    self.w = None
    self.h = None
    if 'xmlStr' in args:
        wdg = ET.XML(args['xmlStr'])
        self.w = wdg.find('width').text
        self.h = wdg.find('height').text
        self.wdg = wdg
        self.name = wdg.find('name').text
        #print("ParsedWidget xmlStr: ",self.name,self.w,self.h)
    elif 'file' in args:
        widgetFileName = args['file']
        opts           = args['options']
        if opts.verbose: print("ParsedWidget FILE:",widgetFileName)
        self.wdg = None
        (widget,wdgFile) = getWidgetFile(widgetFileName,opts)
        #print("ParsedWidget",widget,wdgFile)
        wdgGroup = ET.XML('<widget type="group" version="2.0.0"> <name>{}</name> <x>{}</x> <y>{}</y> <width>1</width> <height>1</height> <style>3</style> <transparent>true</transparent></widget>'.format(widget,opts.spaceing,opts.spaceing))
        self.name = widget
        if wdgFile != None:
            parseTree = ET.parse(wdgFile)
            display = parseTree.getroot()
            if display.tag == 'display':
                self.w = display.find('width').text
                self.w = int(self.w) + opts.spaceing
                wdgGroup.find('width').text = str(self.w)
                self.h = display.find('height').text
                self.h = int(self.h) + opts.spaceing
                wdgGroup.find('height').text = str(self.h)
                #print("    "+self.name+":\tSize",str(self.w),str(self.h))
                for wdg in display.findall('widget'):
                    #print("\t",wdg.tag,wdg.get('type'))
                    wdgGroup.append(wdg)
            else:
                raise ValueError("Ilegal widget file: "+wdgFile)
            self.wdg = wdgGroup
#            print("ParsedWidget file: ",self.name,self.w,self.h)
        else:
            sys.stderr.write(("ERROR: Can't find:",wdgFile,os.path.isfile(wdgFile))+"\n")
    else:
        sys.stderr.write("Can't create a ParsedWidget from args: "+str(args)+"\n")

  def __str__(self):
    return self.name+" w:"+str(self.w)+" h:"+str(self.h)

  def parsePV(self,substData):
    """ A PV substitution that contains a field is truncated to the PV name for PV definitions in the 
      widget that contains also fields. For compatibility to CreatePanel.pl
    """
    if len(substData) == 0: return
    if 'PV' not in substData:
        if ('DEVN' in substData) and ('SNAME' in substData):
            substData['PV'] = ("{}:{}").format(substData['DEVN'],substData['SNAME'])
        elif ('NAME' in substData) and ('SNAME' in substData):
            substData['PV'] = ("{}:{}").format(substData['NAME'],substData['SNAME'])
# Truncate field from PV for compatibility with CreatPanel.pl TODO: check if this is neccessary!
    else:
        m =self.regPvField.match(substData['PV'])
        if m != None:
            substData['PV'] = m.groups()[0]
    
    
  def setWidget(self,xPos,yPos,substData):
    wdgStr = ""
    wdgRoot = copy.deepcopy(self.wdg)
    self.parsePV(substData)
    macros = newElemToTree(wdgRoot,'macros')
    for n in substData:
        newElemToTree(macros,n,substData[n])
    x = wdgRoot.find('x')
    y = wdgRoot.find('y')
    x.text = str(xPos + int(x.text))
    y.text = str(yPos + int(y.text))
    return (self.w,self.h,wdgRoot)

def layoutLine(substData,display,yPos,opts):
    """ layoutLine:

    * The Widgets are placed from the left to the right - as written in a line.

    fst Widget1 | scnd Widget1 | 3rd Widget1
    4th Widget1 | 5th  Widget1 
    frst Widget2| 2nd  Widget2 | 3rd Widget2

    * The total width of the panel is set by the argument '-width', or by default.
    * A new line begins if the display width is exceeded or if there is a new 
      edl-template type.
    * The order of widgets may be set ba the option '-sort NAME'. NAME is any name 
      of a variable in the '.substitutions' file
    """
    if opts.verbose: print("layout: Line at y:",yPos)
    panelWidth = opts.width;
    dWidth = display.find('width')
    dWidth.text = str(panelWidth)
    xPos=0
    yLast = yPos          # after finish a group next group needs to know this
    dbg = Dbg( ("type","x","y","substitutions") )

    for group in substData: # the .template files
        (wName,wExt) = getFileExt(group[0])
        if opts.verbose:print("Group:",wName,"at x:",xPos," y:",yPos)
        items = group[1:len(group)]
        if opts.sort != None: items = sorted(items,key=lambda x: x[opts.sort])

        try:        
            wdgItem = opts.widgetStore[wName]
            for item in items:
                dbg.add( (wdgItem.name,str(xPos),str(yPos),str(item)) )
                (wdgWidth,wdgHeight,wdg) = wdgItem.setWidget(xPos,yPos,item)
                #print(prettyXml(ET.tostring(wdg,encoding='utf-8')))
                display.append(wdg)

                if (xPos + 2*wdgWidth) > opts.width:
                    xPos = 0
                    yPos = yPos + wdgHeight
                else:
                    xPos = xPos + wdgWidth
        except ValueError as err:
            sys.stderr.write("Warning: skip: "+err+"\n")
            continue
        if xPos > 0:
            yPos += wdgHeight
            xPos =0
    dHeight = display.find('height')
    dHeight.text = str(yPos+wdgHeight)

    if opts.verbose:
        dbg.print()
        print("Display width:",dWidth.text," height:",dHeight.text)
    panelStr = prettyXml(ET.tostring(display,encoding='utf-8'))
    return panelStr

def layoutRawLine(substData,display,yPos,opts):
    """ layoutRawLine: 
    * The Widgets are placed from the left to the right - as written in a line
    * The total width of the panel is set by the argument '-width', or default.
    * A new line begins if the nex widget would exceed the display width, 
      no grouping by the widget type
    * The order of widgets may be set ba the option '-sort NAME'. NAME is any 
      name of a variable in the '.substitutions' file
    """
    if opts.verbose: print("layout: LineRaw at y:",yPos)
    panelWidth = opts.width;
    dWidth = display.find('width')
    dWidth.text = str(panelWidth)
    xPos=0
    yLast = yPos          # after finish a group next group needs to know this
    wdgMaxHeight = 0
    dbg = Dbg( ("type","x","y","substitutions") )

    for group in substData: # the .template files
        (wName,wExt) = getFileExt(group[0])
        if opts.verbose: print("Group:",wName,"at x:",xPos," y:",yPos)
        items = group[1:len(group)]
        if opts.sort != None: items = sorted(items,key=lambda x: x[opts.sort])

        try:        
            wdgItem = opts.widgetStore[wName]
            if wdgItem.h > wdgMaxHeight:
                wdgMaxHeight = wdgItem.h
            
            for item in items:
                if (xPos + 2*wdgItem.w) > opts.width:
                    xPos = 0
                    yPos = yPos + wdgMaxHeight
                dbg.add( (wdgItem.name,str(xPos),str(yPos),str(item)) )
                (wdgWidth,wdgHeight,wdg) = wdgItem.setWidget(xPos,yPos,item)
                #print(prettyXml(ET.tostring(wdg,encoding='utf-8')))
                display.append(wdg)
                xPos = xPos + wdgWidth

        except ValueError as err:
            sys.stderr.write("Warning: skip: "+err+"\n")
            continue
    dHeight = display.find('height')
    dHeight.text = str(yPos+wdgHeight)
    if opts.verbose: 
        dbg.print()
        print("Display width:",dWidth.text," height:",dHeight.text)
    panelStr = prettyXml(ET.tostring(display,encoding='utf-8'))
    return panelStr

def layoutColumn(substData,display,yPos,opts):
    """ layoutLine:
    * The Widgets are placed in collumns. Each file.xx {} block in the substitutions
      file defines one collumn
    * The total width of the panel is given by the sum all widgets in a row, option
      width is ignored
    * There order of widgets in a collumn is as read from the substitution file or
      determined by -sort option one below the other.
    """
    if opts.verbose: print("layout: collumn at y:",yPos)
    panelWidth = opts.width;
    dWidth = display.find('width')
    dWidth.text = str(panelWidth)
    xPos = 0
    y0   = yPos          # after finish a group next group needs to know this
    yMax = yPos
    dbg  = Dbg( ("type","x","y","substitutions") )

    for group in substData: # the .template files
        (wName,wExt) = getFileExt(group[0])
        if opts.verbose: print("Group:",wName,"at x:",xPos," y:",yPos)
        items = group[1:len(group)]
        if opts.sort != None: items = sorted(items,key=lambda x: x[opts.sort])

        try:        
            wdgItem = opts.widgetStore[wName]
            yPos = y0
            for item in items:
                dbg.add( (wdgItem.name,str(xPos),str(yPos),str(item)) )
                (wdgWidth,wdgHeight,wdg) = wdgItem.setWidget(xPos,yPos,item)
                #print(prettyXml(ET.tostring(wdg,encoding='utf-8')))
                display.append(wdg)
                yPos += wdgHeight
            xPos += wdgItem.w
            if yPos > yMax: yMax = yPos
            
        except ValueError as err:
            sys.stderr.write("Warning: skip: "+err+"\n")
            continue

    dHeight = display.find('height')
    dHeight.text = str(yMax)
    if opts.verbose:
        dbg.print()
        print("Display width:",dWidth.text," height:",dHeight.text)
    panelStr = prettyXml(ET.tostring(display,encoding='utf-8'))
    return panelStr

def layoutTable(substData,display,yPos,opts):
    """ layoutTable:

    Widget1 | Widget4 | Widget7 
    Widget2 | Widget5 | Widget8 
    Widget3 | Widget6 | Widget9 

    * The widgets of a group are placed in columns top down and rows right to left. 
    * The total width of the panel is set by the argument '-width', or by default.
    * A new table begins if there is a new  edl-template type.
    * The order of widgets may be set ba the option '-sort NAME'. NAME is any name
      of a variable in the '.substitutions' file
    """
    if opts.verbose: print("layout: table at y:",yPos)
    panelWidth = opts.width;
    dWidth = display.find('width')
    dWidth.text = str(panelWidth)
    xPos = 0
    y0   = yPos          # after finish a group next group needs to know this
    yMax = yPos
    dbg  = Dbg( ("type","x","y","substitutions") )

    for group in substData: # the .template files
        (wName,wExt) = getFileExt(group[0])
        if opts.verbose: print("Group:",wName,"at x:",xPos," y:",yPos)
        items = group[1:len(group)]
        if opts.sort != None: items = sorted(items,key=lambda x: x[opts.sort])

        try:        
            wdgItem = opts.widgetStore[wName]
            cols = int(panelWidth/wdgItem.w)
            rows = len(group) / cols
            if rows - int(rows) != 0: rows = int(rows) + 1

            yPos = y0
            idx = 0
            for item in items:
                xPos = int(idx/rows) * wdgItem.w 
                yPos = (idx%rows * wdgItem.h) + y0
                dbg.add(( ("{}:w={} h={}".format(wdgItem.name,wdgItem.w,wdgItem.h)) ,str(xPos),str(yPos),str(item)) )
                (wdgWidth,wdgHeight,wdg) = wdgItem.setWidget(xPos,yPos,item)
                #print(prettyXml(ET.tostring(wdg,encoding='utf-8')))
                display.append(wdg)
                idx += 1
            
        except ValueError as err:
            sys.stderr.write("Warning: skip: "+err+"\n")
            continue
        yPos += rows * wdgItem.h
    dHeight = display.find('height')
    dHeight.text = str( (rows*wdgItem.h)+y0 )
    if opts.verbose:
        dbg.print()
        print("Display width:",dWidth.text," height:",dHeight.text)
    panelStr = prettyXml(ET.tostring(display,encoding='utf-8'))
    return panelStr

def layoutXY(substData,display,yPos,opts):
    """ layoutXY:

     -------------------------
    |   Widget1               |    
    |                Widget3  |    
    |                         |    
    |    Widget2  Widget2     |    
     -------------------------

    * The widgets placed on pixel coordinates in parameter PANEL_POS="x,y"
    * The Title display file is the background where to place the widgets, means
      the title determins width and height of the panel.
    * Without title display, width and hight are calculated to fit for all widgets
    """
    if opts.verbose: print("layout: xy")

    xPos = 0
    yPos = 0          # ignore title height parameter, as title is the background file!
    yMax = 0
    xMax = 0
    dbg  = Dbg( ("type","x","y","substitutions") )

    for group in substData: # the .template files
        (wName,wExt) = getFileExt(group[0])
        if opts.verbose: print("Group:",wName,"at x:",xPos," y:",yPos)
        items = group[1:len(group)]
        try:        
            wdgItem = opts.widgetStore[wName]
            #print("\t","Cols:",cols," Rows:",rows)

            for item in items:
                try:
                    (xPos,yPos) = item['PANEL_POS'].split(',')
                    xPos = int(xPos)
                    yPos = int(yPos)
                    del(item['PANEL_POS'])      # unuseful in widget substitutions
                except KeyError:
                     sys.stderr.write("ERROR: Can't find PANEL_POS in: "+str(item)+"\n");
                dbg.add(( ("{}:w={} h={}".format(wdgItem.name,wdgItem.w,wdgItem.h)) ,str(xPos),str(yPos),str(item)) )
                (wdgWidth,wdgHeight,wdg) = wdgItem.setWidget(xPos,yPos,item)
                display.append(wdg)
                if xPos+wdgWidth > xMax: xMax = xPos+wdgWidth
                if yPos+wdgHeight> yMax: yMax = xPos+wdgHeight
            
        except ValueError as err:
            sys.stderr.write("Warning: skip: "+err+"\n")
            continue

    dWidth = display.find('width')
    dHeight = display.find('height')
    if opts.backGroundDisplay == None:
        dHeight.text = str(yMax)
        dWidth.text  = str(xMax)
    else:
        if int(dWidth.text) < xMax:
            sys.stderr.write("Warning: Display width {} smaler than calculated, set to {}".format(dWidth.text,str(xMax))+"\n" );
            dWidth.text = str(xMax)
        if int(dHeight.text) < yMax:
            sys.stderr.write("Warning: Display height {} smaler than calculated, set to {}".format(dHeight.text,str(yMax))+"\n" );
            dHeight.text = str(yMax)
    
    if opts.verbose: 
        dbg.print()
        print("Display width:",dWidth.text," height:",dHeight.text)
    panelStr = prettyXml(ET.tostring(display,encoding='utf-8'))
    return panelStr

def layoutGrid(substData,display,y0,opts):
    class PanelItem:
        def __init__(self,widget,yGrid,xGrid,xScale,span,wdgWidth,wdgHeight,subst):
            self.widget    = widget   
            self.yGrid     = yGrid    
            self.xGrid     = int(xGrid)
            self.xScale    = xScale   
            self.span      = span
            self.wdgWidth  = wdgWidth 
            self.wdgHeight = wdgHeight
            self.subst     = subst    
    dbg  = Dbg( ("type","x","y","substitutions") )
    itemList     = []
    for group in substData: # the .template files
        (wName,wExt) = getFileExt(group[0])
        items = group[1:len(group)]
        try:        
            wdgItem = opts.widgetStore[wName]

            for item in items:
                try:
                    (xPos,yPos) = item['GRID'].split(',')
                    xPos = int(xPos)
                    yPos = int(yPos)
                    del(item['GRID'])      # unuseful in widget substitutions
                except KeyError:
                     sys.stderr.write("ERROR: Can't find GRID in: "+str(item)+"\n");
                span = None
                if 'SPAN' in item:
                    span = int(item['SPAN'])
                    del(item['SPAN'])
                xScale = None
                if 'SCALE' in item:
                    xScale = item['SCALE']
                    del(item['SCALE'])
                itemList.append( PanelItem(wdgItem,yPos,xPos,xScale,span,wdgItem.w,wdgItem.h,item) )
                dbg.add(( ("{}:w={} h={}".format(wdgItem.name,wdgItem.w,wdgItem.h)) ,str(xPos),str(yPos),str(item)) )
        except ValueError as err:
            sys.stderr.write("Warning: skip: "+err+"\n")
            continue

    if len(itemList) == 0: 
        sys.stderr.write("ERROR: No GRID items found skip Display\n")
        return

    if opts.verbose: dbg.print()
    
    xLen = 0    
    yLen = 0    
    for item in itemList:
        if item.xGrid > xLen: xLen = int(item.xGrid)
        if item.yGrid > yLen: yLen = int(item.yGrid)
    xLen += 1
    yLen += 1
    table = []
    colMaxWidth  = [0]*xLen
    rowMaxHeight = [0]*yLen
    spannedRows  = [None]*xLen
    for x in range(0,yLen,1): table.append([None]*xLen)

    for item in itemList:
        if table[item.yGrid][item.xGrid] != None:
            sys.stderr.write("Warning: Multiple definition of GRID=({},{})\n".format(item.xGrid,item.yGrid) )
        table[item.yGrid][item.xGrid] = item
        if item.span != None:
            spannedRows[item.xGrid] = item
        else:
            if colMaxWidth[item.xGrid] < item.wdgWidth: colMaxWidth[item.xGrid] = item.wdgWidth
        
        if rowMaxHeight[item.yGrid] < item.wdgHeight: rowMaxHeight[item.yGrid] = item.wdgHeight

    for spnItem in reversed(spannedRows):  # calculate in pos direction, so later width has to be allready corected by span
        if spnItem == None:
            continue
        spannedCols = colMaxWidth[spnItem.xGrid:(spnItem.xGrid+spnItem.span-1)];
        spannedWidth = 0
        for w in spannedCols:   # total width of the spanned collumns ..
            if w != None: spannedWidth += w
        if spannedWidth < item.wdgWidth:  # .. if the spanned widget exceeds this ..
            colMaxWidth[spnItem.xGrid] += spnItem.wdgWidth - spannedWidth # .. add to the first collumn

    displayWidth=0
    for x in colMaxWidth: displayWidth += x
    displayHeight=0
    for x in rowMaxHeight: displayHeight += x
    spanedWidth = 0

    # show table
    if opts.verbose:
        h = [ str(x) for x in range(0, yLen)]
        tblDbg = Dbg(h)
        tblDbg.add(colMaxWidth)
        for row in table:
            R=[]
            for c in row:
                if c != None:
                    R.append("{}:{},{}".format(c.widget.name,c.xGrid,c.yGrid))
                else:
                    R.append("None")
            tblDbg.add(R)
        if opts.verbose:
            tblDbg.print()
            print("rowMaxHeight:",rowMaxHeight,"\nspan:",spanedWidth,"\ndisplayWidth:",displayWidth,"\ndisplayHeight:",displayHeight)
    rowPos = [0]*len(rowMaxHeight)
    rowPos[0] = int(y0)
    for y in range(1,len(rowMaxHeight)):
        rowPos[y] = rowPos[y-1] + rowMaxHeight[y-1]
    colPos = [0]*len(colMaxWidth)
    for x in range(1,len(colMaxWidth)):
        colPos[x] = colPos[x-1] + colMaxWidth[x-1]
    if opts.verbose:
        print("rowMaxHeight:",rowMaxHeight,"\ncolMaxWidth:",colMaxWidth,"\ndisplayWidth:",displayWidth,"\ndisplayHeight:",displayHeight)
    dbg.clear()
    for (y,row) in zip(range(0,len(table)),table):
        for (x,item) in zip(range(0,len(row)),row):
            if item == None:
                continue
            parsedWdg = item.widget
            xPos = colPos[x]
            yPos = rowPos[y]
            (wdgWidth,wdgHeight,wdg) = parsedWdg.setWidget(xPos,yPos,item.subst)
            dbg.add(( ("{}:w={} h={}".format(parsedWdg.name,parsedWdg.w,parsedWdg.h)) ,str(xPos),str(yPos),str(parsedWdg)) )
            display.append(wdg)
    if opts.verbose:
        print("The grid table:\n****************" )
        dbg.print()
    panelStr = prettyXml(ET.tostring(display,encoding='utf-8'))
    return panelStr
        
        
def process_file(opts):
    """convert a single file."""
    display = ET.XML("""<?xml version="1.0" encoding="UTF-8"?>
<display version="2.0.0">
  <name>text</name>
  <x>0</x>
  <y>0</y>
  <width>600</width>
  <height>15</height>
  <background_color>
    <color name="EDM canvas" red="200" green="200" blue="200">
    </color>
  </background_color>
  <grid_visible>false</grid_visible>
</display>
""")

    if opts.backGroundDisplay != None:
        (wdgWidth,wdgHeight,wdg) = opts.backGroundDisplay.setWidget(0,0,{})
        display.append(wdg)
        dWidth = display.find('width')
        dWidth.text = wdgWidth
        dHeight = display.find('height')
        dHeight.text = wdgHeight
#-------- get substitutions data
    if opts.inFile != "-":
        f= open(opts.inFile, "r")
    else:
        sys.stderr.write("(expect input from stdin)\n")
        f= sys.stdin
    substFileStr= f.read()
    if opts.inFile != "-":
        f.close()
    
    substData = parse_subst.parse(substFileStr,"list")
    #print("PARSED substData:",substData)

#-------- check for widget dependencies and read them
    dependencies = [x[0] for x in substData]
    if opts.dependencies == True:
        depFiles = []
        for widgetFileName in dependencies:
            (widget,wdgFile) = getWidgetFile(widgetFileName,opts)
            if wdgFile == None:
                sys.stderr.write("-M: dependant file '{}' not found\n".format(widgetFileName))
            else:
                depFiles.append(wdgFile)
        reg=re.compile(r"\.d\s*$")
        target =reg.sub("",opts.outFile)
        with open(opts.outFile,mode="w") as w:
            w.write("{}: {}\n".format(target," ".join(depFiles) ))

        return
    for wdg in dependencies:
        w = ParsedWidget(file=wdg,options=opts)
        if w.name != None:
            opts.widgetStore[w.name] = w

    if opts.verbose: 
        print("\n**** WIDGET Store:",",".join(opts.widgetStore.keys()))
        for wKey in opts.widgetStore:
            wdg = opts.widgetStore[wKey]
            print(wKey,wdg)

#-------- create display by layout
    printData = "Empty Print Data!"    
    yPos      = 0
    if 'title' in opts.widgetStore:
        (wdgWidth,wdgHeight,wdg) = opts.widgetStore['title'].setWidget(0,yPos,{})
        display.append(wdg)
        yPos = int(wdgHeight)

    if opts.layout == 'line':    
        printData = layoutLine(substData,display,yPos,opts)
    elif opts.layout == 'rawline':    
        printData = layoutRawLine(substData,display,yPos,opts)
    elif opts.layout == 'column':
        printData = layoutColumn(substData,display,yPos,opts)
    elif opts.layout == 'table':
        printData = layoutTable(substData,display,yPos,opts)
    elif opts.layout == 'xy':
        printData = layoutXY(substData,display,yPos,opts)
    elif opts.layout == 'grid':
        printData = layoutGrid(substData,display,yPos,opts)
#-------- print display file
    if opts.outFile is not None:
        out= open(opts.outFile, "w")
        output_mode = "a"
    else:
        out= sys.stdout
    #out.write("do(\n")
    out.write(printData)
    #out.write(")\n")
    if opts.outFile is not None:
        out.close()
#--------------------------------------------------
class getOption(object):
  def __init__(self):

    usage = "usage: %prog [options] inFile.substitutions outFile.bob"

    parser = OptionParser(usage=usage,
                          version="%%prog %s" % __version__,
                          description="Convert EPICS substitution file/s to panels\n")
    parser.add_option("--baseW",
                      action="store",
                      type="string",
                      help="Background display file, mandatory for for layout=xy",
                     )
    parser.add_option("--border",
                      action="store",
                      type="string",
                      help="see spaceing. For compatibility to CreatePanel.pl option",
                     )
    parser.add_option("-I",
                      action="append",
                      type="string",
                      help="Search path(s) for panel widgets, Delimiter: ':'",
                     )
    parser.add_option("-i",
                      action="store_true",
                      help="Add ., .., \$EPICS_DISPLAY_PATH' variable to search path(s) for panel widgets",
                     )
    parser.add_option("--layout",
                      action="store",
                      type="string",
                      help=" line|xy|grid|table|collumn|rawline    placement of the widgets,(default: by Line)",
                     )
    parser.add_option("-M",
                      action="store_true",
                      help="Create make dependencies",
                     )
    parser.add_option("--sort",
                      action="store",
                      type="string",
                      help="--sort KEY: Sort a group of signals by its substitutions key. Not for for layouts: 'grid' and 'xy'",
                     )
    parser.add_option("--spaceing",
                      action="store",
                      type="string",
                      help="extra space in pixel between widgets",
                     )
    parser.add_option("--subst",
                      action="store",
                      type="string",
                      help=" 'NAME=\"VALUE\";...' Panel substitutions from commandline, Item delimiter: ';'",
                     )
    parser.add_option("--title",
                      action="store",
                      type="string",
                      help="TitleString | Title.type  Title of the panel (string or file).",
                     )
    parser.add_option("--type",
                      action="store",
                      type="string",
                      help="Output type: bob, (adl, edm not supported yet)- Default is bob",
                     )
    parser.add_option("-v", "--verbose",
                      action="store_true",
                      help="verbose",
                     )
    parser.add_option("-w",
                      action="store",
                      type="string",
                      help="Panel width (default=900)",
                     )
#    parser.add_option("-x",
#                      action="store",
#                      type="string",
#                      help="(pixel) X-Position of the panel (default=100)",
#                     )
#    parser.add_option("-y",
#                      action="store",
#                      type="string",
#                      help="(pixel) Y-Position of the panel (default=100)",
#                     )
    (options, args) = parser.parse_args()
    self.inFile = None
    self.outFile = None
    try:
        (self.inFile, self.outFile) = args
    except ValueError:
        sys.stderr.write("ERROR: missing argument for in-, out-file:"+str(args))
        sys.exit(1)
    self.verbose = False
    if options.verbose: 
        print("READ: ",self.inFile,"WRITE:",self.outFile)
        self.verbose = True

    self.type = "bob"    
    if options.type:
        if options.type not in ['bob']: # Currently only bob supported! ['bob','adl','edl']:
            sys.stderr.write("ERROR: not supported --type option: "+options.type)
            sys.exit(1)
        self.type = options.type
    if self.verbose: print("TYPE:\t",self.type)

    self.width = 900
    if options.w:
        try:
            self.width = int(options.w)
        except ValueError:
            sys.stderr.write("ERROR: illegal --width option: "+options.w)
            sys.exit(1)
    if self.verbose: print("WIDTH:\t",self.width)

    self.layout = "line"
    if options.layout:
        if options.layout not in ['line','xy','grid','table','column','rawline']:
            sys.stderr.write("ERROR: illegal --layout option: "+options.layout)
            sys.exit(1)
        self.layout= options.layout
    if self.verbose: print("LAYOUT:\t",self.layout)

    self.substitutions = None    
    if options.subst:
        self.substitutions = parseParam(options.subst,';')
        if self.verbose: print("SUBST:\t",self.substitutions)

    self.dependencies = None    
    if options.M:
        self.dependencies = True

    self.sort = None
    if options.sort:
        self.sort = options.sort
    self.searchDlPath = []
    path_i = []        
    path_I = []        
    if options.I:
        if type(options.I) == list:
            for o in options.I:
                path_I.extend(o.split(':'))
        else:
            path_I = options.I.split(':')
    if options.i:
        try:
            path_i = os.environ['EPICS_DISPLAY_PATH'].split(':')
        except KeyError:
            path_i = []        
    self.searchDlPath = [*path_I, *path_i]
    if self.verbose: print("WIDGETPATH:\t",self.searchDlPath)

    self.widgetStore = {} # buffer allready parsed widgets 
    self.backGroundDisplay = None
    if options.baseW:
        try:            # check if its a file name of form: name.extension
            (file,ext) = getFileExt(options.baseW)
            if ext != self.type:
                sys.stderr.write("ERROR: option mismatch panel type and title extension "+options.baseW)
                sys.exit(1)
            self.backGroundDisplay = ParsedWidget(file=options.baseW,options=self)
        except AttributeError:
            sys.stderr.write("ERROR: illegal --baseW option: "+options.baseW+"\n")

    self.spaceing = 0
    self.titleWdg = None
    if options.title:
        titleFile = options.title
        try:            # check if its a file name of form: name.extension
            (file,ext) = getFileExt(titleFile)
            if ext != self.type:
                sys.stderr.write("ERROR: option mismatch panel type and title extension "+options.title)
                sys.exit(1)
            titleWdg = ParsedWidget(file=titleFile,options=self)
        except AttributeError:
            titleWdg = ParsedWidget(xmlStr=createLableStr(options.title,self.width,30,0,0,25))

        except:           # title string, put to text wiget
            sys.stderr.write("ERROR: illegal --title option: "+options.title+"\n")
        self.widgetStore["title"] = titleWdg

    # set spaceing after setting the title!
    if options.border:
        self.spaceing = int(options.border)
    if options.spaceing:
        self.spaceing = int(options.spaceing)

def main():
    opts = getOption()
    process_file(opts)

if __name__ == "__main__":
    main()            

