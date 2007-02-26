eval 'exec perl -S $0 ${1+"$@"}' # -*- Mode: perl -*-
    if 0;
# the above is a more portable way to find perl
# ! /usr/bin/perl

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

use Data::Dumper;

use simpleconf;
use container;
use maillike;

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
            $opt_mirror
            $opt_rm_lock
            $opt_mk_lock
            $opt_rebuild_last
            $opt_ls 
            $opt_cat_log
            $opt_tail_log
            $opt_perl_log
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
            $opt_editor
            $opt_prefix_distdir
            $opt_no_editor_defaults
            $opt_last_dist
            $opt_ls_bug
            $opt_checksum
            $opt_progress
            $opt_dry_run
            $opt_world_readable
            $opt_debug 
            $opt_version
            );


my $sc_version= "1.6";

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
                  '--mirror',
                  '--rm-lock',
                  '--mk-lock',
                  '--rebuild-last',
                  '--ls',
                  '--cat-log',
                  '--tail-log',
                  '--perl-log',
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
                     REMOTEPATH 
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

my $gbl_rsync_opts="-a -u -z --delete";

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
               RSYNC_DIST_CHECKSUM  => \$opt_checksum,
               RSYNC_DIST_EDITOR => \$opt_editor,
               RSYNC_DIST_EDITOR_NO_DEFAULTS => \$opt_no_editor_defaults,
               RSYNC_DIST_SHOW_PROGRESS => \$opt_progress,
               RSYNC_DIST_TAG => \$opt_tag,
               RSYNC_DIST_MESSAGE => \$opt_message,
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
               RSYNC_DIST_CHECKSUM =>
                                  "use checksum to detect file changes",
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
                                  "and change-links commands"                                     
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
RSYNC_DIST_EDITOR 
RSYNC_DIST_EDITOR_NO_DEFAULTS
RSYNC_DIST_SHOW_PROGRESS
RSYNC_DIST_TAG
RSYNC_DIST_MESSAGE
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
                "mirror=s",
                "rm_lock|rm-lock=s",
                "mk_lock|mk-lock=s",
                "rebuild_last|rebuild-last",

                "ls=s",
                "cat_log|cat-log=s",
                "tail_log|tail-log=s",
                "perl_log|perl-log=s",
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
                
                "editor=s",
                "no_editor_defaults|no-editor-defaults|N!",
                "prefix_distdir|prefix-distdir!",               
                "last_dist|last-dist|L",
                "ls_bug|ls-bug",
                "checksum",
                "progress",
                "dry_run|dry-run",
                "world_readable|world-readable|w",

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
  { $gbl_rsync_opts .= " --progress"; };

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

if ($opt_localprefix)
  { @opt_localpaths= map{ File::Spec->catfile($opt_localprefix,$_) }
                          @opt_localpaths;
  }  

if ($opt_debug)
  { $debug= $opt_debug; }

# ------------------------------------------------

if (defined $opt_ls)
  { my($arg,$rpath,$log,$chg)= dir_dependant($opt_ls);
    ls(\@opt_hosts,\@opt_users,$rpath);
    exit(0);
  }

if ((defined $opt_cat_log) || (defined $opt_perl_log))
  { my $dump_perl= (defined $opt_perl_log);
    my $dirname= ($dump_perl) ? $opt_perl_log : $opt_cat_log;
    my($arg,$rpath,$log,$chg)= dir_dependant($dirname);
    
    my $rc= cat_file_(\@opt_hosts,\@opt_users,$rpath,
                                $log,undef,$dump_perl);
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
    ls_tag(\@opt_hosts,\@opt_users,$rpath,$opt_ls_tag);
    exit(0);
  }

if (defined $opt_ls_version)
  { my($arg,$rpath,$log,$chg)= dir_dependant('dist');
    ls_version(\@opt_hosts,\@opt_users,$rpath,$opt_ls_version);
    exit(0);
  }

