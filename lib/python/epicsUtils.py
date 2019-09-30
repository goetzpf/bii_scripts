# -*- coding: utf-8 -*-

# Copyright 2015 Helmholtz-Zentrum Berlin für Materialien und Energie GmbH
# <https://www.helmholtz-berlin.de>
#
# Author: Bernhard Kuner <bernhard.kuner@helmholtz-berlin.de>
# Contributions by:
#         Thomas Birke <Thomas.Birke@helmholtz-berlin.de>
#         Benjamin Franksen <Benjamin.Franksen@helmholtz-berlin.de>
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

version = "1"
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
    Manage store and print of a group of panels. This class creates 
    panel.substitutions information
    class PanelFile(object):
    class PanelWidget(object): Subclass to manage one widget

class epicsAlh(object):
    Hold all data to  write an alarm handler file.

class epicsTemplate(object):
    Stores and print an EPICS database data for one .db or .substitutions file.

def updateStruct(a,b): Merge two data structures for st.cmd defintion.
"""
from optparse import OptionParser
import sys
import os
import re
import math
import csv
import os.path
import listOfDict as lod
import pprint
try:
    import BDNS
    BDNS_EXIST = 1      
except ImportError, e:
    BDNS_EXIST = None

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
    if m:
        return m.groups()
    else:
        return None

def searchRe(searchStr,reStr,flags=0) :
    """ serarch, means regExp has to be found somewhere in searchStr, else return None
    """
    regx = re.compile(reStr,flags)
    m = regx.search(searchStr)
    if m:
        return m.groups()
    else:
        return None

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
        sString = sString.replace(r"$("+name+")",str(substDict[name]))
    return sString

def printDb(recList, printMode = "TABLE"):
    """ Print a list of record dictionaries, printmodes: 'TABLE', 'DB'
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

    Field filter:   defines the filtered fields to return. Default is the field/s
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
            sys.stderr.write( str(x) )
            return 0
    for row in rTable:
        fLen = map(lambda x: length(x),row)
        formatMax = map(lambda x: choose(x),zip(formatMax,fLen))
    #print "rT",formatMax
    sys.stderr.write( " | ".join(map(lambda x:("%%%ds"%x[0])%x[1] ,zip(formatMax,header)) )+"\n" )
    sys.stderr.write( "-+-".join(map(lambda x: x*'-' ,formatMax) )+"\n" )
    for line in rTable:
        sys.stderr.write( " | ".join(map(lambda x:("%%%ds"%x[0])%x[1] ,zip(formatMax,line)) )+"\n" )

class Panels(object):
    """
    Manage store and print of a group of panels. This class creates 
    panel.substitutions information to be expanded to a panel with the 
    CreatePanel.pl script of (bii_scripts:http://www-csr.bessy.de/control/bii_scripts/html/scripts/CreatePanel.html)

    It supports to create several panel files and groups of widgets within a panel

    Spreadsheet collumns
    --------------------

    * EPICS Panel Name Prefix (Col. W): The Panel Name, without the ending .edl

    * EPICS Panel Group (Col. X):  The Group within a panel. Omit this will put 
      all signals to a default group.

      Each group will be shown with a hedline by a widget with the same name or
      text.edl, also with GRID definition!

    * EPICS Panel Sort/Grid (Col. Y):

      - Nothing: Sort all signals by device- and signal name
      - Unique number: Sort within a group by number.To get the order as defined 
        in the spreadsheet just put an incrementet number here
      - (GRID="x,y") or (GRID="x,y",SPAN="n"or (XY="n,m"): Just pass the parameter
        to the panel.substitutions file to be interpreted by CreatePanel.pl
        ATTENTION: the Groupname will get the Y position of Ymin-1, so there has to
        be a free gap of 1 line in grid-Y numbering!
      - SORT=n|otherParameters|...: Sort by number, but pass other arguments to the panel

    """
    class PanelFile(object):
        """
        Store all informations to hold a panel group
        """
        def __init__(self,panelName,widgetPath) :
            self.order = None
            if BDNS_EXIST:
                self.order = BDNS.mkOrder("MEMBER,DOMAIN,SUBDOMNUMBER,INDEX,SUBINDEX")
            self.panelName = panelName    # panel name
            self.groups = []    # [groupName_1, groupName_2,...] to get the order of groups
            self.items  = {}    # self.items[groupName_n] = [item1, item2,...] the items of a group
            self.widgetPath = widgetPath
