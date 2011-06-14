#! /usr/bin/env python
# -*- coding: UTF-8 -*- 

# This software is copyrighted by the 
# Helmholtz-Zentrum Berlin fuer Materialien und Energie GmbH (HZB), 
#  Berlin, Germany.
# The following terms apply to all files associated with the software.
# 
# HZB hereby grants permission to use, copy and modify this
# software and its documentation for non-commercial, educational or
# research purposes provided that existing copyright notices are
# retained in all copies.
# 
# The receiver of the software provides HZB with all enhancements, 
# including complete translations, made by the receiver.
# 
# IN NO EVENT SHALL HZB BE LIABLE TO ANY PARTY FOR DIRECT, INDIRECT,
# SPECIAL, INCIDENTAL OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE
# OF THIS SOFTWARE, ITS DOCUMENTATION OR ANY DERIVATIVES THEREOF, EVEN 
# IF HZB HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
# 
# HZB SPECIFICALLY DISCLAIMS ANY WARRANTIES, INCLUDING, BUT NOT LIMITED
# TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
# PURPOSE, AND NON-INFRINGEMENT. THIS SOFTWARE IS PROVIDED ON AN "AS IS"
# BASIS, AND HZB HAS NO OBLIGATION TO PROVIDE MAINTENANCE, SUPPORT,
# UPDATES, ENHANCEMENTS OR MODIFICATIONS.

from optparse import OptionParser
import re
import tempfile
import subprocess
import sys

_no_check= len(sys.argv)==2 and (sys.argv[1] in ("-h","--help","--summary"))
try:
    import Tix
except ImportError:
    if _no_check:
        sys.stderr.write("WARNING: (in %s) mandatory module Tix not found\n" % \
                         sys.argv[0])
    else:
        raise

import os.path
import os

# version of the program:
my_version= "1.0"

_hg_root= None
_hgidentify= None
_pids=[]

def _system(cmd, catch_stdout, verbose, dry_run):
    """execute a command.

    execute a command and return the programs output
    may raise:
    IOError(errcode,stderr)
    OSError(errno,strerr)
    ValueError
    """
    if dry_run or verbose:
        print ">", cmd
        if dry_run:
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

def _system_fork(cmd, catch_stdout, verbose, dry_run, cleanup):
    pid= os.fork()
    if pid!=0:
        _pids.append(pid)
        return pid
    result= _system(cmd, catch_stdout, verbose, dry_run)
    if cleanup is not None:
        cleanup(result)
    sys.exit(0)

def script_shortname():
    """return the name of this script without a path component."""
    return os.path.basename(sys.argv[0])
          
def print_summary():
    """print a short summary of the scripts function."""
    print "%-20s: display mercurial patches with tkdiff\n" % script_shortname()

def heading(revisions, verbose, dry_run):
    """generate a heading."""
    if len(revisions)<=0:
        return "rev %s (current) <--> working copy" % hgidentify(verbose,dry_run)
    if len(revisions)==1:
        return "rev %s <--> working copy" % revisions[0]
    return "rev %s <--> rev %s" % (revisions[0],revisions[1])

def hg_loglist(verbose, dry_run):
    """return all logs, one tuple per entry."""
    result= _system("hg log --template '{rev}:{desc|firstline}\n'", 
                    True, verbose, dry_run)
    new= []
    for l in result.splitlines():
        parts= l.split(":",1)
        new.append((int(parts[0]),parts[1]))
    return new

def hg_full_loglist(verbose, dry_run):
    """return all logs, full text.
    
    This returns a dictionary with local (short) revision numbers as key and
    each log message as a list of lines.
    """
    result= _system("hg log --template ':REVISION:{rev}\n{desc}\n'", 
                    True, verbose, dry_run)
    rev= None
    nrev= None
    txt= []
    logs= {}
    for l in result.splitlines():
        if l.startswith(":REVISION:"):
            idx= l.find(":",1)
            try:
                nrev= int(l[idx+1:])
                txt= []
                logs[nrev]= txt
                continue
            except ValueError, e:
                pass
        txt.append(l)
    return logs

def hgidentify(verbose, dry_run):
    """return current revision number."""
    global _hgidentify
    if _hgidentify is None:
        result= _system("hg identify -n", True, verbose, dry_run)
        result=result.strip()
        if result[-1]=="+":
            result= result[0:-1]
        _hgidentify= result
    return _hgidentify

