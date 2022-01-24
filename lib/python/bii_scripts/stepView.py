# -*- coding: utf-8 -*-

# Copyright 2022 Helmholtz-Zentrum Berlin für Materialien und Energie GmbH
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

import sys
from bii_scripts import pfunc
from Tkinter import *
import tkFont
import tkMessageBox
import tkSimpleDialog
import tkFileDialog
from bii_scripts import step
from bii_scripts import stepConfig
import time
import os

assert sys.version_info[0]==2

def warn(msg):
    tkMessageBox.showwarning(title="Warning", message=msg)
    
def getPvName(pvName=None,title="Enter PV",msg="PV name:") :
    """
    Dialog to enter a pv name. Check if pv exists
    return: pvName or None for Cancel
    """
    pvGood = 0  # 0=unchecked pvName, 1=pvName exists, 2=cancel
    step.lock.acquire();
        
    if pvName is None : pvName = tkSimpleDialog.askstring(title,msg)
    while pvGood == 0:
        if pvName is not None and len(pvName) > 0: # check 
            try :
                val = ca.Get(pvName)
                pvGood = 1
            except ca.caError,e:
                if tkMessageBox.askretrycancel("Illegal"," PV doesn't exist: "+ pvName) == False:
                    pvGood = 2  # cancel
                else:           # retry
                    pvGood = 0
                    pvName = tkSimpleDialog.askstring("Set PV","PV name:")
        else:
            pvGood = 2 # cancel
    step.lock.release()
    if pvGood == 2 : 
        return None
    return pvName

def setBold(tkItem):
    """
    set the font weight to BOLD
    """
    f = tkFont.Font(font=tkItem['font'])
    f['weight'] = 'bold'
    tkItem['font'] = f
    
class caTextUpdate(Frame):
    """
    Widget for a Lable and a Textstring updated by ca-monitor
    """
    def __init__(self, master,pvName,labelText="",width=None,height=None,alarm=False,fg=None,bg=None,txtOrient=TOP,prec=0):
        Frame.__init__(self, master, relief=SUNKEN)
        self.prec=prec
        self.descLable  = Label(self,text=labelText,fg=fg,bg=bg)
        self.val = StringVar()
        self.valItem = Label(self,textvariable=self.val,fg=fg,bg=bg,width=width,height=height)

        def updateNUM(self,val):
            valStr = ("%%10.%df" % self.prec) % val[0]
            self.val.set(valStr)
            if self.alarm == True: 
                fgAlarm=self.statToColor(val[1])
                self.valItem.configure(fg=fgAlarm)

        def monNUM(ch,val,self) : 
            updateNUM(self,val)

        self.descLable.pack(side=txtOrient)
        self.valItem.pack()
        ca.Monitor(pvName,pfunc.ArgFreeze(monNUM,None,None,self))

    def statToColor(stat):
        if   stat == 1: return '#FFFF00'        # MINOR=yellow
        elif stat == 2: return '#FF0000'        # MAJOR=red
        elif stat == 3: return '#FFFFFF'        # INVALID=white
        else:           return '#00FF00'        # NO_ALARM=green

class TimeBar(Frame):
    """
    Create a bar widget, that shows a progress bar and elapsed time or the time till done.
    """
    def __init__(self, master,barFg='green',width=250):
        Frame.__init__(self, master)
        self.maxSteps = 0
        self.t0 = 0
        self.pauseAt = 0
        self.barWidth=width
        self.barHeight=15
        self.barFg=barFg
        self.barBg='grey90'
        
        self.timeVar = StringVar()
        self.timeVar.set(" - ")
        self.timeLable = Label(self,textvariable=self.timeVar,bg='grey90',width=10,padx=5)
        self.timeLable.grid(row=0, column=1)
        
        self.valItem = Canvas(self,width=self.barWidth,height=self.barHeight)
        self.vIBar = self.valItem.create_rectangle(1, 1, self.barWidth-2, self.barHeight-1,fill=self.barFg,outline=self.barFg)
        self.line = self.valItem.create_rectangle(0, 0, self.barWidth, self.barHeight,fill=self.barBg,outline=self.barBg)
        self.valItem.grid(row=0, column=0)
    def reset(self):
        """
        Reset start time and panel
        """
#       print "TimeBar.reset()"
        self.t0 = 0
        self.setNext(0)
    def start(self):
        """
        Reset the panel and set the start time
        """
        self.reset()
        self.t0 = time.time()
