"""canlink - a module for the encoding and decoding the MultiCAN CAN Link. 

This module contains functions to decode and encode the EPICS hardware link
definition that is used in MultiCAN. The EPICS device and driver support for
the CAN bus that was developed for the BESSY II control system.

Note that HZB has the copyright on this software. It may not be used or copied
without permission from HZB.

This software is copyrighted by the
Helmholtz-Zentrum Berlin fuer Materialien und Energie GmbH (HZB),
Berlin, Germany.
The following terms apply to all files associated with the software.

HZB hereby grants permission to use, copy and modify this
software and its documentation for non-commercial, educational or
research purposes provided that existing copyright notices are
retained in all copies.

The receiver of the software provides HZB with all enhancements, 
including complete translations, made by the receiver.

IN NO EVENT SHALL HZB BE LIABLE TO ANY PARTY FOR DIRECT, INDIRECT,
SPECIAL, INCIDENTAL OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE
OF THIS SOFTWARE, ITS DOCUMENTATION OR ANY DERIVATIVES THEREOF, EVEN 
IF HZB HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

HZB SPECIFICALLY DISCLAIMS ANY WARRANTIES, INCLUDING, BUT NOT LIMITED
TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
PURPOSE, AND NON-INFRINGEMENT. THIS SOFTWARE IS PROVIDED ON AN "AS IS"
BASIS, AND HZB HAS NO OBLIGATION TO PROVIDE MAINTENANCE, SUPPORT,
UPDATES, ENHANCEMENTS OR MODIFICATIONS.

"""

# ----------------------------------------------------------------

# pylint: disable=C0322,C0103,C0302

import sys

VERSION="1.0"

_warn= sys.stderr.write

def _redirect_warnings():
    """print warnings on stdout, needed for doctests."""
    global _warn
    def mywarn(st):
        """a simple replacement for the _warn function."""
        print st,
    _warn= mywarn

# Specificaion of the CAN link:

class _CharList(object):
    """map the can link char to server,multi,access.

    This class contains methods for mapping first CAN link character to the
    server, multiplex and access property.
    """
    # server, multi, access
    _char_list= { \
        'a' : ( False, False,  'r'  ),
        'b' : ( False, False,  'w'  ),
        'c' : ( False, False,  'rw' ),
        'd' : ( False, True ,  'r'  ),
        'e' : ( False, True ,  'w'  ),
        'f' : ( False, True ,  'rw' ),
        'g' : ( True , False,  'r'  ),
        'h' : ( True , False,  'w'  ),
        'i' : ( True , False,  'rw' ),
        'j' : ( True , True ,  'r'  ),
        'k' : ( True , True ,  'w'  ),
        'l' : ( True , True ,  'rw' ),
    }
    _inv_list= dict((v,k) for k,v in _char_list.iteritems())
    _access= set(('r', 'w', 'rw'))
    def __init__(self):
        pass
    @classmethod
    def known_access(cls, type_):
        """returns True if the type_ is known and valid.

        Here are some examples:

        >>> _CharList.known_access("x")
        False
        >>> _CharList.known_access("r")
        True
        >>> _CharList.known_access("w")
        True
        >>> _CharList.known_access("rw")
        True
        """
        return type_ in cls._access
    @classmethod
    def decode(cls, char):
        """return a dictionary that is the deocoded char.
        
        Here are some examples:

        >>> import pprint
        >>> pprint.pprint(_CharList.decode("a"))
        {'access': 'r', 'multi': False, 'server': False}
        >>> pprint.pprint(_CharList.decode("b"))
        {'access': 'w', 'multi': False, 'server': False}
        >>> pprint.pprint(_CharList.decode("c"))
        {'access': 'rw', 'multi': False, 'server': False}
        >>> pprint.pprint(_CharList.decode("d"))
        {'access': 'r', 'multi': True, 'server': False}
        >>> pprint.pprint(_CharList.decode("e"))
        {'access': 'w', 'multi': True, 'server': False}
        >>> pprint.pprint(_CharList.decode("f"))
        {'access': 'rw', 'multi': True, 'server': False}
        >>> pprint.pprint(_CharList.decode("g"))
        {'access': 'r', 'multi': False, 'server': True}
        >>> pprint.pprint(_CharList.decode("h"))
        {'access': 'w', 'multi': False, 'server': True}
        >>> pprint.pprint(_CharList.decode("i"))
        {'access': 'rw', 'multi': False, 'server': True}
        >>> pprint.pprint(_CharList.decode("j"))
        {'access': 'r', 'multi': True, 'server': True}
        >>> pprint.pprint(_CharList.decode("k"))
        {'access': 'w', 'multi': True, 'server': True}
        >>> pprint.pprint(_CharList.decode("l"))
        {'access': 'rw', 'multi': True, 'server': True}
        """
        tp= cls._char_list[char]
        return { 'server': tp[0], "multi": tp[1], "access": tp[2] }
    @classmethod
    def encode(cls, server, multi, access):
        """return the char that represents the given parameters.
        
        Here are some examples:

        >>> _CharList.encode(False,False,"r")
        'a'
        >>> _CharList.encode(False,False,"w")
        'b'
        >>> _CharList.encode(False,False,"rw")
        'c'
        >>> _CharList.encode(False,True,"r")
        'd'
        >>> _CharList.encode(False,True,"w")
        'e'
        >>> _CharList.encode(False,True,"rw")
        'f'
        >>> _CharList.encode(True,False,"r")
        'g'
        >>> _CharList.encode(True,False,"w")
        'h'
        >>> _CharList.encode(True,False,"rw")
        'i'
        >>> _CharList.encode(True,True,"r")
        'j'
        >>> _CharList.encode(True,True,"w")
        'k'
        >>> _CharList.encode(True,True,"rw")
        'l'
        """
        return cls._inv_list[(server, multi, access)]
    @classmethod
    def has_char(cls, char):
        """tests if a char is in the list of known chars.

        Here are some examples:

        >>> _CharList.has_char("a")
        True
        >>> _CharList.has_char("y")
        False
        """
        return cls._char_list.has_key(char)

