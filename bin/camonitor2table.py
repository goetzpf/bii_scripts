#! /usr/bin/env python
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

# pylint: disable=too-many-lines
"""
===================
 camonitor2table.py
===================
--------------------------------------------------------------
 a tool to convert outputs from camonitor to a table of values
--------------------------------------------------------------

Overview
===============
Camonitor, when used with more than one process variable, prints each new value
in a new line. Here is an example::

  U3IV:AdiUn9PmsPosI             2011-01-25 14:22:04.022486 0
  U3IV:AdiUn14PmsPosI            2011-01-25 14:22:04.022486 -3491
  U3IV:AdiUn9PmsPosI             2011-01-25 14:22:15.022486 329
  U3IV:AdiUn14PmsPosI            2011-01-25 14:22:15.022486 -4577
  U3IV:AdiUn14PmsPosI            2011-01-25 14:22:15.122486 -7045
  U3IV:AdiUn9PmsPosI             2011-01-25 14:22:15.122486 1111
  U3IV:AdiUn9PmsPosI             2011-01-25 14:22:15.222486 1470
  U3IV:AdiUn14PmsPosI            2011-01-25 14:22:15.222486 -8137
  U3IV:AdiUn9PmsPosI             2011-01-25 14:22:15.322486 1459
  U3IV:AdiUn14PmsPosI            2011-01-25 14:22:15.322486 -8121


Comparing several variables at the same time is sometimes made difficult by
this. A table-like format would be better in this case. This program does just
this, it creates a simple table from the output of a camonitor command that can
for example be used for gnuplot. Here is an example of such a table::

  Timestamp                  U3IV:AdiUn9PmsPosI U3IV:AdiUn14PmsPosI
  2011-01-25 14:22:04.022486 0                  -3491
  2011-01-25 14:22:15.022486 329                -4577
  2011-01-25 14:22:15.122486 1111               -7045
  2011-01-25 14:22:15.222486 1470               -8137
  2011-01-25 14:22:15.322486 1459               -8121

Examples
========

* convert a file to a table::

    camonitor2table.py -f myfile

    Timestamp                  U3IV:AdiUn14PmsPosI U3IV:AdiUn9PmsPosI
    2011-01-25 14:22:04.022486 -3491               0
    2011-01-25 14:22:15.022486 -4577               329
    2011-01-25 14:22:15.122486 -7045               1111
    2011-01-25 14:22:15.222486 -8137               1470
    2011-01-25 14:22:15.322486 -8121               1459

* convert a file, floating point format for each column, right justified::

    camonitor2table.py -f myfile -c '%f' --rjust

    Timestamp                  U3IV:AdiUn14PmsPosI U3IV:AdiUn9PmsPosI
    2011-01-25 14:22:04.022486        -3491.000000           0.000000
    2011-01-25 14:22:15.022486        -4577.000000         329.000000
    2011-01-25 14:22:15.122486        -7045.000000        1111.000000
    2011-01-25 14:22:15.222486        -8137.000000        1470.000000
    2011-01-25 14:22:15.322486        -8121.000000        1459.000000

* convert a file, floating point format for each column, right justified,
  floattime::

    camonitor2table.py -f myfile -c '%f' --rjust --floattime first

    Timestamp                  U3IV:AdiUn14PmsPosI U3IV:AdiUn9PmsPosI
                      0.000000        -3491.000000           0.000000
                     11.000000        -4577.000000         329.000000
                     11.100000        -7045.000000        1111.000000
                     11.200000        -8137.000000        1470.000000
                     11.300000        -8121.000000        1459.000000

* convert a file, a different format for each column, right justified,
  floattime::

    camonitor2table.py -f myfile -c '%.6f %.2f %d' --rjust --floattime first

    Timestamp                  U3IV:AdiUn14PmsPosI U3IV:AdiUn9PmsPosI
                      0.000000            -3491.00                  0
                     11.000000            -4577.00                329
                     11.100000            -7045.00               1111
                     11.200000            -8137.00               1470
                     11.300000            -8121.00               1459

* convert a file, floating point format for each column, right justified,
  floattime, differentiate::

    camonitor2table.py -f myfile -c '%.2f' --rjust --floattime first --differentiate

    Timestamp                  U3IV:AdiUn14PmsPosI U3IV:AdiUn9PmsPosI
                          0.00                0.00               0.00
                         11.00              -98.73              29.91
                         11.10           -24680.00            7820.00
                         11.20           -10920.00            3590.00
                         11.30              160.00            -110.00

* convert a file, floating point format for each column, right justified,
  separator::

    camonitor2table.py -f myfile -c '%f' --rjust --separator "|"

    Timestamp                 |U3IV:AdiUn14PmsPosI|U3IV:AdiUn9PmsPosI
    2011-01-25 14:22:04.022486|       -3491.000000|          0.000000
    2011-01-25 14:22:15.022486|       -4577.000000|        329.000000
    2011-01-25 14:22:15.122486|       -7045.000000|       1111.000000
    2011-01-25 14:22:15.222486|       -8137.000000|       1470.000000
    2011-01-25 14:22:15.322486|       -8121.000000|       1459.000000

* convert a file, floating point format for each column, csv::

    camonitor2table.py -f myfile -c '%f' --csv

    Timestamp,U3IV:AdiUn14PmsPosI,U3IV:AdiUn9PmsPosI
    2011-01-25 14:22:04.022486,-3491.000000,0.000000
    2011-01-25 14:22:15.022486,-4577.000000,329.000000
    2011-01-25 14:22:15.122486,-7045.000000,1111.000000
    2011-01-25 14:22:15.222486,-8137.000000,1470.000000
    2011-01-25 14:22:15.322486,-8121.000000,1459.000000

Reference of command line options
=================================

-h
  print a short help for all command line options.

--summary
  print a one-line summary of the scripts function

--doc
  create online help in restructured text. Use
  "./txtcleanup.py --doc | rst2html" to create html-help

-t, --test
  perform a simple self-test

--raw
  print the internal HashedList2D object, this is for debugging only.

--dump
  do not collect the data to a table but dump the data in camonitor format to
  the console. This may be useful if combined with some of the filter options
  or options that modify the timestamps or pv names.

-r, --rjust
  justify the values in each row to the right side. Note that the timestamps
  are always left justified except when the are converted to a floating point
  number (see --floattime).

-c, --columnformat FORMAT
  format columns with the given FORMAT. A FORMAT is a space separated list of
  format substrings that use the same conventions as C format strings. If only
  a single format is given, this is applied to all columns. If floattime is
  used, the same format is also applied to the timestamp field.

-s, --separator SEPARATOR
  specify the SEPARATOR that separates columns of the table. This string is
  also used to separate values when csv format is used (see --csv).

--csv
  produce a comma-separated list of values. Note that the separator character
  may be specified with the separator option (--separator).

--floattime STARTTIME
  convert timestamps floating point seconds when 0 corresponds to STARTTIME.
  If STARTTIME has the special value "FIRST", the first timestamp is taken as
  STARTTIME.

--from-time STARTTIME
  use only data where the timestamp is newer or equal to STARTTIME.

--to-time ENDTIME
  use only data where the timestamp is older or equal to ENDTIME.

--max-lines MAX
  stop after MAX lines have been fetched. This may be used for checking a
  command line with a very large file.

--filter-pv REGEXP
  select only PVs that match REGEXP.

--filter-complete
  select only rows where each column has a value.

--skip-flagged REGEXP
  Skip all lines where the flags match REGEXP, e.g. "UDF" skips all lines where
  the flags contain "UDF". If REGEXP has the special value "all" or "ALL", all
  flags are removed.

--rm-flags REGEXP
  remove all flags that match REGEXP from the data, e.g. "HIHI|HI" removes
  "HIHI" and "HI" from the flags.

--differentiate
  differentiate all values, that means that each value is replaced with the
  difference of this and the previous value for the same PV divided by the
  difference of the timestamp in seconds. The values must be numbers in order
  to be able to do this.

--fill
  fill empty places in the table with the first non-empty value in the same
  column from a row above.

--add-seconds [seconds]
  add the seconds given (a floating point value) to the timestamps.

--time-rebase [OLDTIME,NEWTIME]
  Add an offset to all timestamps. The offset is calculated to ensure that
  OLDTIME is changed to NEWTIME.

--pvmap [PVMAP]
  Defines a mapping that replaces a pv with a new name. A PVMAP is a string
  with the form 'OLDPV,NEWPV. You can specify more than one PVMAP.

--pvmaprx [REGEXP]
  Apply a regular expression to each pv to modify it. The REGEXP should have
  the form '/match/replace/'. You can specify more than one REGEXP, in this
  case all are applied in the order you specify them. REGEXPs are applied
  *after* PVMAP changes (see above).

--progress
  show the progress of the program on stderr. 2 numbers are printed, the first
  is the current line in the data file, the second one is the number of fetched
  lines.

-f, --file FILE
  read the data from FILE. If this parameter is missing, read from stdin.
"""

