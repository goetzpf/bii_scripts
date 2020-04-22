#! /usr/bin/env python2
# -*- coding: UTF-8 -*-

# Copyright 2015 Helmholtz-Zentrum Berlin für Materialien und Energie GmbH
# <https://www.helmholtz-berlin.de>
#
# Author: Goetz Pfeiffer <Goetz.Pfeiffer@helmholtz-berlin.de>
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

"""
======================
cvs-recover.py
======================
------------------------------------------------------------------------------
 a tool to backup and recover cvs working directories
------------------------------------------------------------------------------

Overview
===============
This tool can be used to backup and recover a cvs working
directory. 

Instead of saving the complete repository this script only saves
differences relative to a central cvs repository. By this,
much disk space is saved, the backup file has usually only about 
100kBytes or less.

Quick reference
===============

* create the recover file cvs-recover.tar.gz, current working
  directory must be a cvs working copy::

   cvs-recover.py -c

* recreate a working directory from the file cvs-recover.tar.gz::

   cvs-recover.py -r

* recreate a working directory from a file [file]::

   cvs-recover.py -r -f [file]

More examples
=============

* create a recover file with a given name::

   cvs-recover.py -c -f [myfile].tar.gz

* create a recover file with a given name and a given working copy::

   cvs-recover.py -c -f [myfile].tar.gz -w [working copy directory]

* create a recover directory with a given name. If the parameter
  after "-f" doesn't end with ".tar.gz", the recover directory is
  not packed into compressed tar file::

   cvs-recover.py -c -f [myfile]

* recreate a repository in a given directory from a recovery file::

   cvs-recover.py -r -f [file] -w [directory]

Reference of command line options
=================================

--version
  show program's version number and exit

-h, --help
  show the online-help an exit

--summary
  print a summary of the function of the program

--doc
  create online help in restructured text format. 
  Use "./cvs-recover.py --doc | rst2html" to create html-help"

-f FILENAME, --file=FILENAME
  create cvs recovery data in the given file or
  directory. If the given name ends with ".tar" or
  ".tag.gz", a tar file or a compressed tar file is
  created. The default for this is "cvs-recover.tar.gz"

-w WORKINGCOPY, --working-copy=WORKINGCOPY
  specify where the WORKINGCOPY is found, "." is the
  default. For --recover, this is the directory where the
  working copy directory will be created as a sub-
  directory.

-c, --create
  create cvs recovery data in the given
  DATA_DIRECTORY. If the given name ends with ".tar" or
  ".tag.gz", a tar file or a compressed tar file is
  created.

-r, --recover
  recover repository from the recovery data in the given
  DATA_DIRECTORY

-v, --verbose
  print to the screen what the program does

--dry-run
  do not apply any changes
"""


from optparse import OptionParser
#import string
import sys
import subprocess
import os
import os.path
import shutil
import tarfile
import datetime
import re

_no_check= len(sys.argv)==2 and (sys.argv[1] in ("-h","--help","--summary","--doc"))
try:
    import yaml
except ImportError:
    if _no_check:
        sys.stderr.write("WARNING: (in %s) mandatory module yaml not found\n" % \
                         sys.argv[0])
    else:
        raise

import re

# version of the program:
my_version= "1.0"

default_file= "cvs-recover.tar.gz"

# -----------------------------------------------
# basic system utilities
# -----------------------------------------------

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

def copyfile(src, dest, verbose, dry_run):
    """copies a file."""
    if dry_run or verbose:
        print "copy %s to %s" % (src,dest)
        if dry_run:
            return
    shutil.copyfile(src, dest)

def rm_all(path, verbose, dry_run):
    """remove dir or file, no error check."""
    if dry_run or verbose:
        print "remove \"%s\"" % path
        if dry_run:
            return
    if os.path.isdir(path):
        shutil.rmtree(path, ignore_errors= True)
    else:
        os.remove(path)

def rmdir(dir, verbose, dry_run):
    """remove recursivly a directory."""
    if dry_run or verbose:
        print "rm -rf %s" % dir
        if dry_run:
            return
    shutil.rmtree(dir)

