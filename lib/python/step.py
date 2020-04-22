# -*- coding: utf-8 -*-

# Copyright 2015 Helmholtz-Zentrum Berlin für Materialien und Energie GmbH
# <https://www.helmholtz-berlin.de>
#
# Author: Bernhard Kuner <bernhard.kuner@helmholtz-berlin.de>
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

import re
import ca
import time
import sys
import string
import signal
import pfunc
from types import FunctionType
from optparse import OptionParser
import threading
import atexit
import os
import pprint, StringIO
#from traceback import *
"""
step.py - Configurable Measure Program
****************************************

"""

assert sys.version_info[0]==2

my_version = "1.1"
lock = threading.Lock()

def warnSh(warnStr): 
    print warnStr

# Global warn function, should be set to msg-window by GUI
warnfuncArr = [warnSh]

def setWarnFunc(func):
    warnfuncArr[0] = func

def warnFunc(msg):
    warnfuncArr[0](msg)

def Dumper(x):
    s = StringIO.StringIO()
    pprint.pprint(x, s)
    return s.getvalue()
 
class SaveRestore(object):
    """
    Save and Restore original values of all caput() commands.
    """ 
    caputStore = {}
    def __init__(self) :
        pass
                
    @staticmethod
    def isEmpty():
        print SaveRestore.caputStore.keys()
        if SaveRestore.caputStore: return False
        return True
    @staticmethod
    def save(pv): 
        """
        """
#       print "SaveRestore check:", pv
        if SaveRestore.caputStore.has_key(pv): 
            return
        val = caget(pv)
#       print "\tadd:", pv,val
        SaveRestore.caputStore[pv] = val

    @staticmethod
    def restore(pvName):
        chSet = ca.channel(pvName)
        chSet.wait_conn(dt=0.1,wait=10)
        val = SaveRestore.caputStore[pvName]
#       print "SaveRestore restore:", pvName,val, chSet
        caput(val,chSet)
        del SaveRestore.caputStore[pvName]
    @staticmethod
    def restoreAll(verbose=None):
        if verbose is not None: print "SaveRestore.restoreAll",SaveRestore.caputStore
        for pv in sorted(SaveRestore.caputStore.keys()):
            SaveRestore.restore(pv)
    
#    def get(self,x): 
#       return "%-25s %s" % (x,SaveRestore.caputStore[x])
#    def getStore(self):
#       """
#       get list of all stored pvs: PV   VALUE to be used for printing or listBox
#       """
#       ret = map(get(x),sorted(SaveRestore.caputStore.keys()))
#    def writeFile(self,filename):
#       try:
#           os.rename(filename,filename+".OLD")
#           f = open("step.sto",'w')
#           for key in sorted(SaveRestore.caputStore.keys()):
#               f.write(get(key)+"\n")
#           f.close()
#           os.unlink(filename+".OLD")
#       except IOError:
#           return False
#       return True
#
#    def readFile(self,filename):
#       """
#       Read a store from File and set the static readStore variable. 
#
#       Raise: ValueError if there is a line that don't match the PV-Value reg. exp.
#
#       Return: True or False if there is a IOEror
#       """             
#       re_parseLine = re.compile('^\s*([\w\d_-]+)\s*([\.\w\d_-]+)')
#       readStore = {}
#       try:
#           f = open("step.sto",'r')
#           for line in f:
#               p = re_parseLine.match(line)
#               if p is None: raise ValueError
#               pv = p.group(0)
#               val= p.group(1)
#               readStore[pv] = val
#           f.close()
#       except IOError:
#           return None
#       SaveRestore.caputStore = readStore
#       return True

################################################################################
#
#  Base functions for channel access (module ca)
#  ============================================
#
def caExist(chName) :
    """
    Return: True if chName is found, otherwise False
    """
    try :
        ch = ca.channel(chName)
        ch.wait_conn(dt=0.1,wait=10)
        return True
    except ca.caError,e:
        return False
    
def caput(val,chSet) :
    """
    Primitive channel access functions provide for exception handling
    and communication with the thread of the ca-module

    pvs will be setup and hold in a dictionary within ca-module
    
    Example:
    
        try:
            chSet = ca.channel(pvName)
            chSet.wait_conn(dt=0.1,wait=10)
        except ca.caError,e:
            return False
        caput(value,chSet)
        return True
    """
    try :
        lock.acquire();
        chSet.put(val)
        chSet.flush()
    except ca.caError,e:
        warnFunc( "caput ERROR: '"+chSet.name+"': "+e.__doc__)
        lock.release()
        return False
    else :
        lock.release()
        return True

