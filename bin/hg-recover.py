#! /usr/bin/env python3
# -*- coding: UTF-8 -*-

# Copyright 2020 Helmholtz-Zentrum Berlin für Materialien und Energie GmbH
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

If the backed up repository uses mq patch queues, the tool saves
and restores all *applied* patches, too. Note that the unapplied
patches, however, are not saved.

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

# pylint: disable= invalid-name, bad-whitespace, too-many-lines


from optparse import OptionParser # pylint: disable= deprecated-module
#import string
import sys
import subprocess
import os
import os.path
import shutil
import tarfile
import re

# pylint: disable= line-too-long

# set the following variable to True in order to implement a work around for a
# mercurial bug.

# Here is an example for a command that fails:
#   hg clone -r 00a1405aaff2 http://repo.acc.bessy.de/hg/id_db id_db

# We get an exception:
#   ** unknown exception encountered, please report by visiting
#   ** https://mercurial-scm.org/wiki/BugTracker
#   ** Python 2.7.13 (default, Jan 13 2017, 10:15:16) [GCC 6.3.1 20161221 (Red Hat 6.3.1-1)]
#   ** Mercurial Distributed SCM (version 3.7.3)
#   ** Extensions loaded: fetch, hgk, extdiff, transplant, graphlog, rebase, strip, mq, convert, record, color, pager
#   Traceback (most recent call last):
#    ...
#     File "/usr/lib64/python2.7/site-packages/mercurial/localrepo.py", line 1363, in wlock
#       l = self._wlockref and self._wlockref()
#   AttributeError: 'statichttprepository' object has no attribute '_wlockref'

# The problem is to fetch a repository with a version given by "-r VERSION" via
# http. We work around this problem by fetching the newest version of the repo
# (omitting "-r VERSION") and then doing "hg update -r VERSION" to go to the
# specified version after cloning the repository. Hopefully this bug is fixed
# some time in the future.

# Note this this fix will sometimes lead to errors with respect to patch
# queues, when patches of the patch queue have been integrated in the central
# repository in the mean time. So it is preferred to set HG_QUIRK to False when
# possible.

# pylint: enable= line-too-long

assert sys.version_info[0]==3

HG_QUIRK= False

_no_check= len(sys.argv)==2 and (sys.argv[1] in ("-h","--help","--summary","--doc"))
try:
    import yaml
except ImportError:
    if _no_check:
        sys.stderr.write("WARNING: (in %s) mandatory module yaml not found\n" % \
                         sys.argv[0])
    else:
        raise


# version of the program:
my_version= "1.0.1"

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
    def to_str(data):
        """decode byte stream to unicode string."""
        if data is None:
            return None
        return data.decode()
    if dry_run or verbose:
        print(">", cmd)
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
        raise IOError(p.returncode,"cmd \"%s\", errmsg \"%s\"" % \
                      (cmd,to_str(child_stderr)))
    return to_str(child_stdout)

def copyfile(src, dest, verbose, dry_run):
    """copies a file."""
    if dry_run or verbose:
        print("copy %s to %s" % (src,dest))
        if dry_run:
            return
    shutil.copyfile(src, dest)

def rmdir(dir_, verbose, dry_run):
    """remove recursivly a directory."""
    if dry_run or verbose:
        print("rm -rf %s" % dir_)
        if dry_run:
            return
    shutil.rmtree(dir_)

def my_chdir(newdir, verbose):
    """change directory, return the old directory."""
    if newdir is None:
        return None
    olddir= os.getcwd()
    if verbose:
        print("cd %s" % newdir)
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
        print("creating %s" % filename)
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
        raise ValueError("only \".tar\" or \".tar.gz\" are allowed " +\
                          "as file extension")
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

