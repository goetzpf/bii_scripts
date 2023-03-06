#! /usr/bin/env python3
# -*- coding: UTF-8 -*-

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

# pylint: disable=invalid-name, too-many-lines, consider-using-f-string

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

  U3IV:AdiUn9PmsPosI             2023-01-25 14:22:04.022486 0
  U3IV:AdiUn14PmsPosI            2023-01-25 14:22:04.022486 -3491
  U3IV:AdiUn9PmsPosI             2023-01-25 14:22:15.022486 329
  U3IV:AdiUn14PmsPosI            2023-01-25 14:22:15.022486 -4577
  U3IV:AdiUn14PmsPosI            2023-01-25 14:22:15.122486 -7045
  U3IV:AdiUn9PmsPosI             2023-01-25 14:22:15.122486 1111
  U3IV:AdiUn9PmsPosI             2023-01-25 14:22:15.222486 1470
  U3IV:AdiUn14PmsPosI            2023-01-25 14:22:15.222486 -8137
  U3IV:AdiUn9PmsPosI             2023-01-25 14:22:15.322486 1459
  U3IV:AdiUn14PmsPosI            2023-01-25 14:22:15.322486 -8121


Comparing several variables at the same time is sometimes made difficult by
this. A table-like format would be better in this case. This program does just
this, it creates a simple table from the output of a camonitor command that can
for example be used for gnuplot. Here is an example of such a table::

  Timestamp                  U3IV:AdiUn9PmsPosI U3IV:AdiUn14PmsPosI
  2023-01-25 14:22:04.022486 0                  -3491
  2023-01-25 14:22:15.022486 329                -4577
  2023-01-25 14:22:15.122486 1111               -7045
  2023-01-25 14:22:15.222486 1470               -8137
  2023-01-25 14:22:15.322486 1459               -8121

Examples
========

* convert a file to a table::

    camonitor2table.py -f myfile

    Timestamp                  U3IV:AdiUn14PmsPosI U3IV:AdiUn9PmsPosI
    2023-01-25 14:22:04.022486 -3491               0
    2023-01-25 14:22:15.022486 -4577               329
    2023-01-25 14:22:15.122486 -7045               1111
    2023-01-25 14:22:15.222486 -8137               1470
    2023-01-25 14:22:15.322486 -8121               1459

* convert a file, floating point format for each column, right justified::

    camonitor2table.py -f myfile -c '%f' --rjust

    Timestamp                  U3IV:AdiUn14PmsPosI U3IV:AdiUn9PmsPosI
    2023-01-25 14:22:04.022486        -3491.000000           0.000000
    2023-01-25 14:22:15.022486        -4577.000000         329.000000
    2023-01-25 14:22:15.122486        -7045.000000        1111.000000
    2023-01-25 14:22:15.222486        -8137.000000        1470.000000
    2023-01-25 14:22:15.322486        -8121.000000        1459.000000

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
    2023-01-25 14:22:04.022486|       -3491.000000|          0.000000
    2023-01-25 14:22:15.022486|       -4577.000000|        329.000000
    2023-01-25 14:22:15.122486|       -7045.000000|       1111.000000
    2023-01-25 14:22:15.222486|       -8137.000000|       1470.000000
    2023-01-25 14:22:15.322486|       -8121.000000|       1459.000000

* convert a file, floating point format for each column, csv::

    camonitor2table.py -f myfile -c '%f' --csv

    Timestamp,U3IV:AdiUn14PmsPosI,U3IV:AdiUn9PmsPosI
    2023-01-25 14:22:04.022486,-3491.000000,0.000000
    2023-01-25 14:22:15.022486,-4577.000000,329.000000
    2023-01-25 14:22:15.122486,-7045.000000,1111.000000
    2023-01-25 14:22:15.222486,-8137.000000,1470.000000
    2023-01-25 14:22:15.322486,-8121.000000,1459.000000

Waveform support
================

Currently the program handles waveform records by adding a column for each
element in the waveform record, here is an example, this line::

    U3IV:DiagSpdSet                2023-02-20 16:44:58.859846 2 3.0 4.0

creates two columns, named "U3IV:DiagSpdSet_0" and "U3IV:DiagSpdSet_1" with the
values 3.0 and 4.0. A Possible output of pretty_print() then loons like this::

    Timestamp                  U3IV:DiagSpdSet_0 U3IV:DiagSpdSet_1
    2023-02-20 16:44:58.859846 3.0               4.0

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
  the flags contain "UDF". If REGEXP has the value '.*', all lines with flags
  are removed.