def caget(pv,dbrTtype=-1):
    """
    see caput(), 
    """
    try :
        lock.acquire();
        val = ca.Get(pv,Type=dbrTtype)
    except ca.caError,e:
        warnFunc( "caget ERROR: '"+pv+"': "+e.__doc__)
        val = None
    lock.release()
    return val

cadiffPVs = {}
def cadiff(pv,dbrTtype=-1):
    """
    Return the difference value of consecutive calls of a PV OR 
    None for the first call or ca-error. This works for multiple PVs! see also caput
    """
    try :
        now = ca.Get(pv,Type=dbrTtype)
    except ca.caError,e:
        warnFunc( "cadiff ERROR: '"+pv+"': "+e.__doc__)
        return None
    else :
        if cadiffPVs.has_key(pv) :
            before = cadiffPVs[pv]
            diff = now - before
        else :
            diff = None         # first call - just define the before value
        cadiffPVs[pv] = now
        return diff

class monPV :
    """
    Create a monitored PV, 

    - setup the PV, or throw any ca.caError
    - access the updated value
    - set/read event flag
    """ 
    def __init__(self, pv,Type=-1):
        self.val = None
        self.event = False
        def myCB(ch,val) : 
            self.val = val
            self.event = True
        ca.Monitor(pv,myCB)
    def get(self) : 
        """
        - o.get()     Return: PV.VAL
        """
        if self.val != None : 
            return self.val[0] 
        else : 
            return None
    def getAll(self) : 
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

################################################################################
#
#  The classes that provide functions to set PVs in the measure loop
#  ============================================
#
class anyLoopPV(object):
    """
    Base class for loop PVs
    """
    def __init__(self, name):
        """
        Base init two variables: 
        
        - self.setVal: the last set value (init to None)
        - self.pvName: the PV name, but no channel access initialisation of it!
        
        If there exists a global saveRestObj (class saveRestore),store the value
        of this PV before it is set by the program.
        """
#       print "anyLoopPV.__init__(",name,")"
        if name == "":
            raise exceptions.ValueError, name
        self.setVal = None
        self.pvName  = name
        sr = None
        try:
            sr = saveRestObj
        except NameError:
#           print  "NameError saveRestObj"
            return
        else:
#           print "\tsr.save(",name,")"
            sr.save(name)
    def __str__(self) : 
        return str(self.toDict())
    def toDict(self):
        """
        Dictionary representation of the object
        """
        return {'TYPE':'anyLoopPV_DUMMY','PV':self.pvName}
    def get(self) : 
        """
        Get the active set value
        """
        return self.setVal
    def set(self, val) :
        """
        Set the PV
        """
        self.setVal = val
#       print "anyLoopPV.set(",self.pvName,",",self.setVal,")"
class setPV(anyLoopPV) :
    """
    Establish a PV and provide for a set(val) function.
    See also Ducktypes (motorPV)
    """
    def __init__(self, name):
        """
        Create a motor object and setup all PVs, monitors to operate this motor.
        """
        anyLoopPV.__init__(self,name)
        self.chSet= None
        self.chSet = ca.channel(self.pvName)
        self.chSet.wait_conn(dt=0.1,wait=10)

    def toDict(self):
        return {'TYPE':'PV','PV':self.pvName}
    def set(self, val) :
        self.setVal = val
        caput(val,self.chSet)

class motorPV(anyLoopPV) :
    """
    Is Ducktype of class setPV to define access for a stepper motor via motorRecord
    """
    def __init__(self, motor):
        """
        Create a motor object and setup all PVs, monitors to operate this motor.
        """
        anyLoopPV.__init__(self,motor)

        chSet = None
        chSetCmd = None
        # Setup motor PVs
        self.chSet = ca.channel(self.pvName)
        self.chSet.wait_conn(dt=0.1,wait=10)
        self.chSetCmd = ca.channel(self.pvName + ":cmdHome")
        self.chSetCmd.wait_conn(dt=0.1,wait=10)
        self.lvio =   monPV(self.pvName + ".LVIO")
        self.dmov =   monPV(self.pvName + ".DMOV")
        self.rbv =    monPV(self.pvName + ".RBV")
        self.lls =    monPV(self.pvName + ".LLS")
        self.hls =    monPV(self.pvName + ".HLS")
        self.stShow = monPV(self.pvName + ":stShow",Type=1)

    def toDict(self):
        return {'TYPE':'MOTOR','PV':self.pvName}
    def set(self, pos, Wait=True) :
        """
        Move this motor to the position and wait if has reached it. Break for
        limit violations (motor.LVIO)
        
        Wait==True: optional parameter True means wait until move is done, False means fire and forget.
        """