def hgparents(revision, verbose, dry_run):
    """return the parent(s) of a revision."""
    result= _system("hg parents -r %s --template \"{rev} \"" % revision, 
                    True,
                    verbose, dry_run)
    if result=="" or result.isspace():
        return []
    return result.strip().split()

def hgchild(revision, verbose, dry_run):
    """return the child of a revision."""
    result= _system("hg log -r %s:tip --template \"{rev} \"" % revision, 
                    True,
                    verbose, dry_run)
    r= result.strip().split()
    if len(r)<=1:
        return None
    return r[1]

def hgplusminus(revision, delta, verbose, dry_run):
    """return parent or child of a revision."""
    if delta<0:
        return hgparents(revision, verbose, dry_run)
    c= hgchild(revision, verbose, dry_run)
    if c is None:
        return []
    return [c]

def hgtip(verbose, dry_run):
    """return the parent(s) of a revision."""
    result= _system("hg tip --template \"{rev}\"",
                    True,
                    verbose, dry_run)
    return result.strip()

def hgstatus(revisions, verbose, dry_run):
    """return the hg status.
    """
    extra=""
    if len(revisions)>0:
        extra= " "+" ".join(["--rev %s" % r for r in revisions])
    result= _system("hg status%s" % extra, True, verbose, dry_run)
    return result.splitlines()

def hgcat(revision, file, outfile, verbose, dry_run):
    """return the hg status.
    """
    extra= ""
    if revision is not None:
        extra=" -r %s" % revision
    result= _system("hg cat%s %s > %s" % (extra,file,outfile), True, verbose, dry_run)
    return result.splitlines()

def hgcattemp(revision, file, verbose, dry_run):
    """cat a file to a temporary file."""
    base= os.path.basename(file)
    temp= tempfile.mkstemp("-hgdiff-%s" % base)
    os.close(temp[0])
    hgcat(revision, file, temp[1], verbose, dry_run)
    return temp[1]

def hgroot(verbose, dry_run):
    """return hg root."""
    global _hg_root
    if _hg_root is None:
        result= _system("hg root", True, verbose, dry_run)
        _hg_root= result.strip()
    return _hg_root

def give_filepath(file, verbose, dry_run):
    """return the absolute path of a file."""
    return os.path.join(hgroot(verbose,dry_run),file)

def show(file, verbose, dry_run):
    """show a file."""
    file= give_filepath(file, verbose, dry_run)
    result= _system_fork("gview -f %s" % file, False, verbose, dry_run, None)

def show_delete(file, verbose, dry_run):
    """show a file and delete it afterwards."""
    file= give_filepath(file, verbose, dry_run)
    def _delete(dummy):
        os.remove(file)
    result= _system_fork("gview -f %s" % file, False, verbose, dry_run,
                         _delete)

def show_revision(revision, file, verbose, dry_run):
    """show a file of a given revision."""
    t= hgcattemp(revision, file, verbose, dry_run)
    show_delete(t, verbose, dry_run)

def diff(revisions, file, verbose, dry_run):
    """show the difference for a file.

    if revision1 and revision2 are none, show the local changes.
    """
    revlabels= []
    if len(revisions)<=0:
        revlabels= [hgidentify(verbose,dry_run)]
    else:
        revlabels= [revisions[0]]
    if len(revisions)<2:
        revlabels.append("working copy")
    else:
        revlabels.append(revisions[1])
    labelpar= "-L \"%s:%s\" -L \"%s:%s\"" % (file,revlabels[0],file,revlabels[1])

    t1= hgcattemp(revisions[0] if len(revisions)>0 else None, file, verbose, dry_run)
    del_list=[t1]
    t2= None
    if len(revisions)>1:
        t2= hgcattemp(revisions[1], file, verbose, dry_run)
        del_list.append(t2)
    else:
        t2= give_filepath(file, verbose, dry_run)
    remove_cmd= "rm -f %s" % t1
    def _delete(dummy):
        for f in del_list:
            os.remove(f)
    _system_fork("tkdiff %s %s %s; true" % (t1,t2,labelpar), False, verbose, dry_run, _delete)