#       print "TimeBar.start:",self.t0,self.maxSteps
    def setMaxSteps(self,s):
        """
        Set the max number of steps
        """
        self.maxSteps = s
    def pause(self): 
        """
        Begin pause. Pause is finished with the next setNext() call. Multiple calls of pause() doesn't harm.
        """
        if self.pauseAt == 0:
            self.pauseAt = time.time()
    def setNext(self,idx):
        """
        update time and bar. If pause time is set by pause() end pause.
        idx <= 1 will reset the panel, 
        idx =  1 Should be the first regular call.
        So the panel is set if there was at least two calls, to perform a time measurement. 
        """
        barWidth = 0
        if self.pauseAt > 0:
            self.t0 +=  time.time() - self.pauseAt
            self.pauseAt = 0
        if idx > 1:
            tDiff = time.time() - self.t0
            tMax  = 0
            try:
                tMax = tDiff * self.maxSteps / idx
                barWidth = self.barWidth * idx / self.maxSteps
                if self.t0 > 0:
                    t = int(tMax-tDiff)
                    timeStr = str(t/3600)
                    t = t%3600
                    timeStr = timeStr+":"+str(t/60)
                    t = t%60
                    timeStr = timeStr+":"+str(t)
                    self.timeVar.set( timeStr )
                else:
                    self.timeVar.set( "-")
            except ZeroDivisionError:
                pass

#           print "TimeBar.setNext: idx",idx," runTime:", int(tDiff)," total Time: ",int(tMax),"rest time", int(tMax-tDiff)
        else:
            self.timeVar.set( "-")
        self.valItem.delete(self.vIBar)
        self.vIBar = self.valItem.create_rectangle(1, 1, barWidth, self.barHeight-1,fill=self.barFg,outline=self.barBg)
        
class LabelEntryWidget(Frame):
    """
    Contains a Label and a Entry field, 
    
    - isEmpty(): return True if any string is set, False if there is no entry
    - get() method to get the entry string raise valueError if empty!
    - getFloat() method to get and convert Entry to float, Illegal value = None
    - getPv()    method to get and check Entry to to be a valid PV name, Illegal value = None
    """
    def __init__(self, master,labelText,width=None,variable=None):
        Frame.__init__(self, master)
        l = Label(self,text=labelText)
        l.grid(row=0, column=0)
        self.entryStr = StringVar()
        if variable is not None : 
            self.entryStr.set(variable)
        self.entry = Entry(self,textvariable=self.entryStr,width=width)
        self.entry.grid(row=0, column=1)
        self.entry.focus_set()
        setBold(self.entry)
    def isEmpty(self):
        if len(self.entry.get())==0: return True
        return False
    def getFloat(self,illegalVal=None):
        fl = None
        try:
            fl = float(self.entry.get())
            if illegalVal is not None:
                if fl == illegalVal:
                    raise ValueError
        except ValueError:
            self.entry.configure(bg='#FF8080')
            self.entry.focus_set()
            raise ValueError
        else :
            self.entry.configure(bg='grey90')
            return fl
    def getInt(self,illegalVal=None):
        fl = None
        try:
            i = int(self.entry.get())
            if illegalVal is not None:
                if i == illegalVal:
                    raise ValueError
        except ValueError:
            self.entry.configure(bg='#FF8080')
            self.entry.focus_set()
            raise ValueError
        else :
            self.entry.configure(bg='grey90')
            return i
    def getPv(self):
        """
        getPv() returns a valid pvName or raise ValueError
        """
        pv = self.entryStr.get()
        if len(pv) == 0 or not step.caExist(pv):
            self.entry.configure(bg='#FF8080')
            raise ValueError
        else :
            self.entry.configure(bg='grey90')
            return pv
    def get(self):
        """
        get() returns a string or raise ValueError if string is empty
        """
        val = self.entryStr.get()
        if len(val) == 0:
            self.entry.configure(bg='#FF8080')
            raise ValueError
        else :
            self.entry.configure(bg='grey90')
            return val
            
        return 
    def set(self,val):
        self.entryStr.set(val)

