# -*- coding: utf-8 -*-

# Copyright 2015 Helmholtz-Zentrum Berlin für Materialien und Energie GmbH
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

"""
 *  Author  B.Kuner

  Collection of Functions:
  
* Helper functions of the csv2epics script and to be used in local modules that
  define substitutions for local template files.

- class csvData(object):
  This object contains the data from then .csv file. Adaption to other file 
  formats has to be done just here!

- def setupPlugins(searchPathList): read all plugins
  read all plugins for templates to be used

* Support Hardware links, functions for HZB specific hardware: CAN Bus and 
  DTYP lowcal but also VME cards, OPC devices and WAGO-I/O-SYSTEM accessed 
  by ModbusTCP coupler.

- def setupRecordLink(devName,devObj,canOption,opc_name,iocTag,fileName,lines):
- def getOpcLink(PLCLink,rtyp,bits,device_name,opc_name,lines,fileName):
class PLC_Address(object):
- def getVmeLink()
- def getCANLink()
- def getWagoLink()

* Process record attributes for display, alarms etc from the special columns

- def getShiftParam(bits):
- def getEcName(port,canId,cardNr,namesEnd):
- def adaCanMux(id,card,chan,typ='hex'):
- def createAdaCanLink(port,id,card,chan):

- def getDisplayLimits(rangeEng,egu,signal=None,lines=None):
- def createLimits(rangeEng,rangeRaw,rangeAlhVal,rangeAlhSevr,signal=None,lines=None):
- def getBinaryAttributes(rangeEng,rangeRaw,rangeAlhSevr,fields,fileName,lines):

* Create complete Record

- def procRecord(devName,devObj,canOption,opc_name,iocTag,warnings,lines,fileName):

- def createAnalogRecord(rtype,devName,fields,rangeEng,rangeRaw,egu,rangeAlhVal,rangeAlhSevr,signal,fileName,lines):
- def createBiBoRecord(rtype,devName,fields,rangeEng,rangeRaw,rangeAlhSevr,signal,fileName,lines):
- def createMbbIoRecord(rtype,devName,fields,rangeEng,rangeRaw,rangeAlhSevr,signal,fileName,lines):

* Process epic alh data

- def epicsAlh(devName,alhSig,devObj,lines)

* Builtin Templates (for convenience only)

- def watchdogGetFunc():
- def watchdog(devName,devObj,canOption,opc_name,iocTag,warnings,lines,fileName):

- def pt100tempGetFunc():
- def pt100temp(devName,devObj,canOption,opc_name,iocTag,warnings,lines,fileName):
"""

import csv
import math
import sys
import imp
import os
#import os.path
import epicsUtils
import pprint

class csvData(object):
    """ Store splitted, line of a csv file and store it's data to be used for 
        template and record processing. 
	
	Other file formats have to be mapped in a derived object with this member 
    variables to process correctly.
	
	Hold constants to check stringlengths dependant on the EPICS version.

	- def getRecNameLen():
	- def getDESClen():
	- def getMBBlen():
	- def getNAMlen():
	- def getStringVALlen():
    """
    def __init__(self,device,canOption) :
	self.disableRec = None
	try: self.dev        = device[0].strip() # A  devicname
	except IndexError: self.dev = ""
	try: self.rtype      = device[1].strip() # B  record-, template type
	except IndexError: self.rtype = ""
	try: self.signal     = device[2].strip() # C  BESSY Signalname
	except IndexError: self.signal = ""

	try: self.port       = device[3].strip() # D is string SPS Symbolname
	except IndexError: self.port = ""
	if canOption != 'opc':
	    try: self.port   = int(self.port)    # D is int: CAN-Port
	    except ValueError: 
	        try:
	            self.port = int(canOption)   # D CAN-port set by argument
	        except ValueError:
	            pass    	    	    	 # my be a string for use outside CAN e.g.wago device

	try: self.canId     = device[4].strip()  # E  CAN-Id / VME DTYP
	except IndexError: self.canId = ""
	try: self.cardNr    = device[5].strip()  # F  Card-Nr / Siemens Access rights
	except IndexError: self.cardNr = ""
	try: self.chan       = device[6].strip()  # G  binary: Inputbits bi/bo: nr, mbbi/o start-stop: e.g. 5-7 -> SHFT=5, NOBT=3 
	except IndexError: self.chan = ""
	try: self.rangeRaw   = device[7].strip()  # H  Datenbereich Rohdaten binary: '2|15|33', ai: '0-65535'
	except IndexError: self.rangeRaw = ""
	try: self.rangeEng   = device[8].strip()  # I  Datenbereich ENG     binary Named:'True|False|Invalid', anlog:' 0-100'
	except IndexError: self.rangeEng = ""
    	try: self.egu        = device[9].strip()  # J  Engeneering unit 
	except IndexError: self.egu = ""
	self.egu = self.egu.decode("UTF-8").encode("ISO-8859-1")      # konversion to ISO for edm!
	try: self.rangeAlhVal= device[10].strip() # K  BESSY Alarm-Werte     anlog: LOLO=-5|HIGH=12
	except IndexError: self.rangeAlhVal = ""
        try: self.rangeAlhSevr=device[11].strip() # L  BESSY Alarm-Zustand   anlog, bi : 'NO_ALARM|MINOR|MAJOR|INVALID'
	except IndexError: self.rangeAlhSevr = ""
	try: self.DESC       = device[12].strip() # M  BESSY Description
	except IndexError: self.DESC = ""

        # conversion to ISO for edm:
        # for decoding an encoding we catch the UnicodeEncodeError exception
        # and re-raise an exception that prints the string that caused the
        # problem:
        try:
            decoded = self.DESC.decode("UTF-8")
        except UnicodeEncodeError,e:
            raise ValueError("%s, string before UTF8 decode: %s" % \
                             (str(e),repr(self.DESC)))
        try:
            self.DESC = decoded.encode("ISO-8859-1")
        except UnicodeEncodeError,e:
            raise ValueError("%s, string before UTF-8 decode: %s, string "
                             "after UTF-8 decode: %s" % \
                             (str(e),repr(self.DESC),repr(decoded)))

	try: self.prec       = device[13].strip() # N  BESSY Prec
	except IndexError: self.prec = ""
	try: self.archPeriod = device[14].strip() # O  BESSY Arch
	except IndexError: self.archPeriod = ""
	try: self.reqFlag    = device[15].strip() # P  BESSY SR
	except IndexError: self.reqFlag = ""
	try: self.alhGroup   = device[16].strip() # Q  BESSY ALH Group
	except IndexError: self.alhGroup = ""
	self.alhGroup = self.alhGroup.decode("UTF-8").encode("ISO-8859-1")      # konversion to ISO for edm!
	try: self.alhFlags   =device[17].strip()  # R  BESSY ALH Flags
	except IndexError: self.alhFlags = ""
	try: self.alhSort    = device[18].strip() # S  BESSY ALH Sort
	except IndexError: self.alhSort = ""
	try: self.panelName  = device[19].strip() # T  BESSY Panel name extended to panel Name: <panel>.edl
	except IndexError: self.panelName = ""
	try: self.panelGroup = device[20].strip() # U  BESSY Panel Group
	except IndexError: self.panelGroup = ""
	self.panelGroup = self.panelGroup.decode("UTF-8").encode("ISO-8859-1")      # konversion to ISO for edm!
    	try: self.panelSort  = device[21].strip() # V BESSY Panel Sort
	except IndexError: self.panelSort = ""
	try: self.dbFileName = device[22].strip() # W  Filename for .db or .substitutions File
	except IndexError: self.dbFileName = ""
	
    def __str__(self):
       return "*** csvData Object:\ndev: '"+self.dev+"'\nrtype: '"+self.rtype+"'\nsignal: '"+self.signal+"'\nport: '"+self.port+"'\nport: '"+self.port+"'\ncanId: '"+self.canId+\
       "'\ncardNr: '"+self.cardNr+"'\nchan: '"+self.chan+"'\nrangeRaw: '"+self.rangeRaw+"'\nrangeEng: '"+self.rangeEng+"'\negu: '"+self.egu+\
       "'\nrangeAlhVal: '"+self.rangeAlhVal+"'\nrangeAlhSevr: '"+self.rangeAlhSevr+"'\nDESC: '"+self.DESC+"'\nprec: '"+self.prec+\
       "'\narchPeriod: '"+self.archPeriod+"'\nreqFlag: '"+self.reqFlag+"'\nalhGroup: '"+self.alhGroup+"'\nalhFlags: '"+self.alhFlags+\
       "'\nalhSort: '"+self.alhSort+"'\npanelName: '"+self.panelName+"'\npanelGroup: '"+self.panelGroup+"'\npanelSort: '"+self.panelSort+"'\nEPICS File Name: '"+self.dbFileName+"'\n*** End"