def my_chdir(newdir, verbose):
    """change directory, return the old directory."""
    if newdir is None:
        return None
    olddir= os.getcwd()
    if verbose:
        print "cd %s" % newdir
    os.chdir(newdir)
    return olddir

def mkfile(text,filename, verbose, dry_run):
    """create a file with a given text.
    
    parameters:
        text      --  content of the file
        filename  --  the name of the file

    returns:
        the complete path of the file (the path that includes
        the name of the test directory)
    """
    if dry_run or verbose:
        print "creating %s" % filename
        if dry_run:
            return
    file= open(filename, "w")
    file.write(text)
    file.close()

# -----------------------------------------------
# date utilities
# -----------------------------------------------

def isodatetime(d):
    """converts a date to ISO format.

    This function returns the datetime.datetime
    object as an ISO date string of the form
    YYYY-MM-DDTHH:MM:SS.

    parameters:
        d       -- a datetime.datetime object
    returns:
        a string.

    Here are some examples:
    >>> isodatetime(datetime.datetime(2008, 10, 20, 11, 19, 30))
    '2008-10-20T11:19:30'
    """
    return d.strftime("%Y-%m-%dT%H:%M:%S")

# -----------------------------------------------
# path and filename utilities
# -----------------------------------------------

def last_path_element(path):
    """returns the last element of a path."""
    return os.path.split(path)[-1]

def splitpath(path):
    """converts a path to a list."""
    l= []
    while True:
      (path,t)= os.path.split(path)
      if t=="":
        l.reverse()
        return l
      l.append(t)

def splitext(path):
    """split file-name and extension."""
    ext= ""
    while True:
        (path,t)= os.path.splitext(path)
        if t=="":
            return (path,ext)
        ext= t+ext

def check_ext(path):
    """check if path ends with .tar or .tar.gz.
    
    This function also returns the mode for
    the tarfile.open() function. 
    """
    (path, extension)= splitext(path)
    if extension not in ["",".tar",".tar.gz"]:
        raise ValueError, "only \".tar\" or \".tar.gz\" are allowed " +\
                          "as file extension"
    return (path, extension)

def search_datafile(data_dir):
    """looks for the directory or the tar.gz file."""
    if os.path.exists(data_dir):
        return data_dir
    (base, extension)= check_ext(data_dir)
    if extension=="":
        sys.exit("error, \"%s\" not found" % data_dir)
    if not os.path.exists(base):
        sys.exit("error, neither \"%s\" not \"%s\" found" % (data_dir,base))
    return base

def remove_paths(path_list, paths_to_remove):
    """removes paths from a list of paths."""
    new= []
    paths_to_remove= [os.path.abspath(p) for p in paths_to_remove]
    for p in path_list:
        if os.path.abspath(p) not in paths_to_remove:
            new.append(p)
    return new

def my_relpath(path, start):
    """changes path to a path relative to start.

    I have to re-implement this since our computing host
    still runs with python 2.5!!
    """
    def plist(path):
        path= os.path.abspath(path)
        return splitpath(path)
    path_parts= plist(path)
    start_parts= plist(start)
    matches= -1
    for i in xrange(len(start_parts)):
        if i>len(path_parts):
            break
        if path_parts[i]!=start_parts[i]:
            break
        matches= i
    new= [".."] * (len(start_parts)-matches-1)
    new.extend(path_parts[matches+1:])
    if len(new)==0:
        return "."
    return os.path.join(*new)

def rm_files(filelist, verbose, dry_run):
    """remove all files from the list if they exist."""
    for f in filelist:
        if os.path.exists(f):
            if dry_run:
                print "file %s exists, would remove it" % f
                continue
            if verbose:
                print "file %s exists, remove it" % f
            os.remove(f)

# -----------------------------------------------
# tar file handling
# -----------------------------------------------

def tarfile_mode(extension, write= True):
    """returns the tarfile mode-string."""
    if write:
        st= "w:"
    else:
        st= "r:"
    if extension==".tar.gz":
        st= st + "gz"
    return st

