===========
bii_scripts
===========

.. contents:: :backlinks: none

-------
Remarks
-------

This is a collection of useful scripts and libraries for the Bessy control
system.

bii_scripts is avaliable under the terms of the 
`GNU General Public License v.3 <http://www.gnu.org/licenses/gpl-3.0.html>`_.

| If you are interested in getting the scripts or libraries you can download 
  them as tar.gz or zip
| file from the 
  `repository page <http://www-csr.bessy.de/cgi-bin/hgweb.cgi/bii_scripts/file>`_ 
  (click on "bz2", "zip" or "gz").

However, the preferred way is to clone the main darcs repository::

  darcs get http://www-csr.bessy.de/control/bii_scripts/repo/bii_scripts

or to clone the mercurial mirror repository::

  hg clone http://www-csr.bessy.de/cgi-bin/hgweb.cgi/bii_scripts

For any questions feel free to contact one of the script authors:

| Thomas.Birke@helmholtz-berlin.de
| Benjamin.Franksen@helmholtz-berlin.de
| Berhard.Kuner@helmholtz-berlin.de
| Victoria.Laux@helmholtz-berlin.de
| Goetz.Pfeiffer@helmholtz-berlin.de

or the maintainer of this page:

| Goetz.Pfeiffer@helmholtz-berlin.de

-------
Scripts
-------

**accLaunch**
  | launch panels for the BESSY II control system. All panels are read-only, so
    you can not interfere with the control system.

**addPVtoArchiver**
  | script to add a PV to the channel access archiver.

**adl_cvs_diff.pl**
  | show differences between the working and the repository version of an dm2k
    panel (\*.adl) file. Supports CVS and subversion as version control systems.
  | `documentation <scripts/adl_cvs_diff.html>`__

**adlsort.pl**
  | Print dm2k panel (\*.adl) files sorted to standard out.  This can be used to
    compare two dm2k panel files.  
  | `documentation <scripts/adlsort.html>`__

**archiver2camonitor.py**
  | This tool converts data from the Channel access archiver (retrieved via CGI,
    "plot" command, then clicking on "plot") to a sorted list of values
    compatible with the format of the camonitor tool.  
  | `documentation <scripts/archiver2camonitor.html>`__

**bdns_import.pl**
  | import BESSY device names into the oracle database.
  | `documentation <scripts/bdns_import.html>`__

**bdns_lookup.pl**
  | lookup BESSY device names in the oracle database.
  | `documentation <scripts/bdns_lookup.html>`__

**bdns_sort.pl**
  | sort BESSY device names according to their
    member,index,subindex,family,counter,subdomain, subdomainnumber,domain and
    facility.
  | `documentation <scripts/bdns_sort.html>`__

**bdnsParse.pl**
  | Parse and print BESSY device names according to their
    member,index,subindex,family,counter,subdomain, subdomainnumber,domain and
    facility.
  | USAGE: bdnsParse.pl DEVNAME1 ...
  
**browsedb.pl**
  | a perl-script with a graphical user interface to browse the oracle database.
    The program can be used to view and change data in the database as well as
    show relations between the tables.

**buildall.pl**
  | Find EPICS support modules and build them in the correct dependency order.
  | `documentation <scripts/buildall.html>`__

**buds_lookup.pl**
  | lookup BESSY units in the oracle database.
  | `documentation <scripts/buds_lookup.html>`__

**camon**
  | simple channel access monitor with output as table of PVs.
  | `documentation <scripts/camon.html>`__

**camonitor2table.py**
  | convert files created by the EPICS camonitor command to tables. This 
    command can also filter by timestamp and by PV. It can create csv output 
    and it can differentiate values.
  | `documentation <scripts/camonitor2table.html>`__

**camon**
  | simple channel access monitor with output as table of PVs.
  | `documentation <scripts/camon.html>`__

**camonitor_sort.pl**
  | sort and filter files created by the EPICS camonitor command.  The filtering
    can be specified with regular expressions.  This tool is especially useful
    when many different PV's are monitored at a time.  
  | `documentation <scripts/camonitor_sort.html>`__

**canlink.pl**
  | encode and decode the lowCAL hardware link as it is used in the BESSY
    MultiCAN device support for EPICS.
  | `documentation <scripts/canlink.html>`__

