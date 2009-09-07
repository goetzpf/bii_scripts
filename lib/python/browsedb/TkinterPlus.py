#!/usr/bin/env python
# -*-python-*-
'''
======================
TkinterPlus.py
======================
------------------------------------------------------------------------------
tk expanding module for getting morefeatures
------------------------------------------------------------------------------
 
Overview
===============
- notebook/tab 
  Notebook Implemntation started with the one from http://code.activestate.com/recipes/188537/
- logindialog
  LoginDialog implementation for having a dialog to get login/authentification dialog
 
will be enhanced by self for better using GUI elements.
'''
 
from Tkinter import *

class Notebook:
        ''' initialization. receives the master widget.
            reference and the notebook orientation

	    Example:
	    >>> from Tkinter import *
	    >>> from tkNotebook import *
	    >>> root = Tk()

	    having tk environment, init the notebook class
	    >>> main = Notebook(root)

	    creating the tab content
	    >>> frame1 = Frame(main())
	    >>> label1 = Label(frame1, text="Tab 1")
	    >>> label1.pack(fill=BOTH, expand=1)
	    >>> frame2 = Frame(main())
	    >>> label2 = Label(frame2, text="Tab 2")
	    >>> label2.pack(fill=BOTH, expand=1)

	    adding the default shown screen followed by the others
	    >>> x1 = main.add(frame1, "Screen1")
	    >>> main.add(frame2, "Screen 2")
	    <Tkinter.Radiobutton instance at 0xb7a8b6ec>

	'''
	def __init__(self, master, side=LEFT):
		''' creates notebook's frames structure.
		    master is the to be bind to widget
		    side is a choice from TOP, BOTTOM of menu buttons
		'''
		self.active_fr = None
		self.count = 0
		self.choice = IntVar(0)
		if side in (TOP, BOTTOM):
			self.side = LEFT
		else:
			self.side = TOP
		self.rb_fr = Frame(master, borderwidth=2, relief=RIDGE)
		self.rb_fr.pack(side=side, fill=BOTH)
		self.screen_fr = Frame(master, borderwidth=2, relief=RIDGE)
		self.screen_fr.pack(fill=BOTH)

	def __call__(self):
	     	''' return a master frame reference for the external frames (screens).
		'''
		return self.screen_fr

	def add(self, fr, title):
		''' add a new frame (screen) to the (bottom/left of the) notebook
		'''
		b = Radiobutton(self.rb_fr, text=title, indicatoron=0, \
			variable=self.choice, value=self.count, \
		        command=lambda: self.display(fr))
		b.pack(fill=BOTH, side=self.side)
		# ensures the first frame will be
		# the first selected/enabled
                if not self.active_fr:
			fr.pack(fill=BOTH, expand=1)
			self.active_fr = fr
		self.count += 1
		# returns a reference to the newly created
                # radiobutton (allowing its configuration/destruction)         
		return b

	def display(self, fr):
		''' hides the former active frame and shows.
		    another one, keeping its reference
		'''
		self.active_fr.forget()
		fr.pack(fill=BOTH, expand=1)
		self.active_fr = fr

class LoginDialog:
        ''' initialization. receives the master widget.
            reference and the notebook orientation
	'''
	login_user = StringVar
	login_pass = StringVar
	login_serv = StringVar
	login_inst = StringVar

	def __init__(self, master, server=False, instance=False, profiles=None):
	    ''' creates the login dialog frame .
	        - master is the to be bind to widget
	        - server is a string for a server to be used
	        - instanz is a instanz to be connected
	        - profile a list od predefined values for the login
	    '''
	    self.main_fr = Toplevel(master, borderwidth=2)
	    self.main_fr.resizable(width=None, height=None)
	    self.screen_fr = Frame(main_fr)
	    if (server):
	        self.server_l = Label(main_fr, text="Server: ")
	        self.server_e = Entry(main_fr, textvariable=login_serv)
	    if (instance):
	        self.instance_l = Label(main_fr, text="Instance: ")
	        self.instance_e = Entry(main_fr, textvariable=login_inst)
	    self.user_l = Label(main_fr, text="Username: ")
	    self.user_e = Entry(main_fr, textvariable=login_user)
	    self.pass_l = Label(main_fr, text="Password: ")
	    self.pass_e = Entry(main_fr, textvariable=login_pass, show="*")
	    return self.main_fr

	def __call__(self):
	    ''' return a master frame reference for the external frames (screens).
	    '''
	    return self.main_fr

	def profiling(self, list):
	    ''' refills the profiles drop down list
	    '''

	def hide(self):
	    ''' hide the login top level window.
	    '''
	    self.main_fr.withdraw()

	def display(self, fr):
	    ''' displays the top level window..
	    '''
	    self.main_fr.deiconify()	

# END
