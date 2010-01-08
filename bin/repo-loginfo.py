#!/usr/bin/env python
# -*- coding: UTF-8 -*-

#  This software is copyrighted by the
#  Helmholtz-Zentrum Berlin fuer Materialien und Energie GmbH (HZB),
#  Berlin, Germany.
#  The following terms apply to all files associated with the software.
#  
#  HZB hereby grants permission to use, copy and modify this
#  software and its documentation for non-commercial, educational or
#  research purposes provided that existing copyright notices are
#  retained in all copies.
#  
#  The receiver of the software provides HZB with all enhancements, 
#  including complete translations, made by the receiver.
#  
#  IN NO EVENT SHALL HZB BE LIABLE TO ANY PARTY FOR DIRECT, INDIRECT,
#  SPECIAL, INCIDENTAL OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE
#  OF THIS SOFTWARE, ITS DOCUMENTATION OR ANY DERIVATIVES THEREOF, EVEN 
#  IF HZB HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#  
#  HZB SPECIFICALLY DISCLAIMS ANY WARRANTIES, INCLUDING, BUT NOT LIMITED
#  TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
#  PURPOSE, AND NON-INFRINGEMENT. THIS SOFTWARE IS PROVIDED ON AN "AS IS"
#  BASIS, AND HZB HAS NO OBLIGATION TO PROVIDE MAINTENANCE, SUPPORT,
#  UPDATES, ENHANCEMENTS OR MODIFICATIONS.

