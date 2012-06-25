"""
This module is a wild collection of functions and classes to handle EPICS data:
===============================================================================

def die(errMsg,line=None):
def hasIndex(lst,idx):
def matchRe(matchStr,reStr) :
def substRe(matchStr,matchRe,replaceStr):
def substituteVariables(sString,substDict):
def parseStCmd(stCmdLine):
def parseDb(content):
def printDb(recList, printMode = "TABLE"):
def filterDb(recList,options):
def parseParam(fieldPar):
def printTable(rT,header=None,sortIdx=None) :

class Panels(object):
    Manage store and print of a group of panels. This class creates panel.substitutions information
    class PanelFile(object):
    class PanelWidget(object): Subclass to manage one widget

class epicsAlh(object):
    Hold all data to  write an alarm handler file.

class epicsTemplate(object):
    Stores and print an EPICS database data for .db or .template files.
"""
from optparse import OptionParser
import sys
import os
import re
import math
import csv
import BDNS
import os.path
import pyparsing as pp
import listOfDict as lod
import pprint

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

def matchRe(matchStr,reStr,flags=0) :
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
    regx = re.compile(reStr,flags)
    m = regx.match(matchStr)
    if m is not None :
        return m.groups()
    else:
        return None

def searchRe(searchStr,reStr,flags=0) :
    """ serarch, means regExp has to be found somewhere in searchStr, else return None
    """
    regx = re.compile(reStr,flags)
    return regx.search(searchStr)

def substRe(matchStr,matchRe,replaceStr,flags=0):
    """
    Return substitute 'matchRe' replaced by 'replaceStr' from 'matchStr'
    """
    regx = re.compile(matchRe,flags)
    return regx.sub(replaceStr,matchStr)

    """
    Substitute all variables of type '$(VAR)' with the value of substDict,
    if there is an entry for the tag 'VAR'.
    """
def substituteVariables(sString,substDict):
    for name in substDict.keys():
    	sString = sString.replace(r"$("+name+")",substDict[name])
    return sString

def parseStCmd(stCmdLine):
    """
    Parse a st.cmd file by line. Return array ofthe command and the parsed parameters

    * Example:

    for line in IN_FILE:
        parsedLine = epicsUtils.parseStCmd(line)
        if len(parsedLine)<1: continue
        cmd = parsedLine[0]
        if cmd == "epicsEnvSet":
            envDict[parsedLine[1]]=parsedLine[2]
        if cmd == "putenv":
            (name,value)=parsedLine[1].split("=")
            envDict[name]=value
        if cmd == "dbLoadDatabase":
            dbdFile += substituteVariables(substRe(parsedLine[1],"dbd/",""),envDict)
        if cmd == "dbLoadRecords":
            dbFile = substituteVariables(substRe(parsedLine[1],"db/",""),envDict)
    """
    cmd     = pp.Word(pp.alphanums)
    qString = pp.dblQuotedString.setParseAction(pp.removeQuotes) # double quoted String, quotes removed
    function =pp.Word(pp.alphanums)+pp.Suppress(pp.Word("("))+pp.Optional(pp.delimitedList(pp.Word(pp.alphanums),","))+ pp.Suppress(pp.Word(")"))
    function.setName("function")
    arg     = qString | function | pp.Word(pp.alphanums+"-_|<>/.${}=><")
    argGrp  = pp.delimitedList(arg,",")
    command = (cmd + pp.Suppress("(")+ argGrp + pp.Suppress(")")) | \
              (cmd + argGrp) | \
              (cmd + pp.OneOrMore(arg) )| \
              pp.Empty()
    comment = pp.Suppress(pp.pythonStyleComment)
    line =  comment | (command + pp.Optional(comment))
    return line.parseString(stCmdLine)