def make_archive(tarfile_name, filelist, verbose, dry_run, 
                 start_dir= None,
                 mode="w:gz"):
    """create a tar.gz file from a list of files."""
    if dry_run or verbose:
        print "creating tar file: %s" % tarfile_name
        if dry_run:
            print "files:"
            for f in filelist:
                print "\t%s" % f
            return
    old_dir= None
    if (start_dir is not None) and (start_dir!=""):
        old_dir= my_chdir(start_dir, verbose)
    t= tarfile.open(tarfile_name, mode)
    for f in filelist:
        # if start_dir was given, store only path names
        # relative to start_dir in the tar file:
        if old_dir is not None:
            #f= os.path.relpath(f)
            f= my_relpath(f, start_dir)
        # print "tar: ",f
        t.add(f)
    t.close()
    if old_dir is not None:
        my_chdir(old_dir, verbose)

def extract_archive(tarfile_name, verbose, dry_run, mode="r:gz"):
    """extract a tar.gz file."""
    if dry_run or verbose:
        print "extracting from tar file %s" % tarfile_name
        if dry_run:
            return
    t= tarfile.open(tarfile_name, mode)
    t.extractall()
    t.close()

# -----------------------------------------------
# create README
# -----------------------------------------------

recover_info="""
This file shows how to restore the cvs working directory
manually. However, "cvs-recover.py -r -f [filename]" should do
all these things automatically.

[data-dir] is the name of the directory containing the 
recovery information and should be an absolute path. 
You get this path if you enter "pwd" within the data-dir.

The file "metadata.yaml" contains various variables in YAML format. Usually 
a variable is shown as "variable-name: variable-value".

1. checkout the sources

In metadata.yaml, the variable "cvs root" is the path of the central
repository. The environment variable CVSROOT should have this value.

In the following lines, [varname] refers to the value of a variable in the
file metadata.yaml.

You checkout like this:

"cvs checkout -D [up to date] -A -d [source dir] [cvs repo]"
"cd [source dir]

2. update files to the correct version

You have to compare the cvs status from the current working directory with
cvs status as it is stored in the recovery directory, note that [data-dir]
is the directory with the recovery data:

grep -v "Sticky Date" [data-dir]/cvs-status > cvs-status
cvs status | grep -v "Sticky Date" > cvs-status-now
diff cvs-status-now cvs-status

The output now shows which files have the wrong version. You can see this
under "Working revision", the second one is the wanted revision. Note that
the name of the file is UNDER "Working revision" at "Repository revision".
 
For each file that needs to be updated (there should only be a few or none)
you need to enter:

"cvs update -r REVISION FILE"

3. apply uncomitted changes

If in the file "metadata.yaml", the line starting with "uncomitted changes"
contains "true", then there are changes not committed to the repository that
have to be applied. These are in the file "cvs-diff". In this case apply these
changes with:

"patch -p0 < [data-dir]/cvs-diff

5. add files not known to the repository

If in the file "metadata.yaml", the line starting with "extra files" contains
"true", then there are additional files not known to the repository. Add them
with:

"tar -xzf [data-dir]/extra-files.tar.gz"

For each of the files in the variable [added files] you may enter 
cvs add FILENAME

This should be all.
"""

def mk_readme(filename, verbose, dry_run):
    """create the readme file."""
    mkfile(recover_info, filename, verbose, dry_run)


# -----------------------------------------------
# cvs commands
# -----------------------------------------------

def cvs_cmd(cmd, catch_stdout, verbose, dry_run):
    """get data from a cvs command."""
    return _system("cvs %s" % cmd, catch_stdout, verbose, dry_run)

def cvs_root(verbose, dry_run):
    """return the CVS root."""
    f= open("CVS/Root")
    l= f.readlines()
    f.close()
    return l[0].strip()

def cvs_repo(verbose, dry_run):
    """return the CVS root."""
    f= open("CVS/Repository")
    l= f.readlines()
    f.close()
    return l[0].strip()

rx_file= re.compile("^File:\s+(\S+)\s+Status:\s+(.*)$")
rx_working= re.compile("^\s+Working\s+revision:\s+(\S+).*")
rx_repository= re.compile("^\s+Repository\s+revision:\s+(\S+)\s+(.*),v\s*$")