"""
======================
 repo-loginfo.py
======================
------------------------------------------------------------------------------
 a tool print logging information of darcs and mercurial repositories
------------------------------------------------------------------------------

Overview 
===============

This tool can be used to print a summary of the logging information 
of several repositories. This gives with respect to software repository
activity a good overview on what tasks were done over a given timespan.

Here are some key terms used in this manual:

repository
  this is the software repository that holds the current and all the previous
  versions of an application's source. 

version control system
  this is the software that is used to manage the software repository. At this
  time this script supports two version control systems, darcs and mercurial.
  Both are decentralized version control systems where a working copy usually contains
  the complete history of all previous version by maintaining a repository of it's own.

changeset
  this is the smallest entity the version control system can manage. A changeset
  is a set of changes in one or several source files that is filed in the version
  control system together with a log message, the name of the author and a date.

log message
  this is the message that is filed together with a changeset. It consists of one 
  or several lines of text where the first line is taken as a heading, giving a
  short description of the changeset. This tool currently only prints the
  first line of the log message.

author
  this is the name of the author of the changeset. Since the author name is sometimes
  a mail address, sometimes a full name and sometimes the name of an unix account,
  the specification of the author is a regular expression matching all the different
  names of the author.

date
  this is the date and time of the filing of the changeset. It's accuracy is a single 
  second.

Quick reference
===============

* show logs of a given darcs repository for the current year::

    repo-loginfo.py --darcs --newer [year]-01-01 --dir [repository-directory]

* the same but with number of deleted and added lines::

    repo-loginfo.py --darcs --newer [year]-01-01 --changes --dir [repository-directory]

* the same but show only a single user::

    repo-loginfo.py --darcs --newer [year]-01-01 --changes --author [author] --dir [repository-directory]

Note that the author is a regular expression, so you can specify something like "[Ss]mith" in
order to catch all of "Smith", "smith", "smith@somecompany.com".

Command Examples
=================================

The following examples can be executed on host aragon.acc.bessy.de.

all changes from last year
--------------------------

This command queries the MultiCAN repository and shows all changes of 2009::

  repo-loginfo.py --newer 2009-01-01 --darcs --dir /opt/repositories/controls/darcs/epics/support/mcan/base-3-14

These are some lines from the output of this command::

  2009-04-27 11:52 benjamin.franksen@bessy.de          upgraded module soft to version R2-5 (which no longer contains cvtRecordApp)
  2009-04-27 11:53 benjamin.franksen@bessy.de          TAG R2-3-9
  2009-05-11 11:03 benjamin.franksen@bessy.de          re-enable CI_LOST_IRQ_FIX (in vcan driver)

all changes from last year with deleted and added lines
-------------------------------------------------------

This command queries the BII-Controls repository and shows all changes from 2009 
with the number of changed lines::

  repo-loginfo.py --newer 2009-01-01 --darcs --changes --dir /opt/repositories/controls/darcs/epics/ioc/BII-Controls/base-3-14

These are some lines from the output of this command::

  2009-01-06 11:29 Bernhard.Kuner@bessy.de                -3     3 Update: remove GPNIs from all panels, Fix: remove debug output (VacuumApp)
  2009-01-07 11:47 Thomas.Birke@bessy.de                -317    19 fixed vacuum sub-panels for W7* (WLS7App, HMIApp)
  2009-01-07 18:47 Thomas.Birke@bessy.de                  -4     7 cleaned up command-bit handling - esp. for kicker/septa (PowerSupApp)
  2009-01-08 13:30 Bernhard.Kuner@bessy.de                -1    71 Add laserMotorServicePanel.mfp (MotorApp)


all changes since a given date for a single user
------------------------------------------------

Query the MultiCAN repository, show all changes of 2007 made by user "pfeiffer"::

  repo-loginfo.py --newer 2007-01-01 --older 2008-01-01 --author '[Pp]feiffer' --darcs --dir /opt/repositories/controls/darcs/epics/support/mcan/base-3-13

These are some lines from the output of this command::

  2007-01-18 15:54 pfeiffer@mail.bessy.de              TAG R1-17-1
  2007-02-06 12:08 Goetz.Pfeiffer@bessy.de             The inline documentation had to be changed: the
  2007-10-09 11:58 Goetz.Pfeiffer,15.8.204,6392-4862,@bessy.de support for VCAN2 and VCAN4 was slightly improved

all changes for a given year for a single user without user name, with deleted and added lines
------------------------------------------------------------------------------------------------

Query the MultiCAN repository, show all changes of 2007 made by user "pfeiffer" without printing the author and
with changed lines::

  repo-loginfo.py --newer 2007-01-01 --older 2008-01-01 --author '[Pp]feiffer' --no-author --changes --darcs --dir /opt/repositories/controls/darcs/epics/support/mcan/base-3-13

These are some lines from the output of this command::

  2007-01-18 14:45    -2    24 time stamps of monitored objects are now printed too
  2007-01-18 15:17    -2     4 a simple type error was corrected
  2007-01-18 15:54     0     0 TAG R1-17-1
  2007-02-06 12:08   -25    21 The inline documentation had to be changed: the

all changes since a given date for two repositories
---------------------------------------------------

Query both MultiCAN repositories, base-3-13 and base-3-14 and show all changes of 2007::

  repo-loginfo.py --newer 2007-01-01 --older 2008-01-01 --repos 'MCAN-3.13:/opt/repositories/controls/darcs/epics/support/mcan/base-3-13:darcs,MCAN-3.14:/opt/repositories/controls/darcs/epics/support/mcan/base-3-14:darcs'

These are some lines from the output of this command::

  2007-01-10 14:48 benjamin.franksen@bessy.de          MCAN-3.14    beautified info messages (mCANSupport)
  2007-01-12 15:03 benjamin.franksen@bessy.de          MCAN-3.14    TAG R2-0
  2007-01-18 14:45 pfeiffer@mail.bessy.de              MCAN-3.13    time stamps of monitored objects are now printed too
  2007-02-06 14:35 Goetz.Pfeiffer@bessy.de             MCAN-3.13    TAG R1-17-2
  2007-10-09 12:08 Bernhard.Kuner@bessy.de             MCAN-3.13    Add vtest.o to MultiCAN library in base3-13

all changes for a given year for two repositories with specification file
-------------------------------------------------------------------------

Query both MultiCAN repositories, base-3-13 and base-3-14 and show all changes of 2007 but this time
using a REPOSPECIFICATIONFILE::

  echo "MCAN-3.13 /opt/repositories/controls/darcs/epics/support/mcan/base-3-13 darcs" >  /tmp/REPOSPEC
  echo "MCAN-3.14 /opt/repositories/controls/darcs/epics/support/mcan/base-3-14 darcs" >> /tmp/REPOSPEC
  repo-loginfo.py --newer 2007-01-01 --older 2008-01-01 --repos-file /tmp/REPOSPEC

This is the content of the REPOSPEC file::

  MCAN-3.13 /opt/repositories/controls/darcs/epics/support/mcan/base-3-13 darcs
  MCAN-3.14 /opt/repositories/controls/darcs/epics/support/mcan/base-3-14 darcs

And these are some lines from the output of this command::

  2007-01-12 15:03 benjamin.franksen@bessy.de          MCAN-3.14    TAG R2-0
  2007-01-18 14:45 pfeiffer@mail.bessy.de              MCAN-3.13    time stamps of monitored objects are now printed too
  2007-01-18 15:17 pfeiffer@mail.bessy.de              MCAN-3.13    a simple type error was corrected
  2007-11-26 09:51 Ralf Hartmann <Ralf.Hartmann@bessy.de> MCAN-3.14    TAG R2-2-1


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
  Use "./repo-loginfo.py --doc | rst2html" to create html-help"

--dry-run
  in this case the program doesn't do anything but only shows
  which directories it would examine and what version control 
  commands it would call.

--darcs
  specify that the repository is a darcs repository.

--hg
  specify that the repository is a mercurial repository.

--changes
  additionally display the number of removed and added lines
  in the patch. This simply counts the "-" and "+" characters 
  at the start of lines when the changesets are printed in the
  unified diff format.

--no-author
  do not print the author, this is useful when you have filtered
  all changeset from an author and do not want to have this author's 
  name printed over and over again.

--fetch-all
  when this option is given, the filtering of dates is done
  by this script, not by the version control system. The processing
  of the output takes longer this way, but it may be that some 
  date specifications can be given more precise this way.

--dir DIRECTORY
  specify the directory where the repository can be found.

--reponame REPONAME
  specify a name for the repository. This is just a short name that
  is printed along the log information. This option is useful if
  you collect log information of several repositories and want to
  collect them in a single file.

--newer DATESPEC
  print only changes at or after the given date.

--older DATESPEC
  print only changes at or before the given date.

--repos REPOSPECIFICATION
  this option can be used to specify more than one repository. The 
  changes for all given repositories are collected and printed, sorted
  by their date. The REPOSPECIFICATION consists of parts that are separated
  by commas, each part consists of a repository name, a directory, and
  a version control type, each specified by a colon. See also
  the section "Examples" for an example on this option.

--repos-file REPOSPECIFICATIONFILE
  this option can also be used to specify more than one repository. In this
  case the specifications of the repositories are in the given file. 
  Each line has (in this order and separated by spaces) the repository name,
  the directory of the repository and the version control type. See also
  the section "Examples" for an example on this option.
"""

