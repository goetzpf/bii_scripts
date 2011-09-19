"""
This module is a wild collection classes and functions used to handle EPICS data:
===============================================================================

def die(errMsg,line=None):
def hasIndex(lst,idx):
def matchRe(matchStr,reStr) :
def substRe(matchStr,matchRe,replaceStr):
def parseParam(fieldPar):
def printTable(rT,header=None,sortIdx=None) :
def getShiftParam(bits):
def getEcName(port,canId,cardNr,namesEnd):
def getOpcLink(PLCLink,rtyp,bits,device_name,lines,fileName):
    * For binary records the class PLC_Address() helps to manage mbbiDirect records to read
def getHwLink(rtyp,port,canId,cardNr,chan,name,fileName,iocTag,lineNr=None):
def adaCanMux(id,card,chan,typ='hex'):
def createAdaCanLink(port,id,card,chan):

class Panels(object):
    Manage store and print of a group of panels. This class creates panel.substitutions information 
    class PanelFile(object):
    class PanelWidget(object):
        Subclass to manage one widget

class epicsAlh(object):
    This class hold all data to  write an alarm handler file.

class epicsTemplate(object):
    This class stores and print an EPICS database data for .db or .template files.

class X_Address(object):
    Base class to manage PLC address names

class PLC_Address(X_Address):
    This class manages a SPS-Symbolname address used in method getOpcLink()

class DB_Address(X_Address):
    This class manages a Siemens PLC adrress. Not used now in method getOpcLink()
"""
from optparse import OptionParser
import sys
import os
import re
import math
import csv
import BDNS
import os.path

def die(errMsg,line=None):
    """
    like perl die function: print message and stacktrace, than exit program
    """
    from traceback import extract_stack
    from traceback import format_list
    
    st = extract_stack()
    err = "\n".join(format_list(st[0:-1]))
    err += "\nERROR: *** "+errMsg+"***"
    if line is not None:
    	err += "(Line:"+str(line)+")"
    err += "\n"
    sys.exit(err)    

def hasIndex(lst,idx):
    """
    Check if 'idx' exist in list 'lst'
    Return True or False instead of raise IndexError
    """
    try : 
    	x = lst[idx]
    except IndexError:
    	return False
    return True

def matchRe(matchStr,reStr) :
    """
    Return tupel with matches, maybe empty if reStr contains no '()' 
        or 'None' if 'matchStr' doesn't match 'reStr'
	
    Check for matches:  
    
    	if matchRe('huhu','xxx') is not None : 
	
    Get match data or None:
    
    	myList = matchRe('my/file.ext','(.*)\.(.+)')
	
    Get tupel of matched data or Raise Errors:

    	try:
	    (a,b) = matchRe('my/file.ext','(.*)\.(.+)')
	except TypeError:
	    print "Doesn't match anything"
	except ValueError:
	    print "Doesn't match the number of values as defined in the tupel"
    """
    regx = re.compile(reStr)
    m = regx.match(matchStr)
    if m is not None :
    	return m.groups()
    else:
    	return None

