#!/usr/bin/env python
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

"""
===========
 console.py
===========

------------------------------------------------------------------
 A tool to connect to an IOC console without requesting a password
------------------------------------------------------------------

Overview
========

This program is just a small addition to the `console
<http://www.conserver.com/>`_ program.  It frees the user from entering a
password to log on an IOC.

It stores usernames and/or passwords in a file 
`.netrc <http://linux.about.com/library/cmd/blcmdl5_netrc.htm>`_ that is
usually present in your home. The IOC name and optional username can be
specified as regular program options or as unnamed parameters following the
program. The following two statements are equivalent::

    console.py -H HOST -u USER

    console.py HOST USER

Format of .netrc
================

A line in a `.netrc`_ file has the following form::

  machine NAME login USER password PASSWORD

In the line above, "NAME", "USER" and "PASSWORD" are different in each line.
"NAME" is usually the hostname, but it is in effect arbitrary. console.py uses
"NAME" not for the real hostname but in the way described below:

* store a password for a user:

  In this case "NAME" has the form "Console-by-user-USER".

* store a password for a specific IOC:

  In this case "NAME" has the form "Console-by-host-IOC".

Note that if you create the file `.netrc`_ for the first time you must ensure
it is readable only by yourself with this command::

  chmod 700 $HOME/.netrc

Quick reference
===============

* add a line to the `.netrc`_ file for a given username and password::

    console.py --netrc-line -u USER -p PASSWORD >> $HOME/.netrc

* add a line to the `.netrc`_ file for a given ioc, username and password::

    console.py --netrc-line -H HOST -u USER -p PASSWORD >> $HOME/.netrc

* log onto an IOC as a specific user, simple form::

    console.py HOST USER

* log onto an IOC as a specific user, command line arguments::

    console.py -H HOST -u USER

* log onto an IOC as user "tscadm", simple form::

    console.py HOST

Reference of command line options
=================================

--summary
  print a one-line summary of the scripts function

--netrc FILE
  Specify the name of the netrc file. If the option is omitted, the program
  tries to read the file "`.netrc`_" from your home. A file of this type (see
  also \"man netrc\") is a simple way to store login information. You just
  create a file ".netrc" in your home which should be readable only by yourself
  ("chmod 700 $HOME/.netrc).

-u, --user USER
  You can specify the user directly with this command line option. If the
  password is not provided, the program tries to find the entry
  "Console-by-user-USER" in the `.netrc`_ file and takes the password from
  there.

-p, --password PASSWORD
  You can specify the password with this command line option. If you specify
  the user and the password with command line options, the program does not
  read the `.netrc`_ file.

-H HOST
  You can specfiy the host with this option. 

-t, --timeout TIMEOUT
  You can specify the timeout for the connection with the console server with
  this option.

--netrc-line
  When this option is given, the program does not log onto the IOC. Instead it
  prints the line you would have to add to your `.netrc`_ file if you want to
  store the username and password there. If this option is given you should
  either specify the host, the user and the password or you shoudl specify the
  only the user and the password.

--doc
  print reStructuredText documentation (THIS text :-)...). Use
  "console.py --doc | rst2html > console.py.html" to create a html documentation.

"""

from optparse import OptionParser
import os
import sys
import netrc

_no_check= len(sys.argv)==2 and (sys.argv[1] in ("-h","--help","--summary","--doc"))
try:
    import pexpect
except ImportError:
    if _no_check:
	sys.stderr.write("WARNING: (in %s) mandatory module pexpect not found\n" % \
			 sys.argv[0])
    else:
	raise

my_version= "1.0"

default_user= "tscadm"

def process(options,args):
    """do the ssh command."""
    def pseudohost_from_host(host):
        return "Console-by-host-%s" % host
    def pseudohost_from_user(user):
        return "Console-by-user-%s" % user
    host= options.host
    if host is None:
        if len(args)<=0:
            if not options.netrc_line:
                sys.exit("hostname missing")
        else:
            host= args[0]

    user= options.user
    if user is None:
        if len(args)>=2:
            user= args[1]
    pw= options.password
    if pw is None:
        if len(args)>=3:
            pw= args[2]

    if (user is None) or (pw is None):
        try:
            if options.netrc:
                n= netrc.netrc(options.netrc)
            else:
                n= netrc.netrc()
        except IOError, e:
            # no netrc file found
            sys.exit("error: .netrc file could not be read")
        if user is None:
            user= default_user
        tp= n.hosts.get(pseudohost_from_host(host))
        if tp is None:
            tp= n.hosts.get(pseudohost_from_user(user))
        if tp is None:
            sys.exit(("not data found for host %s or user %s "+\
                      "in .netrc file") % (host,user))
        user= tp[0]
        pw  = tp[2]

    if options.netrc_line:
        if host is None:
            print "machine %s login %s password %s" % \
                  (pseudohost_from_user(user), user,pw)
        else:
            print "machine %s login %s password %s" % \
                  (pseudohost_from_host(host), user,pw)
        sys.exit(0)

    child= pexpect.spawn("console -l %s %s" % (user,host), 
                         timeout=options.timeout)
    child.expect("@gwc2c's password: ")
    child.sendline(pw)
    try:
        child.interact()
    except OSError, e:
        pass
    sys.exit(0)

def script_shortname():
    """return the name of this script without a path component."""
    return os.path.basename(sys.argv[0])
          
def print_summary():
    """print a short summary of the scripts function."""
    print "%-20s: log onto an IOC without requesting the password\n" % script_shortname()

def print_doc():
    """print embedded reStructuredText documentation."""
    print __doc__

def main():
    """The main function.
    
    parse the command-line options and perform the command
    """
    # command-line options and command-line help:
    usage = "usage: %prog [options] {host|user@host} {commands}"
    parser = OptionParser(usage=usage,
                          version="%%prog %s" % my_version,
                          description="Log on an IOC console without requesting "+\
                                      "the password"
                                      )
    parser.add_option("--summary",  # implies dest="nodelete"
                      action="store_true", # default: None
                      help="print a summary of the function of the program", 
                      )
    parser.add_option("--doc",  # implies dest="nodelete"
                      action="store_true", # default: None
                      help="print a description of the program "+\
                           "in restructured text.", 
                      )

    parser.add_option("--netrc",     # implies dest="switch"
                      action="store", # default: None
                      type="string",  # OptionParser's default
                      help="read user name and password from .netrc file "+\
                           "at the given MACHINE entry. If the host is not "+\
                           "specified otherwise, MACHINE is taken as hostname.",
                      metavar="MACHINE",
                      )
    parser.add_option("-u","-l", "--user", # implies dest="file"
                      action="store", # OptionParser's default
                      type="string",  # OptionParser's default
                      help="specify the USER", 
                      metavar="USER"  # for help-generation text
                      )
    parser.add_option("-p", "--password", # implies dest="file"
                      action="store", # OptionParser's default
                      type="string",  # OptionParser's default
                      help="specify the PASSWORD", 
                      metavar="PASSWORD"  # for help-generation text
                      )
    parser.add_option("-H", "--host", # implies dest="file"
                      action="store", # OptionParser's default
                      type="string",  # OptionParser's default
                      help="specify the HOST", 
                      metavar="HOST"  # for help-generation text
                      )
    parser.add_option("-t", "--timeout", # implies dest="file"
                      action="store", # OptionParser's default
                      type="int",  # OptionParser's default
                      help="specify the connection TIMEOUT.", 
                      metavar="TIMEOUT"  # for help-generation text
                      )
    parser.add_option("--netrc-line",  # implies dest="nodelete"
                      action="store_true", # default: None
                      help="print the line that would have to be "+\
                           "added to the .netrc file for the given "+\
                           "username and password", 
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
        
    process(options,args)
    sys.exit(0)

if __name__ == "__main__":
    main()