class printTable(Frame):
    """
    Frame to show the set and measured data. Unfortunately no table, just a 
    listbox with head line.
    
    holds a step.measurePvs object as data store.
    """
    def __init__(self,parent,):
        Frame.__init__(self, parent,relief=RAISED,padx=10,pady=10)
        self.mPvs = step.measurePvs(None)

        f = tkFont.Font(family='courier',size=14,weight='bold')
        self.header = Text(self,height=1,relief=SUNKEN,font=f,wrap=NONE,state=DISABLED)
        
        self.valList = Listbox(self, height=4, selectmode = MULTIPLE)
        self.scroll = Scrollbar(self, command = self.valList.yview)

        def scrollFunc(*args):
            self.valList.xview(*args)
            self.header.xview(*args)
            
        self.hscroll = Scrollbar(self, command = scrollFunc,orient=HORIZONTAL)
        self.valList.configure(yscrollcommand = self.scroll.set,font=f)

        self.valList.configure(xscrollcommand = self.hscroll.set)
        self.header.configure(xscrollcommand = self.hscroll.set)

        self.header.grid(row=0,column=0,sticky=W+E)
        self.scroll.grid(row = 1, column = 1,sticky=W+N+S)
        self.valList.grid(row = 1, column = 0,sticky=W+E+N+S )
        self.hscroll.grid(row = 2, column = 0,sticky=W+E+N)
        self.columnconfigure(0, weight=1)
        self.rowconfigure(1, weight=1)

    def setMpvs(self,argDict=None):
        if argDict == None:
            raise ValueError
        self.mPvs = step.measurePvs(argDict)
        self.setHeader(self.mPvs.printHeader(toString=True))
        if len(self.mPvs.measData) > 0:     # restore the data list if the mPvs object contains stored data
            for data in mPvs.measData:
                self.mPvs.chanVals = data
                self.setNextLine()
            self.mPvs.chanVals = []

    def setChannels(self,chList,hasTs):
        self.mPvs.setPvList(chList,hasTs)
        self.setHeader(self.mPvs.printHeader(toString=True))
        
    def updateView(self,argDict=None):
        if argDict is not None:
            head = []
            hasTs = False
            if argDict.has_key('TIMESTAMP') and argDict['TIMESTAMP'] == True:
                head.append("Time")
                hasTs = argDict.has_key('TIMESTAMP')
            if argDict.has_key('LOOPS'):
                for loopDict in argDict['LOOPS']:
                    for pvs in loopDict['PVS']:
                        head.append(pvs['PV'])
            if argDict.has_key('MEASURE'):
                head += argDict['MEASURE']
                self.setChannels(argDict['MEASURE'],hasTs)

            hItemWidths = []
            for item in head:
                strLen = len(item)
                if strLen < 15: strLen = 15
                hItemWidths.append(strLen)
            self.setHeader(" | ".join( map(lambda x:("%%%ds"%x[0])%x[1],zip(hItemWidths,head)) ))

    def setHeader(self,itemStr):
        self.header.config(state=NORMAL,width=len(itemStr))
        self.header.delete(1.0, END)
        self.header.insert(END, itemStr)
        self.header.config(state=DISABLED)
        self.valList.config(width=len(itemStr))
    def setNextLine(self):
        """
        Print last measured data to list
        """
        itemStr = self.mPvs.printVals(toString=True)
        self.valList.insert(END, itemStr)
        self.valList.see(END)

    def containsMeasData(self):
        """
        Return: True if there are measured data stored, False if not.
        """
        if len(self.mPvs.measData) > 0: return True
        return False

    def getMeasureChannelNames(self):
        return self.mPvs.chanNames
        
    def clearData(self):
        self.mPvs.clearData()
        self.valList.delete(0,END)

    def writeData(self,fileName):
        try:
            self.mPvs.writeData(fileName)
        except IOError, e:
            warn("IOError: Can't write File: "+fileName)
        self.clearData()

