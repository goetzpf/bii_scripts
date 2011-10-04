""" canlink - the python implementation of the Perl module for the encoding and
decoding of the MultiCAN CAN Link definition.

DESCRIPTION
***********

This module contains functions that are used to decode and encode
the EPICS hardware link definition that is used in MultiCAN. The EPICS
device and driver support for the CAN bus that was developed for the
HZB II control system.
Note that HZB has the copyright on this software. It may not be used
or copied without permission from HZB.

Implemented Functions:
=====================

def warn(x):  print x
def decode (linkStr):
def calc_cidnidsob(linkParams):
def cob2cidnid(cob):
def cob2sobnid(cob):

The property hash
=================

The property-hash may have the following contents:

*  server:  This field specifies wether the host is a CAL server or a CAL 
server. Set this field to "1" for a server, and "0" for a client.

*  multi:  This field specifies the multiplex-type. Set this field "1" 
for a multiplex-variable, and "0" for a basic-variable.

*  access:  This field specifies the accessability of the CAL variable. Set 
is to "r" for a read-only variable, to "w" for a write-only variable and
to "rw" for a read-write variable.

*  type:  This specifies the basic data-type of the CAL variable. Known types
are "zero", "string", "char", "short", "mid" and "long". "mid" is a
special, 24-bit integer, "zero" is a datatyoe with a length of 
0 bytes.

*  raw:  This field specifies, whether the CAL byte-order is used (little-endian
format) or wether the byte-order is left as it is. Set "0" to enforce CAL
byte-order, and "1" for current byte order.

*  signed:  This field is only used, when the C<type> is not "string". Set it to
"1" if the basic type (see C<type>) is signed, or "0" if it is
unsigned.

*  array:  This field defines, wether a CAL array-variable is used. In this
case, several elements of the basic type (see C<type>) are packed
into a single CAN frame. But note, that a CAN frame has a maximum
length of 8 bytes. Set to "1" for array-variables or "0" else.

*  maxlength:  This is the actual length of the CAN frame in bytes.

*  port:  This is the number of the output-port (see sci - documentation for
details).

*  out_cob:  This is the COB for the outgoing CAN-object.

*  in_cob:  This is the COB for the incoming CAN-object.

*  multiplexor:  This is the multiplexor-index. It is only needed for multiplex variables
(see C<multi>).

*  inhibit:  This is the inhibit-time in milliseconds. Note that this is a 
floating-point number.

*  timeout:  This is the timeout in milliseconds. This parameter is an integer.

*  arraysize:  This is the size (that means number of elements) of the CAL array. 
This field is only needed, if the CAL variable is an array (see C<array>).

*  nid:  This is the node-id of the CAL-server.

*  cid:  This is the channel-id of the CAL variable.

*  in_sob:  This is the sub-object id of the incoming CAN object.

*  out_sob:  This is the sub-object id of the outgoing CAN object.

Specification of a CAL variable via the property hash
=======================================================

In order to define a CAL variable by using the property hash,
the following fields are always mandatory:

- access
- type
- port
- inhibit
- timeout

Here is a list of fields that can be used, but have a default, when
they are not specified:

-  server:  default: 0
-  multi:  default: 0
-  multiplexor:  mandatory when C<multi> is "1"
-  signed:  default: 0
-  array:  default: 0
-  arraysize:  mandatory when C<array> is "1"
-  raw:  default:0, mandatory when C<type> is neither "string" nor "char"

Specifying the COB's that are actually used, is a bit complicated. There
are 3 ways:

1. Specify the COB's directly. In this case, the fields C<in_cob> and
C<out_cob> must be specified.

2. Specify NID and IN-SOB and OUT-SOB. In this case, the node-id of the
server, C<nid>, the IN-SOB, C<in_sob> and the OUT-SOB, C<out_sob>
must be specified.

3. Specify NID and CID, in this case, define C<nid> and C<cid>
"""
import epicsUtils as eU

