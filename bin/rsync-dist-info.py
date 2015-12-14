#!/usr/bin/env python
# -*- coding: UTF-8 -*-
# pylint: disable=invalid-name

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

# pylint: disable=line-too-long

"""
======================
 rsync-dist-info.py
======================
------------------------------------------------------------------------------
 a tool to analyze rsync-dist log files
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

   rsync-dist-info.py -c rsync-dist.config -n

* show statistics on versions::

   rsync-dist-info.py -c rsync-dist.config -v

* show statistics on version lifetimes::

   rsync-dist-info.py -c rsync-dist.config -l

* show an overview on IOC boot times::

   rsync-dist-info.py -c rsync-dist.config --boot-times

* show fallback recommendation::

   rsync-dist-info.py -c rsync-dist.config --fallback-info [linkname]

* show information for a list of versions::

   rsync-dist-info.py -c rsync-dist.config --version-info [version1,version2...]

Output formats
==============

rsync-dist-info has four output formats.

the *names* format
  In this format, each symlink-name is followed by a colon and
  a number of lines describing at what date this link pointed
  to what version. If the symbolic link was removed at a certain
  time, the string "REMOVED" is printed instead of a version.
  An active version, that means the version the link currently
  points to, is marked with a star "*".
  Here is an example::

    SIOC7C:
         2009-10-05 11:40:10    2009-10-05T11:39:00
         2009-10-06 13:26:18    2009-10-06T13:25:13
    *    2009-10-06 13:40:49    2009-10-06T13:40:40

    SIOC8C:
         2009-10-05 11:40:10    2009-10-05T11:39:00
         2009-10-06 13:26:18    2009-10-06T13:25:13
    *    2009-10-06 13:40:49    2009-10-06T13:40:40

    SIOC9C:
         2009-10-05 11:40:10    2009-10-05T11:39:00
         2009-10-06 13:26:18    2009-10-06T13:25:13
         2009-10-06 13:40:49    REMOVED

the *versions* format
  This format shows for each version at what time what symbolic links (names)
  pointed to this version. If a symbolic link was made to point to a different
  version at a certain date, the old version has a new entry with that
  timestamp with this symbolic link removed. If there are no symbolic links for
  a version, the list is empty. This shows that from this date on, the version
  is no longer in use. Here is an example::

    2009-07-06T13:22:40:
         2009-07-06 13:22:59    SIOC1C
         2009-10-05 11:25:11

    2009-07-09T13:42:56:
         2009-07-09 13:43:17    IOC1S15G
         2009-07-09 13:43:43    IOC1S15G IOC1S1G
         2009-07-13 08:13:32    IOC1S1G
         2009-07-16 11:50:50

the *lifetimes* format
  This format shows the timespan a version was in use, meaning the time
  when at least one symbolic link pointed to that version. In this format
  the first and last date of any usage is printed as well as the lifetime
  in fractions of days. If the version is at this time still in use,
  the second date is "NOW".
  Here is an example::

    2009-09-22T11:56:18:
         2009-09-22 11:56:43    2009-10-05 11:25:11
                                                        13.0
    2009-09-28T09:29:48:
         2009-09-28 09:31:04    2009-10-05 11:25:11
         2009-10-05 19:25:18    2009-10-06 13:26:18
                                                         7.8
    2009-09-28T12:42:12:
         2009-09-28 12:42:29    2009-10-05 11:25:11
                                                         6.9
                                                         0.97

the *idles* format
  This format is used for the special -i or --idle option. It is
  a list of the sub-directories in the distribution directory
  that are not and were never in use, meaning no symbolic link ever pointed
  to them. Here is an example::

    2009-07-06T09:08:56
    2009-09-14T09:40:01
    2009-10-06T10:22:52

the *boottimes* format
  This format displays an overview on all names and the times when the
  corresponding IOCs were booted. Here is an example::

    name            version              activated            booted               comment
    BAWATCHP        2009-02-18T15:10:54  2009-02-18T15:11:06  -                    dont't known how to find boottime for this name
    IOC1S1GP        2009-10-23T14:06:35  2009-10-23T14:07:06  2009-10-09T16:27:09  IOC doesn't run with active version
    IOC1S4GP        2009-10-09T14:54:54  2009-10-09T14:55:18  2009-10-09T14:56:54
    IOC2S1GP        2009-11-13T11:58:23  2009-11-13T11:58:36  2009-11-13T13:30:15

  If the option --verbose is used together with --boot-times, the number of days
  the IOC's are running is also printed::

    name            version              activated            booted               days running  comment
    BAWATCHP        2009-02-18T15:10:54  2009-02-18T15:11:06  -                               -  dont't known how to find boottime for this name
    IOC1S1GP        2009-10-23T14:06:35  2009-10-23T14:07:06  2009-10-09T16:27:09          38.8  IOC doesn't run with active version (for 24.9 days)
    IOC1S4GP        2009-10-09T14:54:54  2009-10-09T14:55:18  2009-10-09T14:56:54          38.9
    IOC2S1GP        2009-11-13T11:58:23  2009-11-13T11:58:36  2009-11-13T13:30:15           3.9


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
  Use "./rsync-dist-info.py --doc | rst2html" to create html-help"

-t, --test
  perform a simple self-test of some internal functions

-c CONFIGFILE, --call CONFIGFILE
  call rsync-dist.pl directly with CONFIGFILE. With this option it
  is no longer necessary to call rsync-dist.pl directly.

-n, --names
  print summary for each link name

-v, --versions
  print summary for each version

-l, --lifetimes
  print lifetime summary for each version

-i, --idle
  print idle versions, versions that are not in
  use and never have been.

--version-info VERSIONS
  show logfile information for VERSIONS. VERSIONS
  is a comma-separated list of version strings.

--boot-times
  check boot-times in relation with times a version was
  activated.

-b, --brief
  brief output, with -n just show link names,
  with -v and -l just show version names

--last NO
  with --names, print only the last NO versions
  for each name

--filter-names NAMES
  NAMES may be a comma separated list. Only these
  names and their versions are printed.

--filter-versions VERSIONS
  show only information for versions specified by
  VERSIONS, which may be a comma-separated list of
  versions.

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
  distribution directory.

--filter-nonexistent
  show only version that are not existent in the
  distribution directory.

--filter-ignexistent
  show versions no matter if they exist or exist not
  in the distribution directory. This is needed if
  you want to overturn the implicit --filter-existent
  that is otherwise set.

--fallback-info LINKNAME
  show a short list of recommended versions for
  the given linkname. This option corresponds to
  -n --filter-lifetime-bigger 2 --last 3 --filter-names
  LINKNAME.
"""

