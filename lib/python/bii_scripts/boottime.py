# -*- coding: utf-8 -*-

"""determine the time an IOC was booted by querying a PV.
"""

# Copyright 2015 Helmholtz-Zentrum Berlin für Materialien und Energie GmbH
# <https://www.helmholtz-berlin.de>
#
# Author: Goetz Pfeiffer <Goetz.Pfeiffer@helmholtz-berlin.de>
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

import time
import datetime
import sys
try:
    from ca import _ca
    import ca
except ImportError:
    sys.stderr.write("WARNING: (in %s.py) mandatory module ca not found\n" % \
                     __name__)

assert sys.version_info[0]==2

# pylint: disable=invalid-name

#import ptimezone

def caget(pv,type_=float, tmo=0.1, maxtmo=5):
    """reads a single value with timestamp.

    parameters:
        pv      -- the name of the process variable
        type_   -- the python type wanted, currently
                   supported are int, float and str
        tmo     -- the internal sleep time, this times
                   the maxtmo parameter gives the overall
                   timeout
        maxtmo  -- the number of times the function tries
                   to get a value
    returns:
        a tuple consisting of the value and a datetime.datetime
        object that is the epics timestamp.
    """
    typemap= { int : ca.DBR_TIME_LONG,
               float: ca.DBR_TIME_DOUBLE,
               str: ca.DBR_TIME_STRING
             }
    ch= ca.channel(pv)
    ch.wait_conn()
    if not ch.isConnected():
        raise ca.caError, "no connection to PV '%s'" % pv
    epicstype= typemap.get(type_)
    if epicstype is None:
        raise ValueError, "unsupported type: '%s'" % type_
    ch.get(Type= epicstype)
    ch.flush()
    while not ch.updated:
        time.sleep(tmo)
        maxtmo -=tmo
        if maxtmo <=0:
            ch.clear()
            raise ca.caError,"unable to get value for PV '%s'" % pv
    # garbage collection of ch will remove the channel access connection
    ch.clear()
    return (ch.val, datetime.datetime.fromtimestamp(ca.TS2UTC(ch.ts)))

def datetime_from_string(st):
    """parse a string like "09-OCT-2009 16:27:09"."""
    return datetime.datetime.strptime(st,"%d-%b-%Y %H:%M:%S")

def datetime_from_iso(st):
    """parse a string like "2009-10-09T16:27:09"."""
    return datetime.datetime.strptime(st,"%Y-%m-%dT%H:%M:%S")

def boot_time_from_uptime(pv_prefix):
    """return the time when the IOC was rebooted.

    parameters:
        pv_prefix -- the PV prefix for PV's on the IOC
    returns:
        the boottime as a datetime.datetime object

    This requires that the IOC has a record named "pv_prefix:uptime".
    """
    (uptime, timestamp)= caget(pv_prefix+":uptime",int)
    td= datetime.timedelta(seconds=uptime)
    return timestamp-td

def boot_time_from_rebootTime(pv_prefix):
    """return the time when the IOC was rebooted.

    parameters:
        pv_prefix -- the PV prefix for PV's on the IOC
    returns:
        the boottime as a datetime.datetime object

    This requires that the IOC has a record named "pv_prefix:rebootTime"
    that contains the reboot time in the format "%d-%b-%Y %H:%M:%S",
    e.g. "09-OCT-2009 16:27:09".
    """
    (val, _)= caget(pv_prefix+":rebootTime",str)
    return datetime_from_string(val)

def boot_time_from_bootTime(pv_prefix):
    """return the time when the IOC was rebooted.

    parameters:
        pv_prefix -- the PV prefix for PV's on the IOC
    returns:
        the boottime as a datetime.datetime object

    This requires that the IOC has a record named "pv_prefix:bootTime"
    that contains the reboot time in the format "%Y-%m-%dT%H:%M:%S",
    e.g. "2009-10-21T16:27:09".
    """
    (val, _)= caget(pv_prefix+":bootTime",str)
    return datetime_from_iso(val)

def ca_try(call_list):
    """try funclist, catch ca exceptions.
    """
    e= None
    for (func, arg) in call_list:
        try:
            return func(arg)
        except _ca.error, e:
            # ca error, try next function:
            pass
        except ca.caError,e:
            # ca error, try next function:
            pass
        except Exception, e:
            # any other error, raise exception
            raise
    if e is None:
        raise AssertionError, "this part should not be reached"
    l= []
    for (func, arg) in call_list:
        l.append("\t%s(%s)" % (func.__name__, repr(arg)))
    raise IOError, "all channel access IO failed, diagnostics: \n%s" % \
            ("\n".join(l))
    # the program should never get here:

def boot_time_from_vxstats(pv_prefix):
    """return the time when the IOC was rebooted.

    parameters:
        pv_prefix -- the PV prefix for PV's on the IOC
    returns:
        the boottime as a datetime.datetime object

    This requires that the IOC has a record named "pv_prefix:cpuScanPeriod"
    and that this record was processed only once, when the IOC
    was rebooted.
    """
    (_, timestamp)= caget(pv_prefix+":cpuScanPeriod",float)
    return timestamp

idcp_prefix_map= { 
                   "idcp90"  : "U125IL2RP",
                   "idcp3"   : "U125ID2R",
                   "idcp5"   : "UE56ID3R",
                   "idcp6"   : "U41IT3R",
                   "idcp7"   : "U49ID4R",
                   "idcp8"   : "UE49IT4R",
                   "idcp9"   : "UE52ID5R",
                   "idcp10"  : "UE46IT5R",
                   "idcp11"  : "UE56ID6R",
                   "idcp110" : "U139ID6R",
                   "idcp12"  : "UE48IT6R",
                   "idcp120" : "U17IT6R",
                   "idcp13"  : "UE112ID7R",
                   "idcp15"  : "U49ID8R",
                   "idcp99"  : "U1IV",
                 }

def idcp_prefix(name):
    """returns the undulator prefix for an insertion device IOC.
    """
    pre= idcp_prefix_map.get(name)
    if pre is None:
        raise ValueError, "unknown idcp name: '%s'" % name
    return pre

def boottime(link_name):
    """returns the boot-time for an IOC.

    parameters:
        link_name  -- the name of the link in the rsync-dist
                      link directory
    returns:
        the boottime as a datetime.datetime object

    raises ca.caError if not channel access connection
    could be made.
    """
    type_= "BESSY"
    link= (link_name.split(".",1)[0]).lower()
    try:
        devname= idcp_prefix(link)
        type_= "IDCP"
    except ValueError, _:
        devname= link.upper()
    if link.endswith("p"):
        type_= "MLS"

    if type_== "IDCP":
        funcs= [(boot_time_from_bootTime, devname),
                (boot_time_from_uptime, devname)]
    else:
        funcs= [(boot_time_from_bootTime, devname),
                (boot_time_from_rebootTime, devname)]
    return ca_try(funcs)