import sys
import os
import time
import re
import datetime
import StringIO

import subprocess
from optparse import OptionParser

import xml.etree.ElementTree as ET

import dateutils

# version of the program:
my_version= "1.0"

# ---------------------------------------------------------
# logging classes
# ---------------------------------------------------------

class SingleLog(object):
    """hold a single log entry."""
    def __init__(self, date, author, name, 
                 reponame= None, deleted_lines=None, added_lines=None):
        self.date= date
        self.name= name
        self.author= author
        self.reponame= reponame
        self.deleted= deleted_lines
        self.added= added_lines
    def __repr__(self):
        return "SingleLog(%s, %s, %s, %s, %d, %d)" % \
                (repr(self.date), repr(self.author), repr(self.name),
                 repr(self.reponame),
                 repr(self.deleted_lines), repr(self.added_lines))
    def to_string(self, no_author= False):
        st= "%18s" % dateutils.isolsl(self.date)
        if not no_author:
            st= "%s %-35s" % (st, self.author)
        if self.reponame is not None:
            st= "%s %-12s" % (st, self.reponame) 
        if self.deleted is not None:
            st= "%s %5d %5d" % (st, -self.deleted, self.added)
        return "%s %s" % (st, self.name)
    def __str__(self):
        return to_string(self)

class Logs(object):
    """hold VCS logging data in a unified way."""
    def __init__(self):
        """doesn't do anything here."""
        self._dict= {}
    def add_other(self, other):
        """add another Logs object.
        
        keep entries that are already stored in the
        dict under the same key
        """
        new= other._dict.copy()
        new.update(self._dict)
        self._dict= new
    def add(self, log_obj):
        """add a log entry."""
        # by using date+name as a dictionary key, we
        # eliminate duplicate entries coming from different
        # repositories that are branches of the same repository
        # at some time in the past.
        # we do not take the new log data if we already have an
        # entry with the same date and log message:
        if self._dict.has_key((log_obj.date, log_obj.name)):
            return
        self._dict[(log_obj.date, log_obj.name)]= log_obj
    def filter_author(self, author_rx_str):
        """remove authors that do not match a regular expression."""
        rx_author= re.compile(author_rx_str)
        new= Logs()
        for (k,v) in self._dict.items():
            if rx_author.search(v.author) is not None:
                new.add(v)
        return new
    def filter_newer(self, date):
        """keep only logs newer than date."""
        new= Logs()
        for (k,v) in self._dict.items():
            (key_date,key_name)= k
            if key_date>=date:
                new.add(v)
        return new
    def filter_older(self, date):
        """keep only logs older than date."""
        new= Logs()
        for (k,v) in self._dict.items():
            (key_date,key_name)= k
            if key_date<=date:
                new.add(v)
        return new
    def to_string(self, suppress_author=False):
        """print a human readable representation."""
        lines= [self._dict[d].to_string(suppress_author)
                for d in sorted(self._dict.keys())]
        lines.append("")
        return "\n".join(lines)
    def __str__(self):
        return to_string(self)