def substRe(matchStr,matchRe,replaceStr):
    """
    Return substitute 'matchRe' replaced by 'replaceStr' from 'matchStr'
    """
    regx = re.compile(matchRe)
    return regx.sub(replaceStr,matchStr)

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
    """
    commFields = {}
    valList = fieldPar.split(delim) # set alarm values and additional fields for a record
    if len(valList) > 0 and valList[0] != '':
	for v in valList:
	    try:
	    	(valName,val)  = matchRe(v,'(.*?)=(.+)')
		commFields[valName] = val
	    except TypeError:
	    	if len(valList) == 1:
		    return valList[0]
		else:
		    return valList
    return commFields
    
def printTable(rT,header=None,sortIdx=None) :
    """
    Print formated table
    
    Parameter:
    
    - rT,	# The table, a array reference (rows) of an array reference (columns)
    - header,	# (optional) Header, list of strings for each collumn
    - sortIdx	# (optional) Index of the column the table should be sorted to
    """
    lines = header
    formatMax = []	    # max item length of a collumn
    rTable = rT
    if (sortIdx is not None) and sortIdx < len(rT[0]):
    	rTable = sorted(rT,key=lambda x: x[sortIdx])
    if header is not None:
	idx=0
	formatMax = map(lambda x: len(x), lines)
    #print "header: ",formatMax
    def choose(x):
	(a,b) = x
	if x[0] < x[1]: return x[1] 
	else: return x[0]
    def length(x):
    	if x is not None:
	    return len(str(x))
	else:
	    print x
	    return 0
    for row in rTable:
	fLen = map(lambda x: length(x),row)
	formatMax = map(lambda x: choose(x),zip(formatMax,fLen))
    #print "rT",formatMax
    print " | ".join(map(lambda x:("%%%ds"%x[0])%x[1] ,zip(formatMax,header)) )
    print "-+-".join(map(lambda x: x*'-' ,formatMax) )
    for line in rTable:
    	print " | ".join(map(lambda x:("%%%ds"%x[0])%x[1] ,zip(formatMax,line)) )

def getShiftParam(bits):
    """
    Bitrange to paramteres NOBT, SHFT. Parameter bits = 'n' or bits = 'n - m' , 
    SHIFT = n, NOBT = nr of elements.
    Return tupel: (NOBT,SHFT),  NOBT=1 for bits = 'n'
    E.G getShiftParam('5 - 7') = (3,5), getShiftParam('7') = (7,1)
    """
    nobt = 0
    shft = 0
    if bits != '':
    	li = bits.split('-')
    	if li != None:
	    shft = int(li[0].strip())
	    nobt = 1
    	    if len(li) > 1:
	    	nobt += int(li[1].strip()) - int(li[0].strip())
    return (nobt,shft)

def getEcName(port,canId,cardNr,namesEnd):
    """
    Embedded controller device, to hold the mbbi/oDirect. Derives its name from 
    the IOC name to get a unique name for each embedded controller. Remove the
    characters IO from the IOC name to get this e.g. IOC1S15GP -> C1S15GP 
    
    EC<port>-<id><card><IOC derived part>
    
    e.g. Port 1 Id5 card 3 on IOC1S15GP -> EC1-53C1S15GP
    """
    return "EC%d-%02d%s:C%1d"%(int(port),int(canId),namesEnd,int(cardNr))

def getOpcLink(PLCLink,rtyp,bits,device_name,lines,fileName):
    """
    * Set the fields DTYP, SCAN, INP/OUT 

    * For binary records the class PLC_Address() helps to manage mbbiDirect records to read
    the data and distribute it to the binary records.
    
    * Up to now only the symbolic links to a PLC are supported, not the Siemens direct addresses (e.g. 'DB2.X4')
    """
    fields = {}
    if device_name is None:
    	die("Missign option -n deviceName for common mbb_Direct record",lines)
    if rtyp in ('ai','longin','mbbiDirect'):
    	fields['DTYP'] = "opc"
    	fields['SCAN'] = "I/O Intr"
	fields['INP'] = '@'+PLCLink
    elif rtyp in ['ao','longout','mbboDirect']:
    	fields['DTYP'] = "opc"
	fields['OUT'] = '@'+PLCLink
    elif rtyp in ('bi','mbbi','bo','mbbo'):	# access via mbb_Direct to CAN
        (nobt,shft) = getShiftParam(bits)
    	if rtyp in ('bi','mbbi','mbbo'):	# access via mbb_Direct to CAN
            fields['SHFT']  = shft
            fields['NOBT']  = nobt
	    fields['DTYP'] = "Raw Soft Channel"
	dbAddr = PLC_Address(PLCLink,rtyp,bits,device_name,lines)
#    	dbAddr = DB_Address(DBLink,rtyp,opc_name,device_name,lines)
	if rtyp in ('bi','mbbi'):
    	    fields['INP'] = dbAddr.getLink()
	else:
    	    fields['OUT'] = dbAddr.getLink()
    return (fields)


def getHwLink(rtyp,port,canId,cardNr,chan,name,fileName,iocTag,lineNr=None):
    """
    Create an Hardware Link, CAN or VME. The argument canId may be an integer for CAN or 
    a string for the DTYP of the VME device.
    """
    fields = {}
#    print "getHwLink(",rtyp,port,canId,cardNr,chan,name,fileName,lineNr,")"
    try:
    	int(canId)	# CAN link
	if rtyp in ('ai','longin','mbbiDirect'):
    	    fields['DTYP'] = "lowcal"
	    fields['INP'] = createAdaCanLink(port,canId,cardNr,chan)
	elif rtyp in ['ao','longout','mbboDirect']:
    	    fields['DTYP'] = "lowcal"
	    fields['OUT'] = createAdaCanLink(port,canId,cardNr,chan)
	elif rtyp in ('bi','mbbi','bo','mbbo'):	# access via mbb_Direct to CAN
	    hwDevice = getEcName(port,canId,cardNr,iocTag)
	    if rtyp in ('bo','mbbo'):
	    	linkName ='OUT'
		mux = 9
		recType = 'mbboDirect'
		hwSignal = "outBits"
	    else:
	    	linkName ='INP'
		mux = 8
		recType = 'mbbiDirect'
		hwSignal = "inBits"
	    if epicsTemplate.getDevice(hwDevice) is None: 
	    	f = {'DESC'  :'Access Port:'+str(port)+", Id:"+str(canId)+", card:"+str(cardNr),
		     'NOBT'  :'16',
		     'DTYP'  :'lowcal',
		     'SNAME' : hwSignal,
    	    	     linkName: createAdaCanLink(port,canId,cardNr,mux)
		    }
	    	epicsTemplate(recType,{'DEVN':hwDevice},f)
	    
	    (nobt,shft) = getShiftParam(chan)
	    fields['SHFT']  = shft
	    if rtyp in ('bo','bi'):
	    	fields[linkName]= "%s:%s.B%X CPP MS" % (hwDevice,hwSignal,shft)
	    else:   # mbbi, mbbo
	    	fields[linkName]= "%s:%s CPP MS" % (hwDevice,hwSignal)
	    	fields['NOBT']= nobt
	    	fields['SHFT']= shft
    except ValueError:   	    	    	# VME link
    	if len(canId) > 0:
	    fields['DTYP'] = canId
	    (nobt,shft) = getShiftParam(chan)
	    link = "#C%dS%d"% (int(cardNr),int(shft))
	    if nobt is not None:
	    	fields['NOBT'] = nobt
	    	fields['SHFT'] = shft
	    
	    if rtyp in ('bi','mbbi'):	# access direct to card
    	    	fields['IN'] = link
	    elif rtyp in ('bo','mbbo',):	# access direct to card
    	    	fields['OUT'] = link
    	    if lineNr==54:
	    	print rtyp, link,fields['OUT']
	else:
	    warnings.append([fileName,lineNr,"WARN: ",name,"No CAN-Id/DTYP (Col. E) Can't create link"])
    return (fields)

def adaCanMux(id,card,chan,typ='hex'):
    """
    Calculate Can can parameters from Node-Id, Card and Channel for ADA analog input 
    channels.
    
    Return (OUT_CAN,IN_CAN,MUX)
    """
    frmt = "%X"
    if typ == 'dec': frmt = "%d"
    outCan = frmt%(320+int(id),)
    inCan  = frmt%(256+int(id),)
    mux    = frmt%(int(card)*12+int(chan))
    return (outCan,inCan,mux)

def createAdaCanLink(port,id,card,chan):
    """
    Setup a complete CAN link from adaCanMux data:
    
    Return "@f s 5 PORT OUTCAN INCAN MUX 64 3E8 0" % (int(port),outCan,inCan,mux)
    """
    (outCan,inCan,mux) = adaCanMux(id,card,chan)
    return "@f s 5 %X %s %s %s 64 3E8 0" % (int(port),outCan,inCan,mux)

class Panels(object):
    """
    Manage store and print of a group of panels. This class creates panel.substitutions information 
    to be expanded to a panel with the CreatePanel.pl script of (bii_scripts:http://www-csr.bessy.de/control/bii_scripts/html/scripts/CreatePanel.html)
    
    It supports to create several panel files and groups of widgets within a panel
      
    Spreadsheet collumns
    --------------------
    
    * EPICS Panel Name Prefix (Col. W): The Panel Name, without the ending .edl
      
    * EPICS Panel Group	(Col. X):  The Group within a panel. Omit this will put all signals to a default group.
    
      Each group will be shown with a text.edl widget as headline, also with GRID definition!

    * EPICS Panel Sort/Grid (Col. Y): 
    
      - Nothing: Sort all signals by device- and signal name
      - Unique number: Sort within a group by number. 
        To get the order as defined in the spreadsheet just put an incrementet number here
      - (GRID="x,y") or (GRID="x,y",SPAN="n"or (XY="n,m"): Just pass the parameter to the panel.substitutions file 
        to be interpreted by CreatePanel.pl
        ATTENTION: the Groupname will get the Y position of Ymin-1, so there has to be a free gap of 1 line in grid-Y numbering!
      

    """
    class PanelFile(object):
	"""
	Store all informations to hold a panel group
	"""
	def __init__(self,panelName,widgetPath) :
    	    self.panelName = panelName    # panel name
	    self.groups = []    # [groupName_1, groupName_2,...] to get the order of groups
	    self.items  = {}    # self.items[groupName_n] = [item1, item2,...] the items of a group
	    self.order = BDNS.mkOrder("MEMBER,DOMAIN,SUBDOMNUMBER,INDEX,SUBINDEX")
    	    self.widgetPath = widgetPath
#	    print "PanelFile:",panelName,widgetPath
	def __str__(self):
	    return "PanelGroup: '"+self.panelName+"'\nGROUPS:\n"+str(self.groups)+"\nITEMS:\n"+str(self.items)
	def __repr__(self):
    	    return self.__str__()
	def addGroup(self,group):
#    	    print "PanelFile.addGroup:",group
	    self.groups.append(group)
	    self.items[group] = []
	def addItem(self, group,devNamedata,itemDict,panelWidgetName,sort=None):
#	    print "PanelFile.addItem:",group,itemDict,panelWidgetName,sort
	    if self.items.has_key(group)	is False:
		self.addGroup(group)
	    self.items[group].append(Panels.PanelWidget(devNamedata,itemDict,panelWidgetName,self.order,sort))
    	def getWidgetType(self,item):
    	    if item.widgetName:
	    	return item.widgetName
	    elif item.type in ['ai','bi','mbbi','calc']: 
	    	    return "anyVal"
	    else:   return item.type
	def checkWidgetPath(self,widget):
	    fname = widget+".edl"
#	    print "checkWidgetPath",widget,fname,"\n\t",self.widgetPath
	    for path in self.widgetPath:
	    	if os.path.isfile(path+"/"+fname): 
#		    print "\t",path+"/"+fname
		    return True
	    return False
	def toSubst(self):
	    """
	    Print all panel info in substitution format to be processed by CreatePanel.pl. Sort algorythms 
	    are defined by the panels sort column (see above):
	    """
	    retStr = ""	# hold the substitutions string

	    def cmpWidget(a,b): return a.cmpWidget(b)
#	    print "Panels.PanelFile.toSubst() of Groups:",self.groups,"\nItems:",self.items
	    groupList = self.groups
    	    # first take the default group signals
	    try:
	    	idx = groupList.index("Panels DefaultGroup")
	    	del(groupList[idx])
		groupList = ["Panels DefaultGroup"]+groupList
	    except ValueError:
	    	pass
	    for pGroup in groupList:
    	    	
# if not an empty group, setup widget item list
		if self.items.has_key(pGroup) and len(self.items[pGroup]) <= 0:
    	    	    continue 
		itemList = self.items[pGroup]

# get how to sort and sort items
    	    	itemList = sorted(itemList,cmpWidget)		    	

		groupWidget = None
    	    	if pGroup != "Panels DefaultGroup":
		    gridHead=""
		    if itemList[0].isSort == "SORT_BY_GRID": 
			try:
		    	    widget = itemList[0]
			    y = int(widget.yPos)
		    	    if(y <= 0):
		    		raise ValueError
    	    		except ValueError:
		    	    die("Can't set header for group: "+pGroup+"and minimal y parameter: "+widget.sort+", Pos=("+widget.xPos+","+widget.yPos+")")
			gridHead=", GRID=\"0,"+ str(y-1) +"\""

			xMax = 0
			for x in itemList:
			    if x.xPos > xMax:
				 xMax=x.xPos
			if xMax > 1: 
		    	    gridHead = gridHead+", SPAN=\""+xMax+"\""

# Check if this group has a header widget take a text widget
		    if pGroup != "":
			groupWidget = itemList[0].widgetName
			if self.checkWidgetPath(groupWidget+"Header"):
		    	    retStr += "file "+groupWidget+"Header.edl  {\n  {"+gridHead+"}\n}\n"
			else:
		    	    retStr += "file text.edl  {\n  { TEXT=\""+pGroup+"\",WIDTH=\"400\",COLOR=\"28\",TXTCOLOR=\"0\""+gridHead+"}\n}\n"

# process each group
		actualWidgetType = ""
		wLst = []	# hold consecutive widgets of the same type
#		print "Group:",pGroup,itemList
		actualWidgetType = self.getWidgetType(itemList[0])
		wLst.append(itemList[0])
		for item in itemList[1:]:
		    wType = self.getWidgetType(item)
		    if actualWidgetType != wType:
#		    	print "TypeChange: ",actualWidgetType, "->", wType
			retStr += "file "+actualWidgetType+".edl {\n"+"\n".join(map(lambda x: str(x),wLst))+"\n}\n"
			actualWidgetType = wType
			wLst = []
		    wLst.append(item)
#		    print actualWidgetType,wType,"\t",item.type,str(item)
    	    	if len(wLst)>0:
		    retStr += "file "+wType+".edl {\n"+"\n".join(map(lambda x: str(x),wLst))+"}\n"

		retStr+"}\n"
		if groupWidget and self.checkWidgetPath(groupWidget+"Footer"):
		    retStr += "file "+groupWidget+"Footer.edl  {\n  {}\n}\n"
	    return retStr
		
    class PanelWidget(object):
    	"""
	Subclass to manage one widget
	"""
	def __init__(self,devNamedata,item,panelWidgetName,order,sort=None):
#	    print "PanelWidget("+panelWidgetName+","+str(devNamedata)+","+str(item)+","+sort+")"

	    self.widgetName = panelWidgetName # may be overwritten by parsed sort parameter!

	    if isinstance(devNamedata,dict) and len(devNamedata.keys())==1:
    	    	self.devn = devNamedata
	    else:
	    	raise TypeError, "Parameter devNamedata="+str(devNamedata)+" is: "+str(type(item))+". Has to be <type 'dict'>"
	    if isinstance(item,dict):
	    	self.data = item
	    else:
	    	raise TypeError, "Parameter item is: "+type(item)+". Has to be <type 'dict'>"

	    self.isSort = None
	    self.sort = sort
	    self.xPos=None
	    self.yPos=None
	    self.bdnsOrder = order
	    if sort == None or len(sort) == 0: 
		self.isSort = "SORT_BY_BDNS"
	    else:
		Sort = parseParam(sort)
		if isinstance(Sort,str):
		    int(Sort)
		    self.isSort = "SORT_BY_NUMBER"
		elif isinstance(Sort,dict):
		    if Sort.has_key('GRID'):
			self.isSort = "SORT_BY_GRID"
			xy = Sort['GRID']
			(self.xPos,self.yPos)=xy.split(',')
			if self.xPos is not None and self.yPos is not None:
	    		    self.data.update(parseParam(sort))
			else:
			    raise ValueError, "No valid grid sort parameter: "+sort
		    if Sort.has_key('WIDGET'):
		    	self.widgetName = Sort['WIDGET']
		else:
		    raise ValueError, "PanelWidget.__init(): Not a valid sort parameter: "+sort

	def __str__(self):
	    data = ", ".join(map(lambda x:str(x)+"=\""+str(self.data[x])+"\"" ,self.data.keys()))
	    if len(data)>0: data = ", "+data
	    devnTag = self.devn.keys()[0]
	    return "  { "+devnTag+"=\""+self.devn[devnTag]+"\""+data+"}"
	def __repr__(self):
	    data = ", '".join(map(lambda x:str(x)+"':\""+str(self.data[x])+"\"" ,self.data.keys()))
	    return "\n\tPanelWidget("+str(self.devn)+","+str(data)+","+str(self.widgetName)+")"
	def cmpWidget(self,pw):
	    #print "cmpWidget: (",self.devn,self.isSort,") (",pw.devn,pw.isSort,")"
	    if self.isSort == "SORT_BY_NUMBER" and pw.isSort == "SORT_BY_NUMBER":
        	try:
        	    a= int(self.sort)
        	    b= int(pw.sort)
        	    return cmp(a,b)
        	except ValueError:
        	    return cmp(self.sort,pw.sort)
	    elif self.isSort == "SORT_BY_BDNS" and pw.isSort == "SORT_BY_BDNS":
    	    	return BDNS.cmpNamesBy(self.devn.values()[0],pw.devn.values()[0],self.bdnsOrder) 
	    elif self.isSort == "SORT_BY_GRID" and pw.isSort == "SORT_BY_GRID":
        	if self.yPos == pw.yPos: 
		    return cmp(self.xPos,pw.xPos)
		else:
		    return cmp(self.yPos,pw.yPos)
	    else:
	    	raise ValueError, "No comparable sort types in: sorttype='"+str(self.isSort)+"'\n"+str(self)+"\ncompared to:\n"+str(pw)

    def __init__(self,prePath,widgetPath):
	self.panels = {} 	     # PanelFile objects for each panel. Panel-name is the key
	self.prePath = prePath
    	self.widgetPath = widgetPath.split (":")

    def addItem(self,panelName,panelGroup,devNamedata,substitutionData,panelWidgetName,panelSort=None):
#	panelInfos[panelGroup].append([signal,egu,DESC,rtype,sortID])   #[pv,plcname,plcaddr,DESC,rtyp,sortID]
	if panelName is None or len(panelName)==0:     	    	    # if column is undefined take -p argument
	    raise ValueError, "Missing pannel name"

    	if panelGroup is None or len(panelGroup)==0:
	    panelGroup="Panels DefaultGroup"

	if self.panels.has_key(panelName) is False:  
	    panelFile = Panels.PanelFile(panelName,self.widgetPath)
	    self.panels[panelName] = panelFile
    	else:
	    panelFile = self.panels[panelName]
	panelFile.addItem(panelGroup,devNamedata,substitutionData,panelWidgetName,panelSort)
    def printAll(self):
#	print self.panels
	for pn in self.panels.keys():
	    if matchRe(pn,"^.*substitutions$") is None:
		panelName = self.prePath+"/"+pn+".substitutions"
	    else:
	    	panelName = self.prePath+"/"+pn
	    try : 
   		PANEL_FILE = open(panelName,'w') 
		print "Creating file:",panelName
	    except IOError: 
    		die("can't open panel file: "+panelName)
	    p = self.panels[pn]
	    print >> PANEL_FILE,p.toSubst()
	    PANEL_FILE.close()

class epicsAlh(object):
    """
    This class hold all data to  write an alarm handler file.
    
    - Each object holds the data to describe one alarmhandler item (see __init__() )
    - The alarm group structure is stored in an static tree structure.
    
    The Collumns for Alarm definition:
    
    - BESSY ALH Group (R):  The Path to the alarm group the first element is the name of the alh file!
    - BESSY ALH Flags(S):  Optional. First the alarm Flags (CDT..) Than a list of additional Items for 
    	a CHANNEL definition inthis format: ITEM<SPACE>value e.g.

	    "T|ALIAS show this|ACKPV ackPVName ackValue"
	
	Not allowed are the Items: 'CHANNEL','INCLUDE','GROUP','END'

    Defaults:

    	Flags: ---T-
	ALIAS: name signal
	ALARMCOUNTFILTER: 2 1
	COMMAND: None or edm epicsPanel if defined in 'EPICS Panel Name' (col. U)
    """
    nodeDict={}
    @staticmethod
    def toGroupString(grStr): return substRe(grStr,' ','_').upper()
    @staticmethod
    def printFiles(prePath): 
    	for filename in epicsAlh.getRoot():
	    installFile = prePath+"/"+filename
	    try : 
		print "  Creating file",installFile+".alh"
		f = open(installFile+".alh",'w') 
		f.write(epicsAlh.printAllSubst(filename))
		f.close()
	    except IOError: 
    		die("IOError in write file: "+filename+".alh")
    @staticmethod
    def getRoot(): return epicsAlh.nodeDict.keys()
    @staticmethod
    def printAllSubst(root=None):
	"""
	Walk the tree and return the alh file as string
	"""
    	def printChannel(leaf,path,myPar): 
	    """
	    The user defined function to be called for each leaf of the tree - to print 
	    one alarm channel
	    """
	    myPar.append("CHANNEL "+epicsAlh.toGroupString(path[-1])+ " "+str(leaf)+"\n")
	    return myPar
    	def printGroup(nodeName,depth,path,myPar): 
	    """
	    The user defined function to be called for each node of the tree - to print 
	    one alarm group
	    """
	    if depth == 0: 
#	    	print "GROUP NULL "+epicsAlh.toGroupString(path[0])+"\n$ALIAS "+path[0]+"\n"
		myPar.append("GROUP NULL "+epicsAlh.toGroupString(path[0])+"\n$ALIAS "+path[0]+"\n")
	    else:
#	    	print "GROUP "+epicsAlh.toGroupString(path[depth-1])+" "+epicsAlh.toGroupString(path[depth])+"\n$ALIAS "+path[depth]+"\n"
		myPar.append("GROUP "+epicsAlh.toGroupString(path[depth-1])+" "+epicsAlh.toGroupString(path[depth])+"\n$ALIAS "+path[depth]+"\n")
	    return myPar
    	def cmpAlhItems(a,b): return a.cmpSortPar(b)
	def walkTree(nodePath,nodeDict,depth,retPar,leafFunc=None,nodeFunc=None,cmpLeafFunc=None):
#	    print "walkTree:",depth,len(nodePath),nodePath
	    for nodeName in nodeDict.keys():
	    	node = nodeDict[nodeName]
		if len(nodePath) == depth:
		    nodePath.append(nodeName)
		    retPar = nodeFunc(nodeName,depth,nodePath,retPar)
		else:
		    nodePath[depth] = nodeName
#		print "NODE:",nodeName,depth,nodePath
		if node['LEAFS']:
		    leafList = node['LEAFS']
		    if cmpLeafFunc:
			leafList=sorted(leafList,cmpLeafFunc)
		    	
		    for leaf in leafList:
			retPar = leafFunc(leaf,nodePath[:depth+1],retPar)
#			print "/".join(nodePath[:(depth+1)]), "LEAF:",str(leaf)
#			s += "/".join(nodePath[:(depth+1)])+ " LEAF: "+str(leaf)+"\n"
		if node['NODES']:
		    retPar=walkTree(nodePath,node['NODES'],depth+1,retPar,leafFunc,nodeFunc,cmpLeafFunc)
	    	del nodePath[depth]
	    return retPar
	nodePath = []
	retPar = []
	if root is None: # get all files as string
	    rootDict = epicsAlh.nodeDict
    	    return "\n".join(walkTree(nodePath,rootDict,0,retPar,printChannel,printGroup,cmpAlhItems))
	else:
	    nodePath = [root] # get single file as string
	    rootDict = epicsAlh.nodeDict[root]['NODES']
    	    return "GROUP NULL "+epicsAlh.toGroupString(root)+"\n$ALIAS "+root+"\n\n"+"\n".join(walkTree(nodePath,rootDict,1,retPar,printChannel,printGroup,cmpAlhItems))

    def __init__(self,devname,signal,nodePath,tags=None,panel=None,sort=None,lineNr=None) :
    	"""Definition of the alarm objects:
	devname:    The CHANNEL ChannelName is the EPICS PV: "devname:signal"
	signal:
	nodePath:   Group definition path, first element is the alh file name
	sort:	    Optional sort order
	panel:	    Optional panel name to be executed with the COMMAND item
	tags:	    Optional items for the channel configuration
	lineNr:     Optional debug output
   	"""
	#print "epicsAlh(",",".join((devname,signal,nodePath,tags,panel,sort,str(lineNr)))+")"
	self.devName = devname
	self.signal  = signal
	self.nodePath= nodePath
	self.flags   = "---T-"
	self.panel   = None
	self.sort    = None

	self.command = None

	if sort and len(sort)>0:
	    self.sort = sort
	if panel and len(panel)>0: 
	    self.command = "edm -x -noedit -noscrl "+panel+".edl"

	self.tags = [("ALIAS",devname+":"+signal),
	    	     ("ALARMCOUNTFILTER","2 1")
	    	    ]
	tagList = tags.split("|")
	if len(tagList)>0 and len(tagList[0])>0:
	    for tag in tagList:
    	    	try:
		    (name,value) = matchRe(tag,"([\w_]+)\s*=\s*(.*)")
		    if   name == "COMMAND": self.command = value
		    elif name == "ALIAS":   self.tags[1]=("ALIAS",value)
		    elif name == "ALARMCOUNTFILTER":   self.tags[1]=("ALARMCOUNTFILTER",value)
		    elif name in ('CHANNEL','INCLUDE','GROUP','END'): 
	    		die("ALH Flag (col. T) '"+name+"' is not supported here",lines)
		    else: 
			self.tags.append(("$"+name,value))
		except TypeError:
		    if matchRe(tag,"([CDATL])") is not None:
		    	self.setFlags(tag)
		    
	nodePath = nodePath.split("|")
	if len(nodePath) == 0: die("No ALH Group definition (col. S) for: "+devname,lineNr)
	self.putToNode(nodePath,0,epicsAlh.nodeDict)
    def putToNode(self,pathList,depth,nodeDict):
    	nodeName = pathList[depth]
#	print "putToNode",pathList[depth],depth,pathList,  len(pathList),depth
	node = {}
	try:
#	    print "try:",nodeName,nodeDict[nodeName]
	    node = nodeDict[nodeName]
	except KeyError:
#	    print "ADD NODE:",pathList[depth]
	    newNode={}
	    newNode['NODES'] = {}
	    newNode['LEAFS'] = []
	    nodeDict[nodeName]=newNode
	    node = newNode
	if len(pathList)-1 == depth: 
	    node['LEAFS'].append(self)
#	    print "CHAN:",self
	else :
	    self.putToNode(pathList,depth+1,node['NODES'])

    def __str__(self):
    	objStr = self.devName+":"+self.signal+" "+self.flags
	if len(self.tags)>0:
	    objStr += "\n"+"\n".join(map(lambda x: "$"+x[0]+" "+x[1] ,self.tags))
	if self.command: objStr += "\n$COMMAND "+self.command
	return objStr

    def __repr__(self):
	tags = "\""+substRe(self.flags,'-','')+"|"+"|".join(map(lambda x: x[0]+"="+x[1],self.tags))+"\""
	if self.panel: tags += ","+self.panel
	if self.sort:  tags += ","+self.sort
    	return "epicsAlh("+self.devName+","+self.signal+",\""+self.nodePath+"\","+tags+")"
    def setFlags(self,flags): 
    	flagList = ['-','-','-','-','-']
	for flag in list(flags):
	    if   flag == 'C': flagList[0]=flag
	    elif flag == 'D': flagList[1]=flag
	    elif flag == 'A': flagList[2]=flag
	    elif flag == 'T': flagList[3]=flag
	    elif flag == 'L': flagList[4]=flag
	    elif flag == '-': pass
	    else: raise ValueError, "Illegal Flag list: "+self.flags
	self.flags="".join(flagList)
    def cmpSortPar(self, o): 
	return cmp(self.sort,o.sort)

class epicsTemplate(object):
    """
    This class stores and print an EPICS database data for .db or .template files.
    
    * Object Data:

    - rtyp  template name or record type
    - devn  devicename as dictionary of name tag and name {'DEVN':devName}
    - field <dict> dictionary of name/value pairs

    - _init__(self,rtyp,name,fieldDict) 
    - __str__()     	# EPICS substitutions format
    - __repr__()    	# python format: tupel of (rtyp,name,{fieldDict})
    - getType(): return type name
    - getName(): return devicename
    - getFields(): return field dictionary
    - prAsSubst(): print one line for this template without header 'file ...template  {'
    - prAsRec(): treat this data as EPICS record and print one line 'record(rtyp,"NAME:SNAME")
    	ATTENTION the record needs the devicename as defined in 'devn' AND the field 'SNAME' for a PV name
    
    * Static data
    
    - typeDict={}   Dictionary of rtyp s that contain a list of objects with this rtype
    - deviceList=[] List of objects to preserve the creation order and for search functions
    
    - printAllSubst(): print all stored templates in EPICS.substitution format
    - printAllRecords(): treat all data as EPICS-records and print all stored 
    	    	templates in EPICS.db format
    - getDevice(devName): return a list of records with this devicename or None
    """
    typeDict={}
    deviceList=[]
    def __init__(self,rtyp,nameDict,fieldDict={}) :
	self.field = fieldDict
	self.devn   = nameDict
	self.rtyp   = rtyp
#	if self.field.has_key('DESCR'):
#    	    print self.devn,"\tDESCR:",self.field['DESCR']
	try:
	    l = epicsTemplate.typeDict[rtyp]
	except KeyError:
	    l = []
	    epicsTemplate.typeDict[rtyp]=l
	l.append(self)
	epicsTemplate.deviceList.append(self)
    def __str__(self) : 
	rec = "file "+self.rtyp+".template {\n"
    	rec += self.prAsSubst()
    	rec += "\n}"
	return rec
    def __repr__(self) : 
    	return ("('"+str(self.rtyp)+"','"+str(self.devn)+"',"+str(self.field)+")\n")
    def getType(self): return self.rtyp
    def getDevnTag(self): return self.devn.keys()[0]
    def getDevn(self): return self.devn.values()[0]
    def getFields(self): return self.field
    def prAsSubst(self):
    	def prItem(x):
	    val = self.field[x]
	    if isinstance(val,float):
		try:
		    (v,) = matchRe(str(val),"(.*)\.0$") 	# set numeric "n.0" values to "n" 34.0 -> "34"
		    val = v
		except TypeError:
		    pass
	    pr = x+"=\""+str(val)+"\""
	    return pr
	return "  { "+self.getDevnTag()+"=\""+self.getDevn()+"\","+",".join(filter(None,map(lambda x: prItem(x),sorted(self.field.keys()))))+"}"
    def prAsRec(self):
    	def prField(x):
	    val = self.field[x]
	    if isinstance(val,float):
		try:
		    (v,) = matchRe(str(val),"(.*)\.0$") 	# set numeric "n.0" values to "n" 34.0 -> "34"
		    val = v
		except TypeError:
		    pass
	    pr = "field("+x+",\""+str(val)+"\")"
	    return pr
	try:
	    sname = self.field['SNAME']
	except KeyError:
	    print "Warning prAsRec(): no SNAME in ",self.field
	    return ""
	del self.field['SNAME']
	return "record("+self.rtyp+",\""+self.getDevn()+":"+sname+"\") {\n\t"+"\n\t".join(filter(None,map(lambda x: prField(x),sorted(self.field.keys()))))+"\n}"

    @staticmethod
    def getDevice(devName):
    	"""
	Get list of records and template instances that have this device name OR None
	"""
    	li = []
	for item in epicsTemplate.deviceList:
	    if item.getDevn() == devName: li.append(item)
	if len(li) > 0 : return li
	return None
    @staticmethod
    def printAllSubst():
    	"""
	Treat all objects (EPICS records also) as EPICS substitutions and print in 
	EPICS.substitutions format
	"""
	prStr = ""
	for template in epicsTemplate.typeDict.keys():
	    prStr +=  "file "+template+".template {\n"
	    prStr += "\n".join( map(lambda x: x.prAsSubst(),epicsTemplate.typeDict[template]))
	    prStr += "\n}\n";
	return prStr
    @staticmethod
    def printAllRecords():
    	"""
	Treat all objects as EPICS records and print in EPICS.db format
	"""
	prStr = "\n".join( map(lambda x: x.prAsRec(),epicsTemplate.deviceList))


	return prStr

class X_Address(object):
    """
    Base class to manage PLC address names
    """
    mbbiTagIndex=0
    mbboTagIndex=0
    inTagPrefix  = "inBits"
    outTagPrefix = "outBits"
    mbbiDirectLinks = {}  # (OPC|Link,signalName) for all mbbiDirect records
    mbboDirectLinks  = {} # (OPC|Link,signalName) for all mbboDirect records

    def __init__(self) :
    	self.link = None
	self.softLinkTag = None

    def getLink(self):
    	"""
	Return the link to the OPC-object or soft link to the mbb_Direct record
	"""
    	return self.link

    def getSoftLinkTag(self):
    	"""
	Return the tag used in mbb_DirectTags dictionary or None if it has direct 
	access to the OPC server
	"""
	return self.softLinkTag

    @staticmethod
    def setupTemplates(device_name,dtypHw):
	"""
	Create epicsTemplate objects for all mbb_Direct records as indicated in mbb_DirectLinks dictionary
	"""
	for tag in X_Address.mbbiDirectLinks.keys():
	    (link,signalName) = X_Address.mbbiDirectLinks[tag]
	    epicsTemplate('longin', {'DEVN':device_name},{'SNAME':signalName,
    	    	      'DESC': tag[len(tag)-20:len(tag)],
    	    	      'DTYP': dtypHw,
    	    	      'SCAN': "I/O Intr",
#    	    	      'NOBT': "16",
    	    	      'INP':  link})
	for tag in X_Address.mbboDirectLinks.keys():
	    (link,signalName) = X_Address.mbboDirectLinks[tag]
	    epicsTemplate('mbboDirect', {'DEVN':device_name},{'SNAME':signalName,
    	              'DESC': tag[len(tag)-26:len(tag)],
    	              'DTYP': dtypHw,
    	              'NOBT': "16",
    	              'OUT':  link})
    def procInOut(self,rtype):
	if matchRe(rtype,".*o(ut)?(Direct)?") :
    	    return "OUT"
	else:
    	    return "INP"
 
class PLC_Address(X_Address):
    """
    This class manages a SPS-Symbolname address used in method getOpcLink()
    """
    def __init__(self,PLCLink,rtype,bits,deviceName,lines) :
	X_Address.__init__(self)
	if bits == '':
	    self.link = "@"+PLCLink
	else:
 	    self.softLinkTag = PLCLink
 	    (nobt,shft) = getShiftParam(bits)
 	    if self.procInOut(rtype) == 'INP':
 		if not X_Address.mbbiDirectLinks.has_key(self.softLinkTag) :
 		    X_Address.mbbiDirectLinks[self.softLinkTag] = ("@"+PLCLink,X_Address.inTagPrefix+str(X_Address.mbbiTagIndex))
		    X_Address.mbbiTagIndex += 1
 		(hwLink,sTag) = X_Address.mbbiDirectLinks[self.softLinkTag]
		self.link = deviceName+":"+sTag+" CPP MS"
 	    elif self.procInOut(rtype) == 'OUT':
 		if not X_Address.mbboDirectLinks.has_key(self.softLinkTag) :
 		    X_Address.mbboDirectLinks[self.softLinkTag] = ("@"+PLCLink,X_Address.outTagPrefix+str(X_Address.mbboTagIndex))
		    X_Address.mbboTagIndex += 1
 		(hwLink,sTag) = X_Address.mbboDirectLinks[self.softLinkTag]
    	    	if rtype in('mbbo','mbbi'):
 		    self.link = deviceName+":%s PP NMS" % (sTag,) 
		else:	# bi,bo
		    self.link = deviceName+":%s.B%X PP NMS" % (sTag,shft) 
 	    else :
 		die("Unknown output type for record: "+rType+" in Line: ",lines)

class DB_Address(X_Address):
    """
    This class manages a Siemens PLC adrress. Not used now in method getOpcLink()
    """
    def __init__(self,plcAddr,rtype,opc_name,deviceName,lines=None) :
	"""
	Align byte addresses to word addresses. Due to strange PLC behaviour, the 
	endianess of bitfields differs from WORDS, so	address allign swaps endianes  

	- Used for bi/bo are mapped to mbb_Direct 
	- Means odd Bytes: byte -= 1, other bit += 8
	
	Parse 'plcAddr' as something of 'DBn,mo.p' or 'DBn,mo' e.g. 'DB5,X32.4' with:
	
	- n = DB number
	- m = datatype X=byte, W=word
	- o = byte number
	- p = bit number
	"""
	X_Address.__init__(self)
    	typ = None
    	byte =None
    	bit = None
    	db  = None
	if  opc_name is None: die("Missing -m plc-name option")
	if  rtype is None: die("Missing record type (col N) in Line: "+str(lines))

	l = matchRe(plcAddr,".*DB(\d+),(\w)(\d+)\.(\d+)")  # S7:[S7-Verbindung_1]DB2,X0.0

	if l is not None:
    	    (db,typ,byte,bit) = l

	    if typ == 'X':
		byte = int(byte)
		bit  = int(bit)
		db   = int(db)
		if byte%2 != 0:	# align to word boundaries 
		    byte -= 1
		else:
		    bit += 8
	    else:
		die("unknown datatype '"+typ+"' in: '"+plcAddr+"'",lines)
	else:
    	    #print "plcAddr ", plcAddr
	    l = matchRe(plcAddr,".*DB(\d+),(\w)(\d+)")  # S7:[S7-Verbindung_1]DB2,X0.0

	    if l is not None:
    		(db,typ,byte) = l
		byte = int(byte)
		db   = int(db)

		if self.typ != 'W':
	    	    die("unknown datatype '"+self.typ+"' in: '"+plcAddr+"'",lines)

	    else:
		die("unknown datatype in: '"+plcAddr+"'",lines)
	
	self.softLinkTag = str(db)+"_"+str(byte)

	if self.procInOut(rtype) == 'INP':
	    if not mbbiDirectLinks.has_key(self.softLinkTag) :
	    	mbbiDirectLinks[self.softLinkTag] = ("@"+opc_name+"DB"+str(db)+"W"+str(byte),X_Address.inTagPrefix+self.softLinkTag)
 	    (hwLink,sTag) = mbbiDirectLinks[self.softLinkTag]
	    self.link = deviceName+"%s.B%X CPP MS" % (sTag,bit) 
	elif self.procInOut(rtype) == 'OUT':
	    if not mbboDirectLinks.has_key(self.softLinkTag) :
	    	mbboDirectLinks[self.softLinkTag] = ("@"+opc_name+"DB"+str(db)+"W"+str(byte),X_Address.outTagPrefix+self.softLinkTag)
 	    (hwLink,sTag) = mbboDirectLinks[self.softLinkTag]
	    self.link = deviceName+"%s.B%X PP NMS" % (sTag,bit) 
    	else :
	    die("Unknown output type for record: "+rType+" in Line: "+str(lines))
		