--differentiate
  differentiate all values, that means that each value is replaced with the
  difference of this and the previous value for the same PV divided by the
  difference of the timestamp in seconds. The values must be numbers in order
  to be able to do this.

--fill
  fill empty places in the table with the first non-empty value in the same
  column from a row above.

--fill-interpolate
  fill empty places in the table with a linear interpolation taken from the
  rows above and below.

--add-seconds [SECONDS]
  add the seconds given (a floating point value) to the timestamps.

--time-rebase [OLDTIME,NEWTIME]
  Add an offset to all timestamps. The offset is calculated to ensure that
  OLDTIME is changed to NEWTIME.

-T --time-columnname COLUMNNAME
  Set the name of the time column, The default "name for this column is
  'Timestamp'.

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
  read the data from FILE. If this parameter is missing or if it is '-', read
  from stdin.
"""

import argparse
import sys
import re
import datetime
import os.path

from bii_scripts3 import camonitor_parse as cp # type: ignore

assert sys.version_info[0]==3

# version of the program:
my_version= "1.0"

TIMECOLUMN='Timestamp'

_last_str2date_str= None
_last_str2date_obj= None

# some functions for compability with python version 2.5
# unfortunately our development server has only python 2.5 as
# newest version:

def time_total_seconds(td):
    """return the total seconds in a timedelta object.

    Here is an example:
    >>> td= datetime.datetime(2011,0o1,0o1,13,32,15,250000)-datetime.datetime(2011,0o1,0o1,13,30,0)
    >>> time_total_seconds(td)
    135.25
    """
    return td.total_seconds()

# date and time utilities
# ----------------------------------------

def str2date_ui(st):
    """do cp.parse_date_str but with better error handling."""
    if st is None:
        return None
    try:
        d= cp.parse_date_str(st)
    except ValueError as _:
        sys.exit("error: \"%s\" is not a valid timestamp" % st)
    return d

def float_time(date, start_date):
    """convert timestamps to float-time.

    parameters:
      date       -- the date to convert, a datetime.datetime object.
      start_date -- The date that should be 0.0 as float-time.
    return:
      a float that gives the number of seconds passed since start_date.

    Here are some examples:
    >>> float_time(cp.parse_date_str("2011-01-25 14:22:20.822485"),
    ...            cp.parse_date_str("2011-01-24 14:22:20.822485"))
    86400.0
    >>> float_time(cp.parse_date_str("2011-01-25 14:22:20.822485"),
    ...            cp.parse_date_str("2011-01-24 14:22:20"))
    86400.822485
    """
    return time_total_seconds(date-start_date)

# classes
# ----------------------------------------

class RxReplace:
    """Change a string with a regular expression."""
    # pylint: disable= too-few-public-methods
    _rx_re= re.compile(r'(?<!\\)/(.*)(?<!\\)/(.*)(?<!\\)/(.*)')
    def __init__(self, st):
        """initialize the object."""
        m= RxReplace._rx_re.match(st)
        if not m:
            raise ValueError("invalid replacement regexp: '%s'" % st)
        self.flags=0
        for char in m.group(3):
            # we do not use "raise..from" here since this doesn't work on
            # python 3.2:
            e= None
            try:
                self.flags|= getattr(re, char.upper())
            except AttributeError as _e:
                e= _e
            if e is not None:
                raise ValueError("unknown flag '%s' in regexp '%s'" % \
                                 (char,st))
        self.rx= re.compile(m.group(1), self.flags)
        self.repl= m.group(2)
    def sub(self,st):
        """do the replacement."""
        return self.rx.sub(self.repl, st)

class RxReplacer:
    """Change a string with a regular expressions."""
    # pylint: disable= too-few-public-methods
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

class HashIndex:
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
    >>> list(h.keys())
    ['A', 'B', 'C']
    >>> "A" in h
    True
    >>> "X" in h
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
        return val in self._map
    def __contains__(self, val):
        """Test if a key is in the map."""
        return val in self._map
    def __repr__(self):
        """return "repr" string of the object."""
        return "HashIndex(%s)" % repr(list(self.keys()))
    def __str__(self):
        """return "repr" string of the object."""
        return repr(self)

class HashedList:
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
    >>> "B" in h
    True
    >>> "X" in h
    False
    >>> h.relabel("C","CC")
    >>> h
    HashedList([('A', 'x'), ('B', 'y'), ('CC', 'z'), ('D', [1]), ('E', 'new-val')])
    >>> list(h.keys())
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
        # pylint: disable= unnecessary-lambda-assignment
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
        return list(self._h_index.keys())
    def has_key(self, val):
        """Test if a key is known to the object."""
        return val in self._h_index
    def __contains__(self, val):
        """Test if a key is known to the object."""
        return val in self._h_index
    def __repr__(self):
        """return "repr" string of the object."""
        l= []
        for k in list(self.keys()):
            l.append((k, self.lookup(k)))
        return "HashedList(%s)" % repr(l)
    def __str__(self):
        """return "repr" string of the object."""
        return repr(self)

class HashedList2D:
    """a 2-dimensional HashedList.

    Here are some examples:
    >>> h= HashedList2D()
    >>> h.set(1,"A", "x")
    >>> print(h)
    (1,A) : x
    >>> h.set(1,"B", "y")
    >>> h.set(2,"B", "z")
    >>> print(h)
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
    >>> print(h)
    (1,A) : x
    (1,B) : y
    (3,A) : None
    (3,B) : z
    >>> h.fill_incomplete(lambda x: x is None)
    >>> print(h)
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
        val= self._rows.lookup(row,
                               constructor= \
                                   lambda: HashedList(hashindex= \
                                                      self._column_hashindex))
        return val.lookup(column, value= value, constructor= constructor)
    def set(self, row, column, set_value, value= None, constructor= None):
        """Set a value."""
        # pylint: disable= too-many-arguments
        val= self._rows.lookup(row,
                               constructor= \
                                   lambda: HashedList(hashindex= \
                                                      self._column_hashindex))
        return val.set(column, set_value= set_value, value= value, constructor= constructor)
    def rows(self):
        """Return all rows."""
        return list(self._rows.keys())
    def columns(self):
        """Return number of columns."""
        return list(self._column_hashindex.keys())
    def has_row(self, val):
        """Test if a row is known to the object."""
        return val in self._rows
    def has_column(self, val):
        """Test if a column is known to the object."""
        return val in self._column_hashindex
    def relabel_row(self, old_row, new_row):
        """Give a row a new name."""
        self._rows.relabel(old_row, new_row)
    def fill_incomplete(self, is_empty_func=None):
        """Fills empty cells with the value from the previous row."""
        # pylint: disable= unnecessary-lambda-assignment
        if is_empty_func is None:
            is_empty_func= lambda x: x is None
        column_list= self.columns()
        lasts= { k: None for k in column_list }
        for row in list(self._rows.keys()):
            for col in column_list:
                val= self.lookup(row, col)
                if is_empty_func(val):
                    # note that "[:]" is VERY important here, this copies
                    # the whole list. Otherwise the resulting structure would
                    # contain references to the SAME LIST at several places which
                    # would break the differentiate() function:
                    nval= lasts[col]
                    if nval is not None:
                        self.set(row, col, nval[:])
                else:
                    lasts[col]= val
    def fill_interpolate(self, interpolate_func, is_empty_func=None):
        """Interpolates missing values.

        Function that implements the interpolation:
            interpolate_func(hashedlist2d, col, row1, row2, empty_rows)

            paramaters:
              hashedlist2d: the HashedList2D object
              col: the column where to interpolate
              row1: the last non-empty row
              row2: the first non-empty row
                    this may be None if there was no more non-empty
                    row found
              empty_rows: a list of empty rows in-between
        """
        # pylint: disable= unnecessary-lambda-assignment
        if is_empty_func is None:
            is_empty_func= lambda x: x is None
        column_list= self.columns()
        befores= [None]*len(column_list)
        holes= [None]*len(column_list)
        for row in list(self._rows.keys()):
            for (idx,col) in enumerate(column_list):
                val= self.lookup(row, col)
                if not is_empty_func(val):
                    if holes[idx] is not None:
                        interpolate_func(self, col, befores[idx], row,
                                         holes[idx])
                        holes[idx]= None
                    befores[idx]= row
                else:
                    if holes[idx] is None:
                        holes[idx]= [row] # type: ignore
                    else:
                        holes[idx].append(row) # type: ignore
        for (idx,col) in enumerate(column_list):
            if holes[idx] is not None:
                interpolate_func(self, col, befores[idx], None,
                                 holes[idx])
    def filter_complete(self, is_empty_func=None):
        """Removes rows where not all columns have a value."""
        # pylint: disable= unnecessary-lambda-assignment
        if is_empty_func is None:
            is_empty_func= lambda x: x is None
        row_list= list(self._rows.keys())
        column_list= self.columns()
        for row in row_list:
            for col in column_list:
                if is_empty_func(self.lookup(row, col)):
                    self._rows.delete(row)
                    continue
    def __str__(self):
        rows= list(self._rows.keys())
        columns= list(self._column_hashindex.keys())
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
      skip_flagged  -- If this parameter is not None (a regexp), items with
                       matching flags are skipped
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
    >>> print(results)
    (2011-01-25 14:22:15.522486,U3IV:AdiUn14PmsPosI) : -12078
    (2011-01-25 14:22:15.522486,U3IV:AdiUn9PmsPosI) : None
    (2011-01-25 14:22:15.622486,U3IV:AdiUn14PmsPosI) : -12753
    (2011-01-25 14:22:15.622486,U3IV:AdiUn9PmsPosI) : 2925
    (2011-01-25 14:22:15.722486,U3IV:AdiUn14PmsPosI) : -12741
    (2011-01-25 14:22:15.722486,U3IV:AdiUn9PmsPosI) : 2915
    (2011-01-25 14:22:15.822486,U3IV:AdiUn14PmsPosI) : -14212
    (2011-01-25 14:22:15.822486,U3IV:AdiUn9PmsPosI) : 3371
    """
    # pylint: disable= too-many-branches, too-many-locals
    # pylint: disable= too-many-arguments, too-many-statements
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
                sys.stderr.write('\b'*17)
                sys.stderr.write("%8d %8d" % (lineno,lines))
        if empty(line):
            continue
        try:
            # pylint: disable=unbalanced-tuple-unpacking
            tp= cp.parse_line(line, keep_undefined= False)
            (pv,date,val,flags,_)= \
                cp.convert_line_datatypes(tp,
                                          parse_numbers= True,
                                          parse_date= True)
        except:
            print("parse error in line %d" % lineno)
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
        if flags is not None: # flags present
            flag_str= " ".join(flags)
            if skip_flagged is not None:
                if re.search(skip_flagged,flag_str) is not None:
                    continue
        if pvmap:
            pv= pvmap.get(pv, pv)
        if pvmaprx:
            pv= pvmaprx.sub(pv)

        if dump:
            print(cp.create_line((pv, date, val, flags, None), False, None))
        else:
            if type(val) in (list, tuple):
                # waveform record
                # add a column for each waveform number:
                for i, n in enumerate(val):
                    # create pseudo PV name
                    h.set( date, "%s_%d" % (pv, i), n)
            else:
                h.set( date, pv, val )
        lines+=1
        if max_lines is not None:
            if lines>=max_lines:
                break
    if progress:
        sys.stderr.write("\n")
    if dump:
        return None
    return h

# pylint: disable= trailing-whitespace, line-too-long

def pretty_print(hashedlist2d, columnformat=None, rjust= False,
                 is_floattime= False, timecolumn=None,
                 separator=" ", csv=False):
    """pretty print the results from collect().

    Here are some examples:
    >>> t='''
    ... U3IV:AdiUn14PmsPosI            2023-01-25 14:22:15.522486 -12078
    ... U3IV:AdiUn9PmsPosI             2023-01-25 14:22:15.622486 2925
    ... U3IV:AdiUn14PmsPosI            2023-01-25 14:22:15.622486 -12753
    ... U3IV:AdiUn9PmsPosI             2023-01-25 14:22:15.722486 2915
    ... U3IV:AdiUn14PmsPosI            2023-01-25 14:22:15.722486 -12741
    ... U3IV:AdiUn9PmsPosI             2023-01-25 14:22:15.822486 3371
    ... U3IV:AdiUn14PmsPosI            2023-01-25 14:22:15.822486 -14212
    ... U3IV:DiagSpdSet                2023-02-20 16:44:58.859846 2 1 1
    ... '''
    >>> results=collect(t.splitlines())
    >>> pretty_print(results)
    Timestamp                  U3IV:AdiUn14PmsPosI U3IV:AdiUn9PmsPosI U3IV:DiagSpdSet_0 U3IV:DiagSpdSet_1
    2023-01-25 14:22:15.522486 -12078
    2023-01-25 14:22:15.622486 -12753              2925
    2023-01-25 14:22:15.722486 -12741              2915
    2023-01-25 14:22:15.822486 -14212              3371
    2023-02-20 16:44:58.859846                                        1                 1

    >>> pretty_print(results,columnformat=["%.1f"])
    Timestamp                  U3IV:AdiUn14PmsPosI U3IV:AdiUn9PmsPosI U3IV:DiagSpdSet_0 U3IV:DiagSpdSet_1
    2023-01-25 14:22:15.522486 -12078.0
    2023-01-25 14:22:15.622486 -12753.0            2925.0
    2023-01-25 14:22:15.722486 -12741.0            2915.0
    2023-01-25 14:22:15.822486 -14212.0            3371.0
    2023-02-20 16:44:58.859846                                        1.0               1.0
    >>> pretty_print(results,columnformat=["%30s","%d","%.1f"])
    Timestamp                      U3IV:AdiUn14PmsPosI U3IV:AdiUn9PmsPosI U3IV:DiagSpdSet_0 U3IV:DiagSpdSet_1
        2023-01-25 14:22:15.522486 -12078
        2023-01-25 14:22:15.622486 -12753              2925.0
        2023-01-25 14:22:15.722486 -12741              2915.0
        2023-01-25 14:22:15.822486 -14212              3371.0
        2023-02-20 16:44:58.859846                                        1.0               1.0
    >>> pretty_print(results,rjust=True)
    Timestamp                  U3IV:AdiUn14PmsPosI U3IV:AdiUn9PmsPosI U3IV:DiagSpdSet_0 U3IV:DiagSpdSet_1
    2023-01-25 14:22:15.522486              -12078
    2023-01-25 14:22:15.622486              -12753               2925
    2023-01-25 14:22:15.722486              -12741               2915
    2023-01-25 14:22:15.822486              -14212               3371
    2023-02-20 16:44:58.859846                                                        1                 1
    >>> pretty_print(results,separator="|")
    Timestamp                 |U3IV:AdiUn14PmsPosI|U3IV:AdiUn9PmsPosI|U3IV:DiagSpdSet_0|U3IV:DiagSpdSet_1
    2023-01-25 14:22:15.522486|-12078             |                  |                 |
    2023-01-25 14:22:15.622486|-12753             |2925              |                 |
    2023-01-25 14:22:15.722486|-12741             |2915              |                 |
    2023-01-25 14:22:15.822486|-14212             |3371              |                 |
    2023-02-20 16:44:58.859846|                   |                  |1                |1
    >>> pretty_print(results,csv=True)
    Timestamp U3IV:AdiUn14PmsPosI U3IV:AdiUn9PmsPosI U3IV:DiagSpdSet_0 U3IV:DiagSpdSet_1
    2023-01-25 14:22:15.522486 -12078
    2023-01-25 14:22:15.622486 -12753 2925
    2023-01-25 14:22:15.722486 -12741 2915
    2023-01-25 14:22:15.822486 -14212 3371
    2023-02-20 16:44:58.859846   1 1
    >>> pretty_print(results,csv=True,separator=",")
    Timestamp,U3IV:AdiUn14PmsPosI,U3IV:AdiUn9PmsPosI,U3IV:DiagSpdSet_0,U3IV:DiagSpdSet_1
    2023-01-25 14:22:15.522486,-12078,,,
    2023-01-25 14:22:15.622486,-12753,2925,,
    2023-01-25 14:22:15.722486,-12741,2915,,
    2023-01-25 14:22:15.822486,-14212,3371,,
    2023-02-20 16:44:58.859846,,,1,1
    """
    # pylint: disable= too-many-arguments, too-many-branches
    # pylint: disable= too-many-locals, too-many-statements
    def tp(st,columnformat,converter):
        """convert data."""
        if st is None:
            return ""
        if type(st) in (list, tuple):
            raise AssertionError("waveform support not yet implemented: %s" % repr(st))
        val= converter(st)
        val= columnformat % val
        return val
    if timecolumn is None:
        timecolumn= TIMECOLUMN
    columns= ["%-26s" % timecolumn]
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

    for c, f in enumerate(columnformat):
        try:
            _= f % "x"
            type_= "string"
        except TypeError as _:
            type_= "number"
        if type_=="number" and c==0 and (not is_floattime):
            columnformat[0]="%s"
            type_= "string"

        # pylint: disable= unnecessary-lambda
        if type_=="string":
            converters.append(lambda x: str(x))
        else:
            converters.append(lambda x: float(x)) # type: ignore

    lines= [columns[:]] # initialize with the heading
    for date in hashedlist2d.rows():
        lst=[] # type: ignore
        lines.append(lst)
        i= 0
        if isinstance(date,datetime.datetime):
            val_date= cp.date2str(date)
        else:
            val_date= date
        lst.append(tp(val_date, columnformat[i], converters[i]))
        for i in range(1,len(columns)):
            col= columns[i]
            val= hashedlist2d.lookup(date,col)
            lst.append(tp(val, columnformat[i], converters[i]))

    widths= [0]*len(columns)
    for line in lines:
        for i, l in enumerate(line):
            if widths[i] < len(l):
                widths[i]= len(l)
    for line in lines:
        n= []
        for c, l in enumerate(line):
            if csv:
                n.append(l.strip())
            elif not just[c]:
                n.append(l.ljust(widths[c]))
            else:
                n.append(l.rjust(widths[c]))
        print(separator.join(n).rstrip())

# pylint: enable= trailing-whitespace, line-too-long

def convert_to_float_time(start_date, hashedlist2d):
    """convert all times in the HashedList2D object to float-time.
    """
    rows= hashedlist2d.rows()
    for r in rows:
        if start_date is None:
            start_date= r
        hashedlist2d.relabel_row(r, float_time(r, start_date))

def interpolate(hashedlist2d, col, row1, row2, empty_rows):
    """fill in missing values by interpolation.
    """
    # pylint: disable=too-many-locals
    if row2 is None:
        # cannot interpolate, just copy the first value
        val= hashedlist2d.lookup(row1, col)
        for row in empty_rows:
            # note: val is a list, val[:] creates a copy:
            hashedlist2d.set(row, col, val[:])
        return
    if row1 is None:
        # cannot interpolate, just copy the last value
        val= hashedlist2d.lookup(row2, col)
        for row in empty_rows:
            # note: val is a list, val[:] creates a copy:
            hashedlist2d.set(row, col, val[:])
        return
    # pylint: disable= unnecessary-lambda-assignment
    if isinstance(row1, datetime.datetime):
        tm= lambda t : time_total_seconds(t-row1)
    else:
        tm= lambda t : t-row1
    try:
        val1= float(hashedlist2d.lookup(row1, col)[0])
    except ValueError as _:
        sys.stderr.write("warning: no float at row %s, column %s" % \
                         (row1, col))
        return
    try:
        val2= float(hashedlist2d.lookup(row2, col)[0])
    except ValueError as _:
        sys.stderr.write("warning: no float at row %s, column %s" % \
                         (row2, col))
        return
    t1= tm(row1)
    t2= tm(row2)
    f= (val2-val1)/(t2-t1)
    for row in empty_rows:
        nval= hashedlist2d.lookup(row, col)
        st_= str( f*(tm(row)-t1)+val1 )
        if isinstance(nval, list):
            nval[0]= st_
        else:
            hashedlist2d.set(row, col, [st_])

def differentiate(hashedlist2d):
    """differentiate at each point.
    """
    def number(val):
        """try to return a number from val."""
        if val is None:
            return None
        try:
            return float(val[0])
        except ValueError as _:
            return None

    #print "hashedlist2d:", str(hashedlist2d)
    columns= hashedlist2d.columns()
    last= [None]*len(columns)
    last_row= None
    for r in hashedlist2d.rows():
        if last_row is None:
            t= 0
        else:
            if isinstance(r,datetime.datetime):
                t= time_total_seconds(r-last_row)
            else:
                t= r-last_row
        last_row= r
        for i, column in enumerate(columns):
            buf= hashedlist2d.lookup(r,column)
            # each buf is a list of a number and optionally PV flags like
            # "NO_ALARM' etc.
            # if there hasn't been a value for that timestamp, buf is None.
            # number() returns None if this is the case or if buf[0] is no
            # floating point number:
            no= number(buf)
            if no is None:
                hashedlist2d.set(r,column,[0])
                continue
            if last[i] is None:
                last[i]= no
                buf[0]= 0
                continue
            # the value is overwritten with the derivative:
            buf[0]= (no-last[i])/t
            #hashedlist2d.set(r,column, buf)
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
      filename_      -- name of the file, None or '-' for STDIN
                        with None a warning is printed on stderr
      results        -- dictionary where the results are stored
      process_func   -- function to process each file
    """
    # pylint: disable=too-many-locals, too-many-arguments
    # pylint: disable=consider-using-with
    use_stdin= False
    if (filename_ is None) or (filename_=='-'):
        use_stdin= True
        in_file= sys.stdin
        if filename_ is None:
            sys.stderr.write("(read from stdin)\n")
    else:
        in_file= open(filename_, encoding="utf-8")
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
        if not use_stdin:
            print("in file %s" % filename_)
        raise
    finally:
        if not use_stdin:
            in_file.close()
    if dump:
        return None
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
    # pylint: disable=too-many-locals, too-many-statements
    # pylint: disable=too-many-branches
    filelist= []
    if not options.file:
        filelist= [None] # stdin with warning
                         # '-' : stdin without warning
    else:
        filelist=options.file
    if len(args)>0: # extra arguments
        filelist.extend(args)
    results= HashedList2D()
    from_time= str2date_ui(options.from_time)
    to_time= str2date_ui(options.to_time)
    timedelta= None
    if options.add_seconds:
        try:
            add_seconds= float(options.add_seconds)
        except ValueError as _:
            sys.exit("error: argument to --add-seconds must be a float")
        timedelta= datetime.timedelta(0, add_seconds)
    if options.time_rebase:
        (d1,d2)= (cp.parse_date_str(d) for d in options.time_rebase.split(","))
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
    if options.fill_interpolate:
        results.fill_interpolate(interpolate, None)
    if options.filter_complete:
        results.filter_complete()
    if options.differentiate:
        differentiate(results)
    if options.raw:
        print(results)
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
        if not options.time_columnname:
            options.time_columnname= TIMECOLUMN
        pretty_print(results, columnformat,
                     options.rjust,
                     options.floattime,
                     options.time_columnname,
                     separator, options.csv)

