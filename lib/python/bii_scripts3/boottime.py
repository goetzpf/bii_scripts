# -*- coding: utf-8 -*-

"""determine the time an IOC was booted by querying a PV.
"""

# Copyright 2022 Helmholtz-Zentrum Berlin für Materialien und Energie GmbH
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

# pylint: disable= invalid-name, bad-whitespace

import datetime
import sys
import subprocess

try:
    import epics
except ImportError:
    sys.stderr.write(("WARNING: (in %s.py) mandatory module epics "
                      "(aka 'pyepics') not found\n") % __name__)

assert sys.version_info[0]==3

# pylint: disable=invalid-name

VERSION="1.1"
TIMEOUT= 0.5

def _system(cmd, catch_stdout=True):
    """execute a command.

    execute a command and return the programs output
    may raise:
    IOError(errcode,stderr)
    OSError(errno,strerr)
    ValueError
    """
    def to_str(data):
        """decode byte stream to unicode string."""
        if data is None:
            return None
        return data.decode()
    if catch_stdout:
        stdout_par=subprocess.PIPE
    else:
        stdout_par=None

    p= subprocess.Popen(cmd, shell=True,
                        stdout=stdout_par, stderr=subprocess.PIPE,
                        close_fds=True)
    (child_stdout, child_stderr) = p.communicate()
    if p.returncode!=0:
        raise IOError(p.returncode,"cmd \"%s\", errmsg \"%s\"" % \
                      (cmd,to_str(child_stderr)))
    return to_str(child_stdout)

def idcp_prefix(st):
    """get idcp devicename by calling "iddb" utility."""
    e_= None
    try:
        # may raise IOError when the insertion device is unknown:
        result= _system("iddb devicename %s" % st)
        return result.strip()
    except IOError as e:
        # complicated in order to support Python 3.2.3:
        e_= e
    if e_ is not None:
        raise ValueError("error while calling iddb: %s" % str(e_))

def datetime_from_string(st):
    """parse a string like "09-OCT-2009 16:27:09"."""
    return datetime.datetime.strptime(st,"%d-%b-%Y %H:%M:%S")

def datetime_from_iso(st):
    """parse a string like "2009-10-09T16:27:09"."""
    return datetime.datetime.strptime(st,"%Y-%m-%dT%H:%M:%S")

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
    pvname= pv_prefix+":rebootTime"
    pv=epics.PV(pvname, connection_timeout= TIMEOUT)
    val= pv.get(timeout=TIMEOUT)
    del pv # cleanup
    if val is None:
        raise IOError("couldn't read "+pvname)
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
    pvname= pv_prefix+":bootTime"
    pv= epics.PV(pvname, connection_timeout= TIMEOUT)
    val= pv.get(timeout=TIMEOUT)
    del pv # cleanup
    if val is None:
        raise IOError("couldn't read "+pvname)
    return datetime_from_iso(val)

def ca_try(call_list):
    """try funclist, catch ca exceptions.
    """
    e= None
    for (func, arg) in call_list:
        try:
            return func(arg)
        except IOError as e_:
            # ca error, try next function:
            e= e_
            pass
        # any other error, continue exception
    if e is None:
        raise AssertionError("this part should not be reached")
    l= []
    for (func, arg) in call_list:
        l.append("\t%s(%s)" % (func.__name__, repr(arg)))
    raise IOError("all channel access IO failed, diagnostics: \n%s" % \
            ("\n".join(l)))
    # the program should never get here:

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
    if link.startswith("idcp"):
        devname= idcp_prefix(link)
        type_= "IDCP"
    else:
        devname= link.upper()
    if link.endswith("p"):
        type_= "MLS"

    if type_== "IDCP":
        funcs= [(boot_time_from_bootTime, devname)]
    else:
        funcs= [(boot_time_from_bootTime, devname),
                (boot_time_from_rebootTime, devname)]
    return ca_try(funcs)
