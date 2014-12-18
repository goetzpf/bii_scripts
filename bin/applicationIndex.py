#!/usr/bin/env python

from optparse import OptionParser
import time
import sys
import re
import os
import os.path
import subprocess
import epicsUtils as eU
import listOfDict as lod
import pprint as pp
import canLink as cL
import tokParse as tP
# Searching for Hardware means to look at the DTYP field of a record. So here we define
# the list of known DTYPs get it with:
# find $(TOP)/db -name *.db|xargs perl -e 'while(<>){print "$1\n" if($_=~/DTYP,\s*\"(.*)\"/);}'|sort -u
hardwareDtypList = ['esd AIO16','ADA16','BESSY MuxV','Dyncon','EK IO32','ESRF MuxV',
    	    	    'Highland DDG V85x','OMS MAXv','OMS VME58','Rfmux1366','TDU','V375',
		    'V680','VHQ','Vpdu'
		   ]

def systemCall(cmdArgsList):
    """ Do a system call and return the output
    """
    try:
	return subprocess.Popen(cmdArgsList,stdout=subprocess.PIPE,stderr=subprocess.PIPE).communicate()[0]
    except OSError, e:
	print >>sys.stderr, "Execution failed:",cmdArgsList, e
	return None
    
def getIoc(dbIoc,db):
    """ little html helper
    """
    if dbIoc.has_key(db):   
    	return reduce(lambda y,x:y+str("<A HREF=\"#"+x+"\">"+x+"</A><br>"),dbIoc[db],"")
    else: 
    	return None

def getDb(dbApp,db):
    """ little html helper
    """
    if dbApp.has_key(db): 
    	return "<DIV TITLE=\""+dbApp[db]+"\"><A HREF=\"#"+dbApp[db]+"\">"+db+"</A></DIV>"
    else: 
    	return "<DIV TITLE=\"got from support module\">"+db+"</DIV>"

def toCol(dList,tag='TD'): 
    """ create a string of tagged list items, default tag is TD, also possible: TH, LI"""
    def toStr(x):
    	if x is None:
	    return "-"
	else:
	    return str(x)
    return "<"+tag+">"+str("</"+tag+">\n  <"+tag+">").join([toStr(x) for x in dList])+"</"+tag+">"

def substEnvVariables(param,envDict):
    for name in envDict.keys():
	param = param.replace(r"${"+name+"}",envDict[name])
    return param

def getIocStartupData(topPath):
    path = topPath+"/GenericBootApp/O.Common"
    iocPy = []
    for item in systemCall(['ls',path]).split("\n"):
	py = eU.matchRe(item,'(IOC.*)\.py')
	if py: iocPy += py
    if len(iocPy) == 0:
    	return (None,None)
    if options.verbose is True: print "*** getIocStartupData() for:\n",iocPy
    iocDb = {}
    dbIoc = {}
    sys.path.insert(0,path)
    for ioc in iocPy:
    	fileName = path+"/"+ioc+".py"
	myDict = {}
	try:
	    execfile(fileName,myDict)
	except SyntaxError, e:
	    raise SyntaxError("Syntax Error in File: "+fileName+"\n"+str(e))
	iocDb[ioc] = myDict['iocConfig']['loadRecords']
	for db in iocDb[ioc]:
	    db['DB'] = db['DB']+".db"
	    dbFile = db['DB']
	    if not dbIoc.has_key(dbFile):
	    	dbIoc[dbFile] = []
	    dbIoc[dbFile].append(ioc)
    return(iocDb,dbIoc)

