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

use vars qw($opt_help $opt_summary $opt_debug 
            $opt_dist $opt_user 
	    $opt_path
	    $opt_linkpath
	    $opt_message 
	    $opt_cat_log $opt_cat_changes
	    $opt_tail_log $opt_tail_changes
	    $opt_tag
	    $opt_ls 
	    $opt_rm_lock
	    $opt_mk_lock
	    $opt_add_links
	    $opt_change_links
	    $opt_ls_tag 
	    $opt_ls_version
	    $opt_links
	    $opt_man
	    $opt_dry_run
	    $opt_ls_bug
	    $opt_checksum
	    $opt_to_attic
	    $opt_from_attic
	    $opt_world_readable
	    $opt_show_env
            );


my $sc_version= "1.0";

my $sc_name= $FindBin::Script;
my $sc_summary= "rsync-deploy in perl"; 
my $sc_author= "Goetz Pfeiffer";
my $sc_year= "2006";

my $debug= 0; # global debug-switch

my @hosts;
my @localpaths;

my $dist_log= 'LOG-DIST';
my $link_log= 'LOG-LINKS';

my $dist_changes= 'CHANGES-DIST';
my $link_changes= 'CHANGES-LINKS';

my %env_opts= (RSYNC_DIST_HOST      => [\@hosts, '--host'],
               RSYNC_DIST_USER      => [\$opt_user, '--user'],
	       RSYNC_DIST_PATH      => [\$opt_path, '--path'],
	       RSYNC_DIST_LINKPATH  => [\$opt_linkpath, '--linkpath'],
	       RSYNC_DIST_LOCALPATH => [\@localpaths, '--localpath'],
	       RSYNC_DIST_MESSAGE   => [\$opt_message, '--message'],
	       RSYNC_DIST_TAG       => [\$opt_tag, '--tag']
	      );

if (!@ARGV)
  { $opt_man= 1; };
  
# catch things like "-ls", Getopt::Long would otherwise
# take this as "-l s" ...

foreach my $opt (@ARGV)
  { die "unknown option: $opt" if ($opt=~ /^-[^-]{2,}/); };
  
Getopt::Long::config(qw(no_ignore_case));

if (!GetOptions("help|h","summary","host|H=s" => \@hosts,
                "debug",
		"dist|d:s", "user|u=s", 
		"path|p=s",
		"linkpath|P=s",
		"localpath|l=s" => \@localpaths,
		"message|m=s",
		"cat_log|cat-log|c",
		"tail_log|tail-log:i",
		"cat_changes|cat-changes",
		"tail_changes|tail-changes:i",
		"ls",
		"rm_lock|rm-lock",
		"mk_lock|mk-lock",
		"change_links|change-links|C=s",
		"add_links|add-links=s",
		"tag|t=s",
		"ls_tag|ls-tag|T=s",
		"ls_version|ls-version=s",
		"links",
		"man", "dry_run|dry-run",
		"ls_bug|ls-bug",
		"checksum",
		"to_attic|to-attic=s",
		"from_attic|from-attic=s",
		"world_readable|world-readable|w",
		"show_env|show-env"
                ))
  { die "parameter error!\n"; };

if ($opt_help)
  { help();
    exit;
  };

if ($opt_man)
  { exec("perldoc $0"); };

@hosts = split(/[,\s:]+/,join(',',@hosts));

@localpaths = split(/[,\s:]+/,join(',',@localpaths));

if ($opt_show_env)
  { process_environment(\%env_opts, 1); 
    exit(0);
  }
else 
  { process_environment(\%env_opts);
  };

if ($opt_summary)
  { print_summary();
    exit;
  };

if ($opt_debug)
  { $debug= $opt_debug; }

# ------------------------------------------------

my $log = $dist_log;
my $chg = $dist_changes;
my $path= $opt_path;

if ((defined $opt_links) || (defined $opt_change_links) || (defined $opt_add_links))
  { $log = $link_log; 
    $chg = $link_changes; 
    $path= $opt_linkpath if (defined $opt_linkpath);
  }

