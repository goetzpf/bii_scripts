#! /usr/bin/env python2
# -*- coding: UTF-8 -*-

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

"""
======================
 archiver2camonitor.py
======================
------------------------------------------------------------------------------
 a tool to convert channel access "plot" data to a camonitor compatible format
------------------------------------------------------------------------------

Overview
===============
Using the channel access archiver to retrieve values
for many process variables is problematic. The "plot"
cannot be used when the number of PVs is greater than
about 5. In "spreadsheet" format, a table with more than
about 20 columns is also almost unusable. The only solution
is to generate a plot, the click on the plot to get the
values in text form, one value below the next. However, this
format displays dates in US format which is difficult to sort
and it prints all values sorted by PV name, the PV name mentioned
first followed by a list of values with timestamps. Here is an
example::

  # Generated by ArchiveExport 2.9.2
  # Method: Plot-Binning, 21 sec bins
  # Channel 'UE52ID5R:AmsTempT1'
  01/21/2008 16:00:00.000000000   27.4299966
  01/21/2008 16:00:21.893549387   27.3488406

  # Channel 'UE52ID5R:AmsTempT2'
  01/21/2008 16:00:00.000000000   27.1865286
  01/21/2008 16:01:08.891708519   27.1053725

Much better would be the camonitor format which looks
like this::

  UE52ID5R:BasePmGap.D           2008-01-21 18:13:09.212615220 99.5837
  UE52ID5R:BasePmP.A             2008-01-21 18:13:09.212615220 582921
  UE52ID5R:BasePmP.C             2008-01-21 18:13:09.212615220 582921
  UE52ID5R:BasePmP.D             2008-01-21 18:13:09.212615220 582918
  UE52ID5R:CIOC:rdbk0            2008-01-21 18:13:09.773965819 99.2451811

This tool converts data from the first format to the second.

Quick reference
===============

* convert a file and print to standard-out::

    archiver2camonitor.py -f myfile

* read from standard-in and print to standard-out::

    archiver2camonitor.py < myfile

Reference of command line options
=================================

--summary
  print a one-line summary of the scripts function

-f FILE, --file FILE
  specify the file to read from. If this option is missing, all
  left-over arguments on the command line are interpreted as filenames.
  If this option is missing and there are no left-over arguments on the
  command line, the program reads from standard-in. If more than one
  file is given, the sorting of the results in done across the sum
  of all files

-j, --java
  if the option is given, the file is expected to contain data
  from the java archive viewer.

-g, --german
  if this option is given, floating point numbers are converted from
  the german to the english number format.

-d, --rm_double
  if this option is given, entries where the value for a channel
  (including the extra part like alarm severity) didn't change,
  are omitted. This option should always be given, when the data
  is in the java archive viewer format (see -j).

--delta SPEC
  specify a delta for each one from a list of channels. If the
  value of that channel did change by less than the given delta,
  the entry is omitted. SPEC should be a comma separated list
  where the channel name and the delta value are separated
  by a double colon. An example of a valid SPEC is:
  mychannel1::0.02,mychannel2::0.04

-t, --test
  perform a self-test for some functions (used only for debugging the script)

--doc
  print reStructuredText documentation (THIS text :-)...). Use
  "./archiver2camonitor.py --doc | rst2html" to create a html documentation.

"""

# pylint: disable= bad-whitespace
# pylint: disable= deprecated-module
# pylint: disable= invalid-name

from optparse import OptionParser
#import string
import sys
import os.path

import re

from bii_scripts import FilterFile

assert sys.version_info[0]==2

# version of the program:
my_version= "1.0"

# regular expression strings:
rx_str_float= r'[-+]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][-+]?\d+)?'

rx_str_float_or_word= r'(' + rx_str_float + r'|\S+)'

rx_str_us_date= r'(\d+/\d+/\d{4})'

rx_str_time= r'(\d+:\d+:\d+\.?\d*)'

rx_str_quoted= r"'([^']+)'"