char_list= {  'a': {"server":0,"multi":0, "access":'r'  },
              'b': {"server":0,"multi":0, "access":'w'  },
              'c': {"server":0,"multi":0, "access":'rw' },
              'd': {"server":0,"multi":1, "access":'r'  },
              'e': {"server":0,"multi":1, "access":'w'  },
              'f': {"server":0,"multi":1, "access":'rw' },
              'g': {"server":1,"multi":0, "access":'r'  },
              'h': {"server":1,"multi":0, "access":'w'  },
              'i': {"server":1,"multi":0, "access":'rw' },
              'j': {"server":1,"multi":1, "access":'r'  },
              'k': {"server":1,"multi":1, "access":'w'  },
              'l': {"server":1,"multi":1, "access":'rw' },
            }


type_list= {  'a': {"type": 'string',"raw": 0,"signed": 0,"array": 0 },
              'b': {"type": 'string',"raw": 1,"signed": 0,"array": 0 },

              's': {"type": 'short', "raw": 0,"signed": 1,"array": 0 },
              'S': {"type": 'short', "raw": 0,"signed": 0,"array": 0 },
              't': {"type": 'short', "raw": 0,"signed": 1,"array": 1 },
              'T': {"type": 'short', "raw": 0,"signed": 0,"array": 1 },
              'u': {"type": 'short', "raw": 1,"signed": 1,"array": 0 },
              'U': {"type": 'short', "raw": 1,"signed": 0,"array": 0 },
              'v': {"type": 'short', "raw": 1,"signed": 1,"array": 1 },
              'V': {"type": 'short', "raw": 1,"signed": 0,"array": 1 },

              'l': {"type": 'long',  "raw": 0,"signed": 1,"array": 0 },
              'L': {"type": 'long',  "raw": 0,"signed": 0,"array": 0 },
              'm': {"type": 'long',  "raw": 0,"signed": 1,"array": 1 },
              'M': {"type": 'long',  "raw": 0,"signed": 0,"array": 1 },
              'n': {"type": 'long',  "raw": 1,"signed": 1,"array": 0 },
              'N': {"type": 'long',  "raw": 1,"signed": 0,"array": 0 },
              'o': {"type": 'long',  "raw": 1,"signed": 1,"array": 1 },
              'O': {"type": 'long',  "raw": 1,"signed": 0,"array": 1 },
              'c': {"type": 'char',  "raw": 0,"signed": 1,"array": 0 },
              'C': {"type": 'char',  "raw": 0,"signed": 0,"array": 0 },
              'd': {"type": 'char',  "raw": 0,"signed": 1,"array": 1 },
              'D': {"type": 'char',  "raw": 0,"signed": 0,"array": 1 },

              'e': {"type": 'mid' ,  "raw": 0,"signed": 1,"array": 0 },
              'E': {"type": 'mid' ,  "raw": 0,"signed": 0,"array": 0 },
              'f': {"type": 'mid' ,  "raw": 0,"signed": 1,"array": 1 },
              'F': {"type": 'mid' ,  "raw": 0,"signed": 0,"array": 1 },

              'g': {"type": 'mid' ,  "raw": 1,"signed": 1,"array": 0 },
              'G': {"type": 'mid' ,  "raw": 1,"signed": 0,"array": 0 },
              'h': {"type": 'mid' ,  "raw": 1,"signed": 1,"array": 1 },
              'H': {"type": 'mid' ,  "raw": 1,"signed": 0,"array": 1 },

	      'Z': {"type": 'zero',  "raw": 0,"signed": 0,"array": 0 },
            }


#print char_list,type_list

def warn(x):  print x

def key_from_hash_val(linkParams):
# needed for package initialization:
    st=""

    for key in sorted( linkParams.keys()):
      if st == "" is not None: st += ":" 
      st += str(linkParams[key])
    return st

def key_from_hash_val_list(linkParams,lst):
    st=""

    for key in sorted(lst):
        if st == "" is not None: st+= ":" 
        st+= str(linkParams[key])
    return st

def invert_hash(linkParams):
    new = {}

    for key in linkParams.keys():
        new[key_from_hash_val( linkParams[key])] = key
    return new

# attention, data types are Dictionary!!
inv_char_list= invert_hash(char_list)
inv_type_list= invert_hash(type_list)

# Specificaion of the CAN link ends here
# ----------------------------------------------------------------