# pylint: enable=C0301
#                          Line too long
# pylint: disable=C0103
#                          Invalid constant name

from optparse import OptionParser
#import string
import sys
import re
import time  # actually only needed for Python Version < 2.7
import datetime
import os.path

# version of the program:
my_version= "1.0"

_last_str2date_str= None
_last_str2date_obj= None

# some functions for compability with python version 2.5
# unfortunately our development server has only python 2.5 as
# newest version:

def strptime_p25(st_,format_):
    """simulate datetime.datetime.strptime.
    """
    if not format_.endswith(".%f"):
        return datetime.datetime.strptime(st_,format_)
    p= st_.find(".")
    tp= time.strptime(st_[0:p],format_[0:-3])
    if p==-1:
        raise ValueError("date has wrong format_: \"%s\"" % st_)
    frac= int(st_[p+1:])
    date= datetime.datetime(tp[0],tp[1],tp[2],tp[3],tp[4],tp[5],frac)
    return date

def strftime_p25(date,format_):
    """simulate datetime.datetime.strptime.
    """
    if not format_.endswith(".%f"):
        return date.strftime(format_)
    return date.strftime(format_[0:-3]) + (".%06d" % date.microsecond)

def strftime(date,format_):
    """returns date.strftime(format_)."""
    return date.strftime(format_)

# pylint: disable=C0301
#                          Line too long

def time_total_seconds_25(td):
    """return the total seconds in a timedelta object for python 2.5.

    Here is an example:
    >>> td= datetime.datetime(2011,01,01,13,32,15,250000)-datetime.datetime(2011,01,01,13,30,0)
    >>> time_total_seconds_25(td)
    135.25
    """
    return float(td.days*86400+td.seconds)+td.microseconds/1E6

def time_total_seconds(td):
    """return the total seconds in a timedelta object.

    Here is an example:
    >>> td= datetime.datetime(2011,01,01,13,32,15,250000)-datetime.datetime(2011,01,01,13,30,0)
    >>> time_total_seconds(td)
    135.25
    """
    return td.total_seconds()

# pylint: enable=C0301
#                          Line too long

if sys.version_info < (2,7):
    strptime_= strptime_p25
    total_seconds_= time_total_seconds_25
    strftime_= strftime_p25
else:
    strptime_= datetime.datetime.strptime
    total_seconds_= time_total_seconds
    strftime_= strftime

# date and time utilities
# ----------------------------------------

# pylint: disable=C0301
#                          Line too long

def str2date(st):
    """convert an ascii time to a datetime.datetime object.

    Note that only 6 digits after a dot "." are significant. Extra
    digits are ignored. Extra characters other than digits raise
    a ValueError exception.

    Note that there is an optimization here that returns THE SAME
    date object when the string "st" given is the same as it was
    at the last call of this function.

    Here are some examples:
    >>> str2date("2011-01-25 14:22:20.822485")
    datetime.datetime(2011, 1, 25, 14, 22, 20, 822485)
    >>> str2date("2011-01-25 14:22:20.8224")
    datetime.datetime(2011, 1, 25, 14, 22, 20, 822400)
    >>> str2date("2011-01-25 14:22:20")
    datetime.datetime(2011, 1, 25, 14, 22, 20)
    >>> str2date("2011-01-25T14:22:20.8224")
    datetime.datetime(2011, 1, 25, 14, 22, 20, 822400)
    >>> str2date("2011-01-25T14:22:20xy.8224")
    Traceback (most recent call last):
        ...
    ValueError: time data '2011-01-25 14:22:20xy.8224' does not match format '%Y-%m-%d %H:%M:%S.%f'
    >>> str2date("2011-01-25T14:22:20.12345")
    datetime.datetime(2011, 1, 25, 14, 22, 20, 123450)
    >>> str2date("2011-01-25T14:22:20.123456")
    datetime.datetime(2011, 1, 25, 14, 22, 20, 123456)
    >>> str2date("2011-01-25T14:22:20.1234567")
    datetime.datetime(2011, 1, 25, 14, 22, 20, 123456)
    >>> str2date("2011-01-25T14:22:20.12345678")
    datetime.datetime(2011, 1, 25, 14, 22, 20, 123456)
    >>> str2date("2011-01-25T14:22:20.12345678x")
    Traceback (most recent call last):
        ...
    ValueError: extra characters found: "78x"
    """
    # pylint: disable=global-statement
    global _last_str2date_str, _last_str2date_obj
    st_= st.replace("T"," ",1)
    if _last_str2date_str==st_:
        return _last_str2date_obj
    i= st_.find(".")
    if i==-1:
        date= strptime_(st_,"%Y-%m-%d %H:%M:%S")
    else:
        if len(st_)-i > 7:
            if not st_[i+7:].isdigit():
                raise ValueError("extra characters found: \"%s\"" % \
                                 st_[i+7:])
        date= strptime_(st_[0:i+7],"%Y-%m-%d %H:%M:%S.%f")
    _last_str2date_str= st_
    _last_str2date_obj= date
    return date

