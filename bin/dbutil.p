eval 'exec perl -S $0 ${1+"$@"}' # -*- Mode: perl -*-
    if 0;                         
# the above is a more portable way to find perl
# ! /usr/bin/perl

#  This software is copyrighted by the BERLINER SPEICHERRING
#  GESELLSCHAFT FUER SYNCHROTRONSTRAHLUNG M.B.H., BERLIN, GERMANY.
#  The following terms apply to all files associated with the software.
#  
#  BESSY hereby grants permission to use, copy and modify this
#  software and its documentation for non-commercial, educational or
#  research purposes provided that existing copyright notices are
#  retained in all copies.
#  
#  The receiver of the software provides BESSY with all enhancements, 
#  including complete translations, made by the receiver.
#  
#  IN NO EVENT SHALL BESSY BE LIABLE TO ANY PARTY FOR DIRECT, INDIRECT,
#  SPECIAL, INCIDENTAL OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE
#  OF THIS SOFTWARE, ITS DOCUMENTATION OR ANY DERIVATIVES THEREOF, EVEN 
#  IF BESSY HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#  
#  BESSY SPECIFICALLY DISCLAIMS ANY WARRANTIES, INCLUDING, BUT NOT LIMITED
#  TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
#  PURPOSE, AND NON-INFRINGEMENT. THIS SOFTWARE IS PROVIDED ON AN "AS IS"
#  BASIS, AND BESSY HAS NO OBLIGATION TO PROVIDE MAINTENANCE, SUPPORT,
#  UPDATES, ENHANCEMENTS OR MODIFICATIONS.


# @STATUS: release
# @PLATFORM: bessy 
# @CATEGORY: database

#pragmas:
use strict;
use FindBin;

# enable this if you want to search modules like dbitable.pm 
# relative to the location of THIS script:
# ------------------------------------------------------------
# use lib "$FindBin::RealBin/../lib/perl";

use Getopt::Long;
use Net::Netrc;

use dbitable;

#$dbitable::sql_trace=1;
$dbdrv::sql_trace=1;

my $default_user= "guest";
my $default_pass= "bessyguest";

our $opt_help;
our $opt_database = "DBI:Oracle:bii_par";
our $opt_user;
our $opt_password;
our $opt_table;
our $opt_file;
our $opt_outfile;
our $opt_delete;
our $opt_action;
our $opt_tag;
our $opt_filter;
our $opt_order_by;
our $opt_new_name;
our $opt_summary;
our $opt_no_auto_pk;

my $version="1.4";

my %known_actions= (file2file=> 1,
                    db2file=>1, 
		    file2db=>1, 
		    file2screen=>1, 
		    db2screen=>1);

my %parameters;

#warn "options:",join("|",@ARGV),"\n";

Getopt::Long::config(qw(no_ignore_case));
if (!GetOptions("help|h", "summary",
                "database|d=s", "user|u=s", "password|p=s",
	        "table|t=s", "file|f=s", "outfile|o=s",
		"tag|T=s","action|a=s",
		"filter|F=s","order_by:s",
		"new_name|n=s",
		"delete|D", "no_auto_pk"

                ))
  { die(undef,"parameter error, use \"$0 -h\" to display the online-help\n"); 
  };

if ($opt_help)
  { print_help();
    exit;
  };  

if ($opt_summary)
  { print_summary();
    exit;
  };  

if (!exists $known_actions{$opt_action})
  { die "unknown action: $opt_action\n"; };

$parameters{database}= $opt_database; 

if (!defined $opt_user)
  { ($opt_user,$opt_password)= ($default_user, $default_pass);

     #my $mach = Net::Netrc->lookup($opt_database);
     my $mach = Net::Netrc->lookup($opt_database);
     if (defined $mach)
       { $opt_user= $mach->login();
         $opt_password= $mach->password();
       }
     else
       { my $env= $ENV{DBUTIL};
	 if (defined $env)
	  { ($opt_user,$opt_password)= split(":",$env); };
       }
  };

#warn $opt_user;  
#warn $opt_password;  

$parameters{user}    = $opt_user; 
$parameters{password}= $opt_password; 


