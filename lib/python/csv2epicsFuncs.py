"""
  The helper functions of the csv2epics script to be used in local modules that
  define local templates

 *  Author  B.Kuner
"""

import csv
import math
import os.path
import epicsUtils

class csvData(object):
    """ Store splitted, line of a csv file and store it's data to be used for template and record processing
    	First version is just store the data as in a hash
    """
    def __init__(self,device,canOption,lines) :
	try: self.dev        = device[0].strip() # A  devicname
	except IndexError: self.dev = ""
	try: self.rtype      = device[1].strip() # B  record-, template type
	except IndexError: self.rtype = ""
	try: self.signal     = device[2].strip() # C  BESSY Signalname
	except IndexError: self.signal = ""

	try: self.port       = device[3].strip() # D is string SPS Symbolname (else CAN-Id / VME DTYP)
	except IndexError: self.port = ""
	if canOption != 'opc':
	    try: self.port   = int(self.port)    # D is int: CAN-Port
	    except ValueError: 
		try:
	    	    self.port = int(canOption)   # CAN-port set by argument
		except ValueError:
	    	    if len(self.port) != 0:
	    		epicsUtils.die("ERROR: illegal argument -can: '"+str(device[3])+"' assumed here to be empty or a can port number",lines)

	try: self.canId     = device[4].strip()  # E  CAN-Id / VME DTYP (else SPS Symbolname)
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
	self.DESC = self.DESC.decode("UTF-8").encode("ISO-8859-1")      # konversion to ISO for edm!
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
    
def getDisplayLimits(rangeEng,egu,signal=None,lines=None):
    eng = epicsUtils.matchRe(rangeEng,"([-+\d][\d\.eE]*)\s*\-\s*([-+\d][\d\.eE]*)*")
    if eng == None or len(eng) != 2:
    	epicsUtils.die("Need range Eng. for signal "+signal,lines)
    return({'LOPR':float(eng[0]),'HOPR':float(eng[1]),'EGU':egu});
    
def createLimits(rangeEng,rangeRaw,rangeAlhVal,rangeAlhSevr,signal=None,lines=None):
    """
    Create limits for analog type records

    - If 'rangeRaw' is defined: Create konversion parameters 
    - rangeAlhVal has to be in order with rangeAlhSevr to define alarm ranges and severities
      rangeAlhVal can be followed by arbitrary additional fields to be set for records, so the 
      rangeAlhVal fields have to be  set outside this function
    """
#    print "createLimits(rangeEng='",rangeEng,"', rangeRaw='",rangeRaw,"', rangeAlhVal='",rangeAlhVal,"', rangeAlhSevr='",rangeAlhSevr,"', signal='",signal,"')"
#    if lines is None: print "createLimits(rangeEng='",rangeEng,"', rangeRaw='",rangeRaw,"', rangeAlhVal='",rangeAlhVal,"', rangeAlhSevr='",rangeAlhSevr,"', signal='",signal,"')"

    (lopr,hopr) = epicsUtils.matchRe(rangeEng,"\s*(.*)\s*\-\s*(.*)\s*")
    lopr = float(lopr)
    hopr = float(hopr)
    dtype = ""	    # for CAN data - s=short, S=unsigned short
    field = {}
    if rangeAlhVal != "":
	aFields=epicsUtils.parseParam(rangeAlhVal)
	field.update(aFields)
	
	limitVals = rangeAlhVal.split("|")  	# ATTENTION: preserve the order of alarm and severity fields
	limitSevr = rangeAlhSevr.split("|")
	if len(limitSevr[0]) > 0:   # means not empty severities
	    for (v,s) in zip(limitVals,limitSevr):  
		(valName,val)     = v.split("=")
		if valName   == 'LOLO': field['LLSV'] = s
		elif valName == 'LOW':  field['LSV']  = s
		elif valName == 'HIGH': field['HSV']  = s
		elif valName == 'HIHI': field['HHSV'] = s
		else: epicsUtils.die("Illegal Alarm value '"+valName+"' in signal: "+signal,lines)
    
    raw = epicsUtils.matchRe(rangeRaw,"\s*(.*)\s*\-\s*(.*)\s*")