def encode( pDict ):
    """  link_string= canlink::encode(link_definitionDict)

    This function returns the string that is used in the MultiCAN implementation
    in the hardware-link field.
    """
    cl= ('server','multi','access')
    tl= ('type','raw','signed','array')

    st=None
    ch=None

    pDict = complete(pDict)

    st= '@';

    ch = inv_char_list[ key_from_hash_val_list(pDict,cl) ]
    if ch is None:
    	raise ValueError("encode(): internal error |"+ch+"|!")
    st = st+ch+" "

    ch= inv_type_list[ key_from_hash_val_list(pDict,tl) ]
    if ch is None:
    	raise ValueError("encode(): internal error |"+ch+"|!")

    st += ch

    st += " %X" % int(pDict['maxlength'] )
    st += " %X" % int( pDict['port'] )
    st += " %X" % int(pDict['out_cob'] )
    st += " %X" % int(pDict['in_cob'] )
    st += " %X" % int(pDict['multiplexor'])
    st += " %X" % int(pDict['inhibit']*10) 
    st += " %X" % int(pDict['timeout'])
    st += " %X" % int(pDict['arraysize'])
    return st

def decode (linkStr):
    """  link_definitionDict= canlink.decode(link_string)

    This function takes the string that is used in the MultiCAN implementation
    in the hardware-link field as parameter and returns the link-definition
    in form of a hash.
    """
    result = {}

    linkStr.strip()

    linkItems = linkStr.split(' ')

    if len(linkItems) != 10:
    	warn("decode(): unknown can link format (element no) "+linkStr)
	return None

    c = eU.matchRe(linkItems[0],"^\@(\w)$")
    if c is None:
        warn("decode(): unknown can link format (at-sign not found) "+linkStr)
        return None
    ch = c[0]

    if char_list.has_key(ch) is False:
      	warn("decode(): unknown variable-type char "+ch+" in this link: "+linkStr)
        return None

    result.update(char_list[ch])
    
    
    if type_list.has_key(linkItems[1]) is False:
      	warn("decode(): unknown data-type char: "+f[1]+" in this link: "+linkStr)
        return None

    dataType= type_list[linkItems[1]]

    result.update(dataType)

    for (item,itemName) in zip(linkItems[2:],['maxlength','port','out_cob','in_cob','multiplexor','inhibit','timeout','arraysize']):
        if eU.matchRe(item,"^[0-9a-fA-F]+") is None:
            warn("decode(): error in field no "+str(i)+", not a hex-number, link: "+linkStr)
            return None
    	else:
    	    result[itemName] = int(item,16)
    result['inhibit'] = result['inhibit'] * 0.1; # unit: [ms]

    calc_cidnidsob(result)

    return result

def complete( p ):
    """  %completed_link_definition= canlink::complete(%link_definition)

    This function completes the link-definition by adding default-values
    for some missing hash-keys. E.g. if the "signed" field is missing, the
    default, signed==0 which means "unsigned" is added. It also calculates
    node-id and connection-id (nid,cid) or node-id and sub-object-ids (SOBs)
    from the given can-object-ids (COBs).
    """
# complete the properties-hash if some properties are missing
# returns undef in case of an error

    check_set(p,'server',0)
    check_set(p,'multi',0)

    if check_exists(p,'access','access type','complete()') is None:
    	return 
    if  eU.matchRe(p['access'], "^(r|w|rw)$") is None:
        warn ("complete(): unknown access type!")
        return

    if check_exists(p,'type','data type','complete()') is None:
    	return
    if eU.matchRe(p['type'],"^(string|short|long|char|mid|zero)$") is None:
        warn("complete(): unknown data type!")
        return

    check_set(p,'raw',0)

    if p['type'] == 'char' and p['raw']:
        warn( "complete(): error \"char\" and \"raw\" now allowed")
        return

    check_set(p,'signed',0)
    check_set(p,'array',0)

    if check_exists(p,'port'   ,'port','complete()') is None:
    	return
    calc_cob(p)
    calc_cidnidsob(p)

    (needs_r,needs_w)= calc_rw_needs(p)

    if needs_r:
      	if check_exists(p,'in_cob' ,'in-cob','complete()') is None:
	    return 
    if needs_w:
         if check_exists(p,'out_cob','out-cob','complete()') is None:
	    return

    if p['multi']:
        if check_exists(p,'multiplexor','multiplexor','complete()') is None:
	    return
    else:
        check_set(p,'multiplexor',0)


    l = maxlen(p)

    if p.has_key('maxlength') is True:
        if int(p['maxlength']) < l:
            warn( "complete(): maxlength is too small")
            return
    else:
        p['maxlength']= l

    return p