#       try :
        self.chSet.put(pos)
        self.setVal = pos
        self.dmov.testEvent()   # clear event flag
        self.chSet.flush()
        if Wait == True:
            while self.dmov.testEvent() == False:
                if self.lvio.get() == 1:
                    raise ValueError, "lvio"
            while self.dmov.get() == 0:
                if self.lvio.get() == 1:
                    raise ValueError, "lvio"
#       except ca.caError,e:
#           warnFunc( "motorPV Error: '"+self.chSet.name+": "+e.__doc__)
#       except ValueError:
#           warnFunc( "motorPV Error: '"+self.pvName+"LVIO ERROR - move run into soft limit for pos="+str(pos))

    def home(self) :
        """
        Call sequencer moho home routine and wait until done or timeout
        """
        try :
            chSetCmd.put(1)
            chSetCmd.flush()
            t1 = time.time()
            while self.stShow.get() != 6 : # 6=DONE
                time.sleep(0.3)
                if self.stShow.get() == 7: # 7=ABBORT
                    warnFunc("motorPV Error: '"+self.pvName+"moho ABBORT, stShow="+self.stShow)
                    break
        except ca.caError,e:
            warnFunc( "motorPV Error: '"+self.pvName+": "+e.__doc__)

class funcPV(anyLoopPV):
    """
    Create a set PV object. calculate the set value from the loop-set value (variable 'x')
    by a free defined function. e.g. sqare by func = "x*x"
    """
    def __init__(self, name,func):
        anyLoopPV.__init__(self,name)
        self.chSet = None
        self.chSet = ca.channel(self.pvName)
        self.chSet.wait_conn(dt=0.1,wait=10)
        self.func  = func
        if func is not None: self.setFunc(func)
    def toDict(self):
        return {'TYPE':'FUNC','PV':self.pvName,'FUNC':self.func}
    def setFunc(self, f) :
        self.func = f
    def set(self, x) :
        try:
            fVal = eval(self.func)
        except SyntaxError, e:
            raise SyntaxError(" "+self.pvName+" has illegal Function: \n'"+self.func+"'")
         
        self.setVal = fVal
        caput(fVal,self.chSet)

class linPV(anyLoopPV):
    """
    Define a linear function: Set the pv from begin to end value in this loop
    """
    def __init__(self, name,begin,end,loop):
        anyLoopPV.__init__(self,name)

        if type(begin) is not float: begin=float(begin)
        if type(end) is not float: end=float(end)
        self.chSet = None
        self.chSet = ca.channel(self.pvName)
        self.chSet.wait_conn(dt=0.1,wait=10)
        self.loop = loop
        self.begin = begin
        self.end = end

    def toDict(self):
        return {'TYPE':'LINEAR','PV':self.pvName,'BEGIN':self.begin,'END':self.end}
    def set(self, val) :
        if self.loop.incVal == 0: raise ZeroDivisionError
        steps = (self.loop.toVal - self.loop.fromVal) / self.loop.incVal
        step  = (val - self.loop.fromVal) / self.loop.incVal
        if steps == 0: raise ZeroDivisionError
        fVal = (self.end-self.begin) * step/steps + self.begin
        self.setVal = fVal
        caput(fVal,self.chSet)
   