class loopFrame(Frame):
    def __init__(self, master,loopParDict=None):

        Frame.__init__(self, master)
        
        self.startEntry = LabelEntryWidget(self,"From:",width=8)
        self.endEntry   = LabelEntryWidget(self,"To:",width=8)
        self.incEntry   = LabelEntryWidget(self,"Inc:",width=8)
        self.dlyEntry   = LabelEntryWidget(self,"Delay:",width=8)
        self.startEntry.grid(row=0,column=0)
        self.endEntry.grid(row=0,column=1)
        self.incEntry.grid(row=0,column=2)
        self.dlyEntry.grid(row=0,column=3)
        self.addPvMenuButton = Menubutton(self,text="Add PV",relief=RAISED)
        self.addPvMenuButton.grid(row=1,column=0, sticky=W,padx=20)
        self.addPvMenuButton.menu = Menu(self.addPvMenuButton,tearoff=0)
        self.addPvMenuButton['menu'] = self.addPvMenuButton.menu
        self.addPvMenuButton.menu.add_command(label="Pv", command=lambda :self.addPvCommand({'TYPE':'PV'}))
        self.addPvMenuButton.menu.add_command(label="Motor", command=lambda :self.addPvCommand({'TYPE':'MOTOR'}))
        self.addPvMenuButton.menu.add_command(label="Linear", command=lambda :self.addPvCommand({'TYPE':'LINEAR'}))
        self.addPvMenuButton.menu.add_command(label="Func", command=lambda :self.addPvCommand({'TYPE':'FUNC'}))
        self.pvItems = []
        if loopParDict is not None:
            self.setupFromDict(loopParDict)

    def __str__(self):
        Type = "PV"
        if self.isMotorPv.get() == 1: Type="MOTOR"
        return "("+self.pvEntry.get()+","+self.startEntry.get()+","+self.endEntry.get()+","+self.incEntry.get()+","+self.dlyEntry.get()+",'"+Type+"')"

    class setPV(Frame):
        def __init__(self, master):

            Frame.__init__(self, master)
            self.typeLabel = Label(self,text="PV", width=7,justify=LEFT)
            self.pvEntry = LabelEntryWidget(self,"PV:", width=10)
            self.delButton = Button(self, text="Delete", command=self.destr)
            self.typeLabel.grid(row=0,column=1,sticky=W)
            self.pvEntry.grid(row=0,column=2,sticky=W)
            self.delButton.grid(row=0,column=0,sticky=W,padx=20)
            self.pvItems = None
        def get(self): return {'PV':self.pvEntry.getPv(),'TYPE':'PV'}
        def set(self,d):
            """
            Set entry fields to the values of the dictionary
            """
            if d.has_key('PV') : self.pvEntry.set(d['PV'])
        def destr(self) :
            """
            destroy this frame and remove it from loop's pv list
            """
            self.pvItems.remove(self)
            self.destroy()

    class setMOTOR(Frame):
        def __init__(self, master):

            Frame.__init__(self, master)
            self.typeLabel = Label(self,text="MOTOR", width=7,justify=LEFT)
            self.pvEntry = LabelEntryWidget(self,"PV:", width=10)
            self.delButton = Button(self, text="Delete", command=self.destr)
            self.typeLabel.grid(row=0,column=1,sticky=W)
            self.pvEntry.grid(row=0,column=2,sticky=W)
            self.delButton.grid(row=0,column=0,sticky=W,padx=20)
            self.pvItems = None
        def get(self): return {'PV':self.pvEntry.getPv(),'TYPE':'MOTOR'}
        def set(self,d):
            """
            Set entry fields to the values of the dictionary
            """
            if d.has_key('PV') : self.pvEntry.set(d['PV'])
        def destr(self) :
            """
            destroy this frame and remove it from loop's pv list
            """
            self.pvItems.remove(self)
            self.destroy()

    class setFUNC(Frame):
        def __init__(self, master):

            Frame.__init__(self, master)
            self.typeLabel = Label(self,text="FUNC", width=7,justify=LEFT)
            self.pvEntry = LabelEntryWidget(self,"PV:", width=10)
            self.funcEntry = LabelEntryWidget(self,"Function:", width=20)
            self.delButton = Button(self, text="Delete", command=self.destr)
            self.typeLabel.grid(row=0,column=1,sticky=W)
            self.pvEntry.grid(row=0,column=2,sticky=W)
            self.funcEntry.grid(row=0,column=3,sticky=W)
            self.delButton.grid(row=0,column=0,sticky=W,padx=20)
            self.pvItems = None
        def get(self): return {'PV':self.pvEntry.getPv(),'TYPE':'FUNC','FUNC':self.funcEntry.get()}
        def set(self,d):
            """
            Set entry fields to the values of the dictionary
            """
            if d.has_key('PV') :   self.pvEntry.set(d['PV'])
            if d.has_key('FUNC') : self.funcEntry.set(d['FUNC'])
        def destr(self) :
            """
            destroy this frame and remove it from loop's pv list
            """
            self.pvItems.remove(self)
            self.destroy()
    class setLINEAR(Frame):
        def __init__(self, master):

            Frame.__init__(self, master)
            self.typeLabel = Label(self,text="LINEAR", width=7,justify=LEFT)
            self.pvEntry = LabelEntryWidget(self,"PV:", width=10)
            self.begEntry = LabelEntryWidget(self,"Begin:  ", width=10)
            self.endEntry = LabelEntryWidget(self,"End:")
            self.delButton = Button(self, text="Delete", command=self.destr)
            self.typeLabel.grid(row=0,column=1,sticky=W)
            self.pvEntry.grid(row=0,column=2,sticky=W)
            self.begEntry.grid(row=0,column=3,sticky=W)
            self.endEntry.grid(row=0,column=4,sticky=W)
            self.delButton.grid(row=0,column=0,sticky=W,padx=20)
            self.pvItems = None

        def get(self): 
            return {'PV':self.pvEntry.getPv(),'TYPE':'LINEAR','BEGIN':self.begEntry.getFloat(),'END':self.endEntry.getFloat()}
        def set(self,d):
            """
            Set entry fields to the values of the dictionary
            """
            if d.has_key('PV') :    self.pvEntry.set(d['PV'])
            if d.has_key('BEGIN') : self.begEntry.set(d['BEGIN'])
            if d.has_key('END') :   self.endEntry.set(d['END'])
        def destr(self) :
            """
            destroy this frame and remove it from loop's pv list
            """
            self.pvItems.remove(self)
            self.destroy()

    def addPvCommand(self,pvDict):
        Type = pvDict['TYPE']
        if Type == 'PV':
            pv = self.setPV(self)
        elif Type == 'MOTOR':
            pv = self.setMOTOR(self)
        elif Type == 'LINEAR':
            pv = self.setLINEAR(self)
        elif Type == 'FUNC':
            pv = self.setFUNC(self)
        else:
            return
        pv.set(pvDict)
        
        idx = len(self.pvItems)+2   # loop + PVs + Add-button
        self.addPvMenuButton.grid(row=idx+1,column=0, sticky=W)
        pv.grid(row=idx,column=0,columnspan=4, sticky=W)
        pv.pvItems = self.pvItems
        self.pvItems.append(pv)

    def getEntry(self):
        """
        Get a Dictionary with loop parameters and pvs to create a step.loopPv object
        
        Return None if there is any illegal entry in this loopView
        """
        d = {}
        try:
            d['FROM']  = self.startEntry.getFloat()
            d['TO']    = self.endEntry.getFloat()
            d['INC']   = self.incEntry.getFloat(illegalVal=0.0)
            d['DELAY'] = self.dlyEntry.getFloat()