# pylint: enable=C0301
#                          Line too long

def str2date_ui(st):
    """do str2date but with better error handling."""
    if st is None:
        return None
    try:
        d= str2date(st)
    except ValueError,_:
        sys.exit("error: \"%s\" is not a valid timestamp" % st)
    return d

def date2str(date):
    """convert a datetime.datetime object to ascii time.

    Here is an example:
    >>> d= str2date("2011-01-25 14:22:20.822485")
    >>> date2str(d)
    '2011-01-25 14:22:20.822485'
    """
    return strftime_(date, "%Y-%m-%d %H:%M:%S.%f")

def float_time(date, start_date):
    """convert timestamps to float-time.

    parameters:
      date       -- the date to convert, a datetime.datetime object.
      start_date -- The date that should be 0.0 as float-time.
    return:
      a float that gives the number of seconds passed since start_date.

    Here are some examples:
    >>> float_time(str2date("2011-01-25 14:22:20.822485"),
    ...            str2date("2011-01-24 14:22:20.822485"))
    86400.0
    >>> float_time(str2date("2011-01-25 14:22:20.822485"),
    ...            str2date("2011-01-24 14:22:20"))
    86400.822485
    """
    return total_seconds_(date-start_date)

# classes
# ----------------------------------------

class RxReplace(object):
    """Change a string with a regular expression."""
    # pylint: disable=R0903
    #                          Too few public methods
    _rx_re= re.compile(r'(?<!\\)/(.*)(?<!\\)/(.*)(?<!\\)/(.*)')
    def __init__(self, st):
        """initialize the object."""
        m= RxReplace._rx_re.match(st)
        if not m:
            raise ValueError("invalid replacement regexp: '%s'" % st)
        self.flags=0
        for char in m.group(3):
            try:
                self.flags|= getattr(re, char.upper())
            except AttributeError, _:
                raise ValueError("unknown flag '%s' in regexp '%s'" % \
                                 (char,st))
        self.rx= re.compile(m.group(1), self.flags)
        self.repl= m.group(2)
    def sub(self,st):
        """do the replacement."""
        return self.rx.sub(self.repl, st)

class RxReplacer(object):
    """Change a string with a regular expressions."""
    # pylint: disable=R0903
    #                          Too few public methods
    def __init__(self, st_list):
        """initialize the container."""
        self.rxs= []
        for st in st_list:
            self.rxs.append(RxReplace(st))
        self.cache= {}
    def sub(self, st):
        """change the string according to regexps.

        Do only apply the *first* matching regexp.
        Cache the results to make things faster.
        """
        cached= self.cache.get(st)
        if cached:
            return cached
        n= st
        for rx in self.rxs:
            n= rx.sub(n)
        if n!=st:
            self.cache[st]= n
            return n
        self.cache[st]= st
        return st

class HashIndex(object):
    """maps a string to an index.

    This associates a fixed index to each string it is given.

    Here are some examples:

    >>> h= HashIndex(("A","B"))
    >>> h
    HashIndex(['A', 'B'])
    >>> h.index("A")
    0
    >>> h.index("B")
    1
    >>> h.last()
    1
    >>> h.index("C")
    2
    >>> h.last()
    2
    >>> h.keys()
    ['A', 'B', 'C']
    >>> h.has_key("A")
    True
    >>> h.has_key("X")
    False
    >>> h.relabel("B","BB")
    >>> h.index("BB")
    1
    >>> h.delete("BB")
    >>> h
    HashIndex(['A', 'C'])
    """
    def __init__(self, iterable=None):
        self._map= {}
        self._last= -1
        if iterable:
            for k in iterable:
                self.index(k)
    def index(self, key):
        """Return an index or create one."""
        i= self._map.get(key)
        if i is None:
            i= self._last+1
            self._last= i
            self._map[key]= i
        return i
    def delete(self, key):
        """Delete an index."""
        del self._map[key]
    def relabel(self, old_key, new_key):
        """Give a key a new name."""
        self._map[new_key]= self._map[old_key]
        del self._map[old_key]
    def last(self):
        """Return the last index."""
        return self._last
    def keys(self):
        """Return a sorted list of keys."""
        #return sorted(self._map.keys(), key= lambda x: self._map[x])
        return sorted(self._map.keys())
    def has_key(self, val):
        """Test if a key is in the map."""
        return self._map.has_key(val)
    def __repr__(self):
        """return "repr" string of the object."""
        return "HashIndex(%s)" % repr(self.keys())
    def __str__(self):
        """return "repr" string of the object."""
        return repr(self)

# pylint: disable=C0301
#                          Line too long

