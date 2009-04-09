#! /usr/bin/env python2.5
# -*- coding: UTF-8 -*-
"""
======================
 rsync-linklog-stat.py
======================
------------------------------------------------------------------------------
 a tool to analyze rsync-dist log-link files
------------------------------------------------------------------------------

Overview
===============
This tool can be used to analyze the rsync-dist LOG-LINKS file. A LOG-LINKS
file is modified by rsync-dist.pl each time one or more links are changed.
Although the format of the log file contains all necessary information, it
is difficult to see which links point to which version or to see
what versions are no longer in use.

Here are the terms used in this manual:

version
  This is a single version of the distributed software. A version is a
  directory in the rsync-dist distribution directory whose last part
  is an ISO Date string like "2009-04-01T12:15". 

link
  This is a symbolic link in the rsync-dist link directory that
  points to a specific version. Links may come into existence at 
  some point of time pointing to a specific version. They may be 
  changed at another time to point to another
  version and they may be deleted some time later.

name
  In this program, this is the name of a link.

in use
  A version is called "in use" when at least one name points to
  that version.

active
  A version is called active when it is "in use" today

lifetime
  This is the sum of days a version was "in use". Note that
  the precise times are taken into account by using fractions
  of whole days.

Quick reference
===============

* show statistics on link names::

   rsync-linklog-stat.py -c rsync-dist.config -n

* show statistics on versions::

   rsync-linklog-stat.py -c rsync-dist.config -v

* show statistics on version lifetimes::

   rsync-linklog-stat.py -c rsync-dist.config -l

* show fallback recommendation::

   rsync-linklog-stat.py -c rsync-dist.config --fallback-info [linkname]

* show information for a list of versions::

   rsync-linklog-stat.py -c rsync-dist.config --version-info [version1,version2...]

Examples
========

The examples above, rsync-linklog-stat calls rsync-dist itself,
it only needs to know where the rsync-dist config file is found.
If you want better control on the parameters rsync-dist is called with,
you can also use rsync-linklog-stat in pipe mode. Here are 
some further examples. 

In the first example we just want a statistic of the lifetimes of all
versions::

  rsync-dist.pl -c rsync-dist.config --single-host python-log l | rsync-linklog-stat.py -l

If we want to use one of the options --filter-existent or --filter-nonexistent, calling the
program with a pipe gets a bit more complicated, since rsync-dist.pl has to be 
called twice in order to provide all the needed information::

  (rsync-dist.pl -c rsync-dist.config --single-host ls d; \\
   rsync-dist.pl -c rsync-dist.config --single-host python-log l) |\\
   rsync-linklog-stat.py -l --filter-existent

Output formats
==============

rsync-linklog-stat has four output formats.

the *names* format
  In this format, each symlink-name is followed by a colon and
  a number of lines describing at what date this link pointed
  to what version. If the symbolic link was removed at a certain
  time, the string "REMOVED" is printed instead of a version.
  An active version, that means the version the link currently
  points to, is marked with a star "*".
  Here is an example::

    ioc1:
         2009-03-19 11:40:16    2009-03-19T11:38:54

    ioc2:
         2009-03-19 11:41:16    2009-03-19T11:38:12
         2009-03-19 15:00:47    REMOVED

    ioc3:
    *    2009-03-19 15:00:24    2009-03-19T11:38:54

the *versions* format
  This format shows for each version at what time what symbolic links (names) pointed
  to this version. If a symbolic link was made to point to a different version
  at a certain date, the old version has a new entry with that timestamp with
  this symbolic link removed. If there are no symbolic links for a version,
  the list is empty. This shows that from this date on, the version is no longer 
  in use. Here is an example::

    2009-03-19T11:38:12:
         2009-03-19 11:41:16    ioc2
         2009-03-19 15:00:47    

    2009-03-19T11:38:54:
         2009-03-19 11:40:16    ioc1
         2009-03-19 15:00:24    ioc1 ioc3

the *lifetimes* format
  This format shows the timespan a version was in use, meaning the time 
  when at least one symbolic link pointed to that version. In this format
  the first and last date of any usage is printed as well as the lifetime 
  in fractions of days. If the version is at this time still in use,
  the second date is "NOW".
  Here is an example::

    2009-03-03T13:54:42:
         2009-03-03 13:55:58    2009-03-04 11:01:06 
         2009-03-04 14:42:43    2009-03-05 13:29:57 
                                                         1.83

    2009-03-19T11:38:54:
         2009-03-19 11:40:16    NOW
                                                         0.97

the *idles* format
  This format is used for the special -i or --idle option. It is 
  a list of the sub-directories in the distribution directory 
  that are not and were never in use, meaning no symbolic link ever pointed 
  to them. Here is an example::

    2009-02-25T08:29:07
    2009-02-25T17:01:44


Reference of command line options
=================================

--version
  print the version number of the script

-h, --help
  print a short help

--summary
  print a one-line summary of the script function

--doc
  create online help in restructured text format. 
  Use "./rsync-linklog-stat.py --doc | rst2html" to create html-help"

-t, --test
  perform a simple self-test of some internal functions

-f FILE, --file FILE
  specify the file to read from. If this option is missing, read
  from standard-in, if the program is used in pipe mode.
  Note that the -c option omits pipe mode, so -f is not needed if
  -c is used.

-c CONFIGFILE, --call CONFIGFILE
  call rsync-dist.pl directly with CONFIGFILE. With this option it
  is no longer necessary to call rsync-dist.pl directly.

-d, --distdir
  the option tells the program that the input on standard-in or
  from the file (see -f) contains also a listing of the 
  remote distribution directory as it is returned by rsync-dist.pl

-n, --names
  print summary for each link name

-v, --versions
  print summary for each version

-l, --lifetimes
  print lifetime summary for each version

-i, --idle
  print idle versions, versions that are not in 
  use and never have been.

--version-info [versions]
  show logfile information for [versions]. [versions] 
  is a comma-separated list of version strings.

-b, --brief
  brief output, with -n just show link names,
  with -v and -l just show version names

--last [no]
  with --names, print only the last [no] versions
  for each name
  
--filter-names [names]
  [names] may be a comma separated list. Only these
  names and their versions are printed.

--filter-active
  show only versions that are now in use

--filter-inactive
  show only versions that are not in use

--filter-inactive-since=DATE
  filter versions inactive for longer than a given DATE

--filter-lifetime-smaller=DAYS
  filter versions with a lifetime smaller than DAYS

--filter-lifetime-bigger=DAYS
  filter versions with a lifetime bigger than DAYS

--filter-existent
  show only version that are still existent in the 
  distribution directory. Note that in pipe-mode 
  you have call rsync-dist twice to get a listing of 
  the remote distribution directory.

--filter-nonexistent
  show only version that are not existent in the 
  distribution directory. Note that in pipe-mode 
  you have call rsync-dist twice to get a listing of 
  the remote distribution directory.

--filter-ignexistent
  show versions no matter if they exist or exist not
  in the distribution directory. This is needed if 
  you want to overturn the implicit --filter-existent
  that is defined in non pipe mode (when option -c
  is given).
  
--fallback-info [linkname]
  show a short list of recommended versions for
  the given linkname. This option corresponds to
  -n --filter-lifetime-bigger 2 --last 3 --filter-names 
  [linkname].
"""

from optparse import OptionParser
import subprocess
import os.path

import datetime
import sys
import re

# version of the program:
my_version= "1.0"

def Cnt(lst):
    s= 0
    for l in lst:
	if l:
	    s+= 1
    return s