class _TypeList(object):
    """map can type char to type, raw, signed, array.
    """
    # type, raw, signed, array
    _type_list= { \
        'a' : ( 'string', False, False, False ),
        'b' : ( 'string', True , False, False ),
        's' : ( 'short',  False, True , False ),
        'S' : ( 'short',  False, False, False ),
        't' : ( 'short',  False, True , True  ),
        'T' : ( 'short',  False, False, True  ),
        'u' : ( 'short',  True , True , False ),
        'U' : ( 'short',  True , False, False ),
        'v' : ( 'short',  True , True , True  ),
        'V' : ( 'short',  True , False, True  ),
        'l' : ( 'long',   False, True , False ),
        'L' : ( 'long',   False, False, False ),
        'm' : ( 'long',   False, True , True  ),
        'M' : ( 'long',   False, False, True  ),
        'n' : ( 'long',   True , True , False ),
        'N' : ( 'long',   True , False, False ),
        'o' : ( 'long',   True , True , True  ),
        'O' : ( 'long',   True , False, True  ),
        'c' : ( 'char',   False, True , False ),
        'C' : ( 'char',   False, False, False ),
        'd' : ( 'char',   False, True , True  ),
        'D' : ( 'char',   False, False, True  ),
        'e' : ( 'mid' ,   False, True , False ),
        'E' : ( 'mid' ,   False, False, False ),
        'f' : ( 'mid' ,   False, True , True  ),
        'F' : ( 'mid' ,   False, False, True  ),
        'g' : ( 'mid' ,   True , True , False ),
        'G' : ( 'mid' ,   True , False, False ),
        'h' : ( 'mid' ,   True , True , True  ),
        'H' : ( 'mid' ,   True , False, True  ),
        'Z' : ( 'zero',   False, False, False ),
    }
    _inv_list= dict((v,k) for k,v in _type_list.iteritems())
    _types= set(("string","short","long","char","mid","zero"))
    def __init__(self):
        pass
    @classmethod
    def known_type(cls, type_):
        """returns True if the type_ is known and valid.

        Here are some examples:

        >>> _TypeList.known_type("xx")
        False
        >>> _TypeList.known_type("string")
        True
        >>> _TypeList.known_type("mid")
        True
        """
        return type_ in cls._types
    @classmethod
    def decode(cls, char):
        """return a dictionary that is the deocoded char.
        
        Here are some examples:

        >>> import pprint
        >>> pprint.pprint(_TypeList.decode("a"))
        {'array': False, 'raw': False, 'signed': False, 'type': 'string'}
        >>> pprint.pprint(_TypeList.decode("N"))
        {'array': False, 'raw': True, 'signed': False, 'type': 'long'}
        >>> pprint.pprint(_TypeList.decode("d"))
        {'array': True, 'raw': False, 'signed': True, 'type': 'char'}
        """
        tp= cls._type_list[char]
        # type, raw, signed, array
        return { "type": tp[0], "raw": tp[1], 
                 "signed": tp[2], "array": tp[3] }
    @classmethod
    def encode(cls, type_, raw, signed, array):
        """return the char that represents the given parameters.
        
        Here are some examples:

        >>> _TypeList.encode("string",False,False,False)
        'a'
        >>> _TypeList.encode("long",True,False,False)
        'N'
        >>> _TypeList.encode("char",False,True,True)
        'd'
        """
        return cls._inv_list[(type_, raw, signed, array)]
    @classmethod
    def has_char(cls, char):
        """tests if a char is in the list of known chars.

        Here are some examples:

        >>> _TypeList.has_char("a")
        True
        >>> _TypeList.has_char("x")
        False
        """
        return cls._type_list.has_key(char)

_explantions = \
  { 
    'server':
          [
            "This field specifies wether the host is a CAN server",
            "(server==1) or not (server==0)",
          ],
    'multi':
          [
            "This field specifies wether the CAN variable is of the ",
            "multiplex type (multi==1) or not (multi==0)",
          ],
    'access':
          [
            "This field specifies the access type of the CAN variable",
            "known access types are:",
            "read-only   (access==\'r\')",
            "write-only  (access==\'w\')",
            "read-write  (access==\'rw\')",
          ],
    'type':
          [ 
            "the basic data type of the CAL variable. Known types are:",
            "zero, string, char, short, mid, long. Note that \"mid\" is a ",
            "24-bit integer and \"zero\" is a datatype with a length",
            "of 0 bytes",

          ],
    'raw':
          [ "This field defines wether the data is processed before",
            "it is sent to the CAN bus. For numbers (all non-strings)",
            "it defines wether the numbers are converted to the ",
            "little-endian byte order (raw==0) or wether they are left",
            "alone (raw==1)",
          ],
    'signed':
          [
            "This field has only a meaning for non-string types. It ",
            "defines wether the number is signed (signed==1) or ",
            "unsigned (singed==0)",
          ],
    'array':
          [
            "This field defines wether more than one varable of the",
            "basic data type (type) is packed into one CAN bus frame",
            "(array==1) or not (array==0)",

          ],
    'maxlength':
          [
            "This is the actual length of the CAN object in bytes. ",
            "For non-array non-multiplex variables it equals the size",
            "of the basic data-type (type).",
          ],
    'port':
          [ "This is the port-number for which the CAN objects are defined",

          ],
    'out_cob':
          [
            "This is the COB (can-object ID) for the outgoing (write-)",
            "can-object.",
          ],
    'in_cob':
          [
            "This is the COB (can-object ID) for the incoming (read-)",
            "can-object.",
          ],
    'multiplexor':
          [
            "This is the multiplexor-number. It has only a meaning for",
            "CAN multiplex variables (multi==1)",
          ],
    'inhibit':
          [
            "This is the inhibit time given in milliseconds. Note that ",
            "This parameter is a floating point number.",
          ],
    'timeout':
          [
            "This is the timeout-time for the CAN objects, given in",
            "milliseconds. Note that this parameter is an integer",
          ],
    'arraysize':
          [
            "For arrays (array==1) this gives the number of elements of",
            "the array.",
          ],
    'nid':
          [ "This is the node-id of the server. Note that this parameter",
            "is optional",
          ],
    'cid':
          [  "This is the connection-id of the CAN variable. Note that",
             "this parameter is optional",
          ],
    'in_sob':
          [
            "This is the sub-object id of the incoming CAN object. Note",
            "that this parameter is optional",
          ],
    'out_sob':
          [
            "This is the sub-object id of the outgoing CAN object. Note",
            "that this parameter is optional"
          ]
  }

# Specificaion of the CAN link ends here
# ----------------------------------------------------------------

# internal functions
# ----------------------------------------------------------------

def _question(options, returns= None, tests= None):
    """ask the user a question.

    options - A list of strings, the text that is displayed for each option.
    returns - A list, the value returned. If omitted, return 0 for the first
              option, 1 for the second and so on.
    tests   - A list of strings, a simulated input. This is only used for the
              doctest.

    returns - The element of the <returns> list that corresponds to the
              selection or an integer if <returns> was None.
    
    Here are some examples:

    >>> _question(["a","b","c"],[10,20,30],["x","0","4","2"])
    please select one:
     1) a
     2) b
     3) c
    x
    please enter an integer!
    0
    please enter an integer between 1 and 3!
    4
    please enter an integer between 1 and 3!
    2
    20
    >>> _question(["a","b","c"],None,["x","0","4","2"])
    please select one:
     1) a
     2) b
     3) c
    x
    please enter an integer!
    0
    please enter an integer between 1 and 3!
    4
    please enter an integer between 1 and 3!
    2
    1
    >>> _question(["opt1","opt2"],[False,True],["1"])
    please select one:
     1) opt1
     2) opt2
    1
    False
    """
    if tests is None:
        _my_input= raw_input
    else:
        def _my_input():
            """simulate raw_input."""
            if len(tests)<=0:
                print "EOF"
                return
            val= tests.pop(0)
            print val
            return val
    if returns is None:
        returns= range(len(options))
    max_= len(options)
    print "please select one:"
    for i in xrange(1,max_+1):
        print "%2d) %s" % (i, options[i-1])
    while True:
        r= _my_input()
        if r is None:
            return
        try:
            idx= int(r)
        except ValueError, _:
            print "please enter an integer!"
            continue
        if idx<=0 or idx>max_:
            print "please enter an integer between 1 and %d!" % max_
            continue
        break
    return returns[idx-1]

