#! /usr/bin/env python3
# -*- coding: UTF-8 -*-

"""convert mercurial to darcs patches by re-recording the patches."""

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

# pylint: disable=invalid-name, missing-module-docstring

# pylint: disable= deprecated-module
from optparse import OptionParser

import subprocess
import sys
import os
import os.path
import tempfile

assert sys.version_info[0]==3

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
        print(">", cmd)
        if dry_run:
            return None
    if catch_stdout:
        stdout_par=subprocess.PIPE
    else:
        stdout_par=None
    # pylint: disable= consider-using-with
    p= subprocess.Popen(cmd, shell=True,
                        stdout=stdout_par, stderr=subprocess.PIPE,
                        close_fds=True)
    (child_stdout, child_stderr) = p.communicate()
    if p.returncode!=0:
        raise IOError(p.returncode,"cmd \"%s\", errmsg \"%s\"" % (cmd,child_stderr))
    if child_stdout is None:
        return None
    # decode: return result as <str> instead of <bytes>
    return child_stdout.decode()

def rename(old, new, verbose, dry_run):
    """rename a file."""
    if dry_run or verbose:
        print("> rename %s to %s" % (old, new))
    if dry_run:
        return
    dir_= os.path.dirname(new)
    if dir_: # if "new" has a ditrectory part:
        if not os.path.isdir(dir_): # if the ditrectory doesn't exist:
            os.mkdir(dir_)
    os.rename(old, new)

# -----------------------------------------------
# path utilities
# -----------------------------------------------

def parent_dirs(d):
    """return the directory and all it's parent directories."""
    while True:
        if not d:
            return
        yield d
        d= os.path.dirname(d)

def all_subdirs(dirs):
    """return all subdirs of dirs as complete paths."""
    n= set()
    for d in dirs:
        for x in os.walk(d):
            n.add(x[0])
    return n

def all_parent_dirs(dirs):
    """return sorted list of all the parent directories of a list of dirs.
    """
    n= set()
    for d in dirs:
        for pd in parent_dirs(d):
            n.add(pd)
    return n

def touch(path, verbose, dry_run):
    """create empty file."""
    if dry_run or verbose:
        print("> create empty file %s" % path)
    if dry_run:
        return
    with open(path, 'a'):
        os.utime(path, None)

def mk_file(path, verbose, dry_run):
    """create a file as empty if it doesn't exist."""
    if os.path.exists(path):
        return
    dir_= os.path.dirname(path)
    if not os.path.exists(dir_):
        if dry_run or verbose:
            print("> create directory %s" % dir_)
        if not dry_run:
            os.makedirs(dir_)
    touch(path, verbose, dry_run)

def rm_file(path, verbose, dry_run):
    """remove file if it exists."""
    if dry_run or verbose:
        print("> remove file %s" % path)
    if dry_run:
        return
    os.remove(path)

def rm_dir(path, verbose, dry_run):
    """remove file if it exists."""
    if dry_run or verbose:
        print("> remove dir %s" % path)
    if dry_run:
        return
    os.rmdir(path)

# -----------------------------------------------
# mercurial commands
# -----------------------------------------------

def hg_cmd(cmd, catch_stdout, verbose, dry_run):
    """get data from a hg command."""
    return _system("hg %s" % cmd, catch_stdout, verbose, dry_run)

def darcs_cmd(cmd, catch_stdout, verbose, dry_run):
    """get data from a hg command."""
    return _system("darcs %s" % cmd, catch_stdout, verbose, dry_run)

def hg_known_files(file_or_dir, verbose):
    """run a simple "hg status -A", remove all unknown files.
    """
    result= hg_cmd("status -A %s" % file_or_dir, True, verbose, False)
    for l in result.splitlines():
        if not l.startswith("?"): # marker for an unknown file
            return True
    return False

#def hg_simple_status(file_or_dir, verbose):
#    """run a simple "hg status -A".
#    """
#    return hg_cmd("status -A %s" % file_or_dir, True, verbose, False)