if ($opt_action=~ /^file/)
  { # file must be specified
    if (!defined $opt_file)
      { die "error: -f option is mandatory\n"; };
    if (!-r $opt_file)
      { die "error: \"$opt_file\" doesn't exist\n"; };
    $parameters{file}= $opt_file;
    if (!defined $opt_tag)
      { die "error: -T option is mandatory\n"; };
    $parameters{tag}= $opt_tag;
  };

if ($opt_action=~ /file$/)
  { # file must be specified
    if (!defined $opt_outfile)
      { die "error: -o option is mandatory\n"; };
    #if (!-r $opt_outfile)
    #  { die "error: \"$opt_outfile\" doesn't exist\n"; };
    $parameters{outfile}= $opt_outfile;
    if (!defined $opt_tag)
      { die "error: -T option is mandatory\n"; };
    $parameters{tag}= $opt_tag;
  };

my ($table,$pk); 
if ($opt_action=~ /^db/)
  { # table must be specified
    if (!defined $opt_table)
      { die "error: -t option is mandatory\n"; };
    ($table,$pk)= split(",",$opt_table);
    $parameters{table}= $table;
    $parameters{pk}   = $pk;
  };    

if ($opt_action eq 'file2db')
  { if ($opt_delete)
      { $parameters{mode}= 'subtract'; 
        $dbitable::sim_delete=0;
      };
  };


if (!exists $parameters{tag})
  { $parameters{tag}= $parameters{table}; };


if (defined $opt_filter)
  { my(@f)= split(",",$opt_filter);
    if (!@f)
      { die "use -F [filter-name,filter-parameters...] !\n"; };  
    $parameters{filter}= \@f;
  }; 

if (defined $opt_order_by)
  { if (!$opt_order_by)
      { $parameters{order_by}= ""; }
    else
      { $parameters{order_by}=[ split(",",$opt_order_by) ]; };
  }; 

if (defined $opt_new_name)
  { $parameters{new_name}= $opt_new_name; };

if    ($opt_action eq 'file2file')
  { file2file(%parameters); }
elsif ($opt_action eq 'db2file')
  { db2file(%parameters); }
elsif ($opt_action eq 'file2db')
  { file2db(%parameters); }
elsif ($opt_action eq 'file2screen')
  { file2screen(%parameters); }
elsif ($opt_action eq 'db2screen')
  { db2screen(%parameters); }
else
  { die "unknown command (internal error): $opt_action"; };


sub db2screen
  { my(%options)= @_;
    my $dbh= get_dbh(\%options);

    my %ld_options;
    copy_hash_entries(\%options,\%ld_options,"filter");

    my $tab= dbitable->new('table',$dbh,
                           $options{table},
			   $options{pk});

    if (!defined $tab)
      { die "error: table not readable, $dbitable::last_error\n"; };

    if ($options{order_by}=="")
      { $options{order_by}= [$tab->primary_key_columns()]; };

    $tab->load(%ld_options);

    dbitable::disconnect_database($dbh);

    my %pp_options;
    copy_hash_entries(\%options,\%pp_options,"order_by");

    $tab->pretty_print(%pp_options); 
  }

sub db2file
  { my(%options)= @_;
    my $dbh= get_dbh(\%options);

    my %ld_options;
    copy_hash_entries(\%options,\%ld_options,"filter","new_name");


    my $tab= dbitable->new('table',$dbh,
                           $options{table},
			   $options{pk});

    if (!defined $tab)
      { die "error: assertion, last error: $dbitable::last_error"; };

    if ($options{order_by}=="")
      { $options{order_by}= [$tab->primary_key_columns()]; };

    $tab->load(%ld_options);

    dbitable::disconnect_database($dbh);

    my %st_options= (pretty=> 1);
    copy_hash_entries(\%options,\%st_options,"order_by");
    my $ftab= $tab->new('file',$options{outfile},
                        $options{tag}
		       )->store(%st_options);

  }