def _num_question(min_, max_, is_int, question, tests= None):
    """ask the user for a number.

    min_    - The smallest allowed number
    max_    - The biggest allowed number
    is_int  - True if the used should enter an integer, False if the used
              should enter a floating point number.
    question- The question that is displayed.
    tests   - A list of strings, a simulated input. This is only used for the
              doctest.

    returns - A number.
    
    Here are some examples:

    >>> _num_question(10,15,True,"please enter an int",["9","16","14.9","11"])
    please enter an int
    9
    please enter number between 10 and 15
    16
    please enter number between 10 and 15
    14.9
    please enter an integer!
    11
    11
    >>> _num_question(10,15,False,"please enter a float",["9.9","15.1","a","14.9"])
    please enter a float
    9.9
    please enter number between 10 and 15
    15.1
    please enter number between 10 and 15
    a
    please enter an integer or a floating point number!
    14.9
    14.9
    """
    if tests is None:
        _my_input= raw_input
    else:
        def _my_input():
            """simulate raw_input."""
            if len(tests)<=0:
                print "EOF"
                return
            val= tests.pop(0)
            print val
            return val
    print question
    while True:
        r= _my_input()
        if r is None:
            return
        if is_int:
            try:
                no= int(r)
            except ValueError, _:
                print "please enter an integer!"
                continue
        else:
            try:
                no= float(r)
            except ValueError, _:
                print "please enter an integer or a floating point number!"
                continue
        if no<min_ or no>max_:
            print "please enter number between %d and %d" % (min_, max_)
            continue
        break
    return no

def _check_exists(p, key, name, func):
    """check if a dict key exists.

    If it doesn't exist, return <None> and print a warning, otherwise return
    True.
    """
    if not p.has_key(key):
        _warn("%s: %s is not specified!\n" % (func, name))
        return
    return True

def _calc_rw_needs(p):
    """determine if a read or write CAN object is needed.

    Here are some examples:

    >>> _calc_rw_needs({"multi": False, "access": "r", "server": False})
    (True, False)
    >>> _calc_rw_needs({"multi": False, "access": "r", "server": True})
    (False, True)
    >>> _calc_rw_needs({"multi": False, "access": "w", "server": False})
    (False, True)
    >>> _calc_rw_needs({"multi": False, "access": "w", "server": True})
    (True, False)
    >>> _calc_rw_needs({"multi": False, "access": "rw", "server": False})
    (True, True)
    >>> _calc_rw_needs({"multi": False, "access": "rw", "server": True})
    (True, True)
    >>> _calc_rw_needs({"multi": True, "access": "r", "server": False})
    (True, True)
    >>> _calc_rw_needs({"multi": True, "access": "r", "server": True})
    (True, True)
    >>> _calc_rw_needs({"multi": True, "access": "w", "server": False})
    (False, True)
    >>> _calc_rw_needs({"multi": True, "access": "w", "server": True})
    (True, False)
    >>> _calc_rw_needs({"multi": True, "access": "rw", "server": False})
    (True, True)
    >>> _calc_rw_needs({"multi": True, "access": "rw", "server": True})
    (True, True)
    """
    access= p["access"]
    needs_r= False
    needs_w= False
    if p["multi"]:
        if access == 'w':
            if p["server"]:
                needs_r= True
            else:
                needs_w= True 
          
        else:
            needs_r= True
            needs_w= True
    elif access == 'rw':
        needs_r= True 
        needs_w= True 
    elif access == 'w':
        if p["server"]:
            needs_r= True 
        else:
            needs_w= True 
    elif access == 'r':
        if p["server"]:
            needs_w= True 
        else:
            needs_r= True 
    return (needs_r,needs_w)

def cob2sobnid(cob):
    """convert a cob to sob, nid.

    parameters:
        cob    - the CAN object id (COB)

    returns:
        (sob,nid) - a tuple consisting of the sob object id (sob) and the node
                    id (nid)

    Here are the meanings of the bits within a cob:

    bit 0-5: nid
    6-10   : sob

    Here are some examples:

    >>> cob2sobnid(-1)
    cob2sobnid(): cob is invalid: -1
    >>> cob2sobnid(2048)
    cob2sobnid(): cob is invalid: 2048
    >>> cob2sobnid(0x46d)
    (17, 45)
    """
    if (cob<0) or (cob>2047):
        _warn("cob2sobnid(): cob is invalid: %s\n" % cob)
        return
    nid= cob & 0x3F
    sob= cob >> 6
    return (sob,nid)

def maxlength(p):
    """return the CAN data length of the type in the property dict.

    parameters:
        p    - the property dictionary

    returns:
        CAN object length, an integer.

    Here are some examples:

    >>> maxlength({"type":"char","array":False,"multi":False})
    1
    >>> maxlength({"type":"short","array":False,"multi":False})
    2
    >>> maxlength({"type":"mid","array":False,"multi":False})
    3
    >>> maxlength({"type":"long","array":False,"multi":False})
    4
    >>> maxlength({"type":"zero","array":False,"multi":False})
    0
    >>> maxlength({"type":"short","array":True,"arraysize":3,"multi":False})
    6
    >>> maxlength({"type":"short","array":False,"multi":True})
    3
    >>> maxlength({"type":"short","array":True,"arraysize":3,"multi":True})
    7
    """
    type_= p["type"]
    if    (type_ == 'char'):
        l=1
    elif  (type_ == 'short'):
        l=2
    elif  (type_ == 'mid'):
        l=3
    elif  (type_ == 'long'):
        l=4
    elif  (type_ == 'zero'):
        l=0
    else:
        return
    if p["array"]:
        l*= p["arraysize"]
    if p["multi"]:
        l+= 1
    return l

  
def sobnid2cob(sob, nid):
    """calculate cob from sob and nid.

    parameters:
        sob   - the sub object id (sob)
        nid   - the CAN node id (nid)

    returns:
        cob   - the can object ID

    Here are some examples:

    >>> sobnid2cob(27,1)
    sobnid2cob(): sob out of range: 27
    >>> sobnid2cob(-1,1)
    sobnid2cob(): sob out of range: -1
    >>> sobnid2cob(0,0)
    sobnid2cob(): nid out of range: 0
    >>> sobnid2cob(0,64)
    sobnid2cob(): nid out of range: 64
    >>> sobnid2cob(0,63)
    63
    >>> sobnid2cob(11,23)
    727
    >>> hex(sobnid2cob(0x12,0x34))
    '0x4b4'
    """
    if (sob<0) or (sob>26):
        _warn("sobnid2cob(): sob out of range: %s\n" % sob)
        return
    if (nid<1) or (nid>63):
        _warn("sobnid2cob(): nid out of range: %s\n" % nid)
        return
    return (sob << 6) | nid