# ---------------------------------------------------------
# system call
# ---------------------------------------------------------

def _system(cmd, catch_stdout=True, dry_run=False):
    """execute a command.

    execute a command and return the programs output
    may raise:
    IOError(errcode,stderr)
    OSError(errno,strerr)
    ValueError
    """
    if dry_run:
        print cmd
        return None
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

def my_chdir(newdir=None, dry_run=False):
    """change directory, return the old directory."""
    if newdir is None:
        return None
    olddir= os.getcwd()
    if not dry_run:
        os.chdir(newdir)
    else:
        print "cd %s" % newdir
    return olddir

# ---------------------------------------------------------
# parse diff output
# ---------------------------------------------------------

# ---------------------------------------------------------
# date utilities
# ---------------------------------------------------------

def parse_date(st):
    """try different methods to parse a date."""
    try:
        return dateutils.parse_isodatetime(st)
    except ValueError,e:
        pass
    try:
        return dateutils.parse_isodate(st)
    except ValueError,e:
        pass
    try:
        return dateutils.parse_lsl_isodate(st)
    except ValueError,e:
        raise

mytimezone= time.timezone

def shortiso_to_datetime(st):
    """converts something like 20091119214912 to a datetime object."""
    return datetime.datetime.strptime(st,"%Y%m%d%H%M%S")

def utc_datetime_to_local(d):
    """converts a UTC datetime to a localized datetime."""
    return d-datetime.timedelta(seconds=mytimezone)

# ---------------------------------------------------------
# parse darcs
# ---------------------------------------------------------

def SingleLogFromDarcsEntry(e, reponame= None, counter_dict={}):
    """convert a patch xml.etree.ElementTree element to a SingleLog object.
    """
    # entry.tag: "patch"
    # items here: 
    # 'date' : '20091119214912'
    # 'local_date' : 'Thu Nov 19 22:49:12 CET 2009'
    # 'inverted' : 'False'
    # 'hash' : '20091119214912-d224c-deb67ffb6e17c9c77d8ee2f7d4c79a4f5cfe961c.gz'
    # 'author' : 'benjamin.franksen@bessy.de'
    # Children:
    # <name>make installation of pydoc generated html files optional</name>
    #   
    # <comment>Ignore-this: 1454c8dea2f22a1ff889972d1811ddce
    # 
    # This makes it possible to complete installation even if pydoc generation
    # fails for some of the libraries. Note that pydoc needs all dependent python
    # libraries to be installed which may not be the case everywhere.</comment>
    def get_subelement(elm, tag):
        lst= [x for x in e.getiterator(tag=tag)]
        #print lst
        if len(lst)!=1:
            raise AssertionError, "XML data cannot be parsed"
        return lst[0]
    mydate= utc_datetime_to_local(shortiso_to_datetime(e.get("date")))
    author= e.get("author")
    name_elm= get_subelement(e, "name")
    name= name_elm.text
    (removed, added)= (None,None)
    if len(counter_dict)>0:
        localdate= e.get("local_date")
        counters= counter_dict.get("%s  %s" % (localdate, author))
        if counters is not None:
            (removed, added)= counters
        else:
            raise AssertionError, "no diff data for patch \"%s  %s\"" % \
                  (localdate, author)
    return SingleLog(mydate, author, name, reponame, removed, added)

