# -*- coding: utf-8 -*-

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

"""a module to parse the output of "ls -l".

This module contains classes and parser functions
to parse the output of the "ls -l" command.
"""
import sys
from bii_scripts import dateutils

# pylint: disable= invalid-name, bad-whitespace

assert sys.version_info[0]==2

def _token_subtract(str_,no):
    """removes <no> tokens from the beginning of a string.

    Here are some examples:
    >>> _token_subtract("a bc def",2)
    'def'
    >>> _token_subtract("a bc def",1)
    'bc def'
    >>> _token_subtract("a bc def",3)
    ''
    >>> _token_subtract("a bc def",4)
    Traceback (most recent call last):
       ...
    ValueError: string hasn't got 4 tokens
    >>> _token_subtract("a bc def ghi  jkl",3)
    'ghi  jkl'
    """
    elms= str_.split()
    if len(elms)<no:
        raise ValueError,"string hasn't got %d tokens" % no
    for e in elms[:no]:
        str_= str_.replace(e,"",1)
    return str_.lstrip()

def _datetime_of_lsl_tokenlist(list_,year=None):
    """parses a date produced by ls -l from a list_ of strings.

    The list_ should be the result of str.split() which splits
    a string along sequences of spaces. The function returns
    the parsed date and the remaining parts of the list_.

    If the string has no information on the year, the year
    may be set with the second parameter. This function
    recognizes two formats:

    YYYY-MM-DD HH:MM or
    mmm d HH:MM (with mmm the month name)

    parameters:
        list_    -- the list_ of strings that is parsed
        year    -- the year that is used when the date string
                   contains no year (optional). If this is not given and the
                   date string contains no year, the current year is used.

    returns:
        (date,newlist) where <date> is a datetime.datetime object
        and <newlist> is the rest of the list_ with the parts belonging
        to the parsed date removed.

    Here are some examples:
    >>> _datetime_of_lsl_tokenlist("2009-03-16 14:46 idcp8 ->".split())
    (datetime.datetime(2009, 3, 16, 14, 46), ['idcp8', '->'])
    >>> _datetime_of_lsl_tokenlist("Oct  9 10:42 idcp13 ->".split(), 1900)
    (datetime.datetime(1900, 10, 9, 10, 42), ['idcp13', '->'])
    >>> _datetime_of_lsl_tokenlist(" Oct  9 10:42 idcp13 ->".split(), 1900)
    (datetime.datetime(1900, 10, 9, 10, 42), ['idcp13', '->'])
    >>> _datetime_of_lsl_tokenlist(" Oct  9 2007 idcp13 ->".split())
    (datetime.datetime(2007, 10, 9, 0, 0), ['idcp13', '->'])
    >>> _datetime_of_lsl_tokenlist("nOct  9 10:42 idcp13 ->".split())
    Traceback (most recent call last):
       ...
    ValueError: no parsable date in list_: ['nOct', '9', '10:42', 'idcp13', '->']
    """
    str_= " ".join(list_[0:2])
    try:
        d= dateutils.parse_lsl_isodate(str_)
        return(d, list_[2:])
    except ValueError:
        pass
    str_= " ".join(list_[0:3])
    try:
        d= dateutils.parse_lsl_shortdate(str_,year)
        return(d, list_[3:])
    except ValueError:
        raise ValueError, "no parsable date in list_: %s" % repr(list_)

def _parse_lsl_symlink(str_):
    """parse a symlink as it is listed by ls -l command.

    returns a tuple consisting of the
    name of the symlink and it's source.

    Here are some examples:
    >>> _parse_lsl_symlink("idcp8 -> /opt/IOC/Releases/idcp/dist/2009-03-16T14:46:04")
    ('idcp8', '/opt/IOC/Releases/idcp/dist/2009-03-16T14:46:04')
    >>> _parse_lsl_symlink("/opt/IOC/Releases/idcp/dist/2009-03-16T14:46:04")
    Traceback (most recent call last):
       ...
    ValueError: string has wrong format: '/opt/IOC/Releases/idcp/dist/2009-03-16T14:46:04'
    """
    try:
        (name,source)= str_.split("->")
    except ValueError:
        raise ValueError,"string has wrong format: '%s'" % str_
    name= name.rstrip()
    source= source.strip()
    return(name,source)

