"""a module that implements the class FilterFile.

That simple class is used to create a filehandle to
a file or a filehandle to standard-in or standard-out.

# This software is copyrighted by the 
# Helmholtz-Zentrum Berlin fuer Materialien und Energie GmbH (HZB), 
# Berlin, Germany.
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
"""

import sys
import os
import shutil
import tempfile

def _copyperm(src,dest):
	"""copy file permission and GID from one file to another."""
	statinfo = os.stat(src)
	# st_mode , st_ino , st_dev , st_nlink , st_uid ,
	# st_gid , st_size , st_atime , st_mtime , st_ctime
	os.chown(dest,-1,statinfo[5])
	os.chmod(dest, statinfo[0])


class FilterFile(object):
	"""a file-object for writing filter utilities.

	This object contains a filehandle to an ordinary file
	or to standard-in or standard-out."""
	def __init__(self,filename=None,
		     opennow=False,
		     mode="r",replace_ext="bak"):
		"""constructor of a FilterFile. Arguments:

		parameters:
		filename             -- the filename or None in order
					to open stdin or stdout
					default: None
		opennow		     -- if True, open the file just after
					object creation. default: False
		mode		     -- the filemode as it is described for
					the python open() function.
					when filename is None, mode "r" opens
					stdin, mode "w" or mode "u" opens
					stdout. A special case is mode "u",
					with python open() doesn't know of.
					When filename is not None, mode "u"
					opens a temporary-file that is
					renamed to the original file upon
					close. The original file is renamed
					to filename.<replace_ext>.
		replace_ext	     -- the filename-extension for the backup
					of the original file when "u" is
					used for the mode parameter.
		"""
		self._filename= filename
		self._replace_ext= replace_ext
		self._tempname= None
		self._fh= None
		self._mode= mode
		if opennow:
			self.open()
	def __del__(self):
		"""deletion method of FilterFile.

		This method closes a file if a file was opened"""
		#print "filehandle closed!"
		self.close()
	def open(self):
		"""open the file.

		If the filename is None, standard-in or standard-out
		are not actually opened but only their filehandles
		are stored within the FilterFile object."""
		self.close()
		if self._filename is None:
			# use stdin or stdout
			if self._mode=="r":
				self._fh= sys.stdin
			elif self._mode in ("w","a","u"):
				self._fh= sys.stdout
			else:
				raise ValueError, \
				      "filename None is only supported "+\
				      "for modes \"r\",\"w\"\"a\"and \"u\" "+\
				      "mode here is: \"%s\"" % self._mode
		else:
			if self._mode == "u":
				# start by opening a temp-file
				(fd,self._tempname)= tempfile.mkstemp()
				# print "tempfile:",self._tempname
				self._fh= os.fdopen(fd,"w")
			else:
				self._fh= open(self._filename,self._mode)
	def close(self):
		"""close the file.

		If standard-in or standard-out were actually selected,
		they are not closed."""
		if self._fh is None:
			return
		if self._filename is not None:
			self._fh.close()
			if self._tempname is not None:
				_copyperm(self._filename,self._tempname)
				if self._replace_ext is None:
					os.remove(self._filename)
				else:
					os.rename(self._filename,
						"%s.%s" % \
						(self._filename,\
						 self._replace_ext))
				shutil.copy2(self._tempname,self._filename)
				_copyperm(self._tempname,self._filename)
				os.remove(self._tempname)
				self._tempname= None
		self._fh= None
	def fh(self):
		"""return the filehandle of the currently opened file."""
		return self._fh
	def write(self, *args):
		"""write to the currently opened file.

		This method simply calls self.fh().write(args)."""
		self._fh.write(*args)
	def read(self, *args):
		"""read from the currently opened file.

		This method simply calls self.fh().read(args)."""
		return self._fh.read(*args)
	def readline(self, *args):
		"""read a line from the currently opened file.

		This method simply calls self.fh().readline(args)."""
		return self._fh.readline(*args)
	def print_to_screen(self):
		"""print the contents of the file to the screen.

		This function prints the contents of the currently
		in read-mode opened file to standard-out.
		Note that it raises an exception of there is no
		file open or if the mode is not "r".
		"""
		if self._fh is None:
			raise IOError,"file is currently no opened"
		if self._mode != "r":
			raise IOError,"file-mode must be \"r\" "+\
			              "but is \"%s\"" % self._mode
		for line in self._fh:
			print line



