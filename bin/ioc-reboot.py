#! /usr/bin/env python
# -*- coding: UTF-8 -*-

"""
==============
 ioc-reboot.py
==============

----------------------
 A tool to reboot iocs
----------------------

Overview
========

This program reboots one or several vxWorks IOCs by connecting via telnet and
issuing the "reboot" command.

It stores usernames and/or passwords in the file 
`.netrc <http://linux.about.com/library/cmd/blcmdl5_netrc.htm>`_ that is
usually present in your home. The IOC name and an optional username and password can be
specified on the command line.

Format of .netrc
================

A line in a `.netrc`_ file has the following form::

  machine NAME login USER password PASSWORD

In the line above, "NAME", "USER" and "PASSWORD" are different in each line.
"NAME" is usually the hostname, but it is in effect arbitrary. ioc-reboot.py uses
"NAME" not for the real hostname but in the way described below:

* store a password for a user:

  In this case "NAME" has the form "ioc-reboot-by-user-USER".

* store a user and password for a specific IOC:

  In this case "NAME" has the form "ioc-reboot-by-host-HOST".

Note that if you create the file `.netrc`_ for the first time you must ensure
it is readable only by yourself with this command::

  chmod 700 $HOME/.netrc

Quick reference
===============

* add a line to the `.netrc`_ file for a given username and password::

    ioc-reboot.py --netrc-line USER:PASSWORD >> $HOME/.netrc

* add a line to the `.netrc`_ file for a given ioc, username and password::

    ioc-reboot.py --netrc-line HOST:USER:PASSWORD >> $HOME/.netrc

* reboot an IOC as a specific user, simple form::

    ioc-reboot.py HOST

* reboot an IOC as a specific user, take password from .netrc::

    ioc-reboot.py HOST:USER

* reboot an IOC as a specific user with a given password::

    ioc-reboot.py HOST:USER:PASSWORD

Reference of command line options
=================================

-h, --help
  display short help for command line arguments

--summary
  print a one-line summary of the scripts function

--test
  perform some self-tests

--doc
  print reStructuredText documentation (THIS text :-)...). Use
  "ioc-reboot.py --doc | rst2html > ioc-reboot.py.html" to create a html documentation.

--dry-run
  just show what the program would do.

-d, --delay DELAYTIME
  When the program is used to boot more than one IOC this specifies the time
  it waits between two IOCs in seconds.

--netrc FILE
  Specify the name of the netrc file. If the option is omitted, the program
  tries to read the file "`.netrc`_" from your home. A file of this type (see
  also \"man netrc\") is a simple way to store login information. You just
  create a file ".netrc" in your home which should be readable only by yourself
  ("chmod 700 $HOME/.netrc).

--netrc-line
  When this option is given, the program does not log onto the IOC. Instead it
  prints the line you would have to add to your `.netrc`_ file if you want to
  store the username and password there. If this option is given you should
  either specify the host, the user and the password as "host:user:password" 
  or you should specify the only the user and the password as "user:password".
  is stored for a specific host, in the second case a user and password are stored which
  can be user for all hosts.

-t, --timeout TIMEOUT
  You can specify the timeout for the telnet connection. The program uses telnet to
  log onto the IOC in order to issue the "reboot" command on the vxworks console.

"""

from optparse import OptionParser
#import string
import os.path
import sys
import telnetlib
import time
import netrc

# version of the program:
my_version= "1.0"

default_delay= 0
default_timeout= 5

pseudohost_prefix_host= "ioc-reboot-by-host"
pseudohost_prefix_user= "ioc-reboot-by-user"


def tn_read_until(tn, expected, timeout= None):
    """read from telnet connection until a special string is found."""
    args= [expected]
    if timeout is not None:
        args.append(timeout)
    st= tn.read_until(*args)
    if not st.endswith(expected):
        tn.close()
        raise AssertionError, "unexpected reply:\n%s\n" % st

def vxlogin(ioc, loginname, loginpassword, timeout):
    """login on an vxworks ioc."""
    if sys.version_info < (2,6):
        tn= telnetlib.Telnet(ioc)
    else:
        tn= telnetlib.Telnet(ioc, timeout= timeout)
    tn_read_until(tn, "VxWorks login: ", timeout= timeout)
    tn.write(loginname+"\n")
    tn_read_until(tn, "Password: ", timeout= timeout)
    tn.write(loginpassword+"\n")
    tn_read_until(tn, "> ", timeout= timeout)
    return tn