def script_shortname():
    """return the name of this script without a path component."""
    return os.path.basename(sys.argv[0])

def print_summary():
    """print a short summary of the scripts function."""
    print("%-20s: convert camonitor data to a table of values\n" % \
          script_shortname())

def print_doc():
    """print embedded reStructuredText documentation."""
    print(__doc__)

def _test():
    """does a self-test of some functions defined here."""
    print("performing self test...")
    # pylint: disable= import-outside-toplevel
    import doctest
    doctest.testmod()
    print("done!")

def main():
    """The main function.

    parse the command-line options and perform the command
    """

    # command-line options and command-line help:
    usage = "%(prog)s [options]"
    parser = argparse.ArgumentParser(\
                 usage= usage,
                 description="convert archiver data format to camonitor "
                             "format",
                 formatter_class=argparse.RawDescriptionHelpFormatter
                                    )
    parser.add_argument('--version', action='version',
                        version='%%(prog)s %s' % my_version
                       )

    parser.add_argument("--summary",
                        action="store_true",
                        help= "print a one-line summary of the scripts "
                              "function"
                       )

    parser.add_argument("-t", "--test",
                        action="store_true",
                        help="perform a simple self-test"
                       )
    parser.add_argument("--raw",
                        action="store_true",
                        help="print the internal HashedList2D object, this "
                             "is for debugging only."
                       )
    parser.add_argument("--dump",
                        action="store_true",
                        help="do not collect the data to a table but dump the "
                             "data in camonitor format to the console. This "
                             "may be useful if combined with some of the "
                             "filter options or options that modify the "
                             "timestamps or pv names.)"
                       )
    parser.add_argument("-r", "--rjust",
                        action="store_true",
                        help="justify the values in each row to the right "
                             "side. Note that the timestamps are always left "
                             "justified except when the are converted to a "
                             "floating point number (see --floattime)."
                       )
    parser.add_argument("-c", "--columnformat",
                        help="format columns with the given FORMAT. A "
                             "FORMAT is a space separated list of format "
                             "substrings that use the same conventions as C "
                             "format strings. If only a single format is "
                             "given, this is applied to all columns. If "
                             "floattime is used, the same format is also "
                             "applied to the timestamp field.",
                        metavar="FORMAT"
                       )
    parser.add_argument("-s", "--separator",
                        help="specify the SEPARATOR that separates columns of "
                             "the table. This string is also used to separate "
                             "values when csv format is used (see --csv).",
                        metavar="SEPARATOR"
                       )
    parser.add_argument("--csv",
                        action="store_true",
                        help="format columns with the given FORMAT. A FORMAT "
                             "is a space separated list of format substrings "
                             "that use the same conventions as C format "
                             "strings. If only a single format is given, this "
                             "is applied to all columns. If floattime is "
                             "used, the same format is also applied to the "
                             "timestamp field."
                       )
    parser.add_argument("--floattime",
                        help="convert timestamps floating point seconds when "
                             "0 corresponds to STARTTIME.  If STARTTIME has "
                             "the special value 'FIRST', the first timestamp "
                             "is taken as STARTTIME.",
                        metavar="START"
                       )
    parser.add_argument("--from-time",
                        help="use only data where the timestamp is newer "
                             "or equal to STARTTIME.",
                        metavar="TIMESTAMP"
                       )
    parser.add_argument("--to-time",
                        help="use only data where the timestamp is older "
                             "or equal to ENDTIME.",
                        metavar="TIMESTAMP"
                       )
    parser.add_argument("--max-lines",
                        type=int,
                        help="stop after MAX lines have been fetched. This "
                             "may be used for checking a command line with a "
                             "very large file.",
                        metavar="MAX"
                       )
    parser.add_argument("--filter-pv",
                        help="select only PVs that match REGEXP",
                        metavar="REGEXP"
                       )
    parser.add_argument("--filter-complete",
                        action="store_true",
                        help="select only rows where each column has a value"
                       )
    parser.add_argument("--skip-flagged",
                        help="Skip all lines where the flags match REGEXP, "
                             "e.g. 'UDF' skips all lines where the flags "
                             "contain 'UDF'. If REGEXP has the special "
                             "value 'all' or 'ALL', all flags are removed.",
                        metavar="REGEXP"
                       )
    parser.add_argument("--rm-flags",
                        help="remove all flags that match REGEXP from the "
                             "data, e.g. 'HIHI|HI' removes 'HIHI' and 'HI' "
                             "from the flags.",
                        metavar="REGEXP"
                       )
    parser.add_argument("--differentiate",
                        action="store_true",
                        help="differentiate all values, that means that "
                             "each value is replaced with the difference of "
                             "this and the previous value for the same PV "
                             "divided by the difference of the timestamp in "
                             "seconds. The values must be numbers in order to "
                             "be able to do this."
                       )
    parser.add_argument("--fill",
                        action="store_true",
                        help="fill empty places in the table with the first "
                             "non-empty value in the same column from a "
                             "row above."
                       )
    parser.add_argument("--fill-interpolate",
                        action="store_true",
                        help="Like --fill but fill empty places with "
                             "interpolated numbers taken from the first "
                             "non-empty value above and below. If the "
                             "value is not numerical, this works like --fill."
                       )
    parser.add_argument("--add-seconds",
                        help="add the seconds given (a floating point value) "
                             "to the timestamps.",
                        metavar="SECONDS"
                       )
    parser.add_argument("--time-rebase",
                        help="Add an offset to all timestamps. The offset is "
                             "calculated to ensure that OLDTIME is changed "
                             "to NEWTIME.",
                        metavar="TIMESPEC"
                       )
    parser.add_argument("-T", "--time-columnname",
                        help="Set the name of the time column, The default "
                             "name for this column is 'Timestamp'.",
                        metavar="NAME"
                       )
    parser.add_argument("-P", "--pvmap",
                        action="append",
                        help="Defines a mapping that replaces a pv with a "
                             "new name. A PVMAP is a string with the form "
                             "'OLDPV,NEWPV. You can specify more than one "
                             "PVMAP.",
                        metavar="PVMAP"
                       )
    parser.add_argument("--pvmaprx",
                        action="append",
                        type=str,
                        help="Apply a regular expression to each pv to modify "
                             "it. The REGEXP should have the form "
                             "'/match/replace/'. You can specify more than "
                             "one REGEXP, in this case all are applied in the "
                             "order you specify them. REGEXPs are applied "
                             "*after* PVMAP changes (see above).",
                        metavar="REGEXP"
                       )
    parser.add_argument("--progress",
                        action="store_true",
                        help="show the progress of the program on stderr. 2 "
                             "numbers are printed, the first is the current "
                             "line in the data file, the second one is the "
                             "number of fetched lines."
                       )

    parser.add_argument("-f", "--file",
                        action="append",
                        help="read the data from FILE. If this parameter is "
                             "missing, read from stdin.",
                        metavar="FILE"
                       )
    parser.add_argument("--doc",
                        action="store_true",
                        help="create online help in restructured text"
                             "format. Use \"./txtcleanup.py --doc | "
                             "rst2html\" to create html-help"
                       )

    (args, rest) = parser.parse_known_args()
    if rest:
        for r in rest:
            if r.startswith("-"):
                sys.exit("unknown option: %s" % repr(r))

    if args.summary:
        print_summary()
        sys.exit(0)

    if args.doc:
        print_doc()
        sys.exit(0)

    if args.test:
        _test()
        sys.exit(0)

    process_files(args, rest)

    sys.exit(0)

if __name__ == "__main__":
    #print __doc__
    main()