**console.py**
  | Open a console on an IOC by contacting the console server
    without requesting a password.
  | `documentation <scripts/console.html>`__

**console-get**
  | download and concatenate console server files.
  | `documentation <scripts/console-get.html>`__

**console-watch**
  | display growth rate of console server files.
  | `documentation <scripts/console-watch.html>`__

**CreatePanel.pl**
  | Create Panels for 'dm2k' or 'edm' from EPICS-Database '.substitution' files
    and widgets for each item of the '.substitution' file.
  | `documentation <scripts/CreatePanel.html>`__

**csv2alh**
  | Create alarm handler config file from .CSV file 
  | `documentation <scripts/csv2alh.html>`__
  | For details see alh part of `csv2EpicsDb <scripts/csv2epicsDb.html>`__

**csv2epicsDb**
  | Create EPICS data from a spreadsheet: EPICS.db, Panels, Alarm handler, 
  | Archiver files `documentation <scripts/csv2epicsDb.html>`__

**csv2json.py**
  | Convert CSV files to JSON and vice versa.
  | This can be used to convert csv files as they are used in BII-Controls and
    MLS-Controls to JSON and back again to CSV. This can be useful if you want 
    to edit csv files or run a diff to see what was changed. CSV files have very
    long lines that are hard to edit and are hard to use with 'diff'.

**csv2plot**
  | Combine and convert numerical data from .csv files for gnuplot use.
  | `documentation <scripts/csv2plot.html>`__

**ctl-dist-info**
  | A wrapper script for rsync-dist-info.py that is used to get information on
    installed software versions of the BII-Controls, MLS-Controls,
    ERL-Controls, BL-Controls or HoBiCaT-Controls application.
  | `documentation <scripts/csv2plot.html>`__

**ctl-restore**
  | A small wrapper script that calls darcs-restore to restore the source
    directory along with it's darcs repository for a given version of the
    BII-Controls, MLS-Controls, ERL-Controls, BL-Controls or HoBiCaT-Controls
    application.
  | `documentation <scripts/ctl-restore>`__

**cvs-recover.py**
  | A backup and recovery tool for CVS. 
  | Instead of saving the complete repository this script only saves
    differences relative to a central CVS repository. By this, much disk space
    is saved, the backup file has usually only about 100kBytes or less.  This
    can be used to distribute a small recovery file together with the
    application. If it is needed, it is possible to restore the state of the
    original CVS working copy from which the application was built. 
  | `documentation <scripts/cvs-recover.html>`__

**cvs_diff.pl**
  | compare versions of a file in a CVS repository. This tool can remove emtpy
  | lines and c-comments before comparing.
  | `documentation <scripts/cvs_diff.html>`__

**cvsGuru**
  | CVS wrapper script - for ctlguru only

**cvs_log_diff.pl**
  | compares the all log-messages between two revisions or tags in a CVS
    repository.  
  | `documentation <scripts/cvs_log_diff.html>`__

**hg-compare-repos**
  | compares the logs of two mercurial repositories with tkdiff.
  | `documentation <scripts/hg-compare-repos.html>`__

**hg-kompare**
  | Show mercurual patches with kompare..
  | `documentation <scripts/hg-kompare.html>`__

**hg-meld**
  | Show mercurual patches with meld..
  | `documentation <scripts/hg-meld.html>`__

**darcs-compare-repos**
  | compares the logs of two darcs repositories with tkdiff.
  | `documentation <scripts/darcs-compare-repos.html>`__

**darcs-kompare**
  | start KDE kompare to compare the working copy with the repository copy of a
    file.
  | `documentation <scripts/darcs-kompare.html>`__

**darcs-meld**
  | start KDE meld to compare the working copy with the repository copy of a
    file.
  | `documentation <scripts/darcs-meld.html>`__

**darcs-notify**
  | Send email notification when patches are applied to a repository. Intended
    as a light-weight replacement for darcs-monitor.
  | `documentation <scripts/darcs-notify.html>`__

**darcs-restore**
  | see darcs-save

