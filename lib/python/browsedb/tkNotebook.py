from Tkinter import *

'''
    Notebook IMplemntation started with teh one from http://code.activestate.com/recipes/188537/
    will be enhanced by self for better using GUI elements.
'''
class tkNotebook:
        ''' initialization. receives the master widget.
            reference and the notebook orientation
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
# END