def cidnid2cob(cid,d,nid):
    """calculate cid and nid from cob.

    parameters:
        cid    - the CAN channel id (cid)
        d      - the direction flag, must be 0 or 1
        nid    - the CAN node id (nid)

    returns:
        the CAN object id (COB)

    Here are some examples:

    >>> _redirect_warnings() # catch warnings in this doctest
    >>> cidnid2cob(-1,0,0)
    cidnid2cob(): cid out of range: -1
    >>> cidnid2cob(13,0,0)
    cidnid2cob(): cid out of range: 13
    >>> cidnid2cob(2,3,0)
    cidnid2cob(): d out of range: 3
    >>> cidnid2cob(2,0,0)
    cidnid2cob(): nid out of range: 0
    >>> cidnid2cob(2,0,64)
    cidnid2cob(): nid out of range: 64
    >>> cidnid2cob(2,0,33)
    289
    >>> hex(cidnid2cob(0x8,1,0x2d))
    '0x46d'
    >>> hex(cidnid2cob(0x8,0,0x2d))
    '0x42d'
    """
    if (cid<0) or (cid>12):
        _warn("cidnid2cob(): cid out of range: %s\n" % cid)
        return
    if (d!=0) and (d!=1):
        _warn("cidnid2cob(): d out of range: %s\n" % d)
        return
    if (nid<1) or (nid>63):
        _warn("cidnid2cob(): nid out of range: %s\n" % nid)
        return
    return (cid << 7) | (d << 6) | nid


# pylint: disable=R0912

def calc_cob(p):
    """calculates and sets "in_cob" and "out_cob" in the property dictionary.

    calculates in_cob and out_cob from nid and cid or nid and in_sob and
    out_sob.

    parameters:
        p    - the property dictionary

    returns:
        nothing

    This function *modifies* the given dictionary. It adds the fields "in_cob"
    and "out_cob". The values of these fields are calculated from the fields
    "nid" and "cid" or "nid" and "in_sob" and "out_sob". The field "in_cob" is
    only set if the described CAN variable needs an input CAN object, the field
    "out_cob" is only set if the CAN variable needs an output CAN object.

    Here are some examples:

    >>> def t(multi, access, server, nid, cid=None, in_sob= None, out_sob= None):
    ...     d={"multi":multi, "access":access, "server":server,
    ...        "nid": nid}
    ...     if cid is not None:
    ...         d["cid"]= cid
    ...     if in_sob is not None:
    ...         d["in_sob"]= in_sob
    ...     if out_sob is not None:
    ...         d["out_sob"]= out_sob
    ...     calc_cob(d)
    ...     print "in:",d.get("in_cob"),"  out:",d.get("out_cob")
    >>> t(False,'r',False,5,9)
    in: 1157   out: None
    >>> t(False,'w',False,5,9)
    in: None   out: 1221
    >>> t(False,'rw',False,5,9)
    in: 1157   out: 1221
    >>> t(False,'r',True,5,9)
    in: None   out: 1157
    >>> t(False,'w',True,5,9)
    in: 1221   out: None
    >>> t(False,'rw',True,5,9)
    in: 1221   out: 1157
    >>> t(True,'r',False,5,9)
    in: 1157   out: 1221
    >>> t(True,'w',False,5,9)
    in: None   out: 1221
    >>> t(True,'rw',False,5,9)
    in: 1157   out: 1221
    >>> t(False,'rw',False,5,in_sob=11,out_sob=13)
    in: 709   out: 837
    >>> t(False,'r',False,5,in_sob=11)
    in: 709   out: None
    >>> t(False,'w',False,5,out_sob=13)
    in: None   out: 837
    """
    (needs_r,needs_w)= _calc_rw_needs(p)
    calc_r= False
    calc_w= False
    if needs_r:
        if not p.has_key("in_cob"):
            calc_r= True
    if needs_w:
        if not p.has_key("out_cob"):
            calc_w= True
    if not (calc_r or calc_w):
        return
    if not _check_exists(p,'nid' ,'nid','calc_cob()'):
        return
    if p.has_key("cid"):
        c1= cidnid2cob( p["cid"], 0, p["nid"] ) # writeobj on srvr
        c2= cidnid2cob( p["cid"], 1, p["nid"] ) # readobj on srvr
        if p["server"]:
            if calc_r:
                p["in_cob"]  = c2
            if calc_w:
                p["out_cob"] = c1
        else:
            if calc_r:
                p["in_cob"]  = c1
            if calc_w:
                p["out_cob"] = c2
    else:
        if calc_r:
            if not _check_exists(p,'in_sob' ,'in_sob','calc_cob()'):
                return
            p["in_cob"] = sobnid2cob( p["in_sob"] , p["nid"] )
        if calc_w:
            if (not _check_exists(p,'out_sob' ,'out_sob','calc_cob()')):
                return
            p["out_cob"]= sobnid2cob( p["out_sob"], p["nid"] )

# pylint: enable=R0912
# pylint: disable=R0912,R0914

def calc_cidnidsob(p):
    """tries to calc cid,nid or cid,[in/out]_sob from in_cob and out_cob.

    parameters:
        p    - the property dictionary

    returns:
        nothing

    This function *modifies* the given dictionary. It adds the fields "cid" and
    "nid" or "cid" and "in_sob" and "out_sob". The values of these fields are
    calculated from the fields "in_cob" and "out_cob". The field "in_sob" is
    only set if the described CAN variable needs an input CAN object, the field
    "out_sob" is only set if the CAN variable needs an output CAN object.

    Here are some examples:

    >>> def t(multi, access, server, in_cob, out_cob):
    ...     d={"multi":multi, "access":access, "server":server}
    ...     if in_cob is not None:
    ...         d["in_cob"]= in_cob
    ...     if out_cob is not None:
    ...         d["out_cob"]= out_cob
    ...     calc_cidnidsob(d)
    ...     print "nid: %s  cid: %s  in_sob: %s  out_sob: %s" % \
                  (d.get("nid"), d.get("cid"), d.get("in_sob"), d.get("out_sob"))

    >>> t(False, "r", False, 1157, None)
    nid: 5  cid: 9  in_sob: 18  out_sob: None
    >>> t(False, "w", False, None, 1221)
    nid: 5  cid: 9  in_sob: None  out_sob: 19
    >>> t(False, "rw", False, 1157, 1221)
    nid: 5  cid: 9  in_sob: 18  out_sob: 19
    >>> t(False, "r", True, None, 1221)
    nid: 5  cid: None  in_sob: None  out_sob: 19
    >>> t(False, "w", True, 1157, None)
    nid: 5  cid: None  in_sob: 18  out_sob: None
    >>> t(False, "rw", True, 1157, 1221)
    nid: 5  cid: 9  in_sob: 18  out_sob: 19
    >>> t(True, "r", False, 1157, 1221)
    nid: 5  cid: 9  in_sob: 18  out_sob: 19
    >>> t(True, "w", False, None, 1221)
    nid: 5  cid: 9  in_sob: None  out_sob: 19
    >>> t(True, "rw", False, 1157, 1221)
    nid: 5  cid: 9  in_sob: 18  out_sob: 19
    >>> t(False, "rw", False, 709, 837)
    nid: 5  cid: None  in_sob: 11  out_sob: 13
    >>> t(False, "r", False, 709, None)
    nid: 5  cid: None  in_sob: 11  out_sob: None
    >>> t(False, "w", False, None, 837)
    nid: 5  cid: 6  in_sob: None  out_sob: 13
    >>> t(False, "rw", True, 12, 34)
    nid: None  cid: None  in_sob: None  out_sob: None
    """
    me= 'calc_cidnidsob()'
    (needs_r,needs_w)= _calc_rw_needs(p)
    if needs_r:
        if not _check_exists(p,'in_cob' ,'in_cob' , me):
            return
    if needs_w:
        if not _check_exists(p,'out_cob','out_cob', me):
            return
    if (p.has_key("cid")) and (p.has_key("nid")):
        return
    if p.has_key("nid"):
        if (needs_r and p.has_key("in_sob")) and \
           (needs_w and p.has_key("out_sob")):
            return
    if needs_r:
        (cid1,d1,nid1)= cob2cidnid( p["in_cob"] )
    if needs_w:
        (cid2,d2,nid2)= cob2cidnid( p["out_cob"] )
    is_server= p["server"]
    set_cid= None
    set_nid= None
    if needs_r and needs_w:
        if (cid1==cid2) and (nid1==nid2):
            set_cid=cid1
            set_nid=nid1
    elif needs_r:
        if is_server == d1:
            set_cid=cid1
            set_nid=nid1
    elif needs_w:
        if is_server != d2:
            set_cid=cid2
            set_nid=nid2
    if set_cid is not None:
        p["cid"]= set_cid
    if set_nid is not None:
        p["nid"]= set_nid
    if needs_r:
        (sob_in ,nid_in) = cob2sobnid( p["in_cob"] )
    if needs_w:
        (sob_out,nid_out)= cob2sobnid( p["out_cob"] )
    if needs_r and needs_w and (nid_in!=nid_out):
        # _warn "me: contradicting NID's were calculated\n"
        return
         # nid_in!=nid_out is an error!
    if needs_r:
        p["in_sob"] = sob_in
        p["nid"]    = nid_in
    if needs_w:
        p["out_sob"]= sob_out
        p["nid"]    = nid_out

# pylint: enable=R0912,R0914

def cob2cidnid(cob):
    """calculate a cob from cid and nid.

    parameters:
        cob    - the CAN object id (COB)

    returns:
        (cid,d,nid) - a tuple consisting of the channel id (cid), the direction
                      flag d and the node id (nid).

    Here are the meanings of the bits within a cob:

    bit 0-5: nid
    6      : direction : 1 for read-objects on server
    7-10   : cid

    Here are some examples:

    >>> cob2cidnid(-1)
    cob2cidnid(): cob is invalid: -1
    >>> cob2cidnid(2048)
    cob2cidnid(): cob is invalid: 2048
    >>> cob2cidnid(2047)
    (15, 1, 63)
    >>> cob2cidnid(0x46d)
    (8, 1, 45)
    >>> cob2cidnid(0x42d)
    (8, 0, 45)
    """
    if (cob<0) or (cob>2047):
        _warn("cob2cidnid(): cob is invalid: %s\n" % cob)
        return
    nid= cob & 0x3F
    d  = 1 if (cob & 0x40) else 0
    cid= cob >> 7
    return (cid,d,nid)

# pylint: disable=R0911,R0912

def complete(p):
    """complete the properties dict if some properties are missing.

    parameters:
        p    - the property dictionary

    returns:
        the property dictionary or <None> in case of an error.

    This function *modifies* the property dictionary. It adds properties that
    are missung but can be calculated from other properties or have sensible
    defaults.

    returns None in case of an error

    >>> import pprint
    >>> d={"access":"r", "type":"short", "in_cob":1157, "port":0}
    >>> pprint.pprint(complete(d))
    {'access': 'r',
     'array': False,
     'cid': 9,
     'in_cob': 1157,
     'in_sob': 18,
     'maxlength': 2,
     'multi': False,
     'multiplexor': 0,
     'nid': 5,
     'port': 0,
     'raw': False,
     'server': False,
     'signed': False,
     'type': 'short'}
    >>> d={"access":"w", "type":"short", 
    ...    "array": True, "arraysize":2, "out_cob":1221, "port":0}
    >>> pprint.pprint(complete(d))
    {'access': 'w',
     'array': True,
     'arraysize': 2,
     'cid': 9,
     'maxlength': 4,
     'multi': False,
     'multiplexor': 0,
     'nid': 5,
     'out_cob': 1221,
     'out_sob': 19,
     'port': 0,
     'raw': False,
     'server': False,
     'signed': False,
     'type': 'short'}
    >>> d={"access":"rw", "type":"short", "multi": True, "multiplexor": 10,
    ...    "server": True, "nid": 5, "cid": 9, "port": 1}
    >>> pprint.pprint(complete(d))
    {'access': 'rw',
     'array': False,
     'cid': 9,
     'in_cob': 1221,
     'maxlength': 3,
     'multi': True,
     'multiplexor': 10,
     'nid': 5,
     'out_cob': 1157,
     'port': 1,
     'raw': False,
     'server': True,
     'signed': False,
     'type': 'short'}
    >>> d={"access":"r", "type":"short", "in_cob":1157, 
    ...    "raw": True, "signed": True, "port":0}
    >>> pprint.pprint(complete(d))
    {'access': 'r',
     'array': False,
     'cid': 9,
     'in_cob': 1157,
     'in_sob': 18,
     'maxlength': 2,
     'multi': False,
     'multiplexor': 0,
     'nid': 5,
     'port': 0,
     'raw': True,
     'server': False,
     'signed': True,
     'type': 'short'}
    """
    me= "complete()"
    p.setdefault("server", False)
    p.setdefault("multi", False)
    if not _check_exists(p,'access','access type',me):
        return
    if not _CharList.known_access(p["access"]):
        _warn("complete(): unknown access type!\n")
        return
    if not _check_exists(p,'type','data type',me):
        return
    if not _TypeList.known_type(p["type"]):
        _warn("complete(): unknown data type!\n")
        return
    p.setdefault("raw", False)
    if (p["type"] == "char") and p["raw"]:
        _warn("complete(): error \"char\" and \"raw\" now allowed\n")
        return
    p.setdefault("signed", False)
    p.setdefault("array", False)
    if not _check_exists(p,'port'   ,'port',me):
        return
    calc_cob(p)
    calc_cidnidsob(p)
    (needs_r,needs_w)= _calc_rw_needs(p)
    if needs_r:
        if not _check_exists(p,'in_cob' ,'in-cob',me):
            return
    if needs_w:
        if not _check_exists(p,'out_cob','out-cob',me):
            return
    if p["multi"]:
        if not _check_exists(p,'multiplexor','multiplexor',me):
            return
    else:
        p.setdefault("multiplexor", 0)
    l= maxlength(p)
    if p.has_key("maxlength"):
        if p["maxlength"]<l:
            _warn("complete(): maxlength is too small\n")
            return
    else:
        p["maxlength"]= l
    return p

#pylint: disable=R0912,R0915