**darcs-save**
  | darcs-save and darcs-restore can be used to save and later restore a source
    tree that is under darcs control. The idea is to call darcs-save immediately
    before (binary) distribution. The generated directory named '.darcs-restore'
    should then be distributed, too.
    
  | In order to restore the sources for such a distribution, call darcs-restore
    with the distribution directory (which may be a remote path, darcs-restore
    uses scp) as first, and the name of the directory to be created as second
    argument. Special feature: it is not necessary to record pending changes
    prior to distribution.  Not-recorded changes and not-yet-added files and
    directories are restored just fine.

**darcs-sig**
  | create a textual representation of the state of a darcs repository (a list
    of log messages and some extra information).

**dbcount**
  | count the number of records in a file
  | `documentation <scripts/dbcount.html>`__

**dbdiff**
  | display the difference between two \*.db files using tkdiff
  | `documentation <scripts/dbdiff.html>`__

.. _dbfilter.pl:

**dbfilter.pl**
  | A tool to filter db files or to find information in db files. Regular
    expression matches can be done on record names, record types or values of
    record-fields.  Connections between records can be shown, lowCAL and SDO CAN
    links can be decoded.
  | The script needs the following perl modules:
  | `parse_db.pm`_ 
  | `analyse_db.pm`_ 
  | `canlink.pm`_ 
  | Here is the documentation and the source of the script itself:
  | `documentation <scripts/dbfilter.html>`__

**db_request.py**
  | a tool to perform SQL requests on the oracle database.
  | `documentation <scripts/db_request.html>`__

**dbscan.pl**
  | This script is from Rolf Keitel <rolf@triumf.ca>. It scans db and sch files
    and has lots of options, the most interesting being '-d' which searches for
    'dangling links'. I.e. it lists all records which have links that point
    somewhere outside the given db file (along with the target record).
    Unfortunately does not tell which link field and which target field.  Note
    that `dbfilter.pl`_ can do the same with it's "--unresolved_links" option.
  | `documentation <scripts/dbscan.html>`__

**dbsort**
  | print an EPICS database sorted. Note that `dbfilter.pl`_ does exactly the same
    when called with a database file and no options at all.
  | `documentation <scripts/dbsort.html>`__

**dbutil.p**
  | A tool that can export oracle database-tables to ASCII files and re-import
    these files. Useful if you want to change many parts of a database-table
    with your favorite text-editor...
  | `documentation <scripts/dbutil.html>`__

**dumpdb**
  | dump a database (\*.db) file, one record-name combined with one field name
    in a single line.

**expander.pl**
  | macro expander for text-files. Since this tool allows the execution of
    arbitrary perl-expressions, it is quite powerful and (if you want this) a
    programming language of its own. It features if-statements, complex
    expressions and for-loops among others.  This script needs the
    `expander.pm`_ module. See the `expander documentation <perl/expander.html>`__
    for a more comprehensive description of the expander file format.
  | `documentation <scripts/expander.html>`__

**filter_can_links.pl**
  | extract CAN links from a .db file (for the BESSY lowCAL protocol). Note that
    `dbfilter.pl`_ can do the same with it's "--lowcal" option.
  | `documentation <scripts/filter_can_links.html>`__

**flatdb**
  | expands and vdctdb db-file into a "flat" db file. 

**gadgetbrowser**
  | database browser for the new gadget database.

**git-meld**
  | compares all files of two git versions with meld.

**git-repo-merge.sh**
  | Combines patches of two git repositories by creating a new git branch.

**grab_xkeys.pl**
  | a little X11 utility that displays scan codes of pressed keys.

**grepDb.pl**
  | A tool to search in EPICS-db files. It allows to define regular expressions
    as triggers in its commandline options for record-name, record-type,
    field-name and field value if a record or a field matches the trigger, it
    causes a print of the record. To control the printed output there are
    options to define the record names, record types or field types that have to
    be printed. This script needs the `parse_db.pm`_ module.
  | `documentation <scripts/grepDb.html>`__

**hg2darcs.py**
  | A program that converts mercurial revisions to darcs revisions.
  | The changes, log messages and "author information remain intact, only the
    record date is set to today. Note that a darcs repository must already be
    present.
  | `documentation <scripts/hg2darcs.html>`__

**hg2git.py**
  | A program that converts mercurial revisions to git revisions. 
  | The changes, log messages and "author information remain intact, only the
    record date is set to today. Note that a git repository must already be
    present.
  | `documentation <scripts/hg2git.html>`__

