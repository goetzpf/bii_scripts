# -*- coding: utf-8 -*-

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

"""utilities for string <-> datetime conversions.
"""
import locale
import datetime

def parse_isodate(str):
    """parse an ISO date without a time.

    This function parses an ISO date (without time) and returns
    a datetime.datetime object. An ISO date
    (at least here) has the form YYYY-MM-DD,
    an example is 2006-10-09.

    parameters:
        str     -- the string to parse
    returns:
        a datetime.datetime object

    Here are some examples:
    >>> parse_isodate("2006-10-09")
    datetime.datetime(2006, 10, 9, 0, 0)
    >>> parse_isodate("2007-11-09")
    datetime.datetime(2007, 11, 9, 0, 0)
    >>> parse_isodate("2007-11-09x")
    Traceback (most recent call last):
       ...
    ValueError: unconverted data remains: x
    """
    return datetime.datetime.strptime(str,"%Y-%m-%d")

def parse_isodatetime(str):
    """parse an ISO date.

    This function parses an ISO date and returns
    a datetime.datetime object. An ISO date
    (at least here) has the form YYYY-MM-DDTHH:MM:SS,
    an example is 2006-10-09T10:33:09.

    parameters:
        str     -- the string to parse
    returns:
        a datetime.datetime object

    Here are some examples:
    >>> parse_isodatetime("2006-10-09T10:33:09")
    datetime.datetime(2006, 10, 9, 10, 33, 9)
    >>> parse_isodatetime("2006-10-09T10:33:09x")
    Traceback (most recent call last):
       ...
    ValueError: unconverted data remains: x
    >>> parse_isodatetime("2006-99-09T10:33:09")
    Traceback (most recent call last):
       ...
    ValueError: time data '2006-99-09T10:33:09' does not match format '%Y-%m-%dT%H:%M:%S'
    """
    return datetime.datetime.strptime(str,"%Y-%m-%dT%H:%M:%S")

def isodatetime(d):
    """converts a date to ISO format.

    This function returns the datetime.datetime
    object as an ISO date string of the form
    YYYY-MM-DDTHH:MM:SS.

    parameters:
        d       -- a datetime.datetime object
    returns:
        a string.

    Here are some examples:
    >>> isodatetime(datetime.datetime(2008, 10, 20, 11, 19, 30))
    '2008-10-20T11:19:30'
    """
    return d.strftime("%Y-%m-%dT%H:%M:%S")

def isolsl(d):
    """converts a date to ISO-like format used in "ls -l".

    This function returns the datetime.datetime
    object as an ISO date string of the form
    YYYY-MM-DD HH:MM.

    parameters:
        d       -- a datetime.datetime object
    returns:
        a string.

    Here are some examples:
    >>> isolsl(datetime.datetime(2008, 10, 20, 11, 19, 30))
    '2008-10-20 11:19'
    """
    return d.strftime("%Y-%m-%d %H:%M")

def parse_lsl_isodate(str):
    """parse an ISO-like date produced from ls -l.

    This function parses a date in the form
    YYYY-MM-DD HH:MM, which is a date that the "ls -l"
    command may produce. It returns a datetime.datetime object.

    parameters:
        str     -- the string to parse
    returns:
        a datetime.datetime object

    Here are some examples:
    >>> parse_lsl_isodate("2009-03-16 10:26")
    datetime.datetime(2009, 3, 16, 10, 26)
    >>> parse_lsl_isodate("2009-03-16  10:26")
    datetime.datetime(2009, 3, 16, 10, 26)
    >>> parse_lsl_isodate("Oct  9 10:42")
    Traceback (most recent call last):
       ...
    ValueError: time data 'Oct  9 10:42' does not match format '%Y-%m-%d %H:%M'
    """
    return datetime.datetime.strptime(str,"%Y-%m-%d %H:%M")

# test with the default locale plus "de_DE.UTF-8":
_locale_list=(None, "de_DE.UTF-8")
_default_locale= locale.setlocale(locale.LC_TIME, None)

def my_strptime(st, format):
    # a strptime replacement that checks with several locales:
    locale_changed= False
    try:
        for i in xrange(len(_locale_list)):
            l= _locale_list[i]
            if l is not None:
                locale.setlocale(locale.LC_TIME, l)
                locale_changed= True
            try:
                return datetime.datetime.strptime(st, format)
            except ValueError, e:
                if i+1==len(_locale_list):
                    raise
    finally:
        if locale_changed:
            locale.setlocale(locale.LC_TIME, _default_locale)

def parse_lsl_shortdate(str,year=None):
    """parse an yearless date produced from ls -l.

    This function parses a date in the form
    mmm d HH:MM (mmm the month name), which is a date that the "ls -l"
    command may produce. It returns a datetime.datetime object.
    Note that this function sets the year to 1900, if not
    specified differently by it's second parameter.

    parameters:
        str     -- the string to parse
        year    -- the optional year, an integer
    returns:
        a datetime.datetime object

    Here are some examples:
    >>> parse_lsl_shortdate("Oct  9 10:42")
    datetime.datetime(1900, 10, 9, 10, 42)
    >>> parse_lsl_shortdate("Oct  9 10:42",2005)
    datetime.datetime(2005, 10, 9, 10, 42)
    >>> parse_lsl_shortdate("Oct  9 2007")
    datetime.datetime(2007, 10, 9, 0, 0)
    >>> parse_lsl_shortdate("Oct  9 10:42b",2005)
    Traceback (most recent call last):
       ...
    ValueError: time data 'Oct  9 10:42b' does not match format '%b %d %Y'
    """
    try:
        if year is None:
            # if the year is not give, we assume the current year:
            year= datetime.datetime.now().year
        d= my_strptime("%s %s" % (str,year),"%b %d %H:%M %Y")
    except ValueError,e:
        d= my_strptime(str,"%b %d %Y")
    return d

def parse_lsl_date(str,year=None):
    """parse a date produced by "ls -l".

    Here are some examples:
    >>> parse_lsl_date("2009-03-16 10:26")
    datetime.datetime(2009, 3, 16, 10, 26)
    >>> parse_lsl_date("Oct  9 10:42")
    datetime.datetime(1900, 10, 9, 10, 42)
    >>> parse_lsl_date("Oct  9 10:42",2010)
    datetime.datetime(2010, 10, 9, 10, 42)
    >>> parse_lsl_date("Oct  9 10:42x",2010)
    Traceback (most recent call last):
       ...
    ValueError: lsl date 'Oct  9 10:42x' not parsable
    """
    try:
        d= parse_lsl_isodate(str)
        return d
    except ValueError, e:
        pass
    try:
        d= parse_lsl_shortdate(str,year)
        return d
    except ValueError, e:
        raise ValueError, "lsl date '%s' not parsable" % str

def _test():
    import doctest
    doctest.testmod()

if __name__ == "__main__":
    _test()