# regular expression objects:
rx_channel= re.compile(r"^\s*#\s*Channel\s+'([^']+)'\s*$")

rx_java_heading= re.compile(r"^\s*#\s*Timestamp\s+(.*?)\s*$")

rx_data= re.compile("".join((r'^',rx_str_us_date,r'\s+',
                             rx_str_time,r'\s+',rx_str_float_or_word,
                             r'\s*(.*)$')))

rx_disconnect= re.compile("".join((r'^# ',rx_str_us_date,r'\s+',
                                   rx_str_time,r" Disconnected\s*$")))

rx_comment= re.compile(r'^\s*#')

def empty(string):
    r"""returns True when the string is empty or just spaces

    Here are some examples:
    >>> empty("")
    True
    >>> empty(" ")
    True
    >>> empty(" \n")
    True
    >>> empty(" \nx")
    False
    """
    if not string:
        return True
    return string.isspace()

def usdate2iso(date):
    """converts an US-Date to ISO format.

    Here is an example:
    >>> usdate2iso('01/21/2008')
    '2008-01-21'
    """
    elms= date.split('/')
    return "%4d-%02d-%02d" % (int(elms[2]),int(elms[0]),int(elms[1]))

def denumber2us(num):
    """converts a german number to US format.

    Here are some examples:
    >>> denumber2us("AB")
    'AB'
    >>> denumber2us("1.23")
    '1.23'
    >>> denumber2us("1,23")
    '1.23'
    >>> denumber2us("A1,23")
    'A1,23'
    """
    new= num.replace(",",".",1)
    try:
        float(new)
    except ValueError:
        return num
    return new

def tofloat(st):
    """converts st to a float, returns None in case of error.
    """
    try:
        a= float(st)
    except ValueError:
        return None
    return a

def must_skip(val,extra,delta,last):
    """handle double entries.

    parameters:
        val    -- the value (a string)
        extra  -- the extra part (also a string)
        delta  -- the allowed delta for the value or None
        last   -- a dictionary containing 'val','extra' and 'last_number'

    returns
        True   -- the value can be skipped
        False  -- the value cannot be skipped
    """
    if (last['val']==val) and (last['extra']==extra):
        return True
    if (last['val'] is None) or (last['extra']!=extra) or (delta is None):
        last['val']= val
        last['extra']= extra
        last['last_number']= tofloat(val)
        return False
    n= tofloat(val)
    if (last['last_number'] is None) or (n is None):
        last['val']= val
        last['extra']= extra
        last['last_number']= n
        return False
    if (n<last['last_number']-delta) or (n>last['last_number']+delta):
        last['val']= val
        last['extra']= extra
        last['last_number']= n
        return False
    return True

def is_comment(line):
    """returns True if the line is a comment line.

    Here are some examples:
    >>> is_comment(r'ldkfj')
    False
    >>> is_comment(r'#ldkfj')
    True
    >>> is_comment(r'  #ldkfj')
    True
    """
    return re.match(rx_comment,line) is not None

def is_channel(line):
    """returns the channel if one can be matched.

    examples of a valid channel definition:
    # Channel 'UE52ID5R:version'

    Here are some examples for the function:
    >>> is_channel(r"# Channel 'UE52ID5R:version'")
    'UE52ID5R:version'
    >>> is_channel(r"# Channel")
    """
    m= re.match(rx_channel,line)
    if m is None:
        return None
    return m.group(1)

def is_java_heading(line):
    """returns the list of column names for the heading.

    This is only needed for the java archiveviewer export format.
    The function returns a list of channel names.

    Here is an example:
    >>> is_java_heading("#Timestamp   UE56IV:BaseStatIELbl  Status  U48IV:BaseStatIELbl  Status")
    ['UE56IV:BaseStatIELbl', 'U48IV:BaseStatIELbl']
    """
    m= re.match(rx_java_heading,line)
    if m is None:
        return None
    l= m.group(1)
    # pylint: disable= deprecated-lambda
    return filter(lambda x: x!="Status", l.split())