################################################################################
#
#  Definition of a measure loop
#  ============================================
#
class loopPv(object):
    """
    Handle the loop parameters from - to - increment and all PVs to be set
    
    - hold the loop parameters
    - RAISE 'ValueError' if one of the parameters fromVal, toVal, incVal, delay is not float convertable
                         if incVal == 0
    - add PVs to be set from the loop by method addPv
    
    - hold the parsed parameters for the breakIf and nextIf functions to be executed in 
      MeasThread by the function procFunc(n)

    EXAMPLE:
        { 'FROM': -1.0, 'TO': 11.0, 'INC': 2.0, 'DELAY': 1.0
          'PVS':   [{'PV': 'motest:mo0', 'TYPE': 'MOTOR'}, 
                    {'PV': 'motest:mo1', 'TYPE': 'PV'}, 
                    {'PV': 'motest:mo2', 'TYPE': 'FUNC', 'FUNC': 'x*x'}, 
                    {'PV': 'motest:mo3', 'BEGIN': 10, 'TYPE': 'LINEAR', 'END': 20} ]
        }
    """
    def __init__(self, argDict):
        """
        init the ca objects for the PVfrom the data dictionary
        """
        
        if type(argDict) is not dict: raise TypeError

        self.setPv     = [] # added by self.addPv() method
        self.fromVal = float(argDict['FROM'])
        self.toVal =   float(argDict['TO'])
        self.delay =   float(argDict['DELAY'])
        self.incVal =  float(argDict['INC'])
        self.stepNr = 0

        
        if self.incVal == 0: raise ValueError
        if self.fromVal == self.toVal: raise ValueError
        if self.fromVal > self.toVal and self.incVal > 0:
            self.incVal = -1 * self.incVal

        if self.fromVal < self.toVal and self.incVal < 0:
            self.incVal = -1 * self.incVal

        self.incSteps = int((self.toVal-self.fromVal)/self.incVal) + 1 # + 1 because the begin is also a step!
        
        if argDict.has_key('PVS') : 
            for p in argDict['PVS']: self.addPv(p)


    def __str__(self) :
        brk = ", loopFunc: "
        return Dumper(self.toDict())

    def __repr__(self) :
        return Dumper(self.toDict())

    def toDict(self):
        loopDict = { 'FROM': self.fromVal,
                     'TO':   self.toVal,
                     'DELAY':self.delay,
                     'INC':  self.incVal,
                   }
        if len(self.setPv) > 0:       loopDict['PVS']   = map(lambda x: x.toDict(), self.setPv)
        return loopDict

    def addPv(self,pvDict):
        """
        Tries to create a kind of setPV object, depending on the self.Type parameter.
        Return True or False, if PV is not found
        """
        pvName = pvDict['PV'] 
        if pvDict['TYPE'] == 'MOTOR' :
            self.setPv.append(motorPV(pvName))
        elif pvDict['TYPE'] == 'PV' :
            self.setPv.append(setPV(pvName))
        elif pvDict['TYPE'] == 'FUNC' :
            self.setPv.append(funcPV(pvName,pvDict['FUNC']))
        elif pvDict['TYPE'] == 'LINEAR' :
            self.setPv.append(linPV(pvName,pvDict['BEGIN'],pvDict['END'],self))
        else :
            warnFunc("loopPv: Illegal PV Type :"+Type+ " for:"+setPvName)
            return False
        return True
            
    def getPvNames(self):
        """
        Return a list of all current PV names for set values of this loop
        """
        return map(lambda x: x.pvName,self.setPv)
    def getSetValues(self):
        """
        Return a list of all current set values of this loop
        """
        return map(lambda x: str(x.setVal),self.setPv)

################################################################################
#
#  Handle PVs and data to be measured:
#  ============================================
#
class measurePvs(object) :
    """
    Handle PVs and data to be measured:
    
    - init a list of channel access objects with the PV names
    - printHeader(), printVals() method to print to screen or string 
    - hold the list of all measured data
    - Need the list of set PVs to be shown

          'BREAK': ('PVname','condition')
          'NEXT':  ('PVname','condition')
    """
    def __init__(self,argDict=None):
        """
        init the ca objects for the PVs to be measured

        Parameters:
            
            measPvNames,     list of PV names to be measured
        """
