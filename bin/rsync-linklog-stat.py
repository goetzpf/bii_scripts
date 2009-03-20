#! /usr/bin/env python2.5
# -*- coding: UTF-8 -*-
"""
======================
 rsync-linklog-stat.py
======================
------------------------------------------------------------------------------
 a tool to analyse rsync-dist log-link files
------------------------------------------------------------------------------

Overview
===============
This tool can be used to analyse rsync-dist log-links files. A log-link
file is modified by rsync-dist.pl each time one or more links are changed.
Although the format of the log file contains all necessary information, it
is difficult to see which links point to which version or to see
what version are no longer in use.

Quick reference
===============

* show statistics on link names::

   rsync-linklog-stat.py -c rsync-dist.config -n

* show statistics on versions::

   rsync-linklog-stat.py -c rsync-dist.config -v

* show statistics on version liftimes::

   rsync-linklog-stat.py -c rsync-dist.config -l

Examples
========

The three examples above, rsync-linklog-stat calls rsync-dist itself,
it only needs to know where the rsync-dist config file is found.
If you want better control on the parameters rsync-dist is called with,
you can also use rsync-linklog-stat in pipe mode. Here are 
some further examples. 

In the first example we just want a statistic of the lifetimes of all
versions::

  rsync-dist.pl -c rsync-dist.config --single-host python-log l | rsync-linklog-stat.py -l

If we want to use one of the options --filter-existent or --filter-nonexistent, calling the
program with a pipe gets a bit more compilcated, since rsync-dist.pl has to be 
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
  The versions are printed as the directory paths as the were found
  in the rsync-dist link-log file.
  Here is an example::

    ioc1:
	 2009-03-19T11:40:16    /opt/IOC/r/dist/2009-03-19T11:38:54

    ioc2:
	 2009-03-19T11:41:16    /opt/IOC/r/dist/2009-03-19T11:38:12
	 2009-03-19T15:00:47    REMOVED

    ioc3:
	 2009-03-19T15:00:24    /opt/IOC/r/dist/2009-03-19T11:38:54

the *versions* format
  This format shows for each version at what time what symbolic links (names) pointed
  to this version. If a symbolic link was made to point to a different version
  at a certain date, the old version has a new entry with that timestamp with
  this symbolic link removed. If there are no symbolic links for a version,
  the list is empty. This shows that from this date on, the version is no longer 
  in use. Here is an example::

    /opt/IOC/r/dist/2009-03-19T11:38:12:
	 2009-03-19T11:41:16    ioc2
	 2009-03-19T15:00:47    

    /opt/IOC/r/dist/2009-03-19T11:38:54:
	 2009-03-19T11:40:16    ioc1
	 2009-03-19T15:00:24    ioc1 ioc3

the *lifetimes* format
  This format shows the timespan a version was in use, meaning the time 
  when at least one symbolic link pointed to that version. In this format
  the first and last date of usage are printed as well as the lifetime 
  in fractions of days. If the version is at this time still in use,
  the second date is "NOW".
  Here is an example::

    /opt/IOC/r/dist/2009-03-19T11:38:12:
	 2009-03-19T11:41:16    2009-03-19T15:00:47      0.14

    /opt/IOC/r/dist/2009-03-19T11:38:54:
	 2009-03-19T11:40:16    NOW                      0.97

the *orphans* format
  This format is used for the special -o or --orphan option. It is 
  just a list of the sub-directories in the distribution directory 
  are not and were never in use, meaning no symbolic link ever pointed 
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
  remote distribition directory as it is returned by rsync-dist.pl

-n, --names
  print summary for each link name

-v, --versions
  print summary for each version

-l, --lifetimes
  print lifetime summary for each version

-o, --orphan
  print orphan versions, versions that are not in 
  use and never have been.

-b, --brief
  brief output, with -n just show link names,
  with -v and -l just show version names

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
  
"""

from optparse import OptionParser
import subprocess
import os.path

import datetime
import sys

# version of the program:
my_version= "1.0"

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