# pylint: enable=line-too-long

from optparse import OptionParser
import sys
import os
import re

# On host "elbe", there is a python module "ca" installed at
# "/opt/Epics/extensions/python/lib/python2.7". This module however, is
# incompatible with this script. We have to take "ca.py" from
# "/opt/csr/lib/python". A proper solution would be to set PYTHONPATH correctly
# (with "/opt/csr/lib/python" first), which would have to be configured in
# "/opt/csr/setup.d/setup.sh". However, it is unclear if this would break some
# other scripts. So for now we change the module search path in this script,
# but only when it runs on host "elbe":

import platform
if platform.node()=="elbe":
    sys.path=[x for x in sys.path \
              if not \
              x.startswith("/opt/Epics/extensions/python/lib/python2.7")]

# pylint: disable=unused-import
try:
    from ca import _ca
    import ca
except ImportError:
    sys.stderr.write("WARNING: (in %s.py) mandatory module ca not found\n" % \
                     __name__)
# pylint: enable=unused-import

import datetime
import dateutils
import rsync_dist_lib as rd
import boottime


# version of the program:
MY_VERSION= "1.1"

def boot_times(objs, verbose=False, csv=False):
    """print boot-times overview."""
    # pylint: disable=too-many-locals
    # pylint: disable=too-many-branches
    def daydiff(d1, d2):
        """returns the difference (d2-d1) between two dates in days."""
        if d1 is None:
            return "-"
        d= d2-d1
        return "%6.1f" % (d.days+d.seconds/86400.0)
    # get all names, but only the names that are not deleted:
    names= [n for n in objs.logByName.keys() if objs.logByName.name_exists(n)]
    act_dist= {}
    for name, entries in objs.logByName.items():
        act_dist[name]= entries[-1]
    if verbose:
        h_format= "%(name)-15s %(version)-19s  %(activated)-19s  "+\
                        "%(booted)-19s  %(days)-12s  %(comment)s"
        r_format= "%(name)-15s %(version)-19s  %(activated)-19s  "+\
                        "%(booted)-19s  %(days)12s  %(comment)s"
    elif csv:
        h_format= '"%(name)s","%(version)s","%(activated)s",'+\
                        '"%(booted)s","%(comment)s"'
        r_format= h_format
    else:
        h_format= "%(name)-15s %(version)-19s  %(activated)-19s  "+\
                        "%(booted)-19s  %(comment)s"
        r_format= h_format
    print h_format % {"name":"name",
                      "version":"version",
                      "activated":"activated",
                      "booted":"booted",
                      "days":"days running",
                      "comment":"comment"
                     }
    today= datetime.datetime.today()
    for name in names:
        (activated,version)= act_dist[name]
        try:
            booted= boottime.boottime(name)
        except IOError, _:
            booted= None
            comment="IOC cannot be contacted!"
        if version is None:
            # symlink was deleted
            if booted is not None:
                comment="name was deleted but IOC still runs!"
            else:
                comment="name was deleted"
        else:
            if booted is not None:
                if booted<=activated:
                    comment="IOC doesn't run with active version"
                    if verbose:
                        comment+= " (for %s days)" % \
                                  daydiff(activated,today).strip()
                else:
                    comment=""
        print r_format % \
               { "name":name,
                 "version": str(version) if version is not None else "-",
                 "activated": dateutils.isodatetime(activated),
                 "booted": dateutils.isodatetime(booted) \
                           if booted is not None else "-",
                 "days": daydiff(booted,today),
                 "comment": comment,
               }


