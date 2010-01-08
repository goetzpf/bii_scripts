#! /usr/bin/env python2.5
# -*- coding: UTF-8 -*-

#  This software is copyrighted by the
#  Helmholtz-Zentrum Berlin fuer Materialien und Energie GmbH (HZB),
#  Berlin, Germany.
#  The following terms apply to all files associated with the software.
#  
#  HZB hereby grants permission to use, copy and modify this
#  software and its documentation for non-commercial, educational or
#  research purposes provided that existing copyright notices are
#  retained in all copies.
#  
#  The receiver of the software provides HZB with all enhancements, 
#  including complete translations, made by the receiver.
#  
#  IN NO EVENT SHALL HZB BE LIABLE TO ANY PARTY FOR DIRECT, INDIRECT,
#  SPECIAL, INCIDENTAL OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE
#  OF THIS SOFTWARE, ITS DOCUMENTATION OR ANY DERIVATIVES THEREOF, EVEN 
#  IF HZB HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#  
#  HZB SPECIFICALLY DISCLAIMS ANY WARRANTIES, INCLUDING, BUT NOT LIMITED
#  TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
#  PURPOSE, AND NON-INFRINGEMENT. THIS SOFTWARE IS PROVIDED ON AN "AS IS"
#  BASIS, AND HZB HAS NO OBLIGATION TO PROVIDE MAINTENANCE, SUPPORT,
#  UPDATES, ENHANCEMENTS OR MODIFICATIONS.

"""
======================
hg-recover.py
======================
------------------------------------------------------------------------------
 a tool to backup and recover local mercurial working copies
------------------------------------------------------------------------------

Overview
===============
This tool can be used to backup and recover a mercurial working
copy complete with the mercurial repository. 

Instead of saving the complete repository this script only saves
differences relative to a central mercurial repository. By this,
much disk space is saved, the backup file has usually only about 
100kBytes or less.

Quick reference
===============

* create the recover file hg-recover.tar.gz, current working
  directory must be a mercurial working copy::

   hg-recover.py -c

* recreate a repository from the file hg-recover.tar.gz::

   hg-recover.py -r

* recreate a repository from a file [file]::

   hg-recover.py -r -f [file]

More examples
=============

* create a recover file for a specified central repository::

   hg-recover.py -c --central-repo [central repository]

* create a recover file with a given name::

   hg-recover.py -c -f [myfile].tar.gz

* create a recover file with a given name and a given working copy::

   hg-recover.py -c -f [myfile].tar.gz -w [working copy directory]

* create a recover directory with a given name. If the parameter
  after "-f" doesn't end with ".tar.gz", the recover directory is
  not packed into compressed tar file::

   hg-recover.py -c -f [myfile]

* recreate a repository in a given directory from a recovery file::

   hg-recover.py -r -f [file] -w [directory]

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
  Use "./hg-recover.py --doc | rst2html" to create html-help"

-f FILENAME, --file=FILENAME
  create mercurial recovery data in the given file or
  directory. If the given name ends with ".tar" or
  ".tag.gz", a tar file or a compressed tar file is
  created. The default for this is "hg-recover.tar.gz"

-w WORKINGCOPY, --working-copy=WORKINGCOPY
  specify where the WORKINGCOPY is found, "." is the
  default. For --recover, this is the directory where the
  working copy directory will be created as a sub-
  directory.

-c, --create
  create mercurial recovery data in the given
  DATA_DIRECTORY. If the given name ends with ".tar" or
  ".tag.gz", a tar file or a compressed tar file is
  created.

-r, --recover
  recover repository from the recovery data in the given
  DATA_DIRECTORY

--central-repo=CENTRALREPOSITORY
  specify the CENTRALREPOSITORY

-v, --verbose
  print to the screen what the program does

--dry-run
  do not apply any changes
"""


from optparse import OptionParser
#import string
import os.path
import sys
import subprocess
import os
import os.path
import shutil
import tarfile
import yaml
import re

# version of the program:
my_version= "1.0"

default_file= "hg-recover.tar.gz"

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

def is_subdir(parent_dir, dir):
    """test if dir is a sub-directory of parent_dir.
    
    Note the follwing relation:
    is_subdir(dir,dir) == True
    """
    parent_dir= os.path.abspath(parent_dir)
    dir= os.path.abspath(dir)
    parent_parts= splitpath(parent_dir)
    dir_parts= splitpath(dir)
    if len(parent_parts)>len(dir_parts):
        return False
    for i in xrange(len(parent_parts)):
        if parent_parts[i]!=dir_parts[i]:
            return False
    return True

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
this file shows how to restore the mercurial repository
manually. However, "hg-recover -r -f [filename]" should do
all these things automatically.

[data-dir] is the name of the directory containing the 
recovery information and should be an absolute path. 
You get this path if you enter "pwd" within the data-dir.

1. clone the central repository