def parse_iso_onlydate(str):
    """parse an ISO date without a time.

    This function parses an ISO date (without time) and returns 
    a datetime.datetime object. An ISO date 
    (at least here) has the form YYYY-MM-DD,
    an example is 2006-10-09.

    parameters:
    	str	-- the string to parse
    returns:
    	a datetime.datetime object

    Here are some examples:
    >>> parse_iso_onlydate("2006-10-09")
    datetime.datetime(2006, 10, 9, 0, 0)
    >>> parse_iso_onlydate("2007-11-09")
    datetime.datetime(2007, 11, 9, 0, 0)
    >>> parse_iso_onlydate("2007-11-09x")
    Traceback (most recent call last):
       ...
    ValueError: unconverted data remains: x
    """
    return datetime.datetime.strptime(str,"%Y-%m-%d")

def parse_iso_date(str):
    """parse an ISO date.

    This function parses an ISO date and returns 
    a datetime.datetime object. An ISO date 
    (at least here) has the form YYYY-MM-DDTHH:MM:SS,
    an example is 2006-10-09T10:33:09.

    parameters:
    	str	-- the string to parse
    returns:
    	a datetime.datetime object

    Here are some examples:
    >>> parse_iso_date("2006-10-09T10:33:09")
    datetime.datetime(2006, 10, 9, 10, 33, 9)
    >>> parse_iso_date("2006-10-09T10:33:09x")
    Traceback (most recent call last):
       ...
    ValueError: unconverted data remains: x
    >>> parse_iso_date("2006-99-09T10:33:09")
    Traceback (most recent call last):
       ...
    ValueError: time data did not match format:  data=2006-99-09T10:33:09  fmt=%Y-%m-%dT%H:%M:%S
    """
    return datetime.datetime.strptime(str,"%Y-%m-%dT%H:%M:%S")

def date_to_iso(d):
    """converts a date to ISO format.

    This function returns the datetime.datetime
    object as an ISO date string of the form
    YYYY-MM-DDTHH:MM:SS.

    parameters:
    	d	-- a datetime.datetime object
    returns:
    	a string.

    Here are some examples:
    >>> date_to_iso(datetime.datetime(2008, 10, 20, 11, 19, 30))
    '2008-10-20T11:19:30'
    """
    return d.strftime("%Y-%m-%dT%H:%M:%S")

def parse_lsl_iso_date(str):
    """parse an ISO-like date produced from ls -l.

    This function parses a date in the form
    YYYY-MM-DD HH:MM, which is a date that the "ls -l"
    command may produce. It returns a datetime.datetime object.

    parameters:
    	str	-- the string to parse
    returns:
    	a datetime.datetime object

    Here are some examples:
    >>> parse_lsl_iso_date("2009-03-16 10:26")
    datetime.datetime(2009, 3, 16, 10, 26)
    >>> parse_lsl_iso_date("2009-03-16  10:26")
    datetime.datetime(2009, 3, 16, 10, 26)
    >>> parse_lsl_iso_date("Oct  9 10:42")
    Traceback (most recent call last):
       ...
    ValueError: time data did not match format:  data=Oct  9 10:42  fmt=%Y-%m-%d %H:%M
    """
    return datetime.datetime.strptime(str,"%Y-%m-%d %H:%M")

def parse_lsl_yearless_date(str,year=None):
    """parse an yearless date produced from ls -l.

    This function parses a date in the form
    mmm d HH:MM (mmm the month name), which is a date that the "ls -l"
    command may produce. It returns a datetime.datetime object.
    Note that this function sets the year to 1900, if not 
    specified differently by it's second parameter.

    parameters:
    	str	-- the string to parse
	year	-- the optional year, an integer
    returns:
    	a datetime.datetime object

    Here are some examples:
    >>> parse_lsl_yearless_date("Oct  9 10:42")
    datetime.datetime(1900, 10, 9, 10, 42)
    >>> parse_lsl_yearless_date("Oct  9 10:42",2005)
    datetime.datetime(2005, 10, 9, 10, 42)
    >>> parse_lsl_yearless_date("Oct  9 10:42b",2005)
    Traceback (most recent call last):
       ...
    ValueError: unconverted data remains: b
    """
    d= datetime.datetime.strptime(str,"%b %d %H:%M")
    if year is not None:
	d= d.replace(year=year)
    return d