class RevisionData(object):
    def __init__(self, verbose, dry_run):
        self._logs= None
        self._verbose= verbose
        self._dry_run= dry_run
    def get_logs(self):
        """get all revision numbers with summary."""
        self._logs= hg_full_loglist(self._verbose, self._dry_run)
    @staticmethod
    def _logline(rev,log):
        """create a logline string."""
        return "%4d: %s" % (rev,log)
    def revision_is_valid(self, revision):
        if self._logs is None:
            self.get_logs()
        return self._logs.has_key(revision)
    def logline(self, revision):
        if revision is None:
            return "working copy"
        if self._logs is None:
            self.get_logs()
        return RevisionData._logline(revision, self._logs[revision][0])
    def loglines(self):
        if self._logs is None:
            self.get_logs()
        return [RevisionData._logline(k, self._logs[k][0]) \
                   for k in sorted(self._logs.keys(),reverse=True)]
    def full_log(self, revision):
        if self._logs is None:
            self.get_logs()
        if revision is None:
            # None: working copy
            return None
        return self._logs[revision]

class RevisionSelector(Tix.ComboBox):
    """class for the combobox for the revision selection.
    """
    _rx_no= re.compile(r'^\s*(\d+)(?:\s*$|\s*:)')
    _verbose= False
    _dry_run= False
    def __init__(self, parent, revisiondata, verbose, dry_run):
        Tix.ComboBox.__init__(self, parent, 
            dropdown= True, 
            editable= True,
            validatecmd= lambda val: self.validate_callback(val))
        self.slb= self.subwidget("slistbox")
        self.lb= self.subwidget("listbox")
        self.en= self.subwidget("entry")
        self.lb.config(width= 80, bg="white")
        self.en.config(width=80)
        self.en.config(disabledbackground="grey")
        self.en.config(disabledforeground="black")
        self.revisiondata= revisiondata
        RevisionSelector._verbose= verbose
        RevisionSelector._dry_run= dry_run
        self.revision= None # working copy
    def set_change_callback(self, callback):
        """call callback when value changes."""
        self.config(command=lambda x: callback())
    @staticmethod
    def get_no(st):
        """returns the number the string starts with.

        returns:
            None: if not found
            integer : otherwise
        """
        m= RevisionSelector._rx_no.match(st)
        if m is None:
            return None
        return int(m.group(1))
    def curr_logline(self):
        """returns the logline string currently selected."""
        return self.revisiondata.logline(self.revision)
    def create_selection_list(self):
        """rebuilds the selection list.
        """
        loglines= self.revisiondata.loglines()
        self.lb.delete(0, Tix.END)
        self.lb.insert(0, *loglines)
        self.lb.insert(0, "working copy")
    def validate_callback(self,val):
        """validate a value, possibly correct it."""
        if val=="working copy" or val.isspace() or val=="":
            self.revision= None
        else:
            new= RevisionSelector.get_no(val)
            if new is not None:
                if self.revisiondata.revision_is_valid(new):
                    self.revision= new
        return self.curr_logline()
    def get_revision(self):
        """returns the revision as an integer or <None>."""
        return self.revision
    def set_value(self, string):
        """sets a new value (as a string)."""
        self.config(value=string)

