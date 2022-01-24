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
from Tkinter import *
import tkMessageBox
import tkSimpleDialog
import tkFileDialog
from bii_scripts import step
# Do NOT import stepView here, stepView already imports stepConfig, this
# creates a mutual dependency that makes problems. 
# We resolve this by defining STEPVIEWLABELCLASS which must be set to class
# LabelEntryWidget from module stepView within the module initialization of
# stepView.

assert sys.version_info[0]==2

STEPVIEWLABELCLASS= None

class ChooseConfigDialog(Toplevel):
    """
    Popup Window to choose an item (configuration) from a config file
    """
    def __init__(self, initDir,callbackFunc):
        Toplevel.__init__(self)

        self.title("Read Configuration")
        self.callbackFunc = callbackFunc
        self.loopCfg = []       # config data structure
        self.hasDeletedItems = False
        listFrame=Frame(self)
        self.l = Label(listFrame,text="Config Description:")
        self.l.grid(row=0,column=0)
        self.valList = Listbox(listFrame, width=30, height=4, selectmode = MULTIPLE)
        scrollY = Scrollbar(listFrame, command = self.valList.yview)
        scrollX = Scrollbar(listFrame, command = self.valList.xview, orient=HORIZONTAL)
        self.valList.configure(yscrollcommand = scrollY.set)
        self.valList.configure(xscrollcommand = scrollX.set)
        scrollY.grid(row=1, column=1,sticky=NS)
        scrollX.grid(row=2, column=0,sticky=EW)
        self.valList.grid(row=1,column=0,sticky=W+E+N+S )
        listFrame.pack(side=LEFT,fill=Y,expand=1,padx=5,pady=5)

        restSelBut = Button(self,width=25,text="Delete all selected",command=self.delCmd)
        restSelBut.pack(side=TOP,padx=5,pady=5,anchor=E)
        okCancelFrame = Frame(self)
        restAllBut = Button(okCancelFrame,width=8,text="Ok",command=self.okCmd)
        cnBut = Button(okCancelFrame,width=8,text="Cancel",command=self.cancelCmd)
        restAllBut.grid(row=0,column=0)
        cnBut.grid(row=0,column=1)
        okCancelFrame.pack(side=BOTTOM,padx=5,pady=5,anchor=E)

        self.fileName = tkFileDialog.askopenfilename(initialdir=initDir)

        if len(self.fileName) > 0:
            try:
                self.loopCfg = step.readConfig(self.fileName)
            except SyntaxError, e:
                tkMessageBox.showwarning(title="Syntax Error",message=str(e))
            except IOError, e:
                tkMessageBox.showwarning(title="IO Error",message=str(e))
        else: 
            self.cancelCmd()
            return 
        
        for cfg in self.loopCfg: 
            self.valList.insert(END, cfg['DESC'])

    def delCmd(self):
        delItems = self.valList.curselection()
        self.hasDeletedItems = True
        for delI in delItems:
            idx = int(delI)
            del(self.loopCfg[idx])
            self.valList.delete(idx)
            
    def cancelCmd(self):
        self.callbackFunc(None)
        self.destroy()
            
    def okCmd(self):
        Items = self.valList.curselection()
        if len(Items) != 1 and self.hasDeletedItems == False:
            tkMessageBox.showwarning(title="Spinnste??",message="Wana confuse me?\nSelect just ONE item")           
            return

        if self.hasDeletedItems == True:
            f = open(self.fileName,'w')
            for cfg in self.loopCfg:
                cfgStr = repr(cfg)+"\n";
                f.write(cfgStr)
            f.close()
            
        if len(Items) == 1 :
            cfg = self.loopCfg[int(Items[0])]
            cfg['FILENAME']=self.fileName
            self.callbackFunc(cfg)
        self.destroy()