**hg-kompare.py**
  | A program that calls kompare to do comparisions of the
    working copy with a mercurial repository or compare files of different 
    versions in the mercurial repository.
  | `documentation <scripts/hg-kompare.html>`__

**hg-recover.py**
  | A backup and recovery tool for mercurial. 
  | Instead of saving the complete repository this script only saves differences
    relative to a central mercurial repository. By this, much disk space is saved,
    the backup file has usually only about 100kBytes or less.
    This can be used together with rsync-dist.pl to distribute a small recovery
    file together with the application. If it is needed, it is possible to restore
    the state of the original working copy and mercurial repository from which the
    application was built. 
  | `documentation <scripts/hg-recover.html>`__

**idcp-dist-info**
  | A small wrapper script that calls rsync-dist-info.py for IDCP (undulator
    control) IOCs
  | `documentation <scripts/idcp-dist-info>`__

**idcp-drive-info**
  | Displays information about drives of IDCP controled undulators.
  | This script can also show the software version of the uniserv program for
    each undulator.
  | `documentation <scripts/idcp-drive-info>`__

**idcp-get-source**
  | Get and and optionally build the source of installed versions of IDCP.
  | You can provide the undulator name or the version string. You can also
    retrieve the latest IDCP version. This script works for the BESSY and MLS
    facility. It can also show a list of installed insertion devices and an
    give an overview of currently used IDCP versions.
  | `documentation <scripts/idcp-get-source>`__

**idcp-restore**
  | A small wrapper script that calls hg-recover.py to restore the source
    directory along with it's mercurial repository for a given version of IDCP
    as it is installed on one of the BESSY undulators.
  | `documentation <scripts/idcp-restore>`__

**idcp-mls-restore**
  | A small wrapper script that calls hg-recover.py to restore the source
    directory along with it's mercurial repository for a given version of IDCP
    as it is installed on the MLS undulator.
  | `documentation <scripts/idcp-mls-restore>`__

**iddb**
  | A script that queries the Insertion Device StructuredData database server
    on gwc2c to display a table with names and properties of insertion devices
    or to do arbitrary queries on that database.
  | `documentation <scripts/iddb>`__

**ioc-reboot.py**
  | Reboots one or several IOCs via telnet and "reboot" command.
  | `documentation <scripts/ioc-reboot.html>`__

**latin1toutf8.sh**
  | convert latin-1 texts to utf-8 (calls the iconv utility).

**lockGuru**
  | Check and/or create the mutex file lock, probably used together
    with cvsGuru.

**makeDocCommonIndex.pl**
  | create an html index for documentation generated with makeDoc.  

**makeDocPerl.pl**
  | create html documentation for perl scripts that contain embedded
    documentation according to "makeDoc" rules. 

**makeDocTxt.pl**
  | create html documentation for ascii files that contain documentation
    according to "makeDoc" rules.  
  | `documentation <scripts/makeDocTxt.html>`__

**makeRegistrar**
  | create EPICS 3.14 registrar code (generates c-code).

**mlsLaunch**
  | launches the operator main panel for the MLS storage ring

**multi-commit.pl**
  | perform multiple commits (cvs, svn, darcs or mercurial) with a prepared
    command-file.
  | `documentation <scripts/multi-commit.html>`__

**oracle_request**
  | command line tool to make database queries on the oracle database.

**paths2.pl**
  | like paths.pl but uses the global installation directories of the
    bii_scripts project.

**paths.pl**
  | prints commands to set your perl-environment in order to use the
    perl-modules and scripts of bii_scripts 

**pcomp.pl**
  | recursivly compare two directories. Shows which files or directories have
    different dates, different sizes or are missing. The files or directories
    can be filtered. The kind comparisons can also be filtered.  Can remove CVS
    tags or <CR> characters before comparing.
  | `documentation <scripts/pcomp.html>`__

**pfind.pl**
  | a perl-script for powerful recursive file pattern search, like a recursive
    grep, but better. Features among other things text-file search, c-file
    search, regular expressions that match across line-ends.
  | `documentation <scripts/pfind.html>`__

**pg_request.py**
  | a tool to perform SQL requests on the PostgreSQL database.
  | `documentation <scripts/pg_request.html>`__

