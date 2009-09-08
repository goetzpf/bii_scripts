#!/usr/bin/env python
# -*-python-*-
'''
======================
tkLoginDialog.py
======================
------------------------------------------------------------------------------
tk expanding module for getting morefeatures
------------------------------------------------------------------------------
 
Overview
===============
- Logindialog
  LoginDialog implementation for having a dialog to get login/authentification dialog

will be enhanced by self for better using GUI elements.
'''
 
from Tkinter import *

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