#            print "PanelFile:",panelName,widgetPath
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
            Print all panel info in substitution format to be processed by CreatePanel.pl.
            Sort algorythms are defined by the panels sort column (see above):
            """
            retStr = "" # hold the substitutions string

            def cmpWidget(a,b): return a.cmpWidget(b)
#            print "Panels.PanelFile.toSubst() of Groups:",self.groups,"\nItems:",self.items
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
#                        print "groupWidget =", pGroup
                        groupWidget = pGroup
                        if self.checkWidgetPath(groupWidget+"Header"):
                            retStr += "file "+groupWidget+"Header.template  {\n  {"+gridHead+"}\n}\n"
                        else:
                            retStr += "file text.template  {\n  { TEXT=\""+pGroup+"\",WIDTH=\"400\",COLOR=\"28\",TXTCOLOR=\"0\""+gridHead+"}\n}\n"

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
                        retStr += "file "+actualWidgetType+".template {\n"+"\n".join(map(lambda x: str(x),wLst))+"\n}\n"
                        actualWidgetType = wType
                        wLst = []
                    wLst.append(item)
#                   print actualWidgetType,wType,"\t",item.type,str(item)
                if len(wLst)>0:
                    retStr += "file "+actualWidgetType+".template {\n"+"\n".join(map(lambda x: str(x),wLst))+"}\n"

                retStr+"}\n"
                if groupWidget and self.checkWidgetPath(groupWidget+"Footer"):
                    retStr += "file "+groupWidget+"Footer.template  {\n  {}\n}\n"
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
                sortParam = parseParam(sort)
                if isinstance(sortParam,str):
                    int(sortParam)
                    self.isSort = "SORT_BY_NUMBER"
                elif isinstance(sortParam,dict):
                    if sortParam.has_key('WIDGET'):
                        self.widgetName = sortParam['WIDGET']
                        del(sortParam['WIDGET'])
                    if sortParam.has_key('GRID'):
                        self.isSort = "SORT_BY_GRID"
                        xy = sortParam['GRID']
                        (self.xPos,self.yPos)=xy.split(',')
                        if self.xPos is not None and self.yPos is not None:
                            self.data.update(sortParam)
                        else:
                            raise ValueError, "No valid grid sort parameter: "+sort
                    elif sortParam.has_key('SORT'):
                        self.isSort = "SORT_BY_NUMBER"
                        self.sort = sortParam['SORT']
                        del(sortParam['SORT'])
                        self.data.update(sortParam)
                        print self.isSort, self.sort, self.widgetName, self.data
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
                if  BDNS_EXIST :                                            # BDNS sort by device name
                    return BDNS.cmpNamesBy(self.devn.values()[0],pw.devn.values()[0],self.bdnsOrder)
                else:
                    return cmp(self.devn.values()[0],pw.devn.values()[0])   # lexical sort by device name
                return 
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
        self.widgetPath = widgetPath

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
    - The alarm group structure is defined as a path for each item and stored in a
      static tree structure.

    - The defaults for the mask of an item is: ---T-
    """
    nodeDict={}

    @staticmethod
    def toGroupString(grStr): return substRe(grStr,' ','_').upper()

    @staticmethod
    def printFiles(prePath,groupNull=None):
        for filename in epicsAlh.nodeDict.keys():
            installFile = prePath+"/"+filename
            try :
#                print "  Creating file",installFile+".alh"
                f = open(installFile+".alh",'w')
                f.write(epicsAlh.printAllSubst(filename,groupNull))
                f.close()
            except IOError:
                die("IOError in write file: "+filename+".alh")

    @staticmethod
    # Walk the tree and return the alh file as string
    def printAllSubst(root=None,groupNull=None):

        #The user defined function to be called for each leaf of the tree - to print one alarm channel
        def printChannel(leaf,path,myPar):
            myPar.append("CHANNEL "+epicsAlh.toGroupString(path[-1])+ " "+str(leaf))
            return myPar

        # The user defined function to be called for each node of the tree - to print one alarm group
        def printGroup(nodeName,depth,path,myPar):
            if depth == 0:
#               print "GROUP NULL "+epicsAlh.toGroupString(path[0])+"\n$ALIAS "+path[0]+"\n"
                myPar.append("GROUP NULL "+epicsAlh.toGroupString(path[0])+"\n$ALIAS "+path[0]+"\n")
            else:
#               print "GROUP "+epicsAlh.toGroupString(path[depth-1])+" "+epicsAlh.toGroupString(path[depth])+"\n$ALIAS "+path[depth]+"\n"
                myPar.append("GROUP "+epicsAlh.toGroupString(path[depth-1])+" "+epicsAlh.toGroupString(path[depth])+"\n$ALIAS "+path[depth]+"\n")
            return myPar

        def cmpAlhItems(a,b): 
            if a.sort and b.sort:
                return cmp( int(a.sort), int(b.sort))
            else:
                return 0
                    
        def walkTree(nodePath,nodeDict,depth,retPar,leafFunc=None,nodeFunc=None,cmpLeafFunc=None):
#           print "walkTree:",depth,len(nodePath),nodePath
            for nodeName in sorted(nodeDict.keys()):
                node = nodeDict[nodeName]
                if len(nodePath) == depth:
                    nodePath.append(nodeName)
                    if  nodeFunc:
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
#        print "printAllSubst('"+root+"')\n",pprint.pprint(epicsAlh.nodeDict)
        nodePath = [root] # get single file as string
        rootDict = epicsAlh.nodeDict[root]['NODES']
        if  groupNull:
            ret = "GROUP NULL "+epicsAlh.toGroupString(root)+"\n$ALIAS "+root+"\n\n"+ \
                  "\n".join(walkTree(nodePath,rootDict,1,retPar,printChannel,printGroup,cmpAlhItems))
        else:
            ret = "\n".join(walkTree(nodePath,rootDict,1,retPar,printChannel,None      ,cmpAlhItems))
        return ret

    @staticmethod
    def setMask(flags):
        """
        compile string with alh mask characters [C D A T L] to a alh mask.
        Raise ValueError for illegal characters
        E.g. 'MASK':"T" -> "---T-"
        """
        flagList = ['-','-','-','-','-']
        for flag in list(flags):
            if   flag == 'C': flagList[0]=flag
            elif flag == 'D': flagList[1]=flag
            elif flag == 'A': flagList[2]=flag
            elif flag == 'T': flagList[3]=flag
            elif flag == 'L': flagList[4]=flag
            elif flag == '-': pass
            else: raise ValueError, "Illegal Flag list: "+flags
        return "".join(flagList)

#epicsUtils.epicsAlh(devName,alhSig,devObj.alhGroup,devObj.alhFlags,devObj.panelName,devObj.alhSort,lines)
#epicsUtils.epicsAlh(devName,alhSig,devObj,lines)
#    def __init__(self,devname,signal,nodePath,tags=None,devObj.panelName=None,sort=None,lineNr=None) :
    def __init__(self,devname,signal,nodePath,tagPar,sort=None) :
        """Definition of the alarm objects:

        devname:    The CHANNEL ChannelName is the EPICS PV: "devname:signal"
        signal:
        nodePath:   '|' separated list. First element is the filename behind it defines 
                    the path in the alh-tree. 
        flags:      Optional dictionary with the format items according to the alh docu. 
                    SPECIAL: the Alarm Channel Mask: is defined as flags['MASK'] but after
                    __init__ removed from the dictionary!
        sort:       Optional sort number: The sort order for the signals within a group. Default 
                    as found.
        Example: 
        
        epicsUtils.epicsAlh("MYDEV","readback","alhFile|device|in|booster",{'ALARMCOUNTFILTER':"2 1",'COMMAND':"run_edm -x huhu.edl",'MASK':"CD"},1)

        EPICS alh docu:
        
        http://www.aps.anl.gov/epics/EpicsDocumentation/ExtensionsManuals/AlarmHandler/ALHUserGuide/ALHUserGuide.html
        """
        #print "epicsAlh(",",".join((devname,signal,nodePath))+")"
        self.devName = devname
        self.signal  = signal
        self.nodePath= nodePath.split("|")
        self.sort    = sort
        self.tags    = {'ACKPV' : None,
                        'FORCEPV' : None,
                        'FORCEPV CALC' : None,
                        'FORCEPV_CALC' : None,
                        'FORCEPV_CALC_A' : None,
                        'FORCEPV_CALC_B' : None,
                        'FORCEPV_CALC_C' : None,
                        'FORCEPV_CALC_D' : None,
                        'FORCEPV_CALC_E' : None,
                        'FORCEPV_CALC_F' : None,
                        'SEVRPV' : None,
                        'GUIDANCE' : None,
                        'END' : None,
                        'GUIDANCE' : None,
                        'ALIAS' : None,
                        'COMMAND' : None,
                        'SEVRCOMMAND' : None,
                        'STATCOMMAND' : None,
                        'ALARMCOUNTFILTER' : None,
                        'BEEPSEVERITY' : None,
                        'BEEPSEVR' : None
                    }
        self.mask   = "---T-"
        if tagPar.has_key('MASK'):
            self.mask = tagPar['MASK']
            del tagPar['MASK']

        names = self.tags.keys()
        for name in tagPar.keys():
            if name in names:
                self.tags[name] = tagPar[name]
            else:
                raise ValueError("Illegal ALH Group definition (col. S)"+name)

        if len(self.nodePath) == 0: 
            raise ValueError("Missing ALH Group definition (col. S)")

        self.putToNode(self.nodePath,0,epicsAlh.nodeDict)
        