def calc_cob(linkParams):
    """  %completed_link_definition= canlink::calc_cob(%link_definition)

    This function completes the link-definition by calculating the
    can-object-ids (COBs) from the given node-id and connection-id
    (nid,cid) or node-id and sub-object-ids (SOBs).
    """
# calculates in_cob and out_cob from nid and cid or nid and in_sob and out_sob
    (needs_r,needs_w)= calc_rw_needs(linkParams);
    calc_r=None
    calc_w=None

    if needs_r:
        if linkParams.has_key('in_cob') is False:
            calc_r=1
    if needs_w:
        if linkParams.has_key('out_cob') is False:
            calc_w=1
    if not (calc_r or calc_w):
    	return

    if check_exists(linkParams,'nid' ,'nid','calc_cob()') is None:
    	return 
    if linkParams.has_key('cid') is True:
      	c1= cidnid2cob( linkParams[cid], 0, linkParams[nid] ) # writeobj on srvr
        c2= cidnid2cob( linkParams[cid], 1, linkParams[nid] ) # readobj on srvr

        if linkParams[server]:
            if (calc_r): linkParams[in_cob]  = c2 
            if (calc_w): linkParams[out_cob] = c1 
        else:
            if (calc_r): linkParams[in_cob]  = c1 
            if (calc_w): linkParams[out_cob] = c2 
    else:
        if calc_r:
            if check_exists(linkParams,'in_sob' ,'in_sob','calc_cob()') is None:
	    	return
            linkParams['in_cob'] = sobnid2cob( linkParams['in_sob'] , linkParams['nid'] );

        if calc_w:
            if check_exists(linkParams,'out_sob' ,'out_sob','calc_cob()') is None:
	    	return
            linkParams['out_cob']= sobnid2cob( linkParams['out_sob'], linkParams['nid'] );

#       if linkParams[multi] is None: # special treatment for basic-variables
#         { if linkParams[access] == 'r':
#               # outgoing cob is not needed
#               if linkParams[out_cob] is None:
#                   linkParams[out_cob]=0
#           elif linkParams[access] == 'w'
#               # incoming cob is not needed
#               if linkParams[in_cob] is None:
#                   linkParams[in_cob]=0

def calc_cidnidsob(linkParams):
    """  completed_link_definitionDict = canlink.calc_cidnidsob(link_definition)

    This function completes the link-definition by calculating the
    node-id and connection-id (nid,cid) or node-id and sub-object-ids (SOBs)
    from the given can-object-ids (COBs)
    """
    functionName= 'calc_cidnidsob()';

    (needs_r,needs_w) = calc_rw_needs(linkParams)

    if needs_r != 0:
        if check_exists(linkParams,'in_cob' ,'in_cob' , functionName) is None:
	    return None
    if needs_w != 0:
        if check_exists(linkParams,'out_cob','out_cob', functionName) is None:
	    return None

    if linkParams.has_key('cid') is True and linkParams.has_key('nid') is True:
    	return None

    if linkParams.has_key('nid') is True:
        if needs_r and linkParams.has_key('in_sob') is True and \
	   needs_w and linkParams.has_key('out_sob') is True:
           return
      

    if needs_r != 0:
    	(cid1,d1,nid1) = cob2cidnid( linkParams['in_cob'] )  
    if needs_w != 0:
    	(cid2,d2,nid2) = cob2cidnid( linkParams['out_cob'] )
    is_server= linkParams['server']

    set_cid=None
    set_nid=None
    if needs_r and needs_w:
        if (cid1==cid2) and (nid1==nid2):
            set_cid=cid1
	    set_nid=nid1

    if needs_r: # so d1 is defined, is_server==d1 demanded
        if is_server == d1:
            set_cid=cid1
	    set_nid=nid1
      
    if needs_w: # so d2 is defined, is_server!=d2 demanded
        if is_server != d2:
            set_cid=cid2
	    set_nid=nid2
      
    if set_cid is not None:
        linkParams['cid']= set_cid
    if set_nid is not None:
        linkParams['nid']= set_nid
    if needs_r:
    	(sob_in ,nid_in) = cob2sobnid( linkParams['in_cob'] )
    if needs_w:
    	(sob_out,nid_out)= cob2sobnid( linkParams['out_cob'] )

    if needs_r and needs_w and (nid_in!=nid_out):
        # warn "functionName: contradicting NID's were calculated\n";
        return None
       # nid_in!=nid_out is an error!

    linkParams['nid']    = nid_in;
    if needs_r:
        linkParams['in_sob'] = sob_in
        linkParams['nid']    = nid_in
      
    if needs_w:
        linkParams['out_sob']= sob_out
        linkParams['nid']    = nid_out

