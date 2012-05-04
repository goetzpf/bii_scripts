#! /usr/bin/env python
# -*- coding: UTF-8 -*-

from optparse import OptionParser
#import string
import os.path
import sys
import telnetlib
import time

# version of the program:
my_version= "1.0"

default_delay= 0
default_timeout= 5

def read_until(tn, expected, timeout= None):
    """read from telnet connection until a special string is found."""
    args= [expected]
    if timeout is not None:
        args.append(timeout)
    st= tn.read_until(*args)
    if not st.endswith(expected):
        tn.close()
        raise AssertionError, "unexpected reply:\n%s\n" % st

def login(ioc, loginname, loginpassword, timeout):
    """login on an ioc."""
    if sys.version_info < (2,6):
        tn= telnetlib.Telnet(ioc)
    else:
        tn= telnetlib.Telnet(ioc, timeout= timeout)
    read_until(tn, "VxWorks login: ", timeout= timeout)
    tn.write(loginname+"\n")
    read_until(tn, "Password: ", timeout= timeout)
    tn.write(loginpassword+"\n")
    read_until(tn, "> ", timeout= timeout)
    return tn

def tran(st,k):
    return "".join([chr(ord(x)^k) for x in st])

def t(st):
    return tran(st, ord(__file__[-1]))

def reboot(ioc_spec, timeout, dry_run= False):
    """reboot an IOC by issuing ctrl-x on the command line.

    ioc_spec: ioc:user:password
              user and password are optional
    """
    default_password= t('\x0f\x01\x1b\x1c\n\n\x00K')
    default_login_data= [ 
                          ("ioc",   default_password),
                          ("epics", default_password),
                        ]
    l= ioc_spec.split(":")
    if len(l)>1:
        usr= l[1]
        pw= default_password
        if len(l)>2:
            pw= l[2]
        default_login_data= [ (usr, pw) ]
    success= False
    tn= None
    if dry_run: 
        print "reboot %s:" % l[0]
    for (usr,pw) in default_login_data:
        try:
            if dry_run:
                if pw==default_password:
                    p="******"
                else:
                    p=pw
                print "\ttry to login as %s:%s" % (usr,p)
            else:
                tn= login(l[0], usr, pw, timeout)
                success= True
                break
        except AssertionError, e:
            pass
    if (not success) and (not dry_run):
        raise AssertionError, "login on host %s failed" % l[0]
    if not dry_run:
        tn.write("reboot\n")
        # for mysterious reasons sending "\x18" (ctrl-x) doesn't work ...
    if dry_run:
        print "\tsleep 2 seconds"
    time.sleep(2.0)
    # without the delay the IOC goes in a state where it is still 
    # running but the network connection is broken
    if not dry_run:
        tn.close()
    else:
        print

def process(options,args):
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
        reboot(spec, timeout, options.dry_run)
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
    parser.add_option("--dry-run",  
                      action="store_true", 
                      help="just print what the program WOULD do.",
		      )
    parser.add_option("-d", "--delay", 
                      action="store", 
		      type="int",  
                      help="specify DELAYTIME before the reboots of"+\
                           "more than one ioc, the default is %d." % \
                           default_delay,
		      metavar="DELAYTIME"  
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

    process(options,args)
    sys.exit(0)

if __name__ == "__main__":
    main()

