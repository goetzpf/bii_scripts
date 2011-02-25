# coding=UTF-8
"""BDNS Name parser
 ******************

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

import re

MAXLENGTH = 22

## Es gibt ein Problem, wenn facility=P und entweder die Subdomain mit K beginnt oder
# die Subdomain leer ist, der letzte Buchstabe im Member einer gültigen Family
# entspricht und die family K ist. In diesem Fall ist ein eindeutiges Parsen nicht möglich!
#
# Beispiele:
#
# 1.AICK3RP kann sowohl
#   a. AI  AI                 - member im regexp hier "non-greedy"
#      C   family control-system
#      K3  subdomain K3
#      R   Ring
#      P   PTB
#   als auch
#   b. AIC AIC                - member im regexp hier "greedy"
#      K   family kicker/septa
#      3   counter 3
#      R   Ring
#      P   PTB
#   bedeuten
#
# 2.KIK1RP kann sowohl 
#   a. K   K                  - member im regexp hier "non-greedy"
#      I   family insertion-device
#      K1  subdomain K1
#      R   Ring
#      P   PTB
#   als auch
#   b. KI  KI                 - member im regexp hier "greedy"
#      K   family kicker/septa
#      1   counter 1
#      R   Ring
#      P   PTB
#   bedeuten
#
# Im ersten Beispiel war der erste Fall gewünscht (1.a.), im zweiten der zweite (2.b.)!
# Blödes Dilemma...
#
# Aktuell ist der Parser auf "non-greedy" gestellt, was zur Folge hat,
# daß im Fall KIK1RP eine subdomain angegeben werden muss(!) - also KIK1L4RP
# um den Namen korrekt aufzulösen. [sic]
#

_p={ "pmem": "[A-Z]+?",
     "pind": "([0-9]+)(-([0-9]+))?",
     "pfam_global": "BCFGHIKLMNOPQRVWYZ"
   }
_p["pfam_B"]= _p["pfam_global"]
_p["pfam_F"]= _p["pfam_global"] + "ST"
_p["pfam_P"]= _p["pfam_global"]

_p["pcnt"]= "[0-9]*"

_p["psdom_global"]= "BUX"
_p["psdom_B"]= _p["psdom_global"] + "DLST"
_p["psdom_F"]= _p["psdom_global"] + "LCEGMSU"
_p["psdom_P"]= _p["psdom_global"] + "KLS"

_p["psdnum"]= "[0-9]*"

_p["pdom_global"]= "CGLRV"
_p["pdom_B"]= _p["pdom_global"] + "BIMST"
_p["pdom_F"]= _p["pdom_global"] + "DEHLS"
_p["pdom_P"]= _p["pdom_global"] + "TM"

_p["pfac"] = "FP"


_re_devname = (
       "^(%(pmem)s)" +\
       "(%(pind)s)?" +\
       "((([%(pfam_B)s])(%(pcnt)s)([%(psdom_B)s]%(psdnum)s)?([%(pdom_B)s]))|" +\
        "(([%(pfam_F)s])(%(pcnt)s)([%(psdom_F)s]%(psdnum)s)([%(pdom_F)s])F)|" +\
        "(([%(pfam_P)s])(%(pcnt)s)([%(psdom_P)s]%(psdnum)s)?([%(pdom_P)s])P))$") % \
        _p

_rx_devname= re.compile(_re_devname)

_rx_capletter= re.compile(r'''([A-Z])(.*)''')

_fields= ( "member",
           "allindex",
           "index",
           "subindex",
           "family",
           "counter",
           "allsubdomain",
           "subdomain",
           "subdompre",
           "subdomnumber",
           "domain",
           "facility",
         )

_fields_dict= dict(zip(_fields,range(len(_fields))))

## Parse device name and return array of:
#
#    (member,allindex,index,subindex,family,counter,allsubdomain,subdomain,subdompre,subdomnumber,domain,facility)
def parse(devname):
    """parse a BESSY or MLS device name, return a tuple.

    parameters:
        devname: the device name to parse (a string)
    returns:
        a tuple consisting of :
        member,allindex,index,subindex,family,counter,allsubdomain,subdomain,
        subdompre,subdomnumber,domain,facility
    """
    def _st(x):
        if x is None:
            return ""
        return x
    if len(devname) > MAXLENGTH:
        return

    m= _rx_devname.match(devname.upper())
    if m is None:
        return
    (
      member,
      allindex, 
        index,
        dashsubindex,
          subindex,
      fcsd,
        ring,
          rfamily,
          rcounter,
          rsubdomain,
          rdomain,
        fel,
          ffamily,
          fcounter,
          fsubdomain,
          fdomain,
        ptb,
          pfamily,
          pcounter,
          psubdomain,
          pdomain
    ) = map(_st, m.groups())
    if ring != "": 
        (family,counter,subdomain,domain) = (rfamily,rcounter,rsubdomain,rdomain)
        facility = ""
        if subdomain[0] == "L" and domain != "I":
            return
    elif fel!= "":
        (family,counter,subdomain,domain) = (ffamily,fcounter,fsubdomain,fdomain)
        facility = "F"
    elif ptb!="":
        (family,counter,subdomain,domain) = (pfamily,pcounter,psubdomain,pdomain)
        facility = "P"
    else:
        return # mismatch
    
    m2= _rx_capletter.match(subdomain)
    if m2 is None:
        (subdompre, subdomnumber)= ("","")
    else:
        (subdompre, subdomnumber) = m2.groups()

    allsubdomain = subdomain + domain

    return (member, allindex, index, subindex, family, counter,
            allsubdomain, subdomain, subdompre, subdomnumber, 
            domain, facility)

def parse_named(devname):
    """parse a BESSY or MLS device name, return a dictionary.

    parameters:
        devname: the device name to parse (a string)
    returns:
        a dictionary consisting of key-value pairs, these are the known keys:
        member,allindex,index,subindex,family,counter,allsubdomain,subdomain,
        subdompre,subdomnumber,domain,facility
    """
    elms= parse(devname)
    if elms is None:
	return {}
    return dict(zip(_fields,elms))

def sortNamesBy(devicenames,order):
    """sort devicenames by a given order.

    parameters:
        order  - a list of integers, created by mkOrder()
    returns:
        a sorted list of devicenames
    """
    def cmp_(a,b):
        return cmpNamesBy(a,b,order)
    return sorted(devicenames, cmp= cmp_)

def sortNames(devicenames):
    """sort devicenames by the global set order.

    The global order is set by the function setOrder().
    returns:
        a sorted list of devicenames
    """
    return sortNamesBy(devicenames, _gbl_order)

## Set sortorder by index or namelist or string
#
#    0       1         2      3         4       5        6             7          8          9             10      11
#    MEMBER, ALLINDEX, INDEX, SUBINDEX, FAMILY, COUNTER, ALLSUBDOMAIN, SUBDOMAIN, SUBDOMPRE, SUBDOMNUMBER, DOMAIN, FACILITY
#    Name: VMI1-2V5S3M
#    VMI     1-2       1      2         V       5        S3M           S3         S          3             M
#
#  Example for order definition synatx:
#
# - BDNS::setOrder([qw(MEMBER ALLINDEX INDEX)])
# - BDNS::setOrder("0,1,2")
# - BDNS::setOrder([0,1,2])
#
#  Reset to default sortorder:
#
#    BDNS::setOrder("DEFAULT")

def mkOrder(order):
    """create an order list from an order specification.

    The created list can be used with sortNamesBy().

    parameters:
        order - either "DEFAULT" or a list of fields or a comma separated list
                of fields. A field in this case is either a fieldname, a string
                like "DOMAIN" or an integer like 10.  It corresponds to a field
                name or field index as they are returned by parse() or
                parse_named().
    returns:
        a list of integers, each representing a field. This returned list is
        usually given as parameter to sortNamesBy().
    """
    def namepart2index(x):
        i= _fields_dict.get(str(x).lower())
        if i is None:
            i= int(x)
        return i
    order_list=[]
    if( order == 'DEFAULT'):
        order_list = _default_order[:]
    elif isinstance(order,list) or isinstance(order,tuple):
    	order_list = [namepart2index(i) for i in order]
    else:
    	order_list = [namepart2index(i) for i in re.split(r'[,\s]+',order)]
    if len(order_list)<=0:
        sys.stderr.write("illegal order parameter")
    return order_list

def setOrder(order):
    """set the internal global order list from an order specification.

    The internal global order list is used by sortNames().

    parameters:
        order - either "DEFAULT" or a list of fields or a comma separated list
                of fields. A field in this case is either a fieldname, a string
                like "DOMAIN" or an integer like 10.  It corresponds to a field
                name or field index as they are returned by parse() or
                parse_named().
    returns:
        a list of integers, each representing a field. This returned list is
        usually given as parameter to sortNamesBy().
    """
    global _gbl_order
    _gbl_order= mkOrder(order)
    

_default_order= mkOrder(("FACILITY","DOMAIN","SUBDOMPRE","SUBDOMNUMBER","MEMBER",
                         "INDEX","SUBINDEX","FAMILY","COUNTER"))
_gbl_order = _default_order[:] # default order

_rx_name_part= re.compile(r'([\w\d-]*)$')

## Compare function, used in function 'sortNames()'

def cmpNamesBy(a,b,order):
    """compare two names by a given order.

    parameters:
        a      - first devicename to compare
        b      - second devicename to compare
        order  - a list of integers, created by mkOrder()
    returns:
        -1 if a<b, 0 if a==b and 1 if a>b
    """
    m= _rx_name_part.search(a)   # this matches a DEVICENAME and a /GADGET/PATH/DEVICENAME 
    a =m.group(1)
    # NOTE : changed behaviour here
    m= _rx_name_part.search(b)
    b =m.group(1)

    A= parse(a)
    B= parse(b)

    cmp_=0
    for i in order:
        if A is None:
            a= ""
        else:
            a = A[i]
        if B is None:
            b= ""
        else:
            b = B[i]
        try:
            ai= int(a)
            bi= int(b)
            cmp_= cmp(ai,bi)
        except ValueError:
            cmp_= cmp(a,b)
        #print "CMP:",cmp_
        if cmp_!=0:
            break
    return cmp_
 
def cmpNames(a,b):
    """compare two names by the internal global order.

    The internal global order is set by setOrder().

    parameters:
        a      - first devicename to compare
        b      - second devicename to compare
    returns:
        -1 if a<b, 0 if a==b and 1 if a>b
    """
    return cmpNamesBy(a,b,_gbl_order)