def process_java_line(channellist,line):
    r"""process a single line of the java archiveviewer format.

    Here is an example:
    >>> l="09/19/2008 15:35:24.954406738 None Disconnected NO_ALARM  Warning NO_ALARM NO_ALARM"
    >>> channels=["UE56IV:BaseStatIELbl","U48IV:BaseStatIELbl"]
    >>> r= process_java_line(channels,l)
    >>> for i in xrange(0,len(channels)):
    ...   print "Channel:",channels[i]
    ...   print r[i]
    ...
    Channel: UE56IV:BaseStatIELbl
    ('09/19/2008', '15:35:24.954406738', 'None', 'Disconnected NO_ALARM')
    Channel: U48IV:BaseStatIELbl
    ('09/19/2008', '15:35:24.954406738', 'Warning', 'NO_ALARM NO_ALARM')
    """
    if is_comment(line):
        return None
    line= line.rstrip()
    fields= line.split()
    # timestamp= " ".join(fields[0:2])
    index= 2
    channel_index=0
    l=[]
    for channel_index in xrange(0,len(channellist)):
        index= channel_index*3+2
        tp=(fields[0],fields[1],fields[index]," ".join(fields[index+1:index+3]))
        l.append(tp)
    return l

# pylint: disable= line-too-long

def process_java_iterable(iterable,results,from_msg="",
                          from_german=False, rm_double=False, delta_dict=None):
    r"""process lines from an iterable.

    parameters:
    iterable   -- an iterable type of strings
    results    -- the results are stored in this dictionary
    from_msg   -- used for the error message. Typically
                  a string like "in file xy "
    rm_double  -- remove lines where the value for a record didn't change
    rel_prec   -- relative precision for rm_double

    Here is an example:
    >>> results={}
    >>> process_java_iterable('''
    ... #
    ... #Timestamp UE56IV:BaseStatIELbl Status  U48IV:BaseStatIELbl Status
    ... 09/19/2008 15:24:22.963809013 None INVALID     UDF       None NO_ALARM  NO_ALARM
    ... 09/19/2008 15:24:22.964805841 None NO_ALARM    NO_ALARM  None NO_ALARM  NO_ALARM
    ... '''.split("\n"),results)
    >>> for key in sorted(results.keys()):
    ...     print key,"->\n       ",results[key]
    ...
    2008-09-19 15:24:22.963809013 U48IV:BaseStatIELbl ->
            U48IV:BaseStatIELbl            2008-09-19 15:24:22.963809013  None                 NO_ALARM NO_ALARM
    2008-09-19 15:24:22.963809013 UE56IV:BaseStatIELbl ->
            UE56IV:BaseStatIELbl           2008-09-19 15:24:22.963809013  None                 INVALID UDF
    2008-09-19 15:24:22.964805841 U48IV:BaseStatIELbl ->
            U48IV:BaseStatIELbl            2008-09-19 15:24:22.964805841  None                 NO_ALARM NO_ALARM
    2008-09-19 15:24:22.964805841 UE56IV:BaseStatIELbl ->
            UE56IV:BaseStatIELbl           2008-09-19 15:24:22.964805841  None                 NO_ALARM NO_ALARM

    Here we see the usage of delta_dict, in this case for the PV
    "UE56IV:BaseStatIELbl". The value "1.4" is printed since the extra part
    (NO_ALARM instead of INVALID) is different. "1.6" is not printed since
    it differs from "1.4" less than 0.5:
    >>> results={}
    >>> d={'UE56IV:BaseStatIELbl':0.5}
    >>> process_java_iterable('''
    ... #
    ... #Timestamp UE56IV:BaseStatIELbl Status  U48IV:BaseStatIELbl Status
    ... 09/19/2008 15:24:22.963809013 1.0 INVALID     UDF       None NO_ALARM  NO_ALARM
    ... 09/19/2008 15:24:22.964805841 1.4 NO_ALARM    NO_ALARM  None NO_ALARM  NO_ALARM
    ... 09/19/2008 15:24:22.965805841 1.6 NO_ALARM    NO_ALARM  None NO_ALARM  NO_ALARM
    ... '''.split("\n"),results,rm_double=True,delta_dict=d)
    >>> for key in sorted(results.keys()):
    ...     print key,"->\n       ",results[key]
    ...
    2008-09-19 15:24:22.963809013 U48IV:BaseStatIELbl ->
            U48IV:BaseStatIELbl            2008-09-19 15:24:22.963809013  None                 NO_ALARM NO_ALARM
    2008-09-19 15:24:22.963809013 UE56IV:BaseStatIELbl ->
            UE56IV:BaseStatIELbl           2008-09-19 15:24:22.963809013  1.0                  INVALID UDF
    2008-09-19 15:24:22.964805841 UE56IV:BaseStatIELbl ->
            UE56IV:BaseStatIELbl           2008-09-19 15:24:22.964805841  1.4                  NO_ALARM NO_ALARM

    Here we see the usage of delta_dict, in this case for the PV
    "UE56IV:BaseStatIELbl". The value "1.4" is not printed since it differs
    from "1.0" by less than 0.5. "1.6" is printed because it differs by more than
    0.5:
    >>> results={}
    >>> d={'UE56IV:BaseStatIELbl':0.5}
    >>> process_java_iterable('''
    ... #
    ... #Timestamp UE56IV:BaseStatIELbl Status  U48IV:BaseStatIELbl Status
    ... 09/19/2008 15:24:22.963809013 1.0 NO_ALARM    NO_ALARM  None NO_ALARM  NO_ALARM
    ... 09/19/2008 15:24:22.964805841 1.4 NO_ALARM    NO_ALARM  None NO_ALARM  NO_ALARM
    ... 09/19/2008 15:24:22.965805841 1.6 NO_ALARM    NO_ALARM  None NO_ALARM  NO_ALARM
    ... 09/19/2008 15:24:22.966805841 2.0 NO_ALARM    NO_ALARM  None NO_ALARM  NO_ALARM
    ... 09/19/2008 15:24:22.967805841 2.2 NO_ALARM    NO_ALARM  None NO_ALARM  NO_ALARM
    ... '''.split("\n"),results,rm_double=True,delta_dict=d)
    >>> for key in sorted(results.keys()):
    ...     print key,"->\n       ",results[key]
    ...
    2008-09-19 15:24:22.963809013 U48IV:BaseStatIELbl ->
            U48IV:BaseStatIELbl            2008-09-19 15:24:22.963809013  None                 NO_ALARM NO_ALARM
    2008-09-19 15:24:22.963809013 UE56IV:BaseStatIELbl ->
            UE56IV:BaseStatIELbl           2008-09-19 15:24:22.963809013  1.0                  NO_ALARM NO_ALARM
    2008-09-19 15:24:22.965805841 UE56IV:BaseStatIELbl ->
            UE56IV:BaseStatIELbl           2008-09-19 15:24:22.965805841  1.6                  NO_ALARM NO_ALARM
    2008-09-19 15:24:22.967805841 UE56IV:BaseStatIELbl ->
            UE56IV:BaseStatIELbl           2008-09-19 15:24:22.967805841  2.2                  NO_ALARM NO_ALARM

    Here is an example where the value is "0.000" or "-0.000":
    >>> results={}
    >>> d={'UE56IV:BaseStatIELbl':0.5}
    >>> process_java_iterable('''
    ... #
    ... #Timestamp UE56IV:BaseStatIELbl Status  U48IV:BaseStatIELbl Status
    ... 09/19/2008 15:24:22.963809013 0.000 NO_ALARM    NO_ALARM  None NO_ALARM  NO_ALARM
    ... 09/19/2008 15:25:22.963809013 0.000 INVALID    NO_ALARM  None NO_ALARM  NO_ALARM
    ... 09/19/2008 15:26:22.963809013 0.000 NO_ALARM    NO_ALARM  None NO_ALARM  NO_ALARM
    ... 09/19/2008 15:27:22.963809013 -0.000 NO_ALARM    NO_ALARM  None NO_ALARM  NO_ALARM
    ... 09/19/2008 15:28:22.963809013 0.000 NO_ALARM    NO_ALARM  None NO_ALARM  NO_ALARM
    ... '''.split("\n"),results,rm_double=True,delta_dict=d)
    >>> for key in sorted(results.keys()):
    ...     print key,"->\n       ",results[key]
    ...
    2008-09-19 15:24:22.963809013 U48IV:BaseStatIELbl ->
            U48IV:BaseStatIELbl            2008-09-19 15:24:22.963809013  None                 NO_ALARM NO_ALARM
    2008-09-19 15:24:22.963809013 UE56IV:BaseStatIELbl ->
            UE56IV:BaseStatIELbl           2008-09-19 15:24:22.963809013  0.000                NO_ALARM NO_ALARM
    2008-09-19 15:25:22.963809013 UE56IV:BaseStatIELbl ->
            UE56IV:BaseStatIELbl           2008-09-19 15:25:22.963809013  0.000                INVALID NO_ALARM
    2008-09-19 15:26:22.963809013 UE56IV:BaseStatIELbl ->
            UE56IV:BaseStatIELbl           2008-09-19 15:26:22.963809013  0.000                NO_ALARM NO_ALARM
    """
    # pylint: disable= too-many-arguments, too-many-locals, too-many-branches
    if delta_dict is None:
        delta_dict= {}
    lineno=0
    channels= None
    channels_last={}
    for line in iterable:
        lineno+=1
        if empty(line):
            continue
        if is_comment(line):
            # may be a comment or a channel definition
            if channels is not None:
                continue
            channels= is_java_heading(line)
            if channels is not None:
                for chan in channels:
                    channels_last[chan]= {'val':None,'extra':None,'last_number':None}
            continue
        if channels is None:
            raise AssertionError,"data before channel definition in %sline %d" % (from_msg,lineno)
        l= process_java_line(channels,line)
        for i in xrange(0,len(channels)):
            channel= channels[i]
            tp= l[i]
            date= usdate2iso(tp[0])
            if not empty(tp[3]): # extra flags present
                extra= " " + tp[3]
            else:
                extra= ""
            val= tp[2]
            if from_german:
                val= denumber2us(val)
            if rm_double:
                if must_skip(val,extra,delta_dict.get(channel,None),channels_last[channel]):
                    continue
            key= " ".join((date,tp[1],channel))
            results[key]= "%-30s %s %-19s %-20s%s" % \
                          (channel,date,tp[1],val,extra)