#       print "Create: measurePvs(",measPvNames,")"
        self.hItemWidths = []
        self.chansCa = []   # ca channels for the pvs to be measured

        self.chanNames = [] # names of the measured PVs
        self.chanVals = []  # last measured data
        self.timestamp = None   # timestamp of the last measured data, set as tupel of (YYYY, MM, DD, HOUR, MIN, SEC)
        self.hasTimestamp = False
        self.breakPar = None
        self.nextPar  = None
        self.measData = []  # store of all measured data
        self.fileName = None# commandline call needs a place to store the filename to be written after loop ends
        self.loopList = [] # point to the looplist. Get pv names and set values from there
        self.loopType = 'ONCE'
        
        if argDict is None: return
        if (argDict.has_key('TIMESTAMP') is True): self.hasTimestamp=argDict['TIMESTAMP']
        if argDict.has_key('BREAK') : self.breakPar = parseFuncParameter(argDict['BREAK'])
        if argDict.has_key('NEXT') : self.nextPar = parseFuncParameter(argDict['NEXT'])
        if argDict.has_key('LOOPS'):
            for loopDict in argDict['LOOPS']:
                try:
                    l = loopPv(loopDict)
                    self.loopList.append(l)
                except Exception, e:
                    warnFunc("Loop ERROR can't create Loop:\n"+str(loopPv(loopDict))+"\nException:\n"+str(e) )
        if argDict.has_key('MEASURE'):
            for cn in argDict['MEASURE'] :
                self.addPv(cn)
        if argDict.has_key('LTYPE') and len(argDict['LTYPE']) > 0:
            self.loopType = argDict['LTYPE']

    def __str__(self) :
        return "measurePvs:\n"+str(self.chanNames) + "\nloops:\n" + str(self.loopList)
        
    def toDict(self):
        mPvsDict = {'LTYPE': self.loopType,'TIMESTAMP':self.hasTimestamp}
        if len(self.chanNames) > 0: mPvsDict['MEASURE'] = self.chanNames
        if self.breakPar is not None: mPvsDict['BREAK'] = ''.join(self.breakPar)
        if self.nextPar  is not None: mPvsDict['NEXT']  = ''.join(self.nextPar)
        if len(self.loopList) > 0: mPvsDict['LOOPS']    = self.loopList
        
        return mPvsDict

    def setPvList(self,chList,hasTs):
        self.hasTimestamp = hasTs
        del(self.chanNames)
        self.chanNames=[]
        del(self.chansCa)
        self.chansCa=[]
        del(self.chanVals)
        self.chanVals=[]
        map(lambda x: self.addPv(x),chList)
        self.clearData()

    def delPv(self,chName):
        """
        Delete a pv to be measured.
        Return None if done, errStr if failed (chName don't exist in chanNames list)
        """
        errStr = None
        #print "\tdelPv:",chName
        try :
            while(1):
                idx = self.chanNames.index(chName)
                #print "delPv",chName, idx,self.chanNames[idx]
                del(self.chanNames[idx])
                del(self.chansCa[idx])
                del(self.chanVals[idx])
        except ValueError,e:
            warnFunc( chName+" not found")

    def addPv(self,chName):
        """
        Create and store a ca.channel for this pv to be measured.
        Return None if done, errStr if failed (pv don't exist)
        """
        errStr = None
        try :
            ch = ca.channel(chName)
            ch.wait_conn(dt=0.1,wait=10)
            self.chansCa.append(ch)
            self.chanVals.append(None)  # default each value to None
            self.chanNames.append(chName)
        except ca.caError,e:
            warnFunc("Measure '"+chName+"': "+e.__doc__)

    def printHeader(self,toString=False,joinStr=" | ") :
        """
        Print a header with the PV names to the measured values to screen 
        and file if paramter fileName is set.(commandline mode of the progeam).
        """
        Items = self.getPvNames()
        for item in Items:
            strLen = len(item)
            if strLen < 15: strLen = 15
            self.hItemWidths.append(strLen)
        header = joinStr.join( map(lambda x:("%%%ds"%x[0])%x[1],zip(self.hItemWidths,Items)) )
        if toString == False: 
            print header
        return header
    
    def printVals(self,toString=False,joinStr=" | ") :
        """
        Print the measured values to screen and file if paramter fileName is set..
        (commandline mode of the progeam)
        """
        Items = self.getVals()
        itemStrs = []
        for (width,item) in zip(self.hItemWidths,Items):
            if type(item) is float:
                l = ("%%%d.3g"%width)%item
            elif type(item) is str:
                l = ("%%%ds"%width)%item
            itemStrs.append(l)
        line = joinStr.join(itemStrs)
        if toString == False: 
            print line
        return line
    def writeData(self,filename=None) :
        """
        Write a Header and all measured data to the file.
        Raise IOError, if file can't be opened
        """
        if len(self.measData) == 0: raise ValueError
        if filename == None and self.fileName is not None:
            f = open(self.fileName,"a")
        else :
            f = open(filename,"a")

        line = self.printHeader(True,"\t")
        f.write( "# "+time.strftime("%d.%m.%y %H:%M",time.localtime())+"\n")
        f.write( "# "+line +"\n")
        for Items in self.measData:
            line = "\t".join(map(lambda x: ("%%%ds"%x[0])%x[1],zip(self.hItemWidths,Items)))
            f.write(line+"\n")
        f.close()
    def clearData(self) :
        """
        Clear the buffer of stored data
        """
        self.measData = []

    def setFileName(self,fileName): self.fileName=fileName

    def getPVs(self):
        """
        Read the values of the PVs to be meausred from channel access
        """
        if self.hasTimestamp is True:
            self.timestamp = time.localtime() [0:6]
        if len(self.chansCa) <= 0:
            return
        try :
            for ch in self.chansCa: 
                ch.get()
            self.chansCa[0].pend_event(1)
        except ca.caError,e:
            return
        self.chanVals = map(lambda x: x.val,self.chansCa)

        self.measData.append(self.getVals()[:])
        
    def getVals(self):
        """
        return string list of timestamp, actual set values for all set-Pvs in the loopList 
        and the measured values.
        """
        Items = []
        if self.hasTimestamp is True:
            timestr = str(self.timestamp[1])+"/"+str(self.timestamp[2])+"/"+str(self.timestamp[0])+" "+str(self.timestamp[3])+":"+str(self.timestamp[4])+":"+str(self.timestamp[5])
            Items.append(timestr)
        for l in self.loopList: Items += l.getSetValues()
        Items += map(lambda x: str(x), self.chanVals)
        return Items
    def getPvNames(self):
        """
        return list of timestamp-tag, actual set pv names for all set-Pvs in the loopList and 
        the measured pvs:
        
              Time            | Loop1     | Loop2 ..| Measured 
                              |           |         |
          2009.02.24 15:34:22 | [ PV1 PV2 | PV3 PV4 | PV5  PV6...]
        """
        Items = []
        if self.hasTimestamp is True:
            Items.append("Time               ")
        for l in self.loopList: Items += l.getPvNames()
        Items += self.chanNames
        return Items