def is_subdir(parent_dir, dir_):
    """test if dir_ is a sub-directory of parent_dir.

    Note the follwing relation:
    is_subdir(dir_,dir_) == True
    """
    parent_dir= os.path.abspath(parent_dir)
    dir_= os.path.abspath(dir_)
    parent_parts= splitpath(parent_dir)
    dir_parts= splitpath(dir_)
    if len(parent_parts)>len(dir_parts):
        return False
    # pylint: disable= consider-using-enumerate
    for i in range(len(parent_parts)):
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
    # pylint: disable= consider-using-enumerate
    for i in range(len(start_parts)):
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
                print("file %s exists, would remove it" % f)
                continue
            if verbose:
                print("file %s exists, remove it" % f)
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
    # pylint: disable= too-many-arguments
    if dry_run or verbose:
        print("creating tar file: %s" % tarfile_name)
        if dry_run:
            print("files:")
            for f in filelist:
                print("\t%s" % f)
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
        print("extracting from tar file %s" % tarfile_name)
        if dry_run:
            return
    t= tarfile.open(tarfile_name, mode)
    for member in t.getmembers():
        t.extract(member, path=".")
    # t.extractall()

    # mysteriously, sometimes the tarfile object doesn't have an extractall
    # method (it seems when hg-recover.py is started with "-r -f" and a
    # directory instead of an overall tar file.  We use extract() instead of
    # extractall() here, this seems to work,
    t.close()

# -----------------------------------------------
# create README
# -----------------------------------------------

recover_info="""
This file shows how to restore the mercurial repository
manually. However, "hg-recover -r -f [filename]" should do
all these things automatically.

[data-dir] is the name of the directory containing the
recovery information and should be an absolute path.
You get this path if you enter "pwd" within the data-dir.

1. clone the central repository

In the file "metadata.yaml", the line starting with "central repository"
contains the name of the central repository. The line starting with "source
dir" has the name of the source directory, although this could be any arbitrary
name.

If there is a field "qparent" in "metadata.yaml", you should use the option "-r
[qparent]" in the following command, otherwise you can skip this option.

Clone the central repository with:

  hg clone [-r qparent] [central repository] [source dir]
  cd [source dir]

2. apply outgoing patches

If in the file "metadata.yaml", the line starting with "outgoing patches" is
followed by one or more integers (the revision numbers of outgoing patches),
these patches have to be applied to the repository. They are placed in the file
"hg-bundle". Apply the patches with:

  hg unbundle [data-dir]/hg-bundle

3. apply mq patches

If in the file "metadata.yaml" there is a line "mq patches used: true", then
you have to apply an mq patch bundle with this command:

  hg unbundle [data-dir]/mq-bundle

4. set the specified revision

In the file "metadata.yaml", the line starting with "revision" contains the
revision number that was used in the working copy. Update to this revision
with:

  hg update -r [revision]

5. apply uncomitted changes

If in the file "metadata.yaml", the line starting with "uncomitted changes"
contains "true", then there are changes not committed to the repository that
have to be applied. These are in the file "hg-diff". In this case apply these
changes with:

  patch -p1 < [data-dir]/hg-diff

6. add files not known to the repository

If in the file "metadata.yaml", the line starting with "unknown files" contains
"true", then there are additional files not known to the repository. Add them
with:

  tar -xzf [data-dir]/unknown-files.tar.gz

7. restore the mq patches

If in the file "metadata.yaml", the line starting with "mq patches used"
contains "true", then there were applied mq patches in the original repository.
The names of the patches together with the revision numbers can be found in the
file "metadata.yaml" after "patchname list:".  Each item contains a number and
a string, separated by a colon ":".
Now apply:

  hg qimport -r [number] -n [string]

For each of the lines from the topmost entry (the biggest revision number) to
the bottom (with the smallest revision number). This recreates the patches and
restores their original names.
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

def hg_parents(revision, verbose, dry_run):
    """get the parent(s) of a revision."""
    parents= hg_cmd("parents -r %s --template '{node|short}:{node}\n'" % revision,
                    True,verbose,dry_run)
    return [x.split(":")[0] for x in parents.splitlines()]

def hg_qparent(verbose, dry_run):
    """returns the "qparent" version if it exists.

    returns:
        if there are no applied patches
            None
        Otherwise
            a hashkey
    """
    filename= os.path.join(".hg","patches","status")
    if not os.path.exists(filename):
        return None
    if hg_cmd("qapplied", True, verbose, dry_run)=="":
        # there is a patch queue but none of the patches is applied
        return None
    qparent= hg_cmd("log -r qparent --template '{node|short}:{node}\n'",
                    True,verbose,dry_run)
    return qparent.split(":")[0]

def hg_hash_patchname_list(verbose, dry_run):
    """returns a list of tuples (hashkey,patchname).

    returns:
        if there are no applied patches
            None
        Otherwise
            a list of tuples (hashkey,patchname).
    """
    filename= os.path.join(".hg","patches","status")
    if not os.path.exists(filename):
        return None
    patchmap= {}
    f= open(filename)
    for line in f:
        line= line.strip()
        (longrev,patchname)= line.split(":")
        patchmap[longrev]= patchname
    f.close()
    if len(patchmap)==0:
        return None
    all_= hg_cmd("log -r qbase:tip --template '{node|short}:{node}\n'",
                 True,verbose,dry_run)
    new= []
    for l in all_.splitlines():
        (shorthashkey,longhashkey)= l.split(":")
        new.append((shorthashkey,patchmap[longhashkey]))
    return new

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
        print("found revision: %s  uncomitted changes: %s" % (data,changes))
    return (data, changes)

def hg_default_repo(verbose):
    """get the default dest repository."""

    filename= os.path.join(".hg","hgrc")
    if verbose:
        print("scanning", filename)
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
                        print("default repo from .hgrc is: %s" % tp[1])
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

    Note that files from the exclude_list (if given) are
    removed from the list of unknown files.
    """
    files= hg_status(exclude_list, "-u", verbose)
    lst= []
    for l in files.splitlines():
        if not l.startswith("? "):
            raise ValueError("unexpected output from hg:\"%s\"" % l)
        file= l[2:]
        lst.append(file)
    if verbose:
        print("found unknown files:")
        for f in lst:
            print("\t%s" % f)
    return lst