def system(cmd, catch_stdout=True):
    """execute a command.
    
    execute a command and return the programs output
    may raise:
    IOError(errcode,stderr)
    OSError(errno,strerr)
    ValueError
    """
    if catch_stdout:
        stdout_par=subprocess.PIPE
    else:
        stdout_par=None
    
    p= subprocess.Popen(cmd, shell=True, 
                        stdout=stdout_par, stderr=subprocess.PIPE, 
                        close_fds=True)
    (child_stdout, child_stderr) = p.communicate()
    if p.returncode!=0:
        raise IOError(p.returncode,"cmd \"%s\", errmsg \"%s\"" % (cmd,child_stderr))
    return(child_stdout)

def rsync_dist(config_file,get_existing=False):
    """calls rsync-dist.pl with --python-log l.

    Parameters:
        config_file  -- the name of the rsync-dist config file
        get_existing -- is this is True, rsync-dist is also used
                        to get a list of existing versions in the
                        distribution directory
    """
    rsync= "rsync-dist.pl -c %s --single-host" % config_file
    if not get_existing:
        cmd=rsync+" python-log l"
    else:
        cmd="(%s ls d; %s python-log l)" % (rsync,rsync)
    return system(cmd)

def parse_maillike_lines(lines):
    """parse a record of the "maillike" format.

    Here is an example:
    >>> parse_maillike_lines(["ab: cd", "efg"," ","x: zz"])
    (['ab', 'x'], {'x': ['zz'], 'ab': ['cd', 'efg', '']})
    """
    rx_field= re.compile(r'^(\w+):\s*(.*)$')
    fields=[]
    contents= {}
    curr_field=None
    curr_value=[]
    for l in lines:
        if empty_str(l):
            l= ""
        if len(l)==0:
            if curr_field is None:
                continue
            curr_value.append(l)
            continue
        m= re.match(rx_field,l)
        if m is None:
            curr_value.append(l)
        else:
            curr_field= m.group(1)
            st= m.group(2)
            if empty_str(st):
                st= ""
            fields.append(curr_field)
            curr_value= [st]
            contents[curr_field]= curr_value
    return (fields,contents)

def parse_maillike(mstr):
    """parse the maillike format.

    Here is an example:
    >>> r='''
    ... %%
    ... VERSION: 2009-03-30T12:16:58
    ... ACTION: added
    ... FROM: pfeiffer@aragon.acc.bessy.de
    ... BRANCH: mars17
    ... TAG: mars17-2009-03-30 6
    ... LOG: a small change in the main panel
    ... %%
    ... VERSION: 2009-03-30T12:20:20
    ... ACTION: added
    ... FROM: pfeiffer@aragon.acc.bessy.de
    ... BRANCH: mars17
    ... TAG: mars17-2009-03-30 7
    ... LOG: another small change in the main panel
    ... '''
    >>> parts=parse_maillike(r)
    >>> for (l,d) in parts:
    ...   print l
    ...   for k in sorted(d.keys()):
    ...     print k,d[k]
    ... 
    ['VERSION', 'ACTION', 'FROM', 'BRANCH', 'TAG', 'LOG']
    ACTION ['added']
    BRANCH ['mars17']
    FROM ['pfeiffer@aragon.acc.bessy.de']
    LOG ['a small change in the main panel']
    TAG ['mars17-2009-03-30 6']
    VERSION ['2009-03-30T12:16:58']
    ['VERSION', 'ACTION', 'FROM', 'BRANCH', 'TAG', 'LOG']
    ACTION ['added']
    BRANCH ['mars17']
    FROM ['pfeiffer@aragon.acc.bessy.de']
    LOG ['another small change in the main panel']
    TAG ['mars17-2009-03-30 7']
    VERSION ['2009-03-30T12:20:20']
    """
    parsed=[]
    parts= mstr.split("%%")
    for p in parts:
        (fields,contents)= parse_maillike_lines(p.splitlines())
        if len(fields)>0:
            parsed.append((fields,contents))
    return parsed

def print_maillike_entry(fields,contents):
    """pretty print structures generated by parse_maillike_lines.

    Here is an example:
    >>> print_maillike_entry(['ab', 'x'], {'x': ['zz'], 'ab': ['cd', 'efg', '']})
    ab:       cd
              efg
    <BLANKLINE>
    x:        zz
    """
    for f in fields:
        pre= "%-10s" % (f+":")
        for l in contents[f]:
            print "%s%s" % (pre,l)
            pre= " " * 10

def print_maillike(parts):
    """print structure returned by parse_maillike.

    Here is an example:
    >>> r='''
    ... %%
    ... VERSION: 2009-03-30T12:16:58
    ... ACTION: added
    ... FROM: pfeiffer@aragon.acc.bessy.de
    ... BRANCH: mars17
    ... TAG: mars17-2009-03-30 6
    ... LOG: a small change in the main panel
    ... %%
    ... VERSION: 2009-03-30T12:20:20
    ... ACTION: added
    ... FROM: pfeiffer@aragon.acc.bessy.de
    ... BRANCH: mars17
    ... TAG: mars17-2009-03-30 7
    ... LOG: another small change in the main panel
    ... '''
    >>> print_maillike(parse_maillike(r))
    VERSION:  2009-03-30T12:16:58
    ACTION:   added
    FROM:     pfeiffer@aragon.acc.bessy.de
    BRANCH:   mars17
    TAG:      mars17-2009-03-30 6
    LOG:      a small change in the main panel
    <BLANKLINE>
    VERSION:  2009-03-30T12:20:20
    ACTION:   added
    FROM:     pfeiffer@aragon.acc.bessy.de
    BRANCH:   mars17
    TAG:      mars17-2009-03-30 7
    LOG:      another small change in the main panel
    """
    sep=False
    for (fields,contents) in parts:
        if sep:
            print
        print_maillike_entry(fields,contents)
        sep= True

def rsync_dist_ls_version(config_file):
    """call rsync-dist.pl in order to get the version-log.
    """
    cmd="rsync-dist.pl -c %s --single-host ls-version '.*'" % config_file
    return system(cmd)

def filter_ls_version(parsed, wanted_versions):
    """filter out wanted versions from rsync_dist_ls_version output.

    if wanted_versions is None, no filtering is performed.
    Here is an example:
    >>> r='''
    ... %%
    ... VERSION: 2009-03-30T12:16:58
    ... ACTION: added
    ... FROM: pfeiffer@aragon.acc.bessy.de
    ... BRANCH: mars17
    ... TAG: mars17-2009-03-30 6
    ... LOG: a small change in the main panel
    ... %%
    ... VERSION: 2009-03-30T12:20:20
    ... ACTION: added
    ... FROM: pfeiffer@aragon.acc.bessy.de
    ... BRANCH: mars17
    ... TAG: mars17-2009-03-30 7
    ... LOG: another small change in the main panel
    ... '''
    >>> parsed=parse_maillike(r)
    >>> filtered= filter_ls_version(parsed,["2009-03-30T12:16:58"])
    >>> print_maillike(filtered)
    VERSION:  2009-03-30T12:16:58
    ACTION:   added
    FROM:     pfeiffer@aragon.acc.bessy.de
    BRANCH:   mars17
    TAG:      mars17-2009-03-30 6
    LOG:      a small change in the main panel
    """
    new=[]
    if wanted_versions is None:
        return parsed
    for (fields,contents) in parsed:
        if not contents.has_key("VERSION"):
            raise ValueError, "entry with no version info found:%s" %\
                               str(contents)
        if contents["VERSION"][0] in wanted_versions:
            new.append((fields,contents))
    return new

