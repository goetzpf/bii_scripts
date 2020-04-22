#!/usr/bin/env python2
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

from optparse import OptionParser
import os
import sys
import netrc

_no_check= len(sys.argv)==2 and (sys.argv[1] in ("-h","--help","--summary"))
try:
    import pexpect
except ImportError:
    if _no_check:
	sys.stderr.write("WARNING: (in %s) mandatory module pexpect not found\n" % \
			 sys.argv[0])
    else:
	raise

assert sys.version_info[0]==2

my_version= "1.0"

def parse_mail_addr(st):
    """parse a mail address name@host."""
    i= st.find("@")
    if i<0:
        return None
    return (st[0:i],st[i+1:])

def process(options,args):
    """do the ssh command."""
    def chk_conflict(key,*args):
        """check if a key is defined multiple times."""
        defined= False
        for a in args:
            if a.get(key) is not None:
                if not defined:
                    defined= True
                else:
                    sys.exit("error, multiple definition of \"%s\"" % key)
    def fill(mandatory,key,main,*args):
        """fill a dict with contents from other dicts."""
        if main[key] is not None:
            return
        for a in args:
            v= a.get(key)
            if v is None:
                continue
            main[key]= v
            return
        if main[key] is None:
            if mandatory:
                sys.exit("error, \"%s\" not specified" % key)

    par_netrc= {}
    par_options= {}
    par_args= {}

    if options.netrc:
        n= netrc.netrc()
        tp= n.hosts.get(options.netrc)
        if tp is None:
            sys.exit("machine name \"%s\" not found in .netrc file" % options.netrc)
        par_netrc={"host":options.netrc,"user":tp[0],"password":tp[2]}

    if len(args)>0:
        tp= parse_mail_addr(args[0])
        if tp is not None:
            par_args= {"user":tp[0],"host":tp[1]}
            args= args[1::]

    par_options["user"]    = options.user
    par_options["password"]= options.password
    par_options["host"]    = options.host

    # check conflicts:
    chk_conflict("user"    ,par_options,par_args)
    chk_conflict("host"    ,par_options,par_args)
    chk_conflict("password",par_options,par_netrc)

    # fill up missing parts:
    fill(True ,"user",par_options,par_args,par_netrc)
    fill(True ,"host",par_options,par_args,par_netrc)
    fill(False,"password",par_options,par_args,par_netrc)

    argstr= "%s@%s %s" % (par_options["user"],
                          par_options["host"],
                          " ".join(args))
    if options.ssh_A:
        argstr= "-A "+argstr
    if options.ssh_args:
        argstr= options.ssh_args+" "+argstr
    if options.dry_run:
        print "ssh %s" % argstr
        sys.exit(0)
    if options.timeout is None:
        timeout= 5
    else:
        timeout= options.timeout
    child= pexpect.spawn("ssh %s" % argstr, timeout=timeout)
    waiting= True
    while waiting:
        try:
            i= child.expect(['[Pp]assword:','yes/no\)\?'])
            if i==0:
                child.sendline(par_options["password"])
                waiting= False
            elif i==1:
                child.sendline('yes')
        except pexpect.EOF:
            # no password request, just print the 
            # output so far and exit:
            print child.before
            sys.exit(0)
    child.expect(pexpect.EOF)
    print child.before
    sys.exit(0)

def script_shortname():
    """return the name of this script without a path component."""
    return os.path.basename(sys.argv[0])
          
def print_summary():
    """print a short summary of the scripts function."""
    print "%-20s: ssh with password as a commandline option\n" % script_shortname()

def main():
    """The main function.
    
    parse the command-line options and perform the command
    """
    # command-line options and command-line help:
    usage = "usage: %prog [options] {host|user@host} {commands}"
    parser = OptionParser(usage=usage,
                          version="%%prog %s" % my_version,
                          description="execute a command on a foreign host "+\
                                      "via ssh. The password (if needed) can "+\
                                      "be specified as a parameter or by the "+\
                                      ".netrc file.")
    parser.add_option("--summary",  # implies dest="nodelete"
                      action="store_true", # default: None
                      help="print a summary of the function of the program", 
                      )

    parser.add_option("--dry-run",     # implies dest="switch"
                      action="store_true", # default: None
                      help="just show the ssh command",
                      )
    parser.add_option("--netrc",     # implies dest="switch"
                      action="store", # default: None
                      type="string",  # OptionParser's default
                      help="read user name and password from .netrc file "+\
                           "at the given MACHINE entry. If the host is not "+\
                           "specified otherwise, MACHINE is taken as hostname.",
                      metavar="MACHINE",
                      )
    parser.add_option("-A","--ssh-A",     # implies dest="switch"
                      action="store_true", # default: None
                      help="just call ssh with \"-A\"",
                      )

    parser.add_option("-u","-l", "--user", # implies dest="file"
                      action="store", # OptionParser's default
                      type="string",  # OptionParser's default
                      help="specify the USER", 
                      metavar="USER"  # for help-generation text
                      )
    parser.add_option("-P", "--password", # implies dest="file"
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
    parser.add_option("--ssh-args", # implies dest="file"
                      action="store", # OptionParser's default
                      type="string",  # OptionParser's default
                      help="specify extra SSH-ARGUMENTS for the ssh-call", 
                      metavar="SSH-ARGUMENTS"  # for help-generation text
                      )

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