#           d['LTYPE'] = self.loopType
            pvs = []
            for p in self.pvItems:
                try:
                    pv = p.get()
                except ValueError:
                    return None
                pvs.append(pv)
            d['PVS'] = pvs
        except ValueError:
            return None
        
        return (d)

    def setupFromDict(self,loopDict):
        """
            Setup a loopVies object from the dictionatry representation of a step.loopPv object
        """
        self.startEntry.set( str(loopDict['FROM']))
        self.endEntry.set( str(loopDict['TO']))
        self.incEntry.set( str(loopDict['INC']))
        self.dlyEntry.set( str(loopDict['DELAY']))
        for p in loopDict['PVS']:
            self.addPvCommand(p)

class stepApp(object):
    """
    the main window
    """
    def __init__(self,root,argDict=None):
        self.root = root
        self.loopViews = []         # loop GUI Items
        self.tb = None              # GUI print table
        self.ms = None              # Measure Thread object: step.MeasThread
        self.loopType = StringVar()
        self.desc = ""
        self.steprcParam = { 'DATAPREPATH': ".",'CFGPREPATH':  "."}
        self.hasTimestamp = BooleanVar()
        self.loopCount = 0
        self.file = StringVar()
        self.desc = StringVar()
# Menu Bar
        self.menubar = Menu(self.root)
        fileMenu = Menu(self.menubar, tearoff=0)
        fileMenu.add_command(label="Open Config", command=self.openConfig)
        fileMenu.add_command(label="Save Config", command=self.saveConfig)
        fileMenu.add_command(label="Save Data", command=self.saveData)
        fileMenu.add_command(label="Quit", command=self.quitApplication)
        self.menubar.add_cascade(label="File", menu=fileMenu)
        
        editMenu = Menu(self.menubar, tearoff=0)
        editMenu.add_command(label="StripTool", command=self.stripToolCmd)
        editMenu.add_command(label="New Loop", command=self.addLoopView)
        editMenu.add_command(label="Delete Loop", command=self.deleteLoopCmd)
        editMenu.add_command(label="Configure Measure PVs", command=self.confMeasCmd)
        self.menubar.add_cascade(label="Edit", menu=editMenu)
        
        self.menuBackground = self.menubar.entrycget(3,'background')
        self.menuActivebackground = self.menubar.entrycget(3,'activebackground')
        
        self.root.config(menu=self.menubar)
        self.root.minsize(width=500,height=200)
# File Label
        self.fileFrame = Frame(self.root,padx=10)
        Label(self.fileFrame,textvariable=self.desc).grid(row=0, column=0, sticky=W)
        Label(self.fileFrame,textvariable=self.file).grid(row=0, column=1, sticky=W)
# Loop definition
        self.loopFrames = Frame(self.root,padx=10)