def LogsFromDarcsElmtree(tree, reponame= None, counter_dict={}):
    """convert a xml.etree.ElementTree tree to a list of tuples."""
    logdata= Logs()
    root= tree.getroot()
    for e in root.getchildren():
        logdata.add(SingleLogFromDarcsEntry(e, reponame, counter_dict))
    return logdata

def process_darcs_diff(data):
    """process darcs changes -v
    """
    mydict= {}
    counters= None
    for line in data.splitlines():
        if len(line)==0:
            continue
        if line.isspace():
            continue
        if (not line[0].isspace()) and (line[0]!="*"):
            counters= [0,0]
            mydict[line]= counters
            continue
        line= line.strip()
        if line[0]=="+":
            counters[1]+=1
            continue
        if line[0]=="-":
            counters[0]+=1
    return mydict
         
def GetDarcsLogs(directory=None, reponame= None, count_changes= False,
                 from_date= None, to_date= None, dry_run=False):
    """convert a darcs log to a tuple list.
    
    parameters:
        directory  -- the start directory.
    """
    def tomorrow():
        return datetime.datetime.today()+datetime.timedelta(days=1)
    olddir= my_chdir(directory, dry_run)

    cmd_add= ""
    if (from_date is not None) or (to_date is not None):
        if (from_date is None):
            from_date= "2000-01-01"
        if (to_date is None):
            to_date= tomorrow().strftime("%Y-%m-%d")
        cmd_add= " --match \"date %s/%s\"" % (from_date, to_date)
    counter_dict= {}
    if count_changes:
        diff_data= _system("darcs changes -v" + cmd_add, True, dry_run)
        if not dry_run:
            counter_dict= process_darcs_diff(diff_data)
    cmd= "darcs changes --xml-output" + cmd_add
    data= _system(cmd, True, dry_run)
    my_chdir(olddir, dry_run)
    if dry_run:
        return None
    fh= StringIO.StringIO(data)
    tree= ET.parse(fh)
    return LogsFromDarcsElmtree(tree, reponame, counter_dict)

# ---------------------------------------------------------
# parse mercurial (hg)
# ---------------------------------------------------------

rx_hg_logline= re.compile(r'^(\d{4}-\d{2}-\d{2} \d{2}:\d{2})[ \d+-]*%%(.*)%%(.*)$')

def diffcount(counters, st):
    """count + and - at line starts.
    """
    if len(st)==0:
        return counters
    if len(st)>1:
        b= st[1]
    else:
        b= ""
    a= st[0]
    if (a=="+") and (b!="+"):
        counters[1]+=1
    elif (a=="-") and (b!="-"):
        counters[0]+=1

def parse_hg_logline(st):
    """parse hg log information."""
    m= rx_hg_logline.match(st)
    if m is None:
        return None
    return m.groups()

def LogsFromHgFile(fh, reponame= None, count_changes= False):
    """create a Logs object."""
    def NewSingleLog(parsed, reponame, counters):
        if counters is None:
            return SingleLog( dateutils.parse_lsl_isodate(parsed[0]), 
                              parsed[1], parsed[2], reponame)
        else:
            return SingleLog( dateutils.parse_lsl_isodate(parsed[0]), 
                              parsed[1], parsed[2], reponame,
                              counters[0], counters[1])
    logdata= Logs()
    old_parsed= None
    counters= None
    for line in fh:
        #print "LINE:",line
        parsed= parse_hg_logline(line)
        if parsed is not None:
            if old_parsed is not None:
                logdata.add(NewSingleLog(old_parsed, reponame, counters))
            old_parsed= parsed
            if count_changes:
                counters= [0,0]
        else:
            if not count_changes:
                raise AssertionError, "parse error"
            diffcount(counters, line)
    if old_parsed is not None:
        logdata.add(NewSingleLog(old_parsed, reponame, counters))
    return logdata