def hg_status(revision, verbose):
    """get status flags for the changes of a given revision.

    returns a list of tuples, each tuple containing:
      command, name, name2(optionals)

    known commands:
      modified [name]
      added [name]
      removed [name]
      rename [old-name] [new-name]
    """
    mymap= { "M" : "modified",
             "A" : "added",
             "R" : "removed",
           }
    result= hg_cmd("status --change %s -C" % revision, True, verbose, False)
    ignore_list= set()
    actions= []
    mylist= []
    for l in result.splitlines():
        flag= l[0]
        name= l[2:]
        if flag!=" ":
            mylist.append([flag,name])
        else:
            mylist[-1].append(name)
            ignore_list.add(name)
    for l in mylist:
        flag= l[0]
        if l[1] in ignore_list:
            continue
        if flag=="A" and len(l)>2:
            # rename
            actions.append(("rename",l[2],l[1]))
        else:
            actions.append((mymap[flag],l[1]))
    return actions

def hg_log(revision,verbose):
    """returns the author and the complete log message.

    returns a tuple: (author,log)
    """
    result= hg_cmd("log -r %s --template '{author}\n{desc}\\n'" % \
                   revision, True, verbose, False)
    l= result.splitlines()
    l.append("")
    return (l[0],"\n".join(l[1:]))

def hg_revision_range(revision1, revision2, verbose):
    """return all revisions between revision1 and revision2."""
    all_= hg_cmd("log -r %s:%s --template '{rev}\\n'" % (revision1,revision2),
                 True,verbose, False)
    return [i for i in all_.splitlines() if not i.isspace() and i!=""]

def darcs_replay(author, log,actions,verbose,dry_run):
    """replay actions in darcs."""
    # pylint: disable= too-many-locals, too-many-branches, too-many-statements
    renames= [i for i in actions if i[0]=="rename"]
    rest   = [i for i in actions if i[0]!="rename"]
    actions_= renames
    actions_.extend(rest)
    added_dirs= set()
    maybe_removed_dirs=set()
    for item in actions_:
        action= item[0]
        if action=="rename":
            (old,new)= item[1:3]
            # mercurial already has renamed the file, undo the rename:
            # pylint: disable= arguments-out-of-order
            rename(new, old, verbose, dry_run)
            # we must take care if the target directory does not exist:
            olddir_= os.path.dirname(old)
            dir_= os.path.dirname(new)
            if olddir_ != dir_:
                if dir_ not in added_dirs:
                    darcs_cmd("add %s" % dir_,False,verbose,dry_run)
                    added_dirs.add(dir_)
            maybe_removed_dirs.add(os.path.dirname(old))
            darcs_cmd("mv --case-ok %s %s" % (old,new),False,verbose,dry_run)
        elif action=="added":
            darcs_cmd("add --case-ok %s" % item[1],False,verbose,dry_run)
        elif action=="removed":
            # recreate the file so darcs can remove it:
            # @@@
            mk_file(item[1], verbose, dry_run) # create empty file if
                                               # it doesn't exist
            darcs_cmd("revert --all %s" % item[1],False,verbose,dry_run)
            darcs_cmd("remove %s" % item[1],False,verbose,dry_run)
            rm_file(item[1], verbose, dry_run)
            maybe_removed_dirs.add(os.path.dirname(item[1]))
        elif action=="modified":
            pass # nothing to do
        else:
            raise ValueError("unknown action: \"%s\"" % action)
    if not dry_run:
        if maybe_removed_dirs:
            print("MAYBE REMOVED:",maybe_removed_dirs)#@@@
            subs= all_subdirs(maybe_removed_dirs)
            pars= all_parent_dirs(maybe_removed_dirs)
            all_possible_removed_dirs= sorted(pars.union(subs))
            all_possible_removed_dirs.reverse()
            for dir_ in all_possible_removed_dirs:
                if not hg_known_files(dir_, verbose):
                    # the directory is unknown to mercurial
                    darcs_cmd("remove %s" % dir_,False,verbose,dry_run)
                    rm_dir(dir_, verbose, dry_run)
        (handle,path)= tempfile.mkstemp(prefix="hg-darcs-",text=True)
        fh= os.fdopen(handle,"w")
        fh.write(log)
        fh.close()
    else:
        path="[logfile]"
    darcs_cmd("record --logfile=%s -A '%s' -a" % (path,author),
              False,verbose,dry_run)
    if dry_run:
        print("LOG:")
        print("-" * 40)
        print(log)
        print("-" * 40)
    if not dry_run:
        os.remove(path)