def cvs_status1(filename, read_file, write_file, verbose, dry_run):
    """returns a list of files and revisions.
    
    Note: read_file and write_file must not both be true.
    parameters:
        filename  : name of the file
        read_file : read from the file
        write_file: create the file
        verbose   : show what the command does
        dry_run   : do not actually do anything
    returns:
        a list of lists consisting of
        (file,revision,status)
    """
    if read_file and write_file:
        raise ValueError, "read_file and write_file MUST NOT both be true"
    root= cvs_root(verbose, dry_run)+os.path.sep
    if read_file:
        f= open(filename)
        all= "".join(f.readlines())
        f.close()
    else:
        all=  cvs_cmd("status", True, verbose, dry_run)
    if write_file:
        mkfile(all,filename,verbose,dry_run)
    lst= []
    s_file= None
    for line in all.splitlines():
        if line.startswith("===="):
            if s_file is not None:
                lst.append([s_path,s_rev,s_status])
                s_file= None
            continue
        m= rx_file.match(line)
        if m is not None:
            (s_file,s_status)= m.groups()
            continue
        m= rx_working.match(line)
        if m is not None:
            s_rev= m.group(1)
            if s_rev=="New": # actually "New file!"
                # an added file, this has not yet been given 
                # a revision number,
                # -> skip it
                s_file= None
            continue
        m= rx_repository.match(line)
        if m is not None:
            s_path= m.group(2)
            s_path= s_path.replace(root,"")
            continue
        continue
    if s_file is not None:
        lst.append([s_path,s_rev,s_status])
    return lst

def cvs_status(verbose, dry_run):
    """returns the output of cvs -n -q update.
    
    returns:
        a list of tuples (flag, filename)
    """
    all= cvs_cmd("-n -q update", True, verbose, dry_run)
    lst= []
    for l in all.splitlines():
        lst.append((l.strip().split()))
    return lst

def cvs_unknown_files(status_list):
    """return a list of files unknown to cvs.
    
    Note that files from the exclude_list (if given) are 
    removed from the list of unknown files.
    """
    return [elm[1] for elm in status_list if elm[0]=='?']

def cvs_added_files(status_list):
    """return a list of files added to cvs.
    
    Note that files from the exclude_list (if given) are 
    removed from the list of unknown files.
    """
    return [elm[1] for elm in status_list if elm[0]=='A']

def cvs_removed_files(status_list):
    """return a list of files added to cvs.
    
    Note that files from the exclude_list (if given) are 
    removed from the list of unknown files.
    """
    return [elm[1] for elm in status_list if elm[0]=='R']

def cvs_uncommitted_changes(status_list):
    """return a list of files with uncommitted changes.
    
    Note that files from the exclude_list (if given) are 
    removed from the list of unknown files.
    """
    return [elm[1] for elm in status_list if elm[0]!='?']

def cvs_status_text(status_list):
    """return the status as a string."""
    return "\n".join([" ".join(elm) for elm in status_list])

def cvs_add(lst, verbose, dry_run):
    """add a list of files."""
    cvs_cmd("add %s" % " ".join(lst), False, verbose, dry_run)

def cvs_remove(lst, verbose, dry_run):
    """remove a list of files."""
    all= " ".join(lst)
    cvs_cmd("update -A %s" % all, False, verbose, dry_run)
    for f in lst:
        rm_all(f, verbose, dry_run)
    cvs_cmd("remove %s" % all, False, verbose, dry_run)

def cvs_update_all(cvs_repo, status_info, verbose, dry_run):
    """update a file to a given revision.
    """
    def info2dict(info):
        d= {}
        for e in info:
            d[e[0]]= e[1]
        return d
    cvs_repo= cvs_repo+os.path.sep
    curr_status_info= cvs_status1("",False,False,verbose, dry_run)
    curr_status_dict= info2dict(curr_status_info)
    for (path, rev, stat) in status_info:
        if rev != curr_status_dict[path]:
            p= path.replace(cvs_repo,"")
            cvs_cmd("update -r %s %s" % (rev,p), False, verbose, dry_run)

# -----------------------------------------------
# major functions
# -----------------------------------------------