class HashedList(object):
    """gives access to elements of a list by a hash key.

    Here are some examples:
    >>> h= HashedList([("A","x"),("B","y")])
    >>> h
    HashedList([('A', 'x'), ('B', 'y')])
    >>> h.lookup("A")
    'x'
    >>> h.lookup("C","z")
    'z'
    >>> h
    HashedList([('A', 'x'), ('B', 'y'), ('C', 'z')])
    >>> h.lookup("D",constructor=lambda:[]).append(1)
    >>> h
    HashedList([('A', 'x'), ('B', 'y'), ('C', 'z'), ('D', [1])])
    >>> h.lookup("E",constructor=lambda:[]).append(2)
    >>> h
    HashedList([('A', 'x'), ('B', 'y'), ('C', 'z'), ('D', [1]), ('E', [2])])
    >>> h.set("E","new-val")
    >>> h
    HashedList([('A', 'x'), ('B', 'y'), ('C', 'z'), ('D', [1]), ('E', 'new-val')])
    >>> h.has_key("B")
    True
    >>> h.has_key("X")
    False
    >>> h.relabel("C","CC")
    >>> h
    HashedList([('A', 'x'), ('B', 'y'), ('CC', 'z'), ('D', [1]), ('E', 'new-val')])
    >>> h.keys()
    ['A', 'B', 'CC', 'D', 'E']
    >>> h.delete("CC")
    >>> h
    HashedList([('A', 'x'), ('B', 'y'), ('D', [1]), ('E', 'new-val')])

    >>> I=HashIndex()
    >>> h=HashedList(hashindex=I)
    >>> h.set("A","value 1")
    >>> h
    HashedList([('A', 'value 1')])
    >>> I
    HashIndex(['A'])
    """
    # pylint: enable=C0301
    #                          Line too long
    def __init__(self, iterable=None, hashindex=None):
        """The object constructor.

        Paremeters:
            iterable  -- an optional list of pairs (2-element tuples)
                         that is used to initialize the object
            hashindex -- an optional external HashIndex object that is
                         used to manage the keys. If this is not given
                         an internal HashIndex object is created an used.
        """
        if hashindex is None:
            hashindex= HashIndex()
        self._h_index= hashindex
        self._list= []
        if iterable:
            for (k,v) in iterable:
                self.lookup(k,v)
    def _index(self, key, value= None, constructor= None):
        """Return or create the internal index."""
        i= self._h_index.index(key)
        if i<len(self._list):
            return i
        if value is not None:
            constructor= lambda: value
        else:
            if constructor is None:
                constructor= lambda: None
        while i>=len(self._list):
            self._list.append(constructor())
        return i
    def delete(self, key):
        """Delete a key."""
        self._h_index.delete(key)
    def lookup(self, key, value= None, constructor= None):
        """lookup a key."""
        return self._list[self._index(key, value, constructor)]
    def set(self, key, set_value, value= None, constructor= None):
        """Set a value."""
        self._list[self._index(key, value, constructor)]= set_value
    def relabel(self, old_key, new_key):
        """Change the name of a key."""
        self._h_index.relabel(old_key, new_key)
    def keys(self):
        """Return all the keys."""
        return self._h_index.keys()
    def has_key(self, val):
        """Test if a key is known to the object."""
        return self._h_index.has_key(val)
    def __repr__(self):
        """return "repr" string of the object."""
        l= []
        for k in self.keys():
            l.append((k, self.lookup(k)))
        return "HashedList(%s)" % repr(l)
    def __str__(self):
        """return "repr" string of the object."""
        return repr(self)

class HashedList2D(object):
    """a 2-dimensional HashedList.

    Here are some examples:
    >>> h= HashedList2D()
    >>> h.set(1,"A", "x")
    >>> print h
    (1,A) : x
    >>> h.set(1,"B", "y")
    >>> h.set(2,"B", "z")
    >>> print h
    (1,A) : x
    (1,B) : y
    (2,A) : None
    (2,B) : z
    >>> h.rows()
    [1, 2]
    >>> h.columns()
    ['A', 'B']
    >>> h.has_row(1)
    True
    >>> h.has_row(3)
    False
    >>> h.has_column("A")
    True
    >>> h.has_column("C")
    False
    >>> h.relabel_row(2,3)
    >>> print h
    (1,A) : x
    (1,B) : y
    (3,A) : None
    (3,B) : z
    >>> h.fill_incomplete(lambda x: x is None)
    >>> print h
    (1,A) : x
    (1,B) : y
    (3,A) : x
    (3,B) : z
    """
    def __init__(self):
        self._rows= HashedList()
        self._column_hashindex= HashIndex()
    def delete_row(self, row):
        """Delete a row."""
        self._rows.delete(row)
    def lookup(self, row, column, value= None, constructor= None):
        """Lookup or create a value."""
        val= self._rows.lookup(row, constructor=lambda: HashedList(hashindex= self._column_hashindex))
        return val.lookup(column, value= value, constructor= constructor)
    def set(self, row, column, set_value, value= None, constructor= None):
        """Set a value."""
        # pylint: disable=R0913
        #                          Too many arguments
        val= self._rows.lookup(row, constructor=lambda: HashedList(hashindex= self._column_hashindex))
        return val.set(column, set_value= set_value, value= value, constructor= constructor)
    def rows(self):
        """Return number of rows."""
        return self._rows.keys()
    def columns(self):
        """Return number of columns."""
        return self._column_hashindex.keys()
    def has_row(self, val):
        """Test if a row is known to the object."""
        return self._rows.has_key(val)
    def has_column(self, val):
        """Test if a column is known to the object."""
        return self._column_hashindex.has_key(val)
    def relabel_row(self, old_row, new_row):
        """Give a row a new name."""
        self._rows.relabel(old_row, new_row)
    def fill_incomplete(self, is_empty_func=None):
        """Fills empty cells with the value from the previous row."""
        if is_empty_func is None:
            is_empty_func= lambda x: x is None
        last= None
        column_list= self.columns()
        for row in self._rows.keys():
            if last is None:
                last= row
                continue
            for col in column_list:
                if is_empty_func(self.lookup(row, col)):
                    # note that "[:]" is VERY important here, this copies
                    # the whole list. Otherwise the resulting structure would
                    # contain references to the SAME LIST at several places which
                    # would break the differentiate() function:
                    val= self.lookup(last,col)
                    if val is not None:
                        val= val[:]
                    self.set(row, col, val)
            last= row
    def filter_complete(self, is_empty_func=None):
        """Removes rows where not all columns have a value."""
        if is_empty_func is None:
            is_empty_func= lambda x: x is None
        row_list= self._rows.keys()
        column_list= self.columns()
        for row in row_list:
            for col in column_list:
                if is_empty_func(self.lookup(row, col)):
                    self._rows.delete(row)
                    continue
    def __str__(self):
        rows= self._rows.keys()
        columns= self._column_hashindex.keys()
        lines=[]
        for r in rows:
            for c in columns:
                lines.append("(%s,%s) : %s" % (r,c,self.lookup(r,c)))
        return "\n".join(lines)