def parseDb(content):
    """
    Parse an EPICS.db file.

    Return a list of EPICS record dictionaries. Each record dict contains the EPICS-field
    and value pairs and additional keys for:

    - recordname
    - alias
    - RTYP
    - info {INFOKEY:INFOVALUE,}
    """
    recordName= pp.ZeroOrMore(pp.Suppress(pp.Word('"')))+pp.Word(pp.alphanums+"_-+:[]<>;")+pp.ZeroOrMore(pp.Suppress(pp.Word('"')))
    qString   = pp.dblQuotedString.setParseAction(pp.removeQuotes) # double quoted String, quotes removed

    comment  = pp.Suppress(pp.pythonStyleComment)
    alias    = pp.Group(pp.Keyword("alias") + pp.Suppress(pp.Word("(")) + recordName +  pp.Suppress(pp.Word(",")) + recordName+ pp.Suppress(pp.Word(")")) )
    field    = pp.Group((pp.Keyword("field")^pp.Keyword("info")) + pp.Suppress(pp.Word("(")) + pp.Word(pp.alphanums) + pp.Suppress(pp.Word(",")) + qString + pp.Suppress(pp.Word(")")) + pp.ZeroOrMore(comment) ^\
        pp.Keyword("alias") + pp.Suppress(pp.Word("(")) + recordName +  pp.Suppress(pp.Word(")")) + pp.ZeroOrMore(comment)\
        )
    record   = pp.Group(pp.Keyword("record") + pp.Suppress(pp.Word("(")) + pp.Word(pp.alphanums) + pp.Suppress(pp.Word(",")) + recordName + pp.Suppress(pp.Word(")")) + pp.ZeroOrMore(comment) +\
                pp.Suppress(pp.Word("{")) + pp.ZeroOrMore(comment) + pp.Group(pp.ZeroOrMore(field)) + pp.Suppress(pp.Word("}")) )
    epicsDb  = pp.OneOrMore(comment ^ alias ^ record)

    recordList = []
    for pGroup in epicsDb.parseString(content):
#        print "pGroup:",pGroup
        if pGroup[0] == 'record':
            rec = {'RTYP':pGroup[1],'recordname':pGroup[2]}
            if len(pGroup) <= 3:
                    continue
            for fields in pGroup[3]:
                if fields[0] == 'field':     # ['field','fieldType','fieldValue']
                    rec[fields[1]]=fields[2]
                if fields[0] == 'alias':
                    rec['alias'] = fields[1]
                if fields[0] == 'info':
                    if not rec.has_key('info'):
                        rec['info'] = {}
                    rec['info'][fields[1]] = fields[2]
            recordList.append(rec)
    return recordList

def printDb(recList, printMode = "TABLE"):
    """ Print a list of record dictionaries, pritmodes: 'TABLEW'
    """
    if printMode == 'DB':
        for rec in recList:
            print "record("+rec['RTYP']+","+rec['recordname']+") {"
            for f in rec.keys():
                if f not in ('RTYP','recordname'):
                    print  '    field(%4s,"%s")' %(f,rec[f])
            print "}"
    else:
        pprint.pprint(recList)
        keys = lod.getAllKeys(recList).keys()
        keys.remove("recordname")
        keys.remove('RTYP')
        keys = sorted(keys)
        order = ['recordname','RTYP']+keys
	table = lod.orderToTable(recList,order)
        if printMode == 'TABLE':
            printTable(table,order)
        else:
            pprint.pprint(recList)

def filterDb(recList,options):
    """
    Filter a list of record-dicionaries by the filter options dictionary. All match
    operations are regular expressions

    TRIGGER Options:  defines what fields, records etc are of interest. The values of
    the trigger options  are processed as regular expressions and concatenated with
    logical AND, means all triggers have to match.
    'tt', 'it' <recType>:   match/ignore record <recType>
    'tr', 'ir' <recName>:   match/ignore record <recName>
    'tf', 'if' <fieldType>: match/ignore field <fieldType>
    'tv', 'iv' <value>:     match/ignore field contains <value>

    Field filter OPTIONS:   defines the filtered fields to return. Default is the field/s
                            defined with '-tf' option or all fields if '-tf' isn't set:
        'pf' 'ipf <fieldType> print/ignore this field/s

    'i' <not NOne>          Case insensitive option

    """
    # default if NO print options are set: the trigger options!
    if options['tt']:
        (recList,forget)=lod.filterRegExp(recList,'RTYP',options['tt'],options['i'])
    if options['it']:
        (forget,recList)=lod.filterRegExp(recList,'RTYP',options['it'],options['i'])
    if options['tr']:
        (recList,forget)=lod.filterRegExp(recList,'recordname',options['tr'],options['i'])
    if options['ir']:
        (forget,recList)=lod.filterRegExp(recList,'recordname',options['ir'],options['i'])

    traceKeys   = lod.getAllKeys(recList).keys()
    if options['tf']:
        if options['tf']:
            traceKeys = [x for x in traceKeys if searchRe(x,options['tf'],options['i']) is not None]
    if options['if']:
        traceKeys = [x for x in traceKeys if searchRe(x,options['if'],options['i']) is None]
    (recList,forget) = lod.filterKeys(recList,traceKeys)

    if options['tv']:
        (recList,forget) = lod.filterAllValuesRegExp(recList,options['tv'],options['i'])
    if options['iv']:
        (forget,recList) = lod.filterAllValuesRegExp(redList,options['iv'],options['i'])


    printKeys   = lod.getAllKeys(recList).keys()
    prFieldName = "recordname|RTYP"
    if not options['pf'] and options['tf']:
        options['pf'] = options['tf']
    if options['pf']:
        prFieldName = "|".join((prFieldName,options['pf']))
        printKeys = [x for x in printKeys if searchRe(x,prFieldName) is not None]
    if options['ipf']:
        printKeys = [x for x in printKeys if searchRe(x,options['ipf']) is None]
    (recList,forget) = lod.filterOutKeys(recList,printKeys)
    return recList

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
		w = matchRe(val,'^"([^"]*)"$')
		if w: val = w[0]
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