def processStCmd(topPath,iocList):
    iocDb = {}
    dbIoc = {}

    tokDefList =( ('B_OPEN', (r'\(',) ),\
    	('B_CLOSE',     (r'\)',) ),\
    	('COMMA',    	(r',',) ),\
    	('QSTRING',(r'(?<!\\)"(.*?)(?<!\\)"',) ), \
    	('WORD',    	(r'[a-zA-Z0-9_&/\.:=+\-\{\}\$\']+',) ),\
    	('COMMENT',   	(r'#.*',) ),\
    	('LOAD',   	(r'[<|>]',) ),\
    	('SPACE',(r"\s+",))
    	)
    tokReList = tP.compileTokDefList(tokDefList)

    if options.verbose is True: print "*** processStCmd() for:\n",iocList
    for iocName in iocList:
	parseFileName = topPath+"/iocBoot/ioc"+iocName+"/st.cmd"
	if not os.path.isfile(parseFileName): eU.die("File doesn't exist: "+parseFileName)
	try :
	    IN_FILE = open(parseFileName) 
	except IOError: 
	    eU.die("can't open input file: "+parseFileName)
	if options.verbose is True: print "Reading data from "+parseFileName

	dbdFile=topPath+"/dbd/"
 	envDict={}
    	lineNr = 0
	for line in IN_FILE:
	    lineNr += 1
	    parsedLine = tP.parseStCmd(line,tokReList,lineNr)
	    if not parsedLine: continue
	    cmd = parsedLine[0]
	    if cmd == "epicsEnvSet":
       		#print "epicsEnvSet,PARSE: '%s'" %line, parsedLine
    		envDict[parsedLine[1]]=parsedLine[2]
	    if cmd == "putenv":
       		#print "putenv,PARSE: '%s'" %line, parsedLine
		(name,value)=parsedLine[1].split("=")
		envDict[name]=value
	    if cmd == "dbLoadDatabase":
       		#print "dbLoadDatabase,PARSE: '%s'" %line, parsedLine
    	    	dbdFile += substEnvVariables(eU.substRe(parsedLine[1],"dbd/",""),envDict)
	    if cmd == "dbLoadRecords":
       		#print "dbLoadRecords,PARSE: '%s'" %line, parsedLine
    		dbFile = substEnvVariables(eU.substRe(parsedLine[1],"db/",""),envDict)
		param = ""
		if len(parsedLine) == 3:
		    param = parsedLine[2]
		    #print "param:",param,eU.parseParam(substEnvVariables(param,envDict),',')
		if not iocDb.has_key(iocName):
	    	    iocDb[iocName] = []
		iocDb[iocName].append( {'DB':dbFile,'SUBST':eU.parseParam(substEnvVariables(param,envDict),',')})
		if not dbIoc.has_key(dbFile):
	    	    dbIoc[dbFile] = []
		dbIoc[dbFile].append(iocName)
    return (iocDb,dbIoc)

def findApplications(topPath):
    appString = systemCall(['find',topPath,"-name","*.db"])
    appList = appString.split("\n")
    if options.verbose is True: print "*** FindApplications in top: '"+topPath+"' : \n", appList
    appDb = {}
    dbApp = {}
    for db in appList:
	db = eU.substRe(db,"O\..*\/","")
	d = eU.matchRe(db,".*/(.*?App.*)")
	if d is not None:   	# look for something like: myApp/[Db/]myFile.db
	    item = d[0].split("/")
	    if len(item) < 2:
	    	print "Error in findApplications:",d[0]
		sys.exit()
	    appName = item[0]
	    dbFileName = item[-1]
	    if not appDb.has_key(appName):
	    	appDb[appName] = []
	    appDb[appName].append(dbFileName)
	    dbApp[dbFileName] = appName
    return (appDb,dbApp)