def parse_lsl_date_from_list(list,year=None):
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
    	list	-- the list of strings that is parsed
	year	-- the year that is used when the date string
		   contains no year (optional)

    returns:
    	(date,newlist) where <date> is a datetime.datetime object
	and <newlist> is the rest of the list with the parts belonging
	to the parsed date removed.

    Here are some examples:
    >>> parse_lsl_date_from_list("2009-03-16 14:46 idcp8 ->".split())
    (datetime.datetime(2009, 3, 16, 14, 46), ['idcp8', '->'])
    >>> parse_lsl_date_from_list("Oct  9 10:42 idcp13 ->".split())
    (datetime.datetime(1900, 10, 9, 10, 42), ['idcp13', '->'])
    >>> parse_lsl_date_from_list(" Oct  9 10:42 idcp13 ->".split())
    (datetime.datetime(1900, 10, 9, 10, 42), ['idcp13', '->'])
    >>> parse_lsl_date_from_list("nOct  9 10:42 idcp13 ->".split())
    Traceback (most recent call last):
       ...
    ValueError: no parsable date in list: ['nOct', '9', '10:42', 'idcp13', '->']
    """
    str= " ".join(list[0:2])
    try:
	d= parse_lsl_iso_date(str)
	return(d, list[2:])
    except ValueError,e:
    	pass
    str= " ".join(list[0:3])
    try:
	d= parse_lsl_yearless_date(str,year)
	return(d, list[3:])
    except ValueError,e:
	raise ValueError, "no parsable date in list: %s" % repr(list)

def token_subtract(str,no):
    """removes <no> tokens from a string and return the rest.

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
    """parses a line of the output of "ls -l".

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
    (timestamp,elms)= parse_lsl_date_from_list(elms)
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
    """
    p= str.find(sep)
    if p==-1:
	# separator not found
	raise ValueError,"separator '%s' not found in string" % sep
    return(str[0:p],str[p:])

def empty_str(str):
    """tests if a string is empty.

    Here are some examples:
    >>> empty_str("A")
    False
    >>> empty_str(" ")
    True
    >>> empty_str("")
    True
    """
    return str.strip()==""

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
	    continue
	name= result[-1]
	try:
	    d= parse_iso_date(name)
	except ValueError,e:
	    # ignore filenames that are not an ISO date
	    continue
	versions.add(name)
    return versions

def filter_existent_versions(version_paths, short_existing_version_names):
    """return all version_paths that are also in short_existing_version_names.

    Note that the parameter short_existing_version_names usually only
    contains the date-part of the version, but not the complete 
    path. version_paths however, contain version paths.

    Here is an example:
    >>> v=set(['/home/pfeiffer/r/dist/2009-03-19T11:38:12',
    ...   '/home/pfeiffer/r/dist/2009-03-19T11:38:54'])
    >>> e=set(['2009-03-19T11:38:12'])
    >>> filter_existent_versions(v,e)
    set(['/home/pfeiffer/r/dist/2009-03-19T11:38:12'])
    """
    result= set()
    for v in version_paths:
	last= os.path.split(v)[-1]
	if last in short_existing_version_names:
	    result.add(v)
    return result

def filter_orphan_version_names(version_paths, short_existing_version_names):
    """return all version_paths that are also in short_existing_version_names.

    Note that the parameter short_existing_version_names usually only
    contains the date-part of the version, but not the complete 
    path. version_paths however, contain version paths.

    Here is an example:
    >>> v=set(['/home/pfeiffer/r/dist/2009-03-19T11:38:12',
    ...   '/home/pfeiffer/r/dist/2009-03-19T11:38:54'])
    >>> e=set(['2009-03-19T11:38:12','2009-03-19T12:00:00'])
    >>> filter_orphan_version_names(v,e)
    set(['2009-03-19T12:00:00'])
    """
    result= set()
    for v in version_paths:
	last= os.path.split(v)[-1]
	if last in short_existing_version_names:
	    result.add(last)
    return short_existing_version_names.difference(result)