def create_recover_data(working_copy,
                        data_dir, 
                        verbose, dry_run):
    """create recovery data for a working directory."""
    data_dir= os.path.abspath(data_dir)
    (data_dir, extension)= check_ext(data_dir)
    old_dir= my_chdir(working_copy, verbose)
    join= os.path.join
    if not (os.path.exists("CVS") and os.path.isdir("CVS")):
        raise ValueError, \
              "error, no CVS repository data found in \"%s\"" % \
              working_copy
    if os.path.exists(data_dir):
        if not os.path.isdir(data_dir):
            raise ValueError, \
                  "error, \"%s\" is the name of an existing file" % \
                  data_dir
        else:
            rm_files([join(data_dir,f) for f in
                       ["cvs-status-summary","cvs-status", "unknown-files.tar.gz", 
                        "metadata.yaml", "cvs-diff", "README"]
                       ], verbose, dry_run)
    else:
        os.mkdir(data_dir)
    status_info= cvs_status1(join(data_dir,"cvs-status"),False,True,verbose, dry_run)
    short_status= cvs_status(verbose, False)
    unknown_files= cvs_unknown_files(short_status)
    added_files= cvs_added_files(short_status)
    removed_files= cvs_removed_files(short_status)
    extra_files= unknown_files[:]
    extra_files.extend(added_files)
    exclude_list= [data_dir]
    if extension!="":
        exclude_list.append(data_dir+extension)
    extra_files= remove_paths(extra_files, exclude_list)

    uncommitted_changes= (len(cvs_uncommitted_changes(short_status))>0)
    source_path= os.getcwd()
    bag= { 
           "cvs root" : cvs_root(verbose,False),
           "cvs repo" : cvs_repo(verbose, False),
           "source path" : source_path, 
           "source dir" : last_path_element(source_path),
           #"revision list": status_info,
           "uncommitted changes": uncommitted_changes,
           "extra files" : (len(extra_files)>0),
           "up to date" : isodatetime(datetime.datetime.today()),
           "added files" : added_files,
           "removed files" : removed_files,
         }
    # print yaml.dump(bag)
    s= yaml.dump(bag,default_flow_style=False)
    mkfile(s, join(data_dir,"metadata.yaml"), verbose, dry_run)
    #if dry_run:
    #    print "with this content:"
    #    print s
    mk_readme(join(data_dir,"README"), verbose, dry_run)
    mkfile(cvs_status_text(short_status),
           join(data_dir,"cvs-status-summary"), verbose, dry_run)
    if uncommitted_changes:
        mkfile(cvs_cmd("diff --unified 2>/dev/null; true", True, verbose, dry_run),
               join(data_dir,"cvs-diff"), verbose, dry_run)
    if len(extra_files)>0:
        make_archive(join(data_dir,"extra-files.tar.gz"),
                     extra_files, verbose, dry_run)
    if extension!="":
        make_archive(data_dir+extension, [data_dir], verbose, dry_run, 
                     start_dir= os.path.dirname(data_dir),
                     mode=tarfile_mode(extension,write=True))
        rmdir(data_dir, verbose, dry_run)


def recover_data(working_copy,
                 data_dir, 
                 verbose, dry_run):
    """recover repository from the given recovery data."""
    data_dir= search_datafile(data_dir)
    data_dir= os.path.abspath(data_dir)
    (data_dir, extension)= check_ext(data_dir)
    old_dir= my_chdir(working_copy, verbose)
    if extension!="":
        if not os.path.exists(data_dir+extension):
            if not os.path.exists(data_dir):
                raise ValueError,("error: neither \"%s\" nor \"%s\" " +\
                                  "do exist") % (data_dir+extension,data_dir)
        else:
            extract_archive(data_dir+extension, verbose, False, 
                            tarfile_mode(extension,write=False))
            data_dir= os.path.basename(data_dir)
    join= os.path.join
    meta= open(join(data_dir,"metadata.yaml"))
    bag= yaml.load(meta)
    meta.close()
    cvs_cmd("checkout -D %s -A -d %s %s" % \
            (bag["up to date"],bag["source dir"],bag["cvs repo"]), 
           not verbose, verbose, dry_run)
    my_chdir(bag["source dir"], verbose or dry_run)
    data_dir= join("..",data_dir)
    status_info= cvs_status1(join(data_dir,"cvs-status"),True,False,verbose,dry_run)
    cvs_update_all(bag["cvs repo"], status_info, verbose, dry_run)
    if bag["uncommitted changes"]:
        _system("patch -p0 < %s" % join(data_dir,"cvs-diff"), 
                catch_stdout= not verbose,
                verbose=verbose, dry_run=dry_run)
    if bag["extra files"]:
        extract_archive(join(data_dir,"extra-files.tar.gz"), verbose, dry_run)
    if len(bag["added files"])>0:
        cvs_add(bag["added files"], verbose, dry_run)
    if len(bag["removed files"])>0:
        cvs_remove(bag["removed files"], verbose, dry_run)