#        print "INIT FINISHED: \n",self.__repr__()
        
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
        ret = self.devName+":"+self.signal+" "+self.mask+"\n"
        for x in sorted(self.tags.keys()):
            if self.tags[x]: ret += "$"+x+" "+self.tags[x]+"\n"
        return ret

    def __repr__(self):
        ret = "epicsAlh('"+self.devName+"', '"+self.signal+"', '"+"|".join(self.nodePath)+"', {"
        for x in self.tags.keys():
            if self.tags[x]: ret += "'"+x+"':'"+self.tags[x]+"', "
        return ret+"'MASK': '"+self.mask+"'})"


class epicsTemplate(object):
    """
    This class stores and print an EPICS database data for .db or .template files.

    * Object Data:

    - rtyp  template name or record type
    - devn  devicename as dictionary of name tag and name {'DEVN':devName}
    - field <dict> dictionary of name/value pairs

    - _init__(self,rtyp,name,fieldDict,filename=None,infoDict=None) )
    - __str__()         # EPICS substitutions format
    - __repr__()        # python format: tupel of (rtyp,name,{fieldDict})
    - getType(): return type name
    - getName(): return devicename
    - getFields(): return field dictionary
    - prAsSubst(): print one line for this template without header 'file ...template  {'
    - prAsRec(): treat this data as EPICS record and print one line 
                 'record(rtyp,"NAME:SNAME")
                 ATTENTION the record needs the devicename as defined in 'devn' AND the 
                 field 'SNAME' for a PV name

    * Static data

    - typeDict={}   Dictionary of rtyp s that contain a list of objects with this rtype
    - deviceList=[] List of objects to preserve the creation order and for search 
                    functions

    - getFileNames(): return a list of File names to be crated or None for default file 
                      only
    - printAllSubst(filename='default'): print all stored templates in 
                    EPICS.substitution format
    - printAllRecords(filename='default'): treat all data as EPICS-records and print all
                   stored templates in EPICS.db format
    - getDevice(devName): return a list of records with this devicename or None

    - findObject(devName, parDict) Get records/template instances that matches 
        the device name and the parameters - may be empty for not found
    """
    files = {}
#    typeDict={}
#    deviceList=[]
    def __init__(self,rtyp,nameDict,fieldDict={},filename=None,infoDict=None) :
        self.field = fieldDict
        self.info  = infoDict
        self.devn  = nameDict
        self.rtyp  = rtyp