**psh**
  | a perl-shell. Useful for testing small functions or expressions in an
    interactive shell.
  | `documentation <scripts/psh.html>`__

**pyone.py**
  | python One-liner helper.
  | `documentation <scripts/pyone.html>`__

**python-modules.py**
  | Show what python modules a python script uses, complete with file path.
  | `documentation <scripts/python-modules.html>`__

**repo-hash.sh**
  | Create a short hash or hash file for a repository.
  | `documentation <scripts/repo-hash.html>`__

**repo-loginfo.py**
  | print log summaries for darcs or mercurial repositories.
  | `documentation <scripts/repo-loginfo.html>`__

**repo-mirror.py**
  | Mirror a repository in another one with a different version control system.
  | `documentation <scripts/repo-mirror.html>`__

**rsync-deploy**
  | tool for management for distribution of binary files with. The successor of
    this script is rsync-dist.pl.

**rsync-dist.pl**
  | A Perl script for managing distributions of binary files. 
  | This script can be used to copy files (usually binary distributions of
    programs) to a remote server while preserving all the old versions of
    these distributions. It can also create and change symbolic links that
    point to certain distributions.
  | `homepage <https://rsync-dist.sourceforge.io>`__

**rsync-dist-info.py**
  | this program prints summaries and statistics of rsync-dist link-log files.
  | The script needs the following perl modules:
  | `dateutils.py`_ 
  | `rsync_dist_lib.py`_ 
  | `boottime.py`_ 
  | `PythonCA <http://www-acc.kek.jp/EPICS_Gr/products.html>`__
  | Here is the documentation and the source of the script itself:
  | `documentation <scripts/rsync-dist-info.html>`__

**Sch2db.pl**
  | a perl sch to db converter. Converts capfast(\*.sch) files to the db file
    format as it is used in EPICS. This is faster and more flexible that the
    combination of sch2edif and e2db. This script needs the 
    `capfast_defaults.pm`_ module.
  | `documentation <scripts/Sch2db.html>`__

**sch_repo_diff.pl**
  | shows the difference between a modified capfast (\*.sch) file and it's
    version on the top-trunk in the repository.  The difference of the resulting
    \*.db files is shown, which is much clearer when you want to find out what
    was really changed. Supports cvs, subversion and mercurial.
  | `documentation <scripts/sch_repo_diff.html>`__

**set_ioc_tsrv.pl**
  | set terminal_server and optionally port to connect to console of an ioc.
    Probably no longer needed since the conserver is now used for all IOCs.
  | `documentation <scripts/set_ioc_tsrv.html>`__

**stepy**
  | Stepy is a configurable measurement program that preforms loops that set
    EPICS process variables (PV) and reads a set of process variables after each step.
  | `documentation <scripts/stepy.html>`__

**sqlutil.py**
  | this program copies data between a database, a dbitabletext file, the
    screen.
  | `documentation <scripts/sqlutil.html>`__

**stripUnresolvedDb.pl**
  | remove all unresolved fields from a database. Means all fields that contain
    some variables $(VARIABLE).
  | `documentation <scripts/stripUnresolvedDb.html>`__

**subst-dump.py**
  | Parse and dump EPICS substitution files as JSON or python data. Can also be
    used to verify, if a substitution is valid.
  | `subst-dump.html <../script/subst-dump.html>`__

**subst2exp.pl**
  | convert substitution-files to expander format for usage with the expander.pl
    script. This can be used on the fly as an alternative to EPICS msi, or to
    convert substitution files to expander format in order to use the much more
    powerful commands of the `expander <../lib/perl/expander.html>`__ 
    format when replacing values in EPICS template files. 
  | `subst2exp.html <../script/subst2exp.html>`__

**substdiff**
  | compares two substitution files.
  | `documentation <scripts/substdiff.html>`__

**substprint.pl**
  | pretty-print a substitution file.
  | `documentation <scripts/substprint.html>`__

**tableutil.py**
  | A tool to manipulate and print tables of numbers. New columns can be
    calculated by applying calculation expression. Command scripts can be used
    to do more complex operations on tables.
  | `documentation <scripts/tableutil.html>`__