def hardware(ioc,dbFile,param,iocname,pvname,fieldDict) :
#    print "hardware(",ioc,dbFile
#    print "param",param
#    print iocname,pvname
    try:
	pvname = eU.substituteVariables(pvname,param)
    except AttributeError:
    	print ioc,dbFile,iocname,pvname,param
	print "Can't substitute variable '"+param+"' from:"
	pp.pprint(fieldDict)
	sys.exit()
    fieldDict.update( {"iocname":iocname,"filename":dbFile,"pvname":pvname} )

    if fieldDict.has_key('INP'):
        link = fieldDict['INP']
    elif fieldDict.has_key('OUT'):
        link = fieldDict['OUT']
    else:
        link = None
    if link and len(param) >0:
	link = eU.substituteVariables(link,param)
    if fieldDict['DTYP'] == 'lowcal':
        try:
	    if fieldDict['RTYP'] == 'hwLowcal':
        	link = cL.hwLowcal2canLink(fieldDict)
	    if link:
		fieldDict.update(cL.decode(link))
        except ValueError, e:
	    print "Warning:",dbFile+", '"+fieldDict['pvname']+"': ",e
	    
	if fieldDict.has_key('cid') and fieldDict['cid'] == 2:	# ADA/IO32 card
            mux = int(fieldDict['multiplexor'])
            fieldDict['CARD'] =  mux/12
            fieldDict['CHAN'] =  mux%12
        if fieldDict.has_key('cid') and fieldDict['cid'] == 4:	# vctrl card
            mux = int(fieldDict['multiplexor'])
            fieldDict['CARD'] =  mux/2
            fieldDict['CHAN'] =  mux%2
    else:
	vmeLnk = eU.matchRe(link,"#C\s*(\d+)\s*S\s*(\d+)")
	if vmeLnk is not None:
            fieldDict['CARD'] =  vmeLnk[0]
            fieldDict['CHAN'] =  vmeLnk[1]
	else:
	    if link.find ("$")>=0:
	    	print "Warning: Unsubstituted values found in IOC:",iocname,"FILE:",dbFile,"PV:",pvname,"LINK:",link
		sys.exit()
    fieldDict['LINK'] = link    	    
    return fieldDict

def checkHardwareAccess(iocDb,topPath):
    hwData = []
    if options.verbose is True: print "\n*** CheckHardwareAccess"
    for ioc in iocDb.keys():
	for dbItem in iocDb[ioc]:
	    dbFile = dbItem['DB']
	    param = {}
	    if dbItem.has_key('SUBST'):
	    	param  = dbItem['SUBST']
	    hw = systemCall(['grepDb.pl','-pH','-th',topPath+"/db/"+dbFile]) # return a perl hash of {PVNAME=> {FIELD=>VALUE}}
            if not hw:
                continue 
	    hw = eU.substRe(hw," => ",":")  	# make it python eval uable
            hw = eU.substRe(hw,"\$VAR1\s*=","")
            hw = eU.substRe(hw,";","")
            try:
                hwDict = eval(hw)
            except:
                pp.pprint(hw)
                print "ERROR in checkHardwareAccess(",iocDb,topPath,")"
                sys.exit()

	    for pv in hwDict.keys():
		hw = hardware(ioc,dbFile,param,ioc,pv,hwDict[pv])
		if hw: 
                    hwData.append(hw)
    return hwData
	    	
######## Main #######################################################
usage        = "USAGE: applicationIndex.py [options] topPath outFile"
parser = OptionParser(usage=usage,
		 version="%%prog 1.0",
    		 description="USAGE: applictionIndex.py [-h OPTIONS] topPath")
parser.add_option("-v","--verbose",
		 action="store_true", # default: None
		 help="print debug information", 
    		 )
try:
    (options,args) = parser.parse_args()
    (topPath,filename) = args[0:2]
except:
    print "OPTIONS:",options,"\nARGS:",args[:2]
    print usage
    sys.exit()

(appDb,dbApp) = findApplications(topPath)
#pp.pprint(appDb)
#pp.pprint(dbApp)
(iocDb,dbIoc) = getIocStartupData(topPath)
if iocDb == None: iocDb = {}
if dbIoc == None: dbIoc = {}

iocString = systemCall(['ls',topPath+"/iocBoot"])
iocList = []
for ioc in iocString.split("\n"):
    i = eU.matchRe(ioc,"ioc(.*)")
    if i is None:
	continue
    iocName = i[0]
    if not iocDb.has_key(iocName):
    	iocList.append(iocName)

(iD,dI) = processStCmd(topPath,iocList)

if iD: iocDb.update(iD)
if dI: dbIoc.update(dI)
#pp.pprint(iocDb)
#pp.pprint(dbIoc)
#sys.exit()
iocHw = None
if iocDb:
    iocHw = checkHardwareAccess(iocDb,topPath)

if options.verbose is True: print "*** Process Data"