def print_orphaned_versions(myset):
    """print the list of orphaned versions.
    """
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
    	log	-- a list of dictionaries, each dictionary 
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
	 (datetime.datetime(2006, 10, 9, 16, 0, 54), '../dist/2006-10-09T10:28:13')
	 (datetime.datetime(2008, 10, 20, 11, 19, 30), '../dist/2008-10-16T12:42:03')
	 (datetime.datetime(2008, 10, 21, 12, 10), None)
    idcp9:
	 (datetime.datetime(2006, 10, 9, 16, 0, 54), '../dist/2006-10-09T10:28:13')
    """
    # a dict mapping names to a list of dates and versions
    versions= {}
    for entry in log:
	date= parse_iso_date(entry["DATE"])
	if entry.has_key("ADDED"):
	    # a dict mapping link names to versions
	    changed_versions= parse_lsl_symlink_lines(entry["ADDED"])
	elif entry.has_key("REMOVED"):
	    changed_versions= parse_lsl_symlink_lines(entry["REMOVED"])
	    # remove version from name-dict, since these
	    # names were deleted:
	    for n in changed_versions:
		changed_versions[n]= None
	else:
	    changed_versions= parse_lsl_symlink_lines(entry["NEW"])
	for n in changed_versions.keys():
	    d= versions.setdefault(n,[])
	    d.append((date,changed_versions[n]))
    return versions

def print_log_by_name(d,brief=False):
    """pretty-prints results by parse_log_by_name.

    Here is an example:
    >>> r={'idcp9': [(datetime.datetime(2006, 10, 9, 16, 0, 54), '../dist/2006-10-09T10:28:13')],
    ...    'idcp8': [(datetime.datetime(2006, 10, 9, 16, 0, 54), '../dist/2006-10-09T10:28:13'),
    ...              (datetime.datetime(2008, 10, 20, 11, 19, 30), '../dist/2008-10-16T12:42:03'),
    ...              (datetime.datetime(2008, 10, 21, 12, 10), None)]}
    >>> print_log_by_name(r)
    idcp8:
	 2006-10-09T16:00:54    ../dist/2006-10-09T10:28:13
	 2008-10-20T11:19:30    ../dist/2008-10-16T12:42:03
	 2008-10-21T12:10:00    REMOVED
    <BLANKLINE>
    idcp9:
	 2006-10-09T16:00:54    ../dist/2006-10-09T10:28:13
    """
    if brief:
	for n in sorted(d.keys()):
	    print n
	return
    LF=""
    for n in sorted(d.keys()):
        lst= d[n]
	print "%s%s:" % (LF,n)
	LF="\n"
	for elm in lst:
	    ver= elm[1]
	    if ver is None:
		ver= "REMOVED"
	    print "%24s    %s" % (date_to_iso(elm[0]),ver)

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
    	log	-- a dictionary that was created by
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
    >>> r={'../dist/2008-10-16T12:42:03': {datetime.datetime(2008, 10, 20, 11, 19, 30): set(['idcp8']),
    ...                                    datetime.datetime(2008, 10, 21, 12, 10): set([])},
    ...    '../dist/2006-10-09T10:28:13': {datetime.datetime(2006, 10, 9, 16, 0, 54): set(['idcp9', 'idcp8']), 
    ...                                    datetime.datetime(2008, 10, 20, 11, 19, 30): set(['idcp9'])}}
    >>> print_log_by_version(r)
    ../dist/2006-10-09T10:28:13:
	 2006-10-09T16:00:54    idcp8 idcp9
	 2008-10-20T11:19:30    idcp9
    <BLANKLINE>
    ../dist/2008-10-16T12:42:03:
	 2008-10-20T11:19:30    idcp8
	 2008-10-21T12:10:00    
    """
    if brief:
	for version in sorted(d.keys()):
	    print version
	return
    LF=""
    for version in sorted(d.keys()):
        version_dict= d[version]
	print "%s%s:" % (LF,version)
	LF="\n"
	for date in sorted(version_dict.keys()):
	    names= sorted(version_dict[date])
	    print "%24s    %s" % (date_to_iso(date),
	                          " ".join(names))
	                        