# string utilities
# ----------------------------------------

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
    if len(string)==0:
        return True
    return string.isspace()

def parse_line(line):
    """parses a line from the camonitor command.

    parameters:
        line    -- a line from camonitor
    returns:
        (pv,date,lst) with
        pv   -- the name of the process variable, a string
        date -- a datetime.datetime object with the whole-second part of
                the timestamp
        lst  -- the value list consisting of the value and optional flags

    Note that "<undefined>" as a timestamp is converted to the date
    1970-01-01 00:00:00.

    Here are some examples:
    >>> parse_line("U41IT6R:AdiUnV1DrvDstG  2011-01-24 23:24:05.612206 -4.36907e+06")
    ('U41IT6R:AdiUnV1DrvDstG', datetime.datetime(2011, 1, 24, 23, 24, 5, 612206), ['-4.36907e+06'])
    >>> parse_line("U41IT6R:AcsDisable       2011-01-10 11:42:29.050755 enabled UDF INVALID")
    ('U41IT6R:AcsDisable', datetime.datetime(2011, 1, 10, 11, 42, 29, 50755), ['enabled', 'UDF', 'INVALID'])
    >>> parse_line("U41IT6R:AdiUn2GblVer    <undefined> 0 UDF INVALID")
    ('U41IT6R:AdiUn2GblVer', datetime.datetime(1970, 1, 1, 0, 0), ['0', 'UDF', 'INVALID'])
    """
    elms= line.split()
    val_i= 3
    if elms[1]=="<undefined>":
        val_i= 2
        date= datetime.datetime(1970,1,1,0,0,0) # use 1970-01-01 00:00:00 instead of "None"
    else:
        date= str2date(" ".join(elms[1:3]))
    return (elms[0],date,elms[val_i:])

def rebuild_line(tp):
    """rebuild a line from the tuple that parse_line creates."""
    return "%-24s %-26s %s" % (tp[0],date2str(tp[1])," ".join(tp[2]))

# higher level functions
# ----------------------------------------

def collect(iterable, hashedlist2d=None, from_time=None, to_time=None,
            filter_pv= None,
            skip_flagged= None, rm_flags= None,
            pvmap= None,
            pvmaprx= None,
            timedelta= None,
            dump= False,
            max_lines= None,
            progress=False):
    r"""collect items from an iterable.

    returns a HashedList2D object.

    parameters:
      iterable      -- the iterable containing strings
      hashedlist2d  -- the HashedList2D object that is used to store items. If
                       it is not given it is created.
      from_time     -- If this parameter is given, only items where the
                       timestamp is equal or after that time are taken.
      to_time       -- If this parameter is given, only items where the
                       timestamp is before or equal that time are taken.
      filter_pv     -- If that parameter is given, only process variables that
                       match that regular expression are taken.
      skip_flagged  -- If this parameter is True, items with flags are skipped
                       (ignored).
      rm_flags      -- If that parameter is given, flags that match that
                       regular expression are removed, the resulting item is taken.
      pvmap         -- A dict that defines a map mapping PV names to new
                       PV names
      pvmaprx       -- A list of RxReplace objects used to change PV names.
      timedelta     -- If given, add this timedelta object to the timestamp.
      dump          -- dump data in camonitor format to console
      max_lines     -- If the number of items taken would exceed that number,
                       no more items are taken.
      progress      -- If this parameter is True, the current progress is shown
                       on stderr.
    returns:
      a HashedList2D object. If the hashedlist2d parameter was given, this is
      returned. Otherwise a new created HashedList2D object is returned.

    Here is an example:
    >>> t='''
    ... U3IV:AdiUn14PmsPosI            2011-01-25 14:22:15.522486 -12078
    ... U3IV:AdiUn9PmsPosI             2011-01-25 14:22:15.622486 2925
    ... U3IV:AdiUn14PmsPosI            2011-01-25 14:22:15.622486 -12753
    ... U3IV:AdiUn9PmsPosI             2011-01-25 14:22:15.722486 2915
    ... U3IV:AdiUn14PmsPosI            2011-01-25 14:22:15.722486 -12741
    ... U3IV:AdiUn9PmsPosI             2011-01-25 14:22:15.822486 3371
    ... U3IV:AdiUn14PmsPosI            2011-01-25 14:22:15.822486 -14212
    ... '''
    >>> results=collect(t.splitlines())
    >>> print results
    (2011-01-25 14:22:15.522486,U3IV:AdiUn14PmsPosI) : ['-12078']
    (2011-01-25 14:22:15.522486,U3IV:AdiUn9PmsPosI) : None
    (2011-01-25 14:22:15.622486,U3IV:AdiUn14PmsPosI) : ['-12753']
    (2011-01-25 14:22:15.622486,U3IV:AdiUn9PmsPosI) : ['2925']
    (2011-01-25 14:22:15.722486,U3IV:AdiUn14PmsPosI) : ['-12741']
    (2011-01-25 14:22:15.722486,U3IV:AdiUn9PmsPosI) : ['2915']
    (2011-01-25 14:22:15.822486,U3IV:AdiUn14PmsPosI) : ['-14212']
    (2011-01-25 14:22:15.822486,U3IV:AdiUn9PmsPosI) : ['3371']
    """
    # pylint: disable=R0913
    #                          Too many arguments
    # pylint: disable=R0914
    #                          Too many local variables
    # pylint: disable=R0912
    #                          Too many branches
    # pylint: disable=R0915
    #                          Too many statements
    if filter_pv is not None:
        filter_pv= re.compile(filter_pv)
    if skip_flagged is not None:
        skip_flagged= re.compile(skip_flagged)
    if rm_flags is not None:
        if rm_flags.lower()=="all":
            rm_flags= re.compile(".*")
        else:
            rm_flags= re.compile(rm_flags)

    lineno=0
    progress_cnt=0
    if hashedlist2d is None:
        hashedlist2d= HashedList2D()
    h= hashedlist2d
    lines=0
    if progress:
        sys.stderr.write("%8d %8d" % (lineno,lines))
    for line in iterable:
        lineno+=1
        if progress:
            progress_cnt+=1
            if progress_cnt >= 2659: # a prime number to make display nicer
                progress_cnt= 0
                sys.stderr.write("\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b%8d %8d" % (lineno,lines))
        if empty(line):
            continue
        try:
            (pv,date,val)= parse_line(line)
        except:
            print "parse error in line %d" % lineno
            raise
        if from_time is not None:
            if date<from_time:
                continue
        if to_time is not None:
            if date>to_time:
                continue
        if timedelta:
            date+= timedelta
        if filter_pv is not None:
            # if the pv was already taken some time before,
            # we can skip a new regexp match:
            if not re.search(filter_pv,pv):
                continue
        if len(val)>1: # flags present
            flag_str= " ".join(val[1:])
            if skip_flagged is not None:
                if re.search(skip_flagged,flag_str) is not None:
                    continue
            if rm_flags is not None:
                flag_str= re.sub(rm_flags,"",flag_str)
                val= [val[0]]+flag_str.split()
        if pvmap:
            pv= pvmap.get(pv, pv)
        if pvmaprx:
            pv= pvmaprx.sub(pv)

        if dump:
            print rebuild_line((pv, date, val))
        else:
            h.set( date, pv, val )
        lines+=1
        if max_lines is not None:
            if lines>=max_lines:
                break
    if progress:
        sys.stderr.write("\n")
    if dump:
        return
    return h