class FrHeadClass(Tix.Frame):
    """Class for the top Tix.Frame, derived from Tix.Frame.
    
    Creates the top frame for the menu. The menu currently
    only contains a "quit" button.
    """
    def __init__(self, parent, revisions, change_callback, 
                 statuslabel, revisiondata, verbose, dry_run):
        def balloonhelp(widget,message):
            w= Tix.Balloon(self, statusbar= statuslabel)
            w.bind_widget(widget, statusmsg=message)
        self.revisiondata= revisiondata
        self.verbose= verbose
        self.dry_run= dry_run
        self.statuslabel= statuslabel
        Tix.Frame.__init__(self, parent, borderwidth=2,relief='raised') 

        self.logwindow= LogWindow()
        self.combo1_label= Tix.Label(self, text="first rev:")
        self.combo2_label= Tix.Label(self, text="second rev:")
        self.combo1= RevisionSelector(self, revisiondata, verbose, dry_run)
        self.combo2= RevisionSelector(self, revisiondata, verbose, dry_run)
        self.combo1.create_selection_list()
        self.combo2.create_selection_list()

        self.labelsep= Tix.Label(self, text=" ")
        # make a shallow copy of revisions, otherwise
        # the "append" some lines below would change the
        # list that was given as parameter to the constructor
        revisions= revisions[:]
        if len(revisions)<=0:
            revisions= [hgidentify(verbose, dry_run)]
        if len(revisions)<2:
            revisions.append("working copy")
        self.combo1.set_value(revisions[0])
        self.combo2.set_value(revisions[1])
        self.buttonframe= Tix.Frame(self)
        self.button= Tix.Button(self.buttonframe, text="re-scan", command= lambda: self.rescan_callback())
        self.plusbutton= Tix.Button(self.buttonframe, text="+rev", command= lambda: self.plusminus_rev_callback(1))
        self.minusbutton= Tix.Button(self.buttonframe, text="-rev", command= lambda: self.plusminus_rev_callback(-1))
        self.deltabutton= Tix.Button(self.buttonframe, text="delta:=1", command= lambda: self.delta_rev_callback())
        self.logbutton= Tix.Button(self.buttonframe, text="full-log", command= lambda: self.fulllog())
        self.change_callback= change_callback

        balloonhelp(self.combo1, "the revision against the comparison is done")
        balloonhelp(self.combo2, "the compared revision, enter a number or \"\" for \"working copy\"")
        balloonhelp(self.button, "re-compute the list of changed files and the list of revisions")
        balloonhelp(self.plusbutton, "increase both revisions")
        balloonhelp(self.minusbutton, "decrease both revisions")
        balloonhelp(self.deltabutton, "set first revision to second revision - 1")
        balloonhelp(self.logbutton, "show full log for second revision")

        self.combo1_label.grid(row=0, column=0, sticky="W")
        self.combo2_label.grid(row=3, column=0, sticky="W")
        self.combo1.grid(row=0, column=1, sticky="W")
        self.combo2.grid(row=3, column=1, sticky="W")
        self.labelsep.grid(row=2, column=0, sticky="W")

        self.buttonframe.grid(row=5, column=0, columnspan=2, sticky="W")
        self.button.pack(side=Tix.LEFT)
        self.plusbutton.pack(side=Tix.LEFT)
        self.minusbutton.pack(side=Tix.LEFT)
        self.deltabutton.pack(side=Tix.LEFT)
        self.logbutton.pack(side=Tix.LEFT)
        self.combo1.set_change_callback(lambda: self.combo_sel_callback())
        self.combo2.set_change_callback(lambda: self.combo_sel_callback())
    def update_logwindow(self):
        if self.logwindow.is_opened():
            revs= self.get_selected_revisions()
            self.logwindow.open(revs[1], self.revisiondata.full_log(revs[1]))
    def combo_sel_callback(self):
        """callback when a new item is selected on the combobox."""
        self.update_logwindow()
        self.change_callback()
    def rescan_callback(self):
        """callback for the re-scan button."""
        revisions= self.get_selected_revisions()
        self.revisiondata.get_logs()
        self.combo1.create_selection_list()
        self.combo2.create_selection_list()
        self.update_logwindow()
        self.change_callback()
    def fulllog(self):
        """show full log in a window."""
        def error(msg):
            self.statuslabel.config(text= msg)
        revs= self.get_selected_revisions()
        self.logwindow.open(revs[1], self.revisiondata.full_log(revs[1]))
    def delta_rev_callback(self):
        """sets first revision to second revision - 1."""
        def error(msg):
            self.statuslabel.config(text= msg)
        revs= self.get_selected_revisions()
        rev_now= revs[1]
        if revs[1] is None:
            rev_prev= hgtip(self.verbose,self.dry_run)
            rev_now= ""
        else:
            r= hgplusminus(revs[1], -1, self.verbose, self.dry_run)
            if len(r)!=1:
                error("error: %s has more than one parent" % revs[1])
                return
            rev_prev= r[0]
        self.set_entry(1,rev_prev)
        self.set_entry(2,rev_now)
        # do not call rescan_callback here, this would re-initialize the
        # comboboxes which is not necessary since we just change
        # the selected revision numbers.
        self.update_logwindow()
        self.change_callback()

    def plusminus_rev_callback(self,delta):
        def error(msg):
            self.statuslabel.config(text= msg)
        revs= self.get_selected_revisions()
        if revs[1] is None:
            if delta>0:
                error("error: cannot go beyond working copy")
                return
            rev_now= hgtip(self.verbose,self.dry_run)
        else:
            r= hgplusminus(revs[1], delta, self.verbose, self.dry_run)
            if len(r)==0:
                # last revision
                rev_now=""
            elif len(r)!=1:
                error("error: %s has more than one parent" % revs[1])
                return
            else:
                rev_now= r[0]
        r= hgplusminus(revs[0], delta, self.verbose, self.dry_run)
        if len(r)!=1:
            error("error: %s has more than one parent" % revs[1])
            return
        rev_prev= r[0]
        self.set_entry(1,rev_prev)
        self.set_entry(2,rev_now)
        # do not call rescan_callback here, this would re-initialize the
        # comboboxes which is not necessary since we just change
        # the selected revision numbers.
        self.update_logwindow()
        self.change_callback()

    def set_entry(self, index, value):
        if index==1:
            widget= self.combo1
        else:
            widget= self.combo2
        widget.set_value(value)
    def get_selected_revisions(self):
        """returns a pair, the 2nd element may be None"""
        wk= "working copy"
        r1= self.combo1.get_revision()
        r2= self.combo2.get_revision()
        return (r1,r2)