################################################################################
#
#  Mesure loop dependant stuff
#  ============================================
#
class MeasThread(object):
    """
    The Measure Thread - A temporary object to perform a multi dimensional measurement
    
    - create a thread to do this measurement
    - runLoop() function will set read the pvs. It is configured by the classes loopPv measurePvs
    - There are methods for start, stop and pause
    - There may be defined nextifFunc and breakifFunc to skip set pvs or to stop measurement
      (see functions: parseFuncParameter(), procFunc() and class loopPv
    """

    def __init__(self,mPvs,win=None):
        """
        Create a thread with the runLoop function - but don't start it!
        """
        # make shure that the mPvs loop list is not one from a previous run! 
        self.mPvs = mPvs
        if mPvs.loopList is None:
            raise ValueError("MeasThread:_init_ gets no LoopList")
        self.strToRunControl = {'INAKTIVE':-1,'START':0, 'PAUSE':1,'STOP':2}
        self.runControlToStr = {-1:'INAKTIVE',0:'START', 1:'PAUSE',2:'STOP'}

        self.updateViewFunc = None
        self.printCallback = None
        #print "Start Measure with:",mPvs.toDict()
        def doneCB(idx,state) :
            win.loopCB(idx,state)
        def printCB() :
            win.setNextLine()
        if win is not None: 
            self.updateViewFunc = doneCB
            self.printCallback = printCB
            maxSteps = 1
            for l in mPvs.loopList:
                maxSteps *= l.incSteps
            win.setMaxSteps(maxSteps)
        self.stepNr = 0

        #print "MeasThreadCreate", len(setLoops), mPvs ,win
        self.setRunControl(-1)
        self.ms = threading.Thread(None, self,"RunLoop",(0,))

    def MeasThreadStart(self):
            """
            Start measure thread after configuration. Start the measure loop itself by 
            startCmd() of setRunControl(x) method
            """
            self.setRunControl(0)
            self.ms.start()

    def setRunControl(self,x)  :
        """
        Set the runControl variable by number or string:
        'INAKTIVE':-1, 'START':0, 'PAUSE':1, 'STOP':2
        """
        if type(x) == int and x >= -1 and x <= 2:
            self.runControl = x
        elif type(x) == str:
            self.runControl = self.strToRunControl[x]
            if self.runControl == None : raise ValueError
        else : raise ValueError
        self.updateView()

    def getRunControlStr(self) : return self.runControlToStr[self.runControl]
    def getRunControl(self)    : return self.runControl

    def stopCmd(self) :
        """
        Stop a measure loop that is not allready inaktive
        """
        if self.getRunControl() != -1:
            self.setRunControl(2)
            
    def pauseCmd(self) :
        """
        Pause a measure loop that is allready aktive or do nothing otherwise
        """
        if self.getRunControl() == 0:
            self.setRunControl(1)
    def startCmd(self) :
        """
        Start a measure loop. Repeated call will cause Pause and Continue
        """
        if self.getRunControl() == 1 : # Pause -> Start again
            self.setRunControl(0)
            return
        if self.getRunControl() == 0 : # Run -> Pause loop
            self.setRunControl(1)
            return
        if self.getRunControl() == -1 :# Start, begin loop
            self.setRunControl(0)

    def updateView(self):