def netrc_dict(netrc_name= None):
    """return netrc as a dict."""
    try:
        if netrc_name is not None:
            n= netrc.netrc(netrc_name)
        else:
            n= netrc.netrc()
    except IOError, e:
        # no netrc file found
        return {}
    return n.hosts

def scan_netrc(netrc_dict):
    """process netrc data returned by netrc_dict.

    Here is an example:
    import pprint
    >>> d= { "dummy": ("user1",None,"password1"),
    ...      "ioc-reboot-by-host-host1": ("host1user",None,"host1password"),
    ...      "ioc-reboot-by-host-host2": ("host2user",None,"host2password"),
    ...      "ioc-reboot-by-user-user1": ("user1user",None,"user1password"),
    ...      "ioc-reboot-by-user-user2": ("user2user",None,"user2password"),
    ...    }
    >>> pprint.pprint(scan_netrc(d))
    ({'host1': ('host1user', 'host1password'),
      'host2': ('host2user', 'host2password')},
     {'user1user': 'user1password', 'user2user': 'user2password'})
    """
    users_dict= {}
    hosts_dict= {}
    for k in netrc_dict.keys():
        if k.startswith(pseudohost_prefix_host):
            host= k.replace(pseudohost_prefix_host+"-","")
            tp= netrc_dict[k]
            hosts_dict[host]= (tp[0], tp[2])
        elif k.startswith(pseudohost_prefix_user):
            user= k.replace(pseudohost_prefix_user+"-","")
            tp= netrc_dict[k]
            users_dict[tp[0]]= tp[2]
    return(hosts_dict, users_dict)

def unpack_spec(spec):
    """unpack a host spec given by the user.

    Here is an example:
    >>> unpack_spec("host")
    ('host', None, None)
    >>> unpack_spec("host:user")
    ('host', 'user', None)
    >>> unpack_spec("host:user:password")
    ('host', 'user', 'password')
    """
    l= spec.split(":")
    h= l[0]
    u= l[1] if len(l)>1 else None
    p= l[2] if len(l)>2 else None
    return(h,u,p)

def netrc_line_from_spec(spec):
    """generate netrc line from given spec.

    In this case, 3 elements mean host:user:password,
    2 elements mean user:password

    Here is an example:
    >>> netrc_line_from_spec("myhost:myuser:mypassword")
    'machine ioc-reboot-by-host-myhost login myuser password mypassword'
    >>> netrc_line_from_spec("myuser:mypassword")
    'machine ioc-reboot-by-user-myuser login myuser password mypassword'
    """
    def mk_netrc(h,u,p):
        if h is None:
            return pseudohost_prefix_user+"-"+u
        else:
            return pseudohost_prefix_host+"-"+h
    (h,u,p)= unpack_spec(spec)
    if p is None:
        p= u
        u= h
        h= None
    return "machine %s login %s password %s" % \
            (mk_netrc(h,u,p),u,p)

def reboot(ioc_spec, timeout, dry_run, hosts_dict, users_dict):
    """reboot an IOC by issuing ctrl-x on the command line.

    ioc_spec: ioc:user:password
              user and password are optional
    """
    (host,user,pw)= unpack_spec(ioc_spec)
    user_provided_password= (pw is not None)
    if user is None:
        if not hosts_dict.has_key(host):
            login_list= sorted(users_dict.items())
            if len(login_list)==0:
                sys.exit("no list of possible users found in .netrc")
        else:
            login_list= [ hosts_dict(host) ]
    else:
        if pw is None:
            if not users_dict.has_key(user):
                sys.exit("no pw information found for user \"%s\"" % user)
            login_list= [ (user, users_dict[user]) ]
        else:
            login_list= [ (user, pw) ]
    success= False
    tn= None
    if dry_run: 
        print "reboot %s:" % host
    for (usr,pw) in login_list:
        try:
            if dry_run:
                if not user_provided_password:
                    p="******"
                else:
                    p=pw
                print "\ttry to login as %s:%s" % (usr,p)
            else:
                tn= vxlogin(host, usr, pw, timeout)
                success= True
                break
        except AssertionError, e:
            pass
    if (not success) and (not dry_run):
        raise AssertionError, "login on host %s failed" % host
    if not dry_run:
        tn.write("reboot\n")
        # for mysterious reasons sending "\x18" (ctrl-x) doesn't work ...
    if dry_run:
        print "\tsleep 2 seconds"
    else:
        time.sleep(2.0)
    # without the delay the IOC goes in a state where it is still 
    # running but the network connection is broken
    if not dry_run:
        tn.close()
    else:
        print