class FrTopClass(Tix.Frame):
    """Class for the top Tix.Frame, derived from Tix.Frame.
    
    Creates the top frame for the menu. The menu currently
    only contains a "quit" button.
    """
    def __init__(self, parent, selection_list, callback, statuslabel):
        Tix.Frame.__init__(self, parent, borderwidth=2,relief='raised') 
        self.scrollbar= Tix.Scrollbar(self)
        self.scrollbar.pack(side=Tix.RIGHT, fill=Tix.Y)
        self.listbox= Tix.Listbox(self)
        self.listbox.pack(side=Tix.LEFT, fill="both", expand="y")
        self.scrollbar["command"]= self.listbox.yview
        self.listbox["yscrollcommand"]= self.scrollbar.set
        if callback is not None:
            self.listbox.bind("<Double-Button-1>", lambda event: callback())
        self.statuslabel= statuslabel
        self.change(selection_list)

        self.listbox_help= Tix.Balloon(self, statusbar= statuslabel)
        self.listbox_help.bind_widget(self.listbox, 
                                      statusmsg="double-click to run tkdiff " +
                                                "or gview on the selected file"
                                     )
    def change(self,newlist):
        self.listbox.delete(0, Tix.END)
        self.items= newlist[:]
        for s in newlist:
           self.listbox.insert(Tix.END, str(s))
    def selection(self):
        sel= self.listbox.curselection()
        if len(sel)<=0:
            self.statuslabel.config(text= "error: no file is selected!")
            return
        return self.items[int(sel[0])]

class FrDnClass(Tix.Frame):
    """Class for the down Tix.Frame, derived from Tix.Frame
    
    contains everything except the menu.
    """
    def __init__(self, parent, callback, statuslabel):
        Tix.Frame.__init__(self, parent) 
        self.quitbutton = Tix.Button(self, text="QUIT", fg="red", command=parent.quit)
        self.quitbutton.pack(side=Tix.LEFT)

        self.quitbutton_help= Tix.Balloon(self, statusbar= statuslabel)
        self.quitbutton_help.bind_widget(self.quitbutton, 
                                         statusmsg="press this button to exit the program"
                                        )

        self.selectbutton = Tix.Button(self, text="Select", command=callback)
        self.selectbutton.pack(side=Tix.LEFT)

        self.selectbutton_help= Tix.Balloon(self, statusbar= statuslabel)
        self.selectbutton_help.bind_widget(self.selectbutton, 
            statusmsg="run tkdiff or gview on the selected file")

class FrStatClass(Tix.Frame):
    """Class for the down Tix.Frame, derived from Tix.Frame
    
    contains everything except the menu.
    """
    def __init__(self, parent):
        Tix.Frame.__init__(self, parent) 
        self.label= Tix.Label(self)
        self.label.pack(side=Tix.LEFT, fill="x")
    def display(self, text):
        self.label.config(text= text)