def getOpcLink(PLCLink,rtyp,bits,device_name,opc_name,lines,fileName):
    """
    Create an OPC Link for option '-c opc', CAN or VME links are not supported!

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
    elif rtyp in ('bi','mbbi','bo','mbbo'):     # access via mbb_Direct from OPC Server Byte/Word data
        (nobt,shft) = getShiftParam(bits)
        if rtyp in ('bi','mbbi','mbbo'):        # access via mbb_Direct to OPC Server Byte/Word data
            fields['SHFT']  = shft
            fields['NOBT']  = nobt
            fields['DTYP'] = "Raw Soft Channel"

        dbAddr = PLC_Address(PLCLink,rtyp,bits,opc_name,device_name,lines)
        if rtyp in ('bi','mbbi'):
            fields['INP'] = dbAddr.getLink()
        else:
            fields['OUT'] = dbAddr.getLink()
    return (fields)


def getHwLink(rtyp,port,canId,cardNr,chan,name,fileName,iocTag,lineNr=None):
    """
    Create an Hardware Link, CAN or VME. For option -c intNr or -c not set. For -c opc 
    the function getOpcLink() ist called!!
    
    * The argument canId may be an integer for CAN or a string for the DTYP of the VME device. 

    * For CAN links and binary records there is support to create mbbiDirect records to read
    the data and distribute it to the binary records.
    """
    fields = {}
#    print "getHwLink(",rtyp,port,canId,cardNr,chan,name,fileName,lineNr,")"
    try:
        int(canId)      # CAN link
        if rtyp in ('ai','longin','mbbiDirect'):
            fields['DTYP'] = "lowcal"
            fields['INP'] = createAdaCanLink(port,canId,cardNr,chan)
        elif rtyp in ['ao','longout','mbboDirect']:
            fields['DTYP'] = "lowcal"
            fields['OUT'] = createAdaCanLink(port,canId,cardNr,chan)
        elif rtyp in ('bi','mbbi','bo','mbbo'): # access via mbb_Direct to CAN
            hwDeviceName = getEcName(port,canId,cardNr,iocTag)
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
	    hwDeviceObj = epicsTemplate.getDevice(hwDeviceName)
	    hasPv = None
	    for dev in hwDeviceObj:
	    	if dev.field['SNAME'] == hwSignal:
		    hasPv=1
		    break
	    
	    if not hasPv:
		f = {'DESC'  :'Access Port:'+str(port)+", Id:"+str(canId)+", card:"+str(cardNr),
                     'NOBT'  :'16',
                     'DTYP'  :'lowcal',
                     'SNAME' : hwSignal,
                     linkName: createAdaCanLink(port,canId,cardNr,mux)
                    }
		if linkName == 'INP':
		    f['SCAN'] = "1 second"
                epicsTemplate(recType,{'DEVN':hwDeviceName},f)

            (nobt,shft) = getShiftParam(chan)
            fields['SHFT']  = shft
            if rtyp  == 'bi':
                fields[linkName]= "%s:%s.B%X CPP MS" % (hwDeviceName,hwSignal,shft)
            if rtyp  == 'bo':
                fields[linkName]= "%s:%s.B%X PP NMS" % (hwDeviceName,hwSignal,shft)
            else:   # mbbi, mbbo
    	    	if rtyp  == 'mbbi':
    	    	    fields[linkName]= "%s:%s CPP MS" % (hwDeviceName,hwSignal)
    	    	if rtyp  == 'mbbo':
    	    	    fields[linkName]= "%s:%s PP NMS" % (hwDeviceName,hwSignal)
                fields['NOBT']= nobt
                fields['SHFT']= shft
    except ValueError:                          # VME link
        if len(canId) > 0:
            fields['DTYP'] = canId
            (nobt,shft) = getShiftParam(chan)
            link = "#C%dS%d"% (int(cardNr),int(shft))
            if nobt is not None:
                fields['NOBT'] = nobt
                fields['SHFT'] = shft

            if rtyp in ('bi','mbbi'):   # access direct to card
                fields['IN'] = link
            elif rtyp in ('bo','mbbo',):        # access direct to card
                fields['OUT'] = link
            if lineNr==54:
                print rtyp, link,fields['OUT']

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

    Return "@f s 5 PORT OUTCAN INCAN MUX 10 1F8 0" % (int(port),outCan,inCan,mux)
    """
    (outCan,inCan,mux) = adaCanMux(id,card,chan)
    return "@f s 5 %X %s %s %s 10 1F8 0" % (int(port),outCan,inCan,mux)