#       print "runDone"
        if self.updateViewFunc is not None:
            self.updateViewFunc(self.stepNr,self.getRunControl())
        
    def notFinished(self,setVal,fromVal,toVal,incVal):
        """
        Check if loop has finished
        """
        if incVal > 0:
            if setVal <= toVal: return True
        else:
            if setVal >= fromVal: return True
        return False
        
    def __call__(self,idx) :
        """
        The Main Measure loop

        - Run the list of loop objects and measure the PVs.
        - Used by commandline and gui version

        - set the values for each loop 
        - measure the PVs
        - take care of stop/go/break commands
        """
        try:
            setLoopList = self.mPvs.loopList
            l = setLoopList[idx]
            l.setVal = l.fromVal
            #print "runLoop: Enter idx: ",idx,self.getRunControlStr(),"Timestamp=",self.mPvs.hasTimestamp #,"loop:",l
            while self.notFinished(l.setVal,l.fromVal,l.toVal,l.incVal) is True:
                try:
                    for s in l.setPv: s.set(l.setVal)       # HERE: set the new value
                except Exception, e:
                    warnFunc("Loop ERROR can't set:"+str(e) )
                    self.stopCmd()
                nxt = procFunc(self.mPvs.nextPar)
                if nxt is None:
                    warnFunc("MeasThread: Illegal next function called\n"+str(self.mPvs.nextPar))
                    self.stopCmd()
                elif nxt is False:
                    brk = procFunc(self.mPvs.breakPar)
                    if brk is None:
                        warnFunc("MeasThread: Illegal break function called\n"+str(self.mPvs.breakPar))
                        self.stopCmd()
                    elif brk is True:       # breakFunc Break
                        warnFunc("Break Loop")
                        if idx == 0:
                            self.setRunControl(-1)
                        return
                    if idx+1 < len(setLoopList) and self.getRunControl() != 2:
                        self.__call__(idx+1)
                    else :
                        while self.getRunControl() == 1:    # Pause
                            time.sleep(0.5)
                        if self.getRunControl() == 2:       # Break
                            if idx == 0:
                                self.setRunControl(-1)
                            return

                        time.sleep(l.delay)                 # Wait Delay
                        #print "runLoop: Measure"
                        try:
                            self.mPvs.getPVs()                      # Measure
                            self.mPvs.setVals = map(lambda x: x.setVal,setLoopList)
                        except Exception, e:
                            warnFunc("Loop ERROR can't read: "+str(e) )
                            self.stopCmd()
                        self.stepNr += 1
                        self.updateView()
                        if self.getRunControl() != 2: 
                            if self.printCallback is not None:
                                self.printCallback()
        #                   self.mPvs.printVals()
                            else :
                                self.mPvs.printVals()
        #           else :
        #               print "runLoop: Skip for val=:",l.setVal
        #           print "runLoop: Finisch"

                l.setVal = l.setVal + l.incVal
                if idx==0 and self.mPvs.loopType == 'SAW' and l.setVal > l.toVal:
                    l.setVal = l.fromVal
                    self.stepNr=0
                    self.updateView()
                elif idx==0 and self.mPvs.loopType == 'TRI' and (l.setVal > l.toVal or l.setVal < l.fromVal):
                    l.incVal *= -1
                    l.setVal = l.setVal + l.incVal + l.incVal
                    self.stepNr=0
                    self.updateView()

            if idx == 0:
                #print "Run Done, Cleanup"
                self.setRunControl(-1)
                if self.mPvs.fileName is not None:   # just for commandline call, GUI doesn't set mPvs.fileName!
                    print "Write measured Data to file: ",self.mPvs.fileName
                    self.mPvs.writeData()
        except:
            warnFunc("Any Error occured in process loops")
            self.setRunControl('STOP')
            return