def interview(tests= None):
    """create a CAN link by interviewing the user.

    This function creates a CAN link definition by asking the user several
    questions. Note that this function is interactive and uses simple terminal
    I/O.

    parameters:
        tests   - an optional list of strings, a simulated input. This is only
                  used for the doctest.

    returns:
        a property dictionary.

    >>> import pprint
    >>> p= interview(["1",   # client
    ...               "1",   # read-only
    ...               "1",   # basic
    ...               "3",   # short
    ...               "1",   # signed
    ...               "2",   # array
    ...               "3",   # arraysize 3
    ...               "1",   # not raw
    ...               "3",   # port
    ...               "3",   # give cid,nid
    ...               "5",   # nid
    ...               "9",   # cid
    ...               100,   # inhibit
    ...               2000]) # timeout
    please select one:
     1) client
     2) server
    1
    please select one:
     1) read-only
     2) write-only
     3) read-write
    1
    please select one:
     1) basic variable
     2) multiplex variable
    1
    please select one:
     1) string
     2) char
     3) short
     4) mid
     5) long
     6) zero
    3
    please select one:
     1) signed
     2) unsigned
    1
    please select one:
     1) simple
     2) array
    2
    please enter the array-size:
    3
    please select one:
     1) not raw
     2) raw
    1
    please enter the port number:
    3
    please select one:
     1) specify in-cob,out-cob
     2) specify sob, nid
     3) specify cid, nid
    3
    please enter the server node-id:
    5
    please enter the channel-id:
    9
    please enter the inhibit-time in [ms]:
    100
    please enter the timeout-time in [ms]:
    2000
    >>> pprint.pprint(p)
    {'access': 'r',
     'array': True,
     'arraysize': 3,
     'cid': 9,
     'in_cob': 1157,
     'inhibit': 100.0,
     'maxlength': 6,
     'multi': False,
     'multiplexor': 0,
     'nid': 5,
     'port': 3,
     'raw': False,
     'server': False,
     'signed': True,
     'timeout': 2000,
     'type': 'short'}
    >>> p= interview(["2",   # server
    ...               "3",   # read-write
    ...               "2",   # multiplexed
    ...               "5",   # long
    ...               "2",   # unsigned
    ...               "1",   # no array
    ...               "1",   # not raw
    ...               "3",   # port
    ...               "1",   # give in-cob, out-cob
    ...               "12",  # in-cob
    ...               "34",  # out-cob
    ...               "7",   # multiplexor
    ...               100,   # inhibit
    ...               2000]) # timeout
    please select one:
     1) client
     2) server
    2
    please select one:
     1) read-only
     2) write-only
     3) read-write
    3
    please select one:
     1) basic variable
     2) multiplex variable
    2
    please select one:
     1) string
     2) char
     3) short
     4) mid
     5) long
     6) zero
    5
    please select one:
     1) signed
     2) unsigned
    2
    please select one:
     1) simple
     2) array
    1
    please select one:
     1) not raw
     2) raw
    1
    please enter the port number:
    3
    please select one:
     1) specify in-cob,out-cob
     2) specify sob, nid
     3) specify cid, nid
    1
    please enter the cob of the incoming can object:
    12
    please enter the cob of the outgoing can object:
    34
    please enter the multiplexor:
    7
    please enter the inhibit-time in [ms]:
    100
    please enter the timeout-time in [ms]:
    2000
    >>> pprint.pprint(p)
    {'access': 'rw',
     'array': False,
     'in_cob': 12,
     'inhibit': 100.0,
     'maxlength': 5,
     'multi': True,
     'multiplexor': 7,
     'out_cob': 34,
     'port': 3,
     'raw': False,
     'server': True,
     'signed': False,
     'timeout': 2000,
     'type': 'long'}
    >>> p= interview(["2",   # server
    ...               "3",   # read-write
    ...               "2",   # multiplexed
    ...               "5",   # long
    ...               "2",   # unsigned
    ...               "1",   # no array
    ...               "1",   # not raw
    ...               "3",   # port
    ...               "1",   # give in-cob, out-cob
    ...               "365", # in-cob
    ...               "621", # out-cob
    ...               "7",   # multiplexor
    ...               100,   # inhibit
    ...               2000]) # timeout
    please select one:
     1) client
     2) server
    2
    please select one:
     1) read-only
     2) write-only
     3) read-write
    3
    please select one:
     1) basic variable
     2) multiplex variable
    2
    please select one:
     1) string
     2) char
     3) short
     4) mid
     5) long
     6) zero
    5
    please select one:
     1) signed
     2) unsigned
    2
    please select one:
     1) simple
     2) array
    1
    please select one:
     1) not raw
     2) raw
    1
    please enter the port number:
    3
    please select one:
     1) specify in-cob,out-cob
     2) specify sob, nid
     3) specify cid, nid
    1
    please enter the cob of the incoming can object:
    365
    please enter the cob of the outgoing can object:
    621
    please enter the multiplexor:
    7
    please enter the inhibit-time in [ms]:
    100
    please enter the timeout-time in [ms]:
    2000
    >>> pprint.pprint(p)
    {'access': 'rw',
     'array': False,
     'in_cob': 365,
     'in_sob': 5,
     'inhibit': 100.0,
     'maxlength': 5,
     'multi': True,
     'multiplexor': 7,
     'nid': 45,
     'out_cob': 621,
     'out_sob': 9,
     'port': 3,
     'raw': False,
     'server': True,
     'signed': False,
     'timeout': 2000,
     'type': 'long'}
    """
    t= tests
    p= {}
    p["server"]= _question(["client","server"],[False,True],t)

    p["access"]= _question(["read-only", "write-only", "read-write"],
                           ["r", "w", "rw"],t)

    p["multi"]= _question(["basic variable", "multiplex variable"],
                          [False, True],t)
    _types=["string", "char", "short", "mid", "long", "zero"]
    p["type"]= _question(_types, _types,t)

    if p["type"]!="string":
        p["signed"]= _question(["signed", "unsigned"],
                               [True, False],t)

        p["array"]= _question(["simple", "array"],
                              [False, True],t)
        if p["array"]:
            p["arraysize"]= _num_question(1,8,True,
                                          "please enter the array-size:",t)
    if p["type"]=="char":
        # a char is always "not raw"
        p["raw"]= False
    else:
        p["raw"]= _question(["not raw", "raw"],
                            [False, True],t)
    p["port"]= _num_question(0,255, True, "please enter the port number:",t)


    sel= _question(['specify in-cob,out-cob',
                    'specify sob, nid',
                    'specify cid, nid'],
                   ["cob","sobnid","cidnid"],t)
    (r_needed, w_needed)= (True, True)
    if not p["multi"]:
        if p["access"] == "r":
            if not p["server"]:
                w_needed= False # outgoing cob is not needed
            else:
                r_needed= False # incoming cob is not needed
        elif p["access"] == 'w':
            if not p["server"]:
                r_needed= False # incoming cob is not needed
            else:
                w_needed= False # outgoing cob is not needed
    else:
        if p["access"] == 'w':
            if not p["server"]:
                r_needed= False # incoming cob is not needed 
            else:
                w_needed= False # outgoing cob is not needed 
    if   sel=="cob":
        if not r_needed:
            p["in_cob"]= 0
        else:
            p["in_cob"] = _num_question(0,2047,1,
                            "please enter the cob of the "+\
                            "incoming can object:",t)
        if not w_needed:
            p["out_cob"]= 0
        else:
            p["out_cob"]= _num_question(0,2047,1,
                            "please enter the cob of the "+\
                            "outgoing can object:",t)
    elif sel=="sobnid":
        p["nid"]     = _num_question(1,63,1,
                                    "please enter the server node-id:",t)
        if not r_needed:
            p["in_sob"]= 0
        else:
            p["in_sob"]  = _num_question(0,26,1,
                                        "please enter the in-sob:",t)
        if not w_needed:
            p["out_sob"]= 0
        else:
            p["out_sob"] = _num_question(0,26,1,
                                       "please enter the out-sob:",t)
    elif sel=="cidnid":
        p["nid"]     = _num_question(1,63,1,
                                    "please enter the server node-id:",t)
        p["cid"]     = _num_question(0,12,1,
                                   "please enter the channel-id:",t)
    else:
        raise AssertionError, "unexpected sel value:",sel

    if p["multi"]:
        p["multiplexor"] = _num_question(0,127,1,
                                        "please enter the multiplexor:",t)
    p["inhibit"] = _num_question(0,20000,0,
                                "please enter the inhibit-time in [ms]:",t)
    p["timeout"] = _num_question(1,32767,1,
                                "please enter the timeout-time in [ms]:",t)
    return complete(p)