class Panels(object):
    """
    Manage store and print of a group of panels. This class creates panel.substitutions information
    to be expanded to a panel with the CreatePanel.pl script of (bii_scripts:http://www-csr.bessy.de/control/bii_scripts/html/scripts/CreatePanel.html)

    It supports to create several panel files and groups of widgets within a panel

    Spreadsheet collumns
    --------------------

    * EPICS Panel Name Prefix (Col. W): The Panel Name, without the ending .edl

    * EPICS Panel Group (Col. X):  The Group within a panel. Omit this will put all signals to a default group.

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
#           print "PanelFile:",panelName,widgetPath
        def __str__(self):
            return "PanelGroup: '"+self.panelName+"'\nGROUPS:\n"+str(self.groups)+"\nITEMS:\n"+str(self.items)
        def __repr__(self):
            return self.__str__()
        def addGroup(self,group):
#           print "PanelFile.addGroup:",group
            self.groups.append(group)
            self.items[group] = []
        def addItem(self, group,devNamedata,itemDict,panelWidgetName,sort=None):
#           print "PanelFile.addItem:",group,itemDict,panelWidgetName,sort
            if self.items.has_key(group)        is False:
                self.addGroup(group)
            self.items[group].append(Panels.PanelWidget(devNamedata,itemDict,panelWidgetName,self.order,sort))
        def getWidgetType(self,item):
            if item.widgetName:
                return item.widgetName
	    else:
	    	die("No Widget defined for Panel:"+item.__repr__())
#            elif item.type in ['ai','bi','mbbi','calc']:
#                    return "anyVal"
#            else:   return item.type
        def checkWidgetPath(self,widget):
            fname = widget+".edl"
#           print "checkWidgetPath",widget,fname,"\n\t",self.widgetPath
            for path in self.widgetPath:
                if os.path.isfile(path+"/"+fname):
#                   print "\t",path+"/"+fname
                    return True
            return False
        def toSubst(self):
            """
            Print all panel info in substitution format to be processed by CreatePanel.pl. Sort algorythms
            are defined by the panels sort column (see above):
            """
            retStr = "" # hold the substitutions string

            def cmpWidget(a,b): return a.cmpWidget(b)
#           print "Panels.PanelFile.toSubst() of Groups:",self.groups,"\nItems:",self.items
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
                wLst = []       # hold consecutive widgets of the same type
#                print "Group:",pGroup,itemList
                actualWidgetType = self.getWidgetType(itemList[0])
                wLst.append(itemList[0])
                for item in itemList[1:]:
		    wType = self.getWidgetType(item)
#                    print actualWidgetType,wType
		    if actualWidgetType != wType:
#                       print "TypeChange: ",actualWidgetType, "->", wType
                        retStr += "file "+actualWidgetType+".edl {\n"+"\n".join(map(lambda x: str(x),wLst))+"\n}\n"
                        actualWidgetType = wType
                        wLst = []
                    wLst.append(item)
#                   print actualWidgetType,wType,"\t",item.type,str(item)
                if len(wLst)>0:
                    retStr += "file "+actualWidgetType+".edl {\n"+"\n".join(map(lambda x: str(x),wLst))+"}\n"

                retStr+"}\n"
                if groupWidget and self.checkWidgetPath(groupWidget+"Footer"):
                    retStr += "file "+groupWidget+"Footer.edl  {\n  {}\n}\n"
            return retStr

    class PanelWidget(object):
        """
        Subclass to manage one widget
        """
        def __init__(self,devNamedata,item,panelWidgetName,order,sort=None):
#           print "PanelWidget("+panelWidgetName+","+str(devNamedata)+","+str(item)+","+sort+")"

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
        self.panels = {}             # PanelFile objects for each panel. Panel-name is the key
        self.prePath = prePath
        self.widgetPath = widgetPath.split (":")

    def addItem(self,panelName,panelGroup,devNamedata,substitutionData,panelWidgetName,panelSort=None):
#       panelInfos[panelGroup].append([signal,egu,DESC,rtype,sortID])   #[pv,plcname,plcaddr,DESC,rtyp,sortID]
        if panelName is None or len(panelName)==0:                  # if column is undefined take -p argument
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
#       print self.panels
        for pn in self.panels.keys():
            if matchRe(pn,"^.*substitutions$") is None:
                panelName = self.prePath+"/"+pn+".substitutions"
            else:
                panelName = self.prePath+"/"+pn
            try :
                PANEL_FILE = open(panelName,'w')
#                print "Creating file:",panelName
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

    - BESSY ALH Group (col. Q): The Path to the alarm group the first element is the name of the alh file!
    - BESSY ALH Flags(col. R):  Optional. First the alarm Flags (CDT..) Than a list of additional Items for
        a CHANNEL definition in this format: ITEM<SPACE>value e.g.

            "T|ALIAS show this|ACKPV ackPVName ackValue"

        Not allowed are the Items: 'CHANNEL','INCLUDE','GROUP','END'

    Defaults:

        Flags: ---T-
        ALIAS: name signal
        ALARMCOUNTFILTER: 2 1
        COMMAND: None or edm epicsPanel if defined in 'EPICS Panel Name' (col. U)

    - ALH Sort (col. S):   An optional sort number to define the order within a group
    """
    nodeDict={}
    @staticmethod
    def toGroupString(grStr): return substRe(grStr,' ','_').upper()
    @staticmethod
    def printFiles(prePath):
        for filename in epicsAlh.getRoot():
            installFile = prePath+"/"+filename
            try :