# pylint: enable= line-too-long

def is_disconnected(line):
    """returns date and time of a "disconnect" message.

    example of a disconnect message:
    # 02/21/2008 13:28:30.309669580 Disconnected

    Here are some examples for the function:
    >>> is_disconnected(r"# 02/21/2008 13:28:30.309669580 Disconnected")
    ('02/21/2008', '13:28:30.309669580', 'Disconnected', '')

    If nothing is matched, the function returns None:
    >>> print is_disconnected(r'01/21/2008 18:45:00.000000000   62.0872102')
    None
    """
    m= re.match(rx_disconnect,line)
    if m is None:
        return None
    return(m.group(1),m.group(2),"Disconnected","")


def is_data(line):
    """scans a data line.

    returns:
    a tuple with date,time,value,extra-string
     -or-
    None if string couldn't be matched

    example:
    01/21/2008 18:45:00.000000000   62.0872102 INVALID TIMEOUT

    Here are some examples for the function:

    Timestamp with value:
    >>> is_data(r'01/21/2008 18:45:00.000000000   62.0872102')
    ('01/21/2008', '18:45:00.000000000', '62.0872102', '')

    Timestamp with value and extra flags:
    >>> is_data(r'01/21/2008 18:45:00.000000000   62.0872102 INVALID TIMEOUT')
    ('01/21/2008', '18:45:00.000000000', '62.0872102', 'INVALID TIMEOUT')

    The value can also be a string:
    >>> is_data(r'01/21/2008 18:45:00.000000000   enabled')
    ('01/21/2008', '18:45:00.000000000', 'enabled', '')

    Value is missing, the function returns None:
    >>> print is_data(r'01/21/2008 18:45:00.000000000 ')
    None
    """
    m= re.match(rx_data,line)
    if m is None:
        return None
    return(m.group(1),m.group(2),m.group(3),m.group(4))