# pylint: disable=C0303
#                          Trailing whitespace

def pretty_print(hashedlist2d, columnformat=None, rjust= False,
                 is_floattime= False,
                 separator=" ", csv=False):
    """pretty print the results from collect().

    Here are some examples:
    >>> t='''
    ... U3IV:AdiUn14PmsPosI            2011-01-25 14:22:15.522486 -12078
    ... U3IV:AdiUn9PmsPosI             2011-01-25 14:22:15.622486 2925
    ... U3IV:AdiUn14PmsPosI            2011-01-25 14:22:15.622486 -12753
    ... U3IV:AdiUn9PmsPosI             2011-01-25 14:22:15.722486 2915
    ... U3IV:AdiUn14PmsPosI            2011-01-25 14:22:15.722486 -12741
    ... U3IV:AdiUn9PmsPosI             2011-01-25 14:22:15.822486 3371
    ... U3IV:AdiUn14PmsPosI            2011-01-25 14:22:15.822486 -14212
    ... '''
    >>> results=collect(t.splitlines())
    >>> pretty_print(results)
    Timestamp                  U3IV:AdiUn14PmsPosI U3IV:AdiUn9PmsPosI
    2011-01-25 14:22:15.522486 -12078                                
    2011-01-25 14:22:15.622486 -12753              2925              
    2011-01-25 14:22:15.722486 -12741              2915              
    2011-01-25 14:22:15.822486 -14212              3371              
    >>> pretty_print(results,columnformat=["%.1f"])
    Timestamp                  U3IV:AdiUn14PmsPosI U3IV:AdiUn9PmsPosI
    2011-01-25 14:22:15.522486 -12078.0                              
    2011-01-25 14:22:15.622486 -12753.0            2925.0            
    2011-01-25 14:22:15.722486 -12741.0            2915.0            
    2011-01-25 14:22:15.822486 -14212.0            3371.0            
    >>> pretty_print(results,columnformat=["%30s","%d","%.1f"])
    Timestamp                      U3IV:AdiUn14PmsPosI U3IV:AdiUn9PmsPosI
        2011-01-25 14:22:15.522486 -12078                                
        2011-01-25 14:22:15.622486 -12753              2925.0            
        2011-01-25 14:22:15.722486 -12741              2915.0            
        2011-01-25 14:22:15.822486 -14212              3371.0            
    >>> pretty_print(results,rjust=True)
    Timestamp                  U3IV:AdiUn14PmsPosI U3IV:AdiUn9PmsPosI
    2011-01-25 14:22:15.522486              -12078                   
    2011-01-25 14:22:15.622486              -12753               2925
    2011-01-25 14:22:15.722486              -12741               2915
    2011-01-25 14:22:15.822486              -14212               3371
    >>> pretty_print(results,separator="|")
    Timestamp                 |U3IV:AdiUn14PmsPosI|U3IV:AdiUn9PmsPosI
    2011-01-25 14:22:15.522486|-12078             |                  
    2011-01-25 14:22:15.622486|-12753             |2925              
    2011-01-25 14:22:15.722486|-12741             |2915              
    2011-01-25 14:22:15.822486|-14212             |3371              
    >>> pretty_print(results,csv=True)
    Timestamp U3IV:AdiUn14PmsPosI U3IV:AdiUn9PmsPosI
    2011-01-25 14:22:15.522486 -12078 
    2011-01-25 14:22:15.622486 -12753 2925
    2011-01-25 14:22:15.722486 -12741 2915
    2011-01-25 14:22:15.822486 -14212 3371
    >>> pretty_print(results,csv=True,separator=",")
    Timestamp,U3IV:AdiUn14PmsPosI,U3IV:AdiUn9PmsPosI
    2011-01-25 14:22:15.522486,-12078,
    2011-01-25 14:22:15.622486,-12753,2925
    2011-01-25 14:22:15.722486,-12741,2915
    2011-01-25 14:22:15.822486,-14212,3371
    """
    # pylint: disable=R0914
    #                          Too many local variables
    # pylint: disable=R0912
    #                          Too many branches
    # pylint: disable=R0915
    #                          Too many statements
    # pylint: disable=R0913
    #                          Too many arguments
    def tp(st,columnformat,converter):
        """convert data."""
        if st is None:
            return ""
        lst= list(st)
        lst[0]= converter(st[0])
        lst[0]= columnformat % lst[0]
        return " ".join(lst)
    columns= ["Timestamp                 "]
    columns.extend(hashedlist2d.columns())

    if (columnformat is None) or (len(columnformat)==0):
        columnformat= ["%s"]*len(columns)
    elif len(columnformat)<len(columns):
        # extend the last format string for all following columns:
        columnformat.extend(\
                 [columnformat[-1]]*(len(columns)-len(columnformat)))
    converters=[]
    just = [rjust] * len(columns)
    if not is_floattime:
        just[0]= False

    for c in xrange(len(columnformat)):
        f= columnformat[c]
        # pylint: disable=W0108
        #                          Unnecessary lambda
        try:
            _= f % "x"
            type_= "string"
        except TypeError,_:
            type_= "number"
        if type_=="number" and c==0 and (not is_floattime):
            columnformat[0]="%s"
            type_= "string"

        if type_=="string":
            converters.append(lambda x: str(x))
        else:
            converters.append(lambda x: float(x))

    lines= [columns[:]] # initialize with the heading
    for date in hashedlist2d.rows():
        lst=[]
        lines.append(lst)
        i= 0
        if isinstance(date,datetime.datetime):
            val_tp= (date2str(date),)
        else:
            val_tp= (date,)
        lst.append(tp(val_tp, columnformat[i], converters[i]))
        for i in xrange(1,len(columns)):
            col= columns[i]
            val_tp= hashedlist2d.lookup(date,col)
            lst.append(tp(val_tp, columnformat[i], converters[i]))

    widths= [None]*len(columns)
    for line in lines:
        for i in xrange(len(line)):
            if widths[i] < len(line[i]):
                widths[i]= len(line[i])
    for r in xrange(len(lines)):
        line= lines[r]
        n= []
        for c in xrange(len(line)):
            if csv:
                n.append(line[c].strip())
            elif not just[c]:
                n.append(line[c].ljust(widths[c]))
            else:
                n.append(line[c].rjust(widths[c]))
        print separator.join(n)