def cob2cidnid(cob):
    """ (cid,d,nid)= canlink::cob2cidnid(cob)

    This function calculates the connection-id, direction-flag and node-id,
    (cid,d,cid) from the given can-object-id (COB)

    - bit 0-5: nid
    - 6: direction : 1 for read-objects on server
    - 7-10 cid
    """
    if (cob<0) or (cob>2047):
        warn( "cob2cidnid(): cob is invalid: "+cob)
	return None

    nid = cob & 0x3F;
    d   = 0
    if (cob & 0x40):
    	d = 1
    cid = cob >> 7
    
    return (cid,d,nid)

def cob2sobnid(cob):
    """ (sob,nid)= canlink::cob2sobnid(cob)

    This function calculates the sub-object-id and node-id
    (sob,nid) from the given can-object-id (COB)

    - bit 0-5: nid
    - 6-10 sob
    """
    if ((cob<0) or (cob>2047)):
        warn ("cob2sobnid(): cob is invalid: "+cob)
	return None

    nid= cob & 0x3F
    sob= cob >> 6

    return (sob,nid)

def sobnid2cob(sob,nid):
    """  cob= canlink::sobnid2cob(sob,nid)

    This function calculates the can-object-id (COB) from the given
    sub-object-id and node-id
    """
    if (sob<0) or (sob>26):
        warn( "sobnid2cob(): sob out of range: "+str(sob))
	return
    if (nid<1) or (nid>63):
        warn( "cidnid2cob(): nid out of range: "+str(nid))
	return
    return  (sob << 6) | nid

def maxlen(r_properties):
    l=None;

    typ= r_properties['type']

    if typ == 'char':
        l=1
    elif typ == 'short':
      	l=2
    elif typ == 'mid':
      	l=3
    elif typ == 'long':
      	l=4
    elif typ == 'zero':
      	l=0
    else:
        return None

    if r_properties['array']:
        l *= int(r_properties['arraysize'])

    if r_properties['multi']:
        l += 1

    return l

def calc_rw_needs(linkParams):
    """ internal """
    access  = linkParams['access']
    needs_r = 0
    needs_w = 0

    if linkParams['multi']:
    	if access == 'w':
            if linkParams['server'] != 0:
                needs_r=1
            else:
                needs_w=1
        else:
            needs_r=1
	    needs_w=1
    elif access == 'rw':
        needs_r=1
	needs_w=1
    elif access == 'w':
        if  linkParams['server'] != 0:
            needs_r=1
        else:
            needs_w=1
    elif access == 'r':
        if linkParams['server'] != 0:
            needs_w=1
        else:
            needs_r=1
      
    return (needs_r,needs_w)

def check_set(r_p,key,val):
    if r_p.has_key(key) is False:
      	r_p[key] = val

def check_exists(linkParams,key,name,func,keyList=None):
    """ internal """
    if linkParams.has_key(key) is False:
      	warn(func+": "+name+" is not specified!")
    	return None
    elif keyList and linkParams[key] not in keyList:
      	warn(func+": '"+name+"' = '"+linkParams[key]+"'is not part of: "+str(keyList) )
    	return None
    
    return 1