def process_iterable(iterable,results,from_msg="",
                     from_german=False, rm_double=False, delta_dict=None):
    r"""process lines from an iterable.

    parameters:
    iterable   -- an iterable type of strings
    results    -- the results are stored in this dictionary
    from_msg   -- used for the error message. Typically
                  a string like "in file xy "
    rm_double  -- remove lines where the value for a record didn't change
    delta_dict --  dictionary of deltas for some PVs

    Here is an example how process_iterable() scans lines
    as they come typically from the channel access
    archiver.
    >>> results={}
    >>> process_iterable('''
    ... # Generated by ArchiveExport 2.9.2
    ... # Method: Plot-Binning, 21 sec bins
    ... # Channel 'UE52ID5R:AmsTempT1'
    ... 01/21/2008 16:00:00.000000000   27.4299966
    ... 01/21/2008 16:00:21.893549387   27.3488406
    ...
    ... # Channel 'UE52ID5R:AmsTempT2'
    ... 01/21/2008 16:00:00.000000000   27.1865286
    ... 01/21/2008 16:01:08.891708519   27.1053725
    ... '''.split("\n"),results)

    After process_iterable() was executed, the results dictionary
    contains keys consisting of the date, the time and the pv
    that map to strings in camonitor format:
    >>> for key in results.keys():
    ...     print key,"->\n       ",results[key]
    ...
    2008-01-21 16:00:00.000000000 UE52ID5R:AmsTempT1 ->
            UE52ID5R:AmsTempT1             2008-01-21 16:00:00.000000000 27.4299966
    2008-01-21 16:01:08.891708519 UE52ID5R:AmsTempT2 ->
            UE52ID5R:AmsTempT2             2008-01-21 16:01:08.891708519 27.1053725
    2008-01-21 16:00:00.000000000 UE52ID5R:AmsTempT2 ->
            UE52ID5R:AmsTempT2             2008-01-21 16:00:00.000000000 27.1865286
    2008-01-21 16:00:21.893549387 UE52ID5R:AmsTempT1 ->
            UE52ID5R:AmsTempT1             2008-01-21 16:00:21.893549387 27.3488406

    Here we see how two consecutive calls to process_iterable()
    gather data in the results dictionary:
    >>> results={}
    >>> process_iterable(["# Channel 'UE52ID5R:AmsTempT1'",
    ...                   "01/21/2008 16:00:00.000000000   27.4299966"],results)
    >>> process_iterable(["# Channel 'UE52ID5R:AmsTempT1'",
    ...                   "01/21/2008 16:00:21.893549387   27.3488406"],results)

    The results dictionary contains both lines:
    >>> for key in results.keys():
    ...     print key,"->\n       ",results[key]
    ...
    2008-01-21 16:00:00.000000000 UE52ID5R:AmsTempT1 ->
            UE52ID5R:AmsTempT1             2008-01-21 16:00:00.000000000 27.4299966
    2008-01-21 16:00:21.893549387 UE52ID5R:AmsTempT1 ->
            UE52ID5R:AmsTempT1             2008-01-21 16:00:21.893549387 27.3488406

    Here we see the useage of delta_dict. For each channel a delta can be specified.
    If two values don't differ more than the given delta, the second entry is
    omitted:
    >>> results={}
    >>> d={'UE52ID5R:AmsTempT1':0.5}
    >>> process_iterable(["# Channel 'UE52ID5R:AmsTempT1'",
    ...                   "01/21/2008 16:00:00.000000000   27.4299966",
    ...                   "01/21/2008 16:00:21.893549387   27.8",
    ...                   "01/21/2008 16:00:22.893549387   27.93",
    ...                  ],
    ...                   results,rm_double=True,delta_dict=d)

    We see, that the line in the middle is missing, since the change
    of the value was smaller than 0.5:
    >>> for key in sorted(results.keys()):
    ...     print key,"->\n       ",results[key]
    ...
    2008-01-21 16:00:00.000000000 UE52ID5R:AmsTempT1 ->
            UE52ID5R:AmsTempT1             2008-01-21 16:00:00.000000000 27.4299966
    2008-01-21 16:00:22.893549387 UE52ID5R:AmsTempT1 ->
            UE52ID5R:AmsTempT1             2008-01-21 16:00:22.893549387 27.93


    An invalid line raises an exception:
    >>> results={}
    >>> process_iterable(["ldfjsldfj"], results,"in teststring ")
    Traceback (most recent call last):
       ...
    AssertionError: parse error in teststring line 1
    """
    # pylint: disable= too-many-arguments, too-many-locals, too-many-branches
    if delta_dict is None:
        delta_dict= {}
    channel= None
    lineno=0
    last={'val':None,'extra':None,'last_number':None}
    for line in iterable:
        lineno+=1
        if empty(line):
            continue
        tp= None
        if is_comment(line):
            # may be a comment or a channel definition or
            # a disconnect message
            st= is_channel(line)
            if st is not None:
                channel= st
                last={'val':None,'extra':None,'last_number':None}
                continue
            tp= is_disconnected(line) # returns date, time, "Disconnected"
            if tp is None:
                continue # ignore all other comments
        if tp is None:   # if tp is none, try to read data
            tp= is_data(line)
        if tp is None:
            print "LINE:",line
            raise AssertionError,"parse error %sline %d" % (from_msg,lineno)
        if channel is None:
            raise AssertionError,"unknown channel"
        date= usdate2iso(tp[0])
        if not empty(tp[3]): # extra flags present
            extra= " " + tp[3]
        else:
            extra= ""
        key= " ".join((date,tp[1],channel))
        val= tp[2]
        if from_german:
            val= denumber2us(val)
        if rm_double:
            if must_skip(val,extra,delta_dict.get(channel,None),last):
                continue
        results[key]= "%-30s %s %s %s%s" % \
                      (channel,date,tp[1],val,extra)
        continue


