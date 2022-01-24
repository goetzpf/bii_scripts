#!/usr/bin/python3
# -*- coding: utf-8 -*-

# Copyright 2022 Helmholtz-Zentrum Berlin für Materialien und Energie GmbH
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


from argparse import ArgumentParser
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

def getWidgetFile(fileName,opts):
    (widget,ext) = getFileExt(fileName)
    widgetFileName = ".".join( (widget,opts['type']) )
    for path in opts['searchDlPath']:
        wdgFile = path+"/"+widgetFileName
        if os.path.isfile(wdgFile) == True:
            return (widget,wdgFile)
    sys.stderr.write(("ERROR: Can't find widget:{} for file:{}\n".format(widgetFileName,fileName)))
    return (None,None)

def newElemToTree(parent,new,value=None,attrib={}):
    x = ET.SubElement(parent,new,attrib)
    if value != None:
        x.text = value
    return x

# Parsed from colors.list by:
#  perl -ne 'printf("        \"%s\":{\"red\":%d,\"green\":%d,\"blue\":%d}\n",$1,$2/256,$3/256,$4/256) if($_=~/static.*\"(.*?)\"\s+\{\s+(\d+)\s(\d+)\s(\d+)/); '  ../../support/APPS/GENERICTEMPLATE/csv2EpicsDbApp/colors.list|sort
def getColor(color):
    try:    # number means dm2k color number
        n=int(color)
    except ValueError:
        pass
    else:
        if n<65: color = "DM2K{}".format(str(n))
        else: return None

    colors= {
        "beige-1":{"red":95,"green":95,"blue":82},
        "beige-2":{"red":118,"green":118,"blue":101},
        "beige-3":{"red":141,"green":141,"blue":121},
        "beige-4":{"red":164,"green":164,"blue":141},
        "beige-5":{"red":186,"green":186,"blue":160},
        "beige-6":{"red":209,"green":209,"blue":180},
        "beige-7":{"red":232,"green":232,"blue":200},
        "beige-8":{"red":255,"green":255,"blue":219},
        "BGReadback":{"red":235,"green":241,"blue":181},
        "black":{"red":0,"green":0,"blue":0},
        "blinkRed":{"red":128,"green":75,"blue":84},
        "blink White":{"red":255,"green":255,"blue":255},
        "blue-1":{"red":0,"green":0,"blue":95},
        "blue-2":{"red":0,"green":0,"blue":148},
        "blue-3":{"red":0,"green":0,"blue":202},
        "blue":{"red":0,"green":0,"blue":255},
        "broen-3":{"red":122,"green":109,"blue":84},
        "brown-1":{"red":244,"green":218,"blue":168},
        "brown-2":{"red":183,"green":164,"blue":126},
        "cyan-1":{"red":0,"green":95,"blue":95},
        "cyan-2":{"red":0,"green":148,"blue":148},
        "cyan-3":{"red":0,"green":202,"blue":202},
        "cyan":{"red":0,"green":255,"blue":255},
        "Cyan":{"red":0,"green":255,"blue":255},
        "Disconn/Invalid":{"red":255,"green":255,"blue":255},
        "DM2K10":{"red":105,"green":105,"blue":105},
        "DM2K11":{"red":90,"green":90,"blue":90},
        "DM2K12":{"red":70,"green":70,"blue":70},
        "DM2K13":{"red":45,"green":45,"blue":45},
        "DM2K1":{"red":236,"green":236,"blue":236},
        "DM2K25":{"red":88,"green":147,"blue":255},
        "DM2K26":{"red":89,"green":126,"blue":225},
        "DM2K27":{"red":75,"green":110,"blue":199},
        "DM2K28":{"red":58,"green":94,"blue":171},
        "DM2K2":{"red":218,"green":218,"blue":218},
        "DM2K30":{"red":251,"green":243,"blue":74},
        "DM2K31":{"red":249,"green":218,"blue":60},
        "DM2K32":{"red":238,"green":182,"blue":43},
        "DM2K35":{"red":255,"green":176,"blue":255},
        "DM2K37":{"red":174,"green":78,"blue":188},
        "DM2K3":{"red":200,"green":200,"blue":200},
        "DM2K40":{"red":164,"green":170,"blue":255},
        "DM2K41":{"red":135,"green":147,"blue":226},
        "DM2K42":{"red":106,"green":115,"blue":193},
        "DM2K43":{"red":77,"green":82,"blue":164},
        "DM2K44":{"red":52,"green":51,"blue":134},
        "DM2K45":{"red":199,"green":187,"blue":109},
        "DM2K46":{"red":183,"green":157,"blue":92},
        "DM2K47":{"red":164,"green":126,"blue":60},
        "DM2K48":{"red":125,"green":86,"blue":39},
        "DM2K50":{"red":153,"green":255,"blue":255},
        "DM2K51":{"red":115,"green":223,"blue":255},
        "DM2K52":{"red":78,"green":165,"blue":249},
        "DM2K53":{"red":42,"green":99,"blue":228},
        "DM2K56":{"red":212,"green":219,"blue":157},
        "DM2K57":{"red":187,"green":193,"blue":135},
        "DM2K58":{"red":166,"green":164,"blue":98},
        "DM2K59":{"red":139,"green":130,"blue":57},
        "DM2K5":{"red":174,"green":174,"blue":174},
        "DM2K60":{"red":115,"green":255,"blue":107},
        "DM2K61":{"red":82,"green":218,"blue":59},
        "DM2K6":{"red":158,"green":158,"blue":158},
        "DM2K7":{"red":145,"green":145,"blue":145},
        "DM2K8":{"red":133,"green":133,"blue":133},
        "DM2K9":{"red":120,"green":120,"blue":120},
        "dullred":{"red":192,"green":113,"blue":126},
        "EDMcanvas":{"red":200,"green":200,"blue":200},
        "EDMhelp":{"red":120,"green":120,"blue":120},
        "EDMtitle":{"red":158,"green":158,"blue":158},
        "GlobalCanvas":{"red":187,"green":187,"blue":187},
        "gray-10":{"red":190,"green":190,"blue":190},
        "gray-11":{"red":203,"green":203,"blue":203},
        "gray-12":{"red":216,"green":216,"blue":216},
        "gray-13":{"red":229,"green":229,"blue":229},
        "gray-14":{"red":242,"green":242,"blue":242},
        "gray-1":{"red":74,"green":74,"blue":74},
        "gray-2":{"red":87,"green":87,"blue":87},
        "gray-3":{"red":100,"green":100,"blue":100},
        "gray-4":{"red":113,"green":113,"blue":113},
        "gray-5":{"red":126,"green":126,"blue":126},
        "gray-6":{"red":139,"green":139,"blue":139},
        "gray-7":{"red":152,"green":152,"blue":152},
        "gray-8":{"red":165,"green":165,"blue":165},
        "gray-9":{"red":177,"green":177,"blue":177},
        "graygreen-20":{"red":206,"green":220,"blue":205},
        "graygreen-30":{"red":185,"green":198,"blue":184},
        "green-1":{"red":0,"green":95,"blue":0},
        "green-20":{"red":225,"green":248,"blue":177},
        "green-21":{"red":202,"green":223,"blue":159},
        "green-2":{"red":0,"green":118,"blue":0},
        "green-3":{"red":0,"green":141,"blue":0},
        "green-4":{"red":0,"green":164,"blue":0},
        "green-5":{"red":0,"green":186,"blue":0},
        "green-6":{"red":0,"green":209,"blue":0},
        "green-7":{"red":0,"green":232,"blue":0},
        "greengray-40":{"red":166,"green":178,"blue":165},
        "green":{"red":0,"green":255,"blue":0},
        "grey-10":{"red":105,"green":105,"blue":105},
        "grey-11":{"red":90,"green":90,"blue":90},
        "grey-12":{"red":70,"green":70,"blue":70},
        "grey-13":{"red":45,"green":45,"blue":45},
        "grey-1":{"red":236,"green":236,"blue":236},
        "grey-2":{"red":218,"green":218,"blue":218},
        "grey-4":{"red":187,"green":187,"blue":187},
        "grey-5":{"red":174,"green":174,"blue":174},
        "grey-7":{"red":145,"green":145,"blue":145},
        "grey-8":{"red":133,"green":133,"blue":133},
        "lilac-1":{"red":82,"green":82,"blue":95},
        "lilac-2":{"red":101,"green":101,"blue":118},
        "lilac-3":{"red":121,"green":121,"blue":141},
        "lilac-4":{"red":141,"green":141,"blue":164},
        "lilac-5":{"red":160,"green":160,"blue":186},
        "lilac-6":{"red":180,"green":180,"blue":209},
        "lilac-7":{"red":200,"green":200,"blue":232},
        "lilac-8":{"red":219,"green":219,"blue":255},
        "mint-1":{"red":181,"green":249,"blue":215},
        "mint-2":{"red":162,"green":224,"blue":193},
        "misc-109":{"red":205,"green":202,"blue":221},
        "misc-110":{"red":184,"green":181,"blue":198},
        "misc-111":{"red":165,"green":162,"blue":178},
        "misc-112":{"red":222,"green":196,"blue":251},
        "misc-113":{"red":199,"green":175,"blue":225},
        "misc-114":{"red":221,"green":202,"blue":221},
        "misc-115":{"red":198,"green":181,"blue":198},
        "misc-116":{"red":178,"green":162,"blue":178},
        "misc-117":{"red":251,"green":235,"blue":236},
        "misc-118":{"red":225,"green":176,"blue":212},
        "misc-119":{"red":255,"green":150,"blue":168},
        "pastel-1":{"red":82,"green":95,"blue":82},
        "pastel-2":{"red":101,"green":118,"blue":101},
        "pastel-3":{"red":121,"green":141,"blue":121},
        "pastel-4":{"red":141,"green":164,"blue":141},
        "pastel-5":{"red":160,"green":186,"blue":160},
        "pastel-6":{"red":180,"green":209,"blue":180},
        "pastel-7":{"red":200,"green":232,"blue":200},
        "pastel-8":{"red":219,"green":255,"blue":219},
        "purple-1":{"red":95,"green":0,"blue":95},
        "purple-2":{"red":148,"green":0,"blue":148},
        "purple-3":{"red":202,"green":0,"blue":202},
        "purple":{"red":255,"green":0,"blue":255},
        "red-1":{"red":95,"green":0,"blue":0},
        "red-2":{"red":118,"green":0,"blue":0},
        "red-3":{"red":141,"green":0,"blue":0},
        "red-4":{"red":164,"green":0,"blue":0},
        "red-5":{"red":186,"green":0,"blue":0},
        "red-6":{"red":209,"green":0,"blue":0},
        "red-7":{"red":232,"green":0,"blue":0},
        "red":{"red":255,"green":0,"blue":0},
        "Relateddisplay":{"red":128,"green":88,"blue":48},
        "rose-1":{"red":95,"green":82,"blue":82},
        "rose-2":{"red":118,"green":101,"blue":101},
        "rose-3":{"red":141,"green":121,"blue":121},
        "rose-4":{"red":164,"green":141,"blue":141},
        "rose-5":{"red":186,"green":160,"blue":160},
        "rose-6":{"red":209,"green":180,"blue":180},
        "rose-7":{"red":232,"green":200,"blue":200},
        "rose-8":{"red":255,"green":219,"blue":219},
        "Shell/reldsp-alt":{"red":255,"green":176,"blue":96},
        "sky-1":{"red":176,"green":218,"blue":249},
        "sky-2":{"red":158,"green":196,"blue":224},
        "steel-1":{"red":194,"green":218,"blue":217},
        "steel-2":{"red":174,"green":196,"blue":195},
        "steel-3":{"red":156,"green":176,"blue":175},
        "TitleBooster":{"red":39,"green":84,"blue":141},
        "TitleHF":{"red":214,"green":127,"blue":226},
        "white":{"red":255,"green":255,"blue":255},
        "White":{"red":255,"green":255,"blue":255},
        "yellow-1":{"red":95,"green":95,"blue":0},
        "yellow-2":{"red":148,"green":148,"blue":0},
        "yellow-3":{"red":202,"green":202,"blue":0},
        "yellow":{"red":255,"green":255,"blue":0}
    }
    if color in colors:
        return colors[color]
    else:
        return None

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

