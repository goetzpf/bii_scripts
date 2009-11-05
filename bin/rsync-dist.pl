eval 'exec perl -S $0 ${1+"$@"}' # -*- Mode: perl -*-
    if 0;
# the above is a more portable way to find perl
# ! /usr/bin/perl

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


# @STATUS: release
# @PLATFORM: home bessy
# @CATEGORY: search


# [scriptname] -- describe the function here

use strict;

use FindBin;
use Getopt::Long;
use Sys::Hostname;
use File::Spec;
use File::Temp;
use Cwd;
use Time::Local;

use Data::Dumper;
use Carp;

use simpleconf;
use container;
use maillike;
use extended_glob;

use vars qw($opt_help
            $opt_man
            $opt_summary
            $opt_distpath
            $opt_linkpath
            $opt_localprefix
            $opt_message
            $opt_automessage
            $opt_tag
            $opt_autotag
            $opt_dist
            $opt_to_attic
            $opt_from_attic
            $opt_change_links
            $opt_add_links
            $opt_remove_links
            $opt_mirror
            $opt_rm_lock
            $opt_force_rm_lock
            $opt_mk_lock
            $opt_rebuild_last
            $opt_create_branch
            $opt_expand_glob
            $opt_ls 
            $opt_cat_log
            $opt_tail_log
            $opt_perl_log
            $opt_python_log
            $opt_ls_tag 
            $opt_ls_version
            $opt_cat_changes
            $opt_tail_changes
            $opt_config
            $opt_show_config
            $opt_write_config
            $opt_show_config_from_log
            $opt_write_config_from_log
            $opt_env
            $opt_branch
            $opt_partial
            $opt_version_file
            $opt_version_file_prefix
            $opt_editor
            $opt_prefix_distdir
            $opt_no_editor_defaults
            $opt_last_dist
            $opt_one_filesystem
            $opt_preserve_links
            $opt_dereference_links
            $opt_exclude_list
            $opt_checksum
            $opt_progress
            $opt_dry_run
            $opt_world_readable
            $opt_debug 
            $opt_version
            $opt_create_missing_links
            $opt_ssh_back_tunnel
            $opt_single_host
            $opt_filter_output
            );

use constant {
  do_add           => 0,
  do_change        => 1,
  do_change_or_add => 2,
  do_remove        => 3,
};

my $sc_version= "2.0";

my $sc_name= $FindBin::Script;
my $sc_summary= "manages binary distributions to remote servers"; 
my $sc_author= "Goetz Pfeiffer";
my $sc_year= "2007";

my $debug= 0; # global debug-switch

my $default_editor= "vi";

my @opt_hosts;
my @opt_users;
my @opt_localpaths;

# the following options are also recognized without
# a leading "--" since they are commands.
my @gbl_arg_lst= ('--dist',
                  '--to-attic',
                  '--from-attic',
                  '--change-links',
                  '--add-links',
                  '--remove-links',
                  '--mirror',
                  '--rm-lock',
                  '--force-rm-lock',
                  '--mk-lock',
                  '--rebuild-last',
                  '--create-branch',
                  '--expand-glob',
                  '--ls',
                  '--cat-log',
                  '--tail-log',
                  '--perl-log',
                  '--python-log',
                  '--ls-tag',
                  '--ls-version',
                  '--cat-changes',
                  '--tail-changes',
                  '--show-config',
                  '--write-config',
                  '--show-config-from-log',
                  '--write-config-from-log',
                  );

my $gbl_local_log= "$ENV{HOME}/.rsync-dist-log";

my @gbl_local_log_order= 
                  qw(ACTION 
                     STATUS
                     LOCALDATE 
                     LOCALHOST 
                     LOCALPATHS 
                     LOCALCWD 
                     FILES
                     REMOTEHOSTS 
                     REMOTEHOST
                     MIRRORHOSTS 
                     REMOTEUSERS
                     REMOTEUSER
                     REMOTE_MPATHS
                     REMOTE_MPATH
                     REMOTEPATH 
                     BRANCH
                     WORLDREADABLE
                     SOURCEDIR
                     VERSION
                     TAG
                     LOGMESSAGE 
                    );

# the following is a classification of commands. This is
# used when the local log-file is searched for defaults 
# of values like the last log-message that was entered
# or the last tag that was entered.
my %gbl_local_log_actionmap= 
     ( 'change links'    => 'links',
       'add links'       => 'links',
       'remove links'    => 'links',
       'move to attic'   => 'move',
       'move from attic' => 'move',
       );

# the following is used when an editor is started in order 
# for the user to specify a missing option. The text below
# is shown as a short help for the user.
my %gbl_edit_texts= 
  ( REMOTEHOSTSUSERS =>
                   "Please enter name of the remote host(s)\n" .
                   "You may specify the remote user(s) as well by\n" .
                   "providing a list in the form \"user\@hostname\"\n",
    REMOTEHOSTS => "Please enter name of the remote host(s)\n",

    REMOTEPATH  => "Please enter the distribution path on the remote host.\n",

    LOGMESSAGE  => "Please enter your log-message. If you see a default \n" .
                   "here, it is STRONGLY recommended that you change this.\n",

    TAG=>          "Please specify a tag (only a single line) for this\n" .
                   "version. If you see a default here, it is STRONGLY\n" .
                   "recommended that you change this.\n",

    DIST_LOCALPATHS  => "Please enter the directory/directories you want to\n" .
                        "distribute. \n",

    REMOTEHOST =>
                  "Please enter name of the remote host.\n",

    MOVE_DIR   => "Please enter the version-directory that is to be\n" .
                  "moved to or from the attic directory\n",
    MIRROR_HOSTS =>
                  "Please enter the hosts that the directory shall be\n" .
                  "mirrored to.\n",
    SOURCE_DIR => "Please enter the source the symbolic link shall refer\n" .
                  "to.\n",
    FILEMASK =>   "Please enter the files (or a filemask aka glob-pattern)\n" .
                  "for the symbolic links that are to be changed\n",                                                       
  );               

# the following are names of log-files
# that are created on the remote host
use constant
  { DIST_LOG     => 'LOG-DIST',
    LINK_LOG     => 'LOG-LINKS',

    DIST_CHANGES => 'CHANGES-DIST',
#    LINK_CHANGES => 'CHANGES-LINKS',

  };

my $my_errcode= 67;
# errcode returned by ssh command when a test 
# for certain preconditions fails. In this case,
# the whole ssh command is not dumped since the 
# ssh-command already did print a sensible error message
# to the screen 

my $gbl_rsync_opts="-a -z --delete";
# -a: equivalent to -rlptgoD:
#     -r: recursive
#     -l: copy symlinks as symlinks
#     -p: preserve permissions
#     -t: preserve modification times
#     -g: preserve group
#     -o: preserve owner
#     -D: preserve deices files (super user only), 
#         preserve special files
# -z: compress file data during transfer
# --delete: delete extraneous files from dest dirs
#           (receiver deletes before transfer)

# the following datastructure is used to take data from
# environment variables. This is done even when the "--env"
# option is nit given.
my %gbl_env_map_hash1=
              (
               RSYNC_DIST_EDITOR => \$opt_editor,
              );

# the following datastructure is used to take data from
# environment variables. This is done even when the "--env"
# option is nit given. This structure is evalued after the
# structure above, so the variables here have a lower priority
# than the ones listed above.
my %gbl_env_map_hash2=
              (
               EDITOR => \$opt_editor,
              );

# the following datastructure is used when the config-file
# is parsed. It links entries in the log-file to global
# variables in this program
my %gbl_map_hash= 
              (RSYNC_DIST_HOST      => \@opt_hosts,
               RSYNC_DIST_USER      => \@opt_users,
               RSYNC_DIST_PATH      => \$opt_distpath,
               RSYNC_DIST_LINKPATH  => \$opt_linkpath, 
               RSYNC_DIST_PREFIX_DISTDIR => \$opt_prefix_distdir, 
               RSYNC_DIST_LOCALPATH => \@opt_localpaths,
               RSYNC_DIST_LOCALPREFIX =>
                                       \$opt_localprefix,
               RSYNC_DIST_WORLDREADABLE => \$opt_world_readable,
               RSYNC_DIST_ONE_FILESYSTEM  => \$opt_one_filesystem,
               RSYNC_DIST_PRESERVE_LINKS  => \$opt_preserve_links,
               RSYNC_DIST_DEREFERENCE_LINKS  => \$opt_dereference_links,
               RSYNC_DIST_EXCLUDE_LIST  => \$opt_exclude_list,
               RSYNC_DIST_CHECKSUM  => \$opt_checksum,
               RSYNC_DIST_BRANCH => \$opt_branch,
               RSYNC_DIST_PARTIAL => \$opt_partial,
               RSYNC_DIST_VERSION_FILE => \$opt_version_file,
               RSYNC_DIST_VERSION_FILE_PREFIX => \$opt_version_file_prefix,
               RSYNC_DIST_EDITOR => \$opt_editor,
               RSYNC_DIST_EDITOR_NO_DEFAULTS => \$opt_no_editor_defaults,
               RSYNC_DIST_SHOW_PROGRESS => \$opt_progress,
               RSYNC_DIST_TAG => \$opt_tag,
               RSYNC_DIST_MESSAGE => \$opt_message,
               RSYNC_DIST_FILTER_OUTPUT => \$opt_filter_output,
              );

# the following datastructure is used when the config-file
# is created. It links entries in the log-file to comments
# describing the entry and is used when a config-file is created
# with show-config, write-config or write-config-from-log
my %gbl_config_comments=
              (RSYNC_DIST_HOST => "name of the remote host(s)",
               RSYNC_DIST_USER => "name of the remote user(s)",
               RSYNC_DIST_PATH => "remote distribution directory",
               RSYNC_DIST_LINKPATH =>
                                  "remote link directory",
               RSYNC_DIST_PREFIX_DISTDIR => 
                                  "prepend the distribution directory to the link-source path\n" .
                                  "(only for the commands \"add-links\" and \"change-links\")",
               RSYNC_DIST_LOCALPATH =>
                                  "local distribution directories",
               RSYNC_DIST_LOCALPREFIX =>
                                  "prefix prepended to all localpaths",           

               RSYNC_DIST_WORLDREADABLE =>
                                  "make all dirs on server world-readable",       
               RSYNC_DIST_ONE_FILESYSTEM =>
                                  "do not cross filesystem boundaries",
               RSYNC_DIST_PRESERVE_LINKS =>
                                  "copy links as they are, do not dereference them",
               RSYNC_DIST_REMOVE_LINKS =>
                                  "always remove symbolic links by dereferencing them",
               RSYNC_DIST_EXCLUDE_LIST =>
                                  "specify a file that contains files to exclude from\n" .
                                  "transfer",
               RSYNC_DIST_CHECKSUM =>
                                  "use checksum to detect file changes",
               RSYNC_DIST_BRANCH =>
                                  "use this branch for distributing files",
               RSYNC_DIST_PARTIAL =>
                                  "transfer only some files to the server",
               RSYNC_DIST_VERSION_FILE =>
                                  "name of the version-file that is created",
               RSYNC_DIST_VERSION_FILE_PREFIX =>
                                  "prefix of the version within the version-file",
               RSYNC_DIST_EDITOR =>
                                  "editor for log-messages and tags",
               RSYNC_DIST_EDITOR_NO_DEFAULTS =>
                                  "do not display defaults when the " .
                                  "editor is called",   
               RSYNC_DIST_SHOW_PROGRESS =>      
                                  "show progress of rsync on console",
               RSYNC_DIST_TAG =>
                                  "fixed tag for all distributions",
               RSYNC_DIST_MESSAGE => 
                                  "fixed log-message for dist, add-links\n" .
                                  "and change-links commands",
               RSYNC_DIST_FILTER_OUTPUT => 
                                  "boolean flag: 1 means process output to\n" .
                                  "be human readable, 0 means raw, default is 0",
              );

# the following datastructure is used when the config-file
# is created. It specifies the order in which the entries
# in the config-file are created.
my @gbl_config_order=qw(
RSYNC_DIST_HOST
RSYNC_DIST_USER
RSYNC_DIST_PATH  
RSYNC_DIST_LINKPATH
RSYNC_DIST_PREFIX_DISTDIR
RSYNC_DIST_LOCALPATH
RSYNC_DIST_LOCALPREFIX
RSYNC_DIST_WORLDREADABLE 
RSYNC_DIST_CHECKSUM
RSYNC_DIST_BRANCH 
RSYNC_DIST_PARTIAL 
RSYNC_DIST_VERSION_FILE
RSYNC_DIST_VERSION_FILE_PREFIX
RSYNC_DIST_EDITOR 
RSYNC_DIST_EDITOR_NO_DEFAULTS
RSYNC_DIST_SHOW_PROGRESS
RSYNC_DIST_TAG
RSYNC_DIST_MESSAGE
RSYNC_DIST_FILTER_OUTPUT
);


# the following datastructure lists only entries of the
# config-file that are arrays. 
my %gbl_config_types=
              (RSYNC_DIST_HOST      => 'ARRAY',
               RSYNC_DIST_USER      => 'ARRAY',
               RSYNC_DIST_LOCALPATH => 'ARRAY');

# the following hash maps directory-specifiers. With some commands,
# the user has to specify wether he operates on the "dist" directory
# or on the "links" directory. The hash keys show the strings the
# program recognizes.
my %gbl_known_dirnames= ('--dist' =>'dist', 
                         dist     =>'dist', 
                         d        =>'dist',
                         '--links'=>'links',
                         links    =>'links',
                         l        =>'links',
                        );

# this is a cache variable. The local logfile is read only once and 
# relevant data from this file is stored here
my $gbl_last_locallog_entries;

if (!@ARGV)
  { $opt_man= 1; };


preproc_args();

#die "args: " . join("|",@ARGV);

# catch things like "-ls", Getopt::Long would otherwise
# take this as "-l s" ...
foreach my $opt (@ARGV)
  { die "unknown option: $opt" if ($opt=~ /^-[^-]{2,}/); };

Getopt::Long::config(qw(no_ignore_case));

