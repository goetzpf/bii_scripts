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
import sys

# pylint: disable= invalid-name, bad-whitespace

assert sys.version_info[0]==2

def parse_isodate(str_):
    """parse an ISO date without a time.

    This function parses an ISO date (without time) and returns
    a datetime.datetime object. An ISO date
    (at least here) has the form YYYY-MM-DD,
    an example is 2006-10-09.

    parameters:
        str_     -- the string to parse
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
    return datetime.datetime.strptime(str_,"%Y-%m-%d")

def parse_isodatetime(str_):
    """parse an ISO date.

    This function parses an ISO date and returns
    a datetime.datetime object. An ISO date
    (at least here) has the form YYYY-MM-DDTHH:MM:SS,
    an example is 2006-10-09T10:33:09.

    parameters:
        str_     -- the string to parse
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
    return datetime.datetime.strptime(str_,"%Y-%m-%dT%H:%M:%S")

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

def parse_lsl_isodate(str_):
    """parse an ISO-like date produced from ls -l.

    This function parses a date in the form
    YYYY-MM-DD HH:MM, which is a date that the "ls -l"
    command may produce. It returns a datetime.datetime object.

    parameters:
        str_     -- the string to parse
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
    return datetime.datetime.strptime(str_,"%Y-%m-%d %H:%M")

# test with the default locale plus "de_DE.UTF-8":

if sys.version_info[0:2] <= (2,5):
    # Here is a fix for python version 2.5. For some weird reason, parsing a
    # date with locale "de_DE.UTF-8" fails, you must set the locale then to
    # "de_DE" and then parse the date again. You must do exactly this,
    # replacing "de_DE.UTF-8" just with "de_DE" doesn't work.
    _locale_list=(None, "de_DE.UTF-8", "de_DE")
else:
    _locale_list=(None, "de_DE.UTF-8")

_default_locale= locale.setlocale(locale.LC_TIME, None)
_locales_missing= set()

# test if locales can be used:
for _l in _locale_list:
    if _l is None:
        continue
    try:
        locale.setlocale(locale.LC_TIME, _l)
    except locale.Error:
        _locales_missing.add(_l)
        break
locale.setlocale(locale.LC_TIME, _default_locale)

months_german= { "Mai"  : "May",
                 "Mär"  : "Mar",
                 "Mrz"  : "Mar",
                 "Sept" : "Sep",
                 "Okt"  : "Oct",
                 "Dez"  : "Dec"
               }

def _translate_months(st):
    """replace german months with english months.
    """
    for de, en in months_german.items():
        st= st.replace(de, en)
    return st

def my_strptime(st, format_):
    """a strptime replacement that checks with several locales."""
    locale_changed= False
    try:
        for i in xrange(len(_locale_list)):
            l= _locale_list[i]
            if l is not None:
                if l in _locales_missing:
                    continue
                locale.setlocale(locale.LC_TIME, l)
                locale_changed= True
            try:
                ret= datetime.datetime.strptime(st, format_)
                return ret
            except ValueError:
                pass
        # last resort, try replacing german month names with english month
        # names:
        ret= datetime.datetime.strptime(_translate_months(st), format_)
        return ret
    finally:
        if locale_changed:
            locale.setlocale(locale.LC_TIME, _default_locale)

# pylint: disable= line-too-long

def parse_lsl_shortdate(st,year=None):
    """parse a possibly yearless date produced from ls -l.

    This function parses a date that was produced by "ls -l".
    It returns a datetime.datetime object.  Note that this function sets the
    year to 1900, if not specified differently by it's second parameter.  Note
    also, that 29th of February is an invalid date for the year 1900.
    The function currently tries the default locale and the de_DE locale.

    parameters:
        st     -- the string to parse
        year    -- the optional year, an integer
    returns:
        a datetime.datetime object

    Here are some examples:
    >>> parse_lsl_shortdate("Oct  9 10:42",2016)
    datetime.datetime(2016, 10, 9, 10, 42)
    >>> parse_lsl_shortdate("Oct  9 10:42",2005)
    datetime.datetime(2005, 10, 9, 10, 42)
    >>> parse_lsl_shortdate("Oct  9 2007")
    datetime.datetime(2007, 10, 9, 0, 0)
    >>> parse_lsl_shortdate("29. Jul 10:42", 2007)
    datetime.datetime(2007, 7, 29, 10, 42)
    >>> parse_lsl_shortdate("Oct  9 10:42b",2005)
    Traceback (most recent call last):
       ...
    ValueError: time data 'Oct  9 10:42b' does not match any of the known formats: ['%b %d %H:%M %Y', '%d. %b %H:%M %Y', '%d. %b %Y', '%b %d %Y'] for locales ['default', 'de_DE.UTF-8']
    """
    if year is None:
        # if the year is not give, we assume the current year:
        year= datetime.datetime.now().year
    st_y= "%s %s" % (st, year)

    formats= ( ("%b %d %H:%M %Y" , True),
               ("%d. %b %H:%M %Y", True),
               ("%d. %b %Y"      , False),
               ("%b %d %Y"       , False),
             )
    for (format_, flag) in formats:
        if flag:
            s= st_y
        else:
            s= st
        try:
            return my_strptime(s, format_)
        except ValueError:
            pass
    locales= ["default"] + [l for l in _locale_list if l]
    formats_= [f for f,_ in formats]
    msg= ("time data %s does not match any of the known formats: %s "
          "for locales %s") % \
         (repr(st), repr(formats_), repr(locales))
    raise ValueError(msg)

# pylint: enable= line-too-long

def parse_lsl_date(str_,year=None):
    """parse a date produced by "ls -l".

    Here are some examples:
    >>> parse_lsl_date("2009-03-16 10:26")
    datetime.datetime(2009, 3, 16, 10, 26)
    >>> parse_lsl_date("Oct  9 10:42", 2016)
    datetime.datetime(2016, 10, 9, 10, 42)
    >>> parse_lsl_date("Oct  9 10:42",2010)
    datetime.datetime(2010, 10, 9, 10, 42)
    >>> parse_lsl_date("Oct  9 10:42x",2010)
    Traceback (most recent call last):
       ...
    ValueError: lsl date 'Oct  9 10:42x' not parsable
    """
    try:
        d= parse_lsl_isodate(str_)
        return d
    except ValueError:
        pass
    try:
        d= parse_lsl_shortdate(str_,year)
        return d
    except ValueError:
        raise ValueError, "lsl date '%s' not parsable" % str_

def _test():
    import doctest
    doctest.testmod()

if __name__ == "__main__":
    _test()