class baseData(object):
# EPICS R3.14. String lengths as found in: aiRecord.h, mbbiRecord.h mbbiDirectRecord.h
    base = "3.14.8"
    baseLen={	    	    # C-strings, so usable length is len-1
	'3.14.8': {'RecName': 60,# record name	 
		  'DESClen': 28,# DESC field
		  'ASGlen': 28, # ASG field
		  'MBBlen': 15, # mbbi/mbbo strings
		  'NAMlen': 19, # bi/bo ONAM, ZNAM
		  'StringVALlen': 39, # stringin/stringout VAL
	    	 },
	'3.14.12': {'RecName': 60,# record name	 
		  'DESClen': 40,# DESC field
		  'ASGlen': 28, # ASG field
		  'MBBlen': 25, # mbbi/mbbo strings
		  'NAMlen': 25, # bi/bo ONAM, ZNAM
		  'StringVALlen': 39, # stringin/stringout VAL
	    	 }
	    	}
    @staticmethod
    def setBase(baseStr):
    	if baseData.baseLen.has_key(baseStr):
	    baseData.base = baseStr
	    return 1
	else:
	    return None
    @staticmethod
    def getRecNameLen():    return baseData.baseLen[baseData.base]['RecName']
    @staticmethod
    def getDESClen():       return baseData.baseLen[baseData.base]['DESClen']
    @staticmethod
    def getMBBlen():        return baseData.baseLen[baseData.base]['MBBlen']
    @staticmethod
    def getNAMlen():        return baseData.baseLen[baseData.base]['NAMlen']
    @staticmethod
    def getStringVALlen():  return baseData.baseLen[baseData.base]['StringVALlen']

recordSet = {'longin':'INP','longout':'OUT','ai':'INP','ao':'OUT','bi':'INP','bo':'OUT','mbbi':'INP','mbbo':'OUT','sel':None,'calc':None,'seq':None,'calcout':None,'mbbiDirect':'INP','mbboDirect':'OUT'}
def procInOut(rtyp):
    """ Is it a in or out record type? Return 'INP'|'OUT' for records or 
    templates that begin with a known record name from the list: 
    
    'longin,longout,ai,ao,bi,bo,mbbi,mbbo,mbbiDirect,mbboDirect'
    
    Other records or templates return 'None'
    """
    if recordSet.has_key(rtyp):
    	return  recordSet[rtyp]
    else:
    	for rec in recordSet.keys():
	    if rtyp.find(rec,0) == 0:
	    	return recordSet[rec]
    return None

def setupPlugins(searchPathList):
    funcs = {}
    for pluginPath in searchPathList:
        if not os.path.exists(pluginPath): 
            continue
        pluginFiles = [fname[:-3] for fname in os.listdir(pluginPath) if fname.endswith("Plugin.py")]
        if not pluginPath in sys.path:
            sys.path.insert(0,pluginPath)

        impModules = [__import__(fname) for fname in pluginFiles]
        for mod in impModules:
            (s,f) = mod.getFunc()
            funcs[s]=f
    funcs.update(pt100tempGetFunc())    # add local pt100temp support
    funcs.update(watchdogGetFunc())    # add local watchdog support

    return funcs