rx_hashkey=re.compile(r'^\s*([0-9A-Fa-f]{6,})\s*$')

def hg_outgoing(central_repo, verbose):
    """returns a list of patches not yet pushed."""
    patchdata= _system("hg outgoing --template \"{node|short}\\n\" \"%s\" || true" % \
                       central_repo,
                       catch_stdout= True,
                       verbose=verbose, dry_run= False)
    l= []
    for line in patchdata.splitlines():
        m= rx_hashkey.match(line)
        if m is None:
            continue
        l.append(m.group(1))
    if verbose:
        print("outgoing patches: ", ",".join([str(e) for e in l]))
    return l

def create_hg_bundle(filename, central_repo, base,
                     verbose, dry_run):
    """create a bundle of outgoing patches."""
    cmd= ["bundle", filename]
    if central_repo:
        cmd.append(central_repo)
    if base:
        cmd.append("--base %s" % base)
    hg_cmd(" ".join(cmd),
           catch_stdout=not verbose,
           verbose=verbose, dry_run=dry_run)

def apply_hg_bundle(filename, verbose, dry_run):
    """create a bundle of outgoing patches."""
    hg_cmd("unbundle %s" % filename,
           not verbose,
           verbose=verbose, dry_run=dry_run)

def rebuild_patchdir(patchlist, verbose, dry_run):
    """rebuild the patches that were in an applied state in the original dir.
    """
    hg_cmd("init --mq", False, verbose, dry_run)
    # use "phase" command to free revisions:
    for (rev,patchname) in patchlist:
        try:
            hg_cmd("phase --force --draft -r %s" % rev, True, False, dry_run)
        except IOError as e:
            if -1!= str(e).find("unknown command"):
                # if mercurial doesn't support "phase", leave the loop:
                break
            # mercurial may return an error "no phases changed"
    for (rev,patchname) in patchlist:
        hg_cmd("qimport -n \"%s\" -r %s" % (patchname,rev), False, verbose, dry_run)

# -----------------------------------------------
# major functions
# -----------------------------------------------

def recover_qparent(bag,
                    data_dir,
                    verbose, dry_run):
    """recover the "qparent" revision.

    In newer versions of the restore file, the qparent revision is part of the
    metadata.yaml file. In older versions this is missing but this information
    is sometimes needed to correctly restore the mq patch queue. This function
    checks out the repository and applies the patch bundle only to get the
    parent of the first patch revision and then throws the repository away.
    """
    join= os.path.join
    if len(bag["outgoing patches"])<=0:
        # the mq patches should also be part of the outgoing patches. If there
        # are no outgoing patches there should be no mq patches an no "qparent"
        # revision.
        return None
    hg_cmd("clone %s %s %s" % ("",
                               bag["central repository"],
                               bag["source dir"]),
           not verbose, verbose, dry_run)
    old_dir= my_chdir(bag["source dir"], verbose or dry_run)
    data_dir= join("..",data_dir)
    apply_hg_bundle(join(data_dir,"hg-bundle"), verbose, dry_run)
    # the last patch in "patchname list" should be the first patch ("qbase")
    # that was applied. So it's parent is the "qparent" revision:
    first_patch= bag["patchname list"][-1].split(":")[0]
    parents= hg_parents(first_patch, verbose or dry_run, False)
    # There shouldn't be more than one parent of the "qbase" patch. If there
    # is, or if there is no parent patch at all the program stops with an
    # assertion:
    if len(parents)!=1:
        raise AssertionError("revision %s does not have a single parent" % \
                               first_patch)
    # throw away the repository:
    delete_dir= my_chdir(old_dir, verbose or dry_run)
    rmdir(delete_dir, verbose, dry_run)
    return parents[0]