**toASCII**
  | toASCII STDIN:  Print hex-numbers from STDIN as characters,
    convert control signals to mnemonics

**tkSQL**
  | query the oracle database by directly entering SQL requests.

**txt2html.pl**
  | trivial html encoding of normal text

**txtcleanup.py**
  | a cleanup tool for text files. Removes tabs and trailing spaces in files.
    Can also be used as a filter.
  | `documentation <scripts/txtcleanup.html>`__

**uniserv-restore**
  | A small wrapper script that calls hg-recover.py to restore the source
    directory along with it's mercurial repository for a given version of 
    uniserv as it is installed on one of the BESSY undulators.
  | `documentation <scripts/uniserv-restore>`__

**unlockGuru**
  | Remove the mutex file lock, probably used together with cvsGuru.

**vdb_repo_diff.pl**
  | graphical compare of vdb files with or within a repository.  Supports cvs,
    subversion and mercurial.
  | `documentation <scripts/vdb_repo_diff.html>`__

**vdct**
  | starts the VisualDCT database editor.   

**xls2csv.pl**
  | A small wrapper around the xls2csv utility that provides better error
    handling.

--------------
Perl Libraries
--------------

.. _analyse_db.pm:

**analyse_db.pm**
  | a Perl module to analyse databases parsed with parse_db.
  | `documentation <perl/analyse_db.html>`__

**BDNS.pm**
  | BESSY device name parser.
  | `documentation <perl/BDNS.html>`__

**bessy_module.pm**
  | This performs a "module <command> <args...>" in the z-shell 
    environment and re-imports the environment-variables to the 
    perl-process, so they are available in the %ENV-hash
  | `documentation <perl/bessy_module.html>`__

**BrowseDB/TkUtils.pm**
  | Tk-utilities for browsedb.pl

**browsedb_conf.PL**
  | this file is only needed for "make install" in order to 
    patch browsedb.pl. It hat no use, once bii_scripts is installed

.. _canlink.pm:

**canlink.pm**
  | a perl-module that can be used to encode or decode the
    "cryptic can link" as it is used in the BESSY CAN Bus
    device support for EPICS.
  | `documentation <perl/canlink.html>`__

.. _capfast_defaults.pm:

**capfast_defaults.pm**
  | a Perl module that contains capfast defaults for
    record-fields.
  | `documentation <perl/capfast_defaults.html>`__

**cfgfile.pm**
  | simple module to read or write a configuration file. Probably
    unfinished and in alpha-release state. 
  | `documentation <perl/cfgfile.html>`__

**CreateX.pm**
  | Routines that help to write CreateX.pl scripts. Not quite sure
    what this does. Connects to the oracle database.
  | `documentation <perl/CreateX.html>`__

**dbdrv_lite.pm**
  | low level routines for sqlite. Used by dbdrv.

**dbdrv_oci.pm**
  | low level routines for the ORACLE database. Needed by dbdrv.

**dbdrv_pg.pm**
  | low level routines for a PostgreSQL database. Needed by dbdrv.

**dbdrv.pm**
  | low level utilities for SQL database access, needed by
    dbitable.
  | `documentation <perl/dbdrv.html>`__

**dbdrv_test.pl**
  | test-script for dbdrv. This shouldn't be in the repository!     

**dbitable.pm**
  | an object-oriented Perl module for handling single tables
    from an SQL database
  | `documentation <perl/dbitable.html>`__

.. _expander.pm:

**expander.pm** 
  | a module to perform macro-replacements in text files. Features
    if-statements, complex expressions and for-loops among others
  | `documentation <perl/expander.html>`__

**makeDocStyle.pm**
  | module for the makeDoc* scripts.

**ODB.pm**
  | a Perl module for accessing database via DBI.  Means easier 
    handling of the DBI routines via this layer.
  | `documentation <perl/ODB.html>`__

**Options.pm**
  | a Perl module for handling programm arguments, command line in
    and output inclusive login requests.
  | `documentation <perl/Options.html>`__

.. _parse_db.pm:

**parse_db.pm**
  | a perl-module for parsing EPICS db-files.
  | `documentation <perl/parse_db.html>`__

**parse_subst.pm**
  | a perl-module for parsing EPICS substitution-files.
  | `documentation <perl/parse_subst.html>`__