#                print "  Creating file",installFile+".alh"
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
#               print "GROUP NULL "+epicsAlh.toGroupString(path[0])+"\n$ALIAS "+path[0]+"\n"
                myPar.append("GROUP NULL "+epicsAlh.toGroupString(path[0])+"\n$ALIAS "+path[0]+"\n")
            else:
#               print "GROUP "+epicsAlh.toGroupString(path[depth-1])+" "+epicsAlh.toGroupString(path[depth])+"\n$ALIAS "+path[depth]+"\n"
                myPar.append("GROUP "+epicsAlh.toGroupString(path[depth-1])+" "+epicsAlh.toGroupString(path[depth])+"\n$ALIAS "+path[depth]+"\n")
            return myPar
        def cmpAlhItems(a,b): return a.cmpSortPar(b)
        def walkTree(nodePath,nodeDict,depth,retPar,leafFunc=None,nodeFunc=None,cmpLeafFunc=None):
#           print "walkTree:",depth,len(nodePath),nodePath
            for nodeName in nodeDict.keys():
                node = nodeDict[nodeName]
                if len(nodePath) == depth:
                    nodePath.append(nodeName)
                    retPar = nodeFunc(nodeName,depth,nodePath,retPar)
                else:
                    nodePath[depth] = nodeName
#               print "NODE:",nodeName,depth,nodePath
                if node['LEAFS']:
                    leafList = node['LEAFS']
                    if cmpLeafFunc:
                        leafList=sorted(leafList,cmpLeafFunc)

                    for leaf in leafList:
                        retPar = leafFunc(leaf,nodePath[:depth+1],retPar)
#                       print "/".join(nodePath[:(depth+1)]), "LEAF:",str(leaf)
#                       s += "/".join(nodePath[:(depth+1)])+ " LEAF: "+str(leaf)+"\n"
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

