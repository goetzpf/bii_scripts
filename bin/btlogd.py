#!/usr/bin/env python
# -*- coding: UTF-8 -*-

"""
=========================================
btlogd.py
=========================================
------------------------------------------------------------------------------
beam time logging deamon
------------------------------------------------------------------------------

Overview
========
This deamon has to grab the beam shutter activities and save the beamtimestamps
into the database. It is the new way for generating statistics over the
machine.

Quick reference
===============

Reference of commandline argOptionList
================================

-t, --test
   perform a self-test for some functions

--doc
   print a restructured Text documentation
   use: "db_request.py --doc | rst2html" for a HTML output
"""

import sys, os, time
from signal import SIGTERM
import adodb
import EpicsCA

class monPV :
    """
    Create a monitored PV,

    - setup the PV, or throw any ca.caError
    - access the updated value
    - set/read event flag
    """

    def __init__(self, pv, Type=-1):
        self.val = None
        self.event = False
        def myCB(ch,val):
            self.val = val
            self.event = True
        ca.Monitor(pv,myCB)

    def get(self):
        """
        - o.get()     Return: PV.VAL
        """
        if self.val != None :
            return self.val[0]
        else :
            return None

    def getAll(self):
        """
        - o.getAll()  Return: (VAL,STAT,SEVR,TS)
        """
        return self.val

    def testEvent(self) :
        """
        o.testEvent() Return: True if any monitor occured since last call of testEvent() or False if not
        """
        if self.event == True :
            self.event = False
            return True
        else :
            return False


def deamonize(stdout='/dev/null', stderr=None, stdin='/dev/null',
              pidfile=None, startmsg = 'started with pid %s' ):
    '''
        This forks the current process into a daemon.
        The stdin, stdout, and stderr arguments are file names that
        will be opened and be used to replace the standard file descriptors
        in sys.stdin, sys.stdout, and sys.stderr.
        These arguments are optional and default to /dev/null.
        Note that stderr is opened unbuffered, so
        if it shares a file with stdout then interleaved output
        may not appear in the order that you expect.
    '''
    # Do first fork.
    try:
        pid = os.fork()
        if pid > 0: sys.exit(0) # Exit first parent.
    except OSError, e:
        sys.stderr.write("fork #1 failed: (%d) %s\n" % (e.errno, e.strerror))
        sys.exit(1)

    # Decouple from parent environment.
    os.chdir("/")
    os.umask(0)
    os.setsid()

    # Do second fork.
    try:
        pid = os.fork()
        if pid > 0: sys.exit(0) # Exit second parent.
    except OSError, e:
        sys.stderr.write("fork #2 failed: (%d) %s\n" % (e.errno, e.strerror))
        sys.exit(1)

    # Open file descriptors and print start message
    if not stderr: stderr = stdout
    si = file(stdin, 'r')
    so = file(stdout, 'a+')
    se = file(stderr, 'a+', 0)
    pid = str(os.getpid())
    sys.stderr.write("\n%s\n" % startmsg % pid)
    sys.stderr.flush()
    sys.stdout.flush()
    if pidfile: file(pidfile,'w+').write("%s\n" % pid)
    # Redirect standard file descriptors.
    os.close(sys.stdin.fileno())
    os.close(sys.stdout.fileno())
    os.close(sys.stderr.fileno())
    os.dup2(si.fileno(), sys.stdin.fileno())
    os.dup2(so.fileno(), sys.stdout.fileno())
    os.dup2(se.fileno(), sys.stderr.fileno())

def startstop(stdout='/dev/null', stderr=None, stdin='/dev/null',
              pidfile='pid.txt', startmsg = 'started with pid %s' ):
    if len(sys.argv) > 1:
        action = sys.argv[1]
        try:
            pf  = file(pidfile,'r')
            pid = int(pf.read().strip())
            pf.close()
        except IOError:
            pid = None
        if 'stop' == action or 'restart' == action:
            if not pid:
                mess = "Could not stop, pid file '%s' missing.\n"
                sys.stderr.write(mess % pidfile)
                sys.exit(1)
            try:
               while 1:
                   os.kill(pid,SIGTERM)
                   time.sleep(1)
            except OSError, err:
               err = str(err)
               if err.find("No such process") > 0:
                   os.remove(pidfile)
                   if 'stop' == action:
                       sys.exit(0)
                   action = 'start'
                   pid = None
               else:
                   print str(err)
                   sys.exit(1)
        if 'start' == action:
            if pid:
                mess = "Start aborded since pid file '%s' exists.\n"
                sys.stderr.write(mess % pidfile)
                sys.exit(1)
            deamonize(stdout,stderr,stdin,pidfile,startmsg)
            return
    print "usage: %s start|stop|restart" % sys.argv[0]
    sys.exit(2)

def test():
    '''
        This is an example main function run by the daemon.
        This prints a count and timestamp once per second.
    '''
    sys.stdout.write ('%s Initializing...\n' % (time.ctime(time.time())))
    sys.stdout.flush()
    #sys.stderr.write ('Message to stderr...')
    epxCurrent = monPV('MDIZ3T5G:current')
    epxLifetime = monPV('MDIZ3T5G:lt50')
    epxBeamshutter = monPV('PSIRC:SBR:BSLOCKIN')
    epxBeamshutter.myCB(self)
    c = 0
    while 1:
        if epxBeamshutter.testEvent():
            what = epxBeamshutter.get()
            if what == "Locked":
                sys.stdout.write ('%d %s: Beamshutter locked I=%s, t=%s\n' % (c, time.ctime(time.time()), "§§§", "%%%") )
                sys.stdout.flush()
            else:
                sys.stdout.write ('%d %s: Beamshutter unlocked I=%s, t=%s\n' % (c, time.ctime(time.time()), "§§§", "%%%") )
                sys.stdout.flush()
        c = c + 1
        sys.stdout.write ('%d I=%s, t=%s\n' % (c, epxCurrent.get(), epxLifetime.get()) )
        sys.stdout.flush()
        time.sleep(1)

if __name__ == "__main__":
    startstop(stdout='/tmp/btlogd.log', stderr='/tmp/btlogd.log', pidfile='/tmp/btlogd.pid')
    test()