def process(options):
    """process a single file.
    """
    # pylint: disable=too-many-locals
    # pylint: disable=too-many-branches
    # pylint: disable=too-many-statements
    existent_versions_set= [None]
    existent_names_set   = [None]

    def existent_versions():
        """return existent versions.

        Note that the returned set contains <None>.
        """
        if existent_versions_set[0] is not None:
            return existent_versions_set[0]
        distLs= rd.DistLs(rd.get_dist_ls(options.config))
        existent_versions_set[0]= set(distLs.keys())
        existent_versions_set[0].add(None)
        # ^^^ in order to keep entries in logByName where the
        # version is <None>, that means entries when the name
        # was deleted
        return existent_versions_set[0]
    def existent_names():
        """return existent names.

        Note that the returned set contains <None>.
        """
        if existent_names_set[0] is not None:
            return existent_names_set[0]
        linkLs= rd.LinkLs(rd.get_link_ls(options.config))
        existent_names_set[0]= set(linkLs.keys())
        return existent_names_set[0]

    class Objs(object):
        """class that holds all rsync-dist information."""
        def __init__(self):
            """create the object empty."""
            self.logByName= None
            self.logByVersion= None
            self.versionActivities= None
            self.versionLifetimes= None
        def filter_by_name(self, keep, use_regexp= False):
            """implement filer-by-name."""
            if self.logByName is not None:
                self.logByName        = self.logByName.select_names(keep,\
                                            use_regexp= use_regexp)
            if self.logByVersion is not None:
                self.logByVersion     = self.logByVersion.select_names(keep,\
                                            use_regexp= use_regexp)
        def filter_by_version(self, keep):
            """implement filer-by-version."""
            if self.logByName is not None:
                self.logByName     = self.logByName.select_versions(keep)
            if self.logByVersion is not None:
                self.logByVersion  = self.logByVersion.select_versions(keep)
            if self.versionActivities is not None:
                self.versionActivities= \
                    self.versionActivities.select_versions(keep)
            if self.versionLifetimes is not None:
                self.versionLifetimes =  \
                    self.versionLifetimes.select_versions(keep)

    if options.version_info:
        distLog= rd.DistLog(rd.get_dist_log(options.config))
        wanted_versions= options.version_info.split(",")
        # print wanted_versions
        # print "-" * 20
        distLog= distLog.select(wanted_versions)
        print distLog
        sys.exit(0)

    if options.fallback_info:
        options.names= True
        options.filter_lifetime_bigger=2
        options.last=3
        options.filter_names= options.fallback_info

    objs= Objs()

    objs.logByName= rd.LLogByName(rd.get_link_log(options.config))
    objs.logByVersion= rd.LLogByVersion(objs.logByName)

    if options.idle:
        existent= existent_versions()
        # remove the <None> element from existent_versions:
        existent.remove(None)
        idles= existent_versions().difference(objs.logByName.versions_set())
        print "idle versions:"
        print "\n".join(sorted(idles))
        return

    if options.filter_names:
        keep= options.filter_names.split(",")
        objs.filter_by_name(keep)

    if options.filter_names_rx:
        keep= [re.compile(rx) for rx in options.filter_names_rx.split(",")]
        objs.filter_by_name(keep, use_regexp= True)

    if options.filter_existent_names:
        keep= existent_names()
        objs.filter_by_name(keep)
    elif options.filter_nonexistent_names:
        keep= set(objs.logByName.keys()).difference(existent_names())
        objs.filter_by_name(keep)

    objs.versionActivities= rd.LLogActivity(objs.logByVersion)
    objs.versionLifetimes = rd.LLogLifeTimes(objs.versionActivities)

    if options.filter_versions:
        keep= options.filter_versions.split(",")
        keep.append(None)
        # keep <None> version entries in logByName
        # (times when names were removed)
        objs.filter_by_version(keep)

    if options.filter_nonexistent:
        keep= objs.logByName.versions_set().difference(existent_versions())
        objs.filter_by_version(keep)
    else:
        if not options.filter_ignexistent:
            keep= existent_versions()
            objs.filter_by_version(keep)

    if options.filter_active:
        keep= objs.versionActivities.active_versions()
        objs.filter_by_version(keep)

    if options.filter_inactive or options.filter_inactive_since:
        since_date= None
        if options.filter_inactive_since is not None:
            try:
                since_date= \
                    dateutils.parse_isodate(options.filter_inactive_since)
            except ValueError,_:
                sys.exit("invalid date:%s" % options.filter_inactive_since)
        keep= objs.versionActivities.inactive_versions(since_date)
        # keep the Version==<None> entries:
        keep.add(None)
        objs.filter_by_version(keep)

    if options.filter_lifetime_smaller:
        bigger= objs.versionLifetimes.lifetime_bigger(\
                    options.filter_lifetime_smaller)
        keep= set(objs.logByVersion.keys()).difference(set(bigger))
        objs.filter_by_version(keep)

    if options.filter_lifetime_bigger:
        keep= objs.versionLifetimes.lifetime_bigger(\
                  options.filter_lifetime_bigger)
        objs.filter_by_version(keep)

    if options.boot_times:
        boot_times(objs,options.verbose,options.csv)
    elif options.names:
        objs.logByName.print_(options.brief,options.last)
        #for n,l in objs.logByName.items():
        #    print "-" * 30
        #    print n,":"
        #    for e in l:
        #        print e
    elif options.versions:
        objs.logByVersion.print_(options.brief)
        #for v,dd in objs.logByVersion.items():
        #    print "-" * 30
        #    print v,":",repr(v)
        #    for d in sorted(dd.keys()):
        #        print d,dd[d]
    elif options.lifetimes:
        objs.versionLifetimes.print_with_actives(objs.versionActivities)
    else:
        print "error: one of -n, -v or -l must be specified"
        sys.exit(1)
    if options.fallback_info:
        print "\nget information on a versions (comma separated list) with:"
        print "rsync-dist-info.py -c %s --version-info [VERSIONS]" % \
              options.config
        print "\nperform a fallback with:"
        print "rsync-dist.pl -c %s change-links [VERSION],%s" % \
              (options.config, options.fallback_info)