def convert(revision, verbose, dry_run):
    """convert a mercurial revision to darcs."""
    hg_cmd("update -r %s" % revision, False, verbose, dry_run)
    (author,log)= hg_log(revision, verbose)
    changes= hg_status(revision, verbose)
    darcs_replay(author, log, changes, verbose, dry_run)


def convert_from_to(revision1, revision2, verbose, dry_run):
    """convert revisions in a range to darcs."""
    if not os.path.exists(".hg"):
        sys.exit("error: no mercurial repo (\".hg\") found")
    if not os.path.exists("_darcs"):
        sys.exit("error: no darcs repo (\"_darcs\") found\n"+\
                 "you can create one with \"darcs init\"")
    revs= hg_revision_range(revision1, revision2, verbose)
    for rev in revs:
        convert(rev, verbose, dry_run)

# version of the program:
my_version= "1.0"

def process(options,_):
    """do all the work."""
    if options.revision is None:
        sys.exit("error: revision is mandatory")
    revs= options.revision.split(":")
    if len(revs)>2:
        sys.exit("error: only -r [rev] or -r [rev1:rev2] is valid")
    if len(revs)==1:
        revs.append("tip")
    convert_from_to(revs[0],revs[1],options.verbose, options.dry_run)

def script_shortname():
    """return the name of this script without a path component."""
    return os.path.basename(sys.argv[0])

def print_summary():
    """print a short summary of the scripts function."""
    print("%-20s: convert mercurial revisions to darcs...\n" % script_shortname())

def main():
    """The main function.

    parse the command-line options and perform the command
    """
    # command-line options and command-line help:
    usage = "usage: %prog -r [revisions] {extra options}"

    parser = OptionParser(usage=usage,
                          version="%%prog %s" % my_version,
                          description= \
                            "This program converts mercurial revisions to "+\
                            "darcs revisions. The changes, log messages and "+\
                            "author information remain intact, only the "+\
                            "record date is set to today. Note that a darcs "+\
                            "repository must already be present."
                         )

    parser.add_option("--summary",  # implies dest="nodelete"
                      action="store_true", # default: None
                      help="print a summary of the function of the program",
                      )
    parser.add_option("-r", "--revision", # implies dest="file"
                      action="store", # OptionParser's default
                      type="string",  # OptionParser's default
                      help= "Specify the REVISION. REVISION may be a "+\
                            "mercurial revision or a revision range where two "+\
                            "revisions are separated by a colon. If just one "+\
                            "revision is given, all revisions from there to "+\
                            "\"tip\" are taken. Tags or strings like \"tip\" "+\
                            "may also be used as a revision specification.",
                      metavar="REVISION"  # for help-generation text
                      )
    parser.add_option("-v", "--verbose",   # implies dest="switch"
                      action="store_true", # default: None
                      help="print to the screen what the program does",
                     )
    parser.add_option("--dry-run",   # implies dest="switch"
                      action="store_true", # default: None
                      help="do not apply any changes",
                     )

    #x= sys.argv
    (options, args) = parser.parse_args()
    # options: the options-object
    # args: list of left-over args

    if options.summary:
        print_summary()
        sys.exit(0)

    process(options,args)
    sys.exit(0)

if __name__ == "__main__":
    main()