class LogWindow(object):
    def __init__(self, lines=[]):
        self.opened= False
    def is_opened(self):
        return self.opened
    def open(self, revision, lines):
        if not self.opened:
            self.top= Tix.Toplevel()
            self.top.protocol("WM_DELETE_WINDOW", lambda: self.destroy_handler())
            self.scrollbar= Tix.Scrollbar(self.top)
            self.scrollbar.pack(side=Tix.RIGHT, fill="y")
            self.txt= Tix.Text(self.top, yscrollcommand= self.scrollbar.set)
            self.txt.pack(side='top', fill='both', expand='y')
            self.scrollbar.config(command=self.txt.yview)
            self.opened= True
        if revision is None:
            self.top.title("working copy")
            self._fill([])
        else:
            self.top.title("Log of revision %d" % revision)
            self._fill(lines)
    def destroy_handler(self):
        self.top.destroy()
        self.opened= False
    def _fill(self, lines):
        if not self.opened:
            self.open()
        self.txt.config(state=Tix.NORMAL)
        self.txt.delete(1.0,Tix.END)
        self.txt.insert(Tix.END, "\n".join(lines))
        self.txt.config(state=Tix.DISABLED)

class App(object):
    def __init__(self, Top, options, args):
        self.revisions= []
        self.verbose= options.verbose
        self.dry_run= options.dry_run
        self.revisiondata= RevisionData(options.verbose, options.dry_run) # hold data on revisions
        if options.changes is not None:
            if options.rev is not None:
                sys.exit("-c must not be used together with -r")
            r= hgparents(options.changes, self.verbose,self.dry_run)
            if len(r)!=1:
                sys.exit("-c cannot be applied to a merge revision")
            self.revisions=[r[0],options.changes]
        elif options.rev is not None:
            self.revisions= options.rev
            if len(options.rev)>2:
                sys.exit("only up to 2 revision numbers may be specified")
            self.revisions= options.rev
        hg_changes= hgstatus(self.revisions,self.verbose,self.dry_run)
        self.options= options

        Top.title("hgdiff")
        self.FrStat = FrStatClass(Top)

        self.FrHead= FrHeadClass(Top, self.revisions, 
                                 lambda: self.rescan(),
                                 self.FrStat.label,
                                 self.revisiondata,
                                 self.verbose, self.dry_run)
        self.FrHead.pack(side='top', fill='x')
        
        self.FrTop= FrTopClass(Top, hg_changes, 
                               lambda : self.execute(),
                               self.FrStat.label,
                              )
        self.FrTop.pack(side='top' ,fill='both', expand="y")
        
        self.FrDn = FrDnClass(Top, 
                              lambda : self.execute(),
                              self.FrStat.label,
                             )
        self.FrDn.pack (side='top',fill='x')
        
        self.FrStat.pack (side='top',fill='x')
        self.process_initial_list(hg_changes, args)
    def display(self, text):
        self.FrStat.display(text)
    def rescan(self):
        def isset(x):
            if x is None:
                return False
            if x == "":
                return False
            return True
        self.revisions= filter(isset, self.FrHead.get_selected_revisions())
        hg_changes= hgstatus(self.revisions,self.verbose,self.dry_run)
        self.FrTop.change(hg_changes)
    def process_initial_list(self, changes_list, args):
        if len(args)<=0:
            return
        files= set()
        for f in args:
            not_found= True
            for c in changes_list:
                if c.endswith(f):
                    not_found= False
                    files.add(c)
            if not_found:
                print "warning: path \"%s\" not found in list of changed/added/removed files" % f
        for f in files:
            self.execute_str(f)
    def execute(self):
        """execute selection."""
        selection= self.FrTop.selection()
        if selection is None:
            return
        self.execute_str(selection)
    def execute_str(self, selection):
        flag= selection[0]
        file= selection[2:]
        if flag=="?" or flag=="I":
            # unknown or ignored files should always be present in the
            # working copy:
            show(file, self.verbose, self.dry_run)
        elif flag=="A" or flag=="C":
            if len(self.revisions)<=1:
                r= None
            else:
                r= self.revisions[1]
            if r is None:
                # show() can only be used on files present in the working copy:
                show(file, self.verbose, self.dry_run)
            else:
                # for files (possibly) no longer in the working copy, 
                # show_revision() has to be used:
                show_revision(r, file, self.verbose, self.dry_run)
        elif flag=="D" or flag=="!" or flag=="R":
            if len(self.revisions)<=0:
                r= None
            else:
                r= self.revisions[0]
            show_revision(r, file, self.verbose, self.dry_run)
        else:
            diff(self.revisions, file, self.verbose, self.dry_run)