def GetHgLogs(directory=None, reponame= None, count_changes= False, 
              from_date=None, to_date=None, dry_run=False):
    """convert a mercurial log.
    
    parameters:
        directory  -- the start directory.
    """
    olddir= my_chdir(directory, dry_run)
    hg_cmd= "hg log --template '{date|isodate}%%{author}%%{desc|firstline}\\n'"
    if (from_date is not None) or (to_date is not None):
        if (from_date is not None) and (to_date is not None):
            hg_cmd+= " --date \"%s to %s\"" % (from_date, to_date)
        elif from_date is not None:
            hg_cmd+= " --date \">%s\"" % from_date
        elif to_date is not None:
            hg_cmd+= " --date \"<%s\"" % to_date
        else:
            raise AssertionError, "shouldn't happen"
    if count_changes:
        hg_cmd+= " -p"
    #print hg_cmd
    data= _system(hg_cmd, True, dry_run)
    my_chdir(olddir, dry_run)
    if dry_run:
        return None
    fh= StringIO.StringIO(data)
    return LogsFromHgFile(fh, reponame, count_changes)

# ---------------------------------------------------------
# generic program part
# ---------------------------------------------------------

# for debugging only:
class bag(object):
    def __init__(self, **kwargs):
        for (k,v) in kwargs.items():
            setattr(self, k, v)

# from repo_loginfo import *
# options= bag(dir="/home/pfeiffer/net/project/bii_scripts", darcs=True, changes=True, no_author=True)
# import pdb
# pdb.run("process(options,[])")
# b process_darcs_diff
# c

def process_one(options, dir, reponame, vcs_type):
    """process a single repository.
    """
    (from_date,to_date)=(None,None)
    if not options.fetch_all:
        (from_date,to_date)= (options.newer,options.older)
    if vcs_type=="darcs":
        logs= GetDarcsLogs(dir, reponame, 
                           options.changes, from_date, to_date, options.dry_run)
    elif vcs_type=="hg":
        logs= GetHgLogs(dir, reponame, 
                        options.changes, from_date, to_date, options.dry_run)
    else:
        sys.exit("darcs or hg must be specified")
    if options.dry_run:
        return None
    if options.author is not None:
        logs= logs.filter_author(options.author)
    if options.fetch_all:
        if options.newer is not None:
            d= parse_date(options.newer)
            logs= logs.filter_newer(d)
        if options.older is not None:
            d= parse_date(options.older)
            logs= logs.filter_older(d)
    return logs

def repospec_check(source, partlist):
    """check parts of a repo specification."""
    if len(partlist)!=3:
        sys.exit("wrong specification: \"%s\"" % source)
        (reponame,dir,vcs_type)= partlist
        if (vcs_type!="darcs") and (vcs_type!="hg"):
            sys.exit("wrong repo type: \"%s\"" % vcs_type)

def get_arg_repospec(st):
    """get repo specification from a command line argument."""
    specs=[]
    for part in st.split(","):
        subparts= part.split(":")
        repospec_check(part, subparts)
        specs.append(subparts)
    return specs

def get_file_repospec(filename):
    """get repository specification from a file."""
    specs=[]
    fh= open(filename, "r")
    for line in fh:
        if line=="":
            continue
        if line.isspace():
            continue
        line= line.strip()
        if line[0]=="#":
            continue
        subparts= line.split()
        repospec_check(line, subparts)
        specs.append(subparts)
    fh.close()
    return specs

def process(options, args):
    """process command line options.
    """
    specs= None
    if options.repos is not None:
        specs= get_arg_repospec(options.repos)
    elif options.repos_file is not None:
        specs= get_file_repospec(options.repos_file)
    if specs is None:
        if options.darcs:
            vcs_type="darcs"
        elif options.hg:
            vcs_type="hg"
        else:
            sys.exit("either --darcs or --hg must be given")
        logs= process_one(options, options.dir, options.reponame, vcs_type)
    else:
        logs= Logs()
        for (reponame, dir, vcs_type) in specs:
            part_logs= process_one(options, dir, reponame, vcs_type)
            if not options.dry_run:
                logs.add_other(part_logs)
    if not options.dry_run:
        print logs.to_string(options.no_author)

def script_shortname():
    """return the name of this script without a path component."""
    return os.path.basename(sys.argv[0])

def print_doc():
    """print embedded reStructuredText documentation."""
    print __doc__

def print_summary():
    """print a short summary of the scripts function."""
    print "%-20s: print log summaries for darcs or mercurial\n" % script_shortname()

