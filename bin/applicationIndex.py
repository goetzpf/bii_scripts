#!/usr/bin/env python

from optparse import OptionParser
import sys
import os
import os.path
import subprocess
import epicsUtils as eU
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

class Hardware(object):
    """ Describes the hardware information of a PV, just the link field or for 
    	CAN: port, id and card, chan or mux
    """
    def __init__(self,filename,iocname,pvname,fieldDict) :
    	self.iocname = iocname
    	self.filename = filename
	self.pvname  = pvname
	self.hwPar   = {"iocname":iocname,"filename":filename,"pvname":pvname}
	self.hwPar.update(fieldDict)

	if self.hwPar.has_key('INP'):
	    self.hwPar['LINK'] = fieldDict['INP']
	elif self.hwPar.has_key('OUT'):
	    self.hwPar['LINK'] = fieldDict['OUT']
	else:
	    self.hwPar['LINK'] = None

	if self.hwPar['DTYP'] == 'lowcal':
	    if self.hwPar['RTYP'] == 'hwLowcal':
	    	self.hwPar['LINK'] = cL.hwLowcal2canLink(fieldDict)
	    self.hwPar.update(cL.decode(self.hwPar['LINK']))
	    if self.hwPar.has_key('cid') and self.hwPar['cid'] == 2:	# ADA/IO32 card
	    	mux = int(self.hwPar['multiplexor'])
	    	self.hwPar['CARD'] =  mux/12
	    	self.hwPar['CHAN'] =  mux%12
	    if self.hwPar.has_key('cid') and self.hwPar['cid'] == 4:	# vctrl card
	    	mux = int(self.hwPar['multiplexor'])
	    	self.hwPar['CARD'] =  mux/2
	    	self.hwPar['CHAN'] =  mux%2
		
	else:
	    vmeLnk = eU.matchRe(self.hwPar['LINK'],"#C\s*(\d+)\s*S\s*(\d+)")
	    if vmeLnk is not None:
	    	self.hwPar['CARD'] =  vmeLnk[0]
	    	self.hwPar['CHAN'] =  vmeLnk[1]
    def __str__(self):
    	par = {}
	par.update(self.hwPar)
	s = par['filename']+", "+par['iocname']+", "+par['pvname']+", "
	return s+par['LINK']
	del(par['filename'])
	del(par['iocname'])
	del(par['pvname'])
	return self.filename+","+self.iocname+","+self.pvname+","+str(self.hwPar)
    def __repr__(self):
    	return "Hardware("+self.filename+","+self.iocname+","+self.pvname+","+str(self.hwPar)+")"

    @staticmethod
    def cmpHardwareByOrder(a,b,order):
    	o = order[0];
	result = 0
	if o == 'iocname':
	    result = cmp(a.iocname,b.iocname)
	    if result == 0 and len(order) > 0:
	    	return Hardware.cmpHardwareByOrder(a,b,order[1:])
	    else: 
		return result
	if o == 'filename':
	    result = cmp(a.filename,b.filename)
	    if result == 0 and len(order) > 0:
	    	return Hardware.cmpHardwareByOrder(a,b,order[1:])
	    else:
		return result
	if o == 'pvname':
	    result = cmp(a.pvname,b.pvname)
	    if result == 0 and len(order) > 0:
	    	return Hardware.cmpHardwareByOrder(a,b,order[1:])
	    else:
		return result
	else:
	    if a.hwPar.has_key(o) and b.hwPar.has_key(o):
	    	result = cmp(a.hwPar[o],b.hwPar[o])
	    	if result != 0:
		    return result
		elif len(order) > 0: 
		    return Hardware.cmpHardwareByOrder(a,b,order[1:])
	return result

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
		hwObj = Hardware(db,ioc,pv,hwDict[pv])
		if hwObj: 
		    hwData.append(hwObj)
    return hwData
	    	
def sortedHardware(hwList,order):
    def cmp_(a,b):
    	return Hardware.cmpHardwareByOrder(a,b,order)
    return sorted(hwList,cmp=cmp_)

def sortedHardwareToTable(hwList,order):
    """
    Parameter:
    	hwList: List of Hardware objects, 
	order:  List of keys to be filtered and sorted from the Hardware.hwPar dictionary
    Return list of ordered list of filtered values of Hardware objects
    """
    table = []
    for hw in hwList:
	col = []
	for key in order:
    	    if hw.hwPar.has_key(key):
    		col.append(str(hw.hwPar[key]))
	    else:
    		col.append("-")
	table.append(col)
#    eU.printTable(table,order)   
    return table

def filterHardware(hwList,filterHw):
    """
    Parameter:
    	hwList= list of Hardware objects, 
    	filterHw= {matchKey:[matchValue,..],..} A match value list for each key in the dict

    Return: tupel of the lists: (filterd, filteredOut)
    """
    res = []
    resOut = []
    for hw in hwList:
    	for outKey in filterHw:
	    if hw.hwPar.has_key(outKey) and hw.hwPar[outKey] not in filterHw[outKey]:
	    	resOut.append(hw)
	    else:
	    	res.append(hw)
    return (res,resOut)
    
######## Main #######################################################
usage        = " CreateOpt.py [options] topPath ioc dbOutPath"
parser = OptionParser(usage=usage,
		 version="%%prog 1.0",
    		 description="USAGE: applictionIndex.py [-h OPTIONS] topPath")
parser.add_option("-v","--verbose",
		 action="store_true", # default: None
		 help="print debug information", 
    		 )
try:
    (options,args) = parser.parse_args()
    (topPath,) = args
except:
    print usage
    sys.exit()