if (!GetOptions("help|h",
                "man", 
                "summary",

                "host|H=s" => \@opt_hosts,
                "user|u=s" => \@opt_users, 

                "distpath|p=s",
                "linkpath|P=s",
                "localpath|l=s" => \@opt_localpaths,
                "localprefix=s",

                "message|m:s",
                "automessage",
                "tag|t:s",
                "autotag",

                "dist|d", 
                "to_attic|to-attic:s",
                "from_attic|from-attic:s",
                "change_links|change-links|C:s",
                "add_links|add-links|A:s",
                "remove_links|remove-links:s",
                "mirror=s",
                "rm_lock|rm-lock=s",
                "force_rm_lock|force-rm-lock=s",
                "mk_lock|mk-lock=s",
                "rebuild_last|rebuild-last",
                "create_branch|create-branch=s",
                "expand_glob|expand-glob",

                "ls=s",
                "cat_log|cat-log=s",
                "tail_log|tail-log=s",
                "perl_log|perl-log=s",
                "python_log|python-log=s",
                "ls_tag|ls-tag|T=s",
                "ls_version|ls-version=s",
                "cat_changes|cat-changes:s",
                "tail_changes|tail-changes=s",

                "config|c=s",
                "show_config|show-config",
                "write_config|write-config=s",
                "show_config_from_log|show-config-from-log",
                "write_config_from_log|write-config-from-log=s",
                "env",

                "branch=s",
                "partial",
                "version_file|version-file=s",
                "version_file_prefix|version-file-prefix=s",
                "editor=s",
                "no_editor_defaults|no-editor-defaults|N!",
                "prefix_distdir|prefix-distdir!",               
                "last_dist|last-dist|L",
                "one_filesystem|one-filesystem",
                "preserve_links|preserve-links",
                "dereference_links|dereference-links",
                "exclude_list|exclude-list=s",
                "checksum",
                "progress",
                "dry_run|dry-run",
                "world_readable|world-readable|w",
                "create_missing_links|create-missing-links",
                "ssh_back_tunnel|ssh-back-tunnel=i",
                "single_host|single-host",

                "filter_output|filter-output",
# undocumented:
                "debug",
                "version",
                ))
  { die "parameter error!\n"; };

#die "pref dd: $opt_prefix_distdir";

if (@ARGV)
  { warn "warning: additional arguments ignored:\"" . 
          join(" ",@ARGV) . "\"\n"; };

if ($opt_help)
  { help();
    exit;
  };

if ($opt_man)
  { exec("perldoc $0"); };

if ($opt_version)
  { my $l1= h_center("**** $sc_name $sc_version -- $sc_summary ****");
    my $l2= h_center("$sc_author $sc_year");
    print $l1,"\n",$l2,"\n";
    exit(0);
  }    

if ($opt_summary)
  { print_summary();
    exit;
  };

@opt_hosts = split(/[,\s:]+/,join(',',@opt_hosts));

@opt_users = split(/[,\s:]+/,join(',',@opt_users));

@opt_localpaths = split(/[,\s:]+/,join(',',@opt_localpaths));

if ($opt_env)
  { read_env(\%gbl_map_hash); }

if ($opt_config)
  { read_config($opt_config); }

if (defined $opt_progress)
  { 
    $gbl_rsync_opts .= " --progress"; 
    # --progress: show progress during transfer
  };

# unconditionally read variables from the environment:
read_env(\%gbl_env_map_hash1);
read_env(\%gbl_env_map_hash2);

if (!defined $opt_editor)
  { $opt_editor= $default_editor; };

if ((defined $opt_show_config) || (defined $opt_write_config))
  { show_config($opt_write_config);
    exit(0);
  } 

if ((defined $opt_show_config_from_log) || 
    (defined $opt_write_config_from_log)) 
  { show_config_from_log($opt_write_config_from_log);
    exit(0);
  } 

if ($opt_debug)
  { $debug= $opt_debug; }

# ------------------------------------------------

if (defined $opt_ls)
  { my($arg,$rpath,$log,$chg)= dir_dependant($opt_ls);
    ls(\@opt_hosts,\@opt_users,$rpath,$opt_single_host);
    exit(0);
  }

if ((defined $opt_cat_log) || (defined $opt_perl_log) || (defined $opt_python_log))
  { my $scheme; 
    if (defined $opt_perl_log)
      { $scheme= "perl"; }; 
    if (defined $opt_python_log)
      { $scheme= "python"; }; 
    my $dirname= ($scheme) ? $opt_perl_log : $opt_cat_log;
    my($arg,$rpath,$log,$chg)= dir_dependant($dirname);

    my $rc= cat_file_(\@opt_hosts,\@opt_users,$rpath,
                                $log,undef,$scheme,$opt_single_host);
    exit($rc ? 0 : 1);
  }

if (defined $opt_cat_changes)
  { $opt_cat_changes= 'd' if ($opt_cat_changes eq "");
    my($arg,$rpath,$log,$chg)= dir_dependant($opt_cat_changes);
    my $rc= cat_file_(\@opt_hosts,\@opt_users,$rpath,$chg);
    exit($rc ? 0 : 1);
  }

if (defined $opt_tail_log)
  { my($arg,$rpath,$log,$chg)= dir_dependant($opt_tail_log);
    my $rc= cat_file_(\@opt_hosts,\@opt_users,$rpath,$log,$arg);
    exit($rc ? 0 : 1);
  }

if (defined $opt_tail_changes)
  { my($arg,$rpath,$log,$chg)= dir_dependant($opt_tail_changes);
    my $rc= cat_file_(\@opt_hosts,\@opt_users,$rpath,$chg,$arg);
    exit($rc ? 0 : 1);
  }

if (defined $opt_ls_tag)
  { my($arg,$rpath,$log,$chg)= dir_dependant('dist');
    ls_tag(\@opt_hosts,\@opt_users,$rpath,$opt_ls_tag,
           $opt_single_host);
    exit(0);
  }

if (defined $opt_ls_version)
  { my($arg,$rpath,$log,$chg)= dir_dependant('dist');
    ls_version(\@opt_hosts,\@opt_users,$rpath,$opt_ls_version,
               $opt_single_host);
    exit(0);
  }

if ((defined $opt_rm_lock) || (defined $opt_force_rm_lock))
  { my $par= (defined $opt_force_rm_lock) ? $opt_force_rm_lock : $opt_rm_lock;
    my($arg,$rpath,$log,$chg)= dir_dependant($par);
    my $rc= 
      server_lock(\@opt_hosts,\@opt_users,$rpath,
                  (defined $opt_force_rm_lock) ? 'force-remove' : 'remove');
    exit($rc ? 0 : 1);
  }

if (defined $opt_mk_lock)
  { my($arg,$rpath,$log,$chg)= dir_dependant($opt_mk_lock);
    my $rc= 
      server_lock(\@opt_hosts,\@opt_users,$rpath,'create');
    exit($rc ? 0 : 1);
  }

if (defined $opt_rebuild_last)
  { my($arg,$rpath,$log,$chg)= dir_dependant('dist');
    my $rc=
      rebuild_last(\@opt_hosts,\@opt_users,$rpath);
    exit($rc ? 0 : 1);
  }

if (defined $opt_create_branch)
  { my($arg,$rpath,$log,$chg)= dir_dependant('dist');
    my $rc=
      create_branch(\@opt_hosts,\@opt_users,$rpath,$opt_create_branch);
    exit($rc ? 0 : 1);
  }

if (defined $opt_expand_glob)
  { make_file_list($opt_localprefix,1,@opt_localpaths);
    exit(0);
  }

if ($opt_mirror)
  { my($arg,$rpath,$log,$chg)= dir_dependant($opt_mirror);
    my $rc=
      mirror(\@opt_hosts,\@opt_users,$rpath);
    exit($rc ? 0 : 1);
  }

if (defined $opt_change_links)
  { my($arg,$rpath,$log,$chg)= dir_dependant('links');
    my $link_action= $opt_create_missing_links ? do_change_or_add : do_change;
    my $rc=
      change_link($link_action, \@opt_hosts,\@opt_users,$rpath,$opt_message,$opt_change_links);
    exit($rc ? 0 : 1);
  }

if (defined $opt_add_links)
  { my($arg,$rpath,$log,$chg)= dir_dependant('links');
    my @files;
    my $source;
    my $rc=
      change_link(do_add, \@opt_hosts,\@opt_users,$rpath,$opt_message,$opt_add_links);
    exit($rc ? 0 : 1);
  }

if (defined $opt_remove_links)
  { my($arg,$rpath,$log,$chg)= dir_dependant('links');
    my @files;
    my $source;
    my $rc=
      change_link(do_remove, \@opt_hosts,\@opt_users,$rpath,$opt_message,$opt_remove_links);
    exit($rc ? 0 : 1);
  }

if (defined $opt_dist)
  { 
    my($arg,$rpath,$log,$chg)= dir_dependant('dist');
    my $rc= 
      dist(\@opt_hosts,\@opt_users,$rpath,
           $opt_localprefix, \@opt_localpaths, 
           $opt_message, $opt_tag,
           $opt_branch, 
           $opt_world_readable);
    exit($rc ? 0 : 1);
  }

if (defined $opt_to_attic)
  { my($arg,$rpath,$log,$chg)= dir_dependant('dist');
    my $rc= 
      move_file(\@opt_hosts,\@opt_users,$rpath,$opt_to_attic, $opt_message, 1);
    exit($rc ? 0 : 1);
  }

if (defined $opt_from_attic)
  { my($arg,$rpath,$log,$chg)= dir_dependant('dist');
    my $rc= 
      move_file(\@opt_hosts,\@opt_users,$rpath,$opt_from_attic, $opt_message, 0);
    exit($rc ? 0 : 1);
  }


die "error: no command given!";

# fit in program text here

# ------------------------------------------------
# commands
# ------------------------------------------------

sub dist
  { my($r_hosts,$r_users,
       $remote_path, 
       $localprefix, $r_local_paths,
       $logmessage, $tag,
       $branch,
       $world_readable)= @_;

    my $r_hosts_users= ensure_host_users($r_hosts,$r_users);

    if (empty($remote_path))
      { ensure_var(\$remote_path   , 'REMOTEPATH' ,
                   take_default('distribute:REMOTEPATH',
                                'links:REMOTEPATH',
                                'move:REMOTEPATH'));
      };

    # empty string as tag is now allowed:
    if (!defined $tag)
      { if (defined $opt_autotag)
          { $tag= incr_tag(last_tag()); }
        else
          { ensure_var(\$tag          , 'TAG' , 
                       take_default('distribute:TAG'));
          }
      };

    # empty string as logmessage is now allowed:
    if (!defined $logmessage)
      { ensure_var(\$logmessage    , 'LOGMESSAGE' , 
                   take_default('distribute:LOGMESSAGE'));
      };

    if (empty($r_local_paths))
      { ensure_var(\$r_local_paths , 'DIST_LOCALPATHS' , 
                   take_default('distribute:LOCALPATHS'));
      };

    my $filelist_file;
    my $local_paths;
    #if (has_glob(@$r_local_paths))
    if ($opt_partial)
      { 
        $filelist_file= make_file_list($localprefix,0,@$r_local_paths); 
      }
    else
      { my @p;
        if ($localprefix)
          { @p= map{ File::Spec->catfile($localprefix,$_) } @$r_local_paths; }
        else
          { @p= @$r_local_paths; }

        foreach my $l (@p)
          { if (!-e $l)
              { die "error: path \"$l\" not found"; };
          };          

        # convert relative to absolute paths based on
        # the current value of the "PWD" environment variable:
        my $pwd= $ENV{PWD};
        $local_paths= join(" ", (map { File::Spec->rel2abs($_,$pwd) } @p));
      }

    my($now,$local_host,$local_user,$from)= local_info();

    # create version-file if this is wanted
    if ($opt_version_file)
      { # create filename
        if (!File::Spec->file_name_is_absolute($opt_version_file))
          { my $pre= $localprefix;
            $pre= cwd() if (!$pre);
            $opt_version_file= File::Spec->catfile($pre,$opt_version_file);
          }
        my $str= "$opt_version_file_prefix$now\n";
        write_file($opt_version_file,\$str);
      }

    # start to create hash for local logfile:
    my $r_log= new_log_hash($now,
                            $local_host,$local_user,
                            $r_hosts_users,
                            $remote_path,
                            'distribute');

    my $rsync_opts= $gbl_rsync_opts;
    if ($opt_preserve_links && $opt_dereference_links)
      { die "ERROR: --dereference-links and --preserve-links are contradicting options"; }
    if ((!$opt_preserve_links) && (!$opt_dereference_links))
      { $rsync_opts.=  " --copy-unsafe-links"; }
    else
      { if ($opt_preserve_links)
          { $rsync_opts.= " -l"; }
        if ($opt_dereference_links)
          { $rsync_opts.= " -L"; }
      }

    # Note: -u and -c combined do a different thing, than each option
    # alone. When combined, files newer on receiver are skipped, 
    # from the then remaining list of files, files with equal 
    # checksum are skipped.
    if (!$opt_checksum)
      {
        $rsync_opts.= " -u";
        # -u: skip files that are newer on the receiver
      }
    else
      {
        $rsync_opts.= " -c";
        # -c: skip based on checksum, not mod-time & size
      }

    $rsync_opts.= " -x" if ($opt_one_filesystem);

    my $log= DIST_LOG;
    my $chg= DIST_CHANGES;

    if (!internal_server_lock($r_hosts_users,$remote_path,'create'))
      { die "ERROR: locking of the servers failed"; };

    if ($opt_exclude_list)
      { copy_file_to_server($opt_exclude_list, $r_hosts_users, $remote_path);  
        $rsync_opts.= " --exclude-from=$opt_exclude_list";
      }

    my $datestr= $now; # make dates consistent!!
    
    $r_log->{LOCALDATE}= $datestr;

    my $last= "LAST";
    if ((defined $branch) && ($branch ne ""))
      { $last.= "-$branch"; };
    
    my $rcmd= sh_handle_attic_s(0,$log,$chg) .
              sh_indent_and_join(0,
              ' && ',
              "echo $datestr > STAMP && ",
              "if test -e $last ; ",
              "then cp -a -l `cat $last` `cat STAMP`; ",
              'else mkdir `cat STAMP`; ',
              'fi ',
              ' && ');

    my $rsync_ssh_opt= "ssh -A -l $local_user";
    my $rsync_host= $local_host;
    if ($opt_ssh_back_tunnel)
      { $rsync_ssh_opt.= " -p $opt_ssh_back_tunnel";
        $rsync_host= "localhost";
      };

    if (!defined $filelist_file)     
      { $rcmd.= sh_indent_and_join(0,         
              "for l in $local_paths;",
              "do rsync $rsync_opts -e \"$rsync_ssh_opt \" \\",
              "         $rsync_host:\$l ./`cat STAMP`;",
              'done');
      }
    else
      { my $lp= File::Spec->rel2abs($localprefix);
        $rcmd.= sh_indent_and_join(0,
              "rsync $rsync_opts -e \"$rsync_ssh_opt \" \\",
              "      --files-from=:$filelist_file \\", 
              "      $rsync_host:$lp ./`cat STAMP`");         
      };

    if ($world_readable)
      { $rcmd.= sh_indent_and_join(0,
                ' && ',
                'chmod -R a+rX `cat STAMP`'); 
      };
    $rcmd.= sh_indent_and_join(0,          
              ' && ',
              "echo \"%%\" >> $log && ",
              "echo VERSION: `cat STAMP` >> $log && ",
              "echo ACTION: added >> $log && "
              );
    $rcmd.= sh_add_log_s(0,$log,$from,$logmessage,$tag, $branch);

    $rcmd.= sh_indent_and_join(0,
              ' && ',  
              "echo \"\" >> $chg && cat STAMP >> $chg && ",
              "if test -e $last;",
              "then echo CHANGED/ADDED FILES relative to `cat LAST`: >> $chg ;",
              "else echo ADDED FILES: >> $chg;",
              'fi',
              ' && ',
              "find `cat STAMP` -links 1 >> $chg && ",
              "cp STAMP $last && ",
              'sleep 1 && ');
#die $rcmd;
    $rcmd.= sh_indent_and_join(0,          
              'echo `cat STAMP` was created && ',
              'rm -f STAMP');

    my $all_rc=1;
    foreach my $r (@$r_hosts_users)
      { my($remote_host, $remote_user)= @$r;
        print "\nHost:$remote_host:\n";

         my($rc)= myssh_cmd($remote_host, $remote_user, $remote_path, 
                            $rcmd, 1);
        $all_rc&= $rc;
        if (!$rc)
          { warn "(command failed)\n"; };
      };

    if ($opt_exclude_list)
      { 
        remove_file_from_server($opt_exclude_list, $r_hosts_users, $remote_path);  
      }

    if (!internal_server_lock($r_hosts_users,$remote_path,'remove'))
      { warn "WARNING: unlocking of the servers failed"; };

    return if (!$all_rc); #error

    return 1 if ($opt_dry_run); # OK

    #print join("\n",@$r_l); 

    # update local log-file
    $r_log->{LOCALPATHS}  = join(",",@$r_local_paths);
    $r_log->{LOCALCWD}    = cwd();
    $r_log->{LOGMESSAGE}  = $logmessage;

    if ($world_readable)
      { $r_log->{WORLDREADABLE}= 1; };

    if (defined $tag)
      { $r_log->{TAG}= $tag; };

    if (defined $branch)
      { $r_log->{BRANCH}= $branch; };

    $r_log->{VERSION}= $datestr;

    append_single_log($gbl_local_log,$r_log,\@gbl_local_log_order);

    if (defined $filelist_file)
      { unlink $filelist_file; }

    return(1);
  }    