regPvField=re.compile(r"(.*)\.")
def parsePV(substData):
    """Create the variable PV for widgets that use the $(PV) variables instead
    of $(DEVN):$(SNAME) or the legacy $(NAME):$(SNAME).
    A PV substitution that contains a field is truncated to the PV name for PV
    definitions in the widget that contains also fields.
    """
    if len(substData) == 0: return
    if 'PV' not in substData:
        if ('DEVN' in substData) and ('SNAME' in substData):
            substData['PV'] = ("{}:{}").format(substData['DEVN'],substData['SNAME'])
        elif ('NAME' in substData) and ('SNAME' in substData):
            substData['PV'] = ("{}:{}").format(substData['NAME'],substData['SNAME'])
    # Truncate field from PV for compatibility with CreatPanel.pl TODO: check if this is neccessary!
    else:
        m =regPvField.match(substData['PV'])
        if m != None:
            substData['PV'] = m.groups()[0]

#---------------------------------
# replace <display> of the widget file by <group>:
# - <group> items may be set by its <x>, <y> positions at load time and 
#   the <widget> items within are set relativ to this, so they need no proccessing!
# - <group> item store the substitution parameters in 
#   the <macro> section and they are filled at load time.
class ParsedWidget:
  def __init__(self,**args):
    self.w = None
    self.h = None
    self.wdg = None
    self.wdgStr = None
    if 'options' in args:
        self.opts = args['options']
    else:
        sys.stderr.write("Warning: Missing 'options' in args: "+str(args)+"\n")
    
    if 'xmlStr' in args:
        wdg = ET.XML(args['xmlStr'])
        self.w = wdg.find('width').text
        self.h = wdg.find('height').text
        self.wdg = wdg
        self.wdgStr = args['xmlStr']
        self.name = wdg.find('name').text
    elif 'file' in args:
        widgetFileName = args['file']
        (widget,wdgFile) = getWidgetFile(widgetFileName,self.opts)
        self.name = widget
        if wdgFile != None:
            wdgGroup = None
            parseTree = ET.parse(wdgFile)
            display = parseTree.getroot()
            if display.tag == 'display':
                self.w = display.find('width').text
                self.w = int(self.w) + self.opts['spaceing']
                self.h = display.find('height').text
                self.h = int(self.h) + self.opts['spaceing']
                wdgGroup = ET.XML(
                '<widget type="group" version="2.0.0"><name>{}</name><x>{}</x><y>{}</y><width>{}</width><height>{}</height><style>3</style><transparent>true</transparent></widget>'.format(
                    widget,self.opts['spaceing'],self.opts['spaceing'],self.w+self.opts['spaceing'],self.h+self.opts['spaceing']))
                #print("    "+self.name+":\tSize",str(self.w),str(self.h))
                for wdg in display.findall('widget'):
                    #print("\t",wdg.tag,wdg.get('type'))
                    wdgGroup.append(wdg)
            else:
                raise ValueError("Ilegal widget file: "+wdgFile)
            self.wdg = wdgGroup
            self.wdgStr = ET.tostring(wdgGroup)
    else:
        sys.stderr.write("Can't create a ParsedWidget from args: "+str(args)+"\n")

  def __str__(self):
    return self.name+" w:"+str(self.w)+" h:"+str(self.h)

  def setWidget(self,xPos,yPos,substData):
    if self.opts['substitutions']:
        if substData is None:
            substData = self.opts['substitutions']
        else:
            substData.update(self.opts['substitutions'])