class LslEntry(object):
    """a class that contains all the information of a single "ls -l" line.

    This class is used to parse a single line of the
    output of the "ls -l" command under unix.
    """
    # pylint: disable= too-many-instance-attributes
    # pylint: disable= line-too-long
    def __init__(self, text="",year=None):
        """parses a single line of the output of "ls -l"

        parameters:
            text   -- the text to parse, optional
            year   -- the year that is used when the file date
                      doesn't contain a year. This parameter is
                      also optional. If this parameter is not given
                      and the file date does not contain a year, the
                      default of the unix time library is used which
                      is "1900".

        Here are some examples:

        >>> l= LslEntry("lrwxr-xr-x   1 idadm    expermt        27 Oct  9 13:14 idcp13 -> ../dist/2006-10-09T10:33:09", 1900)
        >>> print l
        lrwxr-xr-x   1    idadm  expermt        27 1900-10-09 13:14 idcp13 -> ../dist/2006-10-09T10:33:09
        >>> l= LslEntry("lrwxr-xr-x   1 idadm    expermt        27 Oct  9 2007 13:14 idcp13 -> ../dist/2006-10-09T10:33:09")
        >>> print l
        lrwxr-xr-x   1    idadm  expermt        27 2007-10-09 00:00 13:14 idcp13 -> ../dist/2006-10-09T10:33:09
        >>> l= LslEntry("lrwxrwxrwx 1 iocadm iocadm 47 2009-03-16 14:46 idcp8 -> /opt/IOC/Releases/idcp/dist/2009-03-16T14:46:04")
        >>> print l
        lrwxrwxrwx   1   iocadm   iocadm        47 2009-03-16 14:46 idcp8 -> /opt/IOC/Releases/idcp/dist/2009-03-16T14:46:04
        >>> l.is_symlink()
        True
        >>> l.is_dir()
        False
        >>> l= LslEntry("-rwxr-xr-x   1 idadm    expermt        27 Oct  9 13:14 idcp13", 1900)
        >>> print l
        -rwxr-xr-x   1    idadm  expermt        27 1900-10-09 13:14 idcp13
        >>> l.is_symlink()
        False
        >>> l.is_dir()
        False
        >>> l= LslEntry("drwxr-xr-x   1 idadm    expermt        27 Oct  9 13:14 dist", 1900)
        >>> print l
        drwxr-xr-x   1    idadm  expermt        27 1900-10-09 13:14 dist
        >>> l.is_symlink()
        False
        >>> l.is_dir()
        True
        """
        self.mode_string=""
        self.hardlinks  = 0
        self.owner      = ""
        self.group      = ""
        self.size       = 0
        self.timestamp  = None
        self.name       = ""
        self.symlink_from= ""
        self.symlink_to  = ""
        if text!="":
            self.parse(text,year)
    # pylint: enable= line-too-long
    def __str__(self):
        """converts the data to a string.
        """
        st= "%-11s%3d %8s %8s %9d %16s " % \
            (self.mode_string, self.hardlinks,
             self.owner, self.group, self.size,
             dateutils.isolsl(self.timestamp))
        if self.is_symlink():
            st+= "%s -> %s" % (self.symlink_from, self.symlink_to)
        else:
            st+= self.name
        return st
    def __repr__(self):
        st= self.__str__()
        return "LslEntry('%s')" % st

    def parse(self,str_,year=None):
        """parses a line of the output of the "ls -l" command.

        """
        elms= str_.strip().split()
        token_no= len(elms)
        self.mode_string= elms[0]
        self.hardlinks  = int(elms[1])
        self.owner      = elms[2]
        self.group      = elms[3]
        self.size       = long(elms[4])
        elms= elms[5:]
        (self.timestamp,elms)= _datetime_of_lsl_tokenlist(elms, year)
        self.name= _token_subtract(str_,token_no-len(elms))
        if self.is_symlink():
            (self.symlink_from,self.symlink_to)= _parse_lsl_symlink(self.name)
            self.name= self.symlink_from
    def is_symlink(self):
        """return True if it is a symlink."""
        return self.mode_string[0]=="l"
    def is_dir(self):
        """return True if it is a directory."""
        return self.mode_string[0]=="d"

class LslEntries(object):
    """parse a list of lines returned by "ls -l".

    Here is an example:
    >>> txt='''
    ... drwxr-xr-x.  2 pfeiffer pfeiffer      4096 2009-07-07 10:08 Public
    ... lrwxrwxrwx   1 pfeiffer pfeiffer        18 2009-07-09 11:38 pylib -> devel/python/pylib
    ... -rw-rw-r--   1 pfeiffer pfeiffer   5464500 2009-07-28 13:35 python2.ps
    ... '''
    >>> e= LslEntries(text=txt)
    >>> print e
    drwxr-xr-x.  2 pfeiffer pfeiffer      4096 2009-07-07 10:08 Public
    lrwxrwxrwx   1 pfeiffer pfeiffer        18 2009-07-09 11:38 pylib -> devel/python/pylib
    -rw-rw-r--   1 pfeiffer pfeiffer   5464500 2009-07-28 13:35 python2.ps
    """
    def __init__(self, text="", lines=None, year= None):
        """create the LslEntries object.

        parameters:
            text    -- the text to parse (optional)
            lines   -- the lines to parse (optional).
                       Note that either text or lines but not both
                       should be specified.
            year    -- the year that is used when the file date
                       doesn't contain a year. This parameter is
                       also optional. If this parameter is not given
                       and the file date does not contain a year, the
                       default of the unix time library is used which
                       is "1900".
        """
        if lines is None:
            lines= []
        self._entries= {}
        self.parse(text,lines,year)
    def append(self, entry):
        """append a single LslEntry to the list.
        """
        self._entries[entry.name]= entry
    def parse(self, text="", lines=None, year= None):
        """parse a text."""
        if text!="":
            lines= text.splitlines()
        if lines is None:
            return
        for line in lines:
            if line=="" or line.isspace():
                continue
            if line.startswith("total"):
                continue
            entry= LslEntry(line, year)
            self._entries[entry.name]= entry
    def names(self):
        """return names."""
        return sorted(self._entries.keys())
    def items(self):
        """return items."""
        for name in self.names():
            yield (name,self._entries[name])
    def __str__(self):
        """print contents like "ls -l" would do.
        """
        lines= []
        for _,entry in self.items():
            lines.append(str(entry))
        return "\n".join(lines)
    def __repr__(self):
        """return repr-string of the object."""
        lines= [str(i) for _,i in self.items()]
        text= "\n".join(lines)
        return "LslEntries('''\n%s''')" % text

def _test():
    import doctest
    doctest.testmod()

if __name__ == "__main__":
    _test()