sub move_file
  { my($r_hosts,$r_users,
       $remote_path, $dir, $logmessage, $to_attic)= @_;

    my $r_hosts_users= ensure_host_users($r_hosts,$r_users);
    if (empty($remote_path))
      { ensure_var(\$remote_path, 'REMOTEPATH',
                   take_default('move:REMOTEPATH' .
                                'distribute:REMOTEPATH',
                                'links:REMOTEPATH'));
      };                           
    if (empty($dir))
      { ensure_var(\$dir        , 'MOVE_DIR'); };

    # empty log-message is now allowed:
    if (!defined $logmessage)
      { ensure_var(\$logmessage    , 'LOGMESSAGE');
      };

    my($now,$local_host,$local_user,$from)= local_info();

    # start to create hash for local logfile:
    my $r_log= new_log_hash($now,
                            $local_host,$local_user,
                            $r_hosts_users,
                            $remote_path,
                            $to_attic ? 'move to attic' :
                                        'move from attic'
                            );

    my $dest;
    my $odir= $dir;
    my $action;
    if ($to_attic)
      { $dest= 'attic'; 
        $action= "moved to attic";
      }
    else
      { $dir= 'attic/' . $dir; 
        $dest= '.'; 
        $action= "moved from attic";
      };

    my $log= DIST_LOG;
    my $chg= DIST_CHANGES;

    my $rcmd= 
                sh_handle_attic($log,$chg) .
                ' && ' .
                "grep $dir /dev/null LINKS-* 2>/dev/null; " .
                'if test $? -eq 0;' .
                "then echo \"error: $dir is still in use (symlinks)\" && ".
                     "exit $my_errcode;" .
                'fi' .
                ' && ' .
                "if ! test -d $dir;" . 
                "then echo $dir not found && " .
                     "exit $my_errcode;" . 
                'fi && ' .
                "mv $dir $dest && " . 
                "echo \"%%\" >> $log && " .
                "echo VERSION: $odir >> $log && " .
                "echo ACTION: $action >> $log && " .
                sh_add_log($log,$from,$logmessage,undef) . ' && ' .
                sh_rebuild_LAST() . ' && ' .
                'rm -f STAMP';

    # !!!NOTE: "LAST" files for branches are currently NOT rebuilt 
    # you have to do that yourself!! 

    if (!internal_server_lock($r_hosts_users,$remote_path,'create'))
      { die "ERROR: locking of the servers failed"; };

    my $all_rc=1;
    foreach my $r (@$r_hosts_users)
      { my($remote_host, $remote_user)= @$r;
        print "\nHost:$remote_host:\n"; 
        my($rc)= myssh_cmd($remote_host, $remote_user, $remote_path, $rcmd);
        $all_rc&= $rc;
        if (!$rc)
          { warn "(command failed)\n"; };
      };

    if (!internal_server_lock($r_hosts_users,$remote_path,'remove'))
      { warn "WARNING: unlocking of the servers failed"; };

    return 1 if ($opt_dry_run); # OK

    return if (!$all_rc);

    # update local log-file
    $r_log->{LOGMESSAGE} = $logmessage;
    $r_log->{VERSION}    = $odir;

    append_single_log($gbl_local_log,$r_log,\@gbl_local_log_order);
    return(1);
  }