(appDb,dbApp) = findApplications(topPath)
#pp.pprint(appDb)
#pp.pprint(dbApp)
(iocDb,dbIoc) = processStCmd(topPath)
#pp.pprint(iocDb)
#pp.pprint(dbIoc)
##hwList = checkHardwareAccess({'IOC':['hwAccess.IOC2LHF.db']},topPath)
iocHw = checkHardwareAccess(iocDb,topPath)
##pp.pprint(iocHw)

######## PRINT DATA #######################################################
htmlHeader = """<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="de" lang="de">
<head>
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
filename = "reference.html"
try :
    FILE = open(filename,"w") 
except IOError: 
    eU.die("can't open input file: "+filename)

print >> FILE, htmlHeader

# Application Reference:
print "********** Write File *********"
print >> FILE, "<H1>Application Reference</H1>\n\n<TABLE BORDER=1>"
def getIoc(dbIoc,db):
    if dbIoc.has_key(db):   
    	return reduce(lambda y,x:y+str("<A HREF=\"#"+x+"\">"+x+"</A><br>"),dbIoc[db],"")
    else: 
    	return "not loaded on IOC"

for app in appDb.keys():
    dbList = appDb[app]
    span = ""
    if len(dbList) > 1: span = "ROWSPAN=\""+str(len(dbList))+"\" "
    print >> FILE, "<TR >\n  <TD "+span+"VALIGN=\"TOP\"><A NAME=\""+app+"\">"+app+"</TD>\n  <TD VALIGN=\"TOP\">"+dbList[0]+"</TD>\n  <TD>"+getIoc(dbIoc,dbList[0])+"</TD></TR>"
    for db in dbList[1:]:
	print >> FILE,"<TR>\n  <TD VALIGN=\"TOP\">"+db+"</TD>\n  <TD VALIGN=\"TOP\">"+getIoc(dbIoc,db)+"</TD></TR>"
print >> FILE, "</TABLE>\n"

print >> FILE, '<H1>IOC Application Reference</H1>\n\n<TABLE BORDER=1>'

def getDb(dbApp,db):
    if dbApp.has_key(db): return "<DIV TITLE=\""+dbApp[db]+"\"><A HREF=\"#"+dbApp[db]+"\">"+db+"</A></DIV>"
    else: return "<DIV TITLE=\"got from support module\">"+db+"</DIV>"

for ioc in iocDb.keys():
    dbList = iocDb[ioc]
    span = ""
    if len(dbList) > 1: span = "ROWSPAN=\""+str(len(dbList))+"\" "
    print >> FILE, '<TR >\n  <TD '+span+'VALIGN="TOP"><A NAME="'+ioc+'"><A HREF="#HW_'+ioc+'">'+ioc+'</A></TD>\n  <TD>'+getDb(dbApp,db)+'</TD></TR>'
    for db in dbList[1:]:
	print >> FILE,"<TR>\n  <TD>"+getDb(dbApp,db)+"</TD></TR>"
print >> FILE, "</TABLE>\n"

print >> FILE, "<H1>IOC Hardware Reference</H1>\n\n"

def toCol(dList,tag='TD'): 
    """ create a list of taged list item strings, default is TD, also possible: TH, LI"""
    return "<"+tag+">"+str("</"+tag+">\n  <"+tag+">").join(dList)+"</"+tag+">"

(forgetThisList,getHw) = filterHardware(iocHw,{'DTYP':['HwClient','Dist Version','IOC stats','Raw Soft Channel','Soft Channel','Soft Timestamp','Soft Timestamp WA','VX stats','VxWorks Boot Parameter']})
for ioc in iocDb.keys():
    (iocHwList,getHw) = filterHardware(getHw,{'iocname':ioc})
    if len(iocHwList) == 0: 
    	continue

    print >> FILE, '<H2><A NAME="HW_'+ioc+'">'+ioc+'</H2>\n\n'

    print >> FILE, "<H3>CAN Devices</H3>\n\n"
    order = ('port','nid','cid','CARD','CHAN','LINK','pvname','filename')
    (canList,otherList) = filterHardware(iocHw,{'DTYP':['lowcal'],})
    table = sortedHardwareToTable(canList,order)
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
    (vmeList,otherList) = filterHardware(otherList,{'DTYP':['esd AIO16','ADA16','BESSY MuxV','Dyncon','EK IO32','ESRF MuxV','Highland DDG V85x','OMS MAXv','OMS VME58','Rfmux1366','TDU','V375','V680','VHQ','Vpdu']})
    order = ('DTYP','CARD','CHAN','pvname','LINK')
    table = sortedHardwareToTable(vmeList,order)
    if len(table) > 0:
	print >> FILE, "<TABLE BORDER=1>\n<TR>"+toCol(['Process Variable','Card','Chan','DTYP','Link'],'TH')+"\n</TR>"
	for (DTYP,CARD,CHAN,pvname,LINK) in table:
	    print >> FILE, "<TR>"+toCol([pvname,CARD,CHAN,DTYP,LINK])+"\n</TR>"
	print >> FILE, "</TABLE>\n"

    print >> FILE, "<H3>Other Devices</H3>\n\n"
    order = ('LINK','pvname')
    table = sortedHardwareToTable(otherList,order)
    if len(table) > 0:
	print >> FILE, "<TABLE BORDER=1>\n<TR>"+toCol(['Process Variable','Link'],'TH')+"\n</TR>"
	for (link,pv) in table:
	    print >> FILE, "<TR>"+toCol([pv,link])+"\n</TR>"
	print >> FILE, "</TABLE>\n"

print >> FILE, htmlFooter
FILE.close()
 