class ConfigMeasDialog(Toplevel):
    """
    Popup Window to configure the PVs to be measured
    """
    def __init__(self, pvNames,callbackFunc):
        Toplevel.__init__(self)

        self.title("Configure Measure PVs")
        self.callbackFunc = callbackFunc

        listFrame=Frame(self)
        self.l = Label(listFrame,text="Measured PVs:")
        self.l.grid(row=0,column=0)
        self.valList = Listbox(listFrame, height=4, selectmode = MULTIPLE)
        scroll = Scrollbar(listFrame, command = self.valList.yview)
        self.valList.configure(yscrollcommand = scroll.set)
        scroll.grid(row=1, column=1,sticky=NS)
        listFrame.columnconfigure(0,weight=1)
        listFrame.rowconfigure(1,weight=1)
        self.valList.grid(row=1,column=0,sticky=W+E+N+S )
        listFrame.pack(side=LEFT,fill=BOTH,expand=1,padx=5,pady=5)
        self.pvEntr = STEPVIEWLABELCLASS(self,"Add PV:",None,None)
        self.pvEntr.pack(side=TOP,padx=5,pady=5,anchor=E)
        addBut = Button(self,width=25,text="Add PV",command=self.addCmd)
        addBut.pack(side=TOP,padx=5,pady=5,anchor=E)
        restSelBut = Button(self,width=25,text="Delete selected PVs",command=self.delCmd)
        restSelBut.pack(side=TOP,padx=5,pady=5,anchor=E)
        okCancelFrame = Frame(self)
        restAllBut = Button(okCancelFrame,width=8,text="Ok",command=self.okCmd)
        cnBut = Button(okCancelFrame,width=8,text="Cancel",command=self.cancelCmd)
        restAllBut.grid(row=0,column=0)
        cnBut.grid(row=0,column=1)
        okCancelFrame.pack(side=BOTTOM,padx=5,pady=5,anchor=E)
        
        for name in pvNames: self.valList.insert(END, name)

    def addCmd(self):
        try:
            pv = self.pvEntr.getPv()
            self.pvEntr.set("")
        except ValueError:
            return
        self.valList.insert(END, pv)
            
    def delCmd(self):
        delItems = self.valList.curselection()
        a = list(delItems)
        a.reverse()
        for delI in a:
            self.valList.delete(delI)

    def cancelCmd(self):
        self.callbackFunc(None)
        self.destroy()
            
    def okCmd(self):
        self.callbackFunc(self.valList.get(0,END))
        self.destroy()
            
class ChooseRestoreDialog(Toplevel):
    """
    Popup Window to select the PVs to be restored to its initial values
    """
    def __init__(self, ):
        Toplevel.__init__(self)
        
        self.store = []

        self.title("Restore PVs")

        listFrame=Frame(self)
        self.l = Label(listFrame,text="PV - Restore Values")
        self.l.grid(row=0,column=0)
        self.valList = Listbox(listFrame, width=30, height=4, selectmode = MULTIPLE)
        scrollY = Scrollbar(listFrame, command = self.valList.yview)
        scrollX = Scrollbar(listFrame, command = self.valList.xview, orient=HORIZONTAL)
        self.valList.configure(yscrollcommand = scrollY.set)
        self.valList.configure(xscrollcommand = scrollX.set)
        scrollY.grid(row=1, column=1,sticky=NS)
        scrollX.grid(row=2, column=0,sticky=EW)
        self.valList.grid(row=1,column=0,sticky=W+E+N+S )
        listFrame.pack(side=LEFT,fill=Y,expand=1,padx=5,pady=5)

        okCancelFrame = Frame(self)
        restSelBut = Button(okCancelFrame,text="Restore selected",command=self.restSelCmd)
        restAllBut = Button(okCancelFrame,width=8,text="Restore all",command=self.restAllCmd)
        cnBut = Button(okCancelFrame,width=8,text="Don't restore",command=self.cancelCmd)
        restAllBut.grid(row=0,column=0)
        restSelBut.grid(row=0,column=1)
        cnBut.grid(row=0,column=2)
        okCancelFrame.pack(side=BOTTOM,padx=5,pady=5,anchor=E)

        self.store = step.saveRestObj.getStore()
        for item in self.store: 
            self.valList.insert(END, item)

    def restSelCmd(self):
        restItems = self.valList.curselection()
        self.hasDeletedItems = True
        for Item in restItems:
            idx = int(Item)
            print "Restore Selected",Item
            self.valList.delete(idx)
        self.destroy()
            
    def restAllCmd(self):
        restItems = self.valList.curselection()
        for Item in restItems:
            idx = int(Item)
            print "Restore Selected",Item
            self.valList.delete(idx)
        self.destroy()

    def cancelCmd(self):
        self.callbackFunc(None)
        self.destroy()
            
def main():
    def mainGetFunc(x) :
        print "mainGetFunc: ",x
        root.destroy()
        
    root = Tk()
#    ConfigMeasDialog(["motest:mo0","motest:mo1"],mainGetFunc)
    ChooseConfigDialog(".",mainGetFunc)
    mainloop()
    
if __name__ == "__main__":
    #print __doc__
    main()
