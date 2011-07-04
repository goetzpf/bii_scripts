"""determine the time an IOC was booted by querying a PV.

# This software is copyrighted by the 
# Helmholtz-Zentrum Berlin fuer Materialien und Energie GmbH (HZB), 
# Berlin, Germany.
# The following terms apply to all files associated with the software.
# 
# HZB hereby grants permission to use, copy and modify this
# software and its documentation for non-commercial, educational or
# research purposes provided that existing copyright notices are
# retained in all copies.
# 
# The receiver of the software provides HZB with all enhancements, 
# including complete translations, made by the receiver.
# 
# IN NO EVENT SHALL HZB BE LIABLE TO ANY PARTY FOR DIRECT, INDIRECT,
# SPECIAL, INCIDENTAL OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE
# OF THIS SOFTWARE, ITS DOCUMENTATION OR ANY DERIVATIVES THEREOF, EVEN 
# IF HZB HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
# 
# HZB SPECIFICALLY DISCLAIMS ANY WARRANTIES, INCLUDING, BUT NOT LIMITED
# TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
# PURPOSE, AND NON-INFRINGEMENT. THIS SOFTWARE IS PROVIDED ON AN "AS IS"
# BASIS, AND HZB HAS NO OBLIGATION TO PROVIDE MAINTENANCE, SUPPORT,
# UPDATES, ENHANCEMENTS OR MODIFICATIONS.
"""
import time
import datetime
import sys
try:
    from ca import _ca
    import ca
except ImportError:
    sys.stderr.write("WARNING: (in %s.py) mandatory module ca not found\n" % \
                     __name__)

#import ptimezone

def caget(pv,type_=float, tmo=0.01, maxtmo=3):
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
    (val, timestamp)= caget(pv_prefix+":rebootTime",str)
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
    (val, timestamp)= caget(pv_prefix+":bootTime",str)
    return datetime_from_iso(val)

def ca_try(funclist, *args):
    """try funclist, catch ca exceptions.
    """
    for i in xrange(len(funclist)):
        if i>=len(funclist)-1: # last function
            return funclist[i](*args)
        try:
            return funclist[i](*args)
        except _ca.error, e:
            # ca error, try next function:
            pass
        except ca.caError,e:
            # ca error, try next function:
            pass
        except Exception, e:
            # any other error, raise exception
            raise
    # the program should never get here:
    raise AssertionError, "this part should not be reached"

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
    (val, timestamp)= caget(pv_prefix+":cpuScanPeriod",float)
    return timestamp

idcp_prefix_map= {
              "idcp3"  : "U125ID2R",
              "idcp5"  : "UE56ID3R",
              "idcp7"  : "U49ID4R",
              "idcp8"  : "UE49IT4R",
              "idcp9"  : "UE52ID5R",
              "idcp10" : "UE46IT5R",
              "idcp11" : "UE56ID6R",
              "idcp110": "U139ID6R",
              "idcp12" : "U41IT6R",
              "idcp13" : "UE112ID7R",
              "idcp15" : "U49ID8R",
              "idcp80" : "U48IV",
              "idcp81" : "UE56IV",
              "idcp96" : "U125IV",
              "idcp98" : "U2IV",
              "idcp97" : "U3IV",
              "idcp95" : "U4IV",
              "idcp99" : "U1IV",
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
    def until_dot(st):
        """returns everything up to the first dot."""
        return st.split(".",1)[0]
    link_name= link_name.lower()
    if link_name.startswith("ioc") or \
       link_name.startswith("sioc") or \
       link_name.startswith("testi"):
        # machine control system ioc
        # return boot_time_from_vxstats(until_dot(link_name).upper())
        if link_name.endswith("p"):
            funcs=(boot_time_from_rebootTime, boot_time_from_bootTime)
        else:
            funcs=(boot_time_from_bootTime, boot_time_from_rebootTime)
        return ca_try(funcs, until_dot(link_name).upper())

    if link_name.startswith("idcp"):
        # undulator IOC
        return boot_time_from_uptime(idcp_prefix(until_dot(link_name)))
    raise ValueError, "unknown link name: '%s'" % link_name