# Operation Buttons and Status
        self.loopCmdFrame = Frame(self.root,padx=10)
        self.startBut = Button(self.loopCmdFrame,text="<Start>",command=self.startCmd,padx=10)
        stopBut  = Button(self.loopCmdFrame,text="<Stop>", command=self.stopCmd,padx=10)
        clearBut = Button(self.loopCmdFrame,text="<Save&Clear-Data>",command=self.clearCmd,padx=10)
        resetBut = Button(self.loopCmdFrame,text="<Reset PVs>",command=self.resetCmd,padx=10)

        checkTime = Checkbutton(self.loopCmdFrame, text="Time  LoopType", variable=self.hasTimestamp)
        self.loopTypeMenu = Menubutton(self.loopCmdFrame,textvar=self.loopType,relief=RAISED,width=4)
        self.loopTypeMenu.menu = Menu(self.loopTypeMenu,tearoff=0)
        self.loopTypeMenu['menu'] = self.loopTypeMenu.menu
        self.loopTypeMenu.menu.add_command(label="Once", command=lambda :self.setLoopTypeCmd({'LTYPE':'ONCE'}))
        self.loopTypeMenu.menu.add_command(label="Triangle", command=lambda :self.setLoopTypeCmd({'LTYPE':'TRI'}))
        self.loopTypeMenu.menu.add_command(label="Sawtoth", command=lambda :self.setLoopTypeCmd({'LTYPE':'SAW'}))
        self.breakFunc = LabelEntryWidget(self.loopCmdFrame,"Break IF:",width=40)

        self.stRun = StringVar()
        self.stRun.set(" - ")
        self.statLabel = Label(self.loopCmdFrame,text="Status: ",width=8)
        self.stat = Label(self.loopCmdFrame,textvariable=self.stRun,bg='grey90',width=10)
        setBold(self.stat)
        self.timeBar = TimeBar(self.loopCmdFrame)
        self.setupMVars = Button(self.loopCmdFrame,text="<Measure>",command=self.confMeasCmd,padx=10)

        self.startBut.grid(row=0, column=0)
        stopBut.grid(row=0, column=1)
        clearBut.grid(row=0, column=2)
        resetBut.grid(row=0, column=3)

        self.breakFunc.grid(row=1, column=0, columnspan=3, sticky=W,padx=0,pady=0)
        checkTime.grid(row=1,column=3, sticky=W,padx=0,pady=0)
        self.loopTypeMenu.grid(row=1,column=4, sticky=W,padx=0,pady=5)

        self.statLabel.grid(row=2, column=0, sticky=W,padx=0,pady=5)
        self.stat.grid(row=2, column=1)
        self.timeBar.grid(row=2, column=2, columnspan=2)
        self.setupMVars.grid(row=2, column=4)

        self.fileFrame.grid(row=0, column=0, sticky=W)
        Frame(height=2, bd=1, relief=SUNKEN).grid(row=1, column=0, sticky=W+N+E)        #Seperator
        self.loopFrames.grid(row=2, column=0,sticky=W+N,pady=10)
        Frame(height=2, bd=1, relief=SUNKEN).grid(row=3, column=0, sticky=W+N+E)        #Seperator
        self.loopCmdFrame.grid(row=4,column=0,sticky=W+N,pady=10)
        Frame(height=2, bd=1, relief=SUNKEN).grid(row=5, column=0, sticky=W+N+E)        #Seperator
        self.tb = printTable(self.root)
        self.tb.grid(row=6, column=0, sticky=N+S+E+W)

        self.root.rowconfigure(6,weight=1)
        self.root.columnconfigure(0,weight=1)

        # up to now geometry of frames and toplevel is 0. This command invokes the 
        # internal calculation of the window geometry. This allows correct window 
        # calculation when the window is built new in openConfig(). Work around a bug?
        self.root.wm_geometry()

        self.updateView(argDict)

        
## class methonds        
    def addLoopList(self,loopList):
        """
        create a GUI line for each loop in loopList
        """
        if isinstance(loopList,list) and len(loopList) > 0:
            for l in loopList :
                self.addLoopView(l)
            
    def addLoopView(self,loopDict=None):
        """
        Create and add a new loop GUI item from a step.loopPV object!
        """
        loop = loopFrame(self.loopFrames,loopDict)
        loop.grid(column=0,row=self.loopCount,sticky=W)
        self.loopCount += 1
        self.loopViews.append(loop)
         
    def deleteLoop(self, deleteIndex):
        """
        delete loop from gui and app.
        deleteIndex: delete this index
        """
        if deleteIndex >= 0 and deleteIndex < len(self.loopViews):
            self.loopViews[deleteIndex].destroy()
            del(self.loopViews[deleteIndex])
            self.loopCount -= 1
        else:
            warn("Ignore Command: No loop defined")

    def updateView(self,cfg=None):
        """
        
        """