sub change_link
  { my($link_action, $r_hosts,$r_users, $remote_path, $logmessage,
       $linkparam )= @_;

    my @files;
    my $remote_source;

    if (($opt_prefix_distdir) && (!defined $opt_distpath))
      { warn "warning: dist-path not specified, --prefix-distdir ignored\n"; 
        $opt_prefix_distdir= undef;
      };

    # read the link-parameter if it is defined
    # it should be <source-dir>,<filemask>
    if ($linkparam ne "")
      { 
        # NOTE: source-dir may contain a colon (':')
        # so we MUST NOT split the string along a colon:
        # remove leading spaces since this should not make
        # any difference
        $linkparam=~ s/^\s+//;
        @files= split(/(?:,|\s+)/,$linkparam);
        if ($#files>0) # more than one argument
          { if ($files[0] =~ /^\s*$/)
              { # first argument empty, discard it
                shift @files; 
              }
            else
              { # it may be a remote_source or a file. When 
                # --prefix-distdir and --last-dist were given,
                # we assume that it is a file since the remote_source
                # in this case is already completely defined

                if (!(($opt_prefix_distdir) && ($opt_last_dist)))
                  { # take first argument as remote_source
                    if ($link_action != do_remove)
                      { $remote_source= shift @files; }
                  };
              };
          };
      }

    my $r_hosts_users= ensure_host_users($r_hosts,$r_users);

    if (empty($remote_path))
      { ensure_var(\$remote_path   , 'REMOTEPATH' ,
                   take_default('distribute:REMOTEPATH',
                                'links:REMOTEPATH',
                                'move:REMOTEPATH'));
      };

    my $r_files= \@files;
    if (empty($r_files))
      { ensure_var($r_files      , 'FILEMASK' ,
                   take_default('links:FILES'));
      };

        
    # if $remote_source is not defined and --last-dist is given:
    if ($opt_last_dist)
      { my $lastver= last_ver($r_hosts,$opt_distpath);
        if (empty($lastver))
          { die "error: no last dist-version for hosts " . 
                join(",",@$r_hosts) . " and path $opt_distpath\n";
          }     

        if (empty($remote_source))
          { $remote_source= $lastver; }
      }

    if (($opt_prefix_distdir) && (!empty($remote_source)))
      { # prepend distpath to remote_source:
        $remote_source= File::Spec->catfile($opt_distpath,$remote_source); 
      };   



    if (($link_action != do_remove) && (empty($remote_source)))
      { ensure_var(\$remote_source  , 'SOURCE_DIR' ,
                   take_default('links:SOURCEDIR'));
      };

    $remote_source=~ /\/$/; # remove trailing "/"         


    # new: empty string as logmessage is allowed:
    if (!defined $logmessage)
      { my $take_from_user= 1;
        if (defined $opt_automessage)
          { if (!defined $opt_last_dist)
              { warn "warning: --automessage is without effect when " .
                     "--last-dist is not used...\n"; 
              }
            else
              { my $last_tag= last_tag();
                if (!empty($last_tag))
                  { $logmessage= "link to $last_tag"; 
                    $take_from_user=0; 
                  }; 
              };
          }
        if ($take_from_user)
          { ensure_var(\$logmessage    , 'LOGMESSAGE' , 
                       take_default('links:LOGMESSAGE'));
          };
      };

    my($now,$local_host,$local_user,$from)= local_info();

    # start to create hash for local logfile:
    my $action_name= ($link_action == do_add)    ? 'add links' :
                     ($link_action == do_change) ? 'change links' :
                     ($link_action == do_remove) ? 'remove links' :
                                                   'change or add links';
    my $r_log= new_log_hash($now,
                            $local_host,$local_user,
                            $r_hosts_users,
                            $remote_path,
                            $action_name);

    my $log= LINK_LOG;

    my $files= join(" ",@$r_files);
    my $rcmd= 
              "if ! test -e $remote_source; " .
              "then echo error: \"$remote_source does not exist\" && " .
                    "exit $my_errcode; " .
              'fi && ' .
              sh_handle_attic($log);

    if ($link_action==do_add)
      { $rcmd.= ' && ' . sh_must_all_not_exist(@$r_files)  . ' && ';
      }
    elsif ($link_action==do_change)
      { $rcmd.= ' && ' . sh_must_all_be_symlinks(@$r_files) . ' && ' .
                '/bin/ls -l ' . $files;
        $rcmd.= ' > OLD && ' 
      }
    elsif ($link_action==do_remove)
      { $rcmd.= ' && ' . sh_must_all_be_symlinks(@$r_files) . ' && ' .
                '/bin/ls -l ' . $files;
        $rcmd.= ' > REMOVED && ' 
      }
    elsif ($link_action==do_change_or_add)
      { $rcmd.= " && ".
                "for l in $files ; do " .
                  'if test -e $l; ' .
                  'then /bin/ls -l $l >> OLD; echo $l >> CHANGED; ' .
                  'else echo $l >> ADDED; ' .
                  'fi; ';
        $rcmd.= 'done && ';
      };

    # determine where to place the linklog-file:
    my $source_base= (File::Spec->splitpath($remote_source))[1];

    if ($source_base eq "")
      { # was a directory relative to remote user's home
        $source_base= '$HOME';
      };

    my $path_conv= $remote_path;
    $path_conv=~ s/\//-/g; # replace "/" with "-"

    my $linklog= File::Spec->catfile($source_base,"LINKS" . $path_conv); 

    if (!internal_server_lock($r_hosts_users,$remote_path,'create'))
      { die "ERROR: locking of the servers failed"; };

    my $datestr= datestring();
    $r_log->{LOCALDATE}= $datestr;

#die "linklog:$linklog";

    $rcmd.=     
                "for l in $files ; " .
                'do rm -f $l '; 
    if ($link_action!=do_remove)
      { $rcmd.= '&& ' . "ln -s $remote_source \$l "; }
    $rcmd.=     
                ';done && ' .
                "echo \"%%\" >> $log && " .
                "echo DATE: $datestr >> $log && " .
                sh_add_log($log,$from,$logmessage,undef) . ' && ' .
                sh_add_symlink_log($log,$link_action,@$r_files) . ' && ' .
                'find . -type l -printf "%l %f\n" ' .
                "| sort | grep \"^$source_base\" | sed -e \"s/^.*\\///\" " .
                "> $linklog " ;

    my $all_rc=1;
    foreach my $r (@$r_hosts_users)
      { my($remote_host, $remote_user)= @$r;
        print "\nHost:$remote_host:\n";
        my($rc,$r_lines)= myssh_cmd(
          $remote_host, $remote_user, $remote_path, $rcmd, 1, 1);
        print maybe_filter_output($r_lines);
        $all_rc&= $rc;
        if (!$rc)
          { warn "(command failed)\n"; };
      };

    if (!internal_server_lock($r_hosts_users,$remote_path,'remove'))
      { warn "WARNING: unlocking of the servers failed"; };

    return 1 if ($opt_dry_run); # OK

    return if (!$all_rc);

    $r_log->{FILES}       = join(",",@$r_files);
    $r_log->{LOGMESSAGE}  = $logmessage;
    $r_log->{SOURCEDIR}   = $remote_source;

    append_single_log($gbl_local_log,$r_log,\@gbl_local_log_order);
    return(1);
  }

sub cat_file_
  { my($r_hosts,$r_users,
       $remote_path, $filename, $tailpar, $scheme, $single_host) = @_;
    # known values for $scheme: undef,"perl","python"

    my $r_hosts_users= ensure_host_users($r_hosts,$r_users);
    if (empty($remote_path))
      { ensure_var(\$remote_path, 'REMOTEPATH',
                   take_default('distribute:REMOTEPATH',
                                'links:REMOTEPATH'));
      };                           

    my $rcmd;
    if (!defined $tailpar)
      { $rcmd= "cat $filename"; }
    else
      { if ($tailpar<=0)
          { $tailpar= 10; };
        $rcmd= "tail -n $tailpar $filename";
      };

    my $all_rc=1;
    if ($single_host)
      { my @myhosts= ($r_hosts_users->[0]);
        $r_hosts_users= \@myhosts;
      };
    foreach my $r (@$r_hosts_users)
      { my($remote_host, $remote_user)= @$r;
        print "\nHost:$remote_host:\n" if (!$single_host);

        my($rc,$r_lines)= myssh_cmd($remote_host, $remote_user, $remote_path, 
                                    $rcmd, 1, 1);

       $all_rc&= $rc;
        if (!$rc)
          { warn "(command failed)\n"; 
            next;
          };
        if (($scheme eq "perl") || ($scheme eq "python"))
          { 
            my $r_h= maillike::parse($r_lines,recordseparator=>"%%");
            my $name= $filename;
            $name=~ s/-/_/g;
            if ($scheme eq "perl")
              { print Data::Dumper->Dump([$r_h],[$name]); }
            else
              { my $st= Data::Dumper->Dump([$r_h],[$name]); 
                $st=~ s/\$LOG_LINKS\s*=\s*//;
                $st=~ s/=>/:/g;
                $st=~ s/'/"""/g;
                $st=~ s/;\s*$//;
                print $st;
              }
          }
        else
          { 
            foreach my $l (@$r_lines)
              { print $l,"\n"; };
          };
      };
    return($all_rc);
  }

sub ls
  { my($r_hosts,$r_users,
       $remote_path, $single_host) = @_;

    my $r_hosts_users= ensure_host_users($r_hosts,$r_users);
    if (empty($remote_path))
      { ensure_var(\$remote_path, 'REMOTEPATH',
                   take_default('distribute:REMOTEPATH',
                                'links:REMOTEPATH'));
      };                           

    my $rcmd= "/bin/ls -l";

    my $all_rc=1;
    if ($single_host)
      { my @myhosts= ($r_hosts_users->[0]);
        $r_hosts_users= \@myhosts;
      };
    foreach my $r (@$r_hosts_users)
      { my($remote_host, $remote_user)= @$r;
        print "\nHost:$remote_host:\n" if (!$single_host);
        my($rc,$r_lines)= myssh_cmd(
          $remote_host, $remote_user, $remote_path, $rcmd, 1, 1);
        print maybe_filter_output($r_lines);
       $all_rc&= $rc;
       if (!$rc)
          { warn "(command failed)\n"; };
      };
    return($all_rc);
  }

sub copy_file_to_server
  { my($filename, $r_hosts_users, $remote_path)= @_;

    foreach my $r (@$r_hosts_users)
      { my($remote_host, $remote_user)= @$r;
        myscp($remote_host, $remote_user, $filename, $remote_path, 0, 0);
      }
  }

sub remove_file_from_server
  { my($filename, $r_hosts_users, $remote_path)= @_;

    # basically basename($filename):
    $filename= (File::Spec->splitpath($filename))[-1];
    foreach my $r (@$r_hosts_users)
      { my($remote_host, $remote_user)= @$r;
        my $cmd= "rm -f $filename";
        myssh_cmd($remote_host, $remote_user, $remote_path, $cmd, 0, 0); 
      }
  }

sub server_lock
  { my($r_hosts,$r_users,
       $remote_path, $action) = @_;

    my $r_hosts_users= ensure_host_users($r_hosts,$r_users);
    if (empty($remote_path))
      { ensure_var(\$remote_path, 'REMOTEPATH',
                   take_default('distribute:REMOTEPATH',
                                'links:REMOTEPATH'));
      };                           
    return(internal_server_lock($r_hosts_users,
                                $remote_path, $action));
  }

sub internal_server_lock
# action: 'create', 'remove' or 'force-remove'
  { my($r_hosts_users,
       $remote_path, $action, $recursion) = @_;


    my($now,$local_host,$local_user,$from)= local_info();
   # start to create hash for local logfile:
    my $r_log= new_log_hash($now,
                            $local_host,$local_user,
                            $r_hosts_users,
                            $remote_path,
                            "$action lockfile");

    my $rcmd;

    if    ($action eq 'force-remove')
      { my $from= $local_user . '@' . $local_host;
        $rcmd= sh_rmlock_s(0,$from,1);
      }
    elsif ($action eq 'remove')
      { my $from= $local_user . '@' . $local_host;
        $rcmd= sh_rmlock_s(0,$from);
      }
    elsif ($action eq 'create')
      { 
        my $from= $local_user . '@' . $local_host;
        $rcmd= sh_mklock_s(0,$from)
      }
    else
      { die "assertion: unknown action: \"$action\""; };

    my @locked;
    foreach my $r (@$r_hosts_users)
      { my($remote_host, $remote_user, $remote_mpath)= @$r;
        print "\nHost:$remote_host:\n";

        if ($recursion)
          { warn "trying to $action lock on $remote_host...\n"; };

        my($rc)= myssh_cmd($remote_host,
                           $remote_user, 
                           (defined $remote_mpath)?$remote_mpath:$remote_path, 
                           $rcmd);

        if (!$rc)
          { warn "error: locking on \"$remote_host\" path \"$remote_path\"" .
                 "failed\n";
            if ($recursion)
              { warn "undoing failed, giving up...\n";
                return(0);
              };
            warn "trying to undo what already has been done...\n";
            internal_server_lock(\@locked,$remote_path, 
                                 ($action eq 'create') ? 'remove' : 'create', 
                                1);
            return(0);
          }
        else
          { push @locked, $r; };
      }; 
    return 1 if ($opt_dry_run); # OK

    append_single_log($gbl_local_log,$r_log,\@gbl_local_log_order);
    return(1);
  }

sub rebuild_last
  { my($r_hosts,$r_users,
       $remote_path) = @_;

    my $r_hosts_users= ensure_host_users($r_hosts,$r_users);
    if (empty($remote_path))
      { ensure_var(\$remote_path, 'REMOTEPATH',
                   take_default('distribute:REMOTEPATH',
                                'links:REMOTEPATH'));
      };                           

    my($now,$local_host,$local_user,$from)= local_info();

    # start to create hash for local logfile:
    my $r_log= new_log_hash($now,
                            $local_host,$local_user,
                            $r_hosts_users,
                            $remote_path,
                            'rebuild LAST');

    my $rcmd= sh_rebuild_LAST();

    if (!internal_server_lock($r_hosts_users,$remote_path,'create'))
      { die "ERROR: locking of the servers failed"; };

    my $all_rc=1;
    foreach my $r (@$r_hosts_users)
      { my($remote_host, $remote_user)= @$r;
        print "\nHost:$remote_host:\n";
        my($rc)= myssh_cmd($remote_host, $remote_user, $remote_path, $rcmd);
        $all_rc&= $rc;
        if (!$rc)
           { warn "(command failed)\n"; };
      };

    if (!internal_server_lock($r_hosts_users,$remote_path,'remove'))
      { warn "WARNING: unlocking of the servers failed"; };

    return 1 if ($opt_dry_run); # OK

    append_single_log($gbl_local_log,$r_log,\@gbl_local_log_order);
    return($all_rc);
  }

sub create_branch
  { my($r_hosts,$r_users,
       $remote_path, $param) = @_;

    my ($to_br,$from_br)= split(/,/,$param);
    if ((!defined $to_br) || ($to_br=~/^\s*$/))
      { die "\"to\" parameter is invalid: \"$to_br\";"; };
      
    
    my $r_hosts_users= ensure_host_users($r_hosts,$r_users);
    if (empty($remote_path))
      { ensure_var(\$remote_path, 'REMOTEPATH',
                   take_default('distribute:REMOTEPATH',
                                'links:REMOTEPATH'));
      };                           

    my($now,$local_host,$local_user,$from)= local_info();

    # start to create hash for local logfile:
    my $from_pr= (defined $from_br) ? $from_br : "trunk";
    my $r_log= new_log_hash($now,
                            $local_host,$local_user,
                            $r_hosts_users,
                            $remote_path,
                            'create branch $to from $from_pr');

    my $rcmd= sh_create_branch($to_br, $from_br);

    if (!internal_server_lock($r_hosts_users,$remote_path,'create'))
      { die "ERROR: locking of the servers failed"; };

    my $all_rc=1;
    foreach my $r (@$r_hosts_users)
      { my($remote_host, $remote_user)= @$r;
        print "\nHost:$remote_host:\n";
        my($rc)= myssh_cmd($remote_host, $remote_user, $remote_path, $rcmd);
        $all_rc&= $rc;
        if (!$rc)
           { warn "(command failed)\n"; };
      };

    if (!internal_server_lock($r_hosts_users,$remote_path,'remove'))
      { warn "WARNING: unlocking of the servers failed"; };

    return 1 if ($opt_dry_run); # OK

    append_single_log($gbl_local_log,$r_log,\@gbl_local_log_order);
    return($all_rc);
  }


sub mirror
  { my($r_hosts,$r_users,$remote_path)= @_;

    my $r_hosts_users= ensure_host_users($r_hosts,$r_users);
    if (empty($remote_path))
      { ensure_var(\$remote_path, 'REMOTEPATH',
                   take_default('distribute:REMOTEPATH',
                                'links:REMOTEPATH'));
      };

    if ($#$r_hosts_users <=0)
      { die "error: you have to specify at least two servers for this\n"; };  

    my($now,$local_host,$local_user,$from)= local_info();

    # start to create hash for local logfile:
    my $r_log= new_log_hash($now,
                            $local_host,$local_user,
                            $r_hosts_users,
                            $remote_path,
                            'mirror');

    my $remote_host= $r_hosts_users->[0]->[0];
    my $remote_user= $r_hosts_users->[0]->[1];
    my @m_hosts;
    my @m_users;
    my @m_paths;
    for(my $i=1; $i<=$#$r_hosts_users; $i++)
      { push @m_hosts, $r_hosts_users->[$i]->[0]; 
        push @m_users, $r_hosts_users->[$i]->[1]; 
        push @m_paths, $r_hosts_users->[$i]->[2]; 
      };

    my $rcmd= sh_copy_to_hosts_s(0,$remote_path,
                                 \@m_hosts,\@m_users,\@m_paths);

    #die "hosts:". join("|",@m_hosts);

    if (!internal_server_lock($r_hosts_users,$remote_path,'create'))
      { die "ERROR: locking of the servers failed"; };

    my($rc)= myssh_cmd($remote_host, $remote_user, $remote_path, $rcmd);

    if (!internal_server_lock($r_hosts_users,$remote_path,'remove'))
      { warn "WARNING: unlocking of the servers failed"; };

    return if (!$rc);

    return 1 if ($opt_dry_run); # OK

    $r_log->{MIRRORHOSTS}= join(" ",@m_hosts);

    append_single_log($gbl_local_log,$r_log,\@gbl_local_log_order);
    return(1);
  }

sub ls_version
  { my($r_hosts,$r_users,
       $remote_path, $version, $single_host) = @_;

    my $r_hosts_users= ensure_host_users($r_hosts,$r_users);
    if (empty($remote_path))
      { ensure_var(\$remote_path, 'REMOTEPATH',
                   take_default('distribute:REMOTEPATH',
                                'links:REMOTEPATH'));
      };                           

    die "version missing" if (empty($version));

    my $log= DIST_LOG;

    my $rcmd= "if ! test -e $log; then ".
                "echo file $log not found ;" .
              'else ' .
                "tr \"\\n\" \"\\r\" < $log | " .
                "sed -e \"s/%%\\r/%%\\n/g\" | " .
                "grep \"VERSION: $version\" | " .
                "tr \"\\r\" \"\\n\"; " . 
                'if test $? -eq 1; ' .
                'then echo not found;' .
                'fi; ' .
              'fi';

    my $all_rc=1;
    if ($single_host)
      { my @myhosts= ($r_hosts_users->[0]);
        $r_hosts_users= \@myhosts;
      };
    foreach my $r (@$r_hosts_users)
      { my($remote_host, $remote_user)= @$r;
        print "\nHost:$remote_host:\n" if (!$single_host);
        my($rc)= myssh_cmd($remote_host, $remote_user, $remote_path, $rcmd);
        $all_rc&= $rc;
        if (!$rc)
          { warn "(command failed)\n"; };
      };
    return($all_rc);
  }

sub ls_tag
  { my($r_hosts,$r_users,
       $remote_path, $tag, $single_host) = @_;

    my $r_hosts_users= ensure_host_users($r_hosts,$r_users);
    if (empty($remote_path))
      { ensure_var(\$remote_path, 'REMOTEPATH',
                   take_default('distribute:REMOTEPATH',
                                'links:REMOTEPATH'));
      };                           

    die "tag missing" if (empty($tag));

    my $log= DIST_LOG;

    my $rcmd= "if ! test -e $log; then ".
                "echo file $log not found ;" .
              'else ' .
                "tr \"\\n\" \"\\r\" < $log | " .
                "sed -e \"s/%%\\r/%%\\n/g\" | " .
                "grep \"TAG: $tag\" | " .
                "tr \"\\r\" \"\\n\"; " . 
                'if test $? -eq 1; ' .
                'then echo not found;' .
                'fi; ' .
              'fi';

    my $all_rc=1;
    if ($single_host)
      { my @myhosts= ($r_hosts_users->[0]);
        $r_hosts_users= \@myhosts;
      };
    foreach my $r (@$r_hosts_users)
      { my($remote_host, $remote_user)= @$r;
        print "\nHost:$remote_host:\n" if (!$single_host);
        my($rc)= myssh_cmd($remote_host, $remote_user, $remote_path, $rcmd);
        $all_rc&= $rc;
        if (!$rc)
          { warn "(command failed)\n"; };
      };
    return($all_rc);
  }


# ------------------------------------------------
# ssh shell command snipplets
# ------------------------------------------------

sub sh_indent_and_join
# indents lines and joins them to a single 
# string
# NOTE: a CR/LF is added at line-ends
  { my($indent)= shift;
    my $s= " " x $indent;

    return($s . join("\n$s",@_) . "\n");
  }

sub sh_backwards_compatible
  { my $str= join(" ",@_);
    $str=~ s/ +/ /g;
    return($str);
  }

sub sh_copy_to_hosts_l
# hosts may contain a path-prefix like in "myhost:/opt/OPI"
# otherwise $remote_path is taken as path-prefix
  { my($remote_path,$r_hosts,$r_users,$r_paths)= @_;
    my @lines;

    for(my $i=0; $i<=$#$r_hosts; $i++)
      { my $hostpart= $r_hosts->[$i];
        my $dir= $r_paths->[$i];
        $dir= $remote_path if (!defined $dir);
        $hostpart.= ":$dir";
        my $userpart;
        if (defined $r_users->[$i])
          { $userpart= "-l $r_users->[$i] "; }

        push @lines,
             "rsync $gbl_rsync_opts -c -H -e \"ssh $userpart\" . $hostpart;";
        # -c: skip based on checksum, not mod-time & size
        # -H: preserve hard links
        # -e: specify remote shell to use
      }
    return(@lines);
  }   

sub sh_copy_to_hosts_s
  { my($indent)= shift;
    return(sh_indent_and_join($indent,sh_copy_to_hosts_l(@_))); 
  }

sub sh_add_log_l
  { my($logfile,$from,$message,$tag, $branch)= @_;
    my @lines;

    push @lines, "echo FROM: $from >> $logfile";
    if (defined $branch)
      { push @lines,
             ' && ',
             "echo \"BRANCH: $branch\" >> $logfile";
      };       
    
    if (defined $tag)
      { push @lines,
             ' && ',
             "echo \"TAG: $tag\" >> $logfile";
      };       
    if (defined $message)
      { push @lines,
             ' && ',
             'echo LOG: "' . shell_single_quote_escape($message) .
             "\" >> $logfile"; 
      };
    return(@lines);
  }  

sub sh_add_log_s
  { my($indent)= shift;
    return(sh_indent_and_join($indent,sh_add_log_l(@_))); 
  }

sub sh_add_log
  { return(sh_backwards_compatible(sh_add_log_l(@_))); }


sub sh_rmlock_l
  { my($from,$force)=@_;

    my @lines= ("ls -l LOCK | grep $from >/dev/null 2>&1;",
                'if test $? -eq 0; ',
                "then rm -f LOCK; ");

    if (!$force)
      { push @lines,
                "else echo \"LOCK cannot be removed:\" " .
                    "`ls -l LOCK| sed -e \"s/.*-> //\"`;";
      }
    else
      { push @lines,
                "else echo \"warning: removing lock by:\" " .
                    "`ls -l LOCK| sed -e \"s/.*-> //\"`;",
                "     rm -f LOCK; ";
      };
    push @lines,
                "fi";

    return(@lines);           
  }

sub sh_rmlock_s
  { my($indent)= shift;
    return(sh_indent_and_join($indent,sh_rmlock_l(@_))); 
  }

sub sh_rmlock
  { return(sh_backwards_compatible(sh_rmlock_l(@_))); }

sub sh_mklock_l
  { my($from)=@_;

    my $showlock= '/bin/ls -l LOCK';
       $showlock.= ' | sed -e "s/.*-> //"';

    return("ln -s $from LOCK; ",
           'if [ $? -ne 0 ]; ',
           'then echo LOCKED by `' . $showlock . '`; ',
           "     exit $my_errcode; ",
           'fi');
  }        

sub sh_mklock_s
  { my($indent)= shift;
    return(sh_indent_and_join($indent,sh_mklock_l(@_))); 
  }

sub sh_mklock
  { return(sh_backwards_compatible(sh_mklock_l(@_))); }


sub sh_handle_attic_l
  { my(@files)= @_;
    my $files= join(" ",@files);

    return( 'if ! test -d attic;',
            'then mkdir attic; ',
            'fi',
            ' && ',
            "cp $files attic 2>/dev/null; true"
            );
  }         

sub sh_handle_attic_s
  { my($indent)= shift;
    return(sh_indent_and_join($indent,sh_handle_attic_l(@_))); 
  }

sub sh_handle_attic
  { return(sh_backwards_compatible(sh_handle_attic_l(@_))); }

sub sh_must_all_be_symlinks
  { my(@files)= @_;

    my $files= join(" ",@files);

    return( "for l in $files; " .
              'do if ! test -h $l; ' .
                  'then echo error: $l does not exist or is not a symlink && ' .
                  "exit $my_errcode; " .
                  'fi; ' .
              'done' ); 
  }

sub sh_must_all_not_exist
  { my(@files)= @_;

    my $files= join(" ",@files);

    return( "for l in $files; " .
               'do if test -e $l; ' .
                  'then echo error: $l already exists && ' .
                  "exit $my_errcode; " .
                  'fi; ' .
               'done' ); 
  }

sub sh_add_symlink_log
  { my($log,$link_action,@files)= @_;

    my $files= join(" ",@files);

    my $str;
    if ($link_action==do_change_or_add)
      { $str= "if test -f ADDED; then echo \"ADDED:\" >> $log && " .
              "/bin/ls -l `cat ADDED` | tee -a $log && rm -f ADDED; fi && " .
              "if test -f OLD; then echo \"OLD:\" >> $log && " .
              "cat OLD >> $log && rm -f OLD; fi && " .
              "if test -f CHANGED; then echo \"NEW:\" >> $log && " .
              "/bin/ls -l `cat CHANGED` | tee -a $log && rm -f CHANGED; fi ";
      }
    elsif ($link_action==do_remove)
      { $str= "echo \"REMOVED:\" >> $log && " .
              "cat REMOVED >> $log && rm -f REMOVED ";
      }
    else
      { if ($link_action==do_add)
          { $str= "echo \"ADDED:\" >> $log && ";
          }
        elsif ($link_action==do_change)
          { $str= "echo \"OLD:\" >> $log && " .
                  "cat OLD >> $log && rm -f OLD && " .
                  "echo \"NEW:\" >> $log && ";     
          }
        $str.= '/bin/ls -l ' . $files;
        $str.= ' | tee -a ' . $log;
      }
    return($str);
  }    

sub sh_rebuild_LAST
  { my $str= '/bin/ls --indicator-style=none -d [12]* ';
    $str.= ' | sort | tail -n 1 > LAST';
    return($str);
  }

sub sh_create_branch
  { my($to,$from)= @_;
    my $src= "LAST";
    my $dest;
    if (defined $from)
      { $src.= "-$from"; };
      
    if (!defined $to)
      { die "assertion"; };
    $dest= "LAST-$to";  
  
    my $str= "cp $src $dest";
    return($str);
  }

# ------------------------------------------------
# local logfile utilities
# ------------------------------------------------

sub read_locallog
# read the local logfile
# and return a hash
  { return if (!-e $gbl_local_log);

    my $r_h= maillike::parse($gbl_local_log,recordseparator=>"%%");

    return($r_h);
  }

sub get_last_log_entries
# build a collection(hash) of all the last l
# local-log entries of one type
  { my($rr_h)= @_;

    return if (defined($$rr_h));

    my %h; 

    my $r_a= read_locallog();

    if (!defined $r_a)
      { return };

    foreach my $entry (@$r_a)
      { my $action= $entry->{ACTION};
        if (!defined $action)
          { warn "assertion"; next; };
        $h{$action}= $entry;

        if ($action eq 'distribute')
          { # store more for "dist" actions:
            my $date= $entry->{LOCALDATE};
            
            my $hosts= $entry->{REMOTEHOSTS};
            my $path = $entry->{REMOTEPATH};
            $hosts=~ s/^\s*(\S+)\s*$/$1/; 
            # use a sorted list of hosts:
            $hosts= join(",",sort(split(",",$hosts)));
            $path =~ s/^\s*(\S+)\s*$/$1/; 
            $h{join("|",$action,$path,$hosts)}= $entry;
          }; 
        # by the following lines we can collect
        # "similar actions" under a single action-label
        # see also the definition of %gbl_local_log_actionmap
        $action= $gbl_local_log_actionmap{$action};
        if (defined $action)
          { $h{$action}= $entry; };

      };

    $$rr_h= \%h;
  }      

sub last_ver
# searches for the last distributed version
# with the given combination of hosts and remote-path.
# returns only distributions that are not older than 24 hours.
  { my($r_hosts,$path)= @_;
    my $key;

    # take the last distributed version from the
    # local log-file

    get_last_log_entries(\$gbl_last_locallog_entries);

    if (!defined $gbl_last_locallog_entries)
      { die "error: local log-file \"$gbl_local_log\" not found\n" .
            "or no last distribution info found in this file";
      };

    if (!defined $r_hosts)
      { $key= 'distribute'; }
    else
      { # handle the form "user@hostname", extract
        # just the hosts:
        my @h;
        foreach my $h (@$r_hosts)
          { if ($h=~ /^[^\@]*\@(.*)$/)
              { push @h, $1; }
            else
              { push @h, $h; };
          }; 
        my $hosts= join(",",sort(@h));
        $path =~ s/^\s*(\S+)\s*$/$1/; 
        # remove a trailing slash in the path:
        $path =~ s/\/$//;
        $key= join("|","distribute",$path,$hosts);
      };

    return($gbl_last_locallog_entries->{$key}->{VERSION});
  }    

sub last_tag
  { # take the last distributed version from the
    # local log-file

    get_last_log_entries(\$gbl_last_locallog_entries);

    if (!defined $gbl_last_locallog_entries)
      { die "error: local log-file \"$gbl_local_log\" not found\n" .
            "or no last distribution info found in this file";
      };

    return($gbl_last_locallog_entries->{distribute}->{TAG});
  }    

sub show_config_from_log
  { my($filename)= @_;

    my %extracted;
    my %log_map= ( '1:distribute:REMOTEHOSTS' => 'RSYNC_DIST_HOST',
                   '2:distribute:REMOTEHOST'  => 'RSYNC_DIST_HOST',
                   '3:distribute:REMOTEUSERS' => 'RSYNC_DIST_USER',
                   '4:distribute:REMOTEUSER'  => 'RSYNC_DIST_USER',
                   '5:distribute:REMOTEPATH'  => 'RSYNC_DIST_PATH',
                   '6:links:REMOTEPATH'       => 'RSYNC_DIST_LINKPATH');
    my %array_type= (RSYNC_DIST_HOST=>1,RSYNC_DIST_USER=>1);


    get_last_log_entries(\$gbl_last_locallog_entries);
    return if (!defined $gbl_last_locallog_entries);

    foreach my $key (keys %log_map)
      { my($no,$action,$tag)= split(/:/,$key);
        my $entry= $gbl_last_locallog_entries->{$action};
        next if (!defined $entry);
        my $val= $entry->{$tag};
        next if (!defined $val);
        my $config_tag= $log_map{$key};
        if (exists $array_type{$config_tag})
          { my @a= split(/[\s,\n]+/,$val);
            $val= \@a;
          };
        next if (exists $extracted{$config_tag});
        $extracted{$config_tag}= $val;
      };
    container::Import(\%gbl_map_hash,\%extracted,
                      overwrite=>1, 
                      skip_empty=> 1);
    my $var;
    simpleconf::create(\$var,\%extracted,
                       lineseparator=>"\n\n",
                       comments=>\%gbl_config_comments,
                       order=> \@gbl_config_order
                      );
    $var.= "\n";
    if (defined $filename)
      { rename_to_bak($filename);
        write_file($filename,\$var);
      }
    else
      { print $var; };
  }

sub prepare_val
  { my($r_ref, $scalar_tag, $array_tag)=@_;
    my $val;

    my $ref= ref($r_ref);
    my $tag= $scalar_tag;
    if    ($ref eq '')
      { $val= $r_ref; }
    elsif ($ref eq 'SCALAR')
      { $val= $$r_ref; }
    elsif ($ref eq 'ARRAY')
      { $val= join(",",@$r_ref);
        $tag= $array_tag;
      };
    return($val,$tag);
  }     

sub new_log_hash
# creates a hash for later usage with append_single_log().
# the hash is filled with these fields:
# LOCALDATE,LOCALHOST,REMOTEUSER,ACTION,
# REMOTEHOST or REMOTEHOSTS and
# REMOTEPATH
# NOTE: $remote_users is usually an array reference
  { my($now,
       $local_host,$local_user,
       $r_hosts_users,
       $remote_path,
       $action)= @_;

    my @remote_hosts;
    my @remote_users;
    my @remote_mpaths;
    my $mpath_found;
    foreach my $r (@$r_hosts_users)
      { push @remote_hosts , $r->[0];
        push @remote_users , $r->[1]; 
        push @remote_mpaths, $r->[2];
        $mpath_found|= defined($r->[2]);
      };

    my($rhosts,$rhosts_tag)= prepare_val(\@remote_hosts,
                                         'REMOTEHOST','REMOTEHOSTS');
    my($rusers,$rusers_tag)= prepare_val(\@remote_users,
                                         'REMOTEUSER','REMOTEUSERS');

    my %h= (LOCALDATE=> $now,
            LOCALHOST=>$local_host,
            ACTION=> $action,
            $rhosts_tag=> $rhosts,
            $rusers_tag=> $rusers,
            REMOTEPATH=> $remote_path,
            );

    if ($mpath_found)
      { my($rmpaths,$mpaths_tag)= prepare_val(\@remote_mpaths,
                                              'REMOTE_MPATH','REMOTE_MPATHS');
        $h{$mpaths_tag}= $rmpaths;
      }

    return(\%h);
  }           

sub append_single_log
# append a single entry to a logfile. The Entry
# is given as a hash-reference. The field-order is given
# as a list-reference
  { my($logfile,$r_log_hash,$r_order)= @_;

    if (!-e $logfile)
      { warn "creating \"$logfile\"...\n";
      };
    maillike::create($logfile,[$r_log_hash],
                     mode=> '>>', order=> $r_order,
                     recordseparator=>"%%");
  }


# ------------------------------------------------
# file utilities
# ------------------------------------------------

sub write_file
  { my($filename,$r_var)= @_;
    local(*F);
    open(F,">$filename") or die "unable to create \"$filename\"";
    print F $$r_var;
    close(F);
  }

sub to_file
  { my($filename, $r_lines)= @_;
    local(*F);
    if (!open(F, ">$filename"))
      { warn "error: file $filename couldn't be created\n" . 
             "this would have been written into this file:\n" .
             join("\n",@$r_lines) . "\n";
        return;
      };
    foreach my $l (@$r_lines)
      { print F $l,"\n"; };
    close(F);
  }

sub rename_to_bak
  { my($filename)= @_;

    my $file= $filename;
    my $ext= ".bak";
    my $no;

    return if (!-e $filename);
    while (-e ($file . $ext))
      { $ext= sprintf ".bak%d",(++$no); };
    if (!rename($filename, $file . $ext))
      { die "error: renaming $file to $file$ext failed"; };
  }

sub filetime
  { my($path)= @_;
    my $time;

    my ($volume,$directories,$file) = File::Spec->splitpath( $path ); 
    my $oldpwd= cwd();

    chdir($directories) or die "unable to chdir to \"$directories\"";
    $time= (stat($file))[9];
    chdir($oldpwd) or die "unable to chdir to \"$oldpwd\""; 
    return($time);
  }

sub make_file_list
# create a list of files and return the
# name of the created temporary file
  { my($start_dir,$just_dump,@patterns)= @_;
    my $old= cwd();

    # treat a start_dir that is an empty string
    # like an undefined start_dir, this means that the 
    # base for the file-list to build is the current dir
    if ($start_dir=~ /^\s*$/)
      { $start_dir= undef; };

    if (defined $start_dir)
      { chdir($start_dir) or die "unable to chdir to \"$start_dir\"\n"; };

    my $r_files= extended_glob::fglob(@patterns);

    if ($#$r_files<0)
      { die "no files found for transfer\n"; };

    if (defined $start_dir)
      { chdir($old) or die "unable to chdir to \"$old\"\n"; };

    if ($just_dump)
      { print join("\n",@$r_files),"\n";
        return;
      };

    my $tmp = new File::Temp(UNLINK => 0,
                             TEMPLATE => 'rsync-dist-filesXXXXX',
                             DIR => '/tmp');
    foreach my $l (@$r_files)
      { 
        # print $tmp (File::Spec->rel2abs($l)),"\n"; 
        print $tmp $l,"\n"; 
      };
    close($tmp);
    return($tmp->filename());
  }


# ------------------------------------------------
# username/hostname/date utilities  
# ------------------------------------------------

sub local_info
# returns a list consisting of:
# current date and time,
# localhost
# localuser
# from, a string consisting of "localuser@localhost"
  { my $now= datestring();
    my $local_host= my_hostname();
    my $local_user= username();
    my $from= $local_user . '@' . $local_host;
    return($now,$local_host,$local_user,$from);
  }

sub username
# returns the username of the local user
  { return((getpwuid($>))[0]); }

sub my_hostname
# returns the full qualified name of the localhost
  { return((gethostbyname(hostname()))[0]); }

sub datestring
# create a datestring the same way "date +%Y-%m-%dT%H:%M:%S" does
  { my @a=localtime(time()); 
    return(sprintf("%04d-%02d-%02dT%02d:%02d:%02d", 
                    1900+$a[5], 1+$a[4], $a[3], 
                    $a[2], $a[1], $a[0]));
  }

sub timeindex
  { my($datestr)= @_;

    my($date,$time)= split("T",$datestr);
    my($year,$month,$day)= split("-",$date);
    my($h,$m,$s)= split(":",$time);

    return(timegm($s,$m,$h,$day,$month-1,$year-1900))
  }


sub datestring_is_today
  { my($str)= @_;

    my $index= timeindex($str);

    my $now= time();

    if (time()-timeindex($str) < 86400)
      { return(1); };
    return;
  }

# ------------------------------------------------
# string utilities  
# ------------------------------------------------

sub incr_tag
  { my($old_tag)= @_;

    if ($old_tag=~ /^(.*)\s+(\d+)\s*$/)
      { my $txt= $1;
        my $no= $2;
        return($txt . " " . (++$no));
      };
    $old_tag=~ s/\s+$//;
    return($old_tag . " 2");
  }

sub empty
  { my($st)= @_;
    my $reftype= ref($st);

    if    ($reftype eq 'ARRAY')
      { $st= $st->[0]; }
    elsif ($reftype eq 'SCALAR')
      { $st= $$st; }
    elsif ($reftype ne '')
      { croak "assertion: reftype:\"$reftype\""; };

    return(1) if (!defined $st);
    return(1) if ($st eq "");
    return;
  }

sub has_glob
  { 
    foreach my $str (@_)  
      { if (extended_glob::is_glob($str))
          { return(1); };
      };
    return;
  }

sub shell_single_quote_escape
  { my($str)= @_;

    # in a shell command that uses single quotes,
    # it is a bit complicated to escape single quotes
    # example:
    # echo 'test'
    #   prints "test" to the console but 
    # echo 'test's' 
    #   does not print "test's" 
    #   in order to archive this we have to use
    # echo 'test'"'"'s'
    # 
    # this kind of single-quote escaping is done here:
    $str=~s/'/'"'"'/g;
    return($str);
  }

# ------------------------------------------------
# ssh execution
# ------------------------------------------------

sub myscp
  { my($host, $user, $file, $destpath, $do_catch, $silent)= @_;

    my $cmd= "scp $file $user\@$host:$destpath";
    return(mysys($cmd, $do_catch, $silent)); 
  }

sub myssh_cmd
# make a system call on a remote host
# global variables used:
#  $opt_dry_run: when 1, just print the command, do not execute
# parameters:
#  $host: the remote host
#  $user: user on the remote host the command uses
#  $path: path on the remote host from where the command is executed
#  $cmd:  the command
#  $do_catch: when 1, catch output from the system call 
# returns: ($rc,$r_lines)
#   $rc: 1 when everything was ok
#        0 when return code was 256*$my_errcode
#   $r_lines: ref to an array of lines, if $do_catch was 1
# dies when the command fails with a return-code different 
# from 256*$my_errcode
  { my($host, $user, $path, $cmd, $do_catch, $silent)= @_;

    if ($path!~ /^\//)
      { $path= '$HOME/' . $path; };

    if (defined $user)
      { $host= $user . '@' . $host; };

    if (defined $path)
      { $cmd= "(cd $path; \\\n" .
              "if [ \$? -ne 0 ]; \\\n" .
              "then exit $my_errcode; \\\n" .
              "fi && \n" .
              "$cmd)"; };

    # -A: turn agent forwarding on 
    my $ssh_cmd= "ssh -A $host \\\n'$cmd'";

    if ($opt_dry_run)
      { print $ssh_cmd,"\n"; 
        return(1);
      }
    else
      { # shorten the command:
        $ssh_cmd =~ s/\\[\r\n]+/ /g;# combine backslash-continued lines
        $ssh_cmd =~ s/[\r\n]+/ /g;  # CR/LF -> <space>
        $ssh_cmd =~ s/ +/ /g;       # space-sequence -> single space
        return(mysys($ssh_cmd, $do_catch, $silent)); 
      }

   }

# ------------------------------------------------
# system call
# ------------------------------------------------

sub mysys
# make a system call
# parameters:
#   $cmd: the command to execute
#   $do_catch: when 1, catch output from the system call 
#   $silent: do not print to the screen (only with $do_catch==1)
# returns: ($rc,$r_lines)
#   $rc: 1 when everything was ok
#        0 when return code was 256*$my_errcode
#   $r_lines: ref to an array of lines, if $do_catch was 1
# dies when the command fails with a return-code different 
# from 256*$my_errcode
  { my($cmd,$do_catch, $silent)= @_;
    my $rc;
    local(*F);
    my $r_lines;

    print "$cmd\n" if ($debug);

    if ($do_catch)
      { my @lines;
        $r_lines= \@lines;
        $cmd.= " 2>&1 |";
        open(F, $cmd) || die "can\'t fork: $!";
        while (my $line=<F>)
          { print $line if (!$silent);
            chomp($line);
            push @lines,$line;
          }
        if (!close(F))
          { # an error code was returned:
            $rc= $?;
          };
      }
    else
      { $rc= system($cmd); 
      };

    return(1,$r_lines) if ($rc==0);

    return(0,$r_lines) if ($rc==$my_errcode*256);

    die "\"$cmd\" \nfailed, msg:$! errcode: $?";
  }

# ------------------------------------------------
# command line preprocessing
# ------------------------------------------------

sub gbl_arg_lst_to_map
  { my %map;

    foreach my $e (@gbl_arg_lst)
      { # remove "--":
        my $s= $e; $s=~ s/^--//;
        $map{$s}= $e;
        # replace "-" with "_" and add this:
        $s=~ s/-/_/g; 
        $map{$s}= $e;
      };
    return(\%map);
  }

sub preproc_args
  { my $r_map= gbl_arg_lst_to_map();

    # map commands to options e.g.
    # "dist" to "--dist":
    foreach my $arg (@ARGV)
      { if (exists $r_map->{$arg})
          { $arg= $r_map->{$arg}; };
      };
   }

# ------------------------------------------------
# config-file / environment handling
# ------------------------------------------------

sub read_config
# read variables from the config-file but do
# not overwrite variables that are already set
  { my($filename)= @_;

    if (!-r $filename)
      { die "error: file \"$filename\" cannot be read"; };

    my $r_cnf= simpleconf::parse($filename,types=>\%gbl_config_types);


    container::Export(\%gbl_map_hash,$r_cnf,overwrite=>0,skip_empty=>1);
  }  

sub read_env
# read global variables from the environment
# lists must be represented as strings containing
# comma separated values
  { my ($r_gbl_map_hash)= @_; 

    my %env;
    foreach my $key (keys %$r_gbl_map_hash)
      { my $val= $ENV{$key};
        $val=~ s/^\s+//;
        $val=~ s/\s+$//;
        my $ref= ref($gbl_map_hash{$key});
        if    ($ref eq '')
          { $env{$key}= $val; }
        elsif ($ref eq 'SCALAR')
          { $env{$key}= $val; }
        elsif ($ref eq 'ARRAY')
          { $env{$key}= [split(/,/,$val)]; }
        else
          { die "unsupported reftype, key: $key reftype: $ref"; }; 
      };
    container::Export($r_gbl_map_hash,\%env,overwrite=>0,skip_empty=>1);
  }

sub show_config
# uses the global map hash (%gbl_map_hash)
# to print an example of a config file
# (only defined global variables are taken into account)
  { my($filename)= @_;
    my $var;
    my %container;

    my $r_host_users= process_user_and_hostname(\@opt_hosts,\@opt_users);
    if (ref $r_host_users ne '')
      { @opt_hosts= ();
        @opt_users= ();
        for(my $i=0; $i<= $#$r_host_users; $i++)
          { push @opt_hosts, $r_host_users->[$i]->[0];
            push @opt_users, $r_host_users->[$i]->[1];
          };
      };

    container::Import(\%gbl_map_hash,\%container,skip_empty=>1,deep_copy=>1);

    simpleconf::create(\$var,\%container,
                       lineseparator=>"\n\n",
                       comments=>\%gbl_config_comments,
                       order=> \@gbl_config_order
                      );
    $var.= "\n";
    if (defined $filename)
      { rename_to_bak($filename);
        write_file($filename,\$var);
      }
    else
      { print $var; };
  }


# ------------------------------------------------
# utilities for the user interface
# ------------------------------------------------

sub ask_char
# ask the user to enter one from a given
# list of characters and returns that character.
  { my(@chars)= @_;
    my %known= map { $_=> 1 } @chars;

    for(;;)
      { my $var= <STDIN>;
        $var= lc($var);
        $var=~ s/^\s+//;
        $var=~ s/\s+$//;
        if (exists $known{$var})
          { return($var); };
        print "please enter one of these characters:\n",
              join(" ",@chars),"\n";
      }  
  }

sub consume_file
# read the lines of a given file until a 
# given regular expression matches. Returns
# the found text as a single scalar variable
  { my($stop_regexp,$filename,$r_var)= @_;
    local(*F);
    my @lines;

    open(F,$filename) or die "unable to open \"$filename\"";
    while(my $line=<F>)
      { last if ($line=~ /$stop_regexp/o);
        chomp($line);
        push @lines, $line;
      };
    close(F);
    $$r_var= join("\n",@lines);
  }

sub ask_editor
# use an editor to obtain a value from the user.
# prints an initial message below the first line.
# fills the first line(s) with an optional default value
# returns the value
  { my($initial_message, $default, $r_var)= @_;

    return if (defined $$r_var);
    my $str= "-" x 20;

    for(;;)
      { 
        my $tmp = new File::Temp(UNLINK => 0,
                                 TEMPLATE => 'rsync-dist-tempXXXXX',
                                 DIR => '/tmp');

        print $tmp $default if (defined $default);
        print $tmp "\n",$str,"\n";
        print $tmp $initial_message;
        close($tmp);

        my $tmp_file_time= filetime($tmp);

        my $syscmd= "$opt_editor " . $tmp->filename;
        system($syscmd) == 0
            or die "\"$syscmd\" failed: $!";

        if (filetime($tmp) == $tmp_file_time)
          { # file-date was not changed
            print "file was not changed, continue or quit ?\n" .
                  "(C/Q)";
            my $ch= ask_char(qw(c q));
            if ($ch eq 'q')
              { exit 0; };
          };

        consume_file($str,$tmp->filename,$r_var);

        unlink($tmp->filename);

        if ($$r_var=~ /^\s*$/)
          { print "empty text is not allowed here, re-enter or quit ?\n" .
                  "(E/Q)";
            my $ch= ask_char(qw(e q));
            if ($ch eq 'q')
              { exit 0; };
          }
        else
          { last; };     
      };      
  }

sub take_default
# extract default values for usage with ensure_var()
# from the local log-file.
# @list:
#  a list of strings "action:tag{:tag2}" (separated by a ':')
#  searches in the local logfile for the last occurence
#  of the given action and extract the tag(s). The program
#  searches the whole @list until it finds something 
  { my(@list)= @_;
    my @vals;

    get_last_log_entries(\$gbl_last_locallog_entries);

    foreach my $l (@list)
      { my($action,@tags)= split(/:/,$l);

        # find a recent locallog entry for the given action:
        my $r_entry= $gbl_last_locallog_entries->{$action};
        next if (!defined $r_entry);

        @vals=();
        # find all values:
        foreach my $t (@tags)
          { push @vals, $r_entry->{$t} if (defined $r_entry->{$t});
          };

        if ($#vals == $#tags) # all values found
          { last; };
      };
    return(@vals);
  }

sub ensure_var
# ensures that a given variable has a non-empty
# value by calling an external editor.
# takes a reference to that variable, a tag specifying
# a short help text (see also %gbl_edit_texts)
# and a (optional) default value
  { my($ref,$tag,$default)= @_;

    if (defined $opt_no_editor_defaults)
      { $default= undef; };

    my $reftype= ref($ref);
    die "assertion" if ($reftype eq '');
    die "assertion" if ($reftype eq 'HASH');

    return if (!empty($ref));

    my $message= $gbl_edit_texts{$tag};

    die "assertion" if (!defined $message);

    if ($reftype eq 'ARRAY')
      { $message.= "To enter more than one item separate them by\n" .
                   "spaces, commas or by putting them into new lines\n";
      };                   

    if (defined $default)
      { $message.=  "(above you see the text you entered last time)\n"; };

    my $str;
    ask_editor($message, $default, \$str);

    if ($reftype eq 'SCALAR')
      { $$ref= $str; }
    elsif ($reftype eq 'ARRAY')
      { @$ref= split(/[\n ,]+/,$str);
      }
    else
      { die "assertion"; };   
  }

sub ensure_host_users
  { my($r_hosts,$r_users)= @_;

    my @strs;
    my $result;
    my $io_done;

    for(;;)
      { 
        if    (($#$r_hosts<0) && ($#$r_users<0))
          { # no users and no hosts given
            ensure_var(\@strs, 'REMOTEHOSTSUSERS', 
                       take_default('distribute:REMOTEHOSTS:REMOTEUSERS',
                                    'links:REMOTEHOSTS:REMOTEUSERS',
                                   )
                      );
            $io_done= 1;    
            $result= process_user_and_hostname(\@strs);       
          }
        elsif ($#$r_hosts<0)          
          { # users are specified, ask only for the hosts
            ensure_var(\@strs, 'REMOTEHOSTS', 
                       take_default('distribute:REMOTEHOSTS',
                                    'links:REMOTEHOSTS',
                                   )
                      );
            $io_done= 1;    
            $result= process_user_and_hostname(\@strs,$r_users);       
          }
        elsif ($#$r_users<0)
          { # no users may be ok, when they are supplied with the
            # hostnames in the form "user@hostname"
            $result= process_user_and_hostname($r_hosts);             
          }
        else
          { # user- and hostnames given, process both
            $result= process_user_and_hostname($r_hosts,$r_users); 
          };

        return($result) if (ref($result) ne '');
        if ($io_done)
          { print "$result, re-enter or quit (R/Q) ?\n";
            my $ch= ask_char(qw(r q));
            if ($ch eq 'q')
              { exit 0; };
          };
      };    
  } 


sub dir_dependant
# used to recognize command-line options that contain
# a dirname like "dist,16" where "dist" is the dirname and
# "15" is the actual command line argument.
# returns the argument, the path for the dirname,
# the log-file for the dirname and the changes-file for
# the dirname
  { my($option,$strict)= @_;
    my $arg;

    if ($option=~ /^([^,]*),(.*)/)
      { $arg= $2;
        $option= $1;
      };
    $option= dirname($option); 

    if ($option eq 'dist')
      { return($arg, $opt_distpath    ,DIST_LOG,DIST_CHANGES); }
    else 
      { return($arg, $opt_linkpath,LINK_LOG); }
  }

sub dirname 
# recognizes a dirname given by the user. Dirnames may be
# "dist","d","links" or "l"
# returns "dist" or "links"
# dies when the given dirname is not known
  { my($str,$strict)= @_;

    my $dir= $gbl_known_dirnames{$str};
    if (!defined $dir)
      { if ($strict)
          { die "unknown dirname \"$str\"\n" .
                "the following dirnames are known:\n" .
                join(" ",(sort keys %gbl_known_dirnames)) .
                "\n";
            return;     
          };    
      };
    return($dir);
  }         

sub split_uhp
# split hostname-part, returns:
# user (optional)
# host (mandatory)
# path (optional)
# valid formats:
# hostname  user@hostname hostname/path user@hostname/path
  { my($s)= @_;  
    $s=~ s/^\s+//;
    $s=~ s/\s+$//;
    my($u,$h,$p);

    if ($s=~/\@/)
      { if ($s!~/([^\@]+)\@(.+)/)
          { die "error: hostname \"$s\" not parsable!\n"; }
        ($u,$h)=($1,$2); 
      }
    else
      { $h= $s; }

    if ($h=~/\//)
      { if ($h!~/([^\/]+)\/(.+)/)
          { die "error: hostname \"$s\" not parsable!\n"; }
        ($h,$p)= ($1,$2); 
      }
    return($u,$h,$p);
  }

sub process_user_and_hostname
# returns a list of [hostname,username] pairs
# either hosts and users are arrays, where at least 
# one hostname and one username is given or
# hosts is a list of "user@hostname" strings
# NEW: "user@hostname/dir" is now also allowed
  { my($r_hosts,$r_users)= @_;
    my @l;

    if ($#$r_hosts<0)
      { return("no hosts"); }; # no hostnames given

    for(my $i=0; $i<= $#$r_hosts; $i++)
      { my($user,$host,$path)= split_uhp($r_hosts->[$i]);

        if (!defined $user) # no username found or given
          { $user= $r_users->[$i];
            if (!defined $user) # user-array shorter than hostname array
              { $user= $r_users->[-1]; # take last element of array
                if (!defined $user)
                  { return("no users"); # error, username missing
                  };
              };
          }

        push @l, [$host,$user,$path];  
      };
    return(\@l);
  }

sub maybe_filter_output
# call filter_output depending on option
  { my $r_lines = $_[0];
    if ($opt_filter_output)
      { filter_output(@$r_lines)
      }
    else
      { map("$_\n",@$r_lines);
      }
  }

sub filter_output
# filter the output from a remote 'ls -l' command to make it more readable
  { return grep(!/^$/, map
      { if (m{(\S+) -\> .*/([T\d-:]+)})
          { sprintf("%-20s %s\n",$1,$2) }
        elsif (m{error})
          { "$_" }
        else
          { "" }
      } @_);
  }

# ------------------------------------------------
# online-help
# ------------------------------------------------

sub print_summary
# print a summary of the script
  { printf("%-20s: $sc_summary\n",
           $sc_name);
  }

sub h_center
# center a text by adding spaces on both sides
  { my($st)= @_;
    return( (' ' x (38 - length($st)/2)) . $st );
  }

sub help
# prints the program help, called when "-h" option is used
  { my $l1= h_center("**** $sc_name $sc_version -- $sc_summary ****");
    my $l2= h_center("$sc_author $sc_year");
    print <<END;

$l1
$l2

Syntax:
  $sc_name {options} [command]

  commands that do changes on the server:

    dist --dist -d 
                distribute files to remote host

    to-attic --to-attic [dir] 
                move a directory (aka version) to the "attic" directory

    from-attic --from-attic [dir] 
                move a directory (aka version) from the "attic" directory
                back to the main directory (which is given by -p)

    change-links --change-links -C [source,filemask/files]
                change symbolic links on the remote server
                --> see also "--last-dist"

    add-links --add-links -A [source,files]
                add links on the remote server
                --> see also "--last-dist"

    remove-links --remove-links [source,files]
                remove links on the remote server

    mirror --mirror [dist|d|links|l]
                mirror the specified directory from the first
                given host to all following ones. 
                Caution: you may delete data on the secondary
                hosts that you wanted to keep, think twice before
                running this command
                The list of mirror-hosts may contain the directory
                in the form "hostname/directory". With this it is possible
                to distribute directories from the central mirror
                (the first host in the list) to a different directory
                on the other host. If the directory is not given
                (no "/" is found in the hostname) it is the same as on the 
                central mirror

    rm-lock --rm-lock [dist|d|links|l]

                remove the lockfile in the "dist" or "links"
                directory in case it was left behind due to an 
                error in the script
                (for distribution or links)

    force-rm-lock --force-rm-lock [dist|d|links|l]

                like "rm-lock", but the lock file is removed 
                even when it was created by another user.

    mk-lock --mk-lock [dist|d|links|l]

                create the lockfile in the remote directory. This is
                useful in order to lock the directory for other users
                that run rsync-dist.pl when you want to modify files on
                the remote-host manually.
                (for distribution or links)

    rebuild-last --rebuild-last
                rebuild the "LAST" file on the remote server. This
                file contains the name of the latest distribution
                directory. When a new distribution is made, the
                files are compared against the files of this directory.
                When a file has not changed, a hard-link to this
                directory is created. Note that this command creates
                no lock-file on the remote host. You have to do this
                yourself with the "--mk-lock" command before.
                only for distribution directories

    create-branch [name]{,source}
                create a new branch on the server. The {,source} parameter is
                optional. It is the name of the old branch from which new 
                branch is created. If {,source} is omitted, the branch 
                is created from trunk
    
    expand-glob
                if the --localpath parameter contains glob-expressions
                list all the files that would be checked for transfer
                when a dist command is issued

  commands to inspect the server:

    ls --ls     [dist|d|links|l]
                show the remote directory (for distribution or links)

    cat-log --cat-log [dist|d|links|l]
                show the logfile (for distribution or links)

    tail-log --tail-log  [dist|d|links|l,n]
                show the last n lines of the logfile 
                (for distribution or links)

    perl-log --perl-log  [dist|d|links|l]
                similar to --cat-log, but dump the logfile as a 
                perl-structure to the screen.

    ls-tag --ls-tag -T [tag/regexp]
                search for a tag in the log file
                only for distribution directories

    ls-version --ls-version [version/regexp]
                search for a version  in the log file
                only for distribution directories

    cat-changes --cat-changes [dist|d|links|l] 
                show the changes-file (for distribution or links)

    tail-changes --tail-changes [dist|d|links|l,n]
                show the last n lines of the changes-file
                (for distribution or links)

  commands for the config-file:

    show-config --show-config
                Print the contents of a valid configuration file to the
                screen. You can for example create a configuration file
                by supplying --hosts, --user, --distpath, --linkpath and
                --localpath on the command-line and additionally
                --show-config. The program will then print a generated
                configuration-file to the console. If you redirect this
                to a file you have your configuration file.

    write-config --write-config [filename]
                like --show-config but write to a file

    show-config-from-log --show-config-from-log
                similar to --show-config, but in this case the program
                also reads the local log-file to get information on
                the remote-host, the remote-user and the remote paths.

    write-config-from-log --write-config-from-log [filename]
                like --show-config-from-log but write to a file


  help options:
    -h: this help

    --man: show embedded manpage

    --summary:  give a summary of the script

  options to specify remote host and user:

    --host -H [remote-host[,remote-host2...]]
                a list of remote-hosts separated by comma, spaces, or colon

                if this option is not given the script tries to read from
                the environment variable "RSYNC_DIST_HOST"      

    --user -u [remote-user[,remote-user2...]]
                user for login on the remote host

                if this option is not given the script tries to read from
                the environment variable "RSYNC_DIST_USER"      

  options to specify directories:

    --distpath -p [remote-dist-path] 
                remote directory where files are disted

                if this option is not given the script tries to read from
                the environment variable "RSYNC_DIST_PATH"      

    --linkpath -P [remote link-path]
                remote directory where links are created

                if this option is not given the script tries to read from
                the environment variable "RSYNC_DIST_LINKPATH"  

    --localpath -l [local-path,local-path2...] 
                list of files or directories to be distributed

                if this option is not given the script tries to read from
                the environment variable "RSYNC_DIST_LOCALPATH" 
                Several paths can be specified with either a comma-separated 
                list or several -l options

    --localprefix [prefix]
                prepended to all files or directories to be distributed

                if this option is not given the script tries to read from
                the environment variable "RSYNC_DIST_LOCALPREFIX"       

  options to specify tags and log-messages:

    --message -m {logmessage} 
                specify a log message

                if this option is not given the script tries to read from
                the environment variable "RSYNC_DIST_MESSAGE"
                if this option is given without being followed by a 
                message, an empty log-message is used   

    --automessage
                (only for the "add-links" or "change-links" commannds)
                generate a message of the style 
                "link to [tag]" where [tag] is the tag of the
                last distributed version. This is an alternative 
                to the "--message" option

    --tag -t [tag]
                a tag for the distribution

                if this option is not given the script tries to read from
                the environment variable "RSYNC_DIST_TAG"       
                if this option is given without being followed by a 
                tag-string, an empty tag is used        

    --autotag   (only for the "dist" command)
                take the tag from the last distributed version and
                increment the number at the end of this tag by one.
                This is an alternative to the "--tag" option

  options for the management of pre-defined parameters:

    --config -c [filename]
                read variables from a configuration file. The format
                is simple <name>=<value>
                Empty lines and lines starting with "#" are ignored.
                Spaces around the "=" sign are also ignored. Array values
                are specified as comma-separated lists.
                The following variables are recognized
                RSYNC_DIST_HOST
                  name of the distribution host or hosts. 
                  More than one host can be specified as a
                  comma-separated list. See also --hosts
                RSYNC_DIST_USER
                  the username(s) $sc_name uses to log on to the remote
                  hosts. See also --user. When several hosts (see above)
                  are defined, you can define several (possibly different)
                  users for the hosts
                RSYNC_DIST_PATH
                  the remote distribution directory. See also
                  --distpath
                RSYNC_DIST_LINKPATH
                  the remote link directory, see also
                  --linkpath
                RSYNC_DIST_PREFIX_DISTDIR
                  when set to 1, prepend the distribution directory to the 
                  link-source path (only for "add-links" and "change-links")
                RSYNC_DIST_LOCALPATH 
                  the local directory or directories. More than one
                  directory can be specified in a comma-separated list.
                  See also --localpath. 
                RSYNC_DIST_LOCALPREFIX
                  the prefix that is prepended to local paths (see above)
                  see also --localprefix  
                RSYNC_DIST_WORLDREADABLE
                  when set to 1, make all distributed files world-readable
                  see also --world-readable
                RSYNC_DIST_ONE_FILESYSTEM
                  when set to 1, do not cross filesystem boundaries on the
                  local host. See also --one-filesystem 
                RSYNC_DIST_PRESERVE_LINKS
                  when set to 1, symbolic links are never dereferenced and
                  always copied as links
                RSYNC_DIST_REMOVE_LINKS
                  when set to 1, symbolic links always dereferenced
                RSYNC_DIST_EXCLUDE_LIST
                  specify a file on the local host that contains files that
                  are to be excluded
                RSYNC_DIST_CHECKSUM
                  when set to 1, use checksums to detect changes in files.
                  see also --checksum 
                RSYNC_DIST_BRANCH
                  when this variable is defined, use this branch
                  for distributing files. Seet also the --branch option.
                RSYNC_DIST_PARTIAL
                  when set to 1, make a complete copy of the last version on the
                  server but distribute only some files from the client
                  to the server. --localpath may contain file-glob patterns
                  in this case.
                RSYNC_DIST_EDITOR
                  the default editor to enter options that the used didn't
                  specify on the command lines. The default is "$default_editor".
                  See also --editor   
                RSYNC_DIST_EDITOR_NO_DEFAULTS
                  when set to 1, the editor does not show defaults,
                  when called
                RSYNC_DIST_SHOW_PROGRESS
                  when set to 1, show progress of rsync on console
                RSYNC_DIST_TAG
                  specify a default-tag, may also be empty in which
                  case the program does not request a tag if no one
                  is given on the command line
                  NOTE: it is, however, questionable to specify a
                  constant default tag
                RSYNC_DIST_MESSAGE
                  specify a default log-message, may also be empty in which
                  case the program does not request a message if no one
                  is given on the command line
                  NOTE: it is, however, questionable to specify a
                  constant default log message
                RSYNC_DIST_FILTER_OUTPUT
                  when set to 1, output from remote ssh commands
                  is filtered to make it more human readable. This affects the
                  commands "change-links", "add-links", and "ls links".

                Note that command-line arguments always override 
                values taken from the config-file.   


    --env       By supplying this option, the program can take all
                variables mentioned above (see --config) from the 
                unix-shell environment.  

  miscellaneous options:

    --branch [branchname]
                use the most recent version of <branchname> to make the
                hardlink-copy on the server.             

    --partial   make a complete copy of the last version on the
                server but distribute only some files from the client
                to the server. --localpath may contain file-glob patterns

    --filter-output
                when this option is given, output from remote ssh commands
                is filtered to make it more human readable. This affects the
                commands "change-links", "add-links", and "ls links".

    --version-file [filename]
                when the <dist> command is executed, the name of
                the directory that is created on the server is written
                to this file. 
                Note that the filename may be a complete path+filename.
                If the path is not absolute, it is assumed to be relative
                to localprefix. If localprefix is not specified, it is
                assumed to be relative to the current working directory.
                Note too, that the file may be created in one of the
                directories that is to be distributed. This is done before
                the actual transfer of files takes place, so you will
                find the generated file on the server too, in this case.

    --editor [editor]
                specify the interactive editor. 
                if this option is not given the script tries to read from
                the environment variable "RSYNC_DIST_EDITOR", if this
                is not set from "EDITOR", if this is not set the
                default is "$default_editor"
                Note that these environment variables are 
                even if "--env" (see above) is not given        

    --no-editor-defaults -N
                do not show defaults for the text-entries when the
                editor is called

    --no-no-editor-defaults 
                set "--no-editor-defaults" (see above) to false
                (use editor defaults). Since this is the default behavior, 
                this option is only needed in order to override a 
                different setting taken from a config file  

    --prefix-distdir 
                take the path of the dist-directory as prefix for the "source" 
                part of the add-links or change-links command. 
                Together with --last-dist you can specify the "source" part 
                completely like it is shown here:               
                  rsync-dist.pl --config my_config --prefix-distdir \
                                --last-dist change-links idcp*

                and here:

                  rsync-dist.pl --config my_config --prefix-distdir \
                                --last-dist change-links idcp1,idcp2

    --no-prefix-distdir 
                set "--prefix-distdir" (see above) to false. Since
                this is the default behavior, this option is only needed
                in order to override a different setting taken from
                a config file  

    --last-dist -L
                append the name of the last distribution that was
                made to the "source" part of the add-links or
                change-links command            

    --one-filesystem 
                do not cross filesystem boundaries on the local host

    --preserve-links
                never dereference links, just keep them

    --dereference-links
                always dereference links

    --exclude-list [file]
                specify a file that contains files to be excluded from transfer

    --checksum  use checksums instead of date-comparisons when deciding 
                whether a file should be transferred

    --progress  use the rsync "progress" option to show the progress
                of rsync on screen

    --dry-run   just show the command that would be executed    

    --world-readable -w
                make all files world-readable   

    --create_missing_links
                for use with command "change-links": don't complain if links
                don't exist, instead create them

    --ssh-back-tunnel [port]
                use an existing ssh-tunnel on remote host in order to connect
                back to the local host. This option has only an effect on
                the "dist" command.     
                Such a tunnel can be created by issuing this command 
                on the remote host:
                ssh -N -L <port>:<localhost>:22 <localuser>@<tunnel-host>

    --single-host
                perform "ls" or "cat-log" or "tail-log" command
                only on the first remote host.

END
  }
__END__
# Below is the short of documentation of the script

=head1 NAME

rsync-dist.pl - a Perl script for managing distributions of binary files

=head1 SYNOPSIS

  rsync-dist.pl -c <config-file> -m -t dist

  rsync-dist.pl -c <config-file> -m -L change-links <filemask>...

=head1 DESCRIPTION

=head2 Features

This script can be used to copy files (usually binary distributions
of programs) to a remote server while preserving all the old versions
of these distributions. It can also create and change symbolic links
that point to certain distributions. Among the programs features are:

=over 4

=item *

Every distribution is placed in a directory named after the current time 
and date complying with ISO 8601. By this, each directory is unique. 

=item *

Files that didn't change with respect to the last version are saved as
a hard-link, occupying almost no additional disk space.

=item *

Files are transferred via rsync and ssh. Rsync only copies files that
have changed with respect to the last version. Changes are detected
either by comparing file-creation times or a MD5 sum.

=item *

During distribution, files can be transferred to several servers
in one single command. 

=item *

a lock file is created before critical actions on the server(s), so
several instances of this script can be started at the same same
by different people without interfering with each other

=item *

log-files on the server are created that show when and by whom things 
were changed

=item *

a local log-file in the users home tracks all actions that were performed
that changed something on the server.

=item *

a version can be tagged. That tag is placed with other information in
the logfile. Later on, the logfile can be searched for that tag
or by a regular expression

=item *

each version has a mandatory log message that is placed into the
logfile.

=item *

Versions can be moved to an "attic" directory. By this,
the main distribution directory can be cleared of obsolete and
non-working versions. 

=item *

symbolic links can be created that point to the version-directories. 
Manipulation of these links is also logged. This can be used to manage
a list of symbolic links, each pointing to a version a corresponding IOC
has to boot.

=back

=head2 Prerequisites

=over 4

=item *

The rsync program has to be installed on the server and the client machine.

=item *

The user of the client machine must have an account on the server machine
where he can log in via ssh without the need to enter a password or
a passphrase (requires proper setup of the ssh-agent). He must also be 
capable to log from the remote host as remote user back to the local host
as local user by ssh.

=item *

perl (of course...) must be installed on the client machine

=item *

the server must run a unix/linux operating system since this program
needs at least a standard bourne-shell

=item *

there must be a directory on the server where the user or the account
where the user has access to, can write to

=back

=head2 Using a configuration file

Certain values like the name of the remote host or the 
directory on the remote-host can be stored in a configuration file. 
The program can then read that configuration file in order to obtain
these values. Such a file is easy to create. Example:

  rsync-dist.pl -H myhost -u myuser -p /dist-dir -P /link-dir\
      --checksum show-config

This command prints the contents of such a file to the screen where
all settings match the ones given as command line parameters. Here is how
you create that file directly:

  rsync-dist.pl -H myhost -u myuser -p /dist-dir -P /link-dir\
      --checksum write-config MYCONFIG

You can easily extend this file. Here is for example, how you
add the "world-readable" option:

  rsync-dist.pl --config MYCONFIG --world-readable write-config MYCONFIG

Later on, you can start a distribution command like this:

  rsync-dist.pl --config MYCONFIG dist

or like this  

  rsync-dist.pl -c MYCONFIG dist

The program takes all parameter from "MYCONFIG". Parameters it needs but
that are still not specified (like the local path) are requested from
the user interactively by starting an editor (default: vi).  

=head2 Distributing files

In order to distribute files the user must at least specify the
remote-server-name, the remote-path, the local-path and a log-message.
The local and remote-path are relative to your user-home
unless they start with a '/'.

For day to day work, the server-name and paths will be specified in a 
configuration file that you created as it is described 
in the chapter above. Here is how you distribution command looks then:

  rsync-dist.pl -c <config-file> -m <log-message> dist

Additionally you can specify your account-name on the remote machine
(especially when this is different from your account on the local machine).
This can be done with the "-u" option or by the config-file. You can
also specify a tag. The tag should be a one-line string that can later 
be used to identify or search for the current distribution of files. 

Example: 

  rsync-dist.pl -c <config-file> -m <log-message> -t <tag> dist

If you prefer not to have a tag or log-message it is like this:

  rsync-dist.pl -c <config-file> -m -t dist

=head2 Inspecting a remote directory with distributed files

The remote directly can be listed with this command:

  rsync-dist.pl -c <config-file> ls dist

Note that since the command "ls" has a higher priority than the
"dist" command, it overrides the distribution command when
appended at the end of the parameter list.  

The word "dist" after "ls" means that the distribution directory is listed.
In order to see the link directory, you have to specify "links" after
"ls".

On the remote directory you see the following files and directories:

=over 4

=item version directories

These directories are named like: "2006-10-04T13:57:35" or 
"2006-10-04T14:03:12".
This is an ISO 8601 format for timestamps. The numbers within the string are
(in this order) the year, month, day, hour, minute, seconds. The letter "T" 
separates the date from the time. Your distributed files are placed 
within these 
directories. Files that are equal among several directories are stored with
hard-links in order to preserve disk space.

=item the file LAST

This file contains the name of the directory that was most recently 
created. This file is always present after you call this script for
the first time. It is modified each time you distribute files to the 
server. When a new version is distributed, the directory mentioned in
"LAST" is copied by hard-link copy, then rsync is called to transmit
all changed/added or removed files.

=item branches

When your development takes place on several branches at the same 
time, the hard-link copy of the last distributed version may
be inefficient with respect to the space it occupies on the 
hard disk. For these cases, branches can be used. A branch simply
means that another "LAST" file is used in order to create the
hard-link copy. A branch can be created from trunk or another
branch with the create-branch command. It can be used together with
the dist command with the "--branch" option. See also the online
help when you execute "rsync-dist.pl -h".

=item the file CHANGES-DIST

This file contains the changes of the most recent version compared to
the previous version. All files that were changed or added are listed.
Note that files that were delete ARE NOT listed. This is an example of
the contents of this file:

  VERSION: 2006-10-05T11:39:06
  CHANGED/ADDED FILES relative to 2006-10-05T10:10:06:
  2006-10-05T11:39:06/local/idcp/C

  VERSION: 2006-10-05T12:22:16
  CHANGED/ADDED FILES relative to 2006-10-05T11:39:06:
  2006-10-05T11:39:06/local/idcp/B
  2006-10-05T11:39:06/local/idcp/A

The first line of each block is the name of the directory which is 
also the date and time when it was created

=item the file LOG-DIST

This is the log-file that is appended each time new files are distributed.
It contains the information when and by whom the distribution was done.
It also contains a log-message and, optionally, a tag for each version.
This is an example of the log-file:

  VERSION: 2006-10-05T11:28:56
  ACTION: added
  FROM: pfeiffer@tarn.acc.bessy.de
  TAG: TAG1
  LOG: test
  %%
  VERSION: 2006-10-05T11:39:06
  ACTION: added
  FROM: pfeiffer@tarn.acc.bessy.de
  TAG: TAG2
  LOG: test

The first line in each block is the name of the directory, and by this,
the date and time when the action took place. After "ACTION:" you find
the action that took place, "added" or "moved to attic" or "moved from attic".
The part after
"FROM:" is the person who started the command together with the name
of the client-host. After "TAG:" you find the optional tag, after "LOG:"
the optional log message with may span several lines. A "%%" seperates
entries in the log-file.

=back

=head2 Listing the CHANGES-DIST file

The file CHANGES-DIST, as it is described above, can be listed with this command:

  rsync-dist.pl -c <config-file> cat-changes 


=head2 Listing the LOG-DIST file

The file LOG-DIST, as it is described above, can be listed with this command:

  rsync-dist.pl -c <config-file> cat-log dist

The word "dist" after "cat-log" means that logfile of the distribution 
directory is listed.

=head2 Searching for tags

The log-file can be searched for a given tag or a (grep compatible)
regular expression that matches one or more tags. Example:

  rsync-dist.pl -c <config-file> ls-tag <tag or regexp>

A real-world example: 

  rsync-dist.pl -c <config-file> ls_tag TAG

The output of this command looks like this:

  VERSION: 2006-10-05T11:27:51
  ACTION: added
  FROM: pfeiffer@tarn.acc.bessy.de
  TAG: TAG1
  LOG: test
  --
  VERSION: 2006-10-05T11:28:56
  ACTION: added
  FROM: pfeiffer@tarn.acc.bessy.de
  TAG: TAG2
  LOG: test

In this case, the tag (seen as a regular expression) matched two existing tags
"TAG1" and "TAG2". Both entries from the logfile are listed separated by "--". 
Note that there is only the first line shown of each log-message.

=head2 Managing symbolic links

Although the script manages symbolic links in a generic way, the intention
of this feature is to manage startup-scrips of IOCs. The startup-script
determines which version of its application the IOC will boot. By letting the
IOC boot via a symbolic link to a script, there is an easy way to change the 
active version of the IOC's software without logging onto the IOC itself.

=head2 The log-file in the source directory


Note that there is a file created in the "<remote-sourcepath>/.."
directory that contains a list of all links that point to a certain
version. The name of that file is created after the <remote-path> that
contains the symbolic links. Example:

  LINKS-opt-IOC-Releases-idcp-links

contains information on symbolic links in the directory 
"opt/IOC/Releases/idcp/links". Example on the contents of this file:

  2006-10-09T10:28:13 idcp12
  2006-10-09T10:28:13 idcp15
  2006-10-09T10:28:13 idcp3
  2006-10-09T10:28:13 idcp7
  2006-10-09T10:28:13 idcp9
  2006-10-09T10:33:09 idcp13

The first line means for example, that in directory 
"opt/IOC/Releases/idcp/links" there is a symbolic link
named "idcp12" that references the distribution-directory 
"2006-10-09T10:28:13"-

=head2 Adding symbolic links

Symbolic links are added like this:

  rsync-dist.pl -c <config-file> -m <log-message> 
                add-links <remote-sourcepath>,<link1>,<link2>...

Note that if at least one the given links already exists, the command fails.
Note too, that the given remote-path must exist. The log-file is updated 
when this command is run.

=head2 Changing symbolic links

Symbolic links are changed like this:

  rsync-dist.pl -c <config-file> -m <log-message> 
                change-links <remote-sourcepath>,<link1>,<link2>...

or

  rsync-dist.pl -c <config-file> -m <log-message> 
                change-links <remote-path>,<filemask>...


Note that (especially in case one with all links explicitly listed) all 
of the given link-names must exist and must be symbolic links. 
The log-file is updated when this command is run.

If you just distributed a version you can use the "-L" option to access
the last distributed version. In this case, you can omit the
<remote-path> parameter. Example:

  rsync-dist.pl -c <config-file> -m <log-message> -L
                change-links <filemask>...


=head2 Inspecting the remote link-directory

The remote directly can be listed with this command:

  rsync-dist.pl -c <config-file> ls links

Since the command has a higher priority that the
other link commands, it overrides the them when
appended at the end of the parameter list. 

On the remote directory you see the following files and directories:
The "links" after "ls" means that the link directory is listed.

=over 4

=item the file LOG-LINKS

This is the log-file that is appended each time new links are added or 
existing links are changed. It contains the information when and by whom 
the change was done.
It also contains an optional log-message for each change and a directory
listing of the links before and after the change. 
This is an example of the log-file:

  DATE: 2006-10-05T14:09:07
  FROM: pfeiffer@tarn.acc.bessy.de
  OLD:
  lrwxr-xr-x 1 usr exp 22 Oct 5 14:07 ioc1 -> ../2006-10-05T13:02:44
  lrwxr-xr-x 1 usr exp 22 Oct 5 14:07 ioc2 -> ../2006-10-05T13:02:44
  NEW:
  lrwxr-xr-x 1 usr exp 22 Oct 5 14:09 ioc1 -> ../2006-10-05T14:02:44
  lrwxr-xr-x 1 usr exp 22 Oct 5 14:09 ioc2 -> ../2006-10-05T14:02:44

  DATE: 2006-10-05T14:11:58
  FROM: pfeiffer@tarn.acc.bessy.de
  LOG: changed nothing
  OLD:
  lrwxr-xr-x 1 usr exp 22 Oct 5 14:09 ioc1 -> ../2006-10-05T14:02:44
  lrwxr-xr-x 1 usr exp 22 Oct 5 14:09 ioc2 -> ../2006-10-05T14:02:44
  NEW:
  lrwxr-xr-x 1 usr exp 22 Oct 5 14:12 ioc1 -> ../2006-10-05T14:02:44
  lrwxr-xr-x 1 usr exp 22 Oct 5 14:12 ioc2 -> ../2006-10-05T14:02:44

The first line in each block is the date and time when the action took place. 
The part after "FROM:" is the person who started the command together with the name
of the client-host. After "LOG:" is the optional log message with may span several lines.

=back

=head2 Listing the LOG-LINKS file

The file LOG-LINKS, as it is described above, can be listed with this command:

  rsync-dist.pl -c <config-file> cat-log links

The word "links" after "cat-log" means that the logfile of the link directory
is listed.

=head1 QUICK REFERENCE

=head2 distribute a version

=over 4

=item without any log messages

  rsync-dist.pl -c <config-file> -m -t dist

=item with log message and tag

  rsync-dist.pl -c <config-file> -m "my message" -t "my tag" dist

=item enter log-message and tag interactively

  rsync-dist.pl -c <config-file> dist

=back

=head2 change a link

=over 4

=item link to the last dist-version without log message

  rsync-dist.pl -c <config-file> -m -L change-links <filemask>...

=item link to the last dist-version with log message

  rsync-dist.pl -c <config-file> -m "my message" -L change-links <filemask>...

=item link to the last dist-version and enter log-message interactively

  rsync-dist.pl -c <config-file> -L change-links <filemask>...

=item link to a specific version without log message

  rsync-dist.pl -c <config-file> -m change-links <version>,<filemask>...

<version> is usually a date-string like "2007-04-02T11:23:14"  

=back

=head2 inspect remote distribution directory

=over 4

=item list directory

  rsync-dist.pl -c <config-file> ls dist

=item show last entries in log-file

  rsync-dist.pl -c <config-file> tail-log dist

=item show last entries in CHANGES file

  rsync-dist.pl -c <config-file> tail-changes dist

=back

=head2 inspect remote link directory

=over 4

=item list directory

  rsync-dist.pl -c <config-file> ls links

=item show last entries in log-file

  rsync-dist.pl -c <config-file> tail-log links

=item show last entries in CHANGES file

  rsync-dist.pl -c <config-file> tail-changes dist

=back

=head1 Tips and tricks for the server administration

Logging onto the server required

=over 4

=item show all distribution directories

  for i in 2[0-9][0-9][0-9]*; do echo $i; done

=item list all existing distribution directories mentioned in LOG-DIST

  for i in 2[0-9][0-9][0-9]*; do grep $i LOG-DIST; done | \
        sed -e 's/VERSION: //'

=item list directories mentioned in LOG-DIST that do no longer exist

  for i in 2[0-9][0-9][0-9]*; do grep $i LOG-DIST; done | \
        sed -e 's/VERSION: //' > TMP
  grep VERSION LOG-DIST |sort|uniq| sed -e 's/VERSION: //' | \
        diff - TMP

=item compare existing directories with the ones mentioned in LOG-DIST

  for i in 2[0-9][0-9][0-9]*; do echo $i; done > TMP
  grep VERSION LOG-DIST |sort|uniq| sed -e 's/VERSION: //' | \
        diff - TMP

=item list directories used in LOG-LINKS

  grep -- '->' LOG-LINKS | \
        sed -e 's/^.*->.*\(2[0-9][0-9][0-9]\)/\1/'|sort|uniq

=item compare directories used in LOG-LINKS with existing ones

  (cd ../dist && for i in 2[0-9][0-9][0-9]*; \
        do echo $i; done) > TMP
  grep -- '->' LOG-LINKS | \
        sed -e 's/^.*->.*\(2[0-9][0-9][0-9]\)/\1/'|\
        sort|uniq|diff - ../dist/TMP  | grep '<'

=back

=head1 Further reading

Please do also have a look at the parameter help. You get this by
entering

  rsync-dist.pl -h | less

This online-help describes all parameters of the program, some which are
not mentioned here.   

=head1 AUTHOR

Goetz Pfeiffer, Goetz.Pfeiffer@bessy.de

=head1 SEE ALSO

rsync-documentation

=cut