# pylint: enable=R0911,R0912

# pylint: disable=R0912,R0915

def explain(fields= None):
    """returns a string with explanations.

    This function returns a string that contains a short explanation on each
    string that is provided in given list. When called with no parameter, is
    returns an explanation on each CAN link field known in this module.

    parameters:
        fields  - A list of field names, this parameter is optional

    returns:
        a string with explanations.

    Here are some examples:

    >>> print explain(["cid","nid"])
    cid:
      This is the connection-id of the CAN variable. Note that
      this parameter is optional
    nid:
      This is the node-id of the server. Note that this parameter
      is optional
    """
    if fields is None:
        keys= sorted(_explantions.keys())
    else:
        keys= sorted(fields)
    st= []
    for key in keys:
        st.append("%s:" % key)
        st.extend(["  %s" % elm for elm in _explantions[key]])
    return "\n".join(st)

#pylint: disable=R0912

def pretty_print(p):
    """pretty-print a property dictionary.

    parameters:
        p    - the property dictionary

    returns:
        a text describing the property dictionary, a single string

    Here are some examples:

    >>> p=  {'access': 'r',
    ...      'array': True,
    ...      'arraysize': 3,
    ...      'cid': 9,
    ...      'in_cob': 1157,
    ...      'inhibit': 100.0,
    ...      'maxlength': 6,
    ...      'multi': False,
    ...      'multiplexor': 0,
    ...      'nid': 5,
    ...      'port': 3,
    ...      'raw': False,
    ...      'server': False,
    ...      'signed': True,
    ...      'timeout': 2000,
    ...      'type': 'short'}
    >>> print pretty_print(p)
    variable-type: client basic read-only
    data-type    : array of signed short
    length       :    6 bytes
    port         :    3
    in-cob       : 1157
    node-id      :    5
    channel-id   :    9
    inhibit      :  100.0 [ms]
    timeout      : 2000   [ms]
    arraysize    :    3 elements
    >>> p=  {'access': 'rw',
    ...      'array': False,
    ...      'in_cob': 365,
    ...      'in_sob': 5,
    ...      'inhibit': 100.0,
    ...      'maxlength': 5,
    ...      'multi': True,
    ...      'multiplexor': 7,
    ...      'nid': 45,
    ...      'out_cob': 621,
    ...      'out_sob': 9,
    ...      'port': 3,
    ...      'raw': False,
    ...      'server': True,
    ...      'signed': False,
    ...      'timeout': 2000,
    ...      'type': 'long'}
    >>> print pretty_print(p)
    variable-type: server multiplex read-write
    data-type    : unsigned long
    length       :    5 bytes
    port         :    3
    out-cob      :  621
    in-cob       :  365
    node-id      :   45
    in-sob       :    5
    out-sob      :    9
    multiplexor  :    7
    inhibit      :  100.0 [ms]
    timeout      : 2000   [ms]
    """
    st= []
    tp= []
    if p["server"]:
        tp.append("server")
    else:
        tp.append("client")
    if p["multi"]:
        tp.append("multiplex")
    else:
        tp.append("basic")
    if   p["access"] == 'r':
        tp.append("read-only")
    elif p["access"] == 'w':
        tp.append("write-only")
    else:
        tp.append("read-write")
    st.append("variable-type: %s" % (" ".join(tp)))

    tp= []
    if p["array"]:
        tp.append("array of" )
    if p["raw"]:
        tp.append("raw" )
    if p["type"] == 'string':
        tp.append("string")
    else:
        if p["signed"]: 
            tp.append("signed")
        else:
            tp.append("unsigned")
        tp.append("%s" % p["type"])
    st.append("data-type    : %s" % (" ".join(tp)))

    st.append("length       : %4d bytes" % p["maxlength"])
    st.append("port         : %4d" % p["port"])
    if p.has_key("out_cob"):
        st.append("out-cob      : %4d" % p["out_cob"])
    if p.has_key("in_cob"):
        st.append("in-cob       : %4d" % p["in_cob"])
    if p.has_key("nid"):
        st.append("node-id      : %4d" % p["nid"])
    if p.has_key("cid"):
        st.append("channel-id   : %4d" % p["cid"])
    if p.has_key("in_sob"):
        st.append("in-sob       : %4d" % p["in_sob"])
    if p.has_key("out_sob"):
        st.append("out-sob      : %4d" % p["out_sob"])
    if p["multi"]:
        st.append("multiplexor  : %4d" % p["multiplexor"])
    st.append("inhibit      : %6.1f [ms]" % p["inhibit"])
    st.append("timeout      : %4d   [ms]" % p["timeout"])
    if p["array"]:
        st.append("arraysize    : %4d elements" % p["arraysize"])
    return "\n".join(st)

#pylint: enable=R0912
  