def ext_compare(options, args, progname, multi_file_capable):
    """just call an external compare program.
    """
    cmd_args=["hg","extdiff","-p",progname]
    rev_spec=[]
    if options.changes is not None:
        if options.rev is not None:
            sys.exit("-c must not be used together with -r")
        rev_spec=["","-c", options.changes]
    elif options.rev is not None:
        if len(options.rev)>2:
            sys.exit("only up to 2 revision numbers may be specified")
        rev_spec=[""]
        for r in options.rev:
            rev_spec.extend(("-r",r))
    if multi_file_capable:
        os.execvp("hg",cmd_args+rev_spec)
        return
    stat_revspec= [x.replace("-c","--change") for x in rev_spec]
    _system("hg status%s" % (" ".join(stat_revspec)), False, True, options.dry_run)
    if len(args)>0:
        files= args
    else:
        modified= _system("hg status -m -n%s" % (" ".join(stat_revspec)),
                          True, options.verbose, options.dry_run)
        if modified=="":
            sys.exit("no modified files")
        files= modified.splitlines()
    if len(files)>20:
        sys.exit("error, more than 20 files to view, use --kompare or --meld instead")
    for f in files:
        os.spawnvp(os.P_NOWAIT,"hg",cmd_args+rev_spec+[f])
    return



    print "hg status:"

def main():
    """The main function.
    
    parse the command-line options and perform the command
    """
    # command-line options and command-line help:
    usage = "usage: %prog [options] {file list}"
    parser = OptionParser(usage=usage,
                          version="%%prog %s" % my_version,
                          description="graphical display of changes between "+\
                                      "mercurial revisions or a mercurial "+\
                                      "revision and a working copy. If {file list} "+\
                                      "is not empty, run tkdiff or gview on these files")
    parser.add_option("--summary",  # implies dest="nodelete"
                      action="store_true", # default: None
                      help="graphical diff for mercurial", 
                      )

    parser.add_option("--dry-run",    # implies dest="switch"
                      action="store_true", # default: None
                      help="do not execute commands, just show them", 
                      )
    parser.add_option("-v", "--verbose",    # implies dest="switch"
                      action="store_true", # default: None
                      help="show executed external commands", 
                      )
    parser.add_option("-k", "--kompare",    # implies dest="switch"
                      action="store_true", # default: None
                      help="show changes with kompare", 
                      )
    parser.add_option("-m", "--meld",    # implies dest="switch"
                      action="store_true", # default: None
                      help="show changes with meld", 
                      )

    parser.add_option("-r", "--rev", # implies dest="file"
                      action="append", # OptionParser's default
                      type="string",  # OptionParser's default
                      help="specify the REVISION against the comparision is done. "+\
                           "If two --rev options are given, compare these two "+\
                           "revisions.", 
                      metavar="REVISION"  # for help-generation text
                      )

    parser.add_option("-c", "--changes", # implies dest="file"
                      action="store", # OptionParser's default
                      type="string",  # OptionParser's default
                      help="show that changes that REVISION did.",
                      metavar="REVISION"  # for help-generation text
                      )
    parser.add_option("-q", "--quick",    # implies dest="switch"
                      action="store_true", # default: None
                      help="directly show all changes by running "+\
                           "tkdiff. If you want this to be done only for "+\
                           "a specific list of files add them after the command, "+\
                           "otherwise all *modified* files are shown.",
                      )


    (options, args) = parser.parse_args()
    # options: the options-object
    # args: list of left-over args

    if options.summary:
        print_summary()
        sys.exit(0)

    use_fork= False# (os.name == 'posix')
    if use_fork:
        print "starting hgdiff.py..."
        pid= os.fork()
        if pid!=0:
            sys.exit(0)

    # change to the working copy's root dir, since
    # "hg cat" will not work when we are in a different
    # directory.
    os.chdir(hgroot(options.verbose, options.dry_run))

    if options.kompare:
        ext_compare(options,args,"kompare",True)
        sys.exit(0)
    if options.meld:
        ext_compare(options,args,"meld",True)
        sys.exit(0)
    if options.quick:
        ext_compare(options,args,"tkdiff",False)
        sys.exit(0)
        
    root = Tix.Tk()

    app = App(root, options, args)
#    app.master.title("IDCP (%s@%s)" % \
#                     (username(),hostname()))

    root.mainloop()

    sys.exit(0)

if __name__ == "__main__":
    main()