def process(options,args):
    """process the options.
    """
    if options.netrc_line is None:
        (hosts_dict,user_dict)=scan_netrc(netrc_dict(options.netrc))
    else:
        (hosts_dict,user_dict)=(None,None)
    delay= default_delay
    if options.delay:
        delay= options.delay
    timeout= default_timeout
    if options.timeout:
        timeout= options.timeout
    if len(args)==0:
        sys.exit("hostname(s) missing")
    argno= len(args)
    for i in xrange(argno):
        spec= args[i]
        if options.netrc_line:
            print netrc_line_from_spec(spec)
            continue
        reboot(spec, timeout, options.dry_run, 
               hosts_dict, user_dict)
        if i+1<argno:
            if delay>0:
                if options.dry_run:
                    print "sleep %s seconds\n" % delay
                time.sleep(float(delay))

def script_shortname():
    """return the name of this script without a path component."""
    return os.path.basename(sys.argv[0])

def print_summary():
    """print a short summary of the scripts function."""
    print "%-20s: reboots vxworks hosts\n" % script_shortname()

def _test():
    """does a self-test of some functions defined here."""
    print "performing self test..."
    import doctest
    doctest.testmod()
    print "done!"

def print_doc():
    """print embedded reStructuredText documentation."""
    print __doc__

def main():
    """The main function.

    parse the command-line options and perform the command
    """
    # command-line options and command-line help:
    usage = "usage: %prog [options] [ioc-specs]"

    parser = OptionParser(usage=usage,
                	  version="%%prog %s" % my_version,
			  description=
                          "This program reboots iocs. An ioc-spec "+\
                          "is either \"IOCNAME\" or \"IOCNAME:USER\" "+\
                          "or \"IOCNAME:USER:PASSWORD\". If user or "+\
                          "password are not specified, the program "+\
                          "tries two default users, \"epics\" "+\
                          "and \"ioc\".")

    parser.add_option("--summary",  
                      action="store_true", 
                      help="print a summary of the function of the program",
		      )
    parser.add_option("--test",  # implies dest="nodelete"
                      action="store_true", # default: None
                      help="perform simple self-test", 
                      )
    parser.add_option("--doc",  # implies dest="nodelete"
                      action="store_true", # default: None
                      help="print a description of the program "+\
                           "in restructured text.", 
                      )
    parser.add_option("--dry-run",  
                      action="store_true", 
                      help="just show what the program WOULD do.",
		      )
    parser.add_option("-d", "--delay", 
                      action="store", 
		      type="int",  
                      help="specify DELAYTIME before the reboots of"+\
                           "more than one ioc, the default is %d." % \
                           default_delay,
		      metavar="DELAYTIME"  
		      )
    parser.add_option("--netrc",     # implies dest="switch"
                      action="store", # default: None
                      type="string",  # OptionParser's default
                      help="read user name and password from .netrc file "+\
                           "at the given MACHINE entry. If the host is not "+\
                           "specified otherwise, MACHINE is taken as hostname.",
                      metavar="MACHINE",
                      )
    parser.add_option("--netrc-line",  # implies dest="nodelete"
                      action="store_true", # default: None
                      help="print the line that would have to be "+\
                           "added to the .netrc file for the given "+\
                           "username and password", 
                      )
    parser.add_option("--timeout", 
                      action="store", 
		      type="string",  
                      help="specify the TIMEOUT for telnet, "+\
                           "default: %s" % default_timeout,
		      metavar="TIMEOUT"  
		      )
    x= sys.argv
    (options, args) = parser.parse_args()
    # options: the options-object
    # args: list of left-over args

    if options.summary:
        print_summary()
	sys.exit(0)

    if options.test:
        _test()
        sys.exit(0)

    if options.doc:
        print_doc()
        sys.exit(0)

    process(options,args)
    sys.exit(0)

if __name__ == "__main__":
    main()