if (defined $opt_ls)
  { ls($hosts[0],$opt_user,$path);
    exit(0);
  }

if (defined $opt_cat_log)
  { cat_file($hosts[0],$opt_user,$path,$log);
    exit(0);
  }

if (defined $opt_cat_changes)
  { cat_file($hosts[0],$opt_user,$path,$chg);
    exit(0);
  }

if (defined $opt_tail_log)
  { cat_file($hosts[0],$opt_user,$path,$log,$opt_tail_log);
    exit(0);
  }

if (defined $opt_tail_changes)
  { cat_file($hosts[0],$opt_user,$path,$chg,$opt_tail_changes);
    exit(0);
  }

if (defined $opt_ls_tag)
  { ls_tag($hosts[0],$opt_user,$path,$opt_ls_tag);
    exit(0);
  }

if (defined $opt_ls_version)
  { ls_version($hosts[0],$opt_user,$path,$opt_ls_version);
    exit(0);
  }

if (defined $opt_rm_lock)
  { rm_lock($hosts[0],$opt_user,$path,'remove');
    exit(0);
  }

if (defined $opt_mk_lock)
  { rm_lock($hosts[0],$opt_user,$path,'create');
    exit(0);
  }

if (defined $opt_change_links)
  { my @files= split(/,/,$opt_change_links);
    my $source= shift @files;
    die "source missing" if (!defined $source);
    if ($source=~ /local:(.*)/)
      { $source= ver_from_file($1); };
    change_link(0, $hosts[0],$opt_user,$path,$opt_message,$source,@files);
    exit(0);
  }

if (defined $opt_add_links)
  { my @files= split(/,/,$opt_add_links);
    my $source= shift @files;
    die "source missing" if (!defined $source);
    if ($source=~ /local:(.*)/)
      { $source= ver_from_file($1); };
    change_link(1, $hosts[0],$opt_user,$path,$opt_message,$source,@files);
    exit(0);
  }

if (defined $opt_dist)
  { dist(\@hosts,$opt_user,$path,\@localpaths, 
         $opt_message, $opt_tag,
  	 $opt_world_readable,
	 $opt_dist);
    exit(0);
  }
         
if (defined $opt_to_attic)
  { move_file($hosts[0],$opt_user,$path,$opt_to_attic, $opt_message, 1);
    exit(0);
  }
         
if (defined $opt_from_attic)
  { move_file($hosts[0],$opt_user,$path,$opt_from_attic, $opt_message, 0);
    exit(0);
  }
         

die "error: no command given!";

# fit in program text here

# ------------------------------------------------

sub dist
  { my($r_remote_hosts, $remote_user, 
       $remote_path, $r_local_paths,
       $logmessage, $tag, $world_readable,
       $locallog)= @_;

    die "remote_host missing" if (empty($r_remote_hosts));
    die "remote_path missing" if (empty($remote_path));
    die "log-message missing" if (empty($logmessage));
    die "local-path missing"  if (empty($r_local_paths));

    foreach my $l (@$r_local_paths)
      { if (!-d $l)
          { die "error: directory \"$l\" not found"; };
      };	  

    my @hosts= @$r_remote_hosts;

    my $remote_host= shift @hosts; 
    my $hosts= join(" ",@hosts);

    # convert relative to absolute paths based on
    # the current value of the "PWD" environment variable:
    my $pwd= $ENV{PWD};
    my $local_paths=  
       join(" ", (map { File::Spec->rel2abs($_,$pwd) } @$r_local_paths));

    my $local_host= my_hostname();
    my $local_user= username();
    my $from= $local_user . '@' . $local_host;

    my $rsync_opts= "-a -u -z --copy-unsafe-links --delete";
    $rsync_opts.= " -c" if ($opt_checksum);
  
    my $rcmd= sh_mklock($from) .
	      ' && ' .
              sh_handle_attic() .
	      ' && ' .
	      'date +%Y-%m-%dT%H:%M:%S > STAMP && ' .
	      'if test -e LAST ; ' .
	      'then cp -a -l `cat LAST` `cat STAMP`; ' .
	      'fi ' .         
	      ' && ' .
	      "for l in $local_paths;" .
	      "do rsync $rsync_opts " .
	         "-e \"ssh -l $local_user \" " .
	         "$local_host:\$l" .' `cat STAMP`;' .
	      'done';
    if ($world_readable)
      { $rcmd.= ' && chmod -R a+rX `cat STAMP`'; };
    $rcmd.=	      
	      ' && ' .
	      "echo \"\" >> $log && " .
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
    if (@hosts)
      { # distribute the binary-store to other hosts
        # while the lockfile is still present
        $rcmd.= "for h in $hosts; " . 
	        'do rsync -a -u -z -H --delete ' .
		  "-e \"ssh \" . \$h:$remote_path; " .
	        'done && ';
      };	
	
    $rcmd.=	      
	      'echo `cat STAMP` was created && ' .
	      'rm -f STAMP LOCK';

    my $r_l= ssh_cmd($remote_host, $remote_user, $remote_path, $rcmd, 1);
    
    if ($locallog ne "")
      { to_file($locallog, $r_l); };
    #print join("\n",@$r_l); 
  }    