def script_shortname():
    """return the name of this script without a path component."""
    return os.path.basename(sys.argv[0])

def print_doc():
    """print embedded reStructuredText documentation."""
    print __doc__

def print_summary():
    """print a short summary of the scripts function."""
    print "%-20s: backup and recovery a cvs repository\n" % script_shortname()

def main():
    """The main function.

    parse the command-line options and perform the command
    """
    # command-line options and command-line help:
    usage = "usage: %prog [options] {files}"



    parser = OptionParser(usage=usage,
                          version="%%prog %s" % my_version,
                          description="this program generates a short " +\
                                      "data set that can be used to " +\
                                      "restore a cvs repository " +\
                                      "complete with a working copy and " +\
                                      "uncomitted changes.")

    parser.set_defaults(working_copy=".", file= default_file)

    parser.add_option("--summary",  # implies dest="nodelete"
                      action="store_true", # default: None
                      help="print a summary of the function of the program",
                      )
    parser.add_option( "--doc",            # implies dest="switch"
                  action="store_true", # default: None
                  help="create online help in restructured text"
                       "format. Use \"./cvs-recover.py --doc | rst2html\" "
                       "to create html-help"
                  )
    parser.add_option("-f", "--file", # implies dest="file"
                      action="store", # OptionParser's default
                     type="string",  # OptionParser's default
                      help="create cvs recovery data in the " +\
                           "given file or directory. If the given name " +\
                           "ends with \".tar\" or \".tag.gz\", a tar " +\
                           "file or a compressed tar file is created. " +\
                           "The default for this is \"%s\"" % default_file,
                     metavar="FILENAME"  # for help-generation text
                     )
    parser.add_option("-w", "--working-copy", # implies dest="file"
                      action="store", # OptionParser's default
                     type="string",  # OptionParser's default
                      help="specify where the WORKINGCOPY is " +\
                           "found, \".\" is the default. " +\
                           "For --recover, this is the directory " +\
                           "where the working copy directory will " +\
                           "be created as a sub-directory.",
                     metavar="WORKINGCOPY"  # for help-generation text
                     )
    parser.add_option("-c", "--create", # implies dest="file"
                      action="store_true", # default: None
                      help="create cvs recovery data in the " +\
                           "given DATA_DIRECTORY. If the given name " +\
                           "ends with \".tar\" or \".tag.gz\", a tar " +\
                           "file or a compressed tar file is created. ",
                     metavar="DATA_DIRECTORY"  # for help-generation text
                     )
    parser.add_option("-r", "--recover", # implies dest="file"
                      action="store_true", # OptionParser's default
                      help="recover repository from the recovery data " +\
                           "in the given DATA_DIRECTORY",
                     metavar="DATA_DIRECTORY"  # for help-generation text
                     )
    parser.add_option("-v", "--verbose",   # implies dest="switch"
                      action="store_true", # default: None
                      help="print to the screen what the program does",
                     )
    parser.add_option("--dry-run",   # implies dest="switch"
                      action="store_true", # default: None
                      help="do not apply any changes",
                     )

    x= sys.argv
    (options, args) = parser.parse_args()
    # options: the options-object
    # args: list of left-over args

    if options.summary:
        print_summary()
        sys.exit(0)

    if options.doc:
        print_doc()
        sys.exit(0)

    if options.create:
        create_recover_data(working_copy= options.working_copy,
                            data_dir= options.file,
                            verbose= options.verbose,
                            dry_run= options.dry_run)
        sys.exit(0)

    if options.recover:
        recover_data(working_copy= options.working_copy,
                     data_dir= options.file,
                     verbose= options.verbose,
                     dry_run= options.dry_run)
        sys.exit(0)

    sys.exit("no command given!")

if __name__ == "__main__":
    main()