#       print "updateView",step.Dumper(cfg)
        if cfg is None:
            raise ValueError

        self.tb.updateView(cfg) # setup to all channels in configuration and ...
        self.tb.setHeader(self.tb.mPvs.printHeader(toString=True)) # .. remove channels, that are not valid

        while len(self.loopViews) > 0:
            self.deleteLoop(0)
        try:
            self.addLoopList(cfg['LOOPS'])
        except KeyError :
            self.addLoopView()
        try:
            self.hasTimestamp.set(cfg['TIMESTAMP'])
        except KeyError :
            self.hasTimestamp.set(False)
        try:
            self.loopType.set(cfg['LTYPE'])
        except KeyError :
            self.loopType.set('ONCE')
        try :
            self.prePathCfg  = cfg['CFGPREPATH']
        except KeyError :
            self.prePathCfg  = "."
        try :
            self.prePathData = cfg['DATAPREPATH']
        except KeyError :
            self.prePathData = "."
        try :
            self.file.set("  from File: '"+cfg['FILENAME']+"'")
        except TypeError :
            self.file.set("")
        except KeyError :
            self.file.set("")
        try :
            self.desc.set("Load: '"+cfg['DESC']+"'")
        except KeyError :
            self.desc.set("Load: -")

    def setLoopTypeCmd(self,pvDict):
        self.loopType.set(pvDict['LTYPE'])
        self.loopTypeMenu.configure(text=pvDict['LTYPE'])

    def setupLoopFromEntry(self) :
        """
        Take GUI-loop entry fields and create the measure loop list.
        Is called for: Start Command and Save Configuration

        Return: list of a loop parameter dictionarys, or None if there is an illegal entry
        """
        loopList = []
        for lv in self.loopViews:
            d = lv.getEntry()
            if d==None:
                return None
            loopList.append(d)

        if len(loopList) > 0:
            return loopList
        else:
            return None
    def toDict(self):
        """ Read all GUI data to a dictionary
        """
        loops = self.setupLoopFromEntry()
        if loops is None:
            return
        argDict = {'LOOPS':loops}
        argDict['MEASURE']     = self.tb.getMeasureChannelNames()
        argDict['TIMESTAMP']   = self.hasTimestamp.get()
        argDict['LTYPE']       = self.loopType.get()
        argDict['DESC']        = self.desc
        argDict['DATAPREPATH'] = self.prePathData
        argDict['CFGPREPATH']  = self.prePathCfg
        if self.breakFunc.isEmpty() is False:
            argDict['BREAK']   = self.breakFunc.get()
        
        return argDict
                
# menu command fucnctions       
    def quitApplication(self):
        if self.clearCmd() == True:
            if step.SaveRestore.isEmpty() is False:
                doIt = tkMessageBox._show(title="Restore PVs",message="Restore affected PVs?",icon=tkMessageBox.QUESTION,type=tkMessageBox.YESNO)
                if doIt == "yes":
                    step.SaveRestore.restoreAll()
            self.root.quit()
        
    def deleteLoopCmd(self):
        loopLen = len(self.loopViews)
        d = tkSimpleDialog.askinteger("Delete Loop","Choose Loop Nr: [0:"+str(loopLen-1)+"]")
        if d < 0 or d >= len(self.loopViews):
            warn("Ignore value"+str(d)+" range=[0:"+str(length-1)+"]")
        else :
            self.deleteLoop(d)

    def stopCmd(self) :
        if self.ms is not None and self.ms.getRunControl() != -1:
            self.ms.setRunControl(2)
            self.stat.configure(bg='grey90')
            self.stRun.set("Stop")
#           print "stopCmd:"
            return
#       print "stopCmd: NO loop running"
            
    def startCmd(self) :
        if self.ms is not None:
            runCtrl = self.ms.getRunControl()
            
            if runCtrl == 1 :                           # Pause -> Start again
                self.startBut.configure(text="<Pause>")
                self.ms.setRunControl(0)
                self.stat.configure(bg='LawnGreen')
                self.stRun.set("Runing")
#               print "startCmd: Pause -> Start again"
                return
            if runCtrl == 0 :                           # Run -> Pause loop
                self.ms.setRunControl(1)
                self.stat.configure(bg='yellow')
                self.startBut.configure(text="<Start>")
                self.stRun.set("Paused")
#               print "startCmd: Run -> Pause loop"
                self.timeBar.pause()
                return
        else :                                          # Start, begin loop
#           print "startCmd: no loop active"
            self.clearCmd()
            loops = self.setupLoopFromEntry()
            if loops == None:
                return
            self.startBut.configure(text="<Pause>")

            self.tb.setMpvs(self.toDict() )
            self.ms = step.MeasThread(self.tb.mPvs,win=self)
            self.ms.MeasThreadStart()
#           print "startCmd: Start, begin loop"
            self.startBut.configure(text="<Pause>")
            self.stat.configure(bg='LawnGreen')
            self.stRun.set("Runing")
            self.timeBar.start()
            self.ms.setRunControl(0)

    def setNextLine(self):
        self.tb.setNextLine()
    
    def loopCB(self,idx,state) :
        """
        Called by step.runLoop.
        - update status
        - update progress bar
        """
        barWidth = 0
#       print "loopCB",idx,state
        if idx == 0:
            self.timeBar.start()
        if state == -1:
#           print "loopDone"
            self.startBut.configure(text="<Start>")
            self.stat.configure(bg='grey90')
            self.stRun.set("Done")
            self.timeBar.reset()
            self.ms = None
        elif state == 0:
            self.timeBar.setNext(idx)

    def setMaxSteps(self,x):
        self.timeBar.setMaxSteps(x)

    def clearCmd(self) :
        """
        Clear data bufer and output windows
        Return True for done, False for cancel
        """
