''' tkDialogInput is an enhancement for tkDialog

Exaple for all following routines:
>>> from tkdialogplus import *
>>> r = Tk()
'''

from Tkinter import *

class tkDialogInput():
    ''' Getting a string back from entry input

    Example:
    >>> d = tkDialogInput(r)
    >>> print d.get("na dann", "1")
    '''
    window = None
    result = None
    parent = None
    __wid_input = None

    def __init__(self, parent):
        self.parent = parent
        self.window = Toplevel(parent)
        self.window.transient(parent)
        self.result = None

    def get(self, message, title=None, default=None, width=20, ok="Ok", cancel="Cancel"):
        if title:
            self.window.title(title)
        if width:
            e_width=width
        else:
            e_width=20
        widget = Frame(self.window)
        wid_message = Label(widget, text=message)
        wid_message.pack(side=LEFT, padx=5, pady=5, fill=X, expand=1)
        self.__wid_input = Entry(widget, width=e_width, text=default)
        self.__wid_input.pack(side=LEFT, padx=5, pady=5, fill=X, expand=1)
        widget.pack(padx=5, pady=5)
        box = Frame(self.window)
        wid_ok = Button(box, text=ok, width=10, command=self.__ok_cb, default=ACTIVE)
        wid_ok.pack(side=LEFT, padx=5, pady=5)
        wid_cancel = Button(box, text=cancel, width=10, command=self.__cancel_cb)
        wid_cancel.pack(side=LEFT, padx=5, pady=5)
        self.window.bind("<Return>", self.__ok_cb)
        self.window.bind("<Escape>", self.__cancel_cb)
        box.pack(expand=1, fill=BOTH)
        self.window.protocol("WM_DELETE_WINDOW", self.__cancel_cb)
        self.window.geometry("+%d+%d" % (self.parent.winfo_rootx()+50, self.parent.winfo_rooty()+50))
        self.window.wait_window(self.window)
        return self.result

    def __ok_cb(self, event=None):
        self.window.withdraw()
        self.window.update_idletasks()
        self.result = self.__wid_input.get()
        self.parent.focus_set()
        self.window.destroy()

    def __cancel_cb(self, event=None):
        # put focus back to the parent window
        self.result = None
        self.parent.focus_set()
        self.window.destroy()