def script_shortname():
    """return the name of this script without a path component."""
    return os.path.basename(sys.argv[0])

def print_doc():
    """print embedded reStructuredText documentation."""
    print __doc__

def print_summary():
    """print a short summary of the scripts function."""
    print "%-20s: a tool for processing the rsync-dist link log\n" % \
          script_shortname()

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
    # pylint: disable=too-many-statements
    # command-line options and command-line help:
    usage = "usage: %prog [options] {files}"

    parser = OptionParser(usage=usage,
                          version="%%prog %s" % MY_VERSION,
                          description="this program prints summaries and "
                                      "statistics of rsync-dist "
                                      "link-log files."
                         )

    parser.add_option("--summary",  # implies dest="nodelete"
                      action="store_true", # default: None
                      help="print a summary of the function of the program",
                     )
    parser.add_option("--doc",            # implies dest="switch"
                      action="store_true", # default: None
                      help="create online help in restructured text"
                           "format. Use "
                           "\"./rsync-dist-info.py --doc | rst2html\" "
                           "to create html-help"
                     )

    parser.add_option("-t", "--test",     # implies dest="switch"
                      action="store_true", # default: None
                      help="perform simple self-test",
                     )
    parser.add_option("-c", "--config", # implies dest="file"
                      action="store", # OptionParser's default
                      type="string",  # OptionParser's default
                      help="specify the rsync-dist config file",
                      metavar="CONFIGFILE"  # for help-generation text
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
    parser.add_option("--boot-times",   # implies dest="switch"
                      action="store_true", # default: None
                      help="check boot-times in relation with "+\
                           "times a version was activated",
                     )
    parser.add_option("--csv",   # implies dest="switch"
                      action="store_true", # default: None
                      help="use csv format for boot-times command",
                     )
    parser.add_option("--verbose",   # implies dest="switch"
                      action="store_true", # default: None
                      help="make boot-times printout more verbose",
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
    parser.add_option("--filter-names-rx",   # implies dest="switch"
                      action="store", # default: None
                      type="string",
                      help="show only information for links specified "+\
                           "by LINKREGEXP, which may be a comma-separated "+\
                           "list of regular expressions.",
                      metavar="LINKREGEXP",
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
                      help="filter versions inactive for longer than "
                           "a given DATE",
                      metavar="DATE",
                     )
    parser.add_option("--filter-lifetime-smaller",   # implies dest="switch"
                      action="store", # default: None
                      type="float",
                      help="filter versions with a lifetime smaller "
                           "than DAYS",
                      metavar="DAYS",
                     )
    parser.add_option("--filter-lifetime-bigger",   # implies dest="switch"
                      action="store", # default: None
                      type="float",
                      help="filter versions with a lifetime bigger than "
                           "DAYS",
                      metavar="DAYS",
                     )
    parser.add_option("--filter-existent",   # implies dest="switch"
                      action="store_true", # default: None
                      help="show only versions that are still existent "
                           "in the distribution directory.",
                     )
    parser.add_option("--filter-nonexistent",   # implies dest="switch"
                      action="store_true", # default: None
                      help="show only versions that are not existent in the "
                           "distribution directory.",
                     )
    parser.add_option("--filter-ignexistent",   # implies dest="switch"
                      action="store_true", # default: None
                      help= "show versions no matter if they exist or exist "
                            "not in the distribution directory. This is "
                            "needed if you want to overturn the implicit "
                            "--filter-existent that is otherwise set.",
                     )
    parser.add_option("--filter-existent-names",   # implies dest="switch"
                      action="store_true", # default: None
                      help="show only names that are existent in the "+\
                           "distribution directory.",
                     )
    parser.add_option("--filter-nonexistent-names",   # implies dest="switch"
                      action="store_true", # default: None
                      help="show only names that are not existent in the "+\
                           "distribution directory.",
                     )
    parser.add_option("--fallback-info",   # implies dest="switch"
                      action="store", # default: None
                      type="string",
                      help="show recommended fallback versions for "
                           "LINKNAME. This corresponds to -n "
                           "--filter-lifetime-bigger 2 --last 3 "
                           "--filter-names LINKNAME",
                      metavar="LINKNAME",
                     )

    # x= sys.argv
    (options, _) = parser.parse_args()
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
           options.idle,options.boot_times, (options.version_info is not None)]
    vstr="--names,--versions,--lifetimes,--idle,--version-info,boot-times"

    cmdno= reduce(lambda x,y:x+bool(y),cmds,0)
    if cmdno==0:
        if options.fallback_info is None:
            sys.exit("a command is missing, (%s)" % vstr)

    if cmdno>1:
        sys.exit("only one command (%s) is allowed at a time" % vstr)

    # process_files(options,args)
    process(options)
    sys.exit(0)

if __name__ == "__main__":
    main()


