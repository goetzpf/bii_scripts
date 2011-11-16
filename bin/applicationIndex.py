#!/usr/bin/env python

from optparse import OptionParser
import sys
import os
import os.path
import subprocess
import epicsUtils as eU
import listOfDict as lod
import pprint as pp
import canLink as cL

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
    	return "not loaded on IOC"

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

def processStCmd(topPath):
    iocBootPath = topPath+"/iocBoot"
    iocString = systemCall(['ls',iocBootPath])
    if options.verbose is True: print "processStCmd: ",topPath
    iocDb = {}
    dbIoc = {}
    for ioc in iocString.split("\n"):
	i = eU.matchRe(ioc,"ioc(.*)")
	if i is None:
	    continue
	iocName = i[0]
	parseFileName = "/".join( (topPath,"iocBoot",ioc,"st.cmd") )
    	if options.verbose is True: print iocName, parseFileName
	if not os.path.isfile(parseFileName): eU.die("File doesn't exist: "+parseFileName)
	try :
	    IN_FILE = open(parseFileName) 
	except IOError: 
	    eU.die("can't open input file: "+parseFileName)
	if options.verbose is True: print "Reading data from "+parseFileName

	dbdFile=topPath+"/dbd/"
 	envDict={}

	iocDb[iocName] = []
	for line in IN_FILE:
	    parsedLine = eU.parseStCmd(line)
	    if len(parsedLine)<1: continue
	    cmd = parsedLine[0]
	#    print "PARSE: '%s'" %line, parsedLine
	    if cmd == "epicsEnvSet":
	#    	print "PARSE: '%s'" %line, parsedLine
    		envDict[parsedLine[1]]=parsedLine[2]
	    if cmd == "putenv":
		(name,value)=parsedLine[1].split("=")
		envDict[name]=value
	    if cmd == "dbLoadDatabase":
		dbdFile += eU.substituteVariables(eU.substRe(parsedLine[1],"dbd/",""),envDict)
	    if cmd == "dbLoadRecords":
    		dbFile = eU.substituteVariables(eU.substRe(parsedLine[1],"db/",""),envDict)
    		if options.verbose is True: print "\t",dbFile
		iocDb[iocName].append(dbFile)
    	    	if not dbIoc.has_key(dbFile):
		    dbIoc[dbFile] = []
		dbIoc[dbFile].append(iocName)
    return (iocDb,dbIoc)

def findApplications(topPath):
    appString = systemCall(['find',topPath,"-name","*.db"])
    if options.verbose is True: print "findApplications: topPath: '"+topPath+"' : \n", appString
    appDb = {}
    dbApp = {}
    for db in appString.split("\n"):
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

def hardware(filename,iocname,pvname,fieldDict) :
    fieldDict.update( {"iocname":iocname,"filename":filename,"pvname":pvname} )

    if fieldDict.has_key('INP'):
        fieldDict['LINK'] = fieldDict['INP']
    elif fieldDict.has_key('OUT'):
        fieldDict['LINK'] = fieldDict['OUT']
    else:
        fieldDict['LINK'] = None

    if fieldDict['DTYP'] == 'lowcal':
        if fieldDict['RTYP'] == 'hwLowcal':
            fieldDict['LINK'] = cL.hwLowcal2canLink(fieldDict)
        fieldDict.update(cL.decode(fieldDict['LINK']))
        if fieldDict.has_key('cid') and fieldDict['cid'] == 2:	# ADA/IO32 card
            mux = int(fieldDict['multiplexor'])
            fieldDict['CARD'] =  mux/12
            fieldDict['CHAN'] =  mux%12
        if fieldDict.has_key('cid') and fieldDict['cid'] == 4:	# vctrl card
            mux = int(fieldDict['multiplexor'])
            fieldDict['CARD'] =  mux/2
            fieldDict['CHAN'] =  mux%2
    else:
        vmeLnk = eU.matchRe(fieldDict['LINK'],"#C\s*(\d+)\s*S\s*(\d+)")
        if vmeLnk is not None:
            fieldDict['CARD'] =  vmeLnk[0]
            fieldDict['CHAN'] =  vmeLnk[1]
    return fieldDict

def checkHardwareAccess(iocDb,topPath):
    hwData = []
    for ioc in iocDb.keys():
        for db in iocDb[ioc]:
            hw = systemCall(['grepDb.pl','-pH','-th',topPath+"/db/"+db]) # return a perl hash of {PVNAME=> {FIELD=>VALUE}}
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
                hw = hardware(db,ioc,pv,hwDict[pv])
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
(iocDb,dbIoc) = processStCmd(topPath)
iocHw = None
if iocDb:
    iocHw = checkHardwareAccess(iocDb,topPath)