def hwLowcal2canLink(fieldDict,pvName=""):
    """ translate hwLocal record fields to a CAN link
    """
    canPar = {}
    if check_exists(fieldDict,'BTYP','BTYP',"hwLowcal2canLink() "+pvName,('NIL','CHAR','UCHAR','SHORT','USHORT','LONG','ULONG')):
	if fieldDict['BTYP'][0] == 'U':
            canPar['signed'] = 1
            canPar['type'] = fieldDict['BTYP'][1:].lower()
	else:
            canPar['signed'] = 0
            canPar['type'] = fieldDict['BTYP'].lower()
    elif check_exists(fieldDict,'CLAS','CLAS',"hwLowcal2canLink() "+pvName,('Multiplexed','Basic')):
	if fieldDict['CLAS'] == 'Multiplexed':
	    canPar['multi'] = 1
	else: canPar['multi'] = 0
    else:     	return
    if check_exists(fieldDict,'PORT','PORT',"hwLowcal2canLink() "+pvName):
	canPar['port'] = int(fieldDict['PORT'])
    else:     	return
    if check_exists(fieldDict,'INHB','INHB',"hwLowcal2canLink() "+pvName):
	canPar['inhibit'] = int(fieldDict['INHB'])
    else:     	return
    if check_exists(fieldDict,'UTYP','UTYP',"hwLowcal2canLink() "+pvName,('Client','Server')):
	if fieldDict['UTYP'] == 'Server':
	 canPar['server'] = 1
	else: canPar['server'] = 0
    else:     	return
    if check_exists(fieldDict,'ATYP','ATYP',"hwLowcal2canLink() "+pvName,('RO','WO','RW')):
	if fieldDict['ATYP'] == 'RO': canPar['access'] = 'r'
	if fieldDict['ATYP'] == 'WO': canPar['access'] = 'w'
	else:                         canPar['access'] = 'rw'
    else:     	return
    if fieldDict.has_key('NELM') and int(fieldDict['NELM']) > 1:
	canPar['arraysize'] = int(fieldDict['NELM'])
	canPar['array'] = 1
    else:
	canPar['arraysize'] = 0
	canPar['array'] = 0
    if check_exists(fieldDict,'DLEN','DLEN',"hwLowcal2canLink() "+pvName):
	canPar['maxlength'] = int(fieldDict['DLEN'])
    else:     	return
    if fieldDict.has_key('OBJO'):
	canPar['out_cob'] = int(fieldDict['OBJO'])
    else:     	
	canPar['out_cob'] = 0
    if fieldDict.has_key('OBJI'):
	canPar['in_cob'] = int(fieldDict['OBJI'])
    else:     	
	canPar['in_cob'] = 0
    if fieldDict.has_key('MUX'):
	canPar['multiplexor'] = int(fieldDict['MUX'])
    else:     	
	canPar['multiplexor'] = 0
    if fieldDict.has_key('TMO'):
	canPar['timeout'] = int(fieldDict['TMO'])
    else:     	
	canPar['timeout'] = 0
    return encode(canPar)

import sys
import pprint

def test():

#    link = sys.argv[1]
#    print "Check: decode('"+link+"') is decoded to:"
#    pprint.pprint(decode(link))

    hwLowcalPar = {
                   'UTYP': 'Client',
                   'TMO': '500',
                   'ATYP': 'RW',
                   'DESC': 'Raw temp ch2, ch10',
                   'MUX': '2',
                   'SCAN': '2 second',
                   'DTYP': 'lowcal',
                   'BTYP': 'USHORT',
                   'CLAS': 'Multiplexed',
                   'OBJI': '257',
                   'OBJO': '321',
                   'NELM': '2',
                   'DLEN': '5',
                   'RTYP': 'hwLowcal',
                   'PORT': '1',
                   'INHB': '16',
                   'WNPM': '0' }


    par = {'access': 'rw',
	   'array': 1,
	   'arraysize': 2,
	   'in_cob': 257,
	   'inhibit': 16,
	   'maxlength': 5,
	   'multi': 0,
	   'multiplexor': 2,
	   'out_cob': 321,
	   'port': 1,
	   'raw': 0,
	   'server': 0,
	   'signed': 1,
	   'timeout': 500,
	   'type': 'short'}
    pprint.pprint( complete(par) )

    pprint.pprint( hwLowcalPar )
    print hwLowcal2canLink(hwLowcalPar,"EC1-01C2LHF:C0:inTemp2")

#test()