#        if self.field.has_key('SNAME'):
#            print self.devn,self.field['SNAME'],self.info
        if not filename: raise NameError
        
        if not epicsTemplate.files.has_key(filename):
            epicsTemplate.files[filename] = {'TYPEDICT':{},'DEVICELIST':[]}
        try:
            l = epicsTemplate.files[filename]['TYPEDICT'][rtyp]
        except KeyError:
            l = []
            epicsTemplate.files[filename]['TYPEDICT'][rtyp]=l
        l.append(self)
        epicsTemplate.files[filename]['DEVICELIST'].append(self)

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

    def processInfo(self):
        if self.info is None:
            return ""
        return "\n".join(map(lambda x: "info(\\\""+x+"\\\",\\\""+self.info[x]+"\\\")",sorted(self.info.keys())))

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
        info = ""
        i = self.processInfo()
        if(i):
            info = ",INFO=\""+i+"\""
        return "  { "+self.getDevnTag()+"=\""+self.getDevn()+"\","+",".join(filter(None,map(lambda x: prItem(x),sorted(self.field.keys()))))+info+"}"

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
            del self.field['SNAME']
            return "record("+self.rtyp+",\""+self.getDevn()+":"+sname+"\") {\n\t"+self.processInfo() + "\n\t".join(filter(None,map(lambda x: prField(x),sorted(self.field.keys()))))+"\n}"
        except KeyError:
            raise ValueError("Warning prAsRec(): no SNAME in "+str(self.field))
#enable this if the convention PV=NAME:SNAME is NOT wanted!
#            return "record("+self.rtyp+",\""+self.getDevn()+"\") {\n\t"+"\n\t".join(filter(None,map(lambda x: prField(x),sorted(self.field.keys()))))+"\n}"

    @staticmethod
    def getFilenames():
        """
        Get list of filenames - at least one element called 'default'
        """
        return epicsTemplate.files.keys()

    @staticmethod
    def getDevice(devName,filename=None):
        """
        Get list of records and template instances that have this device name - may be 
        empty for not found. 'filename=None' means search in all filenames.
        """
        li = []
        def check(filename):
            for item in epicsTemplate.files[filename]['DEVICELIST']:
                if item.getDevn() == devName: li.append(item)
        if filename:
            check(filename)
        else:
            for f in epicsTemplate.getFilenames():
                check(f)
        return li

    @staticmethod
    def findObject(devName, parDict,filename=None):
        """
        Get records/template instances that matches the device name and the parameters.
        Return empty list for not found.
        """
        li = []
        def findO(filename):
            for item in epicsTemplate.files[filename]['DEVICELIST']:
                try:
                    if item.getDevn() == devName:
                        for par in parDict.keys():
                            if item.field.has_key(par):
                                if item.field[par] != parDict[par]:
                                    raise ValueError
                            else:
                                raise ValueError
                    else:
                        raise ValueError
                except ValueError:
                    pass
                else:
                    li.append(item)
        if filename:
            findO(filename)
        else:
            for f in epicsTemplate.getFilenames():
                findO(f)
        
        return li

    @staticmethod
    def getPV(devName,signalName,signalField='SNAME',filename=None):
        """
        Search object list for devName AND field SNAME=signalName (signalField tag may 
        be set as third parameter)
        
        Return list of matching objects - empty list means not found
        """
        #print "getPV(",devName,signalName,signalField,")"
        li= []
        for item in epicsTemplate.getDevice(devName,filename):
            if (not signalField) or (not item.field.has_key(signalField)) or (item.field[signalField] != signalName):
                continue
            li.append(item)
        return li

    @staticmethod
    def printAllSubst(filename=None):
        """
        Treat all objects (EPICS records also) as EPICS substitutions and print in
        EPICS.substitutions format
        """
        if not filename: raise NameError
        prStr = ""
        for template in epicsTemplate.files[filename]['TYPEDICT'].keys():
            prStr +=  "file "+template+".template {\n"
            prStr += "\n".join( map(lambda x: x.prAsSubst(),epicsTemplate.files[filename]['TYPEDICT'][template]))
            prStr += "\n}\n";
        return prStr
    @staticmethod
    def printAllRecords(filename=None):
        """
        Treat all objects as EPICS records and print in EPICS.db format
        """
        if not filename: raise NameError
        return "\n".join( map(lambda x: x.prAsRec(),epicsTemplate.files[filename]['DEVICELIST']))

def updateStruct(a,b):
    """ Helper function to create st.cmd files. Merge two data structures: b into a. 
    See NEWIOC.py for details to the data structure
    """
    for bKey in b.keys():
        if a.has_key(bKey):
            aList = a[bKey]
            if isinstance( aList,list):
                for item in b[bKey]:
                    aList.append(item)
            else:
                a[bKey] = aList
        else:
            a[bKey] = b[bKey]