######## PRINT DATA #######################################################
htmlHeader = """<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="de" lang="de">
<head>
    <TITLE>Application and Hardware Reference</TITLE>
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
    <link rel=stylesheet type="text/css" href="http://help.bessy.de/~kuner/makeDocs/docStyle.css">
</head>
<body>
<H1>Application and IOC Reference</H1>
"""
htmlFooter = """
</body>
</html>
"""
if not appDb and not iocDb and not iocHw: # nothing to do
    sys.exit()

try :
    FILE = open(filename,"w") 
except IOError: 
    eU.die("can't open input file: "+filename)

print >> FILE, htmlHeader

# Application Reference:
if options.verbose is True: print "*** Write File:", filename
print >> FILE, "<P>last update: "+time.strftime("%d.%m.%Y")+"</P>\n"
print >> FILE, '<H2>Content</H2>\n<P><A HREF="#IOC_APP">IOC Application Reference</A></P>'
print >> FILE, '<P>IOC Hardware Reference</A></P>\n'
(forgetThisList,getHw) = lod.filterMatch(iocHw,{'DTYP':['HwClient','Dist Version','IOC stats','Raw Soft Channel','Soft Channel','Soft Timestamp','Soft Timestamp WA','VX stats','VxWorks Boot Parameter']})
for ioc in sorted(iocDb.keys()):
    (iocHwList,getHw) = lod.filterMatch(getHw,{'iocname':ioc})
    if len(iocHwList) == 0: 
    	continue
    print >> FILE, '<LI><A HREF="#HW_'+ioc+'">'+ioc+'</A>'

print >> FILE, "</UL>\n<H2>Application Reference</H2>\n\n<TABLE BORDER=1>"

if appDb:
    dbNotLoaded = []
    for app in appDb.keys():
	dbList = appDb[app]
	span = ""
	if len(dbList) > 1:
    	    span = "ROWSPAN=\""+str(len(dbList))+"\" "
	iocName = getIoc(dbIoc,dbList[0])
	if iocName == None:
	    iocName = "not loaded on IOC"
	    dbNotLoaded.append(dbList[0])
	print >> FILE, "<TR >\n  <TD "+span+"VALIGN=\"TOP\"><A NAME=\""+app+"\">"+app+"</TD>\n  <TD VALIGN=\"TOP\">"+dbList[0]+"</TD>\n  <TD>"+iocName+"</TD></TR>"
	for db in dbList[1:]:
	    iocName = getIoc(dbIoc,db)
	    if iocName == None:
		iocName = "not loaded on IOC"
	    	dbNotLoaded.append(db)
	    print >> FILE,"<TR>\n  <TD VALIGN=\"TOP\">"+db+"</TD>\n  <TD VALIGN=\"TOP\">"+iocName+"</TD></TR>"
    print >> FILE, "</TABLE>\n"
    if options.verbose is True and len(dbNotLoaded) > 0: 
    	print "*** Warning: .db files not loaded on IOC:\n",dbNotLoaded

if iocDb:
    print >> FILE, '<A NAME="IOC_APP"></A>\n<H2>IOC Application Reference</H2>\n\n<TABLE BORDER=1>'
    for ioc in sorted(iocDb.keys()):
	dbList = iocDb[ioc]
	span = ""
	if len(dbList) > 1:
    	    span = "ROWSPAN=\""+str(len(dbList))+"\" "
	setIoc = '<TH '+span+'VALIGN="TOP"><A NAME="'+ioc+'"><A HREF="#HW_'+ioc+'">'+ioc+'</A></TH>\n  '
	for dbObj in dbList:
	    print >> FILE,'<TR>\n  '+setIoc+'<TD>'+getDb(dbApp,dbObj['DB'])+'</TD></TR>'
	    if len(setIoc) > 0: 	# first item only
		setIoc = ''
    print >> FILE, "</TABLE>\n"