def create_recover_data(working_copy,
                        data_dir,
                        central_repo,
                        verbose, dry_run):
    """create recovery data for a working directory."""
    # pylint: disable= too-many-locals, too-many-branches
    data_dir= os.path.abspath(data_dir)
    (data_dir, extension)= check_ext(data_dir)
    old_dir= my_chdir(working_copy, verbose)
    join= os.path.join
    if not (os.path.exists(".hg") and os.path.isdir(".hg")):
        raise ValueError("error, no mercurial repository data found in \"%s\"" % \
              working_copy)
    if os.path.exists(data_dir):
        if not os.path.isdir(data_dir):
            raise ValueError("error, \"%s\" is the name of an existing file" % \
                  data_dir)
        rm_files([join(data_dir,f) for f in \
                   ["hg-status", "hg-bundle", "unknown-files.tar.gz",
                    "metadata.yaml", "hg-diff", "hgrc", "README"] \
                   ], verbose, dry_run)
    else:
        os.mkdir(data_dir)
    default_repo= hg_default_repo(verbose or dry_run)
    if central_repo is None:
        central_repo= default_repo
    (revision, uncommitted_changes)= hg_revision(verbose or dry_run)
    unknown_files= hg_unknown_files([], verbose)
    exclude_list= [data_dir]
    if extension!="":
        exclude_list.append(data_dir+extension)
    unknown_files= remove_paths(unknown_files, exclude_list)

    source_path= os.getcwd()
    outgoing_patches= hg_outgoing(central_repo, verbose or dry_run)
    qparent= hg_qparent(verbose or dry_run, False)
    patchlist= hg_hash_patchname_list(verbose or dry_run, False)
    bag= { \
           "source path" : source_path,
           "source dir" : last_path_element(source_path),
           "revision": revision,
           "uncommitted changes": uncommitted_changes,
           "outgoing patches" : outgoing_patches,
           "default repository" : default_repo,
           "central repository" : central_repo,
           "unknown files" : (len(unknown_files)>0),
           "mq patches used" : (patchlist is not None),
         }
    if patchlist is not None:
        bag["qparent"]= qparent # this bag element is not there in old
                                # recovery files where this feature was not
                                # yet implemented.
        bag["patchname list"] = ["%s:%s" % i for i in reversed(patchlist)]
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
        create_hg_bundle(join(data_dir,"hg-bundle"),
                         central_repo,
                         None,
                         verbose, dry_run)
    if patchlist is not None:
        create_hg_bundle(join(data_dir,"mq-bundle"),
                         None,
                         "qparent",
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
    # pylint: disable= too-many-branches
    data_dir= search_datafile(data_dir)
    data_dir= os.path.abspath(data_dir)
    (data_dir, extension)= check_ext(data_dir)
    old_dir= my_chdir(working_copy, verbose)
    if extension!="":
        if not os.path.exists(data_dir+extension):
            if not os.path.exists(data_dir):
                raise ValueError(("error: neither \"%s\" nor \"%s\" " +\
                                  "do exist") % (data_dir+extension,data_dir))
        else:
            extract_archive(data_dir+extension, verbose, False,
                            tarfile_mode(extension,write=False))
            data_dir= os.path.basename(data_dir)
    join= os.path.join
    meta= open(join(data_dir,"metadata.yaml"))
    bag= yaml.load(meta)
    meta.close()
    qparent= None
    if bag.get("mq patches used"):
        qparent= bag.get("qparent")
        if qparent is None:
            # qparent revision was not saved, try to recover it:
            qparent= recover_qparent(bag, data_dir, verbose, dry_run)
        # Note: qparent may be part of the bundle that is yet to be applied, so
        # we do not yet do 'hg update -r [qparent]':
    if not HG_QUIRK:
        hg_cmd("clone %s %s" % (bag["central repository"],
                                bag["source dir"]),
               not verbose, verbose, dry_run)
    else:
        if not bag["central repository"].startswith("http://"):
            hg_cmd("clone %s %s" % (bag["central repository"],
                                    bag["source dir"]),
                   not verbose, verbose, dry_run)
        else:
            hg_cmd("clone %s %s %s" % ("",
                                       bag["central repository"],
                                       bag["source dir"]),
                   not verbose, verbose, dry_run)

    my_chdir(bag["source dir"], verbose or dry_run)
    data_dir= join("..",data_dir)
    if len(bag["outgoing patches"])>0:
        apply_hg_bundle(join(data_dir,"hg-bundle"), verbose, dry_run)
    if bag["mq patches used"]:
        # go to "qparent" version:
        hg_cmd("update -r %s" % qparent,
               not verbose, verbose, dry_run)
        mq_bundle_path= join(data_dir,"mq-bundle")
        if not os.path.exists(mq_bundle_path):
            sys.stderr.write("    Warning: File mq-bundle not found. "
                             "For old restore files this is OK\n"
                             "    but for newer ones it is "
                             "probably an error.\n")
        else:
            apply_hg_bundle(mq_bundle_path, verbose, dry_run)
    hg_cmd("update -r %s" % bag["revision"],
           not verbose, verbose, dry_run=dry_run)
    if bag["uncommitted changes"]:
        _system("patch -p1 < %s" % join(data_dir,"hg-diff"),
                catch_stdout= not verbose,
                verbose=verbose, dry_run=dry_run)
    if bag["unknown files"]:
        extract_archive(join(data_dir,"unknown-files.tar.gz"), verbose, dry_run)

    if bag.get("mq patches used"):
        rebuild_patchdir( [ i.split(":") for i in bag["patchname list"] ],
                          verbose, dry_run)

def script_shortname():
    """return the name of this script without a path component."""
    return os.path.basename(sys.argv[0])

def print_doc():
    """print embedded reStructuredText documentation."""
    print(__doc__)

def print_summary():
    """print a short summary of the scripts function."""
    print("%-20s: backup and recovery a mercurial repository\n" % script_shortname())

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

    parser.add_option("--summary",
                      action="store_true",
                      help="print a summary of the function of the program",
                      )
    parser.add_option("--doc",
                      action="store_true",
                      help="create online help in restructured text"
                           "format. Use \"./hg-recover.py --doc | rst2html\" "
                           "to create html-help"
                     )
    parser.add_option("-f", "--file",
                      action="store",
                      type="string",
                      help="create mercurial recovery data in the " +\
                           "given file or directory. If the given name " +\
                           "ends with \".tar\" or \".tag.gz\", a tar " +\
                           "file or a compressed tar file is created. " +\
                           "The default for this is \"%s\"" % default_file,
                      metavar="FILENAME"
                     )
    parser.add_option("-w", "--working-copy",
                      action="store",
                      type="string",
                      help="specify where the WORKINGCOPY is " +\
                           "found, \".\" is the default. " +\
                           "For --recover, this is the directory " +\
                           "where the working copy directory will " +\
                           "be created as a sub-directory.",
                      metavar="WORKINGCOPY"
                     )
    parser.add_option("-c", "--create",
                      action="store_true",
                      help="create mercurial recovery data in the " +\
                           "given DATA_DIRECTORY. If the given name " +\
                           "ends with \".tar\" or \".tag.gz\", a tar " +\
                           "file or a compressed tar file is created. ",
                      metavar="DATA_DIRECTORY"
                     )
    parser.add_option("-r", "--recover",
                      action="store_true",
                      help="recover repository from the recovery data " +\
                           "in the given DATA_DIRECTORY",
                      metavar="DATA_DIRECTORY"
                     )
    parser.add_option("--central-repo",
                      action="store",
                      type="string",
                      help="specify the CENTRALREPOSITORY",
                      metavar="CENTRALREPOSITORY"
                     )
    parser.add_option("-v", "--verbose",
                      action="store_true",
                      help="print to the screen what the program does",
                     )
    parser.add_option("--dry-run",
                      action="store_true",
                      help="do not apply any changes",
                     )

    # x= sys.argv
    (options, _) = parser.parse_args()
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