sub move_file
  { my($remote_host, $remote_user, 
       $remote_path, $dir, $logmessage, $to_attic)= @_;

    die "remote_host missing" if (empty($remote_host));
    die "remote_path missing" if (empty($remote_path));
    die "the directory that is to move is missing" if (empty($dir));

    my $local_host= my_hostname();
    my $local_user= username();
    my $from= $local_user . '@' . $local_host;
 
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
   
    my $rcmd= 
        	sh_mklock($from) .
	        ' && ' .
                sh_handle_attic() .
	        ' && ' .
		'if test -e LINKS-*;' .
		"then grep $dir LINKS-*;" .
		     'if test $? -eq 0;' .
		     "then echo \"error: $dir is still in use (symlinks)\" && ".
		          'rm -f LOCK && exit 0;' .
		     'fi;' .
		'fi '.
	        ' && ' .
		"if ! test -d $dir;" . 
		"then echo $dir not found && " .
        	     'rm -f LOCK && exit 0;' . 
		'fi && ' .
                "mv $dir $dest && " . 
		"echo \"\" >> $log && " .
		"echo VERSION: $odir >> $log && " .
		"echo ACTION: $action >> $log && " .
	        sh_add_log($log,$from,$logmessage,undef) . ' && ' .
		sh_rebuld_LAST() . ' && ' .
		'rm -f STAMP LOCK';
    ssh_cmd($remote_host, $remote_user, $remote_path, $rcmd);
  }
	      

sub cat_file
  { my($remote_host, $remote_user, 
       $remote_path, $filename, $tailpar) = @_;
   
    die "remote_host missing" if (empty($remote_host));
    die "remote_path missing" if (empty($remote_path));
 
    my $rcmd;
    if (!defined $tailpar)
      { $rcmd= "cat $filename"; }
    else
      { if ($tailpar<=0)
          { $tailpar= 10; };
        $rcmd= "tail -n $tailpar $filename";
      };
    ssh_cmd($remote_host, $remote_user, $remote_path, $rcmd);
    
  }
  
sub ls
  { my($remote_host, $remote_user, 
       $remote_path) = @_;
   
    die "remote_host missing" if (empty($remote_host));
    die "remote_path missing" if (empty($remote_path));

    my $rcmd= "ls -l";
    $rcmd.= " 2>/dev/null" if ($opt_ls_bug);
    ssh_cmd($remote_host, $remote_user, $remote_path, $rcmd);
    
  }
  
sub rm_lock
  { my($remote_host, $remote_user, 
       $remote_path, $action) = @_;
   
    die "remote_host missing" if (empty($remote_host));
    die "remote_path missing" if (empty($remote_path));

    my $rcmd;
    if    ($action eq 'remove')
      { $rcmd= "rm -f LOCK"; }
    elsif ($action eq 'create')
      { my $local_host= my_hostname();
        my $local_user= username();
        my $from= $local_user . '@' . $local_host;
        $rcmd= sh_mklock($from)
      }
    else
      { die "assertion: unknown action: \"$action\""; };
      
    ssh_cmd($remote_host, $remote_user, $remote_path, $rcmd);
  }

