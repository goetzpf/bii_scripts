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

    if char_list.has_key(ch) is None:
      	warn("decode(): unknown variable-type char $ch in this link: "+linkStr)
        return None

    result.update(char_list[ch])
    
    
    if type_list.has_key(linkItems[1]) is None:
      	warn("decode(): unknown data-type char: $f[1] in this link: "+linkStr)
        return None

    dataType= type_list[linkItems[1]]

    result.update(dataType)

    for (item,itemName) in zip(linkItems[2:],['maxlength','port','out_cob','in_cob','multiplexor','inhibit','timeout','arraysize']):
        if eU.matchRe(item,"^[0-9a-fA-F]+") is None:
            warn("decode(): error in field no $i, not a hex-number, link: "+linkStr)
            return None
    	else:
    	    result[itemName] = int(item,16)
    result['inhibit'] = result['inhibit'] * 0.1; # unit: [ms]

    calc_cidnidsob(result)

    return result

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

    if linkParams.has_key('cid') and linkParams.has_key('nid'):
    	return None

    if linkParams.has_key('nid'):
        if needs_r and linkParams.has_key('in_sob') and \
	   needs_w and linkParams.has_key('out_sob'):
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

    if needs_r: # so d1 is defined, is_server==$d1 demanded
        if is_server == d1:
            set_cid=cid1
	    set_nid=nid1
      
    if needs_w: # so d2 is defined, $is_server!=$d2 demanded
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
    """ ($cid,$d,$nid)= canlink::cob2cidnid($cob)

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
    """ ($sob,$nid)= canlink::cob2sobnid($cob)

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

def check_exists(linkParams,key,name,func):
    """ internal """
    if linkParams.has_key(key) is None:
      	warn(func+": "+name+" is not specified!")
    	return None
    return 1

#import sys
#import pprint
#link = sys.argv[1]
#print  link
#pprint.pprint(decode(link))