def main():
    """The main function.

    parse the command-line options and perform the command
    """
    # command-line options and command-line help:
    usage = "usage: %prog [options] {files}"

    parser = OptionParser(usage=usage,
                          version="%%prog %s" % my_version,
                          description="this program removes tabs and "
                                      "trailing spaces in files.")

    parser.add_option("--summary",  # implies dest="nodelete"
                      action="store_true", # default: None
                      help="print a summary of the function of the program",
                      )
    parser.add_option( "--doc",            # implies dest="switch"
                  action="store_true", # default: None
                  help=("create online help in restructured text"
                        "format. Use \"./%s --doc | rst2html\" "
                        "to create html-help") % script_shortname(),
                  )
    parser.add_option("--dry-run",   # implies dest="switch"
                      action="store_true", # default: None
                      help="just show what the program would do",
                      )
    parser.add_option("--darcs",   # implies dest="switch"
                      action="store_true", # default: None
                      help="change files in-place",
                      )
    parser.add_option("--hg",   # implies dest="switch"
                      action="store_true", # default: None
                      help="change files in-place",
                      )
    parser.add_option("--changes",   # implies dest="switch"
                      action="store_true", # default: None
                      help="count changed lines per patch",
                      )
    parser.add_option("--no-author",   # implies dest="switch"
                      action="store_true", # default: None
                      help="do not print the author",
                      )
    parser.add_option("--fetch-all",   # implies dest="switch"
                      action="store_true", # default: None
                      help="when --older or --newer is given, do " +\
                           "not pass the date option to the vcs program " +\
                           "but fetch all the repository data and filter " +\
                           "out the needed dates later.",
                      )
    parser.add_option("-d", "--dir", # implies dest="file"
                      action="store", # OptionParser's default
                      type="string",  # OptionParser's default
                      help="specify the DIRECTORY with the repository data",
                      metavar="DIRECTORY"  # for help-generation text
                      )
    parser.add_option("--reponame", # implies dest="file"
                      action="store", # OptionParser's default
                      type="string",  # OptionParser's default
                      help="specify the REPOSITORYNAME, this is for printing only.",
                      metavar="REPOSITORYNAME"  # for help-generation text
                      )
    parser.add_option("--author", # implies dest="file"
                      action="store", # OptionParser's default
                      type="string",  # OptionParser's default
                      help="filter the AUTHOR. AUTHOR may be a regular expression.",
                      metavar="AUTHOR"  # for help-generation text
                      )
    parser.add_option("--newer", # implies dest="file"
                      action="store", # OptionParser's default
                      type="string",  # OptionParser's default
                      help="keep only entries newer than DATE",
                      metavar="DATE"  # for help-generation text
                      )
    parser.add_option("--older", # implies dest="file"
                      action="store", # OptionParser's default
                      type="string",  # OptionParser's default
                      help="keep only entries older than DATE",
                      metavar="DATE"  # for help-generation text
                      )
    parser.add_option("--repos", # implies dest="file"
                      action="store", # OptionParser's default
                      type="string",  # OptionParser's default
                      help="get information from a REPOSPECIFICATION. "+\
                           "This is a comma separated list where each item "+\
                           "consist of 3 parts: a repository description, "+\
                           "a directory and a VCS type. The parts are "+\
                           "separated by colons. The known VCS types "+\
                           "are \"darcs\" and \"hg\". Here is an example: "+\
                           "--repos ../A:repo1:darcs,../B:repo2:hg",
                      metavar="REPOSPECIFICATION",
                      )
    parser.add_option("--repos-file", # implies dest="file"
                      action="store", # OptionParser's default
                      type="string",  # OptionParser's default
                      help="get information from a REPOSPECIFICATIONFILE. "+\
                           "This file has in each line a repository "+\
                           "specification consisting of three parts that"+\
                           "are separated by spaces: "+\
                           "a repository description, a directory and a VCS type. "+\
                           "The parts are "+\
                           "separated by colons. The known VCS types "+\
                           "are \"darcs\" and \"hg\". Here is an example: "+\
                           "--repos ../A:repo1:darcs,../B:repo2:hg",
                      metavar="REPOSPECIFICATIONFILE",
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

    process(options,args)
    sys.exit(0)

if __name__ == "__main__":
    main()