def getShiftParam(bits):
    """
    Bitrange to paramteres NOBT, SHFT. Parameter bits = 'n' or bits = 'n - m' ,
    SHIFT = n, NOBT = nr of elements.
    Return tupel: (NOBT,SHFT),  NOBT=1 for bits = 'n'
    E.G getShiftParam('5 - 7') = (3,5), getShiftParam('7') = (1,7)
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
    mux    = frmt%(int(card)*12+int(chan),)
    return (outCan,inCan,mux)

def createAdaCanLink(port,id,card,chan):
    """
    Setup a complete CAN link from adaCanMux data:

    Return "@f s 5 PORT OUTCAN INCAN MUX 10 1F4 0" % (int(port),outCan,inCan,mux)
    """
    (outCan,inCan,mux) = adaCanMux(id,card,chan)
    return "@f s 5 %X %s %s %s 10 1F4 0" % (int(port),outCan,inCan,mux)

def getDisplayLimits(rangeEng,egu):
    """
    Return a dict with the the display parameters: LOPR, HOPR, EGU or raise ValueError
    """
    eng = epicsUtils.matchRe(rangeEng,"([-+\d][\d\.eE]*)\s*\-\s*([-+\d][\d\.eE]*)*")
    if eng == None or len(eng) != 2:
        raise ValueError("Range Eng. not defined")
    return({'LOPR':float(eng[0]),'HOPR':float(eng[1]),'EGU':egu});
    
def createAlarmLimits(rangeAlhVal,rangeAlhSevr):
    field = {}
    if rangeAlhVal != "":
        field=epicsUtils.parseParam(rangeAlhVal)

    limitVals = rangeAlhVal.split("|")      # ATTENTION: preserve the order of alarm and severity fields
    limitSevr = rangeAlhSevr.split("|")
    if len(limitSevr[0]) > 0:   # means not empty severities
        for (v,s) in zip(limitVals,limitSevr):  
            (valName,val)     = v.split("=")
            if valName   == 'LOLO': field['LLSV'] = s
            elif valName == 'LOW':  field['LSV']  = s
            elif valName == 'HIGH': field['HSV']  = s
            elif valName == 'HIHI': field['HHSV'] = s
            else: 
                raise ValueError("Illegal Alarm value '"+valName+"'")
    return field

def createLimits(rangeEng,rangeRaw,rangeAlhVal,rangeAlhSevr):
    """
    Create limits severities and conversion parameters for analog type records or 
    raise ValueError

    - If 'rangeRaw' is defined: Create conversion parameters for SLOPE conversion

    - rangeAlhVal has to be in order with rangeAlhSevr to define alarm ranges 
      and severities

    - rangeAlhVal can be followed by arbitrary additional fields to be set for 
      records, so the 

    - rangeAlhVal fields have to be  set outside this function
    """
#    print "createLimits(rangeEng='",rangeEng,"', rangeRaw='",rangeRaw,"', rangeAlhVal='",rangeAlhVal,"', rangeAlhSevr='",rangeAlhSevr,"', signal='",signal,"')"
#    if lines is None: print "createLimits(rangeEng='",rangeEng,"', rangeRaw='",rangeRaw,"', rangeAlhVal='",rangeAlhVal,"', rangeAlhSevr='",rangeAlhSevr,"', signal='",signal,"')"

    (lopr,hopr) = epicsUtils.matchRe(rangeEng,"\s*(.*)\s*\-\s*(.*)\s*")
    lopr = float(lopr)
    hopr = float(hopr)
    dtype = ""        # for CAN data - s=short, S=unsigned short
    field = createAlarmLimits(rangeAlhVal,rangeAlhSevr)
    
    # process raw range to setup data conversion with 'SLOPE'
    raw = epicsUtils.matchRe(rangeRaw,"\s*(.*)\s*\-\s*(.*)\s*")
    if raw is not None:
        convert = 'SLOPE'   # LEGACY LINEAR not supported yet
        lraw=float(raw[0])
        hraw=float(raw[1])
        egul  = 0.0         # LEGACY, NOT used yet
        eguf  = 0.0         # LEGACY, NOT used yet
        slope = 0.0
        off   = 0.0
        hyst  = 0.0
        full  = 0.0         # LEGACY, NOT used yet
        minVal=0            # LEGACY, NOT used yet

        # setup 
        if  (hopr != 0) and ( hraw != 0 ):
            if (lraw < 0) or (hraw < 0 ):       # signed value LEGACY, NOT used yet
                dtype = "s"
                full = 32767
                minVal = -32767
            else:                               # unsigned LEGACY, NOT used yet
                dtype = "S"
                full = 65535
            if convert == "LINEAR":             # LEGACY, NOT used yet
                egul = lopr - slope * (lraw-minVal)
                eguf = egul + slope * 65535
                field['LINR'] = 'LINEAR'
                field['EGUL'] = egul
                field['EGUF'] = eguf
            elif convert == "SLOPE":            # SLOPE conversion is done: linear conversion from raw to eng
                slope = (hopr - lopr) / (hraw - lraw)
                off  = hopr - slope * hraw
                field['LINR'] = 'SLOPE'
                field['ESLO'] = slope
                field['EOFF'] = off
                prec =  int(math.log(float(hopr)/10000)/math.log(10.0))

            if prec < 0 : 
                prec = (-1 * prec)+1
            else:
                prec = 0

            field['PREC'] = prec
        else:
            raise ValueError("Raw/engineering limit mismatch (raw: hraw / eng: hopr)")
#    if lines is None: print field
    return (field,dtype)

def getBinaryAttributes(rangeEng,rangeRaw,rangeAlhSevr,fields,fileName,lines,warnings):
    """ Process columns that define values, strings and severities for binary records 
    	from definitions in Col H,I,K
	
	Return the checked data as python lists or raise ValueError
    """
    rangeENG = []
    rangeRAW = []
    rangeALH = []
    r = rangeEng.split("|")
    if isinstance(r,list) is True and len(r)>1:
	rangeENG = map(lambda x: x.strip(),r)
	rangeLen = len(r)
	r = rangeRaw.split("|")
	if isinstance(r,list) is True and len(r) == rangeLen:
	    rangeRAW = map(lambda x: x.strip(),r)
	else:
	    raise ValueError("Illegal rangeRaw (Col: I): \'"+rangeRaw+"\'")
	r = rangeAlhSevr.split("|")
	if isinstance(r,list) is True and r[0] != '':	# No alarms is ok, but..
	    if len(r) == rangeLen:
		rangeALH =  map(lambda x: x.strip(),r)
	    else:
	    	raise ValueError("Illegal length of rangeAlh (Col: L): \'"+rangeAlhSevr+"\'")
	else:  	    	    	    	    	    	# .. fake a NO_ALARM range
	    rangeALH = map(lambda x: "NO_ALARM",range(rangeLen))
    else:
	raise ValueError("Illegal rangeEng (Col: J): \'"+rangeEng+"\'")
    return (rangeENG,rangeRAW,rangeALH)

def createAnalogRecord(devName,fields,devObj,warnings,fileName,lines):
    """ Setup display and alarm limits and create an analog type record/template. 

    INP/OUT link has to be set before so this function is usable for all records, 
    templates that make use of the typical analog fields as HOPR,LOPR,EGU,PREC 
    and LOLO,LOW,HIGH,HIHI + according severities.
    """
#    print "createAnalogRecord",devObj.rtype,devName,devObj.signal,fields,devObj.rangeEng,devObj.rangeRaw,devObj.rangeAlhVal,devObj.rangeAlhSevr
    fields.update(getDisplayLimits(devObj.rangeEng,devObj.egu))
    (f,dtype) = createLimits(devObj.rangeEng,devObj.rangeRaw,devObj.rangeAlhVal,devObj.rangeAlhSevr)
    f.update(fields)	# additional parameters should override calculated values for PREC
    epicsUtils.epicsTemplate(devObj.rtype,{'DEVN':devName},f,devObj.dbFileName)
    
def createBiBoRecord(devName,fields,devObj,warnings,fileName,lines):
    """ Setup fields for bi/bo type records/templates and create instance
    - Setup fields for state names and severities from the columns H,I,K
    - Don't setup SHFT here!
    - Create warnings for to long strings
    """
    #print "createBiBoRecord(",devName,devObj.signal,fields,warnings,fileName,lines
    try:
    	(rangeENG,rangeRAW,rangeALH) = getBinaryAttributes(devObj.rangeEng,devObj.rangeRaw,devObj.rangeAlhSevr,fields,fileName,lines,warnings)
    except ValueError, e:
    	warnings.append([fileName,lines,"SKIP RECORD: ",devName+":"+devObj.signal,str(e)])
    	return
    # set name and severity fields
    idx=0
	
    for state in ["Z", "O"]:
	if epicsUtils.hasIndex(rangeENG,idx) is None:
	    break
        namStr = rangeENG[idx]
	l = len(namStr)
	if l > baseData.getNAMlen():
	    warnings.append([fileName,lines,"TRUNCATE bi/bo string",devName+":"+devObj.signal,namStr[0:baseData.getNAMlen()] +"<TRUNC>" + namStr[(baseData.getNAMlen()):]])
	    namStr = namStr[0:baseData.getNAMlen()]
	fields[state+"NAM"]=namStr
	if epicsUtils.hasIndex(rangeALH,idx) is True:
	    if rangeALH[idx] != '' and rangeALH[idx] != 'NO_ALARM':
		fields[state+"SV"]=rangeALH[idx]
        idx += 1

    epicsUtils.epicsTemplate(devObj.rtype,{'DEVN':devName},fields,devObj.dbFileName)
    
def createMbbIoRecord(devName,fields,devObj,warnings,fileName,lines):
    """ Setup fields for mbbi/mbbo type records/templates and create instance

    - Setup fields for state names, severities and values from the columns H,I,K
    - Don't setup SHFT,NOBT here!
    - Support for mbbi record and long strings: create stringout records for 
      each string
    - Create warnings for to long strings
    """
    #print "createMbbIoRecord(",devName,devObj.signal,fields,warnings,fileName,lines
    (rangeENG,rangeRAW,rangeALH) = getBinaryAttributes(devObj.rangeEng,devObj.rangeRaw,devObj.rangeAlhSevr,fields,fileName,lines,warnings)
    tooLong = False

    pvName = devName+":"+devObj.signal
    if len(rangeENG) > 16:
	warnings.append([fileName,lines,"Truncate mbb modes",pvName,"nr of modes="+str(len(rangeENG))+ "(max 16)"])

    idx = 0
    for state in ["ZR","ON","TW","TH","FR","FV","SX","SV","EI","NI","TE","EL","TV","TT","FT","FF"]:
	if epicsUtils.hasIndex(rangeENG,idx) is True:
	    if len(rangeENG[idx]) > baseData.getMBBlen() :
		tooLong=True
	else:
	    break
        idx += 1

    if (tooLong == False) or (devObj.rtype == "mbbo") :
        dbRec = epicsUtils.epicsTemplate(devObj.rtype,{'DEVN':devName},fields,devObj.dbFileName)
	idx=0
        for state in ["ZR","ON","TW","TH","FR","FV","SX","SV","EI","NI","TE","EL","TV","TT","FT","FF"] :
            if epicsUtils.hasIndex(rangeENG,idx) is False:
		break   # rangeENG[index]

	    namStr = rangeENG[idx]
	    if len(namStr) > baseData.getMBBlen():
		
		warnings.append([fileName,lines,"TRUNCATE mbb string",pvName,namStr[0:baseData.getMBBlen()] +"|" + namStr[baseData.getMBBlen():]])
		namStr = namStr[0:baseData.getMBBlen()]
            dbRec.field[state+"ST"]=namStr
            dbRec.field[state+"VL"]=rangeRAW[idx]
	    if epicsUtils.hasIndex(rangeALH,idx) is True:
		dbRec.field[state+"SV"]=rangeALH[idx]

            idx +=1 
    else:   # mbbi with long string names: each string gets a stringout !
        fields['SNAME'] = fields['SNAME']+'Raw'
	dbRec = epicsUtils.epicsTemplate(devObj.rtype,{'DEVN':devName},fields,devObj.dbFileName)
        idx=0
        stringOuts = ""
        seq = epicsUtils.epicsTemplate('seq',{'DEVN':devName},{'SNAME':devObj.signal+"S1",
		'SELM':"Specified", 
		'SELL':pvName+"C1 CP NMS",
		'SDIS':fields['SDIS'],'DISS':fields['DISS']
		},devObj.dbFileName)
	seqNr=1
	for state in ["ZR","ON","TW","TH","FR","FV","SX","SV","EI","NI","TE","EL","TV","TT","FT","FF"]:
            if epicsUtils.hasIndex(rangeENG,idx) is False:
		  break
            #d = substr(rangeENG[idx],0, baseData.getMBBlen()) ." | " .substr(rangeENG[idx],baseData.getMBBlen(), length(rangeENG[idx]) )
            #push @warnings, [fileName,lines,"Truncate mbb string",pvName,d] if ( length(rangeENG[idx]) > baseData.getMBBlen() )
            if idx == 9 :
        	seq2 = epicsUtils.epicsTemplate('seq',{'DEVN':devName},{'SNAME':devObj.signal+"S2",
		    	'SELM':"Specified", 
			'SELL':pvName+"C2 CP NMS",
			'SDIS':fields['SDIS'],'DISS':fields['DISS']
			},devObj.dbFileName)
		seqNr=2
	    if seqNr==1:
		seq.field["LNK"+str(idx+1)]   = pvName+"St"+str(idx)+".PROC PP NMS"
	    else:
		seq2.field["LNK"+str(idx%9+1)] =  pvName+"St"+str(idx)+".PROC PP NMS"

	    if epicsUtils.hasIndex(rangeRAW,idx) is True:
		dbRec.field[state+"VL"] = rangeRAW[idx]
	    if epicsUtils.hasIndex(rangeALH,idx) is True:
		dbRec.field[state+"SV"] = rangeALH[idx]
            eng = rangeENG[idx]
	    if len(eng) > baseData.getStringVALlen():
		warnings.append([fileName,lines,"TRUNCATE mbb string",pvName,eng[0:baseData.getStringVALlen()]+" | "+ eng[evObj.getStringVALlen():]])
		eng = eng[0:baseData.getStringVALlen()]
            epicsUtils.epicsTemplate('stringout',{'DEVN':devName},{'SNAME':devObj.signal+"St"+str(idx),
        	    		    'VAL':eng,
        			    'OUT':pvName+" PP NMS",
				    'SDIS':fields['SDIS'],'DISS':fields['DISS']},devObj.dbFileName)
	    idx += 1

    	epicsUtils.epicsTemplate('calc',{'DEVN':devName},{'SNAME':devObj.signal+"C1",
        		      'CALC': "(A<9)?A+1:0",
        		      'INPA': pvName+"Raw CP NMS",
			      'SDIS':fields['SDIS'],'DISS':fields['DISS']},devObj.dbFileName)
        epicsUtils.epicsTemplate('calc', {'DEVN':devName},{'SNAME':devObj.signal+"C2",
        		      'CALC': "(A>=9)?A-8:0",
        		      'INPA': pvName+"Raw CP NMS",
			      'SDIS':fields['SDIS'],'DISS':fields['DISS']},devObj.dbFileName)
	epicsUtils.epicsTemplate('stringin', {'DEVN':devName},{'SNAME':devObj.signal,
        		      'SIML': pvName+"Raw.SIMM NPP MS",
			      'SDIS':fields['SDIS'],'DISS':fields['DISS'],'DESC':fields['DESC']},devObj.dbFileName)

def procRecord(devName,devObj,canOption,opc_name,iocTag,warnings,lines,fileName):
    """ Is an EPICS record in: 
    ['ai','ao','longin','longout','bi','bo','mbbi','mbbo','calc','calcout']
        Setup EPICS record and return other data: 
        (alhSignals,arcSignals,panelDict,panelNameDict,panelWidgetName)
    """
    sdis       = ''
    if devObj.disableRec:
        sdis= devObj.disableRec+" CP"
    alhSignals = []         # templates may have a list of signals for alarm handler
    arcSignals = []         # templates may have a list of signals for archiver
    panelDict = {}          # panel widget macro data
    panelNameDict = {}      # panel widget PV name in form of {'TAG':pvName} dictionary
    panelWidgetName = None  # default widget name for this record/template may be overwritten by col.V (Panel Sort)
    autoSRRequest = []      # signals for autoSaveRestore

    if (len(devName)+len(devObj.signal)+1) > baseData.getRecNameLen():
        warnings.append([fileName,lines,"WARN: ",devName+":"+devObj.signal,"Record name length excedet max="+str(baseData.getRecNameLen())])
    
    fields = {}
    fields.update(epicsUtils.parseParam(devObj.prec)) # Common fieles from Col. N
    if devObj.rtype in recordSet.keys():

        pvName = devName+":"+devObj.signal
        alhSignals.append(devObj.signal)
        arcSignals.append(devObj.signal)
        fields['SNAME']= devObj.signal
        fields['DISS']= 'INVALID'
        fields['SDIS']= sdis
        fields['DESC']= devObj.DESC
        try:
            if len(devObj.reqFlag) > 0:
                if len(devObj.reqFlag) <= 1:
                    autoSRRequest.append(devName+":"+devObj.signal)
                else:
                    for signal in devObj.reqFlag.split("|"):
                        autoSRRequest.append( devName+":"+signal)

            # is a record type that has INP/OUT link, is able to supports hardware access
            if procInOut(devObj.rtype) is not None:     
                l=None
                fields.update(setupRecordLink(devName,devObj,canOption,opc_name,iocTag))
                
                if devObj.rtype in ('ai','ao','longin','longout') :
                    createAnalogRecord(devName,fields,devObj,warnings,fileName,lines)
                elif devObj.rtype in ('mbbiDirect','mbboDirect') :
                    fields.update({'NOBT': 16,})
                    epicsUtils.epicsTemplate(devObj.rtype,{'DEVN':devName},fields,devObj.dbFileName)
                elif devObj.rtype in ('bi','bo'):
                        createBiBoRecord(devName,fields,devObj,warnings,fileName,lines)
                elif devObj.rtype in ('mbbi','mbbo'):
                        createMbbIoRecord(devName,fields,devObj,warnings,fileName,lines)
            else: # Soft record, fields from Col. N
                epicsUtils.epicsTemplate(devObj.rtype, {'DEVN':devName}, fields,devObj.dbFileName)
        except ValueError, e:
            warnings.append([fileName,lines,"WARN",pvName,str(e)])

        if devObj.rtype in ('bo') :
            panelDict.update({'SNAME':devObj.signal,'EGU':devObj.egu,'DESC':devObj.DESC})
            panelWidgetName = "bo"
        elif devObj.rtype in ('ao','longout') :
            panelDict.update({'SNAME':devObj.signal,'EGU':devObj.egu,'DESC':devObj.DESC})
            panelWidgetName = "ao"
        elif devObj.rtype in ('mbbo') :
            panelDict.update({'SNAME':devObj.signal,'EGU':devObj.egu,'DESC':devObj.DESC})
            panelWidgetName = "mbbo"
        else:
            panelDict.update({'SNAME':devObj.signal,'EGU':devObj.egu,'DESC':devObj.DESC})
            panelWidgetName = "anyVal"
        panelNameDict.update({'DEVN':devName})
    else:
        return None
    return (autoSRRequest,alhSignals,arcSignals,panelDict,panelNameDict,panelWidgetName)

def setupRecordLink(devName,devObj,canOption,opc_name,iocTag):
    """ Decide which type of hardware is to be processed. All entrys but 'don't care' are mandatory.
    
    Device type      | option -c     | Col. D   | Col. E    | Col. F    | Col. G    | processed in
    -----------------+---------------+----------+-----------+-----------+-----------+-------------
    Bessy CAN Device | empty/CAN-Port| CAN-Port | CAN-Id    | Card Nr.  | Chan. Nr  | getCANLink()
    VME-Device       | don't care    | empty    | DTYP      | Card Nr.  | Chan. Nr  | getVmeLink()
    OPC Device       | opc           | OPC-Link | don't care| don't care| don't care| getOpcLink()
    Wago Device      | don't care   |MODBUS-Port| wago[Type]| Offset    | Bits      | getWagoLink()
    Soft record      | don't care    |empty     | empty     | empty     | empty     | return
    """
    if type(devObj.port) == int:
        return getCANLink(devObj.rtype,devObj.port,devObj.canId,devObj.cardNr,devObj.chan,devName,iocTag,devObj)
    if (len(devObj.port) == 0) and(len(devObj.canId) == 0) and(len(devObj.cardNr) == 0) and(len(devObj.chan) == 0):
        return {}	# is a soft record

    if len(devObj.port) == 0:
        return getVmeLink(devObj.rtype,devObj.canId,devObj.cardNr,devObj.chan)

    if canOption == 'opc':
        return getOpcLink(devObj,devName,opc_name)

    if epicsUtils.matchRe(devObj.canId,'^wago') is not None:
        return getWagoLink(devObj)
    else:
        raise ValueError("Illegal Link")
        
def getOpcLink(devObj,devName,opc_name):
    """
    Create an OPC Link for option '-c opc', CAN or VME links are not supported in 
    this mode!

    * Handle OPC-links (col. D) of type

    - Just a String
    - Siemens notation of Servername,Datablock and byte address (
      e.g. 'S7:[S7-Verbindung_1]DB2,X2.6')

    * Set the fields DTYP, SCAN, INP/OUT according to the record type

    * For binary records there are mbbi/oDirect records to read/write the data and
      distribute it to/from the binary records. Set the fields NOBT, SHFT.
    """
    PLCLink = devObj.port
    rtyp    = devObj.rtype
    bits    = devObj.chan
# print "getOpcLink "+ "%12s %20s %10s %s"%(rtyp,PLCLink,str(bits),(devName+":"+devObj.signal)) 
    if devName is None:
        raise ValueError("Missign option -n devName for common mbb_Direct record",lines)
    fields = {}
    linkType = procInOut(rtyp)
    if linkType is None:
    	raise ValueError("No known link type for record/template:'"+rtyp+"'. INP/OUT expected")
    elif linkType == 'INP':
    	fields['PINI'] = 'YES'
    	
    if len(bits) == 0:
# 1. check for Siemens DB link type with bit definition e.g. S7:[S7-Verbindung_1]DB2,X0.0
        l = epicsUtils.matchRe(PLCLink,".*DB(\d+),(\w)(\d+)\.(\d+)")  # S7:[S7-Verbindung_1]DB2,X0.0
        if l is not None:
            if  opc_name is None: 
	    	raise ValueError("Missing -m plc-name option")

            if rtyp not in ('bi','bo'):
	    	raise ValueError("ERROR: Link '"+PLCLink+"' doesn't support rtype: '"+rtyp+"' (bi/bo only)")
	    (db,typ,byte,bit) = l

            if typ == 'X':
                byte = int(byte)
                bit  = int(bit)
                db   = int(db)
                if byte%2 != 0: # align to word boundaries
                    byte -= 1
                else:
                    bit += 8
		hwLink = opc_name+"DB"+str(db)+",W"+str(byte)
		softLinkTag = str(db)+"_"+str(byte)
		fields[linkType] = PLC_Address(linkType,rtyp,hwLink,softLinkTag,bit,devName,devObj).getLink()
        	fields['DTYP'] = "Soft Channel"
#		if devObj.rtype == 'bi':    	    	# OPCIOCBUG: map bi with set bits to mbbi and longin
#		    devObj.rtype = 'mbbi'   	    	#
#        	    fields['SHFT'] = bit    	    	#
#		    fields['DTYP'] = "Raw Soft Channel" #
#        	    fields['NOBT'] = 1	    	    	#
#		    fields[linkType] = epicsUtils.substRe(fields[linkType],"\.B[\dABCDEF]","") #end OPCIOCBUG
            else:
                raise ValueError("unknown datatype '"+typ+"' in: '"+PLCLink+"'")
# 2. bits not set: direct access for all record types
        else:
#	    if rtyp == 'bi':
#	    	fields['DTYP'] = "opcRaw"
#	    else:
#	    	fields['DTYP'] = "opc"
	    if (len(devObj.rangeRaw)>0) and (rtyp in ('ai','ao')):
	    	fields['DTYP'] = "opc raw"
	    else:
	    	fields['DTYP'] = "opc"
            fields[linkType] = '@'+PLCLink
	    if linkType == 'INP':
        	fields['SCAN'] = "I/O Intr"
	    if epicsUtils.matchRe(rtyp,"^mbb[io].*") is not None:
    		fields['NOBT'] = 16
    elif rtyp in ('bi','mbbi','bo','mbbo'):     # access via mbb_Direct from OPC Server Byte/Word data
#	if devObj.rtype == 'bi':    	    	# OPCIOCBUG: map bi with set bits to mbbi and longin
#	    devObj.rtype = 'mbbi'
#	    rtyp = 'mbbi'
        (nobt,shft) = getShiftParam(bits)
        fields['SHFT'] = shft
	if  rtyp in ['mbbi','mbbo']:
            fields['DTYP'] = "Raw Soft Channel"
            fields['NOBT'] = nobt
	else:
            fields['DTYP'] = "Soft Channel"
	    
# 3. check for Siemens DB link type without bit definition e.g. S7:[S7-Verbindung_1]DB2,X0
        l = epicsUtils.matchRe(PLCLink,".*DB(\d+),(\w)(\d+)")  # S7:[S7-Verbindung_1]DB2,X0.0

        if l is not None:
            (db,typ,byte) = l
            byte = int(byte)
            db   = int(db)
            if  opc_name is None: raise ValueError("Missing -m plc-name option")
            if typ != 'W':
                raise ValueError("unknown datatype '"+typ+"' in: '"+PLCLink+"' (W for Word expected")
    	    else:
		hwLink = opc_name+"DB"+str(db)+",W"+str(byte)
		softLinkTag = str(db)+"_"+str(byte)
		fields[linkType] = PLC_Address(linkType,rtyp,hwLink,softLinkTag,shft,devName).getLink()
# 4. process a string type with bits set - binary records only
        else:
	    fields[linkType] = PLC_Address(linkType,rtyp,PLCLink,PLCLink,shft,devName,devObj).getLink()
    else:
    	raise ValueError("NOT SUPPORTED: Record type '"+rtyp+"' AND set Channel/Bits (Col. G) '"+bits+"'")
        
    return fields

class PLC_Address(object):
    """
    Class to manage PLC address names links for the binary record types: 
    bi,bo,mbbi,mbbo
    
    * Map bits to mbbi/oDirect-Records to access the data and
    
    * Store all data to create this mbbi/oDirect-Records with setupTemplates(). 
      This is the reason why this is a class and not just a function
    """
    mbbiTagIndex=0
    mbboTagIndex=0
    inTagPrefix  = "inBits"
    outTagPrefix = "outBits"
    mbbiDirectLinks = {}  # (hardWareLink,signalName) for all mbbiDirect records
    mbboDirectLinks  = {} # (hardWareLink,signalName) for all mbboDirect records

    def __init__(self,linkTyp,rtyp,PLCLink,softLinkTag,shft,deviceName,devObj) :
        self.link = None

	if linkTyp == 'INP':
            if not PLC_Address.mbbiDirectLinks.has_key(softLinkTag) :
                PLC_Address.mbbiDirectLinks[softLinkTag] = ("@"+PLCLink,PLC_Address.inTagPrefix+str(PLC_Address.mbbiTagIndex))
                PLC_Address.mbbiTagIndex += 1
            (hwLink,sTag) = PLC_Address.mbbiDirectLinks[softLinkTag]
            self.link = deviceName+":"+sTag+" CPP MS"
        elif linkTyp == 'OUT':
            if not PLC_Address.mbboDirectLinks.has_key(softLinkTag) :
                PLC_Address.mbboDirectLinks[softLinkTag] = ("@"+PLCLink,PLC_Address.outTagPrefix+str(PLC_Address.mbboTagIndex))
                PLC_Address.mbboTagIndex += 1
            (hwLink,sTag) = PLC_Address.mbboDirectLinks[softLinkTag]
        else :
            raise ValueError("Unknown output type: '"+linkTyp+"'. INP|OUT expected")

        if rtyp == 'mbbo':
            self.link = deviceName+":%s PP NMS" % (sTag,)
        elif rtyp == 'bo':
            self.link = deviceName+":%s.B%X PP NMS" % (sTag,shft)
        elif rtyp == 'mbbi':
            self.link = deviceName+":%s CPP MS" % (sTag,)
        elif rtyp == 'bi':
            self.link = deviceName+":%s.B%X CPP MS" % (sTag,shft)

    def getLink(self): return self.link

    @staticmethod
    def setupTemplates(deviceName,dtypHw,dbFileName):
        """
        Create epicsTemplate objects for all mbb_Direct records as indicated in 
        mbb_DirectLinks dictionary
        """
        for tag in PLC_Address.mbbiDirectLinks.keys():
            (link,signalName) = PLC_Address.mbbiDirectLinks[tag]
            epicsUtils.epicsTemplate('mbbiDirect', {'DEVN':deviceName},{'SNAME':signalName, # OPCIOCBUG: don't take mbbiDirect, but longin
                      	'DESC': tag[len(tag)-20:len(tag)],
                      	'DTYP': dtypHw,
                      	'PINI': "YES",
                      	'SCAN': "I/O Intr",
                    	'NOBT': "16",	# OPCIOCBUG: no NOBT for the longin 
                      	'INP':  link},dbFileName)
        for tag in PLC_Address.mbboDirectLinks.keys():
            (link,signalName) = PLC_Address.mbboDirectLinks[tag]
            epicsUtils.epicsTemplate('mbboDirect', {'DEVN':deviceName},{'SNAME':signalName,
                      	'DESC': tag[len(tag)-26:len(tag)],
                      	'DTYP': dtypHw,
                      	'NOBT': "16",
                      	'OUT':  link},dbFileName)
def getVmeLink(rtyp,canId,cardNr,chan):
    fields = {}
    if rtyp in ('ai','longin','bi','mbbi','mbbiDirect',):
        linkTyp = 'INP'
    elif rtyp in ('ao','longout','bo','mbbo','mbboDirect'):
        linkTyp = 'OUT'
    else:
	raise ValueError("Record type not supported: "+rtyp)

    fields['DTYP'] = canId
    (nobt,shft) = getShiftParam(chan)
    if (rtyp in ('mbbi','mbbiDirect','mbbo','mbboDirect')):
        fields['NOBT'] = nobt
        fields['SHFT'] = shft
        fields[linkTyp] = "#C%dS0"% (int(cardNr),)
    elif rtyp in ('bi','bo','ai','longin','ao','longout'):  # access direct to card/channel
        fields[linkTyp] = "#C%dS%d"% (int(cardNr),int(shft))
    return (fields)

def getCANLink(rtyp,port,canId,cardNr,chan,name,iocTag,devObj):
    """
    Create an CAN Link.
    
    * For CAN links and binary records there is support to create mbbiDirect 
    records to read the data and distribute it to the binary records.
    """
    fields = {}
    #print "getCANLink(",rtyp,port,canId,cardNr,chan,name,lineNr,")"
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
	hasPv = epicsUtils.epicsTemplate.getPV(hwDeviceName,hwSignal)
	if len(hasPv) < 1:
	    f = {'DESC'  :'Access Port:'+str(port)+", Id:"+str(canId)+", card:"+str(cardNr),
                 'NOBT'  :'16',
                 'DTYP'  :'lowcal',
                 'SNAME' : hwSignal,
                 linkName: createAdaCanLink(port,canId,cardNr,mux)
                }
	    if linkName == 'INP':
		f['SCAN'] = "1 second"
            epicsUtils.epicsTemplate(recType,{'DEVN':hwDeviceName},f,devObj.dbFileName)

        (nobt,shft) = getShiftParam(chan)
        if rtyp  == 'bi':
            fields[linkName]= "%s:%s.B%X CPP MS" % (hwDeviceName,hwSignal,shft)
        elif rtyp  == 'bo':
            fields[linkName]= "%s:%s.B%X PP NMS" % (hwDeviceName,hwSignal,shft)
        else:   # mbbi, mbbo
    	    fields['DTYP'] = "Raw Soft Channel" # has to convert with NOBT/SHFT
	    if rtyp  == 'mbbi':
    	    	fields[linkName]= "%s:%s CPP MS" % (hwDeviceName,hwSignal)
    	    if rtyp  == 'mbbo':
    	    	fields[linkName]= "%s:%s PP NMS" % (hwDeviceName,hwSignal)
            fields['NOBT']= nobt
            fields['SHFT']= shft
    return (fields)

def getWagoLink(devObj):
    """ WAGO-I/O-SYSTEM by Modbus process data architecture:
    
    Bit read/write by modbus function FC2/5 - read/write single coil. Specify
    the bit count starting with 0
    
    Analog values read/write by modbus function FC3/16 read/write multiple 
    registers. Specify the channel by the word count.
    
    Special conversion for temperature modules with wago Tag in Col.E = 'wagoTemp'
    """
    fields = {}
    if devObj.rtype in ['ai','ao']:
        fields.update({'DTYP': "asynInt32"})
        fields.update(getDisplayLimits(devObj.rangeEng,devObj.egu))

        if epicsUtils.matchRe(devObj.canId,'^wagoTemp') is not None: # special conversion for Temperature modules
            fields.update({'LINR': "SLOPE",
                'ASLO': 0.1,
                'AOFF': 0,
                })
        else:
            #Linear conversion from real raw values 16bit hex to EGUL,EGUF defined in Column H. Col.I means just HOPR/LOPR
            raw = epicsUtils.matchRe(devObj.rangeRaw,"\s*(.*)\s*\-\s*(.*)\s*") 
            if raw is None:
                raise ValueError("Col.H Raw Value not defined")
            fields.update({'LINR': "LINEAR",
                    'EGUL': raw[0],
                    'EGUF': raw[1],
                    })
            
        if devObj.rtype == 'ai':
            fields.update({'INP': "@asynMask("+devObj.port+" "+devObj.cardNr+" "+devObj.chan+")MODBUS_DATA",'SCAN':"I/O Intr"})
        else:
            fields.update({'OUT': "@asynMask("+devObj.port+" "+devObj.cardNr+" "+devObj.chan+")MODBUS_DATA"})
             
    elif devObj.rtype == 'bo':
        fields.update({ 'DTYP': "asynUInt32Digital",
                        'PINI':'YES',
                        'OUT': "@asynMask("+devObj.port+" "+devObj.cardNr+" 0x1)"})
    elif devObj.rtype == 'bi':
        fields.update({'DTYP': "asynUInt32Digital",
                       'SCAN':"I/O Intr",
                       'INP': "@asynMask("+devObj.port+" "+devObj.cardNr+" 0x1)"})
            
    return (fields)

"""
Setup a epicsAlh signal. Define default values. These may be overridden by 
'ALH Flag' data (col. T)
"""
def alhItem(devName,sig,devObj):
    nodePath = devObj.alhGroup
    sort     = None
    tags     = {}
#    print "\nalhItem: '"+"', '".join( (devName,sig,devObj.alhGroup,devObj.alhFlags,devObj.alhSort))+"'"
    if devObj.alhSort and len(devObj.alhSort)>0:
        sort = devObj.alhSort

    if devObj.panelName and len(devObj.panelName)>0:
        panel   = devObj.panelName
        command = "run_edm.sh "+devObj.panelName+".edl"
    else:
        egu = " "
        if len(devObj.egu) > 0: egu = devObj.egu
        command = "run_edm.sh -m \"PV="+devName+":"+sig+",DESC="+devObj.DESC+",EGU="+egu+"\" alhVal.edl"
    tags['COMMAND'] = command
    
    tags['ALIAS'] = devName+": "+devObj.DESC
    tags['ALARMCOUNTFILTER'] = "2 1"

    tagList = devObj.alhFlags.split("|")
    if len(tagList)>0 and len(tagList[0])>0:
        # legacy support: first element may be the mask. Better set MASK=.. in ALH-Flags column.
        try:        
            (name,value) = epicsUtils.matchRe(tagList[0],"([\w_]+)\s*=\s*(.*)")
        except TypeError: # no name=value
            tags['MASK'] = epicsUtils.epicsAlh.setMask(tagList[0])   # first element means mask
            tagList = tagList[1:]

        # process tagList, may override defaults
        for tag in tagList:
            try:
                (name,value) = epicsUtils.matchRe(tag,"([\w_]+)\s*=\s*(.*)")
                if   name == 'COMMAND': 
                    tags['COMMAND'] = value
                elif name == 'ALIAS':
                    tags['ALIAS']   = value
                elif name == 'ALARMCOUNTFILTER':
                    tags['ALARMCOUNTFILTER'] = value
                elif name == 'MASK':
                    tags['MASK'] = epicsUtils.epicsAlh.setMask(value)
                elif name in ('CHANNEL','INCLUDE','GROUP','END'):
                    raise ValueError("ALH Flag (col. T) '"+name+"' is not allowed here")
                else:
                    tags[name] = value
            except TypeError: # no name=value
                raise ValueError('Illegal name-value pair in ALH-Flags (col R): '+tag)
    epicsUtils.epicsAlh(devName,sig,nodePath,tags,sort)

"""
Setup all data to  write an alarm handler file.