#       print "clearCmd"
        self.stopCmd()
        if self.tb.containsMeasData() is True:
            doIt = tkMessageBox._show(title="Save or ClearData",message="Save Data?",icon=tkMessageBox.QUESTION,type=tkMessageBox.YESNOCANCEL)
            if doIt == "cancel":
                return False
            elif doIt == "yes" :
                try:
                     self.saveData()    # destroy data only if write was successfull
                except:
                    warn( "EXCEPTION: Can't save Data")
                    return False
                
        self.tb.clearData()
        self.timeBar.reset()
        return True
    def resetCmd(self) :
        """
        Reset all set PVs to initial values, means from start of program or from last reset command.
        Return True for done, False for cancel
        """
        step.SaveRestore.restoreAll()
        self.stat.configure(bg='grey90')
        self.stRun.set("Reseted")

    def saveData(self) :
        if self.tb.containsMeasData() == False:
            self.stat.configure(bg='red2')
            self.stRun.set("No Data")
            return
        fileName = tkFileDialog.asksaveasfilename(initialdir=self.prePathData, title='Save Data')
        if len(fileName) > 0:
            self.tb.writeData(fileName)
        self.prePathData = os.path.dirname(fileName)
        

    def confMeasCmd(self) :
        """
        Dialog to add, delete measure PVs
        """
        chanNames = self.tb.getMeasureChannelNames()
        stepConfig.ConfigMeasDialog(chanNames[:],lambda x: self.confMeasFunc(x))

    def confMeasFunc(self,chanNames):
        """
        Setup new list of measure PVs.
        
        - Clear/Store the measured data
        - Update the print table to the current values for loop and measure PVs
        - Do nothing if the chanNames parameter is None (means Cancel button of the dialog).
        """
        if chanNames is None: return
        self.clearCmd()
        self.tb.setChannels(chanNames,self.hasTimestamp.get())
            
    def saveConfig(self) :
        fileName = tkFileDialog.asksaveasfilename(initialdir=self.prePathCfg, title='Save Config')
        if len(fileName) <= 1: return
        desc = tkSimpleDialog.askstring("Config Description","Set a description to this configuration")
        if desc== None: return
        self.desc = desc
        argDict = self.toDict()
        try:
            step.saveConfig(argDict,fileName)
        except IOError, e:
            warn("IOError: Can't write File: "+fileName)
        self.prePathCfg = os.path.dirname(fileName)

    def openConfigCallback(self,cfg):
        if cfg is None: 
            return

        self.updateView(cfg)
        
    def openConfig(self) :
        stepConfig.ChooseConfigDialog(self.prePathCfg,lambda x: self.openConfigCallback(x) )
        
    def stripToolCmd(self):
        
        fileName = os.environ['HOME']+"/.step.stp"
        try:
            f = open(fileName,'w')
            stripConfig = "StripConfig                 1.2\n\
Strip.Time.Timespan           300\n\
Strip.Time.NumSamples         7200\n\
Strip.Time.SampleInterval     1.0\n\
Strip.Time.RefreshInterval    1.0\n\
Strip.Color.Background        65535     65535     65535\n\
Strip.Color.Foreground        0         0         0    \n\
Strip.Color.Grid              49087     49087     49087\n\
Strip.Color.Color1            0         0         65535\n\
Strip.Color.Color2            27499     36494     8995 \n\
Strip.Color.Color3            42405     10794     10794\n\
Strip.Color.Color4            24415     40606     41120\n\
Strip.Color.Color5            65535     42405     0    \n\
Strip.Color.Color6            41120     8224      61680\n\
Strip.Color.Color7            65535     0         0    \n\
Strip.Color.Color8            65535     55255     0    \n\
Strip.Color.Color9            48316     36751     36751\n\
Strip.Color.Color10           39578     52685     12850\n\
Strip.Option.GridXon          1\n\
Strip.Option.GridYon          1\n\
Strip.Option.AxisYcolorStat   1\n\
Strip.Option.GraphLineWidth   2\n"
            
            pvList = self.tb.getMeasureChannelNames()
            loops = self.setupLoopFromEntry()
            if loops is None:
                return
            for l in loops:
                for pv in l['PVS']:
                    pvList.append(pv['PV'])
            #print pvList
            idx=0
            for pv in pvList:
                stripConfig += "Strip.Curve."+ str(idx) +".Name "+pv+"\n"
                idx += 1
            f.write(stripConfig)
            f.close()
        except IOError :
            warn("Open Striptool Error: Can't open file: "+fileName)
            return
        pid = os.spawnlp(os.P_NOWAIT,'StripTool','StripTool',fileName)
#       print pid, ' StripTool ',fileName

stepConfig.STEPVIEWLABELCLASS= LabelEntryWidget

def main():
    """
    The main function.
    """
    root = Tk()
    stepApp(root)
    mainloop()
    
if __name__ == "__main__":
    #print __doc__
    main()