#epicsUtils.epicsAlh(devName,alhSig,devObj.alhGroup,devObj.alhFlags,devObj.panelName,devObj.alhSort,lines)
#epicsUtils.epicsAlh(devName,alhSig,devObj,lines)
#    def __init__(self,devname,signal,nodePath,tags=None,devObj.panelName=None,sort=None,lineNr=None) :
    def __init__(self,devname,signal,devObj,lineNr=None) :
        """Definition of the alarm objects:
        devname:    The CHANNEL ChannelName is the EPICS PV: "devname:signal"
        signal:
        devObj:     class csvData object with a line of parameters of the spreadshet 
	    alhGroup:   Group definition path, first element is the alh file name
            sort:       Optional sort order
            panelName:  Optional panelName name to be executed with the COMMAND item
            alhFlags:   Optional items for the channel configuration
            lineNr:     Optional debug output
        """
        #print "epicsAlh(",",".join((devname,signal,nodePath,tags,devObj.panelName,sort,str(lineNr)))+")"
        self.devName = devname
        self.signal  = signal
        self.nodePath= devObj.alhGroup
        self.flags   = "---T-"
        self.panel   = None
        self.sort    = None
    	self.desc    = devObj.DESC
        self.command = None

        if devObj.alhSort and len(devObj.alhSort)>0:
            self.sort = devObj.alhSort
        if devObj.panelName and len(devObj.panelName)>0:
            self.panel   = devObj.panelName
	    self.command = "edm -x -noedit -noscrl "+devObj.panelName+".edl"
	else:
	    egu = " "
	    if len(devObj.egu) > 0: egu = devObj.egu
	    self.command = "edm -x -noedit -noscrl -m \"PV="+devname+":"+signal+",DESC="+devObj.DESC+",EGU="+egu+"\" alhVal.edl"

        self.tags = [("ALIAS",devname+": "+self.desc),
                     ("ALARMCOUNTFILTER","2 1")
                    ]
        tagList = devObj.alhFlags.split("|")
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
                    if matchRe(tag,"([CDATL-])") is not None:
                        self.setFlags(tag)

        self.nodePath = self.nodePath.split("|")
        if len(self.nodePath) == 0: die("No ALH Group definition (col. S) for: "+devname,lineNr)
        self.putToNode(self.nodePath,0,epicsAlh.nodeDict)
    def putToNode(self,pathList,depth,nodeDict):
        nodeName = pathList[depth]
#       print "putToNode",pathList[depth],depth,pathList,  len(pathList),depth
        node = {}
        try:
#           print "try:",nodeName,nodeDict[nodeName]
            node = nodeDict[nodeName]
        except KeyError:
#           print "ADD NODE:",pathList[depth]
            newNode={}
            newNode['NODES'] = {}
            newNode['LEAFS'] = []
            nodeDict[nodeName]=newNode
            node = newNode
        if len(pathList)-1 == depth:
            node['LEAFS'].append(self)
#           print "CHAN:",self
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
    - __str__()         # EPICS substitutions format
    - __repr__()        # python format: tupel of (rtyp,name,{fieldDict})
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
#       if self.field.has_key('DESCR'):
#           print self.devn,"\tDESCR:",self.field['DESCR']
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
        return ("epicsTemplate('"+str(self.rtyp)+"',"+str(self.devn)+","+str(self.field)+")\n")
    def getType(self): return self.rtyp
    def getDevnTag(self): return self.devn.keys()[0]
    def getDevn(self): return self.devn.values()[0]
    def getFields(self): return self.field
    def prAsSubst(self):
        def prItem(x):
            val = self.field[x]
            if isinstance(val,float):
                try:
                    (v,) = matchRe(str(val),"(.*)\.0$")         # set numeric "n.0" values to "n" 34.0 -> "34"
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
                    (v,) = matchRe(str(val),"(.*)\.0$")         # set numeric "n.0" values to "n" 34.0 -> "34"
                    val = v
                except TypeError:
                    pass
            pr = "field("+x+",\""+str(val)+"\")"
            return pr
        try:
            sname = self.field['SNAME']
        except KeyError:
            raise ValueError("Warning prAsRec(): no SNAME in "+str(self.field))
        del self.field['SNAME']
        return "record("+self.rtyp+",\""+self.getDevn()+":"+sname+"\") {\n\t"+"\n\t".join(filter(None,map(lambda x: prField(x),sorted(self.field.keys()))))+"\n}"

    @staticmethod
    def getDevice(devName):
        """
        Get list of records and template instances that have this device name - may be empty for not found
        """
        li = []
        for item in epicsTemplate.deviceList:
            if item.getDevn() == devName: li.append(item)
        return li

    @staticmethod
    def getPV(devName,signalName,signalField='SNAME'):
        """
        Search object list for devName AND field SNAME=signalName (signalField tag may be set as third parameter)
	Return list of matching objects - empty list means not found
        """
        #print "getPV(",devName,signalName,signalField,")"
	li= []
        for item in epicsTemplate.getDevice(devName):
            if (not signalField) or (not item.field.has_key(signalField)) or (item.field[signalField] != signalName):
	    	continue
	    li.append(item)
	return li

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