def lifetimes_of_log_by_version(d):
    """calculate lifetimes of a version.

    This function parses the dictionary returned by
    parse_namedict_by_version and returns
    a dictionary mapping versions to tuples,
    each tuple containing two dates. The first date is the 
    date the version was linked to, the second date is the
    date the version was last linked to. If the version is 
    still in use, the second date is None.
    
    The structure looks like this:

    { "version1" : (datetime1, datetime2),
      "version2" : (datetime3, None)
    }

    parameters:
    	d	-- a dictionary that was created by
	           parse_namedict_by_version
    returns:
    	a dictionary mapping versions to tuples of two dates.

    Here are some examples:
    >>> r={'../dist/2008-10-16T12:42:03': {datetime.datetime(2008, 10, 20, 11, 19, 30): set(['idcp8']),
    ...                                    datetime.datetime(2008, 10, 21, 12, 10): set([])},
    ...    '../dist/2006-10-09T10:28:13': {datetime.datetime(2006, 10, 9, 16, 0, 54): set(['idcp9', 'idcp8']), 
    ...                                    datetime.datetime(2008, 10, 20, 11, 19, 30): set(['idcp9'])}}
    >>> l=lifetimes_of_log_by_version(r)
    >>> for v in sorted(l.keys()):
    ...   print "%s:" % v
    ...   print "    from %s  to %s " % (l[v])
    ... 
    ../dist/2006-10-09T10:28:13:
	from 2006-10-09 16:00:54  to None 
    ../dist/2008-10-16T12:42:03:
	from 2008-10-20 11:19:30  to 2008-10-21 12:10:00 
    """
    lifetimes={}
    for version in sorted(d.keys()):
        version_dict= d[version]
	date1= None
	date2= None
	dates= sorted(version_dict.keys())
	date1= dates[0]
	last_number_of_names= len(version_dict[dates[-1]])
	if last_number_of_names==0:
	    date2= dates[-1]
	else:
	    date2= None
	lifetimes[version]= (date1,date2)
    return lifetimes
    
def get_versions_from_lifetime(d,lifetime):
    """calculate a list of version with a lifetime bigger or equal than a given value.

    parameters:
    	d	 -- a dictionary returned by lifetimes_of_log_by_version
	lifetime -- the minimum lifetime in days

    Here is an example:
    >>> l={'../dist/2008-10-16T12:42:03': (datetime.datetime(2008, 10, 20, 11, 19, 30), 
    ...                                    datetime.datetime(2008, 10, 20, 13, 10)),
    ...    '../dist/2006-10-09T10:28:13': (datetime.datetime(2006, 10, 9, 16, 0, 54), None)}
    >>> get_versions_from_lifetime(l,1)
    set(['../dist/2006-10-09T10:28:13'])
    >>> get_versions_from_lifetime(l,0.1)
    set(['../dist/2006-10-09T10:28:13'])
    >>> get_versions_from_lifetime(l,00.1)
    set(['../dist/2006-10-09T10:28:13'])
    >>> get_versions_from_lifetime(l,0.01)
    set(['../dist/2008-10-16T12:42:03', '../dist/2006-10-09T10:28:13'])
    """
    today= datetime.datetime.today()
    active= set()
    for version in d:
	(date1,date2)= d[version]
	if date2 is None:
	    date2= today
	delta= date2-date1
	if delta.days+delta.seconds/86400.0>=lifetime:
	    active.add(version)
    return active

def get_active_versions(d,invert=False,since=None):
    """calculate a list of versions still in use.

    parameters:
    	d	-- a dictionary returned by lifetimes_of_log_by_version
	invert  -- invert function, return inactive versions instead
	           of active versions
	since   -- an optional date, only used when invert is True
    returns:
	a set of versions still active

    Here is an example:
    >>> l={'../dist/2008-10-16T12:42:03': (datetime.datetime(2008, 10, 20, 11, 19, 30), 
    ...                                    datetime.datetime(2008, 10, 20, 13, 10)),
    ...    '../dist/2006-10-09T10:28:13': (datetime.datetime(2006, 10, 9, 16, 0, 54), None)}
    >>> get_active_versions(l)
    set(['../dist/2006-10-09T10:28:13'])
    """
    active= set()
    if not invert:
	for version in d:
	    if d[version][1] is None:
		active.add(version)
    else:
	for version in d:
	    if d[version][1] is not None:
		if since is not None:
		    if since<d[version][1]:
			continue
		active.add(version)
    return active
    