if (defined $opt_rm_lock)
  { my($arg,$rpath,$log,$chg)= dir_dependant($opt_rm_lock);
    my $rc= 
      server_lock(\@opt_hosts,\@opt_users,$rpath,'remove');
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

if ($opt_mirror)
  { my($arg,$rpath,$log,$chg)= dir_dependant($opt_mirror);
    my $rc=
      mirror(\@opt_hosts,\@opt_users,$rpath);
    exit($rc ? 0 : 1);
  }

if (defined $opt_change_links)
  { my($arg,$rpath,$log,$chg)= dir_dependant('links');
    my $rc=
      change_link(0, \@opt_hosts,\@opt_users,$rpath,$opt_message,$opt_change_links);
    exit($rc ? 0 : 1);
  }

if (defined $opt_add_links)
  { my($arg,$rpath,$log,$chg)= dir_dependant('links');
    my @files;
    my $source;
    my $rc=
      change_link(1, \@opt_hosts,\@opt_users,$rpath,$opt_message,$opt_add_links);
    exit($rc ? 0 : 1);
  }

if (defined $opt_dist)
  { my($arg,$rpath,$log,$chg)= dir_dependant('dist');
    my $rc= 
      dist(\@opt_hosts,\@opt_users,$rpath,\@opt_localpaths, 
           $opt_message, $opt_tag, 
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
       $remote_path, $r_local_paths,
       $logmessage, $tag,
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

    my($now,$local_host,$local_user,$from)= local_info();
    
    # start to create hash for local logfile:
    my $r_log= new_log_hash($now,
                            $local_host,$local_user,
                            $r_hosts_users,
                            $remote_path,
                            'distribute');
    
    foreach my $l (@$r_local_paths)
      { if (!-d $l)
          { die "error: directory \"$l\" not found"; };
      };          

    # convert relative to absolute paths based on
    # the current value of the "PWD" environment variable:
    my $pwd= $ENV{PWD};
    my $local_paths=  
       join(" ", (map { File::Spec->rel2abs($_,$pwd) } @$r_local_paths));

    my $rsync_opts= $gbl_rsync_opts . " --copy-unsafe-links";
    $rsync_opts.= " -c" if ($opt_checksum);
  
    my $log= DIST_LOG;
    my $chg= DIST_CHANGES;

    if (!internal_server_lock($r_hosts_users,$remote_path,'create'))
      { die "ERROR: locking of the servers failed"; };
      
    my $datestr= datestring();
    $r_log->{LOCALDATE}= $datestr;
      
    my $rcmd= sh_handle_attic($log,$chg) .
              ' && ' .
              "echo $datestr > STAMP && " .
              'if test -e LAST ; ' .
              'then cp -a -l `cat LAST` `cat STAMP`; ' .
              'fi ' .         
              ' && ' .
              "for l in $local_paths;" .
              "do rsync $rsync_opts " .
                 "-e \"ssh -l $local_user \" " .
                 "$local_host:\$l" .' ./`cat STAMP`;' .
              'done';
              
    if ($world_readable)
      { $rcmd.= ' && chmod -R a+rX `cat STAMP`'; };
    $rcmd.=           
              ' && ' .
              "echo \"%%\" >> $log && " .
              "echo VERSION: `cat STAMP` >> $log && " .
              "echo ACTION: added >> $log && " .
              sh_add_log($log,$from,$logmessage,$tag) . ' && ' .
              "echo \"\" >> $chg && cat STAMP >> $chg && " .
              'if test -e LAST;' .
              "then echo CHANGED/ADDED FILES relative to `cat LAST`: >> $chg ;" .
              "else echo ADDED FILES: >> $chg;" .
              'fi' .
              ' && ' .
              'find `cat STAMP` -links 1 >> ' . $chg . ' && ' .
              'cp STAMP LAST && ' .
              'sleep 1 && ';
#die $rcmd;
    $rcmd.=           
              'echo `cat STAMP` was created && ' .
              'rm -f STAMP';

    my $all_rc=1;
    foreach my $r (@$r_hosts_users)
      { my($remote_host, $remote_user)= @$r;
        if ($#$r_hosts_users>0)
          { print "\nHost:$remote_host:\n"; }

         my($rc)= myssh_cmd($remote_host, $remote_user, $remote_path, 
                            $rcmd, 1);
        $all_rc&= $rc;
        if (!$rc)
          { warn "(command failed)\n"; };
      };

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
    $r_log->{VERSION}= $datestr;
    
    append_single_log($gbl_local_log,$r_log,\@gbl_local_log_order);
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

    if (!internal_server_lock($r_hosts_users,$remote_path,'create'))
      { die "ERROR: locking of the servers failed"; };

    my $all_rc=1;
    foreach my $r (@$r_hosts_users)
      { my($remote_host, $remote_user)= @$r;
        if ($#$r_hosts_users>0)
          { print "\nHost:$remote_host:\n"; }
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
  { my($do_add, $r_hosts,$r_users, $remote_path, $logmessage,
       $linkparam )= @_;

    my @files;
    my $remote_source;

    if (($opt_prefix_distdir) && (!defined $opt_distpath))
      { warn "warning: dist-path not specified, --prefix-distdir ignored\n"; 
        $opt_prefix_distdir= undef;
      };

    # read the link-parameter if it is defined
    # it should be <source-dir>,<filemask>
    if (defined $linkparam)
      { @files= split(/[,\s:]+/,$linkparam);
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
                    $remote_source= shift @files; 
                  };
              };
          };
      }
      
    if ($opt_prefix_distdir)
      { # prepend distpath to remote_source:
        $remote_source= File::Spec->catfile($opt_distpath,$remote_source); 
      };   

    # if $remote_source is defined and --last-dist is given:
    if ($opt_last_dist)
      { if ((!defined ($remote_source)) || ($remote_source eq ""))
          { $remote_source= last_ver(); }
        else
          { $remote_source= File::Spec->catfile($remote_source,
                                                last_ver()); 
          };
      }

    $remote_source=~ /\/$/; # remove trailing "/"         

    my $r_hosts_users= ensure_host_users($r_hosts,$r_users);
    
    if (empty($remote_path))
      { ensure_var(\$remote_path   , 'REMOTEPATH' ,
                   take_default('distribute:REMOTEPATH',
                                'links:REMOTEPATH',
                                'move:REMOTEPATH'));
      };

    if (empty($remote_source))
      { ensure_var(\$remote_source  , 'SOURCE_DIR' ,
                   take_default('links:SOURCEDIR'));
      };

    my $r_files= \@files;
    if (empty($r_files))
      { ensure_var(\$r_files      , 'FILEMASK' ,
                   take_default('links:FILES'));
      };

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
    my $r_log= new_log_hash($now,
                            $local_host,$local_user,
                            $r_hosts_users,
                            $remote_path,
                            $do_add ? 'add links' : 'change links');

    
    my $log= LINK_LOG;
    
    my $files= join(" ",@$r_files);
    my $rcmd= 
              "if ! test -e $remote_source; " .
              "then echo error: \"$remote_source does not exist\" && " .
                    "exit $my_errcode; " .
              'fi && ' .
              sh_handle_attic($log);
                
    if ($do_add)
      { $rcmd.= ' && ' . sh_must_all_not_exist(@$r_files)  . ' && ';
      }
    else        
      { $rcmd.= ' && ' . sh_must_all_be_symlinks(@$r_files) . ' && ' .
                'ls -l ' . $files;
        $rcmd.= " 2>/dev/null" if ($opt_ls_bug);
        $rcmd.= ' > OLD && ' 
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
                'do rm -f $l && ' .
                  "ln -s $remote_source \$l; " .
                'done && ' .
                "echo \"%%\" >> $log && " .
                "echo DATE: $datestr >> $log && " .
                sh_add_log($log,$from,$logmessage,undef) . ' && ' .
                sh_add_symlink_log($log,$do_add,@$r_files) . ' && ' .
                
                'find . -type l -printf "%l %f\n" ' .
                "| sort | grep \"^$source_base\" | sed -e \"s/^.*\\///\" " .
                "> $linklog " ;
                
    my $all_rc=1;
    foreach my $r (@$r_hosts_users)
      { my($remote_host, $remote_user)= @$r;
        if ($#$r_hosts_users>0)
          { print "\nHost:$remote_host:\n"; }
        my($rc)= myssh_cmd($remote_host, $remote_user, $remote_path, $rcmd);
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
       $remote_path, $filename, $tailpar, $perlify) = @_;
   
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
    foreach my $r (@$r_hosts_users)
      { my($remote_host, $remote_user)= @$r;
        if ($#$r_hosts_users>0)
          { print "\nHost:$remote_host:\n"; }

        my($rc,$r_lines)= myssh_cmd($remote_host, $remote_user, $remote_path, 
                                    $rcmd, 1, 1);

       $all_rc&= $rc;
        if (!$rc)
          { warn "(command failed)\n"; 
            next;
          };
        if ($perlify)
          { 
            my $r_h= maillike::parse($r_lines,recordseparator=>"%%");
            my $name= $filename;
            $name=~ s/-/_/g;
            print Data::Dumper->Dump([$r_h],[$name]);
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
       $remote_path) = @_;
   
    my $r_hosts_users= ensure_host_users($r_hosts,$r_users);
    if (empty($remote_path))
      { ensure_var(\$remote_path, 'REMOTEPATH',
                   take_default('distribute:REMOTEPATH',
                                'links:REMOTEPATH'));
      };                           

    my $rcmd= "ls -l";
    $rcmd.= " 2>/dev/null" if ($opt_ls_bug);

    my $all_rc=1;
    foreach my $r (@$r_hosts_users)
      { my($remote_host, $remote_user)= @$r;
        if ($#$r_hosts_users>0)
          { print "\nHost:$remote_host:\n"; }
        my($rc)= myssh_cmd($remote_host, $remote_user, $remote_path, $rcmd);
       $all_rc&= $rc;
       if (!$rc)
          { warn "(command failed)\n"; };
      };
    return($all_rc);
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
    if    ($action eq 'remove')
      { $rcmd= "rm -f LOCK"; }
    elsif ($action eq 'create')
      { 
        my $from= $local_user . '@' . $local_host;
        $rcmd= sh_mklock($from)
      }
    else
      { die "assertion: unknown action: \"$action\""; };
      
    my @locked;
    foreach my $r (@$r_hosts_users)
      { my($remote_host, $remote_user)= @$r;

        if ($recursion)
          { warn "trying to $action lock on $remote_host...\n"; };

        my($rc)= myssh_cmd($remote_host, $remote_user, $remote_path, $rcmd);
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
        if ($#$r_hosts_users>0)
          { print "\nHost:$remote_host:\n"; }
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
    for(my $i=1; $i<=$#$r_hosts_users; $i++)
      { push @m_hosts, $r_hosts_users->[$i]->[0]; };
    
    my $rcmd= sh_copy_to_hosts($remote_path,@m_hosts);

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
       $remote_path, $version) = @_;
   
    my $r_hosts_users= ensure_host_users($r_hosts,$r_users);
    if (empty($remote_path))
      { ensure_var(\$remote_path, 'REMOTEPATH',
                   take_default('distribute:REMOTEPATH',
                                'links:REMOTEPATH'));
      };                           

    die "tag missing" if (empty($version));

    my $log= DIST_LOG;

    my $rcmd= "if ! test -e $log; then ".
                "echo file $log not found ;" .
              'else ' .
                "grep -B 3 -A 1 TAG $log | " .
                "grep -A 4 \"VERSION: $version\" ; " . 
                'if test $? -eq 1; ' .
                'then echo not found;' .
                'fi; ' .
              'fi';
    
    my $all_rc=1;
    foreach my $r (@$r_hosts_users)
      { my($remote_host, $remote_user)= @$r;
        if ($#$r_hosts_users>0)
          { print "\nHost:$remote_host:\n"; }
        my($rc)= myssh_cmd($remote_host, $remote_user, $remote_path, $rcmd);
        $all_rc&= $rc;
        if (!$rc)
          { warn "(command failed)\n"; };
      };
    return($all_rc);
  }
 
sub ls_tag
  { my($r_hosts,$r_users,
       $remote_path, $tag) = @_;
   
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
                "grep '\"'\"'TAG:.*" . $tag . "'\"'\"' $log -B 3 -A 1 ;" .
                'if test $? -eq 1; ' .
                'then echo not found;' .
                'fi; ' .
              'fi';
    
    my $all_rc=1;
    foreach my $r (@$r_hosts_users)
      { my($remote_host, $remote_user)= @$r;
        if ($#$r_hosts_users>0)
          { print "\nHost:$remote_host:\n"; }
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

sub sh_copy_to_hosts
  { my($remote_path,@hosts)= @_;
    my $hosts= join(" ",@hosts);
  
    return( "for h in $hosts; " . 
            "do rsync $gbl_rsync_opts -H " .
              "-e \"ssh \" . \$h:$remote_path; " .
            'done' );   
  }   
    
 
sub sh_add_log
  { my($logfile,$from,$message,$tag)= @_;
  
    my $str= "echo FROM: $from >> $logfile";
    if (defined $tag)
      { $str.= ' && ' . 
               "echo \"TAG: $tag\" >> $logfile";
      };       
    if (defined $message)
      { $str.= ' && ' .
               'echo LOG: "' . $message . "\" >> $logfile"; 
      };
    return($str);
  }  

sub sh_mklock
  { my($from)=@_;
  
    my $showlock= 'ls -l LOCK';
       $showlock.= ' 2>/dev/null' if ($opt_ls_bug);
       $showlock.= ' | sed -e "s/.*-> //"';

    return("ln -s $from LOCK; " .
           "if [ $? -ne 0 ]; " .
           'then echo LOCKED by`' . $showlock . '`; ' .
                "exit $my_errcode; " .
           'fi');
  }        

sub sh_handle_attic
  { my(@files)= @_;
    my $files= join(" ",@files);
  
    return( 'if ! test -d attic;' .
            'then mkdir attic; ' .
            'fi && ' .
            "cp $files attic 2>/dev/null; true"
            );
  }         
            
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
  { my($log,$added,@files)= @_;

    my $files= join(" ",@files);

    my $str;
    if ($added)
      { $str= "echo \"ADDED:\" >> $log && ";
      }
    else
      { $str= "echo \"OLD:\" >> $log && " .
              "cat OLD >> $log && rm -f OLD && " .
              "echo \"NEW:\" >> $log && ";     
      };
    $str.= 'ls -l ' . $files;
    $str.= ' 2>/dev/null' if ($opt_ls_bug);
    $str.= ' | tee -a ' . $log;
    return($str);
  }    

sub sh_rebuild_LAST
  { my $str= 'ls --indicator-style=none -d [12]* ';
    $str.= ' 2>/dev/null' if ($opt_ls_bug);
    $str.= ' | sort | tail -n 1 > LAST';
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
  { # take the last distributed version from the
    # local log-file

    get_last_log_entries(\$gbl_last_locallog_entries);

    if (!defined $gbl_last_locallog_entries)
      { die "error: local log-file \"$gbl_local_log\" not found\n" .
            "or no last distribution info found in this file";
      };
 
    return($gbl_last_locallog_entries->{distribute}->{VERSION});
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
    foreach my $r (@$r_hosts_users)
      { push @remote_hosts, $r->[0];
        push @remote_users, $r->[1]; 
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
      { die "assertion: reftype:\"$reftype\""; };
       
    return(1) if (!defined $st);
    return(1) if ($st eq "");
    return;
  }

# ------------------------------------------------
# ssh execution
# ------------------------------------------------

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
      { $cmd= "(cd $path && $cmd)"; };
      
    # -A: turn agent forwarding on 
    my $ssh_cmd= "ssh -A $host '$cmd'";
    
    if ($opt_dry_run)
      { print $ssh_cmd,"\n"; 
        return(1);
      }
    else
      { return(mysys($ssh_cmd, $do_catch, $silent)); }
      
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
      { $rc= system($cmd); };
      
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
          { $env{$key}= [split(/[,\s:]+/,$val)]; }
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

        system("$opt_editor " . $tmp->filename);

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
          { 
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
            $result= process_user_and_hostname(\@strs);       
          }
        elsif ($#$r_users<0)
          { # no users may be ok, when they are supplied with the
            # hostnames in the form "user@hostname"
            $result= process_user_and_hostname($r_hosts);             
            $r_hosts= [];
          }
        else
          { $result= process_user_and_hostname($r_hosts,$r_users); };
          
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

sub process_user_and_hostname
# returns a list of [hostname,username] pairs
# either hosts and users are arrays, where at least 
# one hostname and one username is given or
# hosts is a list of "user@hostname" strings
  { my($r_hosts,$r_users)= @_;
    my @l;
    
    if ($#$r_hosts<0)
      { return("no hosts"); }; # no hostnames given
    
    for(my $i=0; $i<= $#$r_hosts; $i++)
      { if ($r_hosts->[$i]=~ /^\s*(\S+)\@(\S+)\s*$/)
          { # format: "user@hostname"
            push @l, [$2,$1];
            next;
          };
        # here: simple hostname
        my $user= $r_users->[$i];
        if (!defined $user) # user-array shorter than hostname array
          { $user= $r_users->[-1]; # take last element of array
            if (!defined $user)
              { return("no users"); # error, username missing
              };
          };
        push @l, [$r_hosts->[$i],$user];
      };
    return(\@l);
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

    mirror --mirror [dist|d|links|l]
                mirror the specified directory from the first
                given host to all following ones. 
                Caution: you may delete data on the secondary
                hosts that you wanted to keep, think twice before
                running this command

    rm-lock --rm-lock [dist|d|links|l]
    
                remove the lockfile in the "dist" or "links"
                directory in case it was left behind due to an 
                error in the script
                (for distribution or links)

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
                specify the remote host. A list of secondary 
                remote-hosts can be added separated by a commas or
                spaces or colons
                if this option is not given the script tries to read from
                the environment variable "RSYNC_DIST_HOST"      
    --user -u [remote-user[,remote-user2...]]
                specify the user for login on the remote host
                if this option is not given the script tries to read from
                the environment variable "RSYNC_DIST_USER"      

  options to specify directories:

    --distpath -p [remote-dist-path] 
                specify the remote directory
                if this option is not given the script tries to read from
                the environment variable "RSYNC_DIST_PATH"      

    --linkpath -P [remote link-path]
                specify the remote directory
                if this option is not given the script tries to read from
                the environment variable "RSYNC_DIST_LINKPATH"  
    
    --localpath -l [local-path,local-path2...] 
                specify the local path
                if this option is not given the script tries to read from
                the environment variable "RSYNC_DIST_LOCALPATH" 
                Several paths can be specified with either a comma-separated 
                list or several -l options

    --localprefix [prefix]
                this prefix is prepended to all paths given to
                the localpath option
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
                specify a tag for the distribution
                if this option is not given the script tries to read from
                the environment variable "RSYNC_DIST_TAG"       
                if this option is given without being followed by a 
                tag-string, an empty tag is used        

    --autotag   (only for the "dist" commannd)
                take the tag from the last distributed version and
                increment the number at the end of this tag by one.
                This is an alternative to the "--tag" option

  options for the management of pre-defined parameters:

    --config -c [filename]
                read variables from a configuration file. The format
                is simple <name>=<value>
                Empty lines and lines starting with "#" are ignored.
                Spaces around the "=" sign are also ignored. Array values
                are specifed as comma-separated lists.
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
                RSYNC_DIST_CHECKSUM
                  when set to 1, use checksums to detect changes in files.
                  see also --checksum 
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

                Note that command-line arguments always override 
                values taken from the config-file.   


    --env       By supplying this option, the program can take all
                variables mentioned above (see --config) from the 
                unix-shell environment.  
    
  miscellaneous options:

    --editor [editor]
                specifiy the interactive editor. 
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
                (use editor defaults). Since this is the default behaviour, 
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
                this is the default behaviour, this option is only needed
                in order to override a different setting taken from
                a config file  

    --last-dist -L
                append the name of the last distribution that was
                made to the "source" part of the add-links or
                change-links command            
   
    --ls-bug    suppress 
                "ls: ignoring invalid width in environment variable COLUMNS: 0"
                warning that comes on some systems              

    --checksum  use checksums instead of date-comparisons when deciding 
                wether a file should be transferred

    --progress  use the rsync "progress" option to show the progress
                of rsync on screen
    
    --dry-run   just show the command that would be executed    

    --world-readable -w
                make all files world-readable   
END
  }
__END__
# Below is the short of documentation of the script

=head1 NAME

rsync-dist.pl - a Perl script for managing distributions of binary files

=head1 SYNOPSIS

 rsync-dist.pl -H remote_server -p remote_dir  -l localdir 
                 -m version1 -d 
 
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

a lock file is created before critical actions on the server, so
several instances of this script can be started at the same sime
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

=head2 prerequisites

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

=head2 distributing files

In order to distribute files the user must at least specify the
remote-server-name, the remote-path, the local-path and a log-message a. 
Example:

  rsync-dist.pl -H <remote-server-name> -p <remote-path> 
                  -l <local-path> -m <log-message> dist

Note that the local and remote-path are relative to the user-home
unless the paths start with a '/'.


Additionally the user may specify his account-name on the remote machine
(especially when this is different from his account on the local machine),
and a tag. Example: 

  rsync-dist.pl -H <remote-server-name> -p <remote-path> 
                  -l <log-message> -m <log-message> -u <remote-user>
                  -t <tag> dist

The tag should be a one-line string that can later be used to identify
or search for the current distribution of files. 

=head2 inspecting a remote directory with distributed files

The remote directly can be listed with this command:

  rsync-dist.pl -H <remote-server-name> -p <remote-path> 
                  ls dist
                  
Note that you can optionally specify the remote user. All other
options are ignored. Since the command has a higher priority that the
distribution command "dist", it overrides the distribution command when
appended at the end of the parameter list. So this works too: 

  rsync-dist.pl -H <remote-server-name> -p <remote-path> 
                  -l <log-message> -m <log-message> -u <remote-user>
                  -t <tag> dist ls dist

The "dist" after "ls" means that the distribution directory is listed.
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

=head2 listing the CHANGES-DIST file

The file CHANGES-DIST, as it is described above, can be listed with this command:

  rsync-dist.pl -H <remote-server-name> -p <remote-path> 
                  cat-changes 

=head2 listing the LOG-DIST file

The file LOG-DIST, as it is described above, can be listed with this command:

  rsync-dist.pl -H <remote-server-name> -p <remote-path> 
                  cat-log dist

The "dist" after "cat-log" means that logfile of the distribution directory 
is listed.

=head2 searching for tags

The log-file can be searched for a given tag or a (grep compatible)
regular expression that matches one or more tags. Example:

  rsync-dist.pl -H <remote-server-name> -p <remote-path> 
                  ls-tag <tag or regexp>

A real-world example: 
  rsync-dist.pl -H sioux.blc.bessy.de -u idadm -p z ls_tag TAG

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

=head2 managing symbolic links

Although the script manages symbolic links in a generic way, the intention
of this feature is to manage startup-scrips of IOCs. The startup-script
determines which version of its application the IOC will boot. By letting the
IOC boot via a symbolic link to a script, there is an easy way to change the 
active version of the IOC's software without logging onto the IOC itself.

=head2 the log-file in the source directory


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
"opt/IOC/Releases/idcp/links" there is a symblic link
named "idcp12" that references the distribution-directory 
"2006-10-09T10:28:13"-

=head2 adding symbolic links

Symbolic links are added like this:

  rsync-dist.pl -H <remote-server-name> -p <remote-path>
                  -m <log-message> 
                  add-links <remote-sourcepath>,<link1>,<link2>...
  
Note that if at least one the given links already exists, the command fails.
Note too, that the given remote-path must exist. The log-file is updated 
when this command is run.

=head2 changing symbolic links

Symbolic links are changed like this:

  rsync-dist.pl -H <remote-server-name> -p <remote-path>
                  -m <log-message> 
                  change-links <remote-sourcepath>,<link1>,<link2>...

or

  rsync-dist.pl -H <remote-server-name> -p <remote-path>
                  -m <log-message> 
                  change-links <remote-path>,<filemask>...

  
Note that (especially in case one) all of the given link-names must
exist and must be symbolic links. The log-file is updated 
when this command is run.

=head2 inspecting the remote link-directory

The remote directly can be listed with this command:

  rsync-dist.pl -H <remote-server-name> -p <remote-path> 
                  ls links
                  
Note that you can optionally specify the remote user. All other
options are ignored. Since the command has a higher priority that the
other link commands, it overrides the them when
appended at the end of the parameter list. So this works too: 

  rsync-dist.pl -H <remote-server-name> -p <remote-path>
                  -m <log-message> 
                  change-links <remote-path>,<filemask> ls links

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

=head2 listing the LOG-LINKS file

The file LOG-LINKS, as it is described above, can be listed with this command:

  rsync-dist.pl -H <remote-server-name> -p <remote-path> 
                  cat_log links

The "links" after "cat_log" means that the logfile of the link directory
is listed.

=head2 using a configuration file

Certain values like the name of the remote host or the 
directory on the remote-host can be stored in a configuation file. 
The program can then read that configuration file in order to obtain
these values. Such a file is easy to create. Example:

  rsync-dist.pl -H myhost -u myuser -p /dist-dir -P /link-dir\
      --checksum show-config
      
This command prints the contents of such a file to the screen where
all settings match the ones given as commandline parameters. Here is how
you create that file directly:

  rsync-dist.pl -H myhost -u myuser -p /dist-dir -P /link-dir\
      --checksum write-config MYCONFIG
   
You can easily extend this file. Here is for example, how you
add the "world-readable" option:

  rsync-dist.pl --config MYCONFIG --world-readable write-config MYCONFIG
 
Later on, you can start a distribution command like this:

  rsync-dist.pl --config MYCONFIG dist
  
The program takes all parameter from "MYCONFIG". Parameters it needs but
that are still not specified (like the local path) are requested from
the user interactively by starting an editor (default: vi).  

=head2 tips and tricks (logging onto the server required)

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

=head1 AUTHOR

Goetz Pfeiffer,  goetzp@gmx.net

=head1 SEE ALSO

rsync-documentation

=cut



=