def tab_print(p=None):
    """return a can link print can link in table format.

    This function can be used to print a property dictionaries in a table. If
    the parameter p is not given, the function returns the table heading.

    parameters:
        p    - the property dictionary, this parameter is optional

    returns:
        a line of the table

    Here are some examples:

    >>> p0= {'access': 'r',
    ...      'array': True,
    ...      'arraysize': 3,
    ...      'cid': 9,
    ...      'in_cob': 1157,
    ...      'inhibit': 100.0,
    ...      'maxlength': 6,
    ...      'multi': False,
    ...      'multiplexor': False,
    ...      'nid': 5,
    ...      'port': 3,
    ...      'raw': False,
    ...      'server': False,
    ...      'signed': True,
    ...      'timeout': 2000,
    ...      'type': 'short'}
    >>> p1= {'access': 'rw',
    ...      'array': False,
    ...      'in_cob': 365,
    ...      'in_sob': 5,
    ...      'inhibit': 100.0,
    ...      'maxlength': 5,
    ...      'multi': True,
    ...      'multiplexor': 7,
    ...      'nid': 45,
    ...      'out_cob': 621,
    ...      'out_sob': 9,
    ...      'port': 3,
    ...      'raw': False,
    ...      'server': True,
    ...      'signed': False,
    ...      'timeout': 2000,
    ...      'type': 'long'}
    >>> for e in [None,p0,p1]:
    ...     print tab_print(e)
    srv/cln mul rw arr  s type   len prt   in  out mplx    inh  tmo asz
    client  bas  r arr  s short    6   3 1157   -1   -1  100.0 2000   3
    server  mlt rw sing u long     5   3  365  621    7  100.0 2000   0
    """
    if p is None:
        st= "%-7s %3s %2s %-4s %s %-6s %3s %3s %4s %4s %4s %6s %4s %3s" % \
              ("srv/cln",
               "mul",
               "rw",
               "arr",
               "s",
               "type",
               "len",
               "prt",
               "in",
               "out",
               "mplx",
               "inh",
               "tmo",
               "asz")
        return st
    st= "%-7s %3s %2s %-4s %s %-6s %3d %3d %4d %4d %4d %6.1f %4d %3d" % \
          ( "server" if p["server"] else "client",
            "mlt" if p["multi"] else "bas",
            p["access"],
            "arr" if p["array"] else "sing",
            "s" if p["signed"] else "u",
            p["type"],
            p["maxlength"], 
            p["port"],
            p.get("in_cob", -1),
            p.get("out_cob", -1),
            p["multiplexor"] if p["multi"] else -1,
            p["inhibit"],
            p["timeout"],
            p.get("arraysize", 0)
          )
    return st

def encode(p):
    """convert a property dict to a CAN link string.

    parameters:
        p    - a property dictionary

    returns:
        a CAN link string

    Here are some examples:

    >>> p=  {'access': 'r',
    ...      'array': True,
    ...      'arraysize': 3,
    ...      'cid': 9,
    ...      'in_cob': 1157,
    ...      'inhibit': 100.0,
    ...      'maxlength': 6,
    ...      'multi': False,
    ...      'multiplexor': False,
    ...      'nid': 5,
    ...      'port': 3,
    ...      'raw': False,
    ...      'server': False,
    ...      'signed': True,
    ...      'timeout': 2000,
    ...      'type': 'short'}
    >>> encode(p)
    '@a t 6 3 0 485 0 3e8 7d0 3'
    >>> p=  {'access': 'rw',
    ...      'array': False,
    ...      'in_cob': 365,
    ...      'in_sob': 5,
    ...      'inhibit': 100.0,
    ...      'maxlength': 5,
    ...      'multi': True,
    ...      'multiplexor': 7,
    ...      'nid': 45,
    ...      'out_cob': 621,
    ...      'out_sob': 9,
    ...      'port': 3,
    ...      'raw': False,
    ...      'server': True,
    ...      'signed': False,
    ...      'timeout': 2000,
    ...      'type': 'long'}
    >>> encode(p)
    '@l L 5 3 26d 16d 7 3e8 7d0 0'
    """
    p= complete(p)
    ch= _CharList.encode(p["server"], p["multi"], p["access"])
    st= ["@%s" % ch]
    ch= _TypeList.encode(p["type"], p["raw"], p["signed"], p["array"])
    st.append(ch)
    st.append("%x" % p["maxlength"])
    st.append("%x" % p["port"])
    st.append("%x" % p.get("out_cob",0))
    st.append("%x" % p.get("in_cob",0))
    st.append("%x" % p.get("multiplexor",0))
    st.append("%x" % (p["inhibit"]*10))
    st.append("%x" % p["timeout"])
    st.append("%x" % p.get("arraysize",0))
    return " ".join(st)

# pylint: disable=R0911

def decode(str_):
    """create a property dictionary from a CAN link string.

    parameters:
        str_    - the can link string

    returns:
        a property dictionary or <None> in case of an error.

    This function decodes the CAN link string and returns the property
    dictionary. 

    Here are some examples:

    >>> import pprint
    >>> pprint.pprint(decode('@a t 6 3 0 485 0 3e8 7d0 3'))
    {'access': 'r',
     'array': True,
     'arraysize': 3,
     'cid': 9,
     'in_cob': 1157,
     'in_sob': 18,
     'inhibit': 100.0,
     'maxlength': 6,
     'multi': False,
     'multiplexor': 0,
     'nid': 5,
     'out_cob': 0,
     'port': 3,
     'raw': False,
     'server': False,
     'signed': True,
     'timeout': 2000,
     'type': 'short'}
    >>> pprint.pprint(decode('@l L 5 3 26d 16d 7 3e8 7d0 0'))
    {'access': 'rw',
     'array': False,
     'arraysize': 0,
     'in_cob': 365,
     'in_sob': 5,
     'inhibit': 100.0,
     'maxlength': 5,
     'multi': True,
     'multiplexor': 7,
     'nid': 45,
     'out_cob': 621,
     'out_sob': 9,
     'port': 3,
     'raw': False,
     'server': True,
     'signed': False,
     'timeout': 2000,
     'type': 'long'}
    """
    result= {}
    str_= str_.strip()
    f= str_.split()
    if len(f)!=10:
        _warn("decode(): unknown can link format (element no) \"%s\"\n" %\
             str_)
        return 
    if not f[0].startswith("@"):
        _warn(("decode(): unknown can link format "+\
              "(at-sign not found) \"%s\"\n") % str_)
        return 
    if len(f[0])!=2:
        _warn(("decode(): unknown can link format "+\
              "(at-sign plus exactly ony char not found) \"%s\"\n") % str_)
        return 
    ch= f[0][1]
    if not _CharList.has_char(ch):
        _warn(("decode(): unknown variable-type char "+\
              "\"%s\" in this link: \"%s\"\n") % (ch, str_))
        return
    if not _TypeList.has_char(f[1]):
        _warn(("decode(): unknown data-type char: "+\
              "\"%s\" in this link: \"%s\"\n") % (f[1], str_))
        return
    result= _CharList.decode(ch)
    result.update(_TypeList.decode(f[1]))
    ints= [0,0]
    for i in xrange(2,10):
        try:
            ints.append(int(f[i], 16))
        except ValueError, _:
            _warn(("decode(): error in field no %d, "+\
                  "not a hex-number, link: \"%s\"\n") % (i, str_))
            return
    result["maxlength"]  = ints[2]
    result["port"]       = ints[3]
    result["out_cob"]    = ints[4]
    result["in_cob"]     = ints[5]
    result["multiplexor"]= ints[6]
    result["inhibit"]    = ints[7] * 0.1  # unit: [ms]
    result["timeout"]    = ints[8]        # unit: [ms]
    result["arraysize"]  = ints[9]
    calc_cidnidsob(result)
    return result

# pylint: enable=R0911

def _test():
    """perform doctest tests."""
    import doctest
    doctest.testmod()

if __name__ == "__main__":
    _test()