# compile regexp once
regPvName = re.compile('^\s*([\d\w\.:]+)(.*)$') # 'pvName EXPR, e.g 'MDIZ3T5G:lt50' '< 0.1'
def parseFuncParameter(funcPar):
    """
    Parse a next/break function parameter to be used by MeasThread object
    for the nextifFunc and the breakifFunc to provide for a user defined 
    measure loop control. 

    To skip measurement in case of nextif is true of to break measurement if breakif
    is true.

    The parameter 'funcPar' to this functions is of this type:

        "PV condition"  e.g. "myPv:VAL > 15"

    This will be parsed by regexp to the tupel: (PV, condition) or None if re doesn't match
    """
    #print "parseFuncParameter",funcPar
    nextifPar = regPvName.match(funcPar)
    if nextifPar == None: return None
    else:
        pv = nextifPar.group(1)
        comp = nextifPar.group(2)
        if caget(pv) is None:
            return None
        return (pv,comp)
def procFunc(n) :
    """
    procfunc will do:

        val = caget(PV)
        return exec( "(val"+condition+")" )    
    
    Return True/False or 'None' if either caget or exec will fail
    """
    #print "procFunc",n
    if n == None : return False
    val = caget(n[0])
    if val == None: return None
    #print n[0],"=",val
    nxt = False
    try:
        exec( "nxt = (val"+n[1]+")" )
    except SyntaxError:
        warnFunc("procFunc: '"+n[0]+n[1]+"': SyntaxError")
        return None
    return nxt
    
 
################################################################################
#
#  Read and write configuration data
#  ============================================
#

def saveConfig(argDict,fileName=None) :
    """
    Save program configuration. 
    
    Data format is a list of configuration dictionaries:
    
    [ { 'DESC': "description",
        'LOOPS': [{LoopPV}, .. Objects]
        'LTYPE': 'ONCE',
        'BREAK': "PV:name < 13",
        'TIMESTAMP': False,
        'MEASURE': [ 'PV',.. Names ]
      },
      ...
    ]
    
    Raise IOError if there is no fileName or unable to write the file
    """
    if fileName is None:
        if mPvs.fileName is not None:
            fileName=mPvs.fileName
        else:
            raise IOError("Function step.saveConfig: missing parameter 'filename'")
    cfgList = []
    if os.path.exists(fileName) is True:
        cfgList = readConfig(fileName)
        if cfgList == None: cfgList = []

    #print argDict
    cfgList.append(argDict)
    cfgStr = Dumper(cfgList)+"\n"
    f = open(fileName,'w')
    f.write(cfgStr)
    f.close()

def readConfig(fileName):
    """ Read a configuration file
    
    - The old data format is supported (one dict in one line)
    - May raise the exceptions IOError, SyntaxError
    - Return the list of configuration dictionaries. or None
    """
    if len(fileName) == 0:
        raise IOError("No Filename")
    f = open(fileName,'r')
    s = f.read()
    f.close()
    loopCfg = None
    if s.startswith("{") is False:  # old format is a dict in one line
        try:
            loopCfg = eval(s)
        except SyntaxError, e:
            raise SyntaxError("Syntax Error in File: "+fileName+"\n"+str(e))
    else: # old configuration
        lines = s.split('\n')
        cfg = None
        idx=0
        #print lines
        for cfg in lines:
            if (len(cfg)==0) or cfg.startswith('#'):
                continue 
            idx += 1
            try:
                c = eval(cfg)
            except SyntaxError, e:
                raise SyntaxError("Syntax Error in File: "+fileName+", Line: "+str(idx) )
            if loopCfg == None: loopCfg = []
            loopCfg.append(c)
    return loopCfg
    
# static SaveRestore Object
saveRestObj = SaveRestore() 

if __name__ == "__main__":
    print "NEW: start program with 'stepy'\n     for help type 'stepy -h'"