- Each object holds the data to describe one alarmhandler item (see epicsAlh docu)

The Collumns for Alarm definition:

- BESSY ALH Group (col. Q): The Path to the alarm group the first element is 
  the name of the alh file!
- BESSY ALH Flags(col. R):  Optional. First the alarm Flags (CDT..) Than a 
  list of additional Items for
    a CHANNEL definition in this format: ITEM<SPACE>value e.g.

        "ALIAS=show this|MASK=T|ACKPV=ackPVName ackValue"
        
    or legacy mask definition as first Element:

        "T|ALIAS=show this|ACKPV=ackPVName ackValue"

    Not allowed are the Items: 'CHANNEL','INCLUDE','GROUP','END'

    Defaults:

        Flags: ---T-
        ALIAS: name signal
        ALARMCOUNTFILTER: 2 1
        COMMAND: None or edm epicsPanel if defined in 'EPICS Panel Name' (col. U)

- ALH Sort (col. S):   An optional sort number to define the order within a group
"""
def epicsAlh(devName,alhSignals,devObj):
    if len(alhSignals) == 0:
        return
    firstSig = alhSignals[0]
    alhSignals = alhSignals[1:]
    alhItem(devName,firstSig,devObj)
    if( alhSignals ):
        for alhSig in alhSignals:
            alhItem(devName,alhSig,devObj)
        

def watchdogGetFunc():
    return {"watchdog":watchdog}

def watchdog(devName,devObj,canOption,opc_name,iocTag,warnings,lines,fileName):
    alhSignals = None
    arcSignals = None
    panelDict = {}
    panelWidgetName = "anyVal"
    if len(devObj.signal)>0:
        devName = devName+":"+devObj.signal
    panelNameDict={'DEVN':devName}

    fields = epicsUtils.parseParam(devObj.prec)
    epicsUtils.epicsTemplate('bi',{'DEVN':devName},{'SNAME':"stHeartBeat",
	'DESC':"CPU-Heartbeat",
	'SCAN':"I/O Intr",
	'PINI':"YES",
	'DTYP':"opc",
	'INP':"@"+devObj.port,
	'ZNAM':"Heart",
	'ONAM':"Beat",
	'FLNK':devName+":fwdHeartBeat"},devObj.dbFileName)
    epicsUtils.epicsTemplate('bo',{'DEVN':devName},{'SNAME':"fwdHeartBeat",
	'DOL':devName+":stHeartBeat",
	'OUT':devName+":intWdgCounter PP",
	'ONAM':"Beat",
	'ZNAM':"Heart",
	'HIGH':"1"},devObj.dbFileName)
    epicsUtils.epicsTemplate('calcout',{'DEVN':devName},{'SNAME':"intWdgCounter",
	'INPA':devName+":intWdgCounter.VAL NPP NMS",
	'INPB':fields['TMO'],
	'CALC':"A+1",
	'SCAN':"1 second",
	'OUT':devName+":disable PP NMS",
	'OCAL':"A>B?1:0",
	'DOPT':"Use OCAL"},devObj.dbFileName)
    epicsUtils.epicsTemplate('bi', {'DEVN':devName}, {'SNAME':"disable",
    	'DESC':"Disable: "+devName,
	'INP': devName+":intWdgCounter.OVAL NPP NMS",
	'ZNAM':"enable",
	'ONAM':"disable",
	'OSV':"MAJOR"},devObj.dbFileName)
    return (alhSignals,arcSignals,panelDict,panelNameDict,panelWidgetName)
  
def pt100tempGetFunc():
    return {"pt100temp":pt100temp}

def pt100temp(devName,devObj,canOption,opc_name,iocTag,warnings,lines,fileName):
    alhSignals = ("rdTemp",)
    arcSignals = ("rdTemp",)
    panelNameDict={'DEVN':devName}
    panelDict = {}
    panelWidgetName = "temp"
    try:
    	hwname = getEcName(devObj.port,devObj.canId,devObj.cardNr,iocTag)
    except ValueError:
    	epicsUtils.die("ERROR: "+devName+" CAN definition Port=\'"+devObj.port+"\' Id: \'"+devObj.canId+"\' Card: \'"+devObj.cardNr+"\''",lines)

    if len(epicsUtils.epicsTemplate.getDevice(hwname)) == 0:
	(co,ci,mux) = adaCanMux(devObj.canId,devObj.cardNr,0,'dec')
	mux=int(devObj.cardNr)*12

	epicsUtils.epicsTemplate("pt100dev",{'DEVN':hwname},{
	    'CANPORT': devObj.port,
	    '0XSINOBJ':"%X"%(128+int(devObj.canId)),
	    '0XSOUTOBJ':"%X"%(192+int(devObj.canId)),
	    '0XSMUX':"%X"%(int(devObj.cardNr)*4+17),
	    'INOBJ':ci,
	    'OUTOBJ':co,
	    'C0MUX':mux,
	    'C1MUX':mux+1,
	    'C2MUX':mux+2,
	    'C3MUX':mux+3,
	    'C4MUX':mux+4,
	    'C5MUX':mux+5,
	    'C6MUX':mux+6,
	    'C7MUX':mux+7
	    },devObj.dbFileName)
    fields = epicsUtils.parseParam(devObj.prec)
    if devObj.egu == "K":	    # template default is Grad-C
	fields['EGUF'] = "657.16"
	fields['EGUL'] = "145.16"
	fields['EGU'] = "K"
    fields['DESCR'] = devObj.DESC
    fields['SDIS']  = ''
    fields['HWNAME']= hwname
    devObj.chan = int(devObj.chan)
    if devObj.chan<8: 
	ch  = 1
	sub = devObj.chan
    else:      
	ch  = 2
	sub = devObj.chan-8
    statnr = "%X"%(devObj.chan)
    fields['CHAN']  = ch
    fields['STATNR']= statnr
    fields['SUB']   = sub
    createAnalogRecord(devName,fields,devObj,warnings,fileName,lines)
    return (alhSignals,arcSignals,panelDict,panelNameDict,panelWidgetName)