######## PRINT DATA #######################################################
htmlHeader = """<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="de" lang="de">
<head>
    <TITLE>Application and Hardware Reference</TITLE>
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
    <link rel=stylesheet type="text/css" href="http://www-csr.bessy.de/~kuner/makeDocs/docStyle.css">
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
if options.verbose is True: print "********** Write File *********"
print >> FILE, "<H1>Application Reference</H1>\n\n<TABLE BORDER=1>"

if appDb:
    for app in appDb.keys():
	dbList = appDb[app]
	span = ""
	if len(dbList) > 1:
    	    span = "ROWSPAN=\""+str(len(dbList))+"\" "
	print >> FILE, "<TR >\n  <TD "+span+"VALIGN=\"TOP\"><A NAME=\""+app+"\">"+app+"</TD>\n  <TD VALIGN=\"TOP\">"+dbList[0]+"</TD>\n  <TD>"+getIoc(dbIoc,dbList[0])+"</TD></TR>"
	for db in dbList[1:]:
	    print >> FILE,"<TR>\n  <TD VALIGN=\"TOP\">"+db+"</TD>\n  <TD VALIGN=\"TOP\">"+getIoc(dbIoc,db)+"</TD></TR>"
    print >> FILE, "</TABLE>\n"

if iocDb:
    print >> FILE, '<H1>IOC Application Reference</H1>\n\n<TABLE BORDER=1>'
    for ioc in iocDb.keys():
	dbList = iocDb[ioc]
	span = ""
	if len(dbList) > 1:
    	    span = "ROWSPAN=\""+str(len(dbList))+"\" "
	setIoc = '<TH '+span+'VALIGN="TOP"><A NAME="'+ioc+'"><A HREF="#HW_'+ioc+'">'+ioc+'</A></TH>\n  '
	for db in dbList:
	    print >> FILE,'<TR>\n  '+setIoc+'<TD>'+getDb(dbApp,db)+'</TD></TR>'
	    if len(setIoc) > 0: 	# first item only
		setIoc = ''
    print >> FILE, "</TABLE>\n"

if iocHw:
    print >> FILE, "<H1>IOC Hardware Reference</H1>\n\n"
    (forgetThisList,getHw) = lod.filterMatch(iocHw,{'DTYP':['HwClient','Dist Version','IOC stats','Raw Soft Channel','Soft Channel','Soft Timestamp','Soft Timestamp WA','VX stats','VxWorks Boot Parameter']})
    for ioc in iocDb.keys():
	(iocHwList,getHw) = lod.filterMatch(getHw,{'iocname':ioc})
	if len(iocHwList) == 0: 
    	    continue

	print >> FILE, '<H2><A NAME="HW_'+ioc+'">'+ioc+'</H2>\n\n'

	print >> FILE, "<H3>CAN Devices</H3>\n\n"
	order = ('port','nid','cid','CARD','CHAN','LINK','pvname','filename')
	(canList,otherList) = lod.filterMatch(iocHwList,{'DTYP':['lowcal',],})
	table = lod.orderToTable(canList,order)
	if len(table) > 0:
            print >> FILE, '<TABLE BORDER=1>\n<TR>'+toCol(['Process Variable','Port','CAN-Id','Card','Chan','Link','cid'],'TH')+'\n</TR>'
            for (port,nid,cid,CARD,CHAN,LINK,pvname,filename) in table:
        	c = LINK.split(' ') # c=(@type dataType port in_cob out_cob mux ....)
		t = "In Cob: %d Out Cob: %d Mux: %d" % (int(c[4],16),int(c[5],16),int(c[6],16))
        	LINK = '<DIV TITLE="'+t+'">'+LINK+'</DIV>'
        	pvname = '<DIV TITLE="IOC: '+ioc+', Application: '+dbApp[filename]+', File: '+filename+'">'+pvname+'</DIV>'
        	print >> FILE, "<TR>"+toCol([pvname,port,nid,CARD,CHAN,LINK,cid])+"\n</TR>"
            print >> FILE, "</TABLE>\n"

	print >> FILE, "<H3>VME Devices</H3>\n\n"
	(vmeList,otherList) = lod.filterMatch(otherList,{'DTYP':['esd AIO16','ADA16','BESSY MuxV','Dyncon','EK IO32','ESRF MuxV','Highland DDG V85x','OMS MAXv','OMS VME58','Rfmux1366','TDU','V375','V680','VHQ','Vpdu']})
	order = ('DTYP','CARD','CHAN','pvname','LINK')
	table = lod.orderToTable(vmeList,order)
	if len(table) > 0:
            print >> FILE, "<TABLE BORDER=1>\n<TR>"+toCol(['Process Variable','Card','Chan','DTYP','Link'],'TH')+"\n</TR>"
            for (DTYP,CARD,CHAN,pvname,LINK) in table:
        	print >> FILE, "<TR>"+toCol([pvname,CARD,CHAN,DTYP,LINK])+"\n</TR>"
            print >> FILE, "</TABLE>\n"

	print >> FILE, "<H3>Other Devices</H3>\n\n"
	order = ('LINK','pvname')
	table = lod.orderToTable(otherList,order)
	if len(table) > 0:
            print >> FILE, "<TABLE BORDER=1>\n<TR>"+toCol(['Process Variable','Link'],'TH')+"\n</TR>"
            for (link,pv) in table:
        	print >> FILE, "<TR>"+toCol([pv,link])+"\n</TR>"
            print >> FILE, "</TABLE>\n"

print >> FILE, htmlFooter
FILE.close()
 