in the file "metadata.yaml", the line starting with "central repository"
contains the name of the central repository. The line starting with
"source dir" has the name of the source directory, although this could
be any arbitrary name.
Clone the central repository with:
"hg clone [central repository] [source dir]"
"cd [source dir]

2. apply outgoing patches

if in the file "metadata.yaml", the line starting with "outgoing patches"
is followed by one or more integers (the revision numbers of outgoing patches),
these patches have to be applied to the repository. They are placed
in the file "hg-bundle". Apply the patches with:

"hg unbundle [data-dir]/hg-bundle"

3. set the specified revision

in the file "metadata.yaml", the line starting with "revision" contains
the revision number that was used in the working copy. Update to this
revision with:

"hg update -r [revision]"

4. apply uncomitted changes

if in the file "metadata.yaml", the line starting with "uncomitted changes"
contains "true", then there are changes not committed to the repository
that have to be applied. These are in the file "hg-diff". In this case
apply these changes with:

"patch -p1 < [data-dir]/hg-diff

5. add files not known to the repository

if in the file "metadata.yaml", the line starting with "unknown files"
contains "true", then there are additional files not known to the
repository. Add them with:

"tar -xzf [data-dir]/unknown-files.tar.gz"
"""

def mk_readme(filename, verbose, dry_run):
    """create the readme file."""
    mkfile(recover_info, filename, verbose, dry_run)


# -----------------------------------------------
# mercurial commands
# -----------------------------------------------

def hg_cmd(cmd, catch_stdout, verbose, dry_run):
    """get data from a hg command."""
    return _system("hg %s" % cmd, catch_stdout, verbose, dry_run)

rx_section=re.compile(r'^\[(\w+)\]\s*$')

def get_section(st):
    """check if a new section has started."""
    m= rx_section.match(st)
    if m is None:
        return None
    return m.group(1)

rx_def=re.compile(r'^(\w+)\s*=\s*(.*)$')

def get_def(st):
    """get definition e.g. "a=b"."""
    m= rx_def.match(st)
    if m is None:
        return None
    return m.groups()

def hg_revision(verbose):
    """get the current hg revision."""
    data= hg_cmd("identify -i", catch_stdout= True,
                 verbose= verbose, dry_run= False)
    data= data.strip()
    changes= False
    if data[-1]=="+":
        changes= True
        data= data[0:-1]
    if verbose:
        print "found revision: %s  uncomitted changes: %s" % (data,changes)
    return (data, changes)

def hg_default_repo(verbose):
    """get the default dest repository."""

    filename= os.path.join(".hg","hgrc")
    if verbose:
        print "scanning", filename
    f= open(filename)
    section= None
    for line in f:
        line= line.strip()
        s= get_section(line)
        if s is not None:
            section= s
            continue
        if section=="paths":
            tp= get_def(line)
            if tp is not None:
                if tp[0]=="default":
                    if verbose:
                        print "default repo from .hgrc is: %s" % tp[1]
                    return tp[1]
    return None

def hg_status(exclude_list, hg_options, verbose):
    """returns the output of "hg status".
    
    Note that the strings in the exclude list are
    handled as file-glob patterns.
    """
    arglist=[""]
    if (hg_options is not None) and (hg_options != ""):
        arglist.append(hg_options)
    if len(exclude_list)>0:
        arglist.extend(["-X 'glob:%s'" % e for e in exclude_list])
    args=""
    if len(arglist)>1:
        args= " ".join(arglist)
    return _system("hg status%s" % args, catch_stdout= True, 
                   verbose=verbose, dry_run= False)

def hg_unknown_files(exclude_list, verbose):
    """return a list of files unknown to mercurial.
    
    Note that the exclude_dir (if given) and it's contents are 
    removed from the list of unknown files.
    """
    files= hg_status(exclude_list, "-u", verbose)
    lst= []
    for l in files.splitlines():
        if not l.startswith("? "):
            raise ValueError, "unexpected output from hg:\"%s\"" % l
        file= l[2:]
        lst.append(file)
    if verbose:
        print "found unknown files:"
        for f in lst:
            print "\t%s" % f
    return lst

def hg_outgoing(central_repo, verbose):
    """returns a list of patches not yet pushed."""
    patchdata= _system("hg outgoing --template \"{rev}\\n\" \"%s\" || true" % \
                       central_repo,
                       catch_stdout= True,
                       verbose=verbose, dry_run= False)
    l= []
    for line in patchdata.splitlines():
        try:
            i= int(line)
            l.append(i)
        except ValueError, e:
            continue
    if verbose:
        print "outgoing patches: ", ",".join([str(e) for e in l])
    return l

def create_hg_bundle(filename, central_repo, verbose, dry_run):
    """create a bundle of outgoing patches."""
    hg_cmd("bundle %s %s" % (filename,central_repo), 
           catch_stdout=not verbose,
           verbose=verbose, dry_run=dry_run)

def apply_hg_bundle(filename, verbose, dry_run):
    """create a bundle of outgoing patches."""
    hg_cmd("unbundle %s" % filename, 
           not verbose,
           verbose=verbose, dry_run=dry_run)

# -----------------------------------------------
# major functions
# -----------------------------------------------

def create_recover_data(working_copy,
                        data_dir, 
                        central_repo,
                        verbose, dry_run):
    """create recovery data for a working directory."""
    data_dir= os.path.abspath(data_dir)
    (data_dir, extension)= check_ext(data_dir)
    old_dir= my_chdir(working_copy, verbose)
    join= os.path.join
    if not (os.path.exists(".hg") and os.path.isdir(".hg")):
        raise ValueError, \
              "error, no mercurial repository data found in \"%s\"" % \
              working_copy
    if os.path.exists(data_dir):
        if not os.path.isdir(data_dir):
            raise ValueError, \
                  "error, \"%s\" is the name of an existing file" % \
                  data_dir
        else:
            rm_files([join(data_dir,f) for f in
                       ["hg-status", "hg-bundle", "unknown-files.tar.gz", 
                        "metadata.yaml", "hg-diff", "hgrc", "README"]
                     ], verbose, dry_run)
    else:
        os.mkdir(data_dir)
    default_repo= hg_default_repo(verbose or dry_run)
    if central_repo is None:
        central_repo= default_repo
    (revision, uncommitted_changes)= hg_revision(verbose or dry_run)
    if not is_subdir(working_copy,data_dir):
        exclude_list= []
    else:
        exclude_list= [data_dir]
        if extension!="":
            exclude_list.append(data_dir+extension)

    unknown_files= hg_unknown_files(exclude_list, verbose)
    source_path= os.getcwd()
    outgoing_patches= hg_outgoing(central_repo, verbose or dry_run)
    bag= { 
           "source path" : source_path, 
           "source dir" : last_path_element(source_path),
           "revision": revision,
           "uncommitted changes": uncommitted_changes,
           "outgoing patches" : outgoing_patches,
           "default repository" : default_repo,
           "central repository" : central_repo,
           "unknown files" : (len(unknown_files)>0)
         }
    # print yaml.dump(bag)
    s= yaml.dump(bag,default_flow_style=False)
    mkfile(s, join(data_dir,"metadata.yaml"), verbose, dry_run)
    #if dry_run:
    #    print "with this content:"
    #    print s
    mk_readme(join(data_dir,"README"), verbose, dry_run)
    copyfile(join(".hg","hgrc"), join(data_dir,"hgrc"), verbose, dry_run)
    mkfile(hg_cmd("status", True, verbose, dry_run),
           join(data_dir,"hg-status"), verbose, dry_run)
    if uncommitted_changes:
        mkfile(hg_cmd("diff", True, verbose, dry_run),
               join(data_dir,"hg-diff"), verbose, dry_run)
    if len(outgoing_patches)>0:
        create_hg_bundle(join(data_dir,"hg-bundle"),central_repo, 
                         verbose, dry_run)
    if len(unknown_files)>0:
        make_archive(join(data_dir,"unknown-files.tar.gz"),
                     unknown_files, verbose, dry_run)
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
    hg_cmd("clone %s %s" % (bag["central repository"], bag["source dir"]), 
           not verbose, verbose, dry_run)
    my_chdir(bag["source dir"], verbose or dry_run)
    data_dir= join("..",data_dir)
    if len(bag["outgoing patches"])>0:
        apply_hg_bundle(join(data_dir,"hg-bundle"), verbose, dry_run)
    hg_cmd("update -r %s" % bag["revision"], 
           not verbose, verbose, dry_run=dry_run)
    _system("patch -p1 < %s" % join(data_dir,"hg-diff"), 
            catch_stdout= not verbose,
            verbose=verbose, dry_run=dry_run)
    if bag["unknown files"]:
        extract_archive(join(data_dir,"unknown-files.tar.gz"), verbose, dry_run)

def script_shortname():
    """return the name of this script without a path component."""
    return os.path.basename(sys.argv[0])

def print_doc():
    """print embedded reStructuredText documentation."""
    print __doc__

def print_summary():
    """print a short summary of the scripts function."""
    print "%-20s: backup and recovery a mercurial repository\n" % script_shortname()

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
                                      "restore a mercurial repository " +\
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
                       "format. Use \"./hg-recover.py --doc | rst2html\" "
                       "to create html-help"
                  )
    parser.add_option("-f", "--file", # implies dest="file"
                      action="store", # OptionParser's default
                     type="string",  # OptionParser's default
                      help="create mercurial recovery data in the " +\
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
                      help="create mercurial recovery data in the " +\
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
    parser.add_option("--central-repo", # implies dest="file"
                      action="store", # OptionParser's default
                     type="string",  # OptionParser's default
                      help="specify the CENTRALREPOSITORY",
                     metavar="CENTRALREPOSITORY"  # for help-generation text
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
                            central_repo= options.central_repo,
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