sub ls_version
  { my($remote_host, $remote_user, 
       $remote_path, $version) = @_;
   
    die "remote_host missing" if (empty($remote_host));
    die "remote_path missing" if (empty($remote_path));
    die "tag missing" if (empty($version));

    my $rcmd= "if ! test -e $log; then ".
                "echo file $log not found ;" .
              'else ' .
	        "grep -B 3 -A 1 TAG $log | " .
		"grep -A 4 ^$version ; " . 
		'if test $? -eq 1; ' .
		'then echo not found;' .
		'fi; ' .
	      'fi';
    
    ssh_cmd($remote_host, $remote_user, $remote_path, $rcmd);
    
  }
 
sub ls_tag
  { my($remote_host, $remote_user, 
       $remote_path, $tag) = @_;
   
    die "remote_host missing" if (empty($remote_host));
    die "remote_path missing" if (empty($remote_path));
    die "tag missing" if (empty($tag));

    my $rcmd= "if ! test -e $log; then ".
                "echo file $log not found ;" .
              'else ' .
	        "grep '\"'\"'TAG:.*" . $tag . "'\"'\"' $log -B 3 -A 1 ;" .
		'if test $? -eq 1; ' .
		'then echo not found;' .
		'fi; ' .
	      'fi';
    
    ssh_cmd($remote_host, $remote_user, $remote_path, $rcmd);
    
  }
 
  