def process(filename_,results,process_func,from_german,rm_double,delta_dict):
    """process input from standard-in or from a file.

    parameters:
      filename_      -- name of the file or None for STDIN
      results        -- dictionary where the results are stored
      process_func   -- function to process each file
      from_german    -- if True, convert numbers from german to US format
      rm_double      -- if True, remove lines where the PV didn't change
                        it's value
      delta_dict   --  dictionary of deltas for some PVs
    """
    # pylint: disable= too-many-arguments
    in_file= FilterFile.FilterFile(filename=filename_,opennow=True)
    process_func(in_file.fh(),results,"in file %s " % filename_,
                 from_german,rm_double,delta_dict)
    in_file.close()

def process_files(options,args,process_func,from_german,rm_double,delta_dict):
    """process all files given on the command line.

    parameters:
      options      --  this may contain a "file" member with
                       the filename
      args         --  this may be a list of strings containing
                       extra filenames
      process_func --  function that processes an iterable of lines
      from_german  --  convert values from german to us floating point format
      rm_double    --  remove lines where the value for a record didn't change
      delta_dict   --  dictionary of deltas for some PVs

    output:
      prints the sorted values to standard-out
    """
    # pylint: disable= too-many-arguments
    filelist= []
    if options.file is not None:
        filelist=[options.file]
    if args: # extra arguments
        filelist.extend(args)
    if len(filelist)<=0:
        filelist= [None]
    results= {}
    for f in filelist:
        process(f,results,process_func,from_german,rm_double,delta_dict)
    keys= sorted(results.keys())
    for k in keys:
        print results[k]


