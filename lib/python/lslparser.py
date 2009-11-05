"""a module to parse the output of "ls -l".

This module contains classes and parser functions
to parse the output of the "ls -l" command.

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
import datetime
import dateutils

def _token_subtract(str,no):
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
    elms= str.split()
    if (len(elms)<no):
        raise ValueError,"string hasn't got %d tokens" % no
    for e in elms[:no]:
        str= str.replace(e,"",1)
    return str.lstrip()

def _datetime_of_lsl_tokenlist(list,year=None):
    """parses a date produced by ls -l from a list of strings.

    The list should be the result of str.split() which splits
    a string along sequences of spaces. The function returns
    the parsed date and the remaining parts of the list.

    If the string has no information on the year, the year
    may be set with the second parameter. This function
    recognizes two formats:

    YYYY-MM-DD HH:MM or
    mmm d HH:MM (with mmm the month name)

    parameters:
        list    -- the list of strings that is parsed
        year    -- the year that is used when the date string
                   contains no year (optional)

    returns:
        (date,newlist) where <date> is a datetime.datetime object
        and <newlist> is the rest of the list with the parts belonging
        to the parsed date removed.

    Here are some examples:
    >>> _datetime_of_lsl_tokenlist("2009-03-16 14:46 idcp8 ->".split())
    (datetime.datetime(2009, 3, 16, 14, 46), ['idcp8', '->'])
    >>> _datetime_of_lsl_tokenlist("Oct  9 10:42 idcp13 ->".split())
    (datetime.datetime(1900, 10, 9, 10, 42), ['idcp13', '->'])
    >>> _datetime_of_lsl_tokenlist(" Oct  9 10:42 idcp13 ->".split())
    (datetime.datetime(1900, 10, 9, 10, 42), ['idcp13', '->'])
    >>> _datetime_of_lsl_tokenlist(" Oct  9 2007 idcp13 ->".split())
    (datetime.datetime(2007, 10, 9, 0, 0), ['idcp13', '->'])
    >>> _datetime_of_lsl_tokenlist("nOct  9 10:42 idcp13 ->".split())
    Traceback (most recent call last):
       ...
    ValueError: no parsable date in list: ['nOct', '9', '10:42', 'idcp13', '->']
    """
    str= " ".join(list[0:2])
    try:
        d= dateutils.parse_lsl_isodate(str)
        return(d, list[2:])
    except ValueError,e:
        pass
    str= " ".join(list[0:3])
    try:
        d= dateutils.parse_lsl_shortdate(str,year)
        return(d, list[3:])
    except ValueError,e:
        raise ValueError, "no parsable date in list: %s" % repr(list)

def _parse_lsl_symlink(str):
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
        (name,source)= str.split("->")
    except ValueError,e:
        raise ValueError,"string has wrong format: '%s'" % str
    name= name.rstrip()
    source= source.strip()
    return(name,source)

class LslEntry(object):
    """a class that contains all the information of a single "ls -l" line.

    This class is used to parse a single line of the
    output of the "ls -l" command under unix.
    """
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

        >>> l= LslEntry("lrwxr-xr-x   1 idadm    expermt        27 Oct  9 13:14 idcp13 -> ../dist/2006-10-09T10:33:09")
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
        >>> l= LslEntry("-rwxr-xr-x   1 idadm    expermt        27 Oct  9 13:14 idcp13")
        >>> print l
        -rwxr-xr-x   1    idadm  expermt        27 1900-10-09 13:14 idcp13
        >>> l.is_symlink()
        False
        >>> l.is_dir()
        False
        >>> l= LslEntry("drwxr-xr-x   1 idadm    expermt        27 Oct  9 13:14 dist")
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

    def parse(self,str,year=None):
        """parses a line of the output of the "ls -l" command.

        """
        elms= str.strip().split()
        token_no= len(elms)
        self.mode_string= elms[0]
        self.hardlinks  = int(elms[1])
        self.owner      = elms[2]
        self.group      = elms[3]
        self.size       = long(elms[4])
        elms= elms[5:]
        (self.timestamp,elms)= _datetime_of_lsl_tokenlist(elms)
        self.name= _token_subtract(str,token_no-len(elms))
        if self.is_symlink():
            (self.symlink_from,self.symlink_to)= _parse_lsl_symlink(self.name)
            self.name= self.symlink_from
    def is_symlink(self):
        return self.mode_string[0]=="l"
    def is_dir(self):
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
    def __init__(self, text="", lines=[], year= None):
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
        self._entries= {}
        self.parse(text,lines,year)
    def append(self, entry):
        """append a single LslEntry to the list.
        """
        self._entries[entry.name]= entry
    def parse(self, text="", lines=[], year= None):
        if text!="":
            lines= text.splitlines()
        if len(lines)==0:
            return
        for line in lines:
            if line=="" or line.isspace():
                continue
            if line.startswith("total"):
                continue
            entry= LslEntry(line)
            self._entries[entry.name]= entry
    def names(self):
        return sorted(self._entries.keys())
    def items(self):
        for name in self.names():
            yield (name,self._entries[name])
    def __str__(self):
        """print contents like "ls -l" would do.
        """
        lines= []
        for name,entry in self.items():
            lines.append(str(entry))
        return "\n".join(lines)
    def __repr__(self):
        """return repr-string of the object."""
        lines= [str(i) for n,i in self.items()]
        text= "\n".join(lines)
        return "LslEntries('''\n%s''')" % text

def _test():
    import doctest
    doctest.testmod()

if __name__ == "__main__":
    _test()