sub change_link
  { my($do_add, $remote_host, $remote_user, $remote_path, $logmessage,
       $remote_source, @files )= @_;
   
    die "remote_host missing" if (empty($remote_host));
    die "remote_path missing" if (empty($remote_path));
    die "remote source missing" if (empty($remote_source));
    die "error: no files specified" if (empty(\@files));


    my $local_host= my_hostname();
    my $local_user= username();
    my $from= $local_user . '@' . $local_host;

    if (!@files)
      { die "error: no files specified"; }
    
    my $files= join(" ",@files);
    my $rcmd= 
              "if ! test -e $remote_source; " .
	      "then echo error: \"$remote_source does not exist\"; " .
	      'else ' .
	        sh_mklock($from) .
	        ' && ' .
                sh_handle_attic();
		
    if ($do_add)
      { $rcmd.= ' && ' . sh_must_all_not_exist(@files)  . ' && ';
      }
    else	
      { $rcmd.= ' && ' . sh_must_all_be_symlinks(@files) . ' && ' .
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

#die "linklog:$linklog";
    
    $rcmd.= 	
		"for l in $files ; " .
        	'do rm -f $l && ' .
	          "ln -s $remote_source \$l; " .
		'done && ' .
		"echo \"\" >> $log && " .
		"date +\"VERSION: %Y-%m-%dT%H:%M:%S\" >> $log && " .
	        sh_add_log($log,$from,$logmessage,undef) . ' && ' .
                sh_add_symlink_log($log,$do_add,@files) . ' && ' .
		
		'find . -type l -printf "%l %f\n" ' .
		"| sort | grep \"^$source_base\" | sed -e \"s/^.*\\///\" " .
		"> $linklog && " .
		'rm -f STAMP LOCK; ' .
	       'fi';
    ssh_cmd($remote_host, $remote_user, $remote_path, $rcmd);
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
    return("while ln -s $from LOCK " . '2>/dev/null; [ $? -ne 0 ]; ' .
           'do ' .
             'echo waiting for LOCK by `' . $showlock . '`; ' .
             'sleep 1; ' .
	   'done');
  }	   

sub sh_handle_attic
  { return( 'if ! test -d attic;' .
            'then mkdir attic &&' .
	         "touch $dist_log && " .
		 "touch $dist_changes;" .
            'fi && ' .
	    'cp LOG-* CHANGES-* attic'
	    );
  }	    
	    
sub sh_must_all_be_symlinks
  { my(@files)= @_;
  
    my $files= join(" ",@files);
    
    return( "for l in $files; " .
              'do if ! test -h $l; ' .
	          'then echo error: $l does not exist or is not a symlink && ' .
		  'rm -f LOCK && exit 0; ' .
	          'fi; ' .
              'done' ); 
  }

sub sh_must_all_not_exist
  { my(@files)= @_;
  
    my $files= join(" ",@files);
    
    return( "for l in $files; " .
               'do if test -e $l; ' .
	          'then echo error: $l already exists && ' .
		  'rm -f LOCK && exit 0; ' .
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

sub sh_rebuld_LAST
  { my $str= 'ls --indicator-style=none -d [12]* ';
    $str.= ' 2>/dev/null' if ($opt_ls_bug);
    $str.= ' | sort | tail -n 1 > LAST';
    return($str);
  }

sub ver_from_file
  { my($filename)= @_;
    local(*F);
    open(F, "$filename") or die "unable to open $filename\n";
    my $line=<F>;
    $line=~ s/\s+was\s+created\s+$//;
    close(F);
    return($line);
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

sub empty
  { my($st)= @_;
  
    if (ref($st))
      { die "assertion:" . ref($st) if (ref($st) ne 'ARRAY');
        $st= $st->[0]; 
      };
    return(1) if (!defined $st);
    return(1) if ($st eq "");
    return;
  }

sub username
  { return((getpwuid($>))[0]); }

sub my_hostname
  { return((gethostbyname(hostname()))[0]); }

sub ssh_cmd
  { my($host, $user, $path, $cmd, $do_catch)= @_;

    if ($path!~ /^\//)
      { $path= '$HOME/' . $path; };

    if (defined $user)
      { $host= $user . '@' . $host; };
    
    if (defined $path)
      { $cmd= "(cd $path && $cmd)"; };
      
    # -A: turn agent forwarding on 
    my $ssh_cmd= "ssh -A $host '$cmd'";
    
    if ($opt_dry_run)
      { print $ssh_cmd,"\n"; }
    else
      { if (!$do_catch)
          { sys($ssh_cmd); }
	else
	  { return(sys_catch($ssh_cmd)); } 
      }
  }

sub sys_catch
  { my($cmd)= @_;
    local(*F);
    my @lines;
  
    print "$cmd\n" if ($debug);
    
    $cmd.= " 2>&1 |";
    # -e: environment overrides make
    open(F, $cmd) || die "can\'t fork: $!";
    while (my $line=<F>)
      {
#print $line;
       print $line;
       chomp($line);
       push @lines,$line;
      }
    close(F) || die "bad netstat: $! $?\n";
    return(\@lines);
  }

sub sys
  { my($cmd)= @_;
    print "$cmd\n" if ($debug);
    return if (0==system($cmd));
    #return if ($?==256);
    die "\"$cmd\" failed: $?";
  }

sub process_environment
  { my($r_env_opts,$show)= @_;
    my $env_val;
  
    foreach my $e (keys %$r_env_opts)
      { $env_val= $ENV{$e};
        next if (!defined $env_val);
	$env_val=~ s/^\s+//;
	$env_val=~ s/[\s\r\n]+$//;
        my($ref,$str)= @{$r_env_opts->{$e}};
	if    (ref($ref) eq 'SCALAR')
	  { if ($show)
	      { my $v= (defined $$ref) ? $$ref : $env_val;
	        print $str," ",$v," "; 
	        next;
	      }
	    next if (defined $$ref);
	    $$ref= $env_val;
	    next;
	  }
	elsif (ref($ref) eq 'ARRAY')
	  { if ($show)
	      { my $v= (@$ref) ? join(",",@$ref) : $env_val;
	        print $str," ",$v," "; 
	        next;
	      };
	    next if (@$ref);
	    @$ref= split(/[,\s:]+/,$env_val);
	    next;
          }
	else
	  { die "assertion!"; };
      };
    print "\n" if ($show);  
  }

sub print_summary
  { printf("%-20s: $sc_summary\n",
           $sc_name);
  }

sub h_center
  { my($st)= @_;
    return( (' ' x (38 - length($st)/2)) . $st );
  }

sub help
  { my $l1= h_center("**** $sc_name $sc_version -- $sc_summary ****");
    my $l2= h_center("$sc_author $sc_year");
    print <<END;

$l1
$l2

Syntax:
  $sc_name {options} [arg1] [arg2]

  options:
    -h: this help
    
    --man: show embedded manpage
    
    --summary:  give a summary of the script

  specify remote host and user:

    --host -H [remote-host[,remote-host2...]]
                specify the remote host. A list of secondary 
		remote-hosts can be added separated by a commas or
		spaces or colons
		if this option is not given the script tries to read from
		the environment variable "RSYNC_DIST_HOST"	
    --user -u [remote-user]
                specify the user for login on the remote host
		if this option is not given the script tries to read from
		the environment variable "RSYNC_DIST_USER"	

  specify directories:

    --path -p [remote-path/dist-path/link-path] 
                specify the remote directory
		if this option is not given the script tries to read from
		the environment variable "RSYNC_DIST_PATH" or 
		from "RSYNC_DIST_LINKPATH" (for link commands)	

    --linkpath -P [remote link-path]
                specify the remote directory
		if this option is not given the script tries to read from
		the environment variable "RSYNC_DIST_LINKPATH" 	
    
    --localpath -l [local-path,local-path2...] 
                specify the local path
		if this option is not given the script tries to read from
		the environment variable "RSYNC_DIST_LOCALPATH"	
		Several paths can be specified with either a comma-separated list
		or several -l options

  specify tags and log-messages:

    --message -m [logmessage] 
                specify a log message
		if this option is not given the script tries to read from
		the environment variable "RSYNC_DIST_MESSAGE"	

    --tag -t [tag]
                specify a tag for the distribution
		if this option is not given the script tries to read from
		the environment variable "RSYNC_DIST_TAG"	

  commands:

    --dist -d {filename}
                distribute files to remote host
		if {filename} is given, the name of the created directory
		is written to <filename>. Note that the file is overwritten
		if it exists before.

    --to-attic [dir] 
                move a directory (aka version) to the "attic" directory

    --from-attic [dir] 
                move a directory (aka version) from the "attic" directory
		back to the main directory (which is given by -p)

    --change-links -C [source,filemask/files]
                change symbolic links on the remote server
		if source is "local:<filename>" take the source-directory
		from the first line in file <filename>

    --add-links [source,files]
                add links on the remote server
		if source is "local:<filename>" take the source-directory
		from the first line in file <filename>

    --rm-lock 
                remove the lockfile in case is
		was left behind due to an error in the script

    --mk-lock 
                create the lockfile in the remote directory. This is
		useful in order to lock the directory for other users
		that run rsync-dist.pl when you want to modify files on
		the remote-host manually.

  inspect the remote directory:

    --ls 
                show the remote directory

    --cat-log -c 
                show the logfile (for distribution or links)

    --tail-log [n]
                show the last n lines of the logfile (for distribution or links)

    --ls-tag -T [tag/regexp]
                search for a tag in the log file

    --ls-version [version/regexp]
                search for a version  in the log file

    --cat-changes 
                show the changes-file

    --tail-changes [n]
                show the last n lines of the changes-file

  miscellanious:

    --ls-bug    suppress 
                "ls: ignoring invalid width in environment variable COLUMNS: 0"
                warning that comes on some systems		

    --checksum  use checksums instead of date-comparisons when deciding wether a
                file should be transferred

    --show-env  show the settings the program takes from environment
    	        variables (if not specified differently on the 
		command-line)

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
of that distributions. It can also create and change symbolic links
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

During distribution, files can be transferred from the central server 
to secondary servers which mirror all the files from the central server. 

=item *

a lock file is created before critical actions on the server, so
several instances of this script can be started at the same sime
by different people without interfering with each other

=item *

log-files are created that show when and by whom things were changed

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
                  -l <local-path> -m <log-message> -d

Note that the local and remote-path are relative to the user-home
unless the paths start with a '/'.


Additionally the user may specify his account-name on the remote machine
(especially when this is different from his account on the local machine),
and a tag. Example: 

  rsync-dist.pl -H <remote-server-name> -p <remote-path> 
                  -l <log-message> -m <log-message> -u <remote-user>
		  -t <tag> -d

The tag should be a one-line string that can later be used to identify
or search for the current distribution of files. 

=head2 inspecting a remote directory with distributed files

The remote directly can be listed with this command:

  rsync-dist.pl -H <remote-server-name> -p <remote-path> 
                  --ls
		  
Note that you can optionally specify the remote user. All other
options are ignored. Since the command has a higher priority that the
distribution command "-d", it overrides the distribution command when
appended at the end of the parameter list. So this works too: 

  rsync-dist.pl -H <remote-server-name> -p <remote-path> 
                  -l <log-message> -m <log-message> -u <remote-user>
		  -t <tag> -d --ls

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
the optional log message with may span several lines.

=back

=head2 listing the CHANGES-DIST file

The file CHANGES-DIST, as it is described above, can be listed with this command:

  rsync-dist.pl -H <remote-server-name> -p <remote-path> 
                  --cat-changes

=head2 listing the LOG-DIST file

The file LOG-DIST, as it is described above, can be listed with this command:

  rsync-dist.pl -H <remote-server-name> -p <remote-path> 
                  --cat-log

=head2 searching for tags

The log-file can be searched for a given tag or a (grep compatible)
regular expression that matches one or more tags. Example:

  rsync-dist.pl -H <remote-server-name> -p <remote-path> 
                  --ls-tag <tag or regexp>

A real-world example: 
  rsync-dist.pl -H sioux.blc.bessy.de -u idadm -p z --ls_tag TAG

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
		  --add-links <remote-sourcepath>,<link1>,<link2>...
  
Note that if at least one the given links already exists, the command fails.
Note too, that the given remote-path must exist. The log-file is updated 
when this command is run.

=head2 changing symbolic links

Symbolic links are changed like this:

  rsync-dist.pl -H <remote-server-name> -p <remote-path>
                  -m <log-message> 
		  --change-links <remote-sourcepath>,<link1>,<link2>...

or

  rsync-dist.pl -H <remote-server-name> -p <remote-path>
                  -m <log-message> 
		  --change-links <remote-path>,<filemask>...

  
Note that (especially in case one) all of the given link-names must
exist and must be symbolic links. The log-file is updated 
when this command is run.

=head2 inspecting the remote link-directory

The remote directly can be listed with this command:

  rsync-dist.pl -H <remote-server-name> -p <remote-path> 
                  --ls
		  
Note that you can optionally specify the remote user. All other
options are ignored. Since the command has a higher priority that the
other link commands, it overrides the them when
appended at the end of the parameter list. So this works too: 

  rsync-dist.pl -H <remote-server-name> -p <remote-path>
                  -m <log-message> 
		  --change-links <remote-path>,<filemask> --ls

On the remote directory you see the following files and directories:

=over 4

=item the file LOG-LINKS

This is the log-file that is appended each time new links are added or 
existing links are changed. It contains the information when and by whom 
the change was done.
It also contains an optional log-message for each change and a directory
listing of the links before and after the change. 
This is an example of the log-file:

  VERSION: 2006-10-05T14:09:07
  FROM: pfeiffer@tarn.acc.bessy.de
  OLD:
  lrwxr-xr-x 1 usr exp 22 Oct 5 14:07 ioc1 -> ../2006-10-05T13:02:44
  lrwxr-xr-x 1 usr exp 22 Oct 5 14:07 ioc2 -> ../2006-10-05T13:02:44
  NEW:
  lrwxr-xr-x 1 usr exp 22 Oct 5 14:09 ioc1 -> ../2006-10-05T14:02:44
  lrwxr-xr-x 1 usr exp 22 Oct 5 14:09 ioc2 -> ../2006-10-05T14:02:44

  VERSION: 2006-10-05T14:11:58
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
                  --links --cat_log

Note that without the --links option, the script lists LOG-DIST instead.

=head1 AUTHOR

Goetz Pfeiffer,  goetzp@gmx.net

=head1 SEE ALSO

rsync-documentation

=cut



=