#    if lines is None: print lopr, hopr, raw
    if raw is not None:
	lraw=float(raw[0])
	hraw=float(raw[1])
	egul  = 0.0
	eguf  = 0.0
	slope = 0.0
	off   = 0.0
	hyst  = 0.0
	full  = 0.0
	minVal=0
    	convert = 'SLOPE'   # LINEAR not supported yet
	
    #  die "CAN data type is unsigned short, so only positive limits supported" if( lopr is not 0 || lraw is not 0 )

	if  (hopr != 0) and ( hraw != 0 ):
      	    if (lraw < 0) or (hraw < 0 ):         # signed value
		dtype = "s"
		full = 32767
		minVal = -32767
    	    else:                                 # unsigned
		dtype = "S"
		full = 65535
	    if convert == "LINEAR":
		egul = lopr - slope * (lraw-minVal)
		eguf = egul + slope * 65535
		field['LINR'] = 'LINEAR'
		field['EGUL'] = egul
		field['EGUF'] = eguf
	    elif convert == "SLOPE":
		slope = (hopr - lopr) / (hraw - lraw)
		off  = hopr - slope * hraw
		field['LINR'] = 'SLOPE'
		field['ESLO'] = slope
		field['EOFF'] = off
	    prec =  int(math.log(float(hopr)/10000)/math.log(10.0))
    #ORGINAL: prec = ( ( prec >= 0 ) ? 0 : -prec ) + 1
	    if prec < 0 : 
		prec = (-1 * prec)+1
	    else:
		prec = 0
	    hyst = hopr / hraw * 0.99
	    field['PREC'] = prec
	    field['HYST'] = hyst
	    field['ADEL'] = hyst
	    field['MDEL'] = hyst
	else:
      	    epicsUtils.die("Raw/engineering limit mismatch (raw: hraw / eng: hopr)",lines)
#    if lines is None: print field
    return (field,dtype)

def getBinaryAttributes(rangeEng,rangeRaw,rangeAlhSevr,fields,fileName,lines):

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
	    warnings.append([fileName,lines,"Skip: ",devName,"Illegal rangeRaw (Col: I): \'"+rangeRaw+"\'"])
	    raise ValueError
	r = rangeAlhSevr.split("|")
	if isinstance(r,list) is True and r[0] != '':	# No alarms is ok, but..
	    if len(r) == rangeLen:
		rangeALH =  map(lambda x: x.strip(),r)
	    else:
		warnings.append([fileName,lines,"Skip: ",devName,"Illegal length of rangeAlh (Col: L): \'"+rangeAlhSevr+"\'"])
	    	raise ValueError
	else:  	    	    	    	    	    	# .. fake a NO_ALARM range
	    rangeALH = map(lambda x: "NO_ALARM",range(rangeLen))
    else:
	warnings.append([fileName,lines,"Skip: ",devName,"Illegal rangeEng (Col: J): \'"+rangeEng+"\'"])
    return (rangeENG,rangeRAW,rangeALH)

def createAnalogRecord(rtype,devName,fields,rangeEng,rangeRaw,egu,rangeAlhVal,rangeAlhSevr,signal,fileName,lines):
#    print "createAnalogRecord",rtype,devName,signal,fields,rangeEng,rangeRaw,rangeAlhVal,rangeAlhSevr
    fields.update(getDisplayLimits(rangeEng,egu,signal,lines))
    (limitParams,dtype) = createLimits(rangeEng,rangeRaw,rangeAlhVal,rangeAlhSevr,devName+":"+signal,lines)
    fields.update(limitParams)
    epicsUtils.epicsTemplate(rtype,{'DEVN':devName},fields)
    
def createBiBoRecord(rtype,devName,fields,rangeEng,rangeRaw,rangeAlhSevr,signal,fileName,lines):
    (rangeENG,rangeRAW,rangeALH) = getBinaryAttributes(rangeEng,rangeRaw,rangeAlhSevr,fields,fileName,lines)

    # set name and severitie fields
    idx=0
    if rtype == 'bi':
	rtype = 'mbbi'	# no use of mbbiDirect so bits by longin and mbbi SHFT
	fields['DTYP'] = "Raw Soft Channel"
    	fields['NOBT'] = '1'
	for state in ["ZR", "ON"]:
	    if epicsUtils.hasIndex(rangeENG,idx) is False:
		break
            namStr = rangeENG[idx]
	    l = len(namStr)
	    if l > 19:
		d = namStr[0:19] +" | " + namStr[19:l]
		namStr = namStr[0:19]
		warnings.append([fileName,lines,"Truncate bi/bo string",devName,d])
	    fields[state+"ST"]=namStr
	    fields[state+"VL"]=idx
	    if epicsUtils.hasIndex(rangeALH,idx) is True:
		if rangeALH[idx] != '' and rangeALH[idx] != 'NO_ALARM':
		    fields[state+"SV"]=rangeALH[idx]
            idx += 1
    else:    	
	for state in ["Z", "O"]:
	    if epicsUtils.hasIndex(rangeENG,idx) is None:
		break
            namStr = rangeENG[idx]
	    l = len(namStr)
	    if l > 19:
		d = namStr[0:19] +" | " + namStr[19:l]
		namStr = namStr[0:19]
		warnings.append([fileName,lines,"Truncate bi/bo string",devName,d])
	    fields[state+"NAM"]=namStr
	    if epicsUtils.hasIndex(rangeALH,idx) is True:
		if rangeALH[idx] != '' and rangeALH[idx] != 'NO_ALARM':
		    fields[state+"SV"]=rangeALH[idx]
            idx += 1
    epicsUtils.epicsTemplate(rtype,{'DEVN':devName},fields)
    