def datetime_of_isodate(str):
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
    >>> datetime_of_isodate("2006-10-09")
    datetime.datetime(2006, 10, 9, 0, 0)
    >>> datetime_of_isodate("2007-11-09")
    datetime.datetime(2007, 11, 9, 0, 0)
    >>> datetime_of_isodate("2007-11-09x")
    Traceback (most recent call last):
       ...
    ValueError: unconverted data remains: x
    """
    return datetime.datetime.strptime(str,"%Y-%m-%d")

def datetime_of_isodatetime(str):
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
    >>> datetime_of_isodatetime("2006-10-09T10:33:09")
    datetime.datetime(2006, 10, 9, 10, 33, 9)
    >>> datetime_of_isodatetime("2006-10-09T10:33:09x")
    Traceback (most recent call last):
       ...
    ValueError: unconverted data remains: x
    >>> datetime_of_isodatetime("2006-99-09T10:33:09")
    Traceback (most recent call last):
       ...
    ValueError: time data did not match format:  data=2006-99-09T10:33:09  fmt=%Y-%m-%dT%H:%M:%S
    """
    return datetime.datetime.strptime(str,"%Y-%m-%dT%H:%M:%S")

def isodatetime_of_datetime(d):
    """converts a date to ISO format.

    This function returns the datetime.datetime
    object as an ISO date string of the form
    YYYY-MM-DDTHH:MM:SS.

    parameters:
        d       -- a datetime.datetime object
    returns:
        a string.

    Here are some examples:
    >>> isodatetime_of_datetime(datetime.datetime(2008, 10, 20, 11, 19, 30))
    '2008-10-20T11:19:30'
    """
    return d.strftime("%Y-%m-%dT%H:%M:%S")

def datetime_of_lsl_isodate(str):
    """parse an ISO-like date produced from ls -l.

    This function parses a date in the form
    YYYY-MM-DD HH:MM, which is a date that the "ls -l"
    command may produce. It returns a datetime.datetime object.

    parameters:
        str     -- the string to parse
    returns:
        a datetime.datetime object

    Here are some examples:
    >>> datetime_of_lsl_isodate("2009-03-16 10:26")
    datetime.datetime(2009, 3, 16, 10, 26)
    >>> datetime_of_lsl_isodate("2009-03-16  10:26")
    datetime.datetime(2009, 3, 16, 10, 26)
    >>> datetime_of_lsl_isodate("Oct  9 10:42")
    Traceback (most recent call last):
       ...
    ValueError: time data did not match format:  data=Oct  9 10:42  fmt=%Y-%m-%d %H:%M
    """
    return datetime.datetime.strptime(str,"%Y-%m-%d %H:%M")

def datetime_of_lsl_nonisodate(str,year=None):
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
    >>> datetime_of_lsl_nonisodate("Oct  9 10:42")
    datetime.datetime(1900, 10, 9, 10, 42)
    >>> datetime_of_lsl_nonisodate("Oct  9 10:42",2005)
    datetime.datetime(2005, 10, 9, 10, 42)
    >>> datetime_of_lsl_nonisodate("Oct  9 2007")
    datetime.datetime(2007, 10, 9, 0, 0)
    >>> datetime_of_lsl_nonisodate("Oct  9 10:42b",2005)
    Traceback (most recent call last):
       ...
    ValueError: time data did not match format:  data=Oct  9 10:42b  fmt=%b %d %Y
    """
    try:
	d= datetime.datetime.strptime(str,"%b %d %H:%M")
	if year is not None:
	    d= d.replace(year=year)
    except ValueError,e:
	d= datetime.datetime.strptime(str,"%b %d %Y")
    return d

def datetime_of_lsl_tokenlist(list,year=None):
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
    >>> datetime_of_lsl_tokenlist("2009-03-16 14:46 idcp8 ->".split())
    (datetime.datetime(2009, 3, 16, 14, 46), ['idcp8', '->'])
    >>> datetime_of_lsl_tokenlist("Oct  9 10:42 idcp13 ->".split())
    (datetime.datetime(1900, 10, 9, 10, 42), ['idcp13', '->'])
    >>> datetime_of_lsl_tokenlist(" Oct  9 10:42 idcp13 ->".split())
    (datetime.datetime(1900, 10, 9, 10, 42), ['idcp13', '->'])
    >>> datetime_of_lsl_tokenlist(" Oct  9 2007 idcp13 ->".split())
    (datetime.datetime(2007, 10, 9, 0, 0), ['idcp13', '->'])
    >>> datetime_of_lsl_tokenlist("nOct  9 10:42 idcp13 ->".split())
    Traceback (most recent call last):
       ...
    ValueError: no parsable date in list: ['nOct', '9', '10:42', 'idcp13', '->']
    """
    str= " ".join(list[0:2])
    try:
        d= datetime_of_lsl_isodate(str)
        return(d, list[2:])
    except ValueError,e:
        pass
    str= " ".join(list[0:3])
    try:
        d= datetime_of_lsl_nonisodate(str,year)
        return(d, list[3:])
    except ValueError,e:
        raise ValueError, "no parsable date in list: %s" % repr(list)

def token_subtract(str,no):
    """removes <no> tokens from the beginning of a string.

    Here are some examples:
    >>> token_subtract("a bc def",2)
    'def'
    >>> token_subtract("a bc def",1)
    'bc def'
    >>> token_subtract("a bc def",3)
    ''
    >>> token_subtract("a bc def",4)
    Traceback (most recent call last):
       ...
    ValueError: string hasn't got 4 tokens
    >>> token_subtract("a bc def ghi  jkl",3)
    'ghi  jkl'
    """
    elms= str.split()
    if (len(elms)<no):
        raise ValueError,"string hasn't got %d tokens" % no
    for e in elms[:no]:
        str= str.replace(e,"",1)
    return str.lstrip()

def parse_lsl_line(str):
    """parses a line of the output of the "ls -l" command.

    This function returns a tuple with these contents
    type_and_mode
    hard_links
    owner_name
    group_name
    size
    timestamp (a datetime.datetime object)
    name

    Here are some examples:
    >>> def t(tp):
    ...   for e in tp:
    ...     print e
    ... 
    >>> t(parse_lsl_line("lrwxr-xr-x   1 idadm    expermt        27 Oct  9 13:14 idcp13 -> ../dist/2006-10-09T10:33:09"))
    lrwxr-xr-x
    1
    idadm
    expermt
    27
    1900-10-09 13:14:00
    idcp13 -> ../dist/2006-10-09T10:33:09
    >>> t(parse_lsl_line("lrwxr-xr-x   1 idadm    expermt        27 Oct  9 2007 13:14 idcp13 -> ../dist/2006-10-09T10:33:09"))
    lrwxr-xr-x
    1
    idadm
    expermt
    27
    2007-10-09 00:00:00
    13:14 idcp13 -> ../dist/2006-10-09T10:33:09
    >>> t(parse_lsl_line("lrwxrwxrwx 1 iocadm iocadm 47 2009-03-16 14:46 idcp8 -> /opt/IOC/Releases/idcp/dist/2009-03-16T14:46:04"))
    lrwxrwxrwx
    1
    iocadm
    iocadm
    47
    2009-03-16 14:46:00
    idcp8 -> /opt/IOC/Releases/idcp/dist/2009-03-16T14:46:04
    >>> 
    """
    elms= str.strip().split()
    token_no= len(elms)
    (type_and_mode,hard_links,owner_name,group_name,size)=elms[0:5]
    elms= elms[5:]
    (timestamp,elms)= datetime_of_lsl_tokenlist(elms)
    name= token_subtract(str,token_no-len(elms))
    return (type_and_mode,hard_links,owner_name,group_name,size,timestamp,name)