def process_delta(delta_string):
    """calc a delta dictionary from a given string.

    Here is an example:
    >>> d=process_delta("a::0.01,b::0.3")
    >>> for k in sorted(d.keys()):
    ...   print "%s -> %.3f" % (k,d[k])
    ...
    a -> 0.010
    b -> 0.300
    """
    d={}
    if delta_string is None:
        return d
    l= delta_string.split(",")
    for item in l:
        (channel,delta)= item.split("::")
        d[channel]= float(delta)
    return d

def script_shortname():
    """return the name of this script without a path component."""
    return os.path.basename(sys.argv[0])

def print_summary():
    """print a short summary of the scripts function."""
    print "%-20s: convert archiver data format to camonitor format\n" % script_shortname()

def print_doc():
    """print embedded reStructuredText documentation."""
    print __doc__

def _test():
    """does a self-test of some functions defined here."""
    print "performing self test..."
    import doctest
    doctest.testmod()
    print "done!"

def main():
    """The main function.

    parse the command-line options and perform the command
    """

    # command-line options and command-line help:
    usage = "usage: %prog [options]"
    parser = OptionParser(usage=usage,
                          version="%%prog %s" % my_version,
                          description="convert archiver data format to camonitor format")
    parser.add_option("--summary",  # implies dest="nodelete"
                      action="store_true", # default: None
                      help="print a summary of the function of the program",
                     )

    parser.add_option("-t", "--test",     # implies dest="switch"
                      action="store_true", # default: None
                      help="perform simple self-test",
                     )

    parser.add_option("-j", "--java",     # implies dest="switch"
                      action="store_true", # default: None
                      help="process files from java archive viewer",
                     )

    parser.add_option("-g", "--german",     # implies dest="switch"
                      action="store_true", # default: None
                      help="convert floating point numbers from german to us format",
                     )

    parser.add_option("-d", "--rm_double",     # implies dest="switch"
                      action="store_true", # default: None
                      help="remove entries where the value didn't change",
                     )

    parser.add_option("--delta",     # implies dest="switch"
                      action="store", # default: None
                      type="string",
                      help="Specify a SPEC for a list of channels. The SPEC "+\
                           "defines for each channel a delta. If the value "+\
                           "did change less than delta, the "+\
                           "entry is omitted. The format of this parameter is:"+\
                           "'channel1::delta1,channel2::delta2,...'",
                      metavar="SPEC"
                     )

    parser.add_option("-f", "--file", # implies dest="file"
                      action="store", # OptionParser's default
                      type="string",  # OptionParser's default
                      help="specify the FILE",
                      metavar="FILE"  # for help-generation text
                     )
    parser.add_option("--doc",            # implies dest="switch"
                      action="store_true", # default: None
                      help="create online help in restructured text"
                           "format. Use \"./txtcleanup.py --doc | rst2html\" "
                           "to create html-help"
                     )

    (options, args) = parser.parse_args()
    # options: the options-object
    # args: list of left-over args

    if options.summary:
        print_summary()
        sys.exit(0)

    if options.doc:
        print_doc()
        sys.exit(0)

    if options.test:
        _test()
        sys.exit(0)

    delta_dict= process_delta(options.delta)

    if not options.java:
        process_files(options,args,process_iterable,
                      options.german,options.rm_double,delta_dict)
    else:
        process_files(options,args,process_java_iterable,
                      options.german,options.rm_double,delta_dict)
    sys.exit(0)

if __name__ == "__main__":
    #print __doc__
    main()
