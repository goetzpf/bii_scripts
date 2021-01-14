#!/usr/bin/python3
# -*- coding: utf-8 -*-

# Copyright 2015 Helmholtz-Zentrum Berlin für Materialien und Energie GmbH
# <https://www.helmholtz-berlin.de>
#
# Author: Goetz Pfeiffer <Goetz.Pfeiffer@helmholtz-berlin.de>
# Contributions by:
#         Thomas Birke <Thomas.Birke@helmholtz-berlin.de>
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



"""BDNS Name parser
"""

import re
import sys

from collections import OrderedDict

# pylint: disable= invalid-name, bad-whitespace

assert sys.version_info[0]==3

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
     "pfam_global": "BCEFGHIKLMNOPQRVWYZ"
   }
_p["pfam_B"]= _p["pfam_global"]
_p["pfam_F"]= _p["pfam_global"] + "ST"
_p["pfam_P"]= _p["pfam_global"]

_p["pcnt"]= "[0-9]*"

_p["psdom_global"]= "X"
_p["psdom_B"]= _p["psdom_global"] + "BUDLST"
_p["psdom_F"]= _p["psdom_global"] + "ACDEGLMSVZ"
_p["psdom_P"]= _p["psdom_global"] + "BUKLS"

_p["psdnum"]= "[0-9]*"

_p["pdom_global"]= "CEGLVX"
_p["pdom_B"]= _p["pdom_global"] + "BIMRST"
#_p["pdom_F"]= _p["pdom_global"] + "DEIHLRS"
_p["pdom_F"]= _p["pdom_global"] + "AEHKST"
_p["pdom_P"]= _p["pdom_global"] + "MRT"

_p["pfac"] = "FP"

# pylint: disable= line-too-long

_re_devname = (
    "^(((%(pmem)s)(%(pind)s)?([%(pfam_B)s])(%(pcnt)s)([%(psdom_B)s]%(psdnum)s)?([%(pdom_B)s]))|" +\
      "((%(pmem)s)(%(pind)s)?([%(pfam_F)s])(%(pcnt)s)([%(psdom_F)s]%(psdnum)s)([%(pdom_F)s])F)|" +\
      "((%(pmem)s)(%(pind)s)?([%(pfam_P)s])(%(pcnt)s)([%(psdom_P)s]%(psdnum)s)?([%(pdom_P)s])P))$") % \
    _p

# pylint: enable= line-too-long

#print _re_devname

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

_fields_dict= dict(list(zip(_fields,list(range(len(_fields))))))

# pylint: disable= line-too-long

## Parse device name and return array of:
#
#    (member,allindex,index,subindex,family,counter,allsubdomain,subdomain,subdompre,subdomnumber,domain,facility)

# pylint: enable= line-too-long

def parse(devname):
    """parse a BESSY or MLS device name, return a tuple.

    parameters:
        devname: the device name to parse (a string)
    returns:
        a tuple consisting of :
        member,allindex,index,subindex,family,counter,allsubdomain,subdomain,
        subdompre,subdomnumber,domain,facility
    """
    # pylint: disable= too-many-locals
    def _st(x):
        if x is None:
            return ""
        return x
    if len(devname) > MAXLENGTH:
        return None

    m= _rx_devname.match(devname.upper())
    if m is None:
        return None
    # Note; fcsd, rdashsubindex, fdashsubindex, pdashsubindex are unused here
    # pylint: disable= unused-variable
    ( \
      fcsd, \
        ring, \
          rmember, \
          rallindex,  \
            rindex, \
            rdashsubindex, \
              rsubindex, \
          rfamily, \
          rcounter, \
          rsubdomain, \
          rdomain, \
        fel, \
          fmember, \
          fallindex,  \
            findex, \
            fdashsubindex, \
              fsubindex, \
          ffamily, \
          fcounter, \
          fsubdomain, \
          fdomain, \
        ptb, \
          pmember, \
          pallindex,  \
            pindex, \
            pdashsubindex, \
              psubindex, \
          pfamily, \
          pcounter, \
          psubdomain, \
          pdomain \
    ) = list(map(_st, m.groups()))
    # pylint: enable= unused-variable
    if ring != "":
        # pylint: disable= line-too-long
        (member, allindex, index, subindex, family, counter,subdomain,domain,facility) = (rmember, rallindex, rindex, rsubindex, rfamily, rcounter,rsubdomain,rdomain,'')
        if len(subdomain) > 0 and subdomain[0] == "L" and domain != "I":
            return None # mismatch
    elif fel!= "":
        (member, allindex, index, subindex, family, counter,subdomain,domain,facility) = (fmember, fallindex, findex, fsubindex, ffamily, fcounter,fsubdomain,fdomain,'F')
    elif ptb!="":
        (member, allindex, index, subindex, family, counter,subdomain,domain,facility) = (pmember, pallindex, pindex, psubindex, pfamily, pcounter,psubdomain,pdomain,'P')
    else:
        return None # mismatch

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
    return OrderedDict(list(zip(_fields,elms)))

def sortNamesBy(devicenames,order):
    """sort devicenames by a given order.

    parameters:
        order  - a list of integers, created by mkOrder()
    returns:
        a sorted list of devicenames
    """
    def key_(a):
        return keyOfNameByOrder(a, order)
    return sorted(devicenames, key= key_)

def sortNames(devicenames):
    """sort devicenames by the global set order.

    The global order is set by the function setOrder().
    returns:
        a sorted list of devicenames
    """
    return sortNamesBy(devicenames, _gbl_order)

# pylint: disable= line-too-long

## Set sortorder by index or namelist or string
#
#    0       1         2      3         4       5        6             7          8          9             10      11
#    MEMBER, ALLINDEX, INDEX, SUBINDEX, FAMILY, COUNTER, ALLSUBDOMAIN, SUBDOMAIN, SUBDOMPRE, SUBDOMNUMBER, DOMAIN, FACILITY
#    Name: VMI1-2V5S3M
#    VMI     1-2       1      2         V       5        S3M           S3         S          3             M
#
#  Example for order definition synatx:
#
# - BDNS.setOrder(("MEMBER", "ALLINDEX", "INDEX"))
# - BDNS.setOrder("0,1,2")
# - BDNS.setOrder([0,1,2])
#
#  Reset to default sortorder:
#
#    BDNS.setOrder("DEFAULT")

# pylint: enable= line-too-long

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
    if order == 'DEFAULT':
        order_list = _default_order[:]
    elif isinstance(order, (list, tuple)):
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
    # pylint: disable= global-statement
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
    def cmp(i1,i2):
        """implement the old cmp function."""
        if i1<i2:
            return -1
        if i1>i2:
            return 1
        return 0
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

def keyOfNameByOrder(a,order):
    """return an order key for a.

    parameters:
        a      - devicename
        order  - a list of integers, created by mkOrder()
    returns:
        a tuple than can be used for sorting
    """
    m= _rx_name_part.search(a)   # this matches a DEVICENAME and a /GADGET/PATH/DEVICENAME
    a =m.group(1)
    # NOTE : changed behaviour here

    A= parse(a)

    l= []
    for i in order:
        if A is None:
            l.append("")
            continue
        try:
            ai= int(A[i])
            l.append("%08d" % ai)
        except ValueError:
            l.append(A[i])
    return tuple(l)

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


if __name__ == "__main__":
    for name in sys.argv[1:]:
        # print name, "resolves to", parse_named(name)
        pn=parse(name)
        if pn is None:
            print(name, "fails parser")
        else:
            print(parse(name))