# pylint: enable=C0303
#                          Trailing whitespace

def convert_to_float_time(start_date, hashedlist2d):
    """convert all times in the HashedList2D object to float-time.
    """
    rows= hashedlist2d.rows()
    for r in rows:
        if start_date is None:
            start_date= r
        hashedlist2d.relabel_row(r, float_time(r, start_date))

def differentiate(hashedlist2d):
    """differentiate at each point.
    """
    def number(val):
        """try to return a number from val."""
        if val is None:
            return
        try:
            return float(val[0])
        except ValueError, _:
            return

    #print "hashedlist2d:", str(hashedlist2d)
    columns= hashedlist2d.columns()
    last= [None]*len(columns)
    last_row= None
    for r in hashedlist2d.rows():
        if last_row is None:
            t= 0
        else:
            if isinstance(r,datetime.datetime):
                t= total_seconds_(r-last_row)
            else:
                t= r-last_row
        last_row= r
        for i in xrange(len(columns)):
            buf= hashedlist2d.lookup(r,columns[i])
            # each buf is a list of a number and optionally PV flags like
            # "NO_ALARM' etc.
            # if there hasn't been a value for that timestamp, buf is None.
            # number() returns None if this is the case or if buf[0] is no
            # floating point number:
            no= number(buf)
            if no is None:
                hashedlist2d.set(r,columns[i],[0])
                continue
            if last[i] is None:
                last[i]= no
                buf[0]= 0
                continue
            # the value is overwritten with the derivative:
            buf[0]= (no-last[i])/t
            #hashedlist2d.set(r,columns[i], buf)
            last[i]= no

def collect_from_file(filename_, hashedlist2d=None,
                      from_time=None, to_time=None,
                      filter_pv= None,
                      skip_flagged= None,
                      rm_flags= None,
                      pvmap= None,
                      pvmaprx= None,
                      timedelta= None,
                      dump= False,
                      max_lines= None,
                      progress= False):
    """process input from standard-in or from a file.

    parameters:
      filename_      -- name of the file or None for STDIN
      results        -- dictionary where the results are stored
      process_func   -- function to process each file
    """
    # pylint: disable=R0913
    #                          Too many arguments
    if filename_ is None:
        in_file= sys.stdin
        sys.stderr.write("(read from stdin)\n")
    else:
        in_file= open(filename_)
    try:
        result= collect(in_file, hashedlist2d, from_time, to_time,
                        filter_pv, skip_flagged, rm_flags,
                        pvmap,
                        pvmaprx,
                        timedelta,
                        dump,
                        max_lines,
                        progress)
    except:
        if filename_ is not None:
            print "in file %s" % filename_
        raise
    in_file.close()
    if dump:
        return
    return result

def process_files(options,args):
    """process all files given on the command line.

    parameters:
      options      --  this may contain a "file" member with
                       the filename
      args         --  this may be a list of strings containing
                       extra filenames

    output:
      prints the sorted values to standard-out
    """
    # pylint: disable=R0912
    #                          Too many branches
    # pylint: disable=R0914
    #                          Too many local variables
    # pylint: disable=R0915
    #                          Too many statements
    filelist= []
    if options.file:
        filelist=options.file
    if len(args)>0: # extra arguments
        filelist.extend(args)
    if len(filelist)<=0:
        filelist= [None] # None: read from stdin
    results= HashedList2D()
    from_time= str2date_ui(options.from_time)
    to_time= str2date_ui(options.to_time)
    timedelta= None
    if options.add_seconds:
        try:
            add_seconds= float(options.add_seconds)
        except ValueError, _:
            sys.exit("error: argument to --add-seconds must be a float")
        timedelta= datetime.timedelta(0, add_seconds)
    if options.time_rebase:
        (d1,d2)= (str2date(d) for d in options.time_rebase.split(","))
        if timedelta is None:
            timedelta= d2-d1
        else:
            timedelta= timedelta + (d2-d1)

    if options.pvmap:
        pvmap= dict([s.split(",") for s in " ".join(options.pvmap).split()])
    else:
        pvmap= None

    if options.pvmaprx:
        pvmaprx= RxReplacer(options.pvmaprx)
    else:
        pvmaprx= None

    for f in filelist:
        collect_from_file(f, results,
                          from_time= from_time,
                          to_time= to_time,
                          filter_pv= options.filter_pv,
                          skip_flagged= options.skip_flagged,
                          rm_flags= options.rm_flags,
                          pvmap= pvmap,
                          pvmaprx= pvmaprx,
                          timedelta= timedelta,
                          dump= options.dump,
                          max_lines= options.max_lines,
                          progress=options.progress)
    if options.dump:
        return
    if options.fill:
        results.fill_incomplete()
    if options.floattime:
        if options.floattime.lower()=="first":
            start_date= None
        else:
            start_date= str2date_ui(options.floattime)
        convert_to_float_time(start_date, results)
    if options.filter_complete:
        results.filter_complete()
    if options.differentiate:
        differentiate(results)
    if options.raw:
        print results
    else:
        if options.separator is None:
            if options.csv:
                separator= ","
            else:
                separator= " "
        else:
            separator= options.separator
        columnformat= []
        if options.columnformat is not None:
            columnformat= options.columnformat.split()
        pretty_print(results, columnformat,
                     options.rjust,
                     options.floattime,
                     separator, options.csv)