def parse_lsl_symlink(str):
    """parse a symlink as it is listed by ls -l command.

    returns a tuple consisting of the 
    name of the symlink and it's source.

    Here are some examples:
    >>> parse_lsl_symlink("idcp8 -> /opt/IOC/Releases/idcp/dist/2009-03-16T14:46:04")
    ('idcp8', '/opt/IOC/Releases/idcp/dist/2009-03-16T14:46:04')
    >>> parse_lsl_symlink("/opt/IOC/Releases/idcp/dist/2009-03-16T14:46:04")
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

def split_at(str,sep):
    """split a string at the given separator.

    The separator is kept as the start of the second
    string of the two strings that are returned by
    this function.

    Here is an example:
    >>> split_at("a : b",":")
    ('a ', ': b')
    """
    p= str.find(sep)
    if p==-1:
        # separator not found
        raise ValueError,"separator '%s' not found in string" % sep
    return(str[0:p],str[p:])

def empty_str(str):
    """tests if a string is empty or consists only of whitespaces.

    Here are some examples:
    >>> empty_str("A")
    False
    >>> empty_str(" ")
    True
    >>> empty_str("")
    True
    """
    if len(str)==0:
        return True
    return str.isspace()

def parse_lsl_symlink_lines(str):
    r"""parse the "ADDED", "OLD", "NEW" or "REMOVED" parts of the log-links file.

    returns a dictionary, mapping the link names to the link sources.
    Here are some examples:
    >>> parse_lsl_symlink_lines('''
    ... lrwxr-xr-x   1 idadm    expermt        27 Oct  9 16:00 idcp15 -> ../dist/2006-10-09T10:28:13
    ... lrwxr-xr-x   1 idadm    expermt        27 Oct  9 16:00 idcp9 -> ../dist/2006-10-09T10:28:13
    ... ''')
    {'idcp9': '../dist/2006-10-09T10:28:13', 'idcp15': '../dist/2006-10-09T10:28:13'}
    """
    links= {}
    lines= str.splitlines()
    for l in lines:
        if empty_str(l):
            continue
        (type_and_mode,hard_links,owner_name,group_name,size,timestamp,name)= parse_lsl_line(l)
        (name,source)= parse_lsl_symlink(name)
        links[name]= source
    return links

def basename_symlink_dict(sdict):
    """remove path path of versions in sdict.

    parameters:
        sdict   -- a dictionary returned by parse_lsl_symlink_lines
    returns:
        another dictionary, where the link destinations are replaced
        by their basenames

    Here is an example:
    >>> d={'idcp9': '../dist/2006-10-09T10:28:13', 
    ...    'idcp15': '../dist/2006-10-09T10:28:13'}
    >>> basename_symlink_dict(d)
    {'idcp9': '2006-10-09T10:28:13', 'idcp15': '2006-10-09T10:28:13'}
    """
    new={}
    for (k,v) in sdict.items():
        new[k]= my_basename(v)
    return new

def parse_lsl_distdir(lines):
    """parses the output of "rsync-dist.pl ls l" and returns the versions.

    Note that the set that is returned by this function just
    contains the date-part of the version, not the complete path!

    Here is an example:
    >>> l='''
    ... drwxrwxr-x 3 pfeiffer pfeiffer 4096 2009-03-19 11:38 2009-03-19T11:38:12
    ... drwxrwxr-x 3 pfeiffer pfeiffer 4096 2009-03-19 11:38 2009-03-19T11:38:54
    ... drwxrwxr-x 2 pfeiffer pfeiffer 4096 2009-03-19 11:38 attic
    ... -rw-rw-r-- 1 pfeiffer pfeiffer  158 2009-03-19 11:38 CHANGES-DIST
    ... '''
    >>> parse_lsl_distdir(l)
    set(['2009-03-19T11:38:12', '2009-03-19T11:38:54'])
    """
    versions=set()
    for l in lines.splitlines():
        try:
            result= parse_lsl_line(l)
        except ValueError,e:
            # just ignore unparsable lines
            # print "IGNORED:",l
            continue
        name= result[-1]
        try:
            d= datetime_of_isodatetime(name)
        except ValueError,e:
            # ignore filenames that are not an ISO date
            continue
        versions.add(name)
    return versions

def my_basename(path):
    """returns the last part of a path.

    Here are some examples:
    >>> my_basename("abc")
    'abc'
    >>> my_basename("ab/c")
    'c'
    >>> my_basename("/ab/c")
    'c'
    >>> my_basename("/c")
    'c'
    >>> my_basename("c")
    'c'
    """
    return os.path.split(path)[-1]

def filter_existent_versions(version_paths, short_existing_version_names):
    """return all version_paths that are also in short_existing_version_names.

    Note that the parameter short_existing_version_names usually only
    contains the date-part of the version, but not the complete 
    path. Version_paths however, contain version paths.

    Here is an example:
    >>> v=set(['/home/pfeiffer/r/dist/2009-03-19T11:38:12',
    ...   '/home/pfeiffer/r/dist/2009-03-19T11:38:54'])
    >>> e=set(['2009-03-19T11:38:12'])
    >>> filter_existent_versions(v,e)
    set(['/home/pfeiffer/r/dist/2009-03-19T11:38:12'])
    """
    result= set()
    for v in version_paths:
        last= my_basename(v)
        if last in short_existing_version_names:
            result.add(v)
    return result

def filter_idle_version_names(version_paths, short_existing_version_names):
    """return all versions that are only in short_existing_version_names.

    Note that the parameter short_existing_version_names usually only
    contains the date-part of the version, but not the complete 
    path. Version_paths however, contain version paths.

    Here is an example:
    >>> v=set(['/home/pfeiffer/r/dist/2009-03-19T11:38:12',
    ...   '/home/pfeiffer/r/dist/2009-03-19T11:38:54'])
    >>> e=set(['2009-03-19T11:38:12','2009-03-19T12:00:00'])
    >>> filter_idle_version_names(v,e)
    set(['2009-03-19T12:00:00'])
    """
    result= set()
    for v in version_paths:
        last= os.path.split(v)[-1]
        if last in short_existing_version_names:
            result.add(last)
    return short_existing_version_names.difference(result)

def print_idle_versions(myset):
    """print the list of idle versions.
    """
    print "idle versions:"
    print "\n".join(sorted(myset))

def parse_log_by_name(log):
    """parses the log-links file by name.

    This function parses the log-links structure and returns
    a dictionary mapping link names to lists of tuples, each 
    tuple containing a date (a datetime.datetime object) 
    and a version name. If a link was removed, the version name
    of this event is set to <None>.
    
    The structure looks like this:

    { "name1" : [(datetime1, "version1-1"),
                 (datetime2, "version1-2")],
      "name2" : [(datetime3, "version2-1")]
    }

    parameters:
        log     -- a list of dictionaries, each dictionary 
                   is a single event that was logged
    returns:
        a dictionary mapping link names to dates and version 
        names.

    Here is an example:
    >>> t=[{"DATE":"2006-10-09T16:00:54",
    ...     "ADDED":'''
    ... lrwxr-xr-x 1 idadm expermt 27 Oct  9 16:00 idcp8 -> ../dist/2006-10-09T10:28:13
    ... lrwxr-xr-x 1 idadm expermt 27 Oct  9 16:00 idcp9 -> ../dist/2006-10-09T10:28:13'''},
    ...    {"DATE":"2008-10-20T11:19:30",
    ...     "NEW":'''
    ... lrwxrwxrwx 1 idadm epima 47 2008-10-20 11:19 idcp8 -> ../dist/2008-10-16T12:42:03'''},
    ...    {"DATE":"2008-10-21T12:10:00",
    ...     "REMOVED":'''
    ... lrwxrwxrwx 1 idadm epima 47 2008-10-20 11:19 idcp8 -> ../dist/2008-10-16T12:42:03'''}
    ... ]
    >>> r=parse_log_by_name(t)
    >>> for n in sorted(r.keys()):
    ...   print "%s:" % n
    ...   for e in r[n]:
    ...     print "    ",e
    ... 
    idcp8:
         (datetime.datetime(2006, 10, 9, 16, 0, 54), '2006-10-09T10:28:13')
         (datetime.datetime(2008, 10, 20, 11, 19, 30), '2008-10-16T12:42:03')
         (datetime.datetime(2008, 10, 21, 12, 10), None)
    idcp9:
         (datetime.datetime(2006, 10, 9, 16, 0, 54), '2006-10-09T10:28:13')
    """
    def parse(x):
        """get only basenames of link targets."""
        return basename_symlink_dict(parse_lsl_symlink_lines(x))
    # a dict mapping names to a list of dates and versions
    versions= {}
    for entry in log:
        date= datetime_of_isodatetime(entry["DATE"])
        if entry.has_key("ADDED"):
            # a dict mapping link names to versions
            changed_versions= parse(entry["ADDED"])
        elif entry.has_key("REMOVED"):
            changed_versions= parse(entry["REMOVED"])
            # remove version from name-dict, since these
            # names were deleted:
            for n in changed_versions:
                changed_versions[n]= None
        else:
            changed_versions= parse(entry["NEW"])
        for n in changed_versions.keys():
            d= versions.setdefault(n,[])
            d.append((date,changed_versions[n]))
    return versions

def print_log_by_name(d,activated_versions,brief=False,last=None):
    """pretty-prints results by parse_log_by_name.

    Here is an example:
    >>> r={'idcp9': [(datetime.datetime(2006, 10, 9, 16, 0, 54), '2006-10-09T10:28:13')],
    ...    'idcp8': [(datetime.datetime(2006, 10, 9, 16, 0, 54), '2006-10-09T10:28:13'),
    ...              (datetime.datetime(2008, 10, 20, 11, 19, 30), '2008-10-16T12:42:03'),
    ...              (datetime.datetime(2008, 10, 21, 12, 10), None)]}
    >>> act={'idcp9': '2006-10-09T10:28:13'}
    >>> print_log_by_name(r,act)
    name date                   version
    idcp8:
         2006-10-09 16:00:54    2006-10-09T10:28:13
         2008-10-20 11:19:30    2008-10-16T12:42:03
         2008-10-21 12:10:00    REMOVED
    <BLANKLINE>
    idcp9:
    *    2006-10-09 16:00:54    2006-10-09T10:28:13
    """
    if brief:
        for n in sorted(d.keys()):
            print n
        return
    print "name date                   version"
    LF=""
    for n in sorted(d.keys()):
        activated= activated_versions.get(n)
        lst= d[n]
        print "%s%s:" % (LF,n)
        LF="\n"
        if last is not None:
            if last<len(lst):
                lst=lst[len(lst)-last:]
        # printing is a bit complicated here since
        # we want to print the star "*" only the LAST
        # time an active version is in the list, not
        # every time (note that the same version can
        # appear more than once in the list). 
        # More than one star would confuse the user.
        lines=[]
        for elm in reversed(lst):
            ver= elm[1]
            if ver is None:
                ver= "REMOVED"
            if activated==ver:
                lines.append("*%23s    %s" % (elm[0],ver))
                activated=None
            else:
                lines.append(" %23s    %s" % (elm[0],ver))
        for l in reversed(lines):
            print l

def versions_of_log_by_name(ndict, names):
    """returns a set of versions that were used by the given names.

    parameters:
        ndict   -- a dictionary returned by parse_log_by_name
        names   -- a set or list of names.
    returns:
        a set of versions

    Here are some examples:
    >>> r={'idcp9': [(datetime.datetime(2006, 10, 9, 16, 0, 54), 
    ...                  '../dist/2006-10-09T10:28:13')], 
    ...    'idcp8': [(datetime.datetime(2006, 10, 9, 16, 0, 54), 
    ...                  '../dist/2006-10-09T10:28:13'), 
    ...              (datetime.datetime(2008, 10, 20, 11, 19, 30), 
    ...                  '../dist/2008-10-16T12:42:03'), 
    ...              (datetime.datetime(2008, 10, 21, 12, 10), None)]
    ...   }
    >>> versions_of_log_by_name(r,["idcp8"])
    set(['../dist/2008-10-16T12:42:03', '../dist/2006-10-09T10:28:13'])
    >>> versions_of_log_by_name(r,["idcp9"])
    set(['../dist/2006-10-09T10:28:13'])
    >>> versions_of_log_by_name(r,["idcp10"])
    Traceback (most recent call last):
       ...
    ValueError: name 'idcp10' not found
    """
    version_set= set()
    for name in names:
        if not ndict.has_key(name):
            raise ValueError, "name '%s' not found" % name
        for (date,version) in ndict[name]:
            if version is not None:
                version_set.add(version)
    return version_set

def parse_namedict_by_version(names):
    """parses the name dictionary returned by parse_log_by_name by version.

    This function parses the dictionary returned by
    parse_log_by_name and returns
    a dictionary mapping versions to dictionaries,
    each mapping a date to a set of names.
    
    The structure looks like this:

    { "version1" : {datetime1: set(["name1","name2"]),
                    datetime2: set(["name2"])},
      "version2" : {datetime1: set(["name3","name4"])}
    }

    parameters:
        log     -- a dictionary that was created by
                   parse_log_by_name
    returns:
        a dictionary mapping versions to dates and sets of
        names.

    Here is an example:
    >>> n={'idcp9': [(datetime.datetime(2006, 10, 9, 16, 0, 54), '../dist/2006-10-09T10:28:13')],
    ...    'idcp8': [(datetime.datetime(2006, 10, 9, 16, 0, 54), '../dist/2006-10-09T10:28:13'),
    ...              (datetime.datetime(2008, 10, 20, 11, 19, 30), '../dist/2008-10-16T12:42:03'),
    ...              (datetime.datetime(2008, 10, 21, 12, 10), None)]}
    >>> r=parse_namedict_by_version(n)
    >>> for v in sorted(r.keys()):
    ...   print "%s:" % v
    ...   for d in sorted(r[v].keys()):
    ...     print "    ",d
    ...     print "        ",r[v][d]
    ... 
    ../dist/2006-10-09T10:28:13:
         2006-10-09 16:00:54
             set(['idcp9', 'idcp8'])
         2008-10-20 11:19:30
             set(['idcp9'])
    ../dist/2008-10-16T12:42:03:
         2008-10-20 11:19:30
             set(['idcp8'])
         2008-10-21 12:10:00
             set([])
    """
    # a dict mapping versions to a dict mapping
    # a date to a set of names:
    versions= {}
    # a dict mapping a version to a last-date:
    last_date_of_version={}
    # names= parse_log_by_name(log)
    for n in names.keys():
        old_version= None
        for entry in names[n]:
            (date,new_version)= entry
            # skip events where a name was changed but to
            # the same version it had before:
            if old_version==new_version:
                continue
            if new_version is not None:
                new_version_dict= versions.setdefault(new_version,{})
                new_names= new_version_dict.setdefault(date,[])
                new_names.append(("A",n))
            if old_version is not None:
                old_version_dict= versions.setdefault(old_version,{})
                old_names= old_version_dict.setdefault(date,[])
                old_names.append(("D",n))
            old_version= new_version
    for (version,version_dict) in versions.items():
        dates= sorted(version_dict.keys())
        cur_set= set()
        for d in dates:
            for (flag,name) in version_dict[d]:
                if flag == "A":
                    cur_set.add(name)
                else:
                    try:
                        cur_set.remove(name)
                    except KeyError,e:
                        print "warning: not found: %s %s %s" % (version,d,name)
            version_dict[d]= set(cur_set)
    return versions

# parse_namedict_by_version(zz)

def print_log_by_version(d,brief=False):
    """pretty-prints results by parse_namedict_by_version.

    Here is an example:
    >>> r={'2008-10-16T12:42:03': {datetime.datetime(2008, 10, 20, 11, 19, 30): set(['idcp8']),
    ...                            datetime.datetime(2008, 10, 21, 12, 10): set([])},
    ...    '2006-10-09T10:28:13': {datetime.datetime(2006, 10, 9, 16, 0, 54): set(['idcp9', 'idcp8']), 
    ...                            datetime.datetime(2008, 10, 20, 11, 19, 30): set(['idcp9'])}}
    >>> print_log_by_version(r)
    ver. date                   name(s)
    2006-10-09T10:28:13:
         2006-10-09 16:00:54    idcp8 idcp9
         2008-10-20 11:19:30    idcp9
    <BLANKLINE>
    2008-10-16T12:42:03:
         2008-10-20 11:19:30    idcp8
         2008-10-21 12:10:00    
    """
    if brief:
        for version in sorted(d.keys()):
            print version
        return
    print "ver. date                   name(s)"
    LF=""
    for version in sorted(d.keys()):
        version_dict= d[version]
        print "%s%s:" % (LF,version)
        LF="\n"
        for date in sorted(version_dict.keys()):
            names= sorted(version_dict[date])
            print "%24s    %s" % (date,
                                  " ".join(names))
                                
def active_times_of_log_by_version(vdict):
    """calculate timespans when versions where active (in use).

    This function parses the dictionary returned by
    parse_namedict_by_version and returns
    a dictionary mapping versions to lists. Each list
    contains tuples of two dates, that describe a timespan
    the version was in use, meaning that at least one link
    pointed to that version. If the version is still in use,
    the second date of the last tuple in the list is None.

    The structure looks like in this example:

    { "version1" : [(datetime1, datetime2),(datetime3,datetime4)],
      "version2" : [(datetime3, None)]
    }

    parameters:
        d       -- a dictionary that was created by
                   parse_namedict_by_version
    returns:
        a dictionary mapping versions to tuples of two dates.

    Here are some examples:
    >>> r={'../dist/2008-10-16T12:42:03': {datetime.datetime(2008, 10, 20, 12, 00): set(['idcp8']),
    ...                                    datetime.datetime(2008, 10, 21, 12, 00): set([]),
    ...                                    datetime.datetime(2008, 10, 23, 12, 00): set(['idcp9','idcp8']),
    ...                                    datetime.datetime(2008, 10, 24, 12, 00): set(['idcp8']),
    ...                                    datetime.datetime(2008, 10, 27, 12, 00): set([]),
    ...                                   },
    ...    '../dist/2006-11-09T10:28:13': {datetime.datetime(2006, 11,  9, 12, 00): set(['idcp9', 'idcp8']), 
    ...                                    datetime.datetime(2008, 11, 20, 12, 00): set(['idcp9'])
    ...                                   }
    ...   }
    >>> l=active_times_of_log_by_version(r)
    >>> for v in sorted(l.keys()):
    ...    print "%s:" % v
    ...    for tp in l[v]:
    ...        print "    from %s  to %s " % (tp)
    ... 
    ../dist/2006-11-09T10:28:13:
        from 2006-11-09 12:00:00  to None 
    ../dist/2008-10-16T12:42:03:
        from 2008-10-20 12:00:00  to 2008-10-21 12:00:00 
        from 2008-10-23 12:00:00  to 2008-10-27 12:00:00 
    """
    lifetimes={}
    for version in sorted(vdict.keys()):
        version_alive= []
        # ^^^ list of pairs of dates
        version_dict= vdict[version]
        # ^^^ a dictionary mapping dates to sets of names
        in_use_since= None
        dates= sorted(version_dict.keys())
        for d in dates:
            name_set= version_dict[d]
            if len(name_set)==0:
                # no longer in use
                if in_use_since is None:
                    continue
                version_alive.append((in_use_since,d))
                in_use_since= None
            else:
                # in use
                if in_use_since is not None:
                    continue
                in_use_since= d
        if in_use_since is not None:
            version_alive.append((in_use_since,None))
        lifetimes[version]= version_alive
    return lifetimes

def lifetimes_in_days(vdict, todays_date=None):
    """calculate lifetimes of versions in fractional days.

    This function takes the dictionary returned by 
    active_times_of_log_by_version and calculates a lifetime
    in days for each version by summing up the times it 
    was active.

    parameters:
        vdict        -- a dictionary that was created by active_times_of_log_by_version
        todays_date  -- define the value that is taken for "today" when a version
                        is still active. Mainly used for testing.
    returns:
        a dictionary mapping versions to lifetimes, where the
        lifetime is measured in days and is of type float.

    Here is an example:
    >>> r= {'../dist/2008-10-16T12:42:03': 
    ...         [(datetime.datetime(2008, 10, 20, 12, 0), datetime.datetime(2008, 10, 21, 12, 0)), 
    ...      (datetime.datetime(2008, 10, 23, 12, 0), datetime.datetime(2008, 10, 27, 12, 0))], 
    ...     '../dist/2008-11-09T10:28:13': 
    ...         [(datetime.datetime(2008, 11, 9, 12, 0), None)]
    ...    }
    >>> lifetimes_in_days(r,datetime.datetime(2008,11,10,18,0))
    {'../dist/2008-10-16T12:42:03': 5.0, '../dist/2008-11-09T10:28:13': 1.25}
    """
    if todays_date is None:
        todays_date= datetime.datetime.today()
    lifetimes={}
    for (version,times) in vdict.items():
        liftetime=0
        for tp in times:
            d2= tp[1]
            d1= tp[0]
            if d2 is None:
                d2= todays_date
            delta= d2-d1
            liftetime+= delta.days+delta.seconds/86400.0
        lifetimes[version]= liftetime
    return lifetimes
    
def get_versions_from_lifetime(d,lifetime):
    """calculate a list of version with a lifetime bigger or equal than a given value.

    parameters:
        d        -- a dictionary returned by lifetimes_in_days
        lifetime -- the minimum lifetime in days

    Here are some examples:
    >>> l= {'../dist/2008-10-16T12:42:03': 5.0, '../dist/2008-11-09T10:28:13': 1.25}
    >>> get_versions_from_lifetime(l,1)
    set(['../dist/2008-10-16T12:42:03', '../dist/2008-11-09T10:28:13'])
    >>> get_versions_from_lifetime(l,1.25)
    set(['../dist/2008-10-16T12:42:03', '../dist/2008-11-09T10:28:13'])
    >>> get_versions_from_lifetime(l,1.26)
    set(['../dist/2008-10-16T12:42:03'])
    >>> get_versions_from_lifetime(l,5)
    set(['../dist/2008-10-16T12:42:03'])
    >>> get_versions_from_lifetime(l,6)
    set([])
    """
    active= set()
    for version in d:
        if d[version]>=lifetime:
            active.add(version)
    return active

def get_activated_versions(d):
    """calculate a dictionary mapping names to their currently selected version.

    parameters:
        d       -- a dictionary returned by parse_log_by_name
    returns:
        a dictionary that maps names to their currently selected version.

    Here is an example:
    >>> r={'idcp9': [(datetime.datetime(2006, 10, 9, 16, 0, 54), '../dist/2006-10-09T10:28:13')],
    ...    'idcp8': [(datetime.datetime(2006, 10, 9, 16, 0, 54), '../dist/2006-10-09T10:28:13'),
    ...              (datetime.datetime(2008, 10, 20, 11, 19, 30), '../dist/2008-10-16T12:42:03'),
    ...              (datetime.datetime(2008, 10, 21, 12, 10), None)]}
    >>> get_activated_versions(r)
    {'idcp9': '../dist/2006-10-09T10:28:13', 'idcp8': None}
    """
    active= {}
    for (n,entries) in d.items():
        active[n]= entries[-1][1]
    return active

def get_active_versions(d,invert=False,since=None):
    """calculate a list of versions still in use.

    parameters:
        d       -- a dictionary returned by active_times_of_log_by_version
        invert  -- invert function, return inactive versions instead
                   of active versions
        since   -- an optional date, only used when invert is True
    returns:
        a set of versions still active

    Here is an example:
    >>> l={'../dist/2008-10-16T12:42:03': 
    ...        [(datetime.datetime(2008, 10, 20, 11, 19, 30), datetime.datetime(2008, 10, 20, 13, 10)),
    ...         (datetime.datetime(2008, 10, 21, 12, 00, 00), datetime.datetime(2008, 10, 22, 12, 00))],
    ...    '../dist/2006-10-09T10:28:13': [(datetime.datetime(2006, 10, 9, 16, 0, 54), None)]}
    >>> get_active_versions(l)
    set(['../dist/2006-10-09T10:28:13'])
    """
    active= set()
    if not invert:
        # get active versions
        for (version,dates) in d.items():
            if dates[-1][1] is None:
                active.add(version)
    else:
        # get inactive versions
        for (version,dates) in d.items():
            lastdate= dates[-1][1]
            if lastdate is not None:
                if since is not None:
                    if since<lastdate:
                        continue
                active.add(version)
    return active
    
def filter_by_names(rem_names,namedict,versiondict):
    """remove all names that are in the list.
    """
    for n in rem_names:
        del namedict[n]
        for (v,dates) in versiondict.items():
            for d in dates.keys():
                try:
                    dates[d].remove(n)
                except KeyError,e:
                    pass

def filter_by_versions(rem_versions,namedict,versiondict,lifetimes):
    """remove all versions that are in the list.
    """
    for v in rem_versions:
        del versiondict[v]
        del lifetimes[v]
        for (name,entries) in namedict.items():
            namedict[name]= filter(lambda x:x[1] not in rem_versions, entries)

def print_lifetimes(active,life,brief=False):
    """pretty-print lifetimes of versions.
    """
    if brief:
        for version in sorted(life.keys()):
            print version
        return
    today= datetime.datetime.today()
    print "ver. activated              deactivated"
    LF=""
    for version in sorted(life.keys()):
        print "%s%s:" % (LF,version)
        for (date1,date2) in active[version]:
            datestr1= date1
            if date2 is None:
                datestr2= "NOW"
                delta= today-date1
            else:
                datestr2= date2
                delta= date2-date1
            print "%24s    %-20s" % (datestr1,datestr2)
        print "%24s    %-20s    %5.2f" % ("","",life[version])
        LF="\n"

def version_info(options):
    """print information for selected versions.
    """
    raw_data= rsync_dist_ls_version(options.call)
    parsed= parse_maillike(raw_data)
    # print_maillike(parsed)
    # print "-" * 20
    wanted_versions= options.version_info.split(",")
    # print wanted_versions
    # print "-" * 20
    parsed= filter_ls_version(parsed, wanted_versions)
    print_maillike(parsed)


def process_file(f,options):
    """process a single file.
    """
    if options.fallback_info:
        options.names= True
        options.filter_lifetime_bigger=2
        options.last=3
        options.filter_names= options.fallback_info
    filter_existent= (options.filter_existent or options.call) and \
                     (not (options.filter_ignexistent or options.filter_nonexistent))
    distdir_info= (options.distdir or filter_existent or
                   options.filter_nonexistent or options.idle)
    if options.call:
        input= rsync_dist(options.call,distdir_info)
    else:
        if f is not None:
            fh=open(f)
        else:
            fh=sys.stdin
        # read the whole file:
        input= fh.read()
        if f is not None:
            fh.close()
    if distdir_info:
        # separate the distdir listing from the
        # log-links output:
        (distdir_listing,loglinks_struct)= split_at(input,"[")
    else:
        loglinks_struct= input

    if distdir_info:
        existent_short_versions= parse_lsl_distdir(distdir_listing) 
        
    try:
        log_struc= eval(loglinks_struct)
    except StandardError,e:
        print "input not parsable, error: %s" %e
        raise
    namedict= parse_log_by_name(log_struc)
    versiondict= parse_namedict_by_version(namedict)
    active_times= active_times_of_log_by_version(versiondict)
    lifetimes= lifetimes_in_days(active_times)
    activated_versions= get_activated_versions(namedict)
    remove_names= set()
    remove_versions= set()
    all_names= set(namedict.keys())
    all_versions= set(versiondict.keys())
    since_date= None

    if options.filter_inactive_since:
        try:
            since_date= datetime_of_isodate(options.filter_inactive_since)
        except ValueError,e:
            sys.exit("invalid date:%s" % options.filter_inactive_since)

    if options.idle:
        idles= filter_idle_version_names(all_versions,existent_short_versions)
        print_idle_versions(idles)
        return
        
    if options.filter_names:
        filternames= options.filter_names.split(",")
        remove_names.update( all_names.difference(filternames))
        versions_for_names= versions_of_log_by_name(namedict,filternames)
        remove_versions.update( all_versions.difference(versions_for_names))
    if options.filter_versions:
        wanted_versions= options.filter_versions.split(",")
        remove_versions.update( all_versions.difference(wanted_versions))
    if filter_existent or options.filter_nonexistent:
        existent_in_distdir= filter_existent_versions( 
                                      all_versions,
                                      existent_short_versions)
        if filter_existent:
            remove_versions.update( all_versions.difference(existent_in_distdir))
        else:
            remove_versions.update( existent_in_distdir)
    if options.filter_active:
        active= get_active_versions(active_times)
        remove_versions.update( all_versions.difference(active) )
    if options.filter_inactive or options.filter_inactive_since:
        active= get_active_versions(active_times,True,since_date)
        remove_versions.update( all_versions.difference(active) )
    if options.filter_lifetime_smaller:
        bigger= get_versions_from_lifetime(lifetimes,
                                           options.filter_lifetime_smaller)
        remove_versions.update(bigger)
    if options.filter_lifetime_bigger:
        bigger= get_versions_from_lifetime(lifetimes,
                                           options.filter_lifetime_bigger)
        remove_versions.update( all_versions.difference(bigger))
    if len(remove_names)>0:
        filter_by_names(remove_names,namedict,versiondict)
    if len(remove_versions)>0:
        filter_by_versions(remove_versions,namedict,versiondict,lifetimes)
    if options.names:
        print_log_by_name(namedict,activated_versions,options.brief,options.last) 
    elif options.versions:
        print_log_by_version(versiondict,options.brief)
    elif options.lifetimes:
        print_lifetimes(active_times,lifetimes,options.brief)
    else:
        print "error: one of -n, -v or -l must be specified"
        sys.exit(1)
    if options.fallback_info:
        print "\nget information on a versions (comma separated list) with:"
        print "rsync-linklog-stat.py -c %s --version-info [VERSIONS]" % \
              options.call
        print "\nperform a fallback with:"
        print "rsync-dist.pl -c %s change-links [VERSION],%s" % \
              (options.call, options.fallback_info)

def script_shortname():
    """return the name of this script without a path component."""
    return os.path.basename(sys.argv[0])

def print_doc():
    """print embedded reStructuredText documentation."""
    print __doc__

def print_summary():
    """print a short summary of the scripts function."""
    print "%-20s: a tool for processing the rsync-dist link log\n" % script_shortname()

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
    usage = "usage: %prog [options] {files}"

    parser = OptionParser(usage=usage,
                          version="%%prog %s" % my_version,
                          description="this program prints summaries and "
                                      "statistics of rsync-dist link-log files.")

    parser.add_option("--summary",  # implies dest="nodelete"
                      action="store_true", # default: None
                      help="print a summary of the function of the program",
                      )
    parser.add_option( "--doc",            # implies dest="switch"
                  action="store_true", # default: None
                  help="create online help in restructured text"
                       "format. Use \"./rsync-linklog-stat.py --doc | rst2html\" "
                       "to create html-help"
                  )

    parser.add_option("-t", "--test",     # implies dest="switch"
                      action="store_true", # default: None
                      help="perform simple self-test", 
                      )
    parser.add_option("-f", "--file", # implies dest="file"
                      action="store", # OptionParser's default
                      type="string",  # OptionParser's default
                      help="specify the FILE to process, if this option "+\
                           "is missing read from standard-in if the program "+\
                           "is used in pipe mode. Note that -c omits pipe mode.",
                      metavar="FILE"  # for help-generation text
                      )
    parser.add_option("-c", "--call", # implies dest="file"
                      action="store", # OptionParser's default
                      type="string",  # OptionParser's default
                      help="call rsync-dist.pl directly with CONFIGFILE",
                      metavar="CONFIGFILE"  # for help-generation text
                      )
    parser.add_option("-d", "--distdir",   # implies dest="switch"
                      action="store_true", # default: None
                      help="input contains also a listing of the distribution "+\
                           "directory at the start. " +\
                           "implied by --filter-existent and --filter-nonexistent.",
                      )
    parser.add_option("-n", "--names",   # implies dest="switch"
                      action="store_true", # default: None
                      help="print summary for each link-name",
                      )
    parser.add_option("-v", "--versions",   # implies dest="switch"
                      action="store_true", # default: None
                      help="print summary for each version",
                      )
    parser.add_option("-l", "--lifetimes",   # implies dest="switch"
                      action="store_true", # default: None
                      help="print lifetime summary for each version",
                      )
    parser.add_option("-i", "--idle",   # implies dest="switch"
                      action="store_true", # default: None
                      help="print idle versions, versions that are "+\
                           "not in use and never have been.",
                      )
    parser.add_option("--version-info",   # implies dest="switch"
                      action="store", # default: None
                      type="string",
                      help="show log information on VERSIONS."+\
                           "VERSIONS is a comma-separated "+\
                           "list of version strings.",
                      metavar="VERSIONS",
                      )
    parser.add_option("-b", "--brief",   # implies dest="switch"
                      action="store_true", # default: None
                      help="brief output, with -n just show link names,"+\
                           "with -v and -l just show version names"
                      )
    parser.add_option("--last",   # implies dest="switch"
                      action="store", # default: None
                      type="int",
                      help="print only the last NO versions for each name, "+\
                           "only for option -n.",
                      metavar="NO",
                      )
    parser.add_option("--filter-names",   # implies dest="switch"
                      action="store", # default: None
                      type="string",
                      help="show only information for links specified "+\
                           "by LINKNAMES, which may be a comma-separated "+\
                           "list of link names.",
                      metavar="LINKNAMES",
                      )
    parser.add_option("--filter-versions",   # implies dest="switch"
                      action="store", # default: None
                      type="string",
                      help="show only information for versions specified "+\
                           "by VERSIONS, which may be a comma-separated "+\
                           "list of versions.",
                      metavar="VERSIONS",
                      )
    parser.add_option("--filter-active",   # implies dest="switch"
                      action="store_true", # default: None
                      help="show only versions that are now in use",
                      )
    parser.add_option("--filter-inactive",   # implies dest="switch"
                      action="store_true", # default: None
                      help="show only versions that are not in use",
                      )
    parser.add_option("--filter-inactive-since",   # implies dest="switch"
                      action="store", # default: None
                      type="string",
                      help="filter versions inactive for longer than a given DATE",
                      metavar="DATE",
                      )
    parser.add_option("--filter-lifetime-smaller",   # implies dest="switch"
                      action="store", # default: None
                      type="float",
                      help="filter versions with a lifetime smaller than DAYS",
                      metavar="DAYS",
                      )
    parser.add_option("--filter-lifetime-bigger",   # implies dest="switch"
                      action="store", # default: None
                      type="float",
                      help="filter versions with a lifetime bigger than DAYS",
                      metavar="DAYS",
                      )
    parser.add_option("--filter-existent",   # implies dest="switch"
                      action="store_true", # default: None
                      help="show only version that are still existent in the "+\
                           "distribution directory. Note that in pipe-mode "+\
                           "you have call rsync-dist twice to get a listing of "+\
                           "the remote distribution directory. This option is "+\
                           "true when the program is not run in pipe-mode.",
                      )
    parser.add_option("--filter-nonexistent",   # implies dest="switch"
                      action="store_true", # default: None
                      help="show only version that are not existent in the "+\
                           "distribution directory. Note that in pipe-mode "+\
                           "you have call rsync-dist twice to get a listing of "+\
                           "the remote distribution directory.",
                      )
    parser.add_option("--filter-ignexistent",   # implies dest="switch"
                      action="store_true", # default: None
                      help="show versions no matter if they exist or not. "+\
                           "This can be used to override behaviour in non pipe mode.",
                      )
    parser.add_option("--fallback-info",   # implies dest="switch"
                      action="store", # default: None
                      type="string",
                      help="show recommended fallback versions for LINKNAME. "+\
                           "this corresponds to -n --filter-lifetime-bigger 2 "+\
                           "--last 3 --filter-names LINKNAME",
                      metavar="LINKNAME",
                      )

    x= sys.argv
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

    cmds= [options.names, options.versions, options.lifetimes, 
           options.idle, (options.version_info is not None)]
    vstr="--names,--versions,--lifetimes,--idle,--version-info"

    cmdno= Cnt(cmds)
    if cmdno==0:
	sys.exit("a command is missing, (%s)" % vstr)

    if cmdno>1:
	sys.exit("only one command (%s) is allowed at a time" % vstr)

    if options.version_info:
        version_info(options)
        sys.exit(0)

    # process_files(options,args)
    process_file(options.file,options)
    sys.exit(0)

if __name__ == "__main__":
    main()