def filter_by_versions(rem_versions,namedict,versiondict,lifetimes):
    """remove all versions that are in the list.
    """
    for v in rem_versions:
	del versiondict[v]
	del lifetimes[v]
	for (name,entries) in namedict.items():
	    namedict[name]= filter(lambda x:x[1] not in rem_versions, entries)

def print_lifetimes(l,brief=False):
    """pretty-print lifetimes of versions.
    """
    if brief:
	for version in sorted(l.keys()):
	    print version
	return
    today= datetime.datetime.today()
    LF=""
    for version in sorted(l.keys()):
	(date1,date2)= l[version]
	datestr1= date_to_iso(date1)
	if date2 is None:
	    datestr2= "NOW"
	    delta= today-date1
	else:
	    datestr2= date_to_iso(date2)
	    delta= date2-date1
	print "%s%s:" % (LF,version)
	LF="\n"
	print "%24s    %-20s    %5.2f" % (datestr1,datestr2,
				          delta.days+delta.seconds/86400.0)

def process_file(f,options):
    """process a single file.
    """
    distdir_info= (options.distdir or options.filter_existent or
                   options.filter_nonexistent or options.orphan)
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
    lifetimes= lifetimes_of_log_by_version(versiondict)
    remove_versions= set()
    all_versions= set(versiondict.keys())
    since_date= None

    if options.filter_inactive_since:
	try:
	    since_date= parse_iso_onlydate(options.filter_inactive_since)
	except ValueError,e:
	    sys.exit("invalid date:%s" % options.filter_inactive_since)

    if options.orphan:
	orphans= filter_orphan_version_names(all_versions,existent_short_versions)
	print_orphaned_versions(orphans)
	return
	
    if options.filter_existent or options.filter_nonexistent:
	existent_in_distdir= filter_existent_versions( 
	                              all_versions,
	                              existent_short_versions)
	if options.filter_existent:
	    remove_versions.update( all_versions.difference(existent_in_distdir))
	else:
	    remove_versions.update( existent_in_distdir)
    if options.filter_active:
        active= get_active_versions(lifetimes)
	remove_versions.update( all_versions.difference(active) )
    if options.filter_inactive or options.filter_inactive_since:
        active= get_active_versions(lifetimes,True,since_date)
	remove_versions.update( all_versions.difference(active) )
    if options.filter_lifetime_smaller:
        bigger= get_versions_from_lifetime(lifetimes,
					options.filter_lifetime_smaller)
	remove_versions.update(bigger)
    if options.filter_lifetime_bigger:
        bigger= get_versions_from_lifetime(lifetimes,
					options.filter_lifetime_bigger)
	remove_versions.update( all_versions.difference(bigger))
    if len(remove_versions)>0:
	filter_by_versions(remove_versions,namedict,versiondict,lifetimes)
    if options.names:
	print_log_by_name(namedict,options.brief)
    elif options.versions:
	print_log_by_version(versiondict,options.brief)
    elif options.lifetimes:
	print_lifetimes(lifetimes,options.brief)
    else:
	print "error: one of -n, -v or -l must be specified"
	sys.exit(1)

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
    parser.add_option("-o", "--orphan",   # implies dest="switch"
                      action="store_true", # default: None
                      help="print orphan versions, versions that are "+\
		           "not in use and never have been.",
                      )
    parser.add_option("-b", "--brief",   # implies dest="switch"
                      action="store_true", # default: None
                      help="brief output, with -n just show link names,"+\
		           "with -v and -l just show version names"
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
			   "the remote distribution directory.",
                      )
    parser.add_option("--filter-nonexistent",   # implies dest="switch"
                      action="store_true", # default: None
                      help="show only version that are not existent in the "+\
		           "distribution directory. Note that in pipe-mode "+\
			   "you have call rsync-dist twice to get a listing of "+\
			   "the remote distribution directory.",
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

    # process_files(options,args)
    process_file(options.file,options)
    sys.exit(0)

if __name__ == "__main__":
    main()