**printData.pm**
  | some console print utilities.
  | `documentation <perl/printData.html>`__

**scan_makefile.pm**
  | This module scans one or more than one makefile and returns 
    a hash reference containing all variables that are set within
    the makefile together with all environment variables.
  | `documentation <perl/scan_makefile.html>`__

**tokParse.pm**
  | token parser utilities (for makeDocTxt).
  | `documentation <perl/tokParse.html>`__

----------------
Python Libraries
----------------

**BDNS.py**
  | BESSY device name parser.
  | `documentation <python/bii_scripts3/BDNS.html>`__

.. _boottime.py:

**boottime.py**
  | get the boot time of an BESSY IOC by querying a certain pv.
  | `documentation <python/bii_scripts3/boottime.html>`__

**canlink.py**
  | A python version of the perl module canlink.pl. All functions implemented
    there are now also available in python. This module is used to encode and
    decode the CAN link as it is used in the LowCal device support that is part
    of the MultiCAN package developed here at HZB.
  | `documentation <python/bii_scripts/canlink.html>`__

**canLink.py**
  | partial python implementation of canlink.pl: decode the lowCAL hardware 
    link as it is used in the BESSY MultiCAN device support for EPICS.
  | `documentation <python/bii_scripts/canLink.html>`__

.. _dateutils.py:

**dateutils.py**
  | utilities for string <-> datetime conversions.
  | `documentation <python/bii_scripts/dateutils.html>`__

**p_enum.py**
  | enumeration types for python.
  | `documentation <python/bii_scripts/p_enum.html>`__

**parse_subst.py**
  | Parse EPICS substitution files.
  | `documentation <python/bii_scripts3/parse_subst.html>`__

**epicsUtils.py**
  | Utility collection to parse and handle with EPICS data: Database files,
    Alarm Handler, Panels etc
  | `documentation <python/bii_scripts/epicsUtils.html>`__

**FilterFile.py**
  | a python module for scripts that read or write to files
    or read or write to standard-in or standard-out. Can also
    be used to modify a file in a safe way by creating a temporary
    file and renaming the original file and the temporary file
    upon close.
  | `documentation <python/bii_scripts/FilterFile.html>`__

**listOfDict.py**
  | Functions to operate with the combined datatype list of dictionary items.
  | `documentation <python/bii_scripts/listOfDict.html>`__

**lslparser.py**
  | a module to parse the output of "ls -l".
  | `documentation <python/bii_scripts/lslparser.html>`__

**maillike.py**
  | parse texts that have a mail-like format.
  | `documentation <python/bii_scripts/maillike.html>`__

**numpy_util.py**
  | Utilities to numpy structured arrays. These arrays can be used to hold the
    data of number tables. This module is used by numpy_table.py and
    tableutil.py.
  | `documentation <python/bii_scripts/numpy_util.html>`__

**numpy_table.py**
  | Implements a table class based on numpy structured arrays. This module is
    basically an object oriented wrapper for all functions in numpy_util.py. It
    is used by tableutil.py.
  | `documentation <python/bii_scripts/numpy_table.html>`__

**pdict.py**
  | implements a dictionary for one-to-one relations.
  | `documentation <python/bii_scripts/pdict.html>`__

**pfunc.py**
  | utilities for python functions and lambda statements.
  | `documentation <python/bii_scripts/pfunc.html>`__

**ptestlib.py**
  | a module providing routines for doctest testcode.
  | `documentation <python/bii_scripts/ptestlib.html>`__

**putil.py**
  | This module provides functions for working
    with lists among other utilities.
  | `documentation <python/bii_scripts/putil.html>`__

**rdump.py**
  | a module for dumping of nested structures.
  | `documentation <python/bii_scripts/rdump.html>`__

.. _rsync_dist_lib.py:

**rsync_dist_lib.py**
  | sync_dist_info classes for parsing rsync-dist log files.
  | `documentation <python/bii_scripts3/rsync_dist_lib.html>`__

**sqlpotion.py**
  | a module with utilities and support functions for sqlalchemy.
  | `documentation <python/bii_scripts/sqlpotion.html>`__

**typecheck.py**
  | a module with type-tests and type-assertions.
  | `documentation <python/bii_scripts/typecheck.html>`__