def createMbbIoRecord(rtype,devName,fields,rangeEng,rangeRaw,rangeAlhSevr,signal,fileName,lines):
    (rangeENG,rangeRAW,rangeALH) = getBinaryAttributes(rangeEng,rangeRaw,rangeAlhSevr,fields,fileName,lines)
    tooLong = False

    pvName = devName+":"+signal
    if len(rangeENG) > 16 :
	warnings.append([fileName,lines,"Truncate mbb modes"+pvName+" "+str(len(rangeENG))+", max=16"])

    idx = 0
    for state in ["ZR","ON","TW","TH","FR","FV","SX","SV","EI","NI","TE","EL","TV","TT","FT","FF"]:
	if epicsUtils.hasIndex(rangeENG,idx) is True:
	    if len(rangeENG[idx]) > 15 :
		tooLong=True
	else:
	    break
        idx += 1

    if (tooLong == False) or (rtype == "mbbo") :
        dbRec = epicsUtils.epicsTemplate(rtype,{'DEVN':devName},fields)
        idx=0
        for state in ["ZR","ON","TW","TH","FR","FV","SX","SV","EI","NI","TE","EL","TV","TT","FT","FF"] :
            if epicsUtils.hasIndex(rangeENG,idx) is False:
		break   # rangeENG[index]

	    namStr = rangeENG[idx]
	    if len(namStr) > 15:
		d = namStr[0:15] +" | " + namStr[15:l]
		namStr = namStr[0:15]
		warnings.append([fileName,lines,"Truncate mbb string",pvName,d])
            dbRec.field[state+"ST"]=namStr
            dbRec.field[state+"VL"]=rangeRAW[idx]
	    if epicsUtils.hasIndex(rangeALH,idx) is True:
		dbRec.field[state+"SV"]=rangeALH[idx]

            idx +=1 
    else:   # mbbi with long string names: each string gets a stringout !
        fields['SNAME'] = fields['SNAME']+'Raw'
	dbRec = epicsUtils.epicsTemplate(rtype,{'DEVN':devName},fields)
        idx=0
        stringOuts = ""
        seq = epicsUtils.epicsTemplate('seq',{'DEVN':devName},{'SNAME':signal+"S1",
		'SELM':"Specified", 
		'SELL':pvName+"C1 CP NMS",
		'SDIS':fields['SDIS'],'DISS':fields['DISS']
		})
	seqNr=1
        for state in ["ZR","ON","TW","TH","FR","FV","SX","SV","EI","NI","TE","EL","TV","TT","FT","FF"]:
            if epicsUtils.hasIndex(rangeENG,idx) is False:
		  break
            #d = substr(rangeENG[idx],0, 15) ." | " .substr(rangeENG[idx],15, length(rangeENG[idx]) )
            #push @warnings, [fileName,lines,"Truncate mbb string",pvName,d] if ( length(rangeENG[idx]) > 15 )
            if idx == 9 :
        	seq2 = epicsUtils.epicsTemplate('seq',{'DEVN':devName},{'SNAME':signal+"S2",
		    	'SELM':"Specified", 
			'SELL':pvName+"C2 CP NMS",
			'SDIS':fields['SDIS'],'DISS':fields['DISS']
			})
		seqNr=2
	    if seqNr==1:
		seq.field["LNK"+str(idx+1)]   = pvName+"St"+str(idx)+".PROC PP NMS"
	    else:
		seq2.field["LNK"+str(idx%9+1)] =  pvName+"St"+str(idx)+".PROC PP NMS"
            if (epicsUtils.hasIndex(rangeRAW,idx) is True) and (rangeRAW[idx] != '0'):
		dbRec.field[state+"VL"] = rangeRAW[idx]
	    	if epicsUtils.hasIndex(rangeALH,idx) is True:
		    dbRec.field[state+"SV"] = rangeALH[idx]
            eng = rangeENG[idx]
	    l = len(eng)
	    if l > 39:
		d = eng[0:39]+" | "+ eng[40:l]
		eng = eng[0:39]
		warnings.append([fileName,lines,"Truncate mbb string",pvName,d])
            epicsUtils.epicsTemplate('stringout',{'DEVN':devName},{'SNAME':signal+"St"+str(idx),
        	    		    'VAL':eng,
        			    'OUT':pvName+" PP NMS",
				    'SDIS':fields['SDIS'],'DISS':fields['DISS']})
	    idx += 1

    	epicsUtils.epicsTemplate('calc',{'DEVN':devName},{'SNAME':signal+"C1",
        		      'CALC': "(A<9)?A+1:0",
        		      'INPA': pvName+"Raw CP NMS",
			      'SDIS':fields['SDIS'],'DISS':fields['DISS']})
        epicsUtils.epicsTemplate('calc', {'DEVN':devName},{'SNAME':signal+"C2",
        		      'CALC': "(A>=9)?A-8:0",
        		      'INPA': pvName+"Raw CP NMS",
			      'SDIS':fields['SDIS'],'DISS':fields['DISS']})
	epicsUtils.epicsTemplate('stringin', {'DEVN':devName},{'SNAME':signal,
        		      'SIML': pvName+"Raw.SIMM NPP MS",
			      'SDIS':fields['SDIS'],'DISS':fields['DISS']})