sub file2db
  { my(%options)= @_;
    my $dbh= get_dbh(\%options);

    my %ftab_options= (pretty=>1);

    if (!defined $opt_no_auto_pk)
      { $ftab_options{primary_key}="generate"; }
    else
      { $ftab_options{primary_key}="preserve"; };

    my $ftab= dbitable->new('file',$options{file},$options{tag},
                           );

    if (!defined $ftab)
      { die "error: table not readable, $dbitable::last_error\n"; };

    copy_hash_entries(\%options,\%ftab_options,"new_name");

    $ftab->load(%ftab_options);

    my $tab = $ftab->new('table',"",'','');

    if (!defined $tab)
      { die "error: assertion, last error: $dbitable::last_error"; };

    my %ld_options;
    copy_hash_entries(\%options,\%ld_options,"filter","mode");

    if (!exists $ld_options{mode})
      { $ld_options{mode}="add"; };

warn "ld_options: " . join(",",%ld_options);

    $tab->load(%ld_options);
    # since there cannot be any preliminary primary keys,
    # it is correct here to leave the primary keys untouched
    $tab->store(primary_key=>"preserve");
    dbitable::disconnect_database();
  }

sub file2screen
  { my(%options)= @_;

    my $ftab= dbitable->new('file',$options{file},$options{tag},
                           )->load(pretty=>1,primary_key=>"generate");

    if ($options{order_by}=="")
      { $options{order_by}= [$ftab->primary_key_columns()]; };

    my %pp_options;
    copy_hash_entries(\%options,\%pp_options,"order_by");

    $ftab->pretty_print(%pp_options); 
  }

sub file2file
  { my(%options)= @_;

    my %ld_options=(pretty=>1,primary_key=>"generate");
    copy_hash_entries(\%options,\%ld_options,"new_name");

    my $ftab= dbitable->new('file',$options{file},$options{tag},
                           )->load(%ld_options);


    if ($options{order_by}=="")
      { $options{order_by}= [$ftab->primary_key_columns()]; };

    my %st_options= (pretty=>1);
    copy_hash_entries(\%options,\%st_options,"order_by");

    my $ntab= $ftab->new('file',$options{outfile},$options{tag}
                        )->store(%st_options);
  }

sub get_dbh
  { my($r_options)= @_;

    my $dbh= dbitable::connect_database($r_options->{database},
                                        $r_options->{user},
					$r_options->{password});
    if (!defined $dbh)
      { die "opening the database failed!\n"; };
    return($dbh);
  }

sub copy_hash_entries
  { my($r_src,$r_dest,@tags)= @_;

    foreach my $tag (@tags)
      { if (exists $r_src->{$tag})
          { $r_dest->{$tag}= $r_src->{$tag}; };
      };
  }

sub print_summary
  { printf("%-20s: database to ascii file load and store tool\n",
           $FindBin::Script);
  }

sub print_help
  { print <<END
************* $FindBin::Script $version *****************
useage: $FindBin::Script {options} 
options:
  -h : this help
  -d : database-name, default: $opt_database
  -u [user] , database-user, default: $default_user
     when this option is missing, the scripts first searches for
     \$HOME/.netrc
     If this file exists and there is an entry in the form:
     machine <database-name> login <user-name> password <password>
     the user-name and password are taken from that file. If a matching
     entry is not found, the script looks for the environment variable
     DBUTIL. If it is set to (user:password)
     this user-password combination is taken

  -p [password], default: "bessyguest"

  -a [action]: mandatory, action is one of:
     file2file, db2file, file2db, file2screen, db2screen

  -t [table-name,primary_key]: this is mandatory for all actions db2...
     The primary_key may be omitted, in this case it is determined
     by a special SQL query

  -n [new table name]
     change the table-name to the new given name. This may be useful 
     when a table is copied to another table with a different name but 
     the same structure    

  -f [filename]
     This is mandatory for all actions file2...

  -o [filename]
     This is mandatory for all actions ...2file

  -T [tag] tag in the datafile. Mandatory for all actions file...
     For actions ...2file, the default is the table-name if it is
     not defined

  -F [filter-name,filter-parameters...]: define a filter for the 
     currently known:
     equal,<col-name>,<col-value>
     SQL,"WHERE-Part of an sql query statement"

  --order_by [column-name1,column-name2...] : 
     this is only relevant for "...2file and ...2screen"
     if no columns are given ordering is made according to
     primary keys

  -D deletion mode (only for file2db). In this case, lines
     that are not found in the file but only the database are
     deleted from the database 

  --no_auto_pk (only for file2db)
     do not generate primary keys but take the primary key field
     in the file as it is
END
  }