if iocHw:
    print >> FILE, "<H2>IOC Hardware Reference</H2>\n\n"
    (forgetThisList,getHw) = lod.filterMatch(iocHw,{'DTYP':['HwClient','Dist Version','IOC stats','Raw Soft Channel','Soft Channel','Soft Timestamp','Soft Timestamp WA','VX stats','VxWorks Boot Parameter']})
    for ioc in iocDb.keys():
	(iocHwList,getHw) = lod.filterMatch(getHw,{'iocname':ioc})
	if len(iocHwList) == 0: 
    	    continue

	print >> FILE, '<H3><A NAME="HW_'+ioc+'"></A>Hardware Channels on '+ioc+'</H3>\n\n'

	print >> FILE, "<H4>CAN Devices on"+ioc+"</H4>\n\n"
	order = ('port','nid','cid','CARD','CHAN','LINK','pvname','filename')
	(canList,otherList) = lod.filterMatch(iocHwList,{'DTYP':['lowcal',],})
	table = lod.orderToTable(canList,order)
	if len(table) > 0:
            print >> FILE, '<TABLE BORDER=1>\n<TR>'+toCol(['Process Variable','Port','CAN-Id','Card','Chan','Link','Port, In-, OutCOB, Mux'],'TH')+'\n</TR>'
            try:
		for (port,nid,cid,CARD,CHAN,LINK,pvname,filename) in table:
		    if LINK is not None:
			c = LINK.split(' ') # c=(@type dataType port in_cob out_cob mux ....)
			t = "In Cob: %d Out Cob: %d Mux: %d" % (int(c[4],16),int(c[5],16),int(c[6],16))
			cid ="%d %d %d %d"%(int(c[3],16),int(c[4],16),int(c[5],16),int(c[6],16))
		    else:
			t = "No INP/OUT"
			LINK = '-'
			cid ="-"
        	    LINK = '<DIV TITLE="'+t+'">'+LINK+'</DIV>'

		    pvname = '<DIV TITLE="IOC: '+ioc+', Application: '+dbApp[filename]+', File: '+filename+'">'+pvname+'</DIV>'
		    print >> FILE, "<TR>"+toCol([pvname,port,nid,CARD,CHAN,LINK,cid])+"\n</TR>"
            except KeyError:
	    	print "ERROR in print '"+pvname+"', CAN-Devices: '"+filename+"' not found in dbApp"
	    print >> FILE, "</TABLE>\n"

	print >> FILE, "<H4>VME Devices on "+ioc+"</H4>\n\n"
	(vmeList,otherList) = lod.filterMatch(otherList,{'DTYP':hardwareDtypList})
	order = ('DTYP','CARD','CHAN','pvname','LINK')
	table = lod.orderToTable(vmeList,order)
	if len(table) > 0:
            print >> FILE, "<TABLE BORDER=1>\n<TR>"+toCol(['Process Variable','Card','Chan','DTYP','Link'],'TH')+"\n</TR>"
	    try:
        	for l in table:
		    (DTYP,CARD,CHAN,pvname,LINK) = l
    	    	    pvname = '<DIV TITLE="IOC: '+ioc+', Application: '+dbApp[filename]+', File: '+filename+'">'+pvname+'</DIV>'
        	    print >> FILE, "<TR>"+toCol([pvname,CARD,CHAN,DTYP,LINK])+"\n</TR>"
            except KeyError:
	    	print "ERROR in print '"+pvname+"', VME-Devices: '"+filename+"' not found in dbApp"
            print >> FILE, "</TABLE>\n"

	print >> FILE, "<H4>Other Devices on"+ioc+"</H4>\n\n"
	order = ('LINK','pvname','filename','DTYP','RTYP')
	table = lod.orderToTable(otherList,order)
	if len(table) > 0:
            print >> FILE, "<TABLE BORDER=1>\n<TR>"+toCol(['Process Variable','Link'],'TH')+"\n</TR>"
	    try:
        	for (link,pvname,filename,dtyp,rtyp) in table:
        	    pvname = '<DIV TITLE="IOC: '+ioc+', Application: '+dbApp[filename]+', File: '+filename+', RTYP'+rtyp+', DTYP'+dtyp+'">'+pvname+'</DIV>'
		    print >> FILE, "<TR>"+toCol([pvname,link])+"\n</TR>"
            except KeyError:
	    	print "ERROR in print '"+pvname+"', Other-Devices: '"+filename+"' not found in dbApp"
            print >> FILE, "</TABLE>\n"

print >> FILE, htmlFooter
FILE.close()
 