# set substitutions as group parameter, substitute at load time 
#    wdgRoot = copy.deepcopy(self.wdg)
#    if substData != None:
#        macros = newElemToTree(wdgRoot,'macros')
#        parsePV(substData)
#        for n in substData:
#            newElemToTree(macros,n,substData[n])
#*** END setsubstitutions as group

# replace macros here for decreased load time
    sString = self.wdgStr

    if substData != None:
        parsePV(substData)
        for n in substData:         # replace macros here for decreased load time
            sString = sString.replace(bytes("$("+n+")",'utf-8'),bytes(str(substData[n]),'utf-8') )
    #print("\nWIDGET: ",sString)
    wdgRoot = ET.XML(sString)
#** END replace macros here

    x = wdgRoot.find('x')
    y = wdgRoot.find('y')
    x.text = str(xPos + int(x.text))
    y.text = str(yPos + int(y.text))

    if substData != None and "COLOR" in substData:
        color = substData['COLOR']
        colorData = getColor(color)
        if colorData != None:
          for c in wdgRoot.iter('color'):
              if(c.attrib['name'] == 'dummy1'):
                  c.attrib['name']  = color
                  c.attrib['red']   = str(colorData['red'])
                  c.attrib['green'] = str(colorData['green'])
                  c.attrib['blue']  = str(colorData['blue'])

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
    if opts['verbose']: print("layout: Line at y:",yPos)
    panelWidth = opts['width'];
    dWidth = display.find('width')
    dWidth.text = str(panelWidth)
    xPos=0
    yLast = yPos          # after finish a group next group needs to know this
    dbg = Dbg( ("type","x","y","substitutions") )

    for group in substData: # the .template files
        (wName,wExt) = getFileExt(group[0])
        if opts['verbose']:print("Group:",wName,"at x:",xPos," y:",yPos)
        items = group[1:len(group)]
        if opts['sort'] != None: items = sorted(items,key=lambda x: x[opts['sort']])

        try:        
            wdgItem = opts['widgetStore'][wName]
            for item in items:
                dbg.add( (wdgItem.name,str(xPos),str(yPos),str(item)) )
                (wdgWidth,wdgHeight,wdg) = wdgItem.setWidget(xPos,yPos,item)
                #print(prettyXml(ET.tostring(wdg,encoding='utf-8')))
                display.append(wdg)

                if (xPos + 2*wdgWidth) > opts['width']:
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

    if opts['verbose']:
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
    if opts['verbose']: print("layout: LineRaw at y:",yPos)
    panelWidth = opts['width'];
    dWidth = display.find('width')
    dWidth.text = str(panelWidth)
    xPos=0
    yLast = yPos          # after finish a group next group needs to know this
    wdgMaxHeight = 0
    dbg = Dbg( ("type","x","y","substitutions") )

    for group in substData: # the .template files
        (wName,wExt) = getFileExt(group[0])
        if opts['verbose']: print("Group:",wName,"at x:",xPos," y:",yPos)
        items = group[1:len(group)]
        if opts['sort'] != None: items = sorted(items,key=lambda x: x[opts['sort']])

        try:        
            wdgItem = opts['widgetStore'][wName]
            if wdgItem.h > wdgMaxHeight:
                wdgMaxHeight = wdgItem.h
            
            for item in items:
                if (xPos + 2*wdgItem.w) > opts['width']:
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
    if opts['verbose']: 
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
    if opts['verbose']: print("layout: collumn at y:",yPos)
    panelWidth = opts['width'];
    dWidth = display.find('width')
    dWidth.text = str(panelWidth)
    xPos = 0
    y0   = yPos          # after finish a group next group needs to know this
    yMax = yPos
    dbg  = Dbg( ("type","x","y","substitutions") )

    for group in substData: # the .template files
        (wName,wExt) = getFileExt(group[0])
        if opts['verbose']: print("Group:",wName,"at x:",xPos," y:",yPos)
        items = group[1:len(group)]
        if opts['sort'] != None: items = sorted(items,key=lambda x: x[opts['sort']])

        try:        
            wdgItem = opts['widgetStore'][wName]
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
    if opts['verbose']:
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
    if opts['verbose']: print("layout: table at y:",yPos)
    panelWidth = opts['width'];
    dWidth = display.find('width')
    dWidth.text = str(panelWidth)
    xPos = 0
    y0   = yPos          # after finish a group next group needs to know this
    yMax = yPos
    dbg  = Dbg( ("type","x","y","substitutions") )

    for group in substData: # the .template files
        (wName,wExt) = getFileExt(group[0])
        if opts['verbose']: print("Group:",wName,"at x:",xPos," y:",yPos)
        items = group[1:len(group)]
        if opts['sort'] != None: items = sorted(items,key=lambda x: x[opts['sort']])

        try:        
            wdgItem = opts['widgetStore'][wName]
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
    if opts['verbose']:
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
    * Option --baseW: The backround display file determins width and height of 
      the panel. It is the canvas to place the widgets in.
    * Without --baseW option the display width and hight is calculated to fit for all widgets
    """
    if opts['verbose']: print("layout: xy")

    xPos = 0
    yPos = 0          # ignore title height parameter, as title is the background file!
    yMax = 0
    xMax = 0
    dbg  = Dbg( ("type","x","y","substitutions") )
    for group in substData: # the .template files
        (wName,wExt) = getFileExt(group[0])
        if opts['verbose']: print("Group:",wName)
        items = group[1:len(group)]
        try:        
            wdgItem = opts['widgetStore'][wName]
            for item in items:
                try:
                    (xPos,yPos) = item['PANEL_POS'].split(',')
                    xPos = int(xPos)
                    yPos = int(yPos)
                    del(item['PANEL_POS'])      # unuseful in widget substitutions
                except KeyError:
                     sys.stderr.write("ERROR: Can't find PANEL_POS in: "+str(item)+"\n");
                if opts['verbose']: print("    Set:{}\tx:{} y:{}".format(wName,xPos,yPos))
                (wdgWidth,wdgHeight,wdg) = wdgItem.setWidget(xPos,yPos,item)
                display.append(wdg)
                if xPos+wdgWidth > xMax: xMax = xPos+wdgWidth
                if yPos+wdgHeight> yMax: yMax = yPos+wdgHeight
        except ValueError as err:
            sys.stderr.write("Warning: skip: "+err+"\n")
            continue
    # parameter 'display' is set either to backGroundDisplay or the empty default display
    dWidth  = display.find('width')
    dHeight = display.find('height')
    if opts['backGroundDisplay'] == None:
        dHeight.text = str(yMax)
        dWidth.text  = str(xMax)
    else:
        if int(dWidth.text) < xMax:
            sys.stderr.write("Warning: Background display width:{} smaler than calculated, set to {}".format(dWidth.text,str(xMax))+"\n" );
            dWidth.text = str(xMax)
        if int(dHeight.text) < yMax:
            sys.stderr.write("Warning: Background display height:{} smaler than calculated, set to {}".format(dHeight.text,str(yMax))+"\n" );
            dHeight.text = str(yMax)
    
    if opts['verbose']: print("Display width:",dWidth.text," height:",dHeight.text)
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
    dbg  = Dbg( ("Widget","x","y","substitutions") )
    itemList     = []

    for group in substData: # the .template files
        (wName,wExt) = getFileExt(group[0])
        items = group[1:len(group)]
        try:        
            wdgItem = opts['widgetStore'][wName]

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
                dbg.add(( ("{}:w={} h={} sp={}".format(wdgItem.name,wdgItem.w,wdgItem.h,(0 if not span else span))) ,str(xPos),str(yPos),str(item)) )
        except ValueError as err:
            sys.stderr.write("Warning: skip: "+err+"\n")
            continue

    if len(itemList) == 0: 
        sys.stderr.write("ERROR: No GRID items found skip Display\n")
        return

    if opts['verbose']: 
        print("The .substitutions data:")
        dbg.print()
    
    xLen = 0    
    yLen = 0    
    for item in itemList:
        if item.xGrid > xLen: xLen = int(item.xGrid)
        if item.yGrid > yLen: yLen = int(item.yGrid)
    xLen += 1
    yLen += 1
    table = []
    colMaxWidth  = [0] * xLen
    rowMaxHeight = [0] * yLen
    spannedRows  = [None] * xLen
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

    for spnItem in spannedRows:  # calculate in pos direction, so later width has to be allready corected by span
        if spnItem == None:
            continue
        spannedCols = colMaxWidth[spnItem.xGrid:(spnItem.xGrid+spnItem.span)];
        spannedWidth = 0
        for w in spannedCols:   # total width of the spanned collumns ..
            if w != None: spannedWidth += w
        if spannedWidth < spnItem.wdgWidth:  # .. if the spanned widget exceeds this ..
            colMaxWidth[spnItem.xGrid+spnItem.span-1] += spnItem.wdgWidth - spannedWidth # .. add to the first collumn

    displayWidth=0
    for x in colMaxWidth: displayWidth += x
    displayHeight=0
    for x in rowMaxHeight: displayHeight += x
    spanedWidth = 0

    # show table
    if opts['verbose']:
        h = [ str(x) for x in range(0, yLen)]
        tblDbg = Dbg(h)
        tblDbg.add(colMaxWidth)
        for row in table:
            R=[]
            for w in row:
                if w != None:
                    R.append("{}:{},{}".format(w.widget.name,w.xGrid,w.yGrid))
                else:
                    R.append("None")
            tblDbg.add(R)
        print("\nPanel layout overview:")
        tblDbg.print()

    rowPos = [0]*len(rowMaxHeight)
    rowPos[0] = int(y0)
    for y in range(1,len(rowMaxHeight)):
        rowPos[y] = rowPos[y-1] + rowMaxHeight[y-1]
    colPos = [0]*len(colMaxWidth)
    for x in range(1,len(colMaxWidth)):
        colPos[x] = colPos[x-1] + colMaxWidth[x-1]
    if opts['verbose']:
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
            dbg.add(( ("{}:w={} h={}".format(parsedWdg.name,parsedWdg.w,parsedWdg.h)) ,str(xPos),str(yPos),str(item.subst)) )
            display.append(wdg)
    if opts['verbose']:
        print("\nProcessed widget positions:")
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

#-------- get substitutions data
    if opts['inFile'] != "-":
        f= open(opts['inFile'], "r",encoding=opts['encoding'])
    else:
        if opts['verbose']: print("(expect input from stdin)\n")
        f= sys.stdin
    substFileStr= f.read()
    if opts['inFile'] != "-":
        f.close()
    
    substData = parse_subst.parse(substFileStr,"list")
    #print("PARSED substData:",substData)

#-------- check for widget dependencies and read them
    dependencies = [x[0] for x in substData]
    if opts['dependencies'] == True:
        depFiles = []
        for widgetFileName in dependencies:
            (widget,wdgFile) = getWidgetFile(widgetFileName,opts)
            if wdgFile == None:
                sys.stderr.write("-M: dependant file '{}' not found\n".format(widgetFileName))
            else:
                depFiles.append(wdgFile)
        with open(opts['outFile']+".d",mode="w") as w:
            w.write("{}: {}\n".format(opts['outFile']," ".join(depFiles) ))
        return
    for wdg in dependencies:
        w = ParsedWidget(file=wdg,options=opts)
        if w.name != None:
            opts['widgetStore'][w.name] = w

    if opts['verbose']: 
        table=[]
        print("\n**** WIDGET Store:")
        for wKey in opts['widgetStore']:
            w=opts['widgetStore'][wKey]
            table.append((wKey,w.w,w.h))
        printTable(table,("Widget","width","height"),0)

        print("\n**** Process LAYOUT:",opts['layout'])
    if opts['backGroundDisplay'] != None:
        display = opts['backGroundDisplay']
    target = "stdout"
    if opts['outFile'] != "-":
        path=opts['outFile'].split('/')
        target = ".".join(opts['outFile'].split('/')[-1].split('.')[0:-1])
    dN = display.find('name')
    dN.text = target
#-------- create display by layout
    printData = "Empty Print Data!"    
    yPos      = 0
    if 'title' in opts['widgetStore']:
        (wdgWidth,wdgHeight,wdg) = opts['widgetStore']['title'].setWidget(0,yPos,opts['substitutions'])
        display.append(wdg)
        yPos = int(wdgHeight)

    if opts['layout'] == 'line':    
        printData = layoutLine(substData,display,yPos,opts)
    elif opts['layout'] == 'rawline':    
        printData = layoutRawLine(substData,display,yPos,opts)
    elif opts['layout'] == 'column':
        printData = layoutColumn(substData,display,yPos,opts)
    elif opts['layout'] == 'table':
        printData = layoutTable(substData,display,yPos,opts)
    elif opts['layout'] == 'xy':
        printData = layoutXY(substData,display,yPos,opts)
    elif opts['layout'] == 'grid':
        printData = layoutGrid(substData,display,yPos,opts)
#-------- print display file
    if opts['outFile'] is not None:
        out= open(opts['outFile'], "w")
        output_mode = "a"
    else:
        out= sys.stdout
    out.write(printData)
    if opts['outFile'] is not None:
        out.close()

#--------------------------------------------------
def main():
    description="Convert EPICS substitution file/s to panels in phoebus .bob format\n"

    parser = ArgumentParser(description=description, epilog="* Author: B. Kuner")
    parser.add_argument('InOutFile', nargs='+',
                    help='Input File in EPICS.substitutions format, output panel-filename.bob'
                    )
    parser.add_argument("--baseW",
                      help="Background display file, mandatory for for layout=xy",
                     )
    parser.add_argument("--border",
                      type=int,
                      default=0,
                      help="see spaceing. For compatibility to CreatePanel.pl option",
                     )
    parser.add_argument("--encoding",
                      help="Input file encoding, default: utf8. Files for edm, medm: latin",
                     )
    parser.add_argument("-I",
                      action="append",
                      type=str,
                      default=[],
                      help="Search path(s) for panel widgets, Delimiter: ':'",
                     )
    parser.add_argument("-i",
                      action="store_true",
                      help="Add ., .., \$EPICS_DISPLAY_PATH' variable to search path(s) for panel widgets",
                     )
    parser.add_argument("--layout",
                      help=" line|xy|grid|table|collumn|rawline    placement of the widgets,(default: by Line)",
                     )
    parser.add_argument("-M",
                      action="store_true",
                      help="Create make dependencies",
                     )
    parser.add_argument("--sort",
                      help="--sort KEY: Sort a group of signals by its substitutions key. Not for for layouts: 'grid' and 'xy'",
                     )
    parser.add_argument("--spaceing",
                      type=int,
                      default=0,
                      help="extra space in pixel between widgets",
                     )
    parser.add_argument("--subst",
                      help=" 'NAME=\"VALUE\";...' Panel substitutions from commandline, Item delimiter: ';'",
                     )
    parser.add_argument("--title",
                      help="TitleString | Title.type  Title of the panel (string or file).",
                     )
    parser.add_argument("--type",
                      help="Output type: bob, (adl, edm not supported yet)- Default is bob",
                     )
    parser.add_argument("-v", "--verbose",
                      action="store_true",
                      help="verbose",
                     )
    parser.add_argument("-w",
                      type=int,
                      default=900,
                      help="Panel width (default=900)",
                     )
#    parser.add_argument("-x",
#                      help="(pixel) X-Position of the panel (default=100)",
#                     )
#    parser.add_argument("-y",
#                      help="(pixel) Y-Position of the panel (default=100)",
#                     )
    options = parser.parse_args()

    opts = {}
    opts['inFile'] = None
    opts['outFile'] = None
    try:
        (opts['inFile'], opts['outFile']) = options.InOutFile
    except ValueError:
        sys.stderr.write("ERROR: illegal argument for in-, out-file: '{}'".format(options.InOutFile))
        sys.exit(1)
    opts['encoding'] = 'utf8'
    if options.encoding: 
        opts['encoding'] = options.encoding

    opts['verbose'] = False
    if options.verbose: 
        print("READ: ",opts['inFile'],"WRITE:",opts['outFile'])
        opts['verbose'] = True

    opts['type'] = "bob"    
    if options.type:
        if options.type not in ['bob']: # Currently only bob supported! ['bob','adl','edl']:
            sys.stderr.write("ERROR: not supported --type option: "+options.type)
            sys.exit(1)
        opts['type'] = options.type

    opts['width'] = 900
    if options.w:
        try:
            opts['width'] = int(options.w)
        except ValueError:
            sys.stderr.write("ERROR: illegal --width option: "+options.w)
            sys.exit(1)

    opts['layout'] = "line"
    if options.layout:
        if options.layout not in ['line','xy','grid','table','column','rawline']:
            sys.stderr.write("ERROR: illegal --layout option: "+options.layout)
            sys.exit(1)
        opts['layout']= options.layout

    opts['substitutions'] = None    
    if options.subst:
        opts['substitutions'] = parseParam(options.subst,';')

    opts['dependencies'] = None    
    if options.M:
        opts['dependencies'] = True

    opts['sort'] = None
    if options.sort:
        opts['sort'] = options.sort
    opts['searchDlPath'] = []
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
    opts['searchDlPath'] = [*path_I, *path_i]
    if opts['verbose']: print("WIDGETPATH:\t",opts['searchDlPath'])

    opts['widgetStore'] = {} # buffer allready parsed widgets 

    opts['backGroundDisplay'] = None
    if options.baseW:
        try:            # check if its a file name of form: name.extension
            (file,ext) = getFileExt(options.baseW)
            if ext != opts['type']:
                sys.stderr.write("ERROR: option mismatch panel type and title extension "+options.baseW)
                sys.exit(1)

            (widget,wdgFile) = getWidgetFile(options.baseW,opts)
            if wdgFile != None:
                with open(wdgFile, "r",encoding=opts['encoding']) as f:
                    bgString = f.read()
            else:
                sys.exit(1)
            if opts['substitutions'] != None:
                for n in opts['substitutions']: # replace macros here for decreased load time
                    bgString = bgString.replace("$("+n+")",opts['substitutions'][n] )
            display = ET.XML(bgString)
            opts['backGroundDisplay'] = display
        except AttributeError:
            sys.stderr.write("ERROR: in --baseW option: '"+options.baseW+"'\n")

    opts['spaceing'] = 0
    opts['titleWdg'] = None
    if options.title:
        titleFile = options.title
        try:            # check if its a file name of form: name.extension
            (file,ext) = getFileExt(titleFile)
            if ext != opts['type']:
                sys.stderr.write("ERROR: option mismatch panel type and title extension "+options.title)
                sys.exit(1)
            titleWdg = ParsedWidget(file=titleFile,options=opts)
        except AttributeError:
            titleWdg = ParsedWidget(xmlStr=createLableStr(options.title,opts['width'],30,0,0,25),options=opts)

        except:           # title string, put to text wiget
            sys.stderr.write("ERROR: illegal --title option: "+options.title+"\n")
        opts['widgetStore']["title"] = titleWdg

    # set spaceing after setting the title!
    if options.border:
        opts['spaceing'] = int(options.border)
    if options.spaceing:
        opts['spaceing'] = int(options.spaceing)

    process_file(opts)

if __name__ == "__main__":
    main()            