def script_shortname():
    """return the name of this script without a path component."""
    return os.path.basename(sys.argv[0])

def print_summary():
    """print a short summary of the scripts function."""
    print "%-20s: convert camonitor data to a table of values\n" % \
          script_shortname()

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
                      help= "print a one-line summary of the scripts function",
                     )

    parser.add_option("-t", "--test",
                      action="store_true",
                      help="perform a simple self-test",
                     )
    parser.add_option("--raw",
                      action="store_true",
                      help="print the internal HashedList2D object, this "
                           "is for debugging only.",
                     )
    parser.add_option("--dump",     # implies dest="switch"
                      action="store_true", # default: None
                      help="do not collect the data to a table but dump the "
                           "data in camonitor format to the console. This "
                           "may be useful if combined with some of the "
                           "filter options or options that modify the "
                           "timestamps or pv names.)",
                     )
    parser.add_option("-r", "--rjust",
                      action="store_true",
                      help="justify the values in each row to the right "
                           "side. Note that the timestamps are always left "
                           "justified except when the are converted to a "
                           "floating point number (see --floattime).",
                     )
    parser.add_option("-c", "--columnformat",
                      action="store",
                      type="string",
                      help="format columns with the given FORMAT. A FORMAT is "+\
                           "a space separated list of format substrings that use "+\
                           "the same conventions as C format strings. If only a single "+\
                           "format is given, this is applied to all columns. If floattime "+\
                           "is used, the same format is also applied to the timestamp field.",
                      metavar="FORMAT"
                     )
    parser.add_option("-s", "--separator",
                      action="store",
                      type="string",
                      help="specify the SEPARATOR that separates columns of "
                           "the table. This string is also used to separate "
                           "values when csv format is used (see --csv).",
                      metavar="SEPARATOR"
                     )
    parser.add_option("--csv",
                      action="store_true",
                      help="format columns with the given FORMAT. A FORMAT "
                           "is a space separated list of format substrings "
                           "that use the same conventions as C format "
                           "strings. If only a single format is given, this "
                           "is applied to all columns. If floattime is used, "
                           "the same format is also applied to the timestamp "
                           "field.",
                     )
    parser.add_option("--floattime",
                      action="store",
                      type="string",
                      help="convert timestamps floating point seconds when "
                           "0 corresponds to STARTTIME.  If STARTTIME has "
                           "the special value 'FIRST', the first timestamp "
                           "is taken as STARTTIME.",
                      metavar="START"
                     )
    parser.add_option("--from-time",
                      action="store",
                      type="string",
                      help="use only data where the timestamp is newer "
                           "or equal to STARTTIME.",
                      metavar="TIMESTAMP"
                     )
    parser.add_option("--to-time",
                      action="store",
                      type="string",
                      help="use only data where the timestamp is older "
                           "or equal to ENDTIME.",
                      metavar="TIMESTAMP"
                     )
    parser.add_option("--max-lines",
                      action="store",
                      type="int",
                      help="stop after MAX lines have been fetched. This "
                           "may be used for checking a command line with a "
                           "very large file.",
                      metavar="MAX"
                     )
    parser.add_option("--filter-pv",
                      action="store",
                      type="string",
                      help="select only PVs that match REGEXP",
                      metavar="REGEXP"
                     )
    parser.add_option("--filter-complete",
                      action="store_true",
                      help="select only rows where each column has a value",
                     )
    parser.add_option("--skip-flagged",
                      action="store",
                      type="string",
                      help="Skip all lines where the flags match REGEXP, "
                           "e.g. 'UDF' skips all lines where the flags "
                           "contain 'UDF'. If REGEXP has the special "
                           "value 'all' or 'ALL', all flags are removed.",
                      metavar="REGEXP"
                     )
    parser.add_option("--rm-flags",
                      action="store",
                      type="string",
                      help="remove all flags that match REGEXP from the "
                           "data, e.g. 'HIHI|HI' removes 'HIHI' and 'HI' "
                           "from the flags.",
                      metavar="REGEXP"
                     )
    parser.add_option("--differentiate",
                      action="store_true",
                      help="differentiate all values, that means that "
                           "each value is replaced with the difference of "
                           "this and the previous value for the same PV "
                           "divided by the difference of the timestamp in "
                           "seconds. The values must be numbers in order to "
                           "be able to do this.",
                     )
    parser.add_option("--fill",
                      action="store_true",
                      help="fill empty places in the table with the first "
                           "non-empty value in the same column from a "
                           "row above.",
                     )
    parser.add_option("--add-seconds",
                      action="store",
                      type="string",
                      help="add the seconds given (a floating point value) "
                           "to the timestamps.",
                      metavar="SECONDS"
                     )
    parser.add_option("--time-rebase",
                      action="store",
                      type="string",
                      help="Add an offset to all timestamps. The offset is "
                           "calculated to ensure that OLDTIME is changed "
                           "to NEWTIME.",
                      metavar="TIMESPEC"
                     )
    parser.add_option("-P", "--pvmap",
                      action="append",
                      type="string",
                      help="Defines a mapping that replaces a pv with a "
                           "new name. A PVMAP is a string with the form "
                           "'OLDPV,NEWPV. You can specify more than one "
                           "PVMAP.",
                      metavar="PVMAP"
                     )
    parser.add_option("--pvmaprx",
                      action="append",
                      type="string",
                      help="Apply a regular expression to each pv to modify "
                           "it. The REGEXP should have the form "
                           "'/match/replace/'. You can specify more than "
                           "one REGEXP, in this case all are applied in the "
                           "order you specify them. REGEXPs are applied "
                           "*after* PVMAP changes (see above).",
                      metavar="REGEXP"
                     )
    parser.add_option("--progress",
                      action="store_true",
                      help="show the progress of the program on stderr. 2 "
                           "numbers are printed, the first is the current "
                           "line in the data file, the second one is the "
                           "number of fetched lines.",
                     )

    parser.add_option("-f", "--file",
                      action="append",
                      type="string",
                      help="read the data from FILE. If this parameter is "
                           "missing, read from stdin.",
                      metavar="FILE"
                     )
    parser.add_option("--doc",
                      action="store_true",
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

    process_files(options,args)

    sys.exit(0)

if __name__ == "__main__":
    #print __doc__
    main()
