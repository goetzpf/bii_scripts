eval 'exec perl -S $0 ${1+"$@"}' # -*- Mode: perl -*-
    if 0;
# the above is a more portable way to find perl
# ! /usr/bin/perl

use strict;

use FindBin;

# enable this if you want to search modules like dbitable.pm
# relative to the location of THIS script:
# ------------------------------------------------------------
#CONFIGURE: deactivate_when USE_PERL5LIB
use lib "$FindBin::RealBin/../lib/perl";


# You may specify where to look for perl extensions like Tk or
# find Tk::TableMatrix here. The following line activates
# my private installed extensions on host ocean:
# ------------------------------------------------------------
#CONFIGURE: activate_when USE_GP_MODULES
# use lib "/home/unix/pfeiffer/project/perl/lib/site_perl";

use Sys::Hostname;
use Config;
use Cwd;
use File::Spec;
use File::Find;

#use Tk 800.024; <-- problems on ocean
use Tk;
use Tk::Menu;
use Tk::Dialog;
use Tk::NoteBook;
use Tk::TextUndo;
use Tk::ROText;
use Tk::BrowseEntry;
use Tk::Listbox;
use Tk::FileSelect;
use Tk::Pane;
use Tk::Font;
use Tk::FontDialog;
use Tk::Balloon;

use Tk::TableMatrix;
#use Tk::TableMatrix::Spreadsheet;
use Tk::ProgressBar;
use Tk::Date;
use Tk::NumEntry;

use Text::ParseWords;
use IO::File;
#use Tk::ErrorDialog;

use warnings;
#use diagnostics;

use dbdrv 1.2;
use dbitable 2.1;
use BrowseDB::TkUtils 1.0;

use Data::Dumper;

# warn "TK Version: " . $Tk::VERSION;

# Configurational global data

my %global_data;


$global_data{title} = "BrowseDB";
$global_data{version} = "0.95";

$global_data{about} =
      [ "written by Goetz Pfeiffer",
        "updated and improved by Patrick Laux",
        "BESSY GmbH, Berlin, Adlershof",
        "Comments/Suggestions, please mail to:",
        "pfeiffer\@mail.bessy.de",
        "laux\@mail.bessy.de" ];



$global_data{license}= [ "BESSY License"];

$global_data{os} = $Config{osname};
$global_data{formats}{date}{string} = "%4y-%2m-%2d";
$global_data{formats}{date}{weekdays} = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Son'];
$global_data{formats}{date}{firstday} = 0;
$global_data{formats}{time}{string} = "%2H:%2M:%2S";
$global_data{formats}{number}{decimal} = ".";
$global_data{formats}{number}{thousend} = ",";

my %forkable_os= map { $_=>1 } qw(hpux linux);
# MSWin32 on windows

if ($forkable_os{$global_data{os}})
  {
    # switch myself to the background:
    # (doesn't work on windows)
    if (0 != fork)
      { # parent here
        exit(0);
      };
  };

our %save; # global configuration variable

my @wanted_array;
my $wanted_regex;

$global_data{home} = $ENV{"HOME"};
if (!defined $global_data{home})
  { $global_data{home} = ""; };

#CONFIGURE: make_variable BROWSEDB_SHARE_DIR $share_dir
#CONFIGURE: deactivate_when BROWSEDB_SHARE_DIR
my $share_dir= path_beautify("$FindBin::RealBin/../share/browsedb");

$global_data{share_dir} = $share_dir;

if ((!-d $global_data{share_dir}) or (!-r $global_data{share_dir}))
  { $global_data{share_dir} = undef; };

$global_data{dir} = $global_data{home}."/.browsedb";

if (! -e $global_data{dir})
  {
    printf("creating \"/.browsedb\" in your home directory...\n");
    mkdir($global_data{dir}, 00755) or
      die "Can not create configuration location at ".$global_data{dir};
  }
else
  { chmod 0755, $global_data{dir}; };

#file_find('\.col$', $global_data{dir});
#die;

my $column_map_file= 'column_maps.txt';

my $sim_oracle_access=0;

my $guest_login=0; # for debuggin only, default: 0
$global_data{fast_test} = 0; # skip login dialog and open $fast_table
my $fast_table='p_insertion';

my $db_table_name;
if (!@ARGV)
  { $db_table_name= "p_insertion_value"; }
else
  { $db_table_name= shift; };

$global_data{database}{db_driver}     = "Oracle";
$global_data{database}{db_server}     = "ocean.acc.bessy.de";
$global_data{database}{db_source}     = "bii_par";
$global_data{database}{user}          = "guest";
$global_data{database}{password}      = "bessyguest";

$global_data{autocommit}    = 0;

my $db_driver    = $global_data{database}{db_driver};
my $db_source    = $global_data{database}{db_source};
my $db_username  = $global_data{database}{user};
my $db_password  = $global_data{database}{password};

$global_data{database}{dbproxy_server}      = "ocean.acc.bessy.de";
$global_data{database}{dbproxy_port}        = "12109";

my $db_proxy     = $global_data{database}{dbproxy_server};
my $db_proxy_port= $global_data{database}{dbproxy_port};

$global_data{theme}->{main}= { '-background' => "gray81",
#                              '-font'       => "{helvetica} 10",
                             };

$global_data{theme}->{login}= { '-background'         => "gray90",
                                '-font'               => "{helvetica} 10",
                              };

$global_data{theme}->{'login:entry'}= 
                              { '-background'         => "gray87",
                                '-disabledbackground' => "gray87",
                              };
                             
$global_data{theme}->{'login:button'}= 
                               { '-activebackground'=> "gray90",
                               };

$global_data{theme}->{table}=   { '-background' => "gray90",
                                  '-font'       => "{helvetica} 9",
                                };

$global_data{theme}->{'table:menubar'}= 
                                { '-background'       => "gray90",
                                  '-activebackground' => "gray90",
                                  '-font'             => "{helvetica} 9 bold",
                                  '-foreground'       => 'black',
                                  '-activeforeground' => 'black'
                                };

$global_data{theme}->{'table:changed'}= 
                                { -foreground => 'red'
                                };

$global_data{theme}->{'table:changed_ro'}= 
                                { -foreground => 'orange'
                                };

$global_data{theme}->{'table:pk'}= 
                                { -foreground => 'blue'
                                };

$global_data{theme}->{'table:fk'}= 
                                { -foreground => 'LimeGreen'
                                };

$global_data{theme}->{'table:manual_fk'}= 
                                { -foreground => 'ForestGreen'
                                };

$global_data{theme}->{'table:colmap_on'}= 
                                { -foreground => 'aquamarine2'
                                };

$global_data{theme}->{'table:colmap_off'}= 
                                { -foreground => 'LightCyan2'
                                };


$global_data{theme}->{button}= { '-background'      => "gray81",
                                 '-font'            => "{helvetica} 10",
                                 '-activebackground'=>"gray81",
                               };

$global_data{theme}->{text}= { '-background' => "gray81",
                               #'-foreground' => "black",
                               '-font'       => "{helvetica} 10"
                             };
                             
$global_data{theme}->{shell}= { '-background' => "black",
                                '-font'       => "{courier} 10",
                                '-foreground' => "white",
#                               '-selection'  => "{courier} 10 bold",
#                               '-cursor'     => "yellow",
#                               '-commit'     => "green",
#                               '-error'      => "red",
                              };

$global_data{theme}->{'shell:selection'}= 
                              { 
#                               '-background' => "black";
                                '-font'       => "{courier} 10 bold",
#                               '-foreground' => "white",
#                               '-cursor'     => "yellow",
#                               '-commit'     => "green",
#                               '-error'      => "red",
                              };

$global_data{theme}->{'shell:string'}= 
                              { 
#                               '-background' => "black";
#                               '-font'       => "{courier} 10 bold",
                                '-foreground' => "white",
#                               '-cursor'     => "yellow",
#                               '-commit'     => "green",
#                               '-error'      => "red",
                              };

$global_data{theme}->{'shell:error'}= 
                              { 
#                               '-background' => "black";
#                               '-font'       => "{courier} 10 bold",
                                '-foreground' => "red",
#                               '-cursor'     => "yellow",
#                               '-commit'     => "green",
                              };

#$global_data{theme}->{sql}-> { '-background'  => "gray81";
#                              '-color'       => "black",
#                              '-font'        => "{helvetica} 10",
#                              '-foreign_key' => "green",
#                              '-primary_key' => "blue",
#                              '-changes'     => "red",
#                             };


my $r_alias;

# re-define the dbitable error-handler:
dbdrv::set_err_func(\&dbidie);
dbdrv::set_warn_func(\&dbiwarn);
$dbitable::sim_delete = 0;

my %std_button_options= (
             theme_parameters(\%global_data,'button',
                              '-background','-font','-activebackground'),
                        );

my %std_menue_button_options= (
             theme_parameters(\%global_data,'button',
                              '-background','-font','-activebackground'),
             -relief=> 'raised');

# --------------------- chdir to the directory where THIS SCRIPT is located
# change to the place where THIS SCRIPT is located:
chdir $FindBin::Bin;

# --------------------- database access

#tk_login(\%global_data, $db_name, $db_username, $db_password);
tk_main_window(\%global_data);

# --------------------- create some entry widgets

MainLoop();

#=======================================================
# routines that create windows and dialogs:
#=======================================================

# database login:
#_______________________________________________________

sub tk_login
# r_glbl: hash with global entries
  { my($r_glbl)= @_;

#  { my($r_glbl,$db_name,$user,$password)= @_;

    $r_glbl->{db_driver}    = $db_driver;
    $r_glbl->{db_source}    = $db_source;
    $r_glbl->{user}         = $db_username;
    $r_glbl->{password}     = $db_password;

    $r_glbl->{use_proxy}    = 0;


    if ($r_glbl->{fast_test} || $guest_login)
      { tk_login_finish($r_glbl);
        return;
      };

    my $Top= BrowseDB::TkUtils::MakeToplevel(
                         $r_glbl,
                         title=>"$r_glbl->{title}:Login",
                         theme_parameters($r_glbl,'login','-background')
                                            );
    $r_glbl->{login_widget}= $Top;
    my $FrTop = $Top->Frame(theme_parameters($r_glbl,'login','-background')
                           )->pack(-side=>'top' ,-fill=>'both');
    my $FrDn  = $Top->Frame(
                            theme_parameters($r_glbl,'login','-background')
                           )->pack(-side=>'top' );

    my $row=0;
    my %label_opts= theme_parameters($r_glbl,'login','-background','-font');

    $FrTop->Label(-text => 'driver:',%label_opts,
                 )->grid(-row=>$row++, -column=>0, -sticky=> "w");
    $FrTop->Label(-text => 'database:',%label_opts,
                 )->grid(-row=>$row++, -column=>0, -sticky=> "w");
    $FrTop->Label(-text => 'user:',%label_opts,
                 )->grid(-row=>$row++, -column=>0, -sticky=> "w");
    $FrTop->Label(-text => 'password:',%label_opts,
                 )->grid(-row=>$row++, -column=>0, -sticky=> "w");
    $FrTop->Label(-text => 'use dbi proxy:',%label_opts,
                 )->grid(-row=>$row++, -column=>0, -sticky=> "w");
    $FrTop->Label(-text => 'proxy server:',%label_opts,
                 )->grid(-row=>$row++, -column=>0, -sticky=> "w");
    $FrTop->Label(-text => 'proxy port:',%label_opts,
                 )->grid(-row=>$row++, -column=>0, -sticky=> "w");

    $row=0;
    my %entry_opts= theme_parameters($r_glbl,'login:entry',
                                         '-background','-font',
                                        ($Tk::VERSION >= 804.027) ? 
                                        '-disabledbackground':undef
                                    );
    # ^^^ -disabledbackground not allowed here in older Tk versions                                 

    my $e0= $FrTop->BrowseEntry(-textvariable => \$r_glbl->{db_driver},
                                %entry_opts
                         )->grid(-row=>$row++, -column=>1, -sticky=> "w");
    my $e1= $FrTop->Entry(-textvariable => \$r_glbl->{db_source},
                          %entry_opts
                         )->grid(-row=>$row++, -column=>1, -sticky=> "w");
    my $e2= $FrTop->Entry(-textvariable => \$r_glbl->{user},
                          %entry_opts
                         )->grid(-row=>$row++, -column=>1, -sticky=> "w");
    my $e3= $FrTop->Entry(-textvariable => \$r_glbl->{password},
                          -show => '*',
                          %entry_opts
                         )->grid(-row=>$row++, -column=>1, -sticky=> "w");


    my $Button;
    my($e4,$e5);
    $Button = $FrTop->Checkbutton(
                theme_parameters($r_glbl,'login:button',
                                 '-background','-activebackground'),
                #-text=>"use DBI Proxy",
                -variable => \$r_glbl->{use_proxy},
                -command =>
                   sub { my $state= 'disabled';
                         if ($r_glbl->{use_proxy})
                           { $state= 'normal';
                             if (!$r_glbl->{proxy})
                               { $r_glbl->{proxy}      = $db_proxy;
                                 $r_glbl->{proxy_port} = $db_proxy_port;
                               };
                           };
                         $e4->configure(-state => $state);
                         $e5->configure(-state => $state);
                       }
                                  )->grid(-row=>$row++, -column=>1,
                                          -sticky=> "w");

    $e4= $FrTop->Entry(-textvariable => \$r_glbl->{proxy},
                       -state => 'disabled', %entry_opts
                      )->grid(-row=>$row++, -column=>1, -sticky=> "w");
    $e5= $FrTop->Entry(-textvariable => \$r_glbl->{proxy_port},
                       -state => 'disabled', %entry_opts
                      )->grid(-row=>$row++, -column=>1, -sticky=> "w");



    foreach my $db_driver (DBI->available_drivers)
      {
        $e0->insert('end', $db_driver);
      }

# an experiment with the Oracle Proxy:
#$e0->insert('end', "Proxy:hostname=tarn;port=4097;dsn=DBI:Oracle");

    $e0->focus();
    $e0->bind('<Return>', sub { $e1->focus() } );
    $e0->bind('<Tab>', sub { $e1->focus() } );
    $e1->bind('<Return>', sub { $e2->focus() } );
    $e1->bind('<Tab>', sub { $e2->focus() } );
    $e2->bind('<Return>', sub { $e3->focus() } );
    $e2->bind('<Tab>', sub { $e3->focus() } );
    $e3->bind('<Return>', sub { tk_login_finish($r_glbl); } );
    $e3->bind('<Tab>', sub { $e1->focus(); } );

    my %button_opts= theme_parameters($r_glbl,'login:button',
                                      '-background','-font',
                                      '-activebackground',
                                     );

    
    $FrDn->Button(-text => 'Login',
                  %button_opts,
                  -command => [\&tk_login_finish, $r_glbl ],
                   )->pack(-side=>'left', -anchor=>'nw');
    $FrDn->Button(-text => 'Quit',
                  %button_opts,
                  -command => sub { $Top->destroy(); exit(0); }
                   )->pack(-side=>'left', -anchor=>'nw');

    $Top->Popup(-popover=> $r_glbl->{main_menu_widget} );

  }

sub tk_login_finish
  { my($r_glbl)= @_;
    my $db_handle;

    if (defined($r_glbl->{handle_sql_history}))
      {
        my $fh = $r_glbl->{handle_sql_history};
        $fh->flush();
        $fh->close();
        delete $r_glbl->{handle_sql_history};
      }
    if (defined($r_glbl->{dbh}))
      { dbitable::disconnect_database($r_glbl->{dbh});
        delete $r_glbl->{dbh};
      };
    BrowseDB::TkUtils::SetBusy($r_glbl,1);

    BrowseDB::TkUtils::Progress($r_glbl,10);

    if (!$r_glbl->{use_proxy})
      { if ($r_glbl->{db_driver} eq "Pg")
          { $r_glbl->{db_name} = "DBI:" . $r_glbl->{db_driver} .
                                  ":dbname=" . $r_glbl->{db_source};
            $dbitable::default_dbdrv="Postgresql";
          }
        else
          { # Oracle:
            $r_glbl->{db_name} = "DBI:" . $r_glbl->{db_driver} . ":" .
                                 $r_glbl->{db_source};
          }
      }
    else
      { my $host= $r_glbl->{proxy}; $host=~ s/^\s+//; $host=~ s/\s+$//;
        $r_glbl->{proxy}= $host;
        my $port= $r_glbl->{proxy_port};
        $port=~ s/^\s+//; $port=~ s/\s+$//;
        $r_glbl->{proxy_port}= $port;

        $r_glbl->{db_name} = "DBI:Proxy:hostname=$host;port=$port;dsn=DBI:" .
                             $r_glbl->{db_driver} . ':' .
                             $r_glbl->{db_source};
      };
    if (!$sim_oracle_access)
      { $db_handle= dbitable::connect_database($r_glbl->{db_name},
                                               $r_glbl->{user},
                                               $r_glbl->{password},
                                               $r_glbl->{autocommit}
                                               );
        if (!defined $db_handle)
          { BrowseDB::TkUtils::SetBusy($r_glbl,0);
            BrowseDB::TkUtils::err_dialog($r_glbl->{main_menu_widget},
                          "opening of the database failed");

            BrowseDB::TkUtils::SetBusy($r_glbl,0);
            BrowseDB::TkUtils::Progress($r_glbl,0);
            $r_glbl->{login_widget}->raise();
            return;
          };
      };
    $r_glbl->{password}=~ s/./\*/g;

    $r_glbl->{dbh}= $db_handle;

    $r_glbl->{db_capability} = dbdrv::get_capabilities();
    
    BrowseDB::TkUtils::Progress($r_glbl,20);

    BrowseDB::TkUtils::SetBusy($r_glbl,0);

    if (defined($r_glbl->{login_widget}))
      {
        $r_glbl->{login_widget}->destroy();
        $r_glbl->{main_menu_widget}->update();
        # important to really execute the destroy
        delete $r_glbl->{login_widget};
      };

    tk_main_window_finish($r_glbl);
  }

# browsedb main-window:
#_______________________________________________________

sub tk_main_window
  { my($r_glbl)= @_;

#    $r_glbl->{db_name}     = $db_name;
#    $r_glbl->{user}        = $user;
#    $r_glbl->{password}    = $password;

    my $listbox_action;
    my $Top= MainWindow->new(theme_parameters($r_glbl,'main','-background'));
    
    $Top->protocol('WM_DELETE_WINDOW', [ \&tk_quit_main, $r_glbl]);

    $Top->minsize(400,400);
#    $Top->maxsize(800,800);

    $Top->title("$r_glbl->{title}");
    $r_glbl->{main_menu_widget}= $Top;

    # the Menu-Bar is now created in a way that works on
    # windows to0. Note that this is a property of the
    # top widget, $MnTop MUST NOT be packed

    my $MnTop= $Top->Menu();
    $Top->configure(-menu => $MnTop );


    my $MnFile   = $MnTop->Menu();
    my $MnDb     = $MnTop->Menu();
    my $MnPref   = $MnTop->Menu();
    my $MnWindow = $MnTop->Menu();
    my $MnHelp   = $MnTop->Menu();

    $r_glbl->{MainWindow}->{menu_windows_widget} = $MnWindow;
    $MnTop->add('cascade',
                -label=> 'File',
                -underline   => 0,
                -menu=> $MnFile
               );
    $MnTop->add('cascade',
                -label=> 'Database',
                -underline   => 0,
                -menu=> $MnDb
               );
    $MnTop->add('cascade',
                -label=> 'Preferences',
                -underline  => 0,
                -menu=> $MnPref
               );
    $MnTop->add('cascade',
                -label=> 'Windows',
                -underline  => 0,
                -menu=> $MnWindow
               );
    $MnTop->add('cascade',
                -label=> 'Help',
                -underline  => 0,
                -menu=> $MnHelp
               );

    # configure File-menu:
    $Top->bind($Top,'<Control-o>'=> [\&tk_load_collection,$r_glbl]);
    $MnFile->add('command',
               -label=> 'Open collection',
               -accelerator => 'Ctrl+o',
               -underline  => 0,
               -command=> [\&tk_load_collection,"",$r_glbl]
              );
    $Top->bind($Top,'<Control-s>'=> [\&tk_save_collection,$r_glbl]);
    $MnFile->add('command',
               -label=> 'Save collection',
               -accelerator => 'Ctrl+s',
               -underline  => 0,
               -command=> [\&tk_save_collection,"",$r_glbl]
              );
    $MnFile->add('separator');
    $MnFile->add('command',
                    -label=> 'Quit',
                    -accelerator => 'Ctrl+q',
                    -underline  => 0,
                    -command => [ \&tk_quit_main,$r_glbl],
              );

    $Top->bind('<Control-q>' => [ \&tk_quit_main,$r_glbl]
              );
    # configure Database-menu:
    $MnDb->add('command',
               -label=> 'Login',
               -underline  => 0,
               -command=> [\&tk_login, $r_glbl]
              );
    $MnDb->add('separator');

    my $c_commit_i;
    my $c_rollback_i;

    $MnDb->add('command',
               -label=> 'Commit',
               -underline  => 0,
               -state=> ($r_glbl->{autocommit} ? 
                          'disabled' : 'active'),
               -command=> sub { dbdrv::commit($r_glbl->{dbh}); }
              );
    $c_commit_i= $MnDb->index('end');
    $MnDb->add('command',
               -label=> 'Rollback',
               -underline  => 0,
               -state=> ($r_glbl->{autocommit} ? 
                           'disabled' : 'active'),
               -command=> sub { dbdrv::rollback($r_glbl->{dbh});
                                tk_reload_all_objects($r_glbl);
                              }
              );
    $c_rollback_i= $MnDb->index('end');


    $MnDb->add('separator');
    $MnDb->add('command',
               -label=> 'Reload objects',
               -underline  => 0,
               -command=> [\&tk_reload_all_objects, $r_glbl]
              );
    $MnDb->add('command',
               -label=> 'Show SQL commands',
               -underline  => 5,
               -command=> [\&tk_sql_commands, $r_glbl]
              );

    # configure Preferences-menu:
    # (see also above, $MnPref)
    $r_glbl->{primary_key_auto_generate}= 1;
    $MnPref->add(
              'checkbutton',
               -label=> 'Autocommit',
               -variable => \$r_glbl->{autocommit},
               -command=>
                       sub {
                             my %h=(-state=> 
                                        ($r_glbl->{autocommit}) ?
                                        "disabled" : "active");

                             $MnDb->entryconfigure($c_commit_i,%h);
                             $MnDb->entryconfigure($c_rollback_i,%h);

                             dbdrv::set_autocommit($r_glbl->{dbh},
                                          $r_glbl->{autocommit});
                           }
              );
    $MnPref->add(
                  'checkbutton',
                   -label=> 'auto-generate primary keys',
                   -variable => \$r_glbl->{primary_key_auto_generate},
                );
    $MnPref->add('separator');
    my $MnPrefTheme = $MnPref->Menu();
    $MnPref->add(
            'cascade',
            -label=> 'Theme/Layout',
            -menu=> $MnPrefTheme,
      );
#    warn "found theme ";
    my $ThemeValues  = $r_glbl->{theme};
    foreach my $ThemeEntry (sort keys %$ThemeValues)
      {
        my $MnPrefThemeItem = $MnPrefTheme->Menu();
        $MnPrefTheme->add(
            'cascade',
            -label=> $ThemeEntry,
            -menu=> $MnPrefThemeItem,
          );
        my $r_ThemeHash = $ThemeValues->{$ThemeEntry};
        foreach my $property (keys %$r_ThemeHash)
          {
            if ($property =~ /^-(color|background|foreground|cursor|
                                activebackground)$/x)
              {

                $MnPrefThemeItem->add('command',
                    -label=> $property,
                    -command=>sub{ $r_ThemeHash->{$property} =
                        $MnPrefTheme->chooseColor(
                            -initialcolor=>$r_ThemeHash->{$property},
                            -title=> "Color for $ThemeEntry, $property",
                            -parent=>$Top,
                          );
                      },
                  );
              }
            elsif ($property eq "-font")
              {
                $MnPrefThemeItem->add('command',
                    -label=> $property,
                    -command=>sub{ $r_ThemeHash->{$property} =
                        $Top->FontDialog->Show(
                            -title=> "Font for $ThemeEntry, $property",
                            -sampletext=>"Choose font for $ThemeEntry.",
                            #-initfont=>$r_ThemeHash->{$property},
                          );
                      },
                  );
              }
            else
              {
                $MnPrefThemeItem->add('command',
                    -label=> $property,
                    -command=> 
                       [ \&BrowseDB::TkUtils::SimpleTextDialog,
                          $r_glbl,undef,
                           tag=> "theme_property_dialog",
                           title=> "Value for $ThemeEntry of $property",
                           default => $r_ThemeHash->{$property},
                           variable=> \$r_ThemeHash->{$property}
                       ]           
                                     );
              }
          }
#warn "found theme $ThemeEntry";
      }
    # configure Help-menu:
    $MnHelp->add('command',
                 -label=> 'Dump global datastructure',
                 -underline  => 5,
                 -command => [\&tk_dump_global, $r_glbl],
                );
    $MnHelp->add('command',
                 -label=> 'Dump object dictionary',
                 -underline  => 5,
                 -command => [\&tk_object_dict_dump, $r_glbl],
                );
    $MnHelp->add('command',
                 -label=> 'Dump reverse object dictionary',
                 -underline  => 5,
                 -command => [\&tk_r_object_dict_dump, $r_glbl],
                );
    $MnHelp->add('separator');
    $MnHelp->add('command',
                 -label=> 'About',
                 -underline  => 0,
                 -command=> [\&BrowseDB::TkUtils::About, $r_glbl,
                              $r_glbl->{about}
                            ]
                );
    $MnHelp->add('command',
                 -label=> 'License',
                 -underline  => 0,
                 -command=> [\&BrowseDB::TkUtils::About, $r_glbl,
                              $r_glbl->{license}
                            ]
                );

    # statusbar
    my $MnStatus = $Top->Frame(-relief=>"groove",
                               -height=>14
                              )->pack(-side=> "bottom",
                                      -fill=> "x",
                                      -anchor=> "sw",
                                      -expand=> 0,
                                      );


    $r_glbl->{MainWindow}->{login_info}=
        $MnStatus->Label(-text=>" ",
                        )->pack(
                                -side=>"left",
                                -expand=>1,
                                -anchor=>"w"
                                );

    $MnStatus->Label(
               -text=>'%'
       )->pack(
               -padx=> 2,
               -pady=> 2,
               -side=> "right",
               -anchor=> "e",
               -expand=> 0,
               );

    my $MnStatusProgress = $MnStatus->ProgressBar(
#                -width=>50,
               -blocks=>10,
               -height=>10,
               -length=>100,
               -from=>0,
               -to=>100,
               -blocks=> 10,
               -colors=>[ 0, 'blue' ],
       )->pack(
               -side=> "right",
               -anchor=> "e",
               -expand=> 0,
#               -fill=>'y'
               );
    $r_glbl->{MainWindow}->{progress_widget} = $MnStatusProgress;

#        $Top->update();

    # prepareing mainwindow with dialog
    my $DlgTop = $Top->NoteBook()->pack(
            -fill=>'both',
            -side=>'top',
            -expand=>1,
            -anchor=>'nw'
            );
    $r_glbl->{MainWindow}->{notebook} = $DlgTop;

    my $DlgEnt = $DlgTop->add("DlgEnt", -label=>"Short Exec", -underline=>0);
    my $DlgTbl = $DlgTop->add("DlgTbl", -label=>"Tables", -underline=>0, -state=>"disabled");
    my $DlgVw  = $DlgTop->add("DlgVw", -label=>"Views", -underline=>0, -state=>"disabled");
    my $DlgScr = $DlgTop->add("DlgScr", -label=>"Scripts", -underline=>0, -state=>"disabled");
    my $DlgSQL = $DlgTop->add("DlgSQL", -label=>"Command", -underline=>0);
    my $DlgHlp = $DlgTop->add("DlgHlp", -label=>"Help", -underline=>0);
    my %dlg_def_labentry = (
            -padx=>2, -pady=>2,
            -ipadx=>1, -ipady=>1,
            -fill=>"x",
            -side=>"top", -anchor=>"nw",
    );
    my %dlg_def_okbutton = (
            -padx=>2,-pady=>2,
            -ipadx=>1,-ipady=>1,
            -side=>"right",-anchor=>"se",
    );
    my %dlg_def_listbox = (
        -padx=>2, -pady=>2,
        -ipadx=>3, -ipady=>3,
        -side=>"left", -anchor=>"nw",
        -fill=>"both", -expand=>1,
    );

    $r_glbl->{new_table_name}= "";

    $DlgEnt->Label(-text => 'Open table/view:'
                  )->grid(-row=>0, -column=>0, -sticky=> "nsw");

    $r_glbl->{MainWindow}->{table_browse_widget}=
         $DlgEnt->BrowseEntry(
                      -validate=> 'key',
                      #-textvariable=>$r_glbl->{browse_val},
                      -validatecommand=> [ \&tk_handle_table_browse_entry,
                                           $r_glbl]
                               )->grid(-row=>0, -column=>1,-sticky=> "ew");

    $r_glbl->{MainWindow}->{table_browse_widget}->
             bind('<Return>',
                  sub { my $b= $r_glbl->{MainWindow}->
                                        {table_browse_button};
                        return if ($b->cget('-state') eq "disabled");
                        tk_open_new_object($r_glbl, 'table_or_view');
                      }
                 );

    $r_glbl->{MainWindow}->{table_browse_button}=
             $DlgEnt->Button( -state=>"disabled",
                              -text=>"Show",
                              -underline=>0,
                              -justify=>"center",
                              -command => [\&tk_open_new_object,
                                            $r_glbl, 'table_or_view' ],
                            )->grid(-row=>0,-column=>2,-sticky=> "ew");


    # draw a kind of line to separate both parts
    # in the menu
    $DlgEnt->Frame(-borderwidth=>5,
                  -relief=>'sunken',
                   )->grid(-row=>1, -column=>0,
                           -ipady=>1,
                           -pady=>10,
                           -columnspan=>3,-sticky=> "ew");

    $DlgEnt->Label(-text => "Load your Collection :"
                  )->grid(-row=>2, -column=>0,-sticky=> "nw");

    my $DlgCollListbox =
       $DlgEnt->Scrolled(
                             "Listbox",
#                            -label=>"Load your Collection :",
                             -scrollbars=>"osoe",
                             -width=>48,
                             -selectmode=>"browse",
                           )->grid(-row=>2,-column=>1,-sticky=> "nsew");

    $DlgEnt->gridRowconfigure   (2,-weight=>1); # make it stretchable
    $DlgEnt->gridColumnconfigure(1,-weight=>1); # make it stretchable

    my $DlgEntBF= $DlgEnt->Frame()->grid(-row=>2, -column=>2,-sticky=> "sew");

    my $DlgCollOk =
           $DlgEntBF->Button( -state=>"disabled",
                            -text=>"Load",
                            -underline=>1,
                            -justify=>"center",
                            -command =>
                               sub { my $entry =
                                       $DlgCollListbox->get(
                                           $DlgCollListbox->curselection);
                                     tk_load_collection($Top, $r_glbl, $entry);
                                   },
                          )->grid( -row=>0, -column=>0,-sticky=> "ew");
    my $DlgCollRefresh =
           $DlgEntBF->Button( -state=>"normal",
                              -text=>"Refresh dir",
                              -underline=>4,
                              -justify=>"center",
                              -command =>
                               sub { $DlgCollListbox->delete(0, 'end');
                                     $DlgCollListbox->insert("end",
                                             file_find('\.col$',
                                                       $r_glbl->{share_dir},
                                                       $r_glbl->{dir}
                                                      )     );
                                   },
                          )->grid( -row=>1, -column=>0,-sticky=> "ew");

        $DlgCollListbox->insert("end",
                                file_find('\.col$',$r_glbl->{share_dir},$r_glbl->{dir}) );


        $DlgCollListbox->
            bind('<Button-1>' =>
                 sub { $DlgCollOk->configure(-state=>"active");
                     }
                );

        $DlgCollListbox->
            bind('<Control-r>' =>
                      sub { $DlgCollListbox->delete(0, 'end');
                            $DlgCollListbox->insert("end",
                                    file_find('\.col$',
                                              $r_glbl->{share_dir},
                                              $r_glbl->{dir}
                                             )     );
                          }

               );
        $listbox_action = sub {
                my $entry =
                    $DlgCollListbox->get($DlgCollListbox->curselection);
                tk_load_collection($Top, $r_glbl, $entry);
            };
        $DlgCollListbox->bind('<Return>' => $listbox_action);
        $DlgCollListbox->bind('<Double-1>' => $listbox_action);

        # dialog tables
        my $DlgTblListbox = $DlgTbl->Scrolled(
                "Listbox",
                -scrollbars=>"oe",
                -selectmode=>"browse",
                -width=>0
        )->pack( %dlg_def_listbox );
        my $DlgTblOk = $DlgTbl->Button(
                -state=>"disabled",
                -text=>"Show",
                -underline=>0,
                -justify=>"center",
                -command=>
                  sub {
#                        $cond= $DlgTblWhere->get('1.0','end');
#                        $order= $DlgTblOrder->get('1.0','end');
                        $r_glbl->{new_table_name} =
                            $DlgTblListbox->get($DlgTblListbox->curselection);
#                        tk_open_new_object($r_glbl, "table", $cond, $order);
                        tk_open_new_object($r_glbl, "table");
                      }
        )->pack(%dlg_def_okbutton, );

        $DlgTblListbox->
            bind('<Button-1>' =>
                 sub { $DlgTblOk->configure(-state=>"active");
                     }
                );

        $listbox_action = sub {
#                $cond= $DlgTblWhere->get('1.0','end');
#                $order= $DlgTblOrder->get('1.0','end');
                $r_glbl->{new_table_name} =
                    $DlgTblListbox->get($DlgTblListbox->curselection);
#                tk_open_new_object($r_glbl, "table", $cond, $order);
                tk_open_new_object($r_glbl, "table");
            };
        $DlgTblListbox->bind('<Return>' => $listbox_action);
        $DlgTblListbox->bind('<Double-Button-1>' => $listbox_action);
        $r_glbl->{MainWindow}->{table_listbox_widget}=$DlgTblListbox;

        # dialog view
        my $DlgVwListbox = $DlgVw->Scrolled(
                "Listbox",
                -scrollbars=>"oe",
                -width=>34,
                -selectmode=>"browse",
                -width=>0
        )->pack( %dlg_def_listbox, );
        my $DlgVwOk = $DlgVw->Button(
                -state=>"disabled",
                -text=>"Show",
                -underline=>0,
                -justify=>"center",
                -command=>
                  sub {
#                        $cond = $DlgVwWhere->get('1.0','end');
#                        $order = $DlgVwOrder->get('1.0','end');
                        $r_glbl->{new_table_name} =
                            $DlgVwListbox->get($DlgVwListbox->curselection);
#                        tk_open_new_object($r_glbl, "view", $cond, $order);
                        tk_open_new_object($r_glbl, "view");
                      }
        )->pack( %dlg_def_okbutton, );

        $DlgVwListbox->
            bind('<Button-1>' =>
                 sub { $DlgVwOk->configure(-state=>"active");
                     }
                );
        $listbox_action = sub {
                        $r_glbl->{new_table_name} =
                            $DlgVwListbox->get($DlgVwListbox->curselection);
#                        tk_open_new_object($r_glbl, "view", $cond, $order);
                        tk_open_new_object($r_glbl, "view");
                      };

        $DlgVwListbox->bind('<Return>' => $listbox_action);
        $DlgVwListbox->bind('<Double-1>' => $listbox_action);
        $r_glbl->{MainWindow}->{view_listbox_widget}=$DlgVwListbox;

        # dialog script
        my $DlgScrListbox = $DlgScr->Scrolled(
                "Listbox",
                -scrollbars=>"oe",
                -width=>34,
                -selectmode=>"browse",
                -width=>0
        )->pack( %dlg_def_listbox, );

        $listbox_action = sub
          {
            my $script_name = $DlgScrListbox->get($DlgScrListbox->curselection);
            my $script_content = join "", dbdrv::read_scripttext
                    ($r_glbl->{dbh}, $script_name, $r_glbl->{user} );
            BrowseDB::TkUtils::MakeTextWidget($r_glbl, "Script ".$script_name, \$script_content);
          };

        my $DlgScrOk = $DlgScr->Button(
                -state=>"disabled",
                -text=>"Show",
                -underline=>0,
                -justify=>"center",
                -command=> $listbox_action,
        )->pack( %dlg_def_okbutton, );

        $DlgScrListbox->
            bind('<Button-1>' =>
                sub { $DlgScrOk->configure(-state=>"active");
                     }
                );

        $DlgScrListbox->bind('<Return>' => $listbox_action);
        $DlgScrListbox->bind('<Double-1>' => $listbox_action);
        $r_glbl->{MainWindow}->{script_listbox_widget}=$DlgScrListbox;

        # dialog sequel
        my $DlgSQLCommand;
        $DlgSQL->Label(
                -text=>"History :",
        )->pack( %dlg_def_labentry, );
        my $DlgSQLHistory = $DlgSQL->Scrolled(
                "ROText",
                -scrollbars=> "osoe",
                -height=> 10,
#                -width=>80,
        )->packAdjust( -padx=>2, -pady=>2,
                 -ipadx=>1, -ipady=>1,
                 -fill=>"both",
                 -side=>"top",
                 -expand=> 1,
        );
        BrowseDB::TkUtils::clear_undef_keys($DlgSQLHistory);
        $r_glbl->{MainWindow}->{sql_history_widget}=$DlgSQLHistory;
        $DlgSQL->Label( -text=> "Statement :",
                      )->pack( %dlg_def_labentry, );
        my $DlgSQLOk =
           $DlgSQL->Button( -state=> "normal",
                            -text=> "Exec",
                            -underline=> 1,
                            -justify=> "center",
                            -command=>
                              sub {
                                    my $query_command =
                                         $DlgSQLCommand->getSelected();
                                    if (length ($query_command) <= 2)
                                      {
                                        $query_command =
                                           $DlgSQLCommand->get('1.0', 'end');
                                      }
                                    tk_execute_new_query($r_glbl,
                                                         $query_command);
                                  }
           )->pack(%dlg_def_okbutton,
                -side=>"bottom");
        $DlgSQLCommand = $DlgSQL->Scrolled(
                "TextUndo",
                -height=> 10,
                -wrap=> "word",
                -scrollbars=> "osoe",
                theme_parameters($r_glbl,'shell',
                                 '-background','-foreground','-font')
#                -width=>80,
#                -validate=>cb_sqlcommand_validate(),
        )->pack( -anchor=> "s",
                 -padx=>2, -pady=>2,
                 -ipadx=>1, -ipady=>1,
                 -fill=>"both",
                 -side=>"bottom",
                 -expand=> 0, );

        $r_glbl->{MainWindow}->{sql_command_widget} = $DlgSQLCommand;
        BrowseDB::TkUtils::clear_undef_keys($DlgSQLCommand);
        $DlgSQLCommand->bind('<Control-X>' => $listbox_action);
        $DlgSQLCommand->bind('<Control-S>' => $listbox_action);
        $DlgSQLCommand->tagConfigure('selection', 
                theme_parameters($r_glbl,'shell:selection','-font')
                                    );

        $DlgSQLCommand->
            bind('<Control-Return>' =>
                 sub {  my $query_command;
                        my $failure_selection = $DlgSQLCommand->getSelected();
                        if (length($failure_selection) > 0)
                        {
                            $DlgSQLCommand->insert("insert",
                                                   $failure_selection);
                        }


                        $DlgSQLCommand->delete('insert - 1 char');
                        $query_command = $DlgSQLCommand->get('1.0', 'end');
                        $DlgSQLCommand->tagAdd('selection', '1.0', 'end');
                        tk_execute_new_query($r_glbl, $query_command);

                     }
                );
        $DlgSQLCommand->tagConfigure("string",
             theme_parameters($r_glbl,'shell:string','-foreground')
                                    );

        $DlgSQLCommand->tagConfigure("command",
             theme_parameters($r_glbl,'shell:error','-foreground')
                                    );

        # help dialog of database
        my $DlgHelpListbox = $DlgHlp->Scrolled(
                "Listbox",
                -scrollbars=>"osoe",
                -selectmode=>"browse",
                -width=>20
        )->pack( %dlg_def_listbox, );
        $r_glbl->{MainWindow}->{help_listbox_widget} = $DlgHelpListbox;
        my $DlgHelpContent = $DlgHlp->Scrolled(
                "ROText",
                -scrollbars=> "osoe",
                -width=>80,
        )->pack( -padx=>2, -pady=>2,
                 -ipadx=>1, -ipady=>1,
                 -fill=>"both",
                 -side=>"top",
                 -expand=> 1,
        );
        $r_glbl->{MainWindow}->{help_text_widget} = $DlgHelpContent;
        BrowseDB::TkUtils::clear_undef_keys($DlgHelpContent);
        $listbox_action =
                 sub {  my $entry =
                            $DlgHelpListbox->get($DlgHelpListbox->curselection);
                        $DlgHelpContent->delete('1.0', 'end');
                        my $text = dbdrv::get_help(
                                                    $r_glbl->{dbh},
                                                    $entry
                                                  );
#print Dumper($text_hash);
                        $DlgHelpContent->insert('1.0',$text);
                     };
        $DlgHelpListbox->bind('<Return>' => $listbox_action);
        $DlgHelpListbox->bind('<Button-1>' => $listbox_action);
        $DlgHelpListbox->bind('<Double-1>' => $listbox_action);

       # read column-map definitions:
        my $r_c;
        if (defined $r_glbl->{share_dir})
          { $r_c= load_column_maps($r_glbl,
                                   File::Spec->catdir($r_glbl->{share_dir},
                                                      $column_map_file
                                                     )
                                   );
            if (defined $r_c)
              { $r_glbl->{column_map_definitions_global}= $r_c; };
          };

        if ((-d $r_glbl->{dir}) and (-r $r_glbl->{dir}))
          { $r_c= load_column_maps($r_glbl,
                                   File::Spec->catdir($r_glbl->{dir},
                                                      $column_map_file
                                                     )
                                   );
            if (defined $r_c)
              { $r_glbl->{column_map_definitions_local}= $r_c; };
          };

        # dont remove these update, because of .toplevel
        # problems for destroy operations
        $Top->update();
        tk_login($r_glbl); # calls tk_main_window_finish
  }

sub tk_main_window_finish
  { my($r_glbl)= @_;

    BrowseDB::TkUtils::SetBusy($r_glbl,1);
#    BrowseDB::TkUtils::Progress($r_glbl,35);
    my $infotext= $r_glbl->{user} . "@" . $r_glbl->{db_driver} . ':' .
                  $r_glbl->{db_source};

    if ($r_glbl->{use_proxy})
      { $infotext.= " (proxy $r_glbl->{proxy}:$r_glbl->{proxy_port})"; };

    $r_glbl->{MainWindow}->
             {login_info}->configure(-text =>$infotext);

    my @accessible_objects_tables =
              dbdrv::accessible_objects($r_glbl->{'dbh'},
                                         $r_glbl->{user},
                                         "TABLE",
                                         "PUBLIC,USER");

    BrowseDB::TkUtils::Progress($r_glbl,35);

    my $table_listbox_widget= $r_glbl->{MainWindow}->{table_listbox_widget};
    $table_listbox_widget->delete(0, 'end');
    $table_listbox_widget->
             insert("end",  @accessible_objects_tables );
    $r_glbl->{MainWindow}->{notebook}->pageconfigure("DlgTbl", state=>"normal");

    my @accessible_objects_views=
               dbdrv::accessible_objects($r_glbl->{'dbh'},
                                         $r_glbl->{user},
                                         "VIEW",
                                         "PUBLIC,USER");

    BrowseDB::TkUtils::Progress($r_glbl, 55);

    my $view_listbox_widget= $r_glbl->{MainWindow}->{view_listbox_widget};
    $view_listbox_widget->delete(0, 'end');
    $view_listbox_widget->
             insert("end", @accessible_objects_views );
    $r_glbl->{MainWindow}->{notebook}->pageconfigure("DlgVw", state=>"normal");


    $r_glbl->{MainWindow}->{accessible_objects_all} =
                    [sort @accessible_objects_tables,@accessible_objects_views];

     BrowseDB::TkUtils::Progress($r_glbl,70);

     my @accessible_objects_scripts=
               dbdrv::accessible_objects($r_glbl->{'dbh'},
                                         $r_glbl->{user},
                                         "FUNCTION,PROCEDURE",
                                         "PUBLIC,USER");

    my $script_listbox_widget= $r_glbl->{MainWindow}->{script_listbox_widget};
    $script_listbox_widget->delete(0, 'end');
    $script_listbox_widget->insert("end",  @accessible_objects_scripts );
    $r_glbl->{MainWindow}->{notebook}->pageconfigure("DlgScr", state=>"normal");

     BrowseDB::TkUtils::Progress($r_glbl,85);

    my $help_listbox_widget = $r_glbl->{MainWindow}->{help_listbox_widget};

    my @topics= dbdrv::get_help_topic($r_glbl->{dbh});
    my $size=10;
    my $l;
    foreach my $t (@topics)
      { $l= length($t);
        $size= $l if ($size<$l); };

    $help_listbox_widget->configure(-width=>$size);

    $help_listbox_widget->
             insert("end",  @topics );

    $r_glbl->{MainWindow}->{table_browse_widget}->delete(0, 'end');
    $r_glbl->{MainWindow}->{table_browse_widget}->
             insert("end",  @{  $r_glbl->{MainWindow}->{accessible_objects_all} } );

    # opens or create a new history file
    $r_glbl->{filename_sql_history} =
                   $r_glbl->{dir} . join("_","/history",
                                  $r_glbl->{db_driver},
                                  $r_glbl->{db_source},
                                  $r_glbl->{user});
#@@@@@@@@@@@@@ change here!

    if (-r $r_glbl->{filename_sql_history})
      {
            $r_glbl->{handle_sql_history} =
                     new IO::File "< ".$r_glbl->{filename_sql_history};
            if (! defined ($r_glbl->{handle_sql_history}))
              {
                tkdie($r_glbl,
                      "History file " . $r_glbl->{filename_sql_history} .
                      " can not be opened. Error in line " . __LINE__)
              }
            my $fh=$r_glbl->{handle_sql_history};
            my $sql_history_widget=
                  $r_glbl->{MainWindow}->{sql_history_widget};
            while (my $line = <$fh>)
              {
                $sql_history_widget->insert("end", $line);
                $sql_history_widget->see("end");
              }
            $r_glbl->{handle_sql_history}->close;
      }

    $r_glbl->{handle_sql_history} =
             new IO::File ">> ".$r_glbl->{filename_sql_history};
    if (! defined ($r_glbl->{handle_sql_history}))
      {
            tkdie($r_glbl,
                  "History file " .
                  $r_glbl->{filename_sql_history} .
                  " can not be opened. Error in line " . __LINE__)
      };
    my $fh=$r_glbl->{handle_sql_history};
    BrowseDB::TkUtils::Progress($r_glbl,100);
    BrowseDB::TkUtils::SetBusy($r_glbl,0);

    $fh->flush();
    if ($r_glbl->{fast_test})
      { $r_glbl->{new_table_name}= $fast_table;
            tk_open_new_object($r_glbl, 'table_or_view');
      };

    BrowseDB::TkUtils::Progress($r_glbl,0);

  }

sub tk_dump_global
  { my($r_glbl)= @_;
# ommit dumping the tables-structures completely

    my %glbl_copy;
    foreach my $k (keys %$r_glbl)
      { if ($k eq 'all_tables')
          { my $r_t= $r_glbl->{$k};
            foreach my $tab_name (keys %$r_t)
              { $glbl_copy{all_tables}->{$tab_name}= "REF TO TABLE-HASH"; }
            next;
          };
        $glbl_copy{$k}= $r_glbl->{$k};
      };

    my $buffer;

    rdump(\$buffer,\%glbl_copy,0);

    BrowseDB::TkUtils::MakeTextWidget($r_glbl,"Global datastructure dump",\$buffer);
  }

sub tk_object_dict_dump
 { my($r_glbl)= @_;

   my $r_buffer= dbdrv::dump_object_dict_s();

   BrowseDB::TkUtils::MakeTextWidget($r_glbl,"Object dictionary dump",$r_buffer);
 }

sub tk_r_object_dict_dump
 { my($r_glbl)= @_;

   my $r_buffer= dbdrv::dump_r_object_dict_s();

   BrowseDB::TkUtils::MakeTextWidget($r_glbl,"Reverse object dictionary dump",$r_buffer); }

sub tk_update_window_menu
  { my($r_glbl) =@_;
    my $r_all_tables= $r_glbl->{all_tables};

    my @all_table_names;

    if (defined $r_all_tables)
      { @all_table_names  = (sort keys %$r_all_tables); };

    my $MnWindow= $r_glbl->{MainWindow}->{menu_windows_widget};
    $MnWindow->delete(0,'end');

    $MnWindow->add('command',
                    -label=> 'raise all',
                   -command =>
                            sub { foreach my $win (@all_table_names)
                                    { $r_all_tables->{$win}->
                                           {top_widget}->raise();
                                    };
                                }
                  );

    foreach my $win (@all_table_names)
      { $MnWindow->add('command',
                       -label=> $win,
                       -command =>
                            sub { my $w= $r_all_tables->{$win}->{top_widget};
                                  $w->raise();
                                  $w->focus();
                                }
                      );
      };
  }

sub tk_reload_all_objects
# reloads all objects from the database
  { my($r_glbl)= @_;

    my $r_all_tables= $r_glbl->{all_tables};
    return if (!defined $r_all_tables);

   BrowseDB::TkUtils::SetBusy($r_glbl,1);

    foreach my $table (keys %$r_all_tables)
      { my $r_tbh= $r_all_tables->{$table};
        cb_reload_db($r_glbl,$r_tbh);
      };

   BrowseDB::TkUtils::SetBusy($r_glbl,0);

  }


sub tk_sql_commands
  { my($r_glbl)= @_;

    my $r_text= BrowseDB::TkUtils::MakeTextWidget($r_glbl,"SQL command trace");

    my $Top= $r_text->{Top};


    $r_glbl->{sql_commands_widget}= $r_text->{text_widget};

    dbdrv::set_sql_trace_func(\&dbi_sql_trace);
    $dbdrv::sql_trace=1;

    $Top->bind('<Destroy>', sub { $dbdrv::sql_trace=0;
                                  dbdrv::set_sql_trace_func();
                                  delete $r_glbl->{sql_commands_widget};
                                });
  }

sub tk_handle_table_browse_entry
# action:1 insert 0: delete, -1: forced validation
  { my($r_glbl, $proposed, $chars_added,
       $value_before, $index, $action)= @_;

    my $table_browse_widget= $r_glbl->{MainWindow}->{table_browse_widget};

    my $rewrite_value;

    if (uc($proposed) ne $proposed)
      { $proposed= uc($proposed);
        $rewrite_value= 1;
      };

    # print join(",",$proposed, $chars_added,
    #            $value_before, $index, $action),"\n";

    my @matches= grep { $_ =~ /^$proposed/ } (@{$r_glbl->{MainWindow}->{accessible_objects_all}});

    if (!@matches)
      { # the table doesnt exist
        $table_browse_widget->bell();
        return(0);
      };

    if ($#matches != $r_glbl->{MainWindow}->{table_browse_obj_matched})
      { #  $r_glbl->{table_browse_widget}->configure(-choices=>\@matches);
        $table_browse_widget->delete(0,'end');
        @matches= sort @matches;
        $table_browse_widget->insert('end', @matches);
        $r_glbl->{MainWindow}->{table_browse_obj_matched}= $#matches;
      };

    my $completion= same_start(\@matches);
    if ((defined $completion) && ($action==1)) # action=1: insert
      {
        if (length($completion)>length($proposed))
          { $proposed= $completion;
            $rewrite_value= 1;
          };
      };

    my @exact  = grep { $_ eq $proposed } (@{$r_glbl->{MainWindow}->{accessible_objects_all}});
    my $table_browse_button= $r_glbl->{MainWindow}->{table_browse_button};
    if ($#exact<0)
      { $table_browse_button->configure(-state=>"disabled"); }
    else
      { $table_browse_button->configure(-state=>"active");

        $r_glbl->{new_table_name}= $proposed;
      };

    if ($rewrite_value)
      {
      
        my $Entry= $table_browse_widget->Subwidget('entry');
        my $r_var= ($Entry->configure('-textvariable'))[4];
        $$r_var= $proposed;
        $Entry->icursor('end');
        # re-activate the validate option, needed since return(0)
        # de-activates it
        $Entry->configure('-validate','key');
        return(0);
      };

    return(1);
  }



sub tk_execute_new_query
# routine for executing free sequel
  { my($r_glbl, $sqlinput)= @_;
    my $fh = $r_glbl->{handle_sql_history};
    my $sql_history_widget= $r_glbl->{MainWindow}->{sql_history_widget};
    my $sql_command_widget= $r_glbl->{MainWindow}->{sql_command_widget};
    my @sqlcommands = dbdrv::split_sql_command($sqlinput);

    BrowseDB::TkUtils::Progress($r_glbl, 0);
    my $size = $#sqlcommands;
    my $counter = 0;
    for (my $counter = 0; $counter < $size + 1; $counter++)
    {
        my $sqlquery = $sqlcommands[$counter];
        my ($sqlcommand, $sqlargs) = ($sqlquery =~ /^\s*(\w+)\b(.*)/);
        if (! defined ($sqlcommand))
        { BrowseDB::TkUtils::err_dialog($r_glbl->{main_menu_widget},
                        "Invalid SQL commandstring");
            return;
        }
        if (dbdrv::check_alias($sqlcommand))
        { $sqlargs=~ s/^\s+//;
            my @sqloptions = &parse_line('(\s+|\s*,\s*)', 0, $sqlargs);
            $sqlquery = dbdrv::get_alias($sqlcommand, @sqloptions);
            if ($sqlquery=~ /^ERROR/i)
            { BrowseDB::TkUtils::err_dialog($r_glbl->{main_menu_widget},
                            $sqlquery);
                return;
            }
        }

        $sqlquery = dbdrv::format_sql_command($sqlquery);

        if ($sqlquery =~ /^select /i)
        {
            if (length($sqlquery) >= 6)
            {
                my $StatementResult = make_table_hash_and_window(
                                $r_glbl,
                                table_name=>"SQL:" . $r_glbl->{sql_win_count}++,
                                table_type=>"sql",
                                sequel=>$sqlquery);
            }
        }
        else
        {
            my $TraceFormat;
            my $StatementResult = dbdrv::prepare(\$TraceFormat,
                                                $r_glbl->{dbh}, $sqlquery);

            if ($StatementResult)
            {
                if (!dbdrv::execute($TraceFormat,$r_glbl->{dbh},
                                    $StatementResult))
                { BrowseDB::TkUtils::err_dialog($r_glbl->{main_menu_widget},
                                $DBI::errstr
                                );
                }
            }
            else
            {
                    BrowseDB::TkUtils::err_dialog($r_glbl->{main_menu_widget},
                                $DBI::errstr
                                );
            }

        }
        BrowseDB::TkUtils::Progress($r_glbl, ($counter/($size+1))*100);
        if (! defined ($r_glbl->{dbh}->err))
        {
            $sql_command_widget->delete('sel.first', 'sel.last');
            $sql_history_widget->insert('end', "\n");
            $sql_history_widget->insert('end', "$sqlquery;", "green");
            $sql_history_widget->insert('end', "\n");
            print $fh "\n".$sqlquery.";\n";

        }

    }
    BrowseDB::TkUtils::Progress($r_glbl, 100);
    $sql_history_widget->see("end");
    $fh->flush();
    BrowseDB::TkUtils::Progress($r_glbl, 0);
    return $size;
}

# quit-dialog:
#_______________________________________________________

sub tk_quit_main
  {
# $r_glbl all the globals, if defined top_widget and $r_tbh so it is finally
# only a closing# table_hash_window, otherwise it is a closing application call
# returns: <undef> if the window was closed
#           1 if the window was not closed (on request by the user)

    my($r_glbl)= @_;

    my $message = "\nor do you want to save your changes before?";
    my $choice;
    my $mode;
    my $Top;
    my @options;

  
    $Top = $r_glbl->{main_menu_widget};
    my $r_tab= $r_glbl->{all_tables};
    if ((!defined $r_tab) or (!%$r_tab)) # no open tables
      { $choice="close"; };

    if ($r_glbl->{fast_test})
      { $choice = "close"; };

    while(!defined $choice)
      {
        $choice = $Top->Dialog(
                    -title => 'Quit',
                    -text => "Save your open tables as a collection " .
                             "before quitting?",
                    #-default_button => 'No',
                    -buttons => ['Save', 'Quit without save', 'Cancel']
                    )->Show();

        if    ($choice eq 'Cancel')
          { return 1; }
        elsif ($choice eq 'Save')
          {
            if (!tk_save_collection ($Top, $r_glbl))
              { $choice=undef;
                next;
              };
          }
        else # quit without save
          { last; };
      }; # while()

    if (exists($r_glbl->{handle_sql_history}))
      { my $fh = $r_glbl->{handle_sql_history};
        $fh->flush();
        $fh->close();
      };

    # from here, close application
    if (defined $r_tab)
      { # now close every single table window
        foreach my $tab (keys %$r_tab)
          { if (tk_quit_table($r_glbl,$r_tab->{$tab},'close')) 
              { return(1); };
          };
      };
    exit(0);
  }


sub tk_quit_table
  {
# returns: <undef> if the window was closed
#           1 if the window was not closed (on request by the user)
# action: 'close' or 'reload'
    my($r_glbl, $r_tbh, $action)= @_;

    my $choice;
    my $mode;
    my $Top;
    my $message= "save changes in " .
                 $r_tbh->{table_type} . " " .
                 $r_tbh->{table_name};
    my @options;

    $Top = $r_tbh->{top_widget};

    
    if   ($action eq 'reload')
      {
        $message.= " before re-loading from the database ?";
        @options= ('Save to file', 'Reload without save', 'Cancel');
      }
    elsif ($action eq 'close')
      {
        $message.= "?";
        @options= ('Save to file', 'Save to database',
                   'Close without save', 'Cancel');
      }
    else
      { die "unknown action: $action"; };
      

    if ($r_glbl->{fast_test})
      { $choice = "close"; };

    if (!table_changed($r_tbh))
      { $choice = "close"; };
    
    while(!defined $choice)
      {
        $choice = $Top->Dialog(
                    -title => 'Quit',
                    -text => $message,
                    #-default_button => 'No',
                    -buttons => \@options,
                    )->Show();

        if    ($choice eq 'Cancel')
          { return(1); }
        elsif ($choice eq 'Save to file')
          { if (!tk_save_to_file ("",$r_tbh))
              {
                $choice=undef;
                next;
              };
          }
        elsif ($choice eq 'Save to database')
          { if (!cb_store_db($r_glbl,$r_tbh))
              { $choice=undef;
                next;
              };
          }
        else
          { last; }; # close without save
      }; # while()

    if ($action eq 'close')
      { $Top->destroy();
        return;
      };

  }


# create table window:
#_______________________________________________________

sub tk_open_new_object
# $condition can be the Where-Clause
# $type can be "view", "table","sql" or "table_or_view"
#  the latter means that the type of the object is not known
  { my($r_glbl, $type, $condition, $order)= @_;
    my %known_types= map { $_ =>1 } qw( table view sql table_or_view);

    my %params;
    $params{table_name}= uc( $r_glbl->{new_table_name} );
    delete $r_glbl->{new_table_name};


    # setting kind of db object
    if (lc($type) =~ /(table|view|sql)/)
      {  $params{table_type} = lc($type); }
    else
      {  die "unsupported table type: $type"; #$params{table_type} = "sql";
      }

    if (defined $condition)
      { if ($condition!~ /^\s*$/)
          { chomp($condition);
            $params{table_filter}= $condition; };
      };

    if (defined $order)
      { if ($order!~ /^\s*$/)
          { chomp($order);
            $params{table_order}= $order; };
      };
    make_table_hash_and_window($r_glbl,%params);
  }

sub make_table_hash_and_window
  { my($r_glbl,%options)= @_;
# known options:
#   table_name   => $table_name
#   table_type   => $type, $type either 'table','view', 'sql' or
#                   'table_or_view'
#   table_filter => $WHERE_part
#        $WHERE_part is added after "WHERE" to the SQL fetch command
#        this is not allowed for the type "sql" (see above)
#   sequel       => $sql_statement
#        only for the type "sql", specifies the SQL fetch command
#   geometry     => $geometry_string
#                   can be used to set the window geometry
#   displayed_cols=> %\display_col_hash
#        where column-names are hash-keys, values are "1"
#        for displayed and "0" for hidden columns
#        this parameter is optional !
#   sort_columns  => a list of columns that defines the sort-order
#        OPTIONAL
#   col_map_flags => \%col_map_flag_hash
#         this hash contains 'N' for columns where the mapping
#         is inactive and 'M' for columns where the mapping is
#         active. This parameter is optional
#   col_maps => \%col_hash
#         col_hash contains an SQL statement for certain columns
#         this parameter is optional

    if ($options{table_type} =~ /(table|view|sql|table_or_view)/)
      {
        if (!exists $r_glbl->{all_tables})
          { $r_glbl->{all_tables}= {}; };
      }
    else
      { BrowseDB::TkUtils::err_dialog($r_glbl->{main_menu_widget},
                      "unsupported table type: $options{table_type}");
        return;
      }

    my $r_all_tables= $r_glbl->{all_tables};

    my $table_name= $options{table_name};

    my $r_tbh= $r_glbl->{all_tables}->{$table_name};

    # if the table is already opened, just raise the
    # table window
    if (defined $r_tbh)
      { $r_tbh->{top_widget}->raise();
        return ($r_tbh);
      };

    BrowseDB::TkUtils::SetBusy($r_glbl,1);
    BrowseDB::TkUtils::Progress($r_glbl,10);

    $r_tbh= make_table_hash($r_glbl,%options);

    #warn "make_table_hash returns $r_tbh";

    if (!defined $r_tbh)
      { BrowseDB::TkUtils::SetBusy($r_glbl,0);
        BrowseDB::TkUtils::Progress($r_glbl,0);
        BrowseDB::TkUtils::err_dialog($r_glbl->{main_menu_widget},
                      "opening of the table failed!");
        return;
      };

    $r_all_tables->{$table_name}= $r_tbh;

    BrowseDB::TkUtils::Progress($r_glbl,90);

    make_table_window($r_glbl,$r_tbh);

    # Note: calling tk_progress before tk_set_busy
    # creates a dubious warning:
    #    Use of uninitialized value in subroutine entry at
    #    ./browsedb.pl line 586.
    # which is the update() call in tk_progress

    BrowseDB::TkUtils::SetBusy($r_glbl,0);

    #tk_progress($r_glbl,100);

    BrowseDB::TkUtils::Progress($r_glbl,0);

    return($r_tbh);
  }

sub make_table_hash
# elements of %hash_defaults (the table-hash):
#
#   table_name   => $table_name
#   table_type   => $type, $type either 'table','view', ,'sql' or
#                   'table_or_view'
#   table_filter => $WHERE_part
#        $WHERE_part is added after "WHERE" to the SQL fetch command
#        this is not allowed for the type "sql" (see above)
#   sequel       => $sql_statement
#        only for the type "sql", specifies the SQL fetch command
#   displayed_cols=> %\display_col_hash
#        where column-names are hash-keys, values are "1"
#        for displayed and "0" for hidden columns
#        this parameter is optional !
#   sort_columns    => a list of columns that defines the sort-order
#        OPTIONAL
#   col_map_flags => \%col_map_flag_hash
#         this hash contains 'N' for columns where the mapping
#         is inactive and 'M' for columns where the mapping is
#         active. This parameter is optional
#   col_maps => \%col_hash
#        col_hash contains an SQL statement for certain columns
#        this parameter is optional
# -------------------------------------------------------------------
# creates a table_hash with these contents:
#  table_widget    => table-widget
#  dbh             => database-handle
#  dbitable        => dbitable_object
#  no_pk_cols      => 1 if there are no primary key columns
#  pks             => \@primary_key_column_names
#  pks_h           => \%primary_key_column_hash
#                     each key in this hash is a primary key column
#  column_list     => \@column_names_list
#  column_hash     => \%column_hash
#                     a hash that maps column-names to indices
#  column_properties
#                  => \%column_properties
#                     a hash containing definition of the given column
#  column_no       => number of columns
#  vis_column_list => equal to column_list
#  vis_column_hash => equal to column_hash
#  vis_column_no   => equal to column_no
#  vis_column_width=> equal to column_width
#  foreign_key_hash=> \%foreign_key_hash
#                     this hash maps column-names to a list containing
#                     two elements, the name of the foreign table and
#                     the column-name in the foreign table.
#  write_protected_cols=> \%write_protection_col_hash
#                     each column in this hash that maps to 'P'
#                     is write-protected
#  col_map_flags   => \%col_map_hash
#                     'N' for columns that are not mapped
#                     'M' else
#  sort_columns    => a list of columns that defines the sort-order
#  pk_list         => \@all_primary_key_list
#                     a list of all primary key values for all
#                     lines of the table
#  pk_hash         => \%primary_key_to_row_hash
#                     this hash maps primary key to row-indices
#  pk_generate     => 1,0 or -1 defines wether primary keys are generated
#                     (when pk_generate>0)
#                     -1 means that generation is switched off and
#                     cannot be changed
#  row_no          => the number of rows of the table
#  changed_cells   => \%changed_cells_hash
#                     initially empty, later this is a hash mapping
#                     "$pk;$colname" to "$row,$col", that has an
#                     entry for each changed cell
#  changed_rows    => initially empty, later this is a hash mapping
#                      "$pk" to "$row"
#  displayed_cols  => \%displayed_columns
#                     this hash has an entry for each column. It is
#                     set to 1 when the column is actually displayed,
#                     else it is set to 0
  { my($r_glbl,%hash_defaults)= @_;

    my $dbh= $r_glbl->{dbh};

    my %table_hash= %hash_defaults;

    # the database-handle:
    $table_hash{dbh}        = $dbh;

    BrowseDB::TkUtils::Progress($r_glbl,30);

    # the dbitable object:
    $table_hash{dbitable}  = get_dbitable($r_glbl,\%table_hash);
# warn "get_dbitable($r_glbl,\%table_hash) = $table_hash{dbitable} ";
    BrowseDB::TkUtils::Progress($r_glbl,50);

    if (! defined $table_hash{dbitable})
      {
        warn "unable to open query with dbitable!!\n";
        return;

      }; # was unable to open table

    # $table_hash{dbitable}->dump(); die;

#print "***CNT:",$table_hash{dbitable}->{_counter_pk},"\n";
    my @pks= $table_hash{dbitable}->primary_key_columns();
#print "PKS:",join("|",@pks),"\n";
    if (!@pks)
      { # this is the special case where there is no primary key column
        $table_hash{no_pk_cols}=1;
      }
    else
      { # the primary key column name
        $table_hash{pks}= \@pks;
        # primary key hash, this is currently needed in the popup-menu
        $table_hash{pks_h}= { map { $_ => 1 } @pks };
      };

    if (!$table_hash{dbitable}->primary_key_auto_generate_possible())
      { $table_hash{pk_generate}= -1; # autogen of, not-changable
      }
    else
      { $table_hash{pk_generate}= $r_glbl->{primary_key_auto_generate}; };

    table_hash_init_columns(\%table_hash);

    BrowseDB::TkUtils::Progress($r_glbl,70);

    # the foreign-key hash
    # this is just the pure information from the database which
    # columns are foreign keys. This has nothing to do with the
    # fact wether that foreign key table is displayed or not

    # requesting the foreign keys makes only sense
    # on tables, not on views or SQL statements:
    if ($table_hash{table_type} eq 'table')
      { $table_hash{foreign_key_hash}=
                  $table_hash{dbitable}->foreign_keys();
      };

    BrowseDB::TkUtils::Progress($r_glbl,80);

    # the list with write-protected column-indices:
    # P: protected, T: temporarily writable, undef: writable
    my %wp;

    if (!$table_hash{no_pk_cols})
      { foreach my $col (@{$table_hash{pks}})
          { $wp{$col}='P'; };
      };

    foreach my $col (keys %{$table_hash{foreign_key_hash}})
      { $wp{$col}='P'; };
    $table_hash{write_protected_cols}= \%wp;

    # column-maps specified as a parameter:
    my $r_col_maps= $table_hash{col_maps};
    if (defined $r_col_maps)
      { my %maps= %{$table_hash{col_maps}};
        delete $table_hash{col_maps};

        foreach my $c (keys %maps)
          { set_column_map($r_glbl,\%table_hash,$maps{$c},$c);
          };
      };

    # now apply local and global column-maps
    foreach my $k (qw(local global))
      { $r_col_maps= $r_glbl->{"column_map_definitions_$k"};
        if (defined $r_col_maps)
          { $r_col_maps= $r_col_maps->{$table_hash{table_name}};
            if (defined $r_col_maps)
              { foreach my $c ( keys %$r_col_maps )
                  { next if (column_has_a_map(\%table_hash,$c));
                    set_column_map($r_glbl,\%table_hash,
                                   $r_col_maps->{$c},$c);
                  };
              };
          };
      };

    # calculate column-map flags
    my $r_cm= $table_hash{col_map_flags};
    if (!defined $r_cm)
      { my %h;
        $r_cm= \%h;
        $table_hash{col_map_flags}= \%h;
      };
    foreach my $col (@{$table_hash{column_list}})
      { if (!exists $table_hash{col_maps}->{$col})
          { $r_cm->{$col}= 'N'; next; };
        if (!exists $r_cm->{$col})
          { $r_cm->{$col}= 'N'; };
      };

    # the hash that is used for sorting:
    if (!exists $table_hash{sort_columns})
      { $table_hash{sort_columns}= [ @{$table_hash{column_list}} ];
        initialize_sort_columns(\%table_hash);
      };


    # this list of primary key values,
    # maps the row-index to the primary key value
    $table_hash{pk_list} = get_pk_list(\%table_hash);

    $table_hash{pk_hash} = calc_pk2index(\%table_hash);

    # the number of rows:
    $table_hash{row_no}  = $#{$table_hash{pk_list}} + 1;

    # marker for changed cells in the table:
    $table_hash{changed_cells}  = {};
    $table_hash{changed_rows}   = {};

    return(\%table_hash);
  }

sub make_table_window
# known options in $r_tbh:
#  table_name    => $table_name
#  resident_there=> $resident_there
#                   adds a certain menu entry to the table menu
#                   if set to 1
#  geometry      => $geometry_string
#                   can be used to set the window geometry
#  column_list   => \@column_names_list
#  displayed_cols=> \%displayed_columns
#                   this hash has an entry for each column. It is
#                   set to 1 when the column is actually displayed,
#                   else it is set to 0
#                   OPTIONAL
#  vis_column_no => number of visible columns
#  row_no        => the number of rows of the table
# -----------------------------------------------------
# sets the following parts in $r_tbh:
# display_mode  => $display_mode, either 'table'or 'form' or 'info' or
#                       'dependencies'
# top_widget    => $top-widget
# frame_top     => fastbar container
# frame_down    => tablematrix container
# table_widget  => $table_widget
# column_popup  => \%column_popup_data_hash
# default_popup => \%default_popup_data_hash
#
  { my($r_glbl,$r_tbh)= @_;

    # create a new top-window
    my $Top= BrowseDB::TkUtils::MakeToplevel($r_glbl,
                         title    => $r_tbh->{table_name},
                         geometry => $r_tbh->{geometry},
                         theme_parameters($r_glbl,'table','-background')
                                            );

    tk_update_window_menu($r_glbl);

    # Whats this ???
    $Top->eventAdd('<<Paste>>' => '<Control-v>');
    $Top->eventAdd('<<Copy>>' => '<Control-c>');
    $Top->eventAdd('<<Save>>' => '<Control-s>');
    $Top->eventAdd('<<Quit>>' => '<Control-q>');

##
    $Top->protocol('WM_DELETE_WINDOW', [ \&tk_quit_table,
                                         $r_glbl,$r_tbh,'close'
                                       ]
                  );


    delete $r_tbh->{geometry}; # no longer needed

    $r_tbh->{top_widget}= $Top;

    # set the title

    my %top_opts = theme_parameters($r_glbl,'table:menubar',
                                    '-background','-foreground',
                                    '-font');
    my %menu_opts= theme_parameters($r_glbl,'table:menubar',
                                   '-background','-foreground',
                                   '-font',
                                   '-activebackground',
                                   '-activeforeground',
                                   );
    my $FrTop = $Top->Frame(
                    -height=>14,
                    -relief=>"raised",
                    theme_parameters($r_glbl,'table:menubar',
                                   '-background')
        );
    $r_tbh->{frame_top} = $FrTop;
    $FrTop->Label(-text=>" Where ",
                    -relief=>"flat",
                    -pady=>1, -padx=>1,
                    -justify=>"right",
                    -anchor=>"w",
                    %top_opts
        )->pack(-expand=>0, -side=>"left");

#    my $WhereField = $FrTop->Entry(-foreground=>"orange",
    $r_tbh->{fastbar}->{filter} = $FrTop->BrowseEntry(-foreground=>"orange",
                    -justify=>"left",
                    -relief=>"sunken",
                    -exportselection=>1,
                    -variable=>\$r_tbh->{table_filter},
                    %top_opts
        )->pack(-expand=>1, -fill=>"x", -side=>"left");

    $FrTop->Label(-text=>" Order by ",
                    -relief=>"flat",
                    -pady=>1, -padx=>1,
                    -justify=>"right",
                    -anchor=>"w",
                    %top_opts
        )->pack(-expand=>0, -side=>"left");

    $r_tbh->{fastbar}->{order} = $FrTop->BrowseEntry(-foreground=>"orange",
                    -justify=>"left",
                    -relief=>"sunken",
                    -exportselection=>1,
                    -variable=>\$r_tbh->{table_order},
                    %top_opts
        )->pack(-expand=>1, -fill=>"x", -side=>"left");

    my $OkButton = $FrTop->Button(-text => "Set",
                    -command=> [ \&cb_reload_db, $r_glbl, $r_tbh ],
                    -underline=> 0,
                    -justify=>"center",
                    -relief=>"raised",
                    %top_opts
        )->pack(-expand=>0, -side=>"left");

    #$r_tbh->{frame_top}->packForget;

    my $FrDn  = $Top->Frame(theme_parameters($r_glbl,
                            'table','-background')
                           )->pack(-side=>'top' ,
                                -fill=>'both',
                                -anchor=>'sw',
                                -expand=>'y');
    $r_tbh->{frame_down} = $FrDn;

    # the Menu-Bar is now created in a way that works on
    # windows to0. Note that this is a property of the
    # top widget, $MnTop MUST NOT be packed

    my $MnTop= $Top->Menu(%menu_opts);
    $Top->configure(-menu => $MnTop );

    my $MnFile  = $MnTop->Menu(%menu_opts);
    my $MnDbase = $MnTop->Menu(%menu_opts);
    my $MnPref  = $MnTop->Menu(%menu_opts);
    my $MnEdit  = $MnTop->Menu(%menu_opts);
    my $MnView  = $MnTop->Menu(%menu_opts);
    my $MnHelp  = $MnTop->Menu(%menu_opts);

    $MnTop->add('cascade',
                -label=> 'File',
                -underline   => 0,
                -menu=> $MnFile
                );

    $MnTop->add('cascade',
               -label=> 'Database',
               -underline   => 0,
               -menu=> $MnDbase
               );

    $MnTop->add('cascade',
                -label=> 'Preferences',
                -underline   => 0,
                -menu=> $MnPref
                );
    $MnTop->add('cascade',
                -label=> 'Edit',
                -underline   => 0,
                -menu=> $MnEdit
                );
    $MnTop->add('cascade',
                -label=> 'View',
                -underline   => 0,
                -menu=> $MnView
                );
    $MnTop->add('cascade',
                -label=> 'Help',
                -underline   => 0,
                -menu=> $MnHelp
                );

    # configure file-menu:
    my $MnFileOpen= $MnFile->Menu(%menu_opts);
    my $MnFileSave= $MnFile->Menu(%menu_opts);

    $MnFile->add('cascade',
                -label=> 'Import',
                -underline   => 0,
                -menu=> $MnFileOpen
                );

        $Top->bind($Top,'<Control-o>'=> [\&tk_load_from_file,$r_tbh]);
        $MnFileOpen->add('command',
                    -label=> 'Standard',
                    -accelerator => 'Ctrl+o',
                    -underline   => 0,
                    -command=> [\&tk_load_from_file, "",$r_tbh]
                    );

        $Top->bind($Top,'<Shift-Control-O>'=> [\&tk_import_csv,$r_tbh]);
        $MnFileOpen->add('command',
                    -label=> 'CSV',
                    -accelerator => 'Shift+Ctrl+o',
                    -underline   => 0,
                    -command=> [\&tk_import_csv, "", $r_tbh]
                    );

    $MnFile->add('cascade',
                -label=> 'Export',
                -underline   => 0,
                -menu=> $MnFileSave
                );

        $Top->bind($Top,'<Control-s>'=> [\&tk_save_to_file,$r_tbh]);
        $MnFileSave->add('command',
                    -label=> 'Standard',
                    -accelerator => 'Ctrl+s',
                    -underline   => 0,
                    -command=> [\&tk_save_to_file, "", $r_tbh]
                    );

        $Top->bind($Top,'<Shift-Control-S>'=> [\&tk_export_csv,$r_tbh]);
        $MnFileSave->add('command',
                    -label=> 'CSV',
                    -accelerator => 'Shift+Ctrl+s',
                    -underline   => 0,
                    -command=> [\&tk_export_csv, "", $r_tbh]
                    );

    # configure database-menu:

    my $MnDbaseRela = $MnDbase->Menu(%menu_opts);

    if ($r_tbh->{table_type} eq 'table')
      {
        $MnDbase->add('command',
                      -label=> 'Store',
                      -underline   => 0,
                      -command => [\&cb_store_db, $r_glbl,$r_tbh],
                    );
      };

    $MnDbase->add('command',
                  -label=> 'Reload',
                  -underline   => 0,
                  -command => [\&cb_reload_db, $r_glbl, $r_tbh],
                );

    $MnDbase->add('cascade',
                -label=> 'Relation',
                -underline   => 0,
                -menu=> $MnDbaseRela
               );

        if ($r_tbh->{table_type} eq 'table')
        { $MnDbaseRela->add('command',
                        -label=> 'Dependend tables',
                        -underline   => 10,
                        -command => [\&tk_dependency_dialog, $r_glbl, $r_tbh],
                        );
        };

        if ($r_tbh->{table_type} ne 'sql')
        {
            $MnDbaseRela->add('command',
                        -label=> 'Dependend views',
                        -underline   => 10,
                        -command => [\&tk_dependend_views_dialog, $r_glbl, $r_tbh],
                        );
        };

        if ($r_tbh->{table_type} eq 'table')
        { $MnDbaseRela->add('command',
                        -label=> 'Referenced tables',
                        -underline   => 0,
                        -command => [\&tk_references_dialog, $r_glbl, $r_tbh],
                        );
        };
        if ($r_tbh->{table_type} eq 'view')
        { $MnDbaseRela->add('command',
                        -label=> 'Referenced objects',
                        -underline   => 11,
                        -command => [\&tk_view_dependency_dialog, $r_glbl, $r_tbh],
                        );
        };

    # configure preferences-menu:
    $MnPref->add(
                  'checkbutton',
                   -label=> 'auto-generate primary keys',
                   -variable => \$r_tbh->{pk_generate},
                   -state => ($r_tbh->{pk_generate}==-1) ?
                               'disabled' : 'normal'
                );

    # configure edit-menu:
    my $MnEditField= $MnEdit->Menu(%menu_opts);
    my $MnEditLine = $MnEdit->Menu(%menu_opts);


    $Top->bind($Top,'<Control-f>'=> [\&tk_find_line,$r_glbl, $r_tbh]);
    $MnEdit->add('command',
                  -label=> 'Find in column',
                  -accelerator => 'Ctrl+f',
                  -underline   => 8,
                  -command => [\&tk_find_line, "", $r_glbl, $r_tbh],
                );
    $Top->bind($Top,'<Control-g>'=> [\&tk_find_line_next,
                                     $r_glbl, $r_tbh,'next']);
    $MnEdit->add('command',
                  -label=> 'Find next column',
                  -accelerator => 'Ctrl+g',
                  -underline   => 5,
                  -command => [\&tk_find_line_next, "",
                               $r_glbl, $r_tbh,'next'],
                );
    $Top->bind($Top,'<Shift-Control-G>'=> [\&tk_find_line_next,
                                           $r_glbl, $r_tbh,'prev']);
    $MnEdit->add('command',
                  -label=> 'Find prev column',
                  -accelerator => 'Shift+Ctrl+g',
                  -underline   => 5,
                  -command => [\&tk_find_line_next, "",
                               $r_glbl, $r_tbh,'next'],
                );
    $MnEdit->add('cascade',
                  -label=> 'Field',
                  -underline   => 0,
                  -menu => $MnEditField,
                );
    $MnEdit->add('cascade',
                  -label=> 'Line',
                  -underline   => 0,
                  -menu => $MnEditLine,
                );

    $MnEditLine->add('command',
                      -label=> 'Insert',
                      -underline   => 0,
                      -command => [\&cb_insert_line, $r_glbl, $r_tbh],
                    );
    $MnEditLine->add('command',
                      -label=> 'Delete',
                       -underline   => 0,
                      -command => [\&tk_delete_line_dialog, $r_glbl, $r_tbh],
                    );
    $MnEditLine->add('command',
                      -label=> 'Copy',
                      -underline   => 0,
                      -command => [\&cb_copy_paste_line,
                                   $r_glbl, $r_tbh, 'copy'],
                    );
    $MnEditLine->add('command',
                      -label=> 'Paste',
                      -underline   => 0,
                      -command => [\&cb_copy_paste_line,
                                   $r_glbl, $r_tbh, 'paste'],
                    );

    $MnEditField->add('command',
                       -label=> 'Enter value',
                       -underline   => 0,
                       -command => [\&tk_field_edit, $r_glbl, $r_tbh],
                     );

    $MnEditField->add('command',
                      -label=> 'Copy',
                      -underline   => 0,
                      -command => [\&cb_copy_paste_field,
                                   $r_glbl, $r_tbh, 'copy'],
                     );
    $MnEditField->add('command',
                       -label=> 'Paste',
                       -underline   => 0,
                       -command => [\&cb_copy_paste_field,
                                    $r_glbl, $r_tbh, 'paste'],
                     );



    # configure view-menu:
    # create the sub-menue:

    # switching between different contents
    #$r_tbh->{display_mode} = 'form';
    $r_tbh->{display_mode} = 'table';
    $MnView->add('radiobutton',
                -label=> 'Contenttable',
                -underline=> 8,
                -command=> [ \&cb_show_content, $r_glbl, $r_tbh ],
                -variable=> \$r_tbh->{display_mode},
                -value => 'table',
                );
    $MnView->add('radiobutton',
                -label=> 'Contentform',
                -underline=> 8,
                -command=> [ \&cb_show_content, $r_glbl, $r_tbh ],
                -variable=> \$r_tbh->{display_mode},
                -value => 'form',
                );
    $MnView->add('radiobutton',
                -label=> 'Information',
                -underline=> 1,
                -command=> [ \&cb_show_content, $r_glbl, $r_tbh ],
                -variable=> \$r_tbh->{display_mode},
                -value => 'info',
                );
    $MnView->add('radiobutton',
                -label=> 'Dependencies',
                -underline=> 0,
                -command=> [ \&cb_show_content, $r_glbl, $r_tbh ],
                -variable=> \$r_tbh->{display_mode},
                -value => 'dependencies',
                );

    $MnView->add('separator');

    $MnView->add('command',
                  -label=> 'object-info',
                  -underline   => 0,
                  -command=> [\&object_info, $r_glbl, $r_tbh]
                );
 
    $MnView->add('command',
                  -label=> 'sort rows',
                  -underline   => 0,
                  -command=> [\&tk_sort_menu, $r_glbl, $r_tbh]
                );
 
 
    my $MnViewHCol = $MnView->Menu(%menu_opts);
    $MnView->add('cascade',
                  -label=> 'Hide/Unhide columns',
                  -underline   => 0,
                  -menu => $MnViewHCol
                );

    my $MnViewRela = $MnView->Menu(%menu_opts);

    $MnView->add('cascade',
                -label=> 'Relation',
                -underline   => 0,
                -menu=> $MnViewRela
               );

        if ($r_tbh->{table_type} ne 'sql')
                { $MnViewRela->add('command',
                        -label=> 'Add column map to file',
                        -underline   => 0,
                        -command =>
                            sub { add_to_local_column_maps($r_glbl,$r_tbh,
                                                    "$r_glbl->{dir}/$column_map_file");
                                }
                        );
                };

        $MnViewRela->add('command',
                    -label=> 'Add scroll-relation',
                    -underline   => 0,
                    -command => [\&tk_add_relation_dialog, $r_glbl, $r_tbh],
                    );

        $MnViewRela->add('command',
                    -label=> 'Show scroll-relations',
                    -underline   => 0,
                    -command => [\&tk_show_scroll_relations, $r_glbl, $r_tbh],
                    );

        if ($r_tbh->{resident_there})
        { $MnViewRela->add('command',
                        -label=> 'Select value',
                        -underline   => 0,
                        -command => [\&cb_select, $r_glbl, $r_tbh],
                        );
        }
        else
        {
            # warn "NO resident_key in table $r_tbh->{table_name} !!!";
        };


    $MnView->add('checkbutton',
                  -label=> 'Hide/Unhide fastbar',
                  -underline   => 11,
                  -command => [ \&cb_build_fastbar, $r_glbl, $r_tbh ],
                  -variable => \$r_tbh->{fastbar}->{show},
                );

    $MnHelp->add('command',
                  -label=> 'Dump Object',
                  -underline   => 0,
                  -command => [\&tk_table_dump, $r_glbl, $r_tbh],
                );
    $MnHelp->add('command',
                  -label=> 'Dump dbitable',
                  -underline   => 1,
                  -command => [\&tk_dbitable_dump, $r_glbl, $r_tbh],
                );

    foreach my $col (@{$r_tbh->{column_list}})
      { $MnViewHCol->add('checkbutton',
                         -variable=> \$r_tbh->{displayed_cols}->{$col},
                         -label=> $col,
                         -command=>  [\&cb_set_visible_columns,
                                      $r_glbl, $r_tbh ]
                        );
      };

    if ($r_tbh->{fastbar}->{show})
      { &cb_build_fastbar ($r_glbl, $r_tbh); }

   # --------------------- fastpath widget

    $Top->bind('<Control-Enter>', sub { &cb_reload_db ($r_glbl, $r_tbh) } );

    $r_tbh->{fastbar}->{filter}->bind('<Return>', 
                            sub { &cb_reload_db ($r_glbl, $r_tbh) } );

    $r_tbh->{fastbar}->{order}->bind('<Return>', 
                            sub { &cb_reload_db ($r_glbl, $r_tbh); } );

    cb_show_content($r_glbl, $r_tbh);
  }

sub cb_build_fastbar
  {
    my($r_glbl, $r_tbh)= @_;
    if ($r_tbh->{fastbar}->{show})
      {
        $r_tbh->{frame_top}->pack(-side=> "top",
                    -fill=> "x",
                    -anchor=> "nw",
                    -before=>$r_tbh->{frame_down},
                    -expand=> 0,);

      }
    else
      {
        $r_tbh->{frame_down}->packForget();
        $r_tbh->{frame_top}->packForget();
        $r_tbh->{frame_down}->pack(-side=>'top' ,
                -fill=>'both',
                -anchor=>'sw',
                -expand=>'y');
      }
  }

sub cb_show_content
  { 
    my($r_glbl, $r_tbh)= @_;
    my $dmode= $r_tbh->{display_mode};

    if ($dmode eq 'table')
      {
        cb_show_contenttable($r_glbl, $r_tbh);
      }
    elsif ($dmode eq 'form')
      {
        cb_show_contentform ($r_glbl, $r_tbh);
      }
    elsif ($dmode eq 'info')
      {
        cb_show_objectinfo ($r_glbl, $r_tbh);
      }
    elsif ($dmode eq 'dependencies')
      {
        cb_show_dependencies ($r_glbl, $r_tbh);
      }
    else
      { die "display_mode has wrong value:" . $r_tbh->{display_mode} .
            "(assertion)";
      }; 
  }      
         
sub cb_show_contenttable
  {
    my($r_glbl, $r_tbh)= @_;
    # --------------------- table widget

    my $FrDn = $r_tbh->{frame_down};
    
    
    #$FrDn->gridForget($FrDn->gridSlaves());
    BrowseDB::TkUtils::ungrid($FrDn);
    #$r_glbl->{main_menu_widget}->update();
    
    $FrDn->gridRowconfigure   (0,-weight=>1); # make it stretchable
    $FrDn->gridColumnconfigure(0,-weight=>1); # make it stretchable
    $FrDn->gridRowconfigure   (1,-weight=>0); # make it non-stretchable
    $FrDn->gridColumnconfigure(1,-weight=>0); # make it non-stretchable

    my $Table= $FrDn->TableMatrix
    #my $Table= $FrDn->Spreadsheet
                                (-command =>
                                        [\&cb_put_get_val,
                                        $r_tbh
                                        ],
                                -usecommand=> 1,
                                -browsecommand=>
                                        [\&cb_handle_browse,$r_glbl,$r_tbh],
                                #-coltagcommand =>\&coltag,
                                -selecttitle=> 0,
                                -titlerows => 1,
                                -height =>5,
                                -width  =>0,
                                -cols => $r_tbh->{vis_column_no},
                                -rows => $r_tbh->{row_no} + 1,
                                                    # 1 more f.the heading
                                -justify => "left",
                                -colstretchmode => "all",
#-colstretchmode => "none",
                                -rowstretchmode => "none", #"unset",
#-rowstretchmode => "unset",
                                -selectmode=> 'extended',
                                #-flashmode=> 1,
                                #-width => $dbi_column_no,
                                theme_parameters($r_glbl,'table',
                                                 '-background',
                                                 '-font')
                                
                                );

    $r_tbh->{table_widget}= $Table;

    $Table->activate("1,0"); # one cell must be activated initially,
                            # otherwise index('active') produces a
                            # Tk Error, when it is used

    table_window_set_column_width($r_tbh);

    # The table is "packed" at this place !!!!!!!!!!!!!!!!!!!

    $Table->grid(-row=>0, -column=>0, -sticky=> "nsew");

    my $xscroll = $FrDn->Scrollbar(-command => ['xview', $Table],
                                -orient => 'horizontal',
                                )->grid(-row=>1, -column=>0, -sticky=> "ew");

    $Table->configure(-xscrollcommand => ['set', $xscroll]);

    my $yscroll = $FrDn->Scrollbar(-command => ['yview', $Table],
                                -orient => 'vertical',
                                )->grid(-row=>0, -column=>1, -sticky=> "ns");

    BrowseDB::TkUtils::bind_scroll_wheel($Table);

    $Table->configure(-yscrollcommand => ['set', $yscroll]);


    # mark changed cells by changing the foreground color to red
    $Table->tagConfigure('changed_cell'   ,
                         theme_parameters($r_glbl,'table:changed',
                                          '-foreground'));

    # mark changed cells by changing the foreground color to red
    $Table->tagConfigure('changed_cell_ro', 
                         theme_parameters($r_glbl,'table:changed_ro',
                                          '-foreground'));

    # create a tag for the primary key column
    $Table->tagConfigure('pk_cell', 
                         theme_parameters($r_glbl,'table:pk','-foreground'));

    # create a tag for the foreign key column
    $Table->tagConfigure('fk_cell',
                          theme_parameters($r_glbl,'table:fk','-foreground'));

    # create a tag for the manually added foreign key column
    $Table->tagConfigure('m_fk_cell', 
                          theme_parameters($r_glbl,'table:manual_fk',
                                           '-foreground'));

    # create a tag for column-mapped columns
    $Table->tagConfigure('mapped_col_on' , 
                          theme_parameters($r_glbl,'table:colmap_on',
                                           '-foreground'));

    # create a tag for column-mapped columns
    $Table->tagConfigure('mapped_col_off', 
                          theme_parameters($r_glbl,'table:colmap_off',
                                           '-foreground'));

    $Table->tagRaise('mapped_col_on','title');
    # mapped_col gets a priority higher than "title"

    $Table->tagRaise('mapped_col_off','title');
    # mapped_col gets a priority higher than "title"


    table_window_tag_columns($r_tbh);

    # popup-menu for the columns in the tablematrix widget
    my $itemcnt=0;
    my $r_itemhash={};
    my %colpopup_disable_lists= ( default    => [] );
    my %colpopup_enable_lists = ( foreign_key=> [] );
    my %column_popup;

    my $MnColPopup= $Table->Menu(-type=> 'normal', -tearoff=>0);

    my $itemlabel= 'Sort by column';
    $r_itemhash->{$itemlabel}= $itemcnt++;
    $MnColPopup->add('command',
                    -label=> $itemlabel,
                    -command =>
                        sub { tk_resort_and_redisplay(
                                    $r_tbh,
                                    $column_popup{current_col});
                            }
                    );

    $itemlabel= 'Find in column';
    $r_itemhash->{$itemlabel}= $itemcnt++;
    $MnColPopup->add('command',
                    -label=> $itemlabel,
                    -command =>
                        sub { tk_find_line("",
                                    $r_glbl, $r_tbh,
                                    $column_popup{current_col});
                            }
                    );

    $itemlabel= 'Open/Raise foreign table';
    # this is by default disabled:
    push @{$colpopup_disable_lists{default}}    ,$itemlabel;
    # however, it is enabled for foreign key columns:
    push @{$colpopup_enable_lists{foreign_key}} ,$itemlabel;
    $r_itemhash->{$itemlabel}= $itemcnt++;
    $MnColPopup->add('command',
                    -label=> $itemlabel,
                    -command =>
                        sub { cb_open_foreign_table(
                                    $r_glbl, $r_tbh,
                                    $column_popup{current_col});
                            }
                    );

    $itemlabel= 'Unhide all columns';
    $r_itemhash->{$itemlabel}= $itemcnt++;
    $MnColPopup->add('command',
                    -label=> $itemlabel,
                    -command =>
                        sub { foreach my $c (@{$r_tbh->{column_list}})
                                { $r_tbh->{displayed_cols}->{$c}=1; };
                            cb_set_visible_columns($r_glbl, $r_tbh);
                            }
                    );

    $itemlabel= 'Hide column';
    $r_itemhash->{$itemlabel}= $itemcnt++;
    $MnColPopup->add('command',
                    -label=> $itemlabel,
                    -command =>
                        sub { my $c= $column_popup{current_col};
                            $r_tbh->{displayed_cols}->{$c}=0;
                            cb_set_visible_columns($r_glbl, $r_tbh);
                            }
                    );

    my $MnColMap = $MnColPopup->Menu(-tearoff=>0);
    $itemlabel= 'Column map';
    $r_itemhash->{$itemlabel}= $itemcnt++;
    $MnColPopup->add('cascade',
                    -label=> $itemlabel,
                    -menu => $MnColMap
                    );

    # define the column-map sub-menu:
    $MnColMap->add('command',
                -label=> 'Define',
                -command =>
                        sub { tk_define_col_map($r_glbl, $r_tbh,
                                                $column_popup{current_col}
                                                );

                            }
                );
    $MnColMap->add('command',
                -label=> 'Toggle map usage',
                -command =>
                        sub { my $col= $column_popup{current_col};
                            my $f= $r_tbh->{col_map_flags}->{$col};
                            my $g= $f;
                            if ($f eq 'M')
                                { $g= 'N'; }
                            else
                                { if (exists $r_tbh->{col_maps}->{$col})
                                    { $g= 'M'; };
                                };
                            if ($f ne $g)
                                { $r_tbh->{col_map_flags}->{$col}= $g;
                                # the following forces a redraw
                                my $Table= $r_tbh->{table_widget};
                                $Table->configure(
                                            -padx => ($Table->cget('-padx'))
                                                );
                                tk_rewrite_active_cell($r_tbh);
                                table_window_title_tags($r_tbh,
                                                $column_popup{current_col});
                                };
                            }
                );
    if ($r_tbh->{table_type} ne 'sql')
    { $MnColMap->add('command',
                    -label=> 'Add column map to file',
                    -command =>
                         sub { add_to_local_column_maps(
                                           $r_glbl,$r_tbh,
                                           "$r_glbl->{dir}/$column_map_file"
                                                       );
                             }
                    );
    };

    $column_popup{popup_items} = $itemcnt;
    $column_popup{popup_item_h}= $r_itemhash;

    $column_popup{popup_disable_lists}= \%colpopup_disable_lists;

    $column_popup{popup_enable_lists} = \%colpopup_enable_lists;


    $r_tbh->{column_popup}= \%column_popup;
    $column_popup{popup_widget}= $MnColPopup;

    # popup-menu for the tablematrix widget:
    $itemcnt=0;
    $r_itemhash={};
    my %defpopup_disable_lists= ( default         => [] ,
                                write_protected => [],
                                );
    my %defpopup_enable_lists = ( foreign_key => [],
                                primary_key => [],
                                column_map  => [],
                                );

    my $MnPopup= $Table->Menu(-type=> 'normal', -tearoff=>0);
    $itemlabel= 'Edit';
    push @{$defpopup_disable_lists{write_protected}}, $itemlabel;
    $r_itemhash->{$itemlabel}= $itemcnt++;
    $MnPopup->add('command',
                -label=> $itemlabel,
                -command => [\&tk_field_edit, $r_glbl, $r_tbh],
                );


    $itemlabel= 'New value from list';
    # this is disabled by default:
    push @{$defpopup_disable_lists{default}}   , $itemlabel;
    # it is enabled if a column-map is present
    push @{$defpopup_enable_lists{column_map}} , $itemlabel;
    $r_itemhash->{$itemlabel}= $itemcnt++;
    $MnPopup->add('command',
                -label=> $itemlabel,
                -command => [\&tk_fk_select_dialog, $r_glbl, $r_tbh],
                );

    $itemlabel= 'Edit all in selection';
    # this is disabled is the column is write-protected:
    push @{$defpopup_disable_lists{write_protected}}, $itemlabel;
    $r_itemhash->{$itemlabel}= $itemcnt++;
    $MnPopup->add('command',
                -label=> $itemlabel,
                -command => [\&tk_field_edit, $r_glbl, $r_tbh, 'selected'],
                );

    $itemlabel= 'Copy';
    $r_itemhash->{$itemlabel}= $itemcnt++;
    $MnPopup->add('command',
                -label=> $itemlabel,
                -command => [\&cb_copy_paste_field,
                            $r_glbl, $r_tbh, 'copy'],
                );

    $itemlabel= 'Paste';
    # this is disabled is the column is write-protected:
    push @{$defpopup_disable_lists{write_protected}}, $itemlabel;
    $r_itemhash->{$itemlabel}= $itemcnt++;
    $MnPopup->add('command',
                -label=> $itemlabel,
                -command => [\&cb_copy_paste_field,
                                $r_glbl, $r_tbh, 'paste'],
                );

    $itemlabel= 'Find in column';
    $r_itemhash->{$itemlabel}= $itemcnt++;
    $MnPopup->add('command',
                -label=> $itemlabel,
                -command => [\&tk_find_line, "", $r_glbl, $r_tbh],
                );

    $itemlabel= 'Select THIS as foreign key';
    # this is disabled by default:
    push @{$defpopup_disable_lists{default}}    , $itemlabel;
    # it is enabled, if the column is a primary key column
    push @{$defpopup_enable_lists{primary_key}} , $itemlabel;
    $r_itemhash->{$itemlabel}= $itemcnt++;
    $MnPopup->add('command',
                -label=> $itemlabel,
                -command => [\&cb_select, $r_glbl, $r_tbh],
                );

    $itemlabel= 'Open foreign table';
    # this is disabled by default:
    push @{$defpopup_disable_lists{default}}    , $itemlabel;
    # it is enabled, if the column is a foreign key column
    push @{$defpopup_enable_lists{foreign_key}} , $itemlabel;
    $r_itemhash->{$itemlabel}= $itemcnt++;
    $MnPopup->add('command',
                -label=> $itemlabel,
                -command => [\&cb_open_foreign_table, $r_glbl, $r_tbh],
                );

    $itemlabel= 'Export selection';
    $r_itemhash->{$itemlabel}= $itemcnt++;
    $MnPopup->add('command',
                -label=> $itemlabel,
                -command => [\&cb_export_selection, $r_glbl, $r_tbh],
                );

    my %default_popup;
    $r_tbh->{default_popup}= \%default_popup;

    $default_popup{popup_widget}= $MnPopup;
    $default_popup{popup_items} = $itemcnt;
    $default_popup{popup_item_h}= $r_itemhash;

    $default_popup{popup_disable_lists}= \%defpopup_disable_lists;

    $default_popup{popup_enable_lists} = \%defpopup_enable_lists;

    if ($r_tbh->{resident_there})
    { $default_popup{popup_enable_lists}->{primary_key}=
                            ['Select THIS as foreign key'];
    };

    $Table->bind('<3>',  [\&cb_popup_menu, $r_glbl, $r_tbh, Ev('@')]);


    # bind the right mouse button to a function,
    # give it the current mouse position in the
    # form '@x,y'

    # $Table->bind('<3>', [\&cb_handle_right_button,
    #                      $r_glbl, $r_tbh, Ev('@')] );

    $Table->bind('<Control-plus>',  [\&cb_resize_col,
                                $r_glbl, $r_tbh, 'inc']);
    $Table->bind('<Control-minus>',  [\&cb_resize_col,
                                $r_glbl, $r_tbh, 'dec']);


    $Table->bind('<Destroy>', [\&cb_close_window, $r_glbl, $r_tbh] );

    #$FrDn->pack(-expand=> 1, -fill=>'both', );
  }

sub cb_show_contentform
  {
# adds "current_row" to the table-hash !!!  
    my($r_glbl, $r_tbh)= @_;
    #$key the actual key
    # --------------------- entry widget

    # repacking FrDown is important in order to get a
    # sensible window-size
    my $FrDn = $r_tbh->{frame_down};
    
    #$FrDn->gridForget($FrDn->gridSlaves());
    BrowseDB::TkUtils::ungrid($FrDn);
    # important to re-pack the frame here:
    $FrDn->pack(-expand=> 1, -fill=>'both', );

    #$FrDn->gridPropagate(1);
    
    #$r_glbl->{main_menu_widget}->update();

    $FrDn->gridColumnconfigure(0,-weight=>0); # make it stretchable
    $FrDn->gridColumnconfigure(1,-weight=>1); # make it non-stretchable
    $FrDn->gridRowconfigure   (0,-weight=>1); # make it stretchable


    #$FrDn->pack(-expand=> 1, -fill=>'both', );

    my $rowcol = 0;

    if (!exists $r_tbh->{current_row})
      { $r_tbh->{current_row}= 1; };
    
    my $FastNav = $FrDn->Frame(
                    #-height=>14,
                    -relief=>"raised",-background=>'green',
        )->grid(-row=>0, -column=>0,
                -sticky=>'nw'
               );

    my $ButFirst = $FastNav->Button
      (
        -text=>"First", -cursor=>"hand1",
        -padx=>2, -pady=>1,
        -command=>sub {
                cb_show_contentform_get ($r_glbl, $r_tbh, 'first');
          },
      )->grid(-row=>$rowcol, -column=>0, -sticky=>'ew' );

    $rowcol++;
    my $ButBack = $FastNav->Button
      (
        -text=>"Back", -width=>12, -cursor=>"hand1",
        -padx=>2, -pady=>1,
        -command=>sub {
                cb_show_contentform_get ($r_glbl, $r_tbh, -1);
            },
      )->grid(-row=>$rowcol, -column=>0, -sticky=>'ew');
    $rowcol++;
    my $ButNext = $FastNav->Button
      (
          -text=>"Next", -width=>12, -cursor=>"hand1",
          -padx=>2, -pady=>1,
          -command=>sub {
                  cb_show_contentform_get ($r_glbl, $r_tbh, 1);
          },
      )->grid(-row=>$rowcol, -column=>0, -sticky=>'ew');

    $rowcol++;
    my $ButLast = $FastNav->Button
      (
        -text=>"Last", -width=>12, -cursor=>"hand1",
        -padx=>2, -pady=>1,
        -command=>sub {
                cb_show_contentform_get ($r_glbl, $r_tbh, 'last');
          },
      )->grid(-row=>$rowcol, -column=>0, -sticky=>'ew');

    $rowcol++;

     
    # it's important that the Pane is not yet packed or gridded
    # since we can not yet calculate it's size
    my $Pane= $FrDn->Pane( 
                           -gridded=>'xy',
                           -sticky =>'nwe',
                         );

    # manually add scrollbars:

    my $xscroll = $FrDn->Scrollbar(-command => ['xview', $Pane],
                                -orient => 'horizontal',
                                )->grid(-row=>1, -column=>1, -sticky=> "ew");

    $Pane->configure(-xscrollcommand => ['set', $xscroll]);

    my $yscroll = $FrDn->Scrollbar(-command => ['yview', $Pane],
                                -orient => 'vertical',
                                )->grid(-row=>0, -column=>2, -sticky=> "ns");

    BrowseDB::TkUtils::bind_scroll_wheel($Pane);

    $Pane->configure(-yscrollcommand => ['set', $yscroll]);

    # now add a frame within the pane, we need this in order
    # to proceed with adding the entry fields without the
    # Pane-Widgets having been gridded
    
    my $Form= $Pane->Frame->pack(-side=>'top' ,-fill=>'both', -expand=>1);

    $r_tbh->{form_widget}->{contentframe} = $Form;
    $r_tbh->{form_widget}->{fastnavframe}->{back}  = $ButBack;
    $r_tbh->{form_widget}->{fastnavframe}->{next}  = $ButNext;
    $r_tbh->{form_widget}->{fastnavframe}->{first} = $ButFirst;
    $r_tbh->{form_widget}->{fastnavframe}->{last}  = $ButLast;

#    $FrDn->gridColumnconfigure(1, -weight => 1);
#    $FrDn->gridColumnconfigure(0, -weight => 0, -minsize => 128);
#    $FrDn->gridRowconfigure(0, -weight => 1);
    if (!defined($r_tbh->{form}->{label_length}) )
      { $r_tbh->{form}->{label_length} = 32; }
    if (!defined($r_tbh->{form}->{label_anchor}) )
      { $r_tbh->{form}->{label_anchor} = "e"; }

    #BrowseDB::TkUtils::SetBusy($r_glbl,1);
    # getting value

    my $row=0;
    my $lineno= $r_tbh->{current_row};
    foreach my $colname ( @{$r_tbh->{column_list}} )
      {
       my($LabelWidget,$EntryWidget)=
        cb_show_contentform_entrywidgets($r_glbl, $r_tbh, 
                                     row2pk($r_tbh, $lineno), 
                                     $colname);

       $r_tbh->{form_widget}->{content}->{$colname}=$EntryWidget;
       
       $LabelWidget->grid(-row=>$row, -column=>0, -sticky=>'w');
       $EntryWidget->grid(-row=>$row, -column=>1, -sticky=>'ew');

       $row++;
      };
    
    $Form->gridColumnconfigure   (0,-weight=>0); # make it stretchable
    $Form->gridColumnconfigure   (1,-weight=>1); # make it stretchable

    # now calculate the requested width:

    $Form->update;
    my ($height, $width) = ($Form->reqheight, $Form->reqwidth);


    $Pane->configure(-height => $height, -width => $width);

    $Pane->grid(-row=>0, -column=>1, -sticky=>'nsew');

    cb_show_contentform_get ($r_glbl, $r_tbh);


#@@@@@@@@@@@@@    cb_show_contentform_get ($r_glbl, $r_tbh, $lineno);
    #$MainText->configure(-state=>"disable");

    $FrDn->pack(-expand=> 1, -fill=>'both', );
#$FrDn->update;

    $Pane->bind('<Destroy>', [\&cb_close_window, $r_glbl, $r_tbh] );

    $r_glbl->{main_menu_widget}->update();
    #BrowseDB::TkUtils::SetBusy($r_glbl,0);
}

sub cb_show_contentform_get
  {
    my ($r_glbl, $r_tbh, $incr) = @_;
    my $back = 'disabled';
    my $next = 'disabled';
    my $new = 'normal';
    my $selection = 'disabled';

    my $lineno;
    
    if    (!defined $incr)
      { $lineno=1; }
    elsif ($incr eq 'first')
      { $lineno=1; }
    elsif ($incr eq 'last')
      { $lineno= $r_tbh->{row_no}; }
    else
      { $lineno= $r_tbh->{current_row} + $incr;
        $lineno=1 if ($lineno<1);
        $lineno=$r_tbh->{row_no} if ($lineno>$r_tbh->{row_no});
      };
    
    $r_tbh->{current_row}= $lineno;
    
    if ($lineno > 1)
      {
        $back = 'normal';
      };
    if ($lineno < $r_tbh->{row_no})
      {
        $next = 'normal';
      };
    if (exists $r_tbh->{form_widget}->{fastnavframe})
      {
        $r_tbh->{form_widget}->{fastnavframe}->{back}->
            configure(-state=>$back);
        $r_tbh->{form_widget}->{fastnavframe}->{first}->
            configure(-state=>$back);
        $r_tbh->{form_widget}->{fastnavframe}->{next}->
            configure(-state=>$next);
        $r_tbh->{form_widget}->{fastnavframe}->{last}->
            configure(-state=>$next);
            
        foreach my $colname ( @{$r_tbh->{column_list}} )
        {
            $r_tbh->{form_values}->{$colname} = 
                 put_get_val_direct($r_tbh,0,row2pk($r_tbh, $lineno),$colname);
        };
      }
  }

sub cb_show_contentform_entrywidgets
  {
    # build form for given
    # $r_glbl    : globalhash for config
    # $r_tbh     : tablehash
    # $pkey    : primary key of the row
    # $colname : columnname
    my ($r_glbl, $r_tbh, $pkey, $colname) = @_;
  
    my $FormWidget= $r_tbh->{form_widget}->{contentframe};

#return($FormWidget->Label(-text=>"first"),
#       $FormWidget->Label(-text=>"second"));

    #return if (!defined $FormWidget);
    
    # read data from the table:
    $r_tbh->{form_values}->{$colname} = undef;
               #put_get_val_direct($r_tbh,0,$pkey,$colname);

#warn "val ( $colname) = " . $r_tbh->{form_values}->{$colname};

    my $ColName = $colname;


    my $nullprop= $r_tbh->{dbitable}->get_column_property($colname, "null");
    if ((defined $nullprop) && (uc($nullprop) ne 'Y'))
      {
        $ColName = "*".$colname;
      };

    my $LabelWidget= $FormWidget->Label(
                            -text=>"$ColName : ",
                            -relief=>"groove",
                            -width=>$r_tbh->{form}->{label_length},
                            -anchor=>$r_tbh->{form}->{label_anchor},
                                      );

#return($LabelWidget, $FormWidget->Label(-text=>"second"));

    my $state= ($r_tbh->{table_type} eq 'table') ?
                'normal' : 'readonly';

    my $ColWidget;
    # setting default for new
    my $coltype = $r_tbh->{dbitable}->get_column_type($colname);
    $coltype="unknown" if (!defined $coltype);

    if ($coltype eq "number")
      { $ColWidget = $FormWidget->NumEntry(
                -textvariable=>\$r_tbh->{form_values}->{$colname},
                -cursor=>"hand1",
                -state=>$state
          );
      }
    elsif($coltype eq "date")
      {
        $ColWidget = $FormWidget->DateEntry
          (
            -daynames=>$r_glbl->{formats}->{date}->{weekdays},
            -weekstart=>$r_glbl->{formats}->{date}->{firstday},
            -textvariable=>\$r_tbh->{form_values}->{$colname},
            -state=>$state
          );
      }
    else
      { $ColWidget = $FormWidget->Entry(
            -textvariable=>\$r_tbh->{form_values}->{$colname},
            -state=>$state
          );
      }

#    $ColWidget->configure(-width=>-1);
#
    my $colwidth= $r_tbh->{dbitable}->get_column_property($colname,"length");
    if (!defined $colwidth)
      { $colwidth= 0; }
    else
      { $colwidth+= 2; };

    $ColWidget->configure(
            -width=> $colwidth,
           theme_parameters($r_glbl,'text','-foreground')
          );

    return($LabelWidget,$ColWidget);
  }

sub object_info
  {
    my($r_glbl, $r_tbh)= @_;

    my $dbh= $r_glbl->{dbh};
    my $user= $r_glbl->{user};
    my $table_type= $r_tbh->{table_type};
    my $table_name= $r_tbh->{table_name};

    my $text= "object-type: ";
    if    ($table_type eq 'table')
      { $text.= "table"; }
    elsif ($table_type eq 'view')
      { $text.= "view"; }
    elsif ($table_type eq 'sql')
      { $text.= "arbitrary SQL statement"; }
    elsif ($table_type eq 'table_or_view')
      { $text.= "table or view"; }
    else
      { warn "unknown type: $r_tbh->{table_type}"; };
      
    $text.= "\n\ncolumns:\n";  

    if ($table_type ne 'sql')
      { my $all_col_prop= $r_tbh->{column_properties};
      
        $text.= sprintf("%-20s %-15s %6s %9s %8s %8s\n",
                        'name','type','length',
                        'precision','nullable','key-type');
        
        foreach my $colname ( @ { $r_tbh->{column_list} } )
          { my $col_prop= $all_col_prop->{$colname};
          
            my $type  = $col_prop->{type};
            my $length= $col_prop->{length};
            my $prec  = $col_prop->{precision};
            my $null  = $col_prop->{null};
            $type="" if (!defined $type);
            $null="" if (!defined $null);
            if (defined $length)
              { $length= sprintf("%3d",$length); }
            else
              { $length=""; };
            if (defined $prec)
              { $prec  = sprintf("%3d",$prec); }
            else
              { $prec=""; };

            my $keytype="";
            
            if (exists $r_tbh->{pks_h}->{$colname})
              { $keytype= "primary"; }; 
                    
            my $fkh= $r_tbh->{foreign_key_hash}->{$colname};
            if (defined $fkh)
              { # note: the table-name in the foreign_key_hash is
                # no public synonym but the name of the real table
                # we cannot call dbdrv::real_name here since
                # is only knows all synonyms and all user tables, but
                # not all tables that exist
                # the foreign_key_hash contains:
                # table-name,column,table-owner

                  $keytype = "foreign, " .
                      (dbdrv::real_name($dbh,$user,$fkh->[0]))[0];
              };
              
            $text.= sprintf("%-20s %-15s %6s %9s %8s %s\n",
                            $colname, $type, $length, 
                            $prec, $null, $keytype);
          }; 
        my @dependents=
                dbdrv::object_dependencies($dbh,$table_name,$r_glbl->{user});
        if (@dependents)
          {     $text.="\n\ndependents:\n";   
            foreach my $r_s (@dependents)
              { $text .= sprintf("%s.%s (%s)\n",@$r_s);
              };
          };
    
        my @referenced=
                   dbdrv::object_references($dbh,$table_name,$r_glbl->{user});
        if (@referenced)
          { $text .= "\n\nreferenced objects:\n";
            foreach my $r_s (@referenced)
            { $text .= sprintf("%s.%s (%s)\n",@$r_s);
            };
          };
      };
      
    if ($table_type eq 'view')
      {
        my $sql= dbdrv::read_viewtext($dbh,$table_name,$r_glbl->{user});
        $text.= "\nSQL command of the view:\n" . $sql. "\n";
      };
    if ($table_type eq 'table')
        {
          my @constraints_triggers=
                   dbdrv::object_addicts($dbh,$table_name,$r_glbl->{user});
          if (@constraints_triggers)
            { $text .= "\nconstraints/triggers:\n";
              foreach my $r_s (@constraints_triggers)
                { # caution: name,owner,type here!
                  $text .= sprintf("%s.%s (%s)",$r_s->[1],$r_s->[0],$r_s->[2]);
                  if ($r_s->[2] eq 'C')
                    { $text .= "\n  {\n";
                      $text .= "    " . dbdrv::read_checktext($dbh,$r_s->[0], $r_s->[1]);
                      $text .= "\n  }\n";
                    }
                };
            };

        };
          
    $text.= "\nSQL command: " . $r_tbh->{dbitable}->{_fetch_cmd};
    BrowseDB::TkUtils::MakeTextWidget($r_glbl,$table_name,\$text)
  }  

   


sub cb_show_objectinfo
  {
    my($r_glbl, $r_tbh)= @_;
    # --------------------- object widget

    my $name= $r_tbh->{table_name};
    my $dbh= $r_glbl->{dbh};
    my $user= $r_glbl->{user};


    my $content = $r_tbh->{'cache'}->{'info'};
    if (! defined($content))
      {
        BrowseDB::TkUtils::SetBusy($r_glbl,1);

#        BrowseDB::TkUtils::SetBusy($r_glbl,1);

        my $buffer;

        my $str;
        if    ($r_tbh->{table_type} eq 'table')
        { $str= "object-type: table\n"; }
        elsif ($r_tbh->{table_type} eq 'view')
        { $str= "object-type: view\n"; }
        elsif ($r_tbh->{table_type} eq 'sql')
        { $str= "object-type: arbitrary SQL statement\n"; }
        else
        { $str= "object-type: unknown : $r_tbh->{table_type}\n"; }

        $content = $str;

        if ($r_tbh->{table_type} ne 'sql')
        {
          foreach my $colname ( @ { $r_tbh->{'column_list'} } )
            {
              if ($r_tbh->{col_map_flags}->{$colname} eq 'Y')
                {
                    $content .= "\n\t*$colname";
                }
              else
                {
                    $content .= "\n\t$colname";
                }
              if (exists($r_tbh->{column_properties}->{$colname}))
                {
                    $content .= " ".$r_tbh->{column_properties}->{$colname}->{type};
                    if (defined($r_tbh->{column_properties}->{$colname}->{length}) &&
                        $r_tbh->{column_properties}->{$colname}->{length} > 0)
                      {
                        $content .= "(".$r_tbh->{column_properties}->{$colname}->{length};
                        if (defined($r_tbh->{column_properties}->{$colname}->{precision}))
                          {
                            $content .= " ,".$r_tbh->{column_properties}->{$colname}->{precision};
                          }
                          $content .= ")";
                      }
                    if ($r_tbh->{column_properties}->{$colname}->{null} eq 'Y')
                      {
                        $content .= "\n\t\tnot null";
                      };
                    if (defined ($r_tbh->{column_properties}->{$colname}->{default}))
                      {
                        $content .= "\n\t\tdefault (" .
                            $r_tbh->{column_properties}->{$colname}->{default} .
                            ")";
                      };
                }
              if (exists($r_tbh->{pks_h}->{$colname}))
                {
                    $content .= "\n\t\tprimary key";
                };
              my $fkh= $r_tbh->{foreign_key_hash}->{$colname};
              if (defined $fkh)
                { # note: the table-name in the foreign_key_hash is
                  # no public synonym but the name of the real table
                  # we cannot call dbdrv::real_name here since
                  # is only knows all synonyms and all user tables, but
                  # not all tables that exist
                  # the foreign_key_hash contains:
                  # table-name,column,table-owner

                    $content .= "\n\t\tforeign key ( " .
                             (dbdrv::real_name($dbh,$user,$fkh->[0]))[0] .
                        " )";
                };
            };

          my @dependents=
                  dbdrv::object_dependencies($dbh,$name,$r_glbl->{user});
          if (@dependents)
            { $content .= "\n\ndependents:";
              foreach my $r_s (@dependents)
              {
                 $content .= "\n\t".sprintf("%s.%s (%s)\n",@$r_s);
              };
            };

          my @referenced=
                   dbdrv::object_references($dbh,$name,$r_glbl->{user});
          if (@referenced)
            { $content .= "\n\nreferenced objects:\n\t";
              foreach my $r_s (@referenced)
              { my $st= sprintf("%s.%s (%s)\n\t",@$r_s);
                $content .= $st;
              };
              $content .= "\n";
            };

        };

        if ($r_tbh->{table_type} eq 'view')
        {
          my $sql= dbdrv::read_viewtext($dbh,$name,$r_glbl->{user});
          $str= "\nSQL command of the view:\n" . $sql. "\n";
          $content .= $str;
        }
        elsif ($r_tbh->{table_type} eq 'table')
        {
          my @constraints_triggers=
                   dbdrv::object_addicts($dbh,$name,$r_glbl->{user});
          if (@constraints_triggers)
            { $content .= "\nconstraints/triggers:\n";
              foreach my $r_s (@constraints_triggers)
                { # caution: name,owner,type here!
                  $content .= "\n\t".sprintf("%s.%s(%s)",$r_s->[1],$r_s->[0],$r_s->[2]);
                  if ($r_s->[2] eq 'C')
                    { $content .= "\n\t\t{\n\t\t\t";
                      $content .= dbdrv::read_checktext($dbh,
                              $r_s->[0], $r_s->[1]);
                      $content .= "\n\t\t}\n";
                    }
                };
            };

        };

      my $dbitable= $r_tbh->{dbitable};
      $str= "\n\nSQL command: " . $r_tbh->{dbitable}->{_fetch_cmd};

      $content .=  $str;

      $r_tbh->{'cache'}->{'info'} = $content;
#      BrowseDB::TkUtils::SetBusy($r_glbl,1);

        BrowseDB::TkUtils::SetBusy($r_glbl,0);
      };

    my $FrDn = $r_tbh->{'frame_down'};
#    $FrDn->gridForget($FrDn->gridSlaves(-row=>1));
#    $FrDn->gridForget($FrDn->gridSlaves(-column=>1));
    $FrDn->gridForget($FrDn->gridSlaves());
    $FrDn->gridRowconfigure   (0,-weight=>1); # make it stretchable
    $FrDn->gridColumnconfigure(0,-weight=>1); # make it stretchable

    # repacking FrDown is important in order to get a
    # sensible window-size
    $FrDn->pack(-expand=> 1, -fill=>'both', );

    my $Text= $FrDn->Scrolled('Text',
                -wrap=>'word',
                -scrollbars=>"osoe",
        )->grid(-row=>0, -column=>0, -sticky=> "nsew");

    $Text->delete('1.0', 'end');
    $Text->insert('end', $content);
    #$FrDn->pack(-side=>'top', -expand=>1, -fill=>'both');
  }

sub cb_show_dependencies
  {
    my($r_glbl, $r_tbh)= @_;
    # --------------------- object widget

  }

sub cb_close_window
# global variables used: NONE
 { my($parent_widget, $r_glbl, $r_tbh)= @_;

    # $r_tbh->{top_widget}->destroy();

    # remove the table-hash from the all_tables variable
    # caution: a global variable is used !

    my $r_all_tables= $r_glbl->{all_tables};

    tkdie($r_glbl,"assertion in line " . __LINE__)
     if (!defined $r_all_tables); #assertion

    my $table_name= $r_tbh->{table_name};
    conn_delete_table($r_glbl, $table_name);

    delete $r_all_tables->{ $r_tbh->{table_name} };
    tk_update_window_menu($r_glbl);
# warn "Table $table_name successfully deleted !\n";
 }

sub table_hash_init_columns
 { my($r_tbh)= @_;

   # get (or set-up) column_list, column_hash, column_no:

   $r_tbh->{column_list} = [ $r_tbh->{dbitable}->column_list() ];
   $r_tbh->{column_hash} = { $r_tbh->{dbitable}->column_hash() };
   $r_tbh->{column_properties} = { $r_tbh->{dbitable}->get_column_property() };
   $r_tbh->{column_no}   = $#{$r_tbh->{column_list}} + 1;

   $r_tbh->{column_width}= [ $r_tbh->{dbitable}->max_column_widths(5,25) ];

   if (!exists $r_tbh->{displayed_cols})
     { # when displayed_cols is not defined, display
       # all columns as a default
       $r_tbh->{displayed_cols}=
                   { map{ $_=>1 } @{$r_tbh->{column_list}} };
     };

   calc_visible_columns($r_tbh);
  }

sub table_window_tag_columns
  { my($r_tbh)= @_;
    my $Table_Widget= $r_tbh->{table_widget};

    my $r_col_hash= $r_tbh->{vis_column_hash};

    # remove all cell attributes
    for(my $i=0; $i< $r_tbh->{vis_column_no}; $i++)
      { $Table_Widget->tagCol('', $i); };

    # mark the primary key, it may not be edited
    if (!$r_tbh->{no_pk_cols})
      { foreach my $colname (@{$r_tbh->{pks}})
          { next if (!exists $r_col_hash->{$colname});
            $Table_Widget->tagCol('pk_cell', colname2col($r_tbh,$colname) );

          };
      };

    foreach my $fk_col (keys % {$r_tbh->{foreign_key_hash}})
      { next if (!exists $r_col_hash->{$fk_col});
        $Table_Widget->tagCol('fk_cell', colname2col($r_tbh,$fk_col) );
      };

    # mark mapped columns:
    table_window_title_tags($r_tbh);
  }

sub table_window_title_tags
  { my($r_tbh,$col)= @_;
    my $Table_Widget= $r_tbh->{table_widget};

    my $r_col_hash= $r_tbh->{vis_column_hash};

    my $r_cmf= $r_tbh->{col_map_flags};
    my $r_cm = $r_tbh->{col_maps};
    my @cols;

    if (defined $col)
      { if (!exists $r_col_hash->{$col}) # col is invisible
          { $col= undef; } # retag all titles
        else
          { @cols= ($col); }
      };

    if (!defined $col)
      { @cols= keys %$r_col_hash; }; # only visible columns

    foreach my $colname (@cols)
      { my $col= colname2col($r_tbh,$colname);

        if ($r_cmf->{$colname} eq 'N')
          { if (!exists $r_cm->{$colname})
              { $Table_Widget->tagCell('', "0,$col"); }
            else
              { $Table_Widget->tagCell('mapped_col_off', "0,$col");
              }
          }
        else
          { $Table_Widget->tagCell('mapped_col_on', "0,$col"); }

      };
  }

sub table_window_set_column_width
  { my($r_tbh)= @_;

    my $Table_Widget= $r_tbh->{table_widget};

    my $r_width= $r_tbh->{vis_column_width};

    for(my $i=0; $i<= $#$r_width; $i++)
      {
        $Table_Widget->colWidth($i, $r_width->[$i] + 2);
        # 2 characters more than the real maximum width
      };
  }

sub resize_table
# must be called, when the number of lines in the table
# has changed
# updates the table-hash and the table-widget
  { my($r_tbh)= @_;

    $r_tbh->{pk_list}= get_pk_list($r_tbh);
    $r_tbh->{pk_hash}= calc_pk2index($r_tbh);
    $r_tbh->{row_no} = $#{$r_tbh->{pk_list}} + 1;

    $r_tbh->{table_widget}->configure(-rows => $r_tbh->{row_no} + 1);
  }

#=======================================================
# utilities for table windows:
#=======================================================

# add scroll relation:
#_______________________________________________________

sub tk_add_relation_dialog
  { my($r_glbl,$r_tbh)= @_;
    my $myname= $r_tbh->{table_name};

    my %relation_hash= ( Top=>undef,
                         ocol_browseentry=>undef,
                         mycol=>undef,
                         otab=>undef,
                         ocol=>undef );

    my $Top= BrowseDB::TkUtils::MakeToplevel($r_glbl,
                         title=>"Add relation in $r_tbh->{table_name}",
                         theme_parameters($r_glbl,'main','-background')
                                            );

    $relation_hash{Top}= $Top;

    my @open_tables= grep {$_ ne  $myname}
                           (sort keys %{$r_glbl->{all_tables}});

    $Top->Label(-text => 'this table:'
               )->grid(-row=>0, -column=>0, -sticky=> "w");

    $Top->Label(-text => $myname
               )->grid(-row=>0, -column=>1, -sticky=> "w");

    $Top->Label(-text => 'this column:'
               )->grid(-row=>1, -column=>0, -sticky=> "w");

    $Top->Label(-text => 'other table:'
               )->grid(-row=>2, -column=>0, -sticky=> "w");

    $Top->Label(-text => 'other column:'
               )->grid(-row=>3, -column=>0, -sticky=> "w");

    my %std_options= (-state=> 'readonly');
    if ($Tk::VERSION >= 800.025) # in older Tk versions unknown
      { $std_options{-autolimitheight}=1; };

    $Top->BrowseEntry( %std_options,
                       -choices=> $r_tbh->{column_list},
                       -variable=> \$relation_hash{mycol}
                     )->grid(-row=>1,
                             -column=>1,
                             -sticky=> "w");

    $Top->BrowseEntry( %std_options,
                       -choices=> \@open_tables,
                       -browsecmd=> [\&cb_add_relation,
                                     $r_glbl,
                                     $r_tbh],
                       -variable=> \$relation_hash{otab}
                     )->grid(-row=>2,
                             -column=>1,
                             -sticky=> "w");

    my $Lb_o_cols = $Top->BrowseEntry( %std_options,
                                       -variable=> \$relation_hash{ocol}
                                     )->grid(-row=>3,
                                             -column=>1,
                                             -sticky=> "w");

    $relation_hash{ocol_browseentry}= $Lb_o_cols;


    $Top->Button(-text => 'select',
                  %std_button_options,
                 -command => [\&tk_add_relation_dialog2, $r_glbl, $r_tbh],
                )->grid(-row=>4, -column=>0, -columnspan=>1,
                        -sticky=> "w");

    $r_tbh->{relation_hash}= \%relation_hash;

    $Top->bind('<Destroy>', sub { delete $r_tbh->{relation_hash} } );

    # let the window appear near the mouse-cursor:
    $Top->Popup(-popover    => 'cursor');
  }

sub cb_add_relation
  { my($r_glbl,$r_tbh,$widget,$selected_text)= @_;

    my $r_relation_hash= $r_tbh->{relation_hash};

    my $r_o_tbh= $r_glbl->{all_tables}->{$selected_text};

    die "not a valid table!" if (!defined $r_o_tbh); # assertion

    $r_relation_hash->{ocol_browseentry}->configure(
                         -choices=> $r_o_tbh->{column_list}
                                                   );
  }

sub tk_add_relation_dialog2
  { my($r_glbl,$r_tbh)= @_;

    my $r_relation_hash= $r_tbh->{relation_hash};
    my $Top= $r_relation_hash->{Top};

    my $my_tab= $r_tbh->{table_name};

    my $my_col= $r_relation_hash->{mycol};
    my $o_tab = $r_relation_hash->{otab};
    my $o_col = $r_relation_hash->{ocol};

    if (!defined $my_col)
      { BrowseDB::TkUtils::err_dialog($Top, "local column not selected");
        return;
      };

    if (!defined$o_tab)
      { BrowseDB::TkUtils::err_dialog($Top, "other table not selected");
        return;
      };

    if (!defined$o_col)
      { BrowseDB::TkUtils::err_dialog($Top, "other column not selected");
        return;
      };

    # warn "selected:$my_tab $my_col $o_tab $o_col";

    $r_relation_hash->{Top}->destroy();
    $r_glbl->{main_menu_widget}->update; # force destroy to be executed now
    delete $r_tbh->{relation_hash};

    conn_add($r_glbl,
             $r_tbh->{table_name},$my_col,
             $o_tab,$o_col);

    tk_mark_manual_foreign_key_col($r_tbh, $my_col);
    #table_window_tag_columns($r_tbh);

# @@@@@@@@@@@@@@@@@@@@
  }

sub tk_mark_manual_foreign_key_col
# mark foreign key columns with a special color, only for
# the 'table' display_mode
  { my($r_tbh,$col_name)= @_;

    return if ($r_tbh->{display_mode} ne 'table');
    
    my $Table_Widget= $r_tbh->{table_widget};

    # get column-indices of "green" columns
    my @tagged_cols= $Table_Widget->tagCol('fk_cell');

    my $col= colname2col($r_tbh,$col_name);

    foreach my $i (@tagged_cols)
      { if ($i==$col)
          { # col is already tagged
            return;
          };
      };
    $Table_Widget->tagCol('m_fk_cell', $col );
  }

# referenced-tables dialog:
#_______________________________________________________

sub tk_references_dialog
  { my($r_glbl,$r_tbh)= @_;

    my $parent_widget= $r_tbh->{table_widget};

    my $fkh= $r_tbh->{foreign_key_hash};
    # col_name => [foreign_table,foreign_column]

    if (!defined $fkh) # no foreign keys defined
      { BrowseDB::TkUtils::err_dialog($parent_widget,
                      "there are no foreign keys in this table");
        return;
      };

    if (!keys %$fkh) # no foreign keys defined
      { BrowseDB::TkUtils::err_dialog($parent_widget,
                      "there are no foreign keys in this table");
        return;
      };


    my $Top= BrowseDB::TkUtils::MakeToplevel($r_glbl,
                         title=>"Foreign keys in $r_tbh->{table_name}",
                         theme_parameters($r_glbl,'main','-background')
                                            );


    my $FrTop = $Top->Frame(-borderwidth=>2,-relief=>'raised',
                            theme_parameters($r_glbl,'main','-background')
                           )->pack(-side=>'top' ,-fill=>'both',
                                  -expand=>'y');

    my $maxcolsz=0;
    my @cols= (sort keys %$fkh);
    foreach my $col (@cols)
      { $maxcolsz= length($col) if (length($col)>$maxcolsz); };

    my @lines;

    foreach my $col (@cols)
      { my $fk_table= dbdrv::canonify_name($r_glbl->{dbh},$r_glbl->{user},
                                           $fkh->{$col}->[0],
                                           $fkh->{$col}->[2]);
        push @lines,
             sprintf("%-" . $maxcolsz . "s -> %s",$col,$fk_table);

#        push @lines,
#             sprintf("%-" . $maxcolsz . "s -> %s",$col,
#                     $fkh->{$col}->[2] . '.' . $fkh->{$col}->[0]
#                    )
      };

    my $listbox= $FrTop->Listbox(-selectmode => 'single',
                                 -width=>0,
                                 -height=> $#lines+1);
    foreach my $l (@lines)
      { $listbox->insert('end', $l); };

    $listbox->pack(-fill=>'both',-expand=>'y');

    $Top->bind('<Return>',
                   sub { tk_references_dialog_finish($r_glbl, $r_tbh); });
    $listbox->bind('<Double-1>',
                   sub { tk_references_dialog_finish($r_glbl, $r_tbh); });

    $Top->bind('<Destroy>', sub {
                                delete $r_glbl->{foreign_key_dialog_widget},
                                delete $r_glbl->{foreign_key_dialog_listbox},
                                delete $r_glbl->{foreign_key_cols}
                                });

    $FrTop->Label(-text => 'double-click to open table'
                 )->pack(-side=>'left' ,-fill=>'y');

    $r_glbl->{foreign_key_dialog_widget} = $Top;
    $r_glbl->{foreign_key_dialog_listbox}= $listbox;
    $r_glbl->{foreign_key_cols} = \@cols;

    # let the window appear near the mouse-cursor:
    $Top->Popup(-popover    => 'cursor');
  }

sub tk_references_dialog_finish
  { my($r_glbl,$r_tbh)= @_;

    my $Top    = $r_glbl->{foreign_key_dialog_widget};
    my $listbox= $r_glbl->{foreign_key_dialog_listbox};
    my $r_cols = $r_glbl->{foreign_key_cols};

    my @selection= $listbox->curselection();

    if (!@selection)
      { BrowseDB::TkUtils::err_dialog($Top, "no table selected");
        return;
      };

   my $colname= $r_cols->[ $selection[0] ];

   my($fk_table,$fk_col,$fk_owner)= @{$r_tbh->{foreign_key_hash}->{$colname}};

   $Top->destroy;  # @@@@

   # new: take the table-owner into account:
   $fk_table= dbdrv::canonify_name($r_glbl->{dbh},$r_glbl->{user},
                                   $fk_table,$fk_owner);

   my $r_all_tables= $r_glbl->{all_tables};
   tkdie($r_glbl,"assertion in line " . __LINE__)
     if (!defined $r_all_tables); # assertion, shouldn't happen

   my $r_tbh_fk= $r_all_tables->{$fk_table};
   if (!defined $r_tbh_fk)
     { # 'resident_there' must be given as parameter to
       # make_table_hash_and_window since make_table_window looks for
       # this part of the table-hash and creates the "select" button if
       # that member of the hash is found
       $r_tbh_fk= make_table_hash_and_window($r_glbl,
                table_name=> $fk_table,
                table_type=> 'table',
                resident_there=>1);

        conn_add($r_glbl,$r_tbh->{table_name},$colname,
                 $fk_table,$fk_col);

     };
   my $Table= $r_tbh->{table_widget};

   my($row,$col)= split(",",$Table->index('active'));
   my($pk)= row2pk($r_tbh,$row);
   # using Table->get() would be unnecessary slow
   # 0: do not use column-map
   my $cell_value= put_get_val_direct($r_tbh,0,$pk,$colname);

   # 0: do not use column-map
   tk_activate_cell($r_tbh_fk,0, $fk_col, $cell_value);

   delete $r_glbl->{foreign_key_dialog_widget};
   delete $r_glbl->{foreign_key_dialog_listbox};
   delete $r_glbl->{foreign_key_cols};

  }

# dependent-tables dialog:
#_______________________________________________________

sub tk_dependency_dialog
  { my($r_glbl,$r_tbh)= @_;

    my $parent_widget= $r_tbh->{table_widget};

    BrowseDB::TkUtils::SetBusy($r_glbl,1);
    my $r_resident_keys= $r_tbh->{dbitable}->resident_keys();
    BrowseDB::TkUtils::SetBusy($r_glbl,0);
    if (!defined $r_resident_keys)
      { BrowseDB::TkUtils::err_dialog($parent_widget,
                      "no other table depends on this one");
        return;
      };

    my %resident_tables;
    # res_table_name => [  [res_col1, col1],
    #                      [res_col2, col2],
    #                          ...
    #                   ]

    foreach my $col_name (keys %$r_resident_keys)
      { my $r_list= $r_resident_keys->{$col_name};

        foreach my $r_sublist (@$r_list)
          {
            push @{ $resident_tables{$r_sublist->[0]} },
                 [ $r_sublist->[1] , $col_name ];

          };
      };

    my @resident_table_list= sort keys %resident_tables;

    BrowseDB::TkUtils::ObjectDialog($r_glbl,$r_tbh,
                     tag=> "dependend_tables_dialog",
                     title=> "dependents from $r_tbh->{table_name}",
                     items=> \@resident_table_list,
                     text => 'double-click to open',
                     callback=> [\&tk_dependency_dialog_finish,
                                 \%resident_tables]
                    );

  }

sub tk_dependency_dialog_finish
  { my($r_glbl,$r_tbh,$res_table,$r_resident_tables)= @_;


    my $r_all_tables= $r_glbl->{all_tables};
    tkdie($r_glbl,"assertion in line " . __LINE__)
       if (!defined $r_all_tables); # assertion, shouldn't happen

    my $r_tbh_res= $r_all_tables->{$res_table};
    if (!defined $r_tbh_res)
      { # create a window fore the resident-table:
        $r_tbh_res= make_table_hash_and_window($r_glbl,
                                               table_name=>$res_table,
                                               table_type=>'table');

        # get the name of the current table:
        my $my_table= $r_tbh->{table_name};

        # get the list of relations between the current (the foreign) table
        # and the resident table:
        my $r_col_relations= $r_resident_tables->{$res_table};
        # [res_col1, col1], [res_col2, col2], ...

#warn "new table: col_relations: $r_col_relations\n";
#warn "array content: " , Dumper($r_col_relations) , "\n";

        foreach my $r_col_relation (@$r_col_relations)
          { # save information on connection between the
            # foreign table and the resident table
            my($res_col,$fk_col)= @$r_col_relation;

            conn_add($r_glbl,$res_table,$res_col,$my_table,$fk_col);
          };
      }

  }

# dependent-views dialog:
#_______________________________________________________

sub tk_dependend_views_dialog
  { my($r_glbl,$r_tbh)= @_;

    my $parent_widget= $r_tbh->{table_widget};

    BrowseDB::TkUtils::SetBusy($r_glbl,1);
    my $dbh= $r_glbl->{dbh};

    my @dependents=
          dbdrv::object_dependencies($dbh,$r_tbh->{table_name},$r_glbl->{user});

    BrowseDB::TkUtils::SetBusy($r_glbl,0);

    # filter-out views
    if (@dependents)
      { @dependents= grep { $_->[2] eq 'VIEW' } @dependents; };

    if (!@dependents)
      { BrowseDB::TkUtils::err_dialog($parent_widget,
                      "no view depends on this object");
        return;
      };

    my @objects= map{ dbdrv::canonify_name($r_glbl->{dbh},$r_glbl->{user},
                                           $_->[1], $_->[0]) } @dependents;
    @objects= sort @objects;

    BrowseDB::TkUtils::ObjectDialog($r_glbl,$r_tbh,
                     tag=> "dependend_views_dialog",
                     title=> "dependent views of $r_tbh->{table_name}",
                     items=> \@objects,
                     text => 'double-click to open',
                     callback=> [\&tk_dependend_views_dialog_finish]
                    );

  }

sub tk_dependend_views_dialog_finish
# note: $widget is not really needed, it's just here
# since  this function can be called from via <bind>
  { my($r_glbl,$r_tbh,$obj)= @_;

    make_table_hash_and_window($r_glbl,
                               table_name=>$obj,
                               table_type=>'view');
  }

# (by a view-) referenced objects dialog:
#_______________________________________________________

sub tk_view_dependency_dialog
  { my($r_glbl,$r_tbh)= @_;

    my $parent_widget= $r_tbh->{table_widget};

    BrowseDB::TkUtils::SetBusy($r_glbl,1);
    my $dbh= $r_glbl->{dbh};

    my @referenced=
          dbdrv::object_references($dbh,$r_tbh->{table_name},$r_glbl->{user});

    BrowseDB::TkUtils::SetBusy($r_glbl,0);

    if (!@referenced)
      { BrowseDB::TkUtils::err_dialog($parent_widget,
                      "this view seems to depend on no other object?");
        return;
      };

    my @objects= map{ dbdrv::canonify_name($r_glbl->{dbh},$r_glbl->{user},
                                           $_->[1], $_->[0]) } @referenced;

    my %types;
    for(my $i=0; $i<= $#objects; $i++)
      { my $t= $referenced[$i]->[2];

        $types{ $objects[$i] } = ($t eq 'TABLE') ? 'table' : 'view' ;
      };

    @objects= sort @objects;

    BrowseDB::TkUtils::ObjectDialog($r_glbl,$r_tbh,
                     tag=> "view_dependendcy_dialog",
                     title=> "by $r_tbh->{table_name} referenced objects",
                     items=> \@objects,
                     text => 'double-click to open',
                     callback=> [\&tk_view_dependency_dialog_finish,
                                 \%types]
                    );
  }

sub tk_view_dependency_dialog_finish
# note: $widget is not really needed, it's just here
# since  this function can be called from via <bind>
  { my($r_glbl,$r_tbh,$obj,$r_types)= @_;

    make_table_hash_and_window($r_glbl,
                               table_name=>$obj,
                               table_type=>$r_types->{$obj});
  }

# find-in-column dialog:
#_______________________________________________________

sub tk_find_line
# note: $widget is not really needed, it's just here
# since  this function can be called from via <bind>
# if $given_colname is undefined, take it from the active cell
  { my($widget, $r_glbl, $r_tbh, $given_colname)= @_;

    my $TableWidget= $r_tbh->{table_widget};

    my %col_search_data;

    $r_tbh->{col_search_data}= \%col_search_data;

    # get row-column of the active cell in the current table
    my($row,$col)= split(",",$TableWidget->index('active'));
    my($pk,$colname)= rowcol2pkcolname($r_tbh,$row,$col);

    if (defined $given_colname)
      { $colname= $given_colname; };

    $col_search_data{colname}= $colname;
#    my $fromOpt = 'current';

    my $Top= BrowseDB::TkUtils::MakeToplevel($r_glbl,
                         parent_widget=> $TableWidget,
                         title=>"$r_tbh->{table_name}",
                         theme_parameters($r_glbl,'main','-background')
                        );


    $Top->Label(-text => "find in column $colname:"
        )->pack(-side=>'top' ,
                -fill=>'x',
                -expand=>'y');

    my $FrTop = $Top->Frame( -borderwidth=>2,
                             theme_parameters($r_glbl,'main','-background')
                           )->pack(-side=>'top' ,
                                   -fill=>'x',
                                   -expand=>'y');

#    my $rbfrom1 = $FrTop->Radiobutton(-variable => \$fromOpt,
#                                     -value => 'current',
#                                     -text => 'from here',
#        )->grid(-row=>0, -column=>0,  -sticky=> "w");
#    my $rbfrom2 = $FrTop->Radiobutton(-variable => \$fromOpt,
#                  -value => 'top',
#                  -text => 'from top'
#        )->grid(-row=>1, -column=>0,  -sticky=> "w");


    $col_search_data{direction}= "down";

    $FrTop->Radiobutton( -variable => \$col_search_data{direction},
                         -value => 'down',
                         -text => 'downwards',
                       )->grid(-row=>0, -column=>1,  -sticky=> "w");
    $FrTop->Radiobutton( -variable =>\$col_search_data{direction},
                         -value => 'up',
                         -text => 'upwards',
                       )->grid(-row=>1, -column=>1,  -sticky=> "w");


    $col_search_data{exact}= 1;

    $FrTop->Radiobutton( -variable => \$col_search_data{exact},
                         -value => 1,
                         -text => 'literal',
                       )->grid(-row=>0, -column=>2,  -sticky=> "w");
    $FrTop->Radiobutton( -variable => \$col_search_data{exact},
                         -value => 0,
                         -text => 'regexp match',
                       )->grid(-row=>1, -column=>2,  -sticky=> "w");

    $col_search_data{case_insensitive}= 0;

    $FrTop->Radiobutton( -variable => \$col_search_data{case_insensitive},
                         -value => 0,
                         -text => 'case sensitive',
                       )->grid(-row=>0, -column=>3,  -sticky=> "w");
    $FrTop->Radiobutton( -variable => \$col_search_data{case_insensitive},
                         -value => 1,
                         -text => 'case insensitive',
                       )->grid(-row=>1, -column=>3,  -sticky=> "w");

    #$rbfrom1->select;
    #$rbdirection1->select;
    #$rbexact1->select;

    my $FrBottom = $Top->Frame( -borderwidth=>2,
                                theme_parameters($r_glbl,'main','-background')
                              )->pack(-side=>'top' ,
                                      -fill=>'x',
                                      -expand=>'y');
    my $entry=
       $FrBottom->Entry(-textvariable => \$col_search_data{string},
                     -width=>20
                    )->pack(-side=>'left',-fill=>'x',-expand=>'y');
    $entry->focus();

    $Top->bind('<Return>',
            sub {  my $row= find_next_col($r_tbh,

                                          use_colmap=>1,
                                          from=>'current',
                                          %col_search_data
                                          );
                   # used elements in col_search_data:
                   # colname string direction extact case_insensitive

                   if (!defined $row)
                     { BrowseDB::TkUtils::err_dialog($Top,
                             "$col_search_data{string} " .
                             "not found in table");
                     }
                   else
                     { my $col= colname2col($r_tbh, $colname);
                       $TableWidget->activate("$row,$col");
                       $TableWidget->yview($row-1);
                       $Top->destroy;
                     };
                }
              );


    #$Top->bind('<Destroy>', sub { delete $r_tbh->{find_line_data}; });

    # let the window appear near the mouse-cursor:
    $Top->Popup(-popover    => 'cursor');
  }

sub tk_find_line_next
# $dir: 'prev' or 'next'
  { my($widget, $r_glbl, $r_tbh, $dir)= @_;

    my $r_col_search_data= $r_tbh->{col_search_data};

    if (!defined $r_col_search_data)
      { BrowseDB::TkUtils::err_dialog($r_glbl->{main_menu_widget},
                      "no search string specified");
        return;
      };

    my $colname= $r_col_search_data->{colname};

    my $row= find_next_col($r_tbh,
                           use_colmap=>1,
                           from=>'current',

                           %$r_col_search_data,
                   # used elements in col_search_data:
                   # colname string direction extact case_insensitive
                   # note: the following line effectively overwrites
                   # a direction that in stored in col_search_data:
                           direction=> ($dir eq 'next') ? 'down' : 'up');

    if (!defined $row)
      { BrowseDB::TkUtils::err_dialog($r_glbl->{main_menu_widget},
              "$r_col_search_data->{string} " .
              "not found in table");
      }
    else
      { my $col= colname2col($r_tbh, $colname);
        my $TableWidget= $r_tbh->{table_widget};
        $TableWidget->activate("$row,$col");
        $TableWidget->yview($row-1);
      };
 }

# edit-field dialog:
#_______________________________________________________

sub tk_field_edit
# mode: "active" or "selected"
  { my($r_glbl, $r_tbh, $mode)= @_;

    if (!defined $mode)
      { $mode= 'active'; };

    my $TableWidget= $r_tbh->{table_widget};

#my($wi,$h,$x,$y)= split(/[x\+\-]/,$TableWidget->geometry());
#warn join("|",$wi,$h,$x,$y),"\n";

    my $title;
    my @cells;
    if ($mode eq 'active')
      { $cells[0]= $TableWidget->index('active');
        $title= "edit field";
      }
    else
      { @cells=  $TableWidget->curselection();
        $title= "edit selection";
      };

    # get row-column of the active cell in the current table
    my($row,$col)= split(",",$cells[0]);
    my($pk,$colname)= rowcol2pkcolname($r_tbh,$row,$col);

    BrowseDB::TkUtils::SimpleTextDialog($r_glbl,$r_tbh,
                           tag=> "field_edit_dialog",
                           title=> $r_tbh->{table_name} . ":edit",
                           text=> $title,
                           default=> put_get_val_direct($r_tbh,1,
                                                        $pk,$colname),
                           callback=> [\&tk_field_edit_finish,\@cells]
                          );

  }

sub tk_field_edit_finish
  { my($r_glbl,$r_tbh,$value,$r_cells)= @_;

    my $TableWidget= $r_tbh->{table_widget};

    foreach my $c (@$r_cells)
      { $TableWidget->set($c, $value); };

  }

# file dialog:
#_______________________________________________________

sub tk_save_to_file
# note: $widget is not really needed, it's just here
# since  this function can be called from via <bind>
# returns: <undef> if nothing was saved,
#          filename if something was saved
  { my($widget,$r_tbh)= @_;

    # warn "save to file";

    my $file= BrowseDB::TkUtils::simple_file_menu(widget=> $r_tbh->{top_widget},
                                  type=> 'save',
                                  extension=>'.dbt',
                                  #defaultdir=>$r_glbl->{dir},
                                  title=>'save table to *.dbt',
                                  extension_description=>
                                              'browsedb table files');

    # warn "filename: $file ";
    return if (!defined $file);

    return if ($file=~ /^\s*$/);

    my $dbitable= $r_tbh->{dbitable};
    my $table_name=  $r_tbh->{table_name};

    my $new_dbi= $dbitable->new('file',$file,
                                $table_name
                               )->store(pretty=> 1,
                                        order_by=> $r_tbh->{sort_columns}
                                       );

    # warn "$file was updated/created";
    return($file);
  }

sub tk_load_from_file
# note: $widget is not really needed, it's just here
# since  this function can be called from via <bind>
  { my($widget,$r_tbh)= @_;

    my $file= BrowseDB::TkUtils::simple_file_menu(widget=> $r_tbh->{top_widget},
                                  type=> 'load',
                                  extension=>'.dbt',
                                  #defaultdir=>$r_glbl->{dir},
                                  title=>'load table from *.dbt',
                                  extension_description=>
                                              'browsedb table files');


    # warn "filename: $file ";
    return if (!defined $file);


    my $Table= $r_tbh->{table_widget};
    my $dbitable= $r_tbh->{dbitable};
    my $table_name=  $r_tbh->{table_name};

    my $ftab= dbitable->new('file',$file,$table_name,
                           )->load(pretty=>1,primary_key=>"generate");



    $dbitable->import_table($ftab,
                            mode=> 'add_lines',
                            primary_key=> 'generate');

    my $r_chg= $r_tbh->{changed_rows};
    my $row;

    # re-calc the number of rows, update the table- widget:
    resize_table($r_tbh);

    # update the displayed content in the active cell:
    tk_rewrite_active_cell($r_tbh);

    foreach my $pk ($dbitable->primary_keys(filter=>'updated'))
      {
        $row= pk2row($r_tbh,$pk);
        $r_chg->{$pk}= $row;
        tk_add_changed_cell_tag($r_tbh,row=>$row);
      };

    foreach my $pk ($dbitable->primary_keys(filter=>'inserted'))
      { $row= pk2row($r_tbh,$pk);
        $r_chg->{$pk}= $row;
        tk_add_changed_cell_tag($r_tbh,row=>$row);
      };

    # the following forces a redraw
    # (maybe not necessary ???)
    $Table->configure(-padx => ($Table->cget('-padx')) );

  }

sub tk_export_csv
# note: $widget is not really needed, it's just here
# since  this function can be called from via <bind>
  { my($widget,$r_tbh)= @_;

    # warn "save to file";

    my $file= BrowseDB::TkUtils::simple_file_menu(widget=> $r_tbh->{top_widget},
                                  type=> 'save',
                                  extension=>'.csv',
                                  #defaultdir=>$r_glbl->{dir},
                                  title=>'export to csv',
                                  extension_description=>
                                              'browsedb csv files');


    # warn "filename: $file ";
    return if (!defined $file);

    return if ($file=~ /^\s*$/);

    my $dbitable= $r_tbh->{dbitable};

    $dbitable->export_csv($file, order_by=> $r_tbh->{sort_columns});

    # warn "$file was updated/created";
  }

sub tk_import_csv
# note: $widget is not really needed, it's just here
# since  this function can be called from via <bind>
  { my($widget,$r_tbh)= @_;

    # warn "save to file";

    my $file= BrowseDB::TkUtils::simple_file_menu(widget=> $r_tbh->{top_widget},
                                  type=> 'load',
                                  extension=>'.csv',
                                  #defaultdir=>$r_glbl->{dir},
                                  title=>'load from csv',
                                  extension_description=>
                                              'browsedb csv files');


    # warn "filename: $file ";
    return if (!defined $file);

    return if ($file=~ /^\s*$/);

    my $Table= $r_tbh->{table_widget};

    my $dbitable= $r_tbh->{dbitable};

    $dbitable->import_csv($file);

    my $r_chg= $r_tbh->{changed_rows};
    my $row;

    # re-calc the number of rows, update the table- widget:
    resize_table($r_tbh);

    # update the displayed content in the active cell:
    tk_rewrite_active_cell($r_tbh);

    foreach my $pk ($dbitable->primary_keys(filter=>'updated'))
      {
        $row= pk2row($r_tbh,$pk);
        $r_chg->{$pk}= $row;
        tk_add_changed_cell_tag($r_tbh,row=>$row);
      };

    foreach my $pk ($dbitable->primary_keys(filter=>'inserted'))
      { $row= pk2row($r_tbh,$pk);
        $r_chg->{$pk}= $row;
        tk_add_changed_cell_tag($r_tbh,row=>$row);
      };

    # the following forces a redraw
    # (maybe not necessary ???)
    $Table->configure(-padx => ($Table->cget('-padx')) );
  }

# tableinfo window:
#_______________________________________________________

sub tk_table_info
 { my($r_glbl,$r_tbh)= @_;
   my $name= $r_tbh->{table_name};

   my $dbh= $r_glbl->{dbh};

   BrowseDB::TkUtils::SetBusy($r_glbl,1);

   my $r_text= BrowseDB::TkUtils::MakeTextWidget($r_glbl,"$name:Object-Info");

   my $text= $r_text->{text_widget};

   my $buffer;

   my $str;
   if    ($r_tbh->{table_type} eq 'table')
     { $str= "object-type: table\n"; }
   elsif ($r_tbh->{table_type} eq 'view')
     { $str= "object-type: view\n"; }
   elsif ($r_tbh->{table_type} eq 'sql')
     { $str= "object-type: arbitrary SQL statement\n"; }
   else
     { $str= "object-type: unknown : $r_tbh->{table_type}\n"; }
   $text->insert('end',$str);

#@@@@@@@@@@@@@@@@@@@@@@@

   my($object_name, $object_owner);
   if ($r_tbh->{table_type} ne 'sql')
     {
       my @dependents= dbdrv::object_dependencies($dbh, 
                                                  $r_tbh->{table_name},
                                                  $r_glbl->{user});
       if (@dependents)
         { $text->insert('end',"\ndependents:\n");
           foreach my $r_s (@dependents)
             { my $st= sprintf("%s.%s (%s)\n",@$r_s);
               $text->insert('end',$st);
             };
         };

       my @referenced= dbdrv::object_references($dbh,
                                                $r_tbh->{table_name},
                                                $r_glbl->{user});
       if (@referenced)
         { $text->insert('end',"\nreferenced objects:\n");
           foreach my $r_s (@referenced)
             { my $st= sprintf("%s.%s (%s)\n",@$r_s);
               $text->insert('end',$st);
             };
         };

       my @constraints_triggers=
             dbdrv::object_addicts($dbh,$r_tbh->{table_name},$r_glbl->{user});
       if (@constraints_triggers)
         { $text->insert('end',"\nconstraints/triggers:\n");
           foreach my $r_s (@constraints_triggers)
             { # caution: name,owner,type here!
               my $st= sprintf("%s.%s (%s)\n",$r_s->[1],$r_s->[0],$r_s->[2]);
               $text->insert('end',$st);
               if ($r_s->[2] eq 'C')
                 { $text->insert('end',"constraint-text:\n");
                   my $st= dbdrv::read_checktext($dbh,
                            $r_s->[0], $r_s->[1]);
                   $text->insert('end',"$st\n");
                 }
             };
         };


     };

   my $dbitable= $r_tbh->{dbitable};
   $str= "\nSQL command:\n" . $r_tbh->{dbitable}->{_fetch_cmd} . "\n";

   $text->insert('end',$str);

   if ($r_tbh->{table_type} eq 'view')
     {
       my $sql= dbdrv::read_viewtext($dbh,$object_name, $r_glbl->{user});

       $str= "\nSQL command of the view:\n" . $sql. "\n";
       $text->insert('end',$str);
     };

   $text->pack(-fill=>'both',-expand=>'y');

   BrowseDB::TkUtils::SetBusy($r_glbl,0);

 }

# dump routines:
#_______________________________________________________


sub tk_table_dump
 { my($r_glbl, $r_tbh)= @_;
   my $name= $r_tbh->{table_name};

   my $buffer;
   rdump(\$buffer,$r_tbh,0);
   BrowseDB::TkUtils::MakeTextWidget($r_glbl,"$name:Object-Dump",\$buffer);

 }

sub tk_dbitable_dump
 { my($r_glbl, $r_tbh)= @_;
   my $name= $r_tbh->{table_name};
   my $dbitable= $r_tbh->{dbitable};

   my $r_buffer= $dbitable->dump_s();

   BrowseDB::TkUtils::MakeTextWidget($r_glbl,"$name:DBITable-Dump",$r_buffer);

 }

# resize column:
#_______________________________________________________

sub cb_resize_col
  { my($parent_widget, $r_glbl, $r_tbh, $mode, $at)= @_;

    my($row,$col)= split(",",$parent_widget->index('active'));

    my $w= $parent_widget->colWidth($col);
    if ($mode eq 'inc')
      { $w++; }
    else
      { $w--};
    return if ($w<2);
    $parent_widget->colWidth($col,$w);
  }

# popup-menues:
#_______________________________________________________

sub cb_popup_menu
  { my($parent_widget, $r_glbl, $r_tbh, $at)= @_;

    my($row,$col)= split(",",$parent_widget->index($at));

    if ($row==0)
      { return(cb_column_popup_menu( $parent_widget,
                                     $r_glbl, $r_tbh, $at)); }
    else
      { return(cb_default_popup_menu($parent_widget,
                                     $r_glbl, $r_tbh, $at)); }
  }

sub cb_column_popup_menu
  { my($parent_widget, $r_glbl, $r_tbh, $at)= @_;

    my $r_popup= $r_tbh->{column_popup};

    # determine row and column of the cell that was clicked:
    my($row,$col)= split(",",$parent_widget->index($at));

    # $row should be 0 !!

    my $colname= col2colname($r_tbh,$col);

    $r_popup->{current_col}= $colname;

    my $MnPopup= $r_popup->{popup_widget};

    my @cell_attributes= ('default');

    if (exists $r_tbh->{foreign_key_hash}->{$colname})
      { push @cell_attributes, 'foreign_key'; };

    popup_enable_disable($r_popup,@cell_attributes);

    $MnPopup->Popup(-popover => "cursor",
                    -popanchor => 'nw');
  }

sub cb_default_popup_menu
  { my($parent_widget, $r_glbl, $r_tbh, $at)= @_;
    my $r_popup= $r_tbh->{default_popup};

    # determine row and column of the cell that was clicked:
    my($row,$col)= split(",",$parent_widget->index($at));

    my($pk,$colname)= rowcol2pkcolname($r_tbh,$row,$col);

    my $MnPopup= $r_popup->{popup_widget};

    # now activate the cell:
    $parent_widget->activate($at);

    my @cell_attributes= ('default');

    if (exists $r_tbh->{foreign_key_hash}->{$colname})
      { push @cell_attributes, 'foreign_key'; };
    if (!$r_tbh->{no_pk_cols})
      { if (exists $r_tbh->{pks_h}->{$colname})
          { push @cell_attributes, 'primary_key'; };
      };
    if (exists $r_tbh->{col_maps}->{$colname})
      { push @cell_attributes, 'column_map'; };

    my $r_wp_flags= $r_tbh->{write_protected_cols};
    if (defined $r_wp_flags->{$colname})
      { if ($r_wp_flags->{$colname} eq 'P')
          { push @cell_attributes, 'write_protected'; };
      };

    popup_enable_disable($r_popup,@cell_attributes);

    $MnPopup->Popup(-popover => "cursor",
                    -popanchor => 'nw');
  }

sub popup_enable_disable
  { my($r_popup,@cell_attributes)= @_;
    my $MnPopup= $r_popup->{popup_widget};
    my $r_items= $r_popup->{popup_item_h};

    my @entrystates;
    for(my $i=0; $i<$r_popup->{popup_items}; $i++)
      { $entrystates[$i]=1; };

    my $r_disable_list= $r_popup->{popup_disable_lists};
    foreach my $attr (@cell_attributes)
      { my $r_l= $r_disable_list->{$attr};
        if (defined $r_l)
          { foreach my $item (@$r_l)
              { $entrystates[$r_items->{$item}]=0;
              };
          };
      };

    my $r_enable_list= $r_popup->{popup_enable_lists};
    foreach my $attr (@cell_attributes)
      { my $r_l= $r_enable_list->{$attr};
        if (defined $r_l)
          { foreach my $item (@$r_l)
              {
                $entrystates[$r_items->{$item}]=1;

              };
          };
      };

    for(my $i=0; $i<= $#entrystates; $i++)
      { if ($entrystates[$i])
          { $MnPopup->entryconfigure($i, -state => 'normal'); }
        else
          { $MnPopup->entryconfigure($i, -state => 'disabled'); }
      };
  }

# manage visible columns:
#_______________________________________________________

sub cb_set_visible_columns
# parameters in $r_tbh:
#  displayed_cols=> \%displayed_columns
#                   this hash has an entry for each column. It is
#                   set to 1 when the column is actually displayed,
#                   else it is set to 0
 { my($r_glbl, $r_tbh)= @_;

   my $r_visible_columns= $r_tbh->{displayed_cols};

   my $d_cnt=0;

   grep { $d_cnt++ if ($_) } (values %$r_visible_columns);

   if ($d_cnt<=0)
     { # error, there would be no column left to display
       my $last_col= $r_tbh->{vis_column_list}->[0];
       $r_tbh->{displayed_cols}->{$last_col}=1;
       return; # it's safe to simply return here!
     };

   calc_visible_columns($r_tbh);

   table_window_set_column_width($r_tbh);

   table_window_tag_columns($r_tbh);

   my $Table_Widget= $r_tbh->{table_widget};

   # the following forces a redraw
   $Table_Widget->configure( -cols => $r_tbh->{vis_column_no},
                           );
  }

sub calc_visible_columns
 { my($r_tbh)= @_;

   my $r_visible_columns= $r_tbh->{displayed_cols};

   my $r_col_hash    = $r_tbh->{column_hash};
   my $r_col_list    = $r_tbh->{column_list};
   my $r_col_widths  = $r_tbh->{column_width};

   my %new_col_hash;

   if (exists($r_tbh->{vis_column_hash}))
     { %new_col_hash= %{ $r_tbh->{vis_column_hash} }; };

   foreach my $c (keys %$r_visible_columns)
     { if ($r_visible_columns->{$c})
         { $new_col_hash{$c}=1; }        # make column visible
       else
         { delete $new_col_hash{$c}; };  # make column invisible
     };

   my @new_col_list;
   my @new_widths;
   my $cnt=0;
   foreach my $c (@$r_col_list)
     { next if (!exists $new_col_hash{$c});
       push @new_col_list, $c;
       push @new_widths, $r_col_widths->[ $r_col_hash->{$c} ];
       $new_col_hash{$c}= $cnt++;
     };

   $r_tbh->{vis_column_list} = \@new_col_list;
   $r_tbh->{vis_column_hash} = \%new_col_hash;
   $r_tbh->{vis_column_no}   = $cnt;
   $r_tbh->{vis_column_width}= \@new_widths;
 }

# export selection dialog:
#_______________________________________________________

sub cb_export_selection
 {  my($r_glbl, $r_tbh)= @_;

    my $Table_Widget= $r_tbh->{table_widget};

    my $r_cells= $Table_Widget->curselection();
    # is a list reference to elements in the form
    # "$row,$col"
    my %column_indices;
    my %pk_selection;
    my $cnt;
    foreach my $e (@$r_cells)
      { my($row,$col)= split(",",$e);
        $column_indices{$col}=1;
        $pk_selection{row2pk($r_tbh,$row)}= $cnt++;
      };
    my @col_selection;
    foreach my $colname (@{$r_tbh->{column_list}})
      { my $col= colname2col($r_tbh,$colname);
        if ($column_indices{$col})
          { push @col_selection,$colname; };
      };

    my $file= BrowseDB::TkUtils::simple_file_menu(widget=> $r_tbh->{top_widget},
                                  type=> 'save',
                                  extension=>'.csv',
                                  #defaultdir=>$r_glbl->{dir},
                                  title=>'export to csv',
                                  extension_description=>
                                              'browsedb csv files');


    # warn "filename: $file ";
    return if (!defined $file);

    return if ($file=~ /^\s*$/);

    my $dbitable= $r_tbh->{dbitable};

    my @pk_selection= sort { $pk_selection{$a} <=>  $pk_selection{$b} }
                             (keys %pk_selection);

    $dbitable->export_csv($file,
                          #order_by=> $r_tbh->{sort_columns},
                          col_selection=> \@col_selection,
                          pk_selection => \@pk_selection
                         );

    # warn "$file was updated/created";


 }

# open foreign table:
#_______________________________________________________

sub cb_open_foreign_table
 {  my($r_glbl, $r_tbh, $given_colname)= @_;

    my $Table_Widget= $r_tbh->{table_widget};


    # $at has the form '@x,y'

    # get row, column of the active cell:
    my($row,$col)= split(",",$Table_Widget->index('active'));
    my($pk,$colname)= rowcol2pkcolname($r_tbh,$row,$col);

    $colname= $given_colname if (defined $given_colname);

    # using Table->get() would be unnecessary slow
    # 0: do not use column-maps
    my $cell_value= put_get_val_direct($r_tbh,0,$pk,$colname);

    my $fkh= $r_tbh->{foreign_key_hash};
    return if (!defined $fkh); # no foreign keys defined

    my $fk_data= $fkh->{$colname};
    return if (!defined $fk_data); # no foreign key column!

    # now activate the cell:
    # $parent_widget->activate($at);


    # marking as active is difficult, since the cell is not editable
    # per definition, the "active" tag (inverse colors) can never be
    # removed !
    # $parent_widget->tagCell('active','active');

    my($fk_table,$fk_col,$fk_owner)= @{$fk_data};

    $fk_table= dbdrv::canonify_name($r_glbl->{dbh},$r_glbl->{user},
                                   $fk_table,$fk_owner);

    # print "foreign key data: $fk_table,$fk_col\n";

    my $r_all_tables= $r_glbl->{all_tables};
    tkdie($r_glbl,"assertion in line " . __LINE__)
      if (!defined $r_all_tables); # assertion, shouldn't happen

    my $r_tbh_fk= $r_all_tables->{$fk_table};

    if (defined $r_tbh_fk)
      { $r_tbh_fk->{top_widget}->raise(); }
    else
      { # 'resident_there' must be given as parameter to
        # make_table_hash_and_window since make_table_window looks for
        # this part of the table-hash and creates the "select" button if
        # that member of the hash is found
        $r_tbh_fk= make_table_hash_and_window( $r_glbl,
                                               table_name=>$fk_table,
                                               table_type=>'table',
                                               thash_defaults=>
                                                   {resident_there=>1}
                                             );
        if (!defined $r_tbh_fk) # table couldn't be opened
          { return; };

         conn_add($r_glbl,$r_tbh->{table_name},$colname,
                  $fk_table,$fk_col);

         # 0: do not use column-maps
         tk_activate_cell($r_tbh_fk,0,$fk_col, $cell_value);
      }
  }

# handle browsing in tables:
#_______________________________________________________

sub cb_handle_browse
# $oldrowcol may be empty !!
 { my($r_glbl,$r_tbh,$oldrowcol,$newrowcol)= @_;


   my($oldrow,$oldcol)= split(",",$oldrowcol);
   my($row,$col)= split(",",$newrowcol);
   if (defined $oldrow)
     { return if ($oldrow == $row); };

   my($pk,$colname)= rowcol2pkcolname($r_tbh,$row,$col);

   # now search for foreign tables
   my $r_foreigners= conn_r_find($r_glbl,$r_tbh);
   # a hash-ref of this type: f_table => [f_col,r_col1,r_col2...]

   return if (!defined $r_foreigners);

   foreach my $f_table (keys %$r_foreigners)
     { my $r_cols= $r_foreigners->{$f_table};
       # $r_cols: list reference: [f_col,r_col1,r_col2...]

       my $f_tbh= $r_glbl->{all_tables}->{$f_table};
       tkdie($r_glbl,"assertion in line " . __LINE__)
         if (!defined $f_tbh); # assertion

       if ($#$r_cols==1)
         { # only one reference to the foreign table, this is the
           # simple case
           # 0: do not use column-maps
           tk_activate_cell($f_tbh,0,$r_cols->[0],
                         put_get_val_direct($r_tbh,0,$pk,$r_cols->[1])
                        );
         }
       else
         { # more complicated, two or more references to the same
           # foreign table, we have to take the currenly selected
           # row into account in order to find out what to do
           for(my $i=1; $i<= $#$r_cols; $i++)
             { if ($r_cols->[$i] eq $colname)
                 { # current column is a resident column, now we know
                   # what to do
                   # 0: do not use column-maps
                   tk_activate_cell($f_tbh,0,$r_cols->[0],
                         put_get_val_direct($r_tbh,0,$pk,$colname)
                                );
                 };
             };
           # when the current column is not a resident column do nothing
         };
     };

 }

# "select THIS as foreign key" callback:
#_______________________________________________________

sub cb_select
# global variables used: NONE
# bound to the 'Select' button
 { my($r_glbl, $r_tbh)= @_;

   my $Table= $r_tbh->{table_widget};

   # get row-column of the active cell in the current table
   my($row,$col)= split(",",$Table->index('active'));
   my($pk,$colname)= rowcol2pkcolname($r_tbh,$row,$col);

   # get the value of the current cell
   # using Table->get() would be unnecessary slow
   # 0: do not use column-maps
   my $value= put_get_val_direct($r_tbh,0,$pk,$colname);

   # now look for residents:
   my $r_residents= conn_f_find($r_glbl, $r_tbh, $colname);
   # a hash-ref: res-table-name => [res_col1,res_col2...]

   if (!defined $r_residents)
     {
# warn "SELECT WARN1\n";
       BrowseDB::TkUtils::err_dialog($Table,
                     "the selected column \"$colname\" is no " .
                     "foreign key in any of the currently displayed " .
                     "tables");
       return;
     };

   my @res_table_list= keys %$r_residents;

   if ($#res_table_list>0)
     {
# warn "SELECT WARN2\n";
       BrowseDB::TkUtils::err_dialog($Table,
                     "the selected column \"$colname\" is\n" .
                     "a foreign key in more than one of currently " .
                                                           "displayed\n" .
                     "tables. Don\'t know what to do!");
       return;
     };

   # the following could handle updates in more than one table, but
   # it makes no sense without asking the user in which one
   # the changes should be made:
   foreach my $res_table (@res_table_list)
     { my $res_tbh= $r_glbl->{all_tables}->{ $res_table };

       my $r_res_columns= $r_residents->{$res_table};
       # ^^^ a list of resident columns

       # get the widget of the resident table:
       my $Res_Table= $res_tbh->{table_widget};

       # get row-column of the active cell in the resident table
       my($res_row,$res_col)= split(",",$Res_Table->index('active'));
       my $res_colname= col2colname($res_tbh,$res_col);

       my $found;
       # now search the list, it is not elegant, I know...
       foreach my $r (@$r_res_columns)
         { if ($r eq $res_colname)
             { # column was found in the list !
               # now set the value in the resident table:
               # this must be done via "set" in order for the table
               # to be displayed correctly

               # remove cell write-protection temporarily:
               $res_tbh->{write_protected_cols}->{$res_colname}= 'T';

               # take column-maps in the foreign table into account:
               my $flag= $res_tbh->{col_map_flags}->{$res_colname};
               if ($flag eq 'M') # map is active
                 { my $r_h=
                      $res_tbh->{col_maps}->{$res_colname}->{key_to_str};

                   my $n= $r_h->{$value};
                   $value= $n if (defined $n);
                 };

               $Res_Table->set("$res_row,$res_col",$value);
               $found=1;
               last;
             };
         };

       if (!$found)
         {
# warn "SELECT WARN4\n";
           BrowseDB::TkUtils::err_dialog($Table,
                         "unable to set because in table \"$res_table\"\n" .
                         "none of the following columns is selected:\n" .
                         join(" ",@$r_res_columns));
         };
     };

 }

# copy and paste field callback:
#_______________________________________________________

sub cb_copy_paste_field
  { my($r_glbl,$r_tbh,$mode)= @_;

    my $Table= $r_tbh->{table_widget};

    # get active cell:
    my($row,$col)= split(",",$Table->index('active'));
    my $colname= col2colname($r_tbh,$col);

    if ($mode eq 'copy')
      { $r_tbh->{paste_buffer}= cb_put_get_val($r_tbh,0,$row,$col);
        return;
      };
    if ($mode eq 'paste')
      { my $r_wp_flags= $r_tbh->{write_protected_cols};
        if (defined $r_wp_flags->{$colname})
          { if ($r_wp_flags->{$colname} eq 'P')
              { $r_wp_flags->{$colname}= 'T';
                # remove write protection temporarily
              };
          };
        $Table->set("$row,$col",$r_tbh->{paste_buffer} );

        return;
      };

    tkdie($r_glbl,"assertion in line " . __LINE__ .
          ", unknown mode: $mode");
  }

# copy and paste line callback:
#_______________________________________________________

sub cb_copy_paste_line
  { my($r_glbl,$r_tbh,$mode)= @_;

    my $Table= $r_tbh->{table_widget};

    # get active cell:
    my($row,$col)= split(",",$Table->index('active'));

    if ($mode eq 'copy')
      { my %line;
        my $pk= row2pk($r_tbh,$row);
        foreach my $colname (keys %{$r_tbh->{column_hash}})
          { # 1: use column-maps
            $line{$colname}= put_get_val_direct($r_tbh,1,$pk,$colname);
          };

        $r_tbh->{paste_linebuffer}= \%line;
        return;
      };

    if ($mode eq 'paste')
      { my $r_line= $r_tbh->{paste_linebuffer};
        my $r_wp_flags= $r_tbh->{write_protected_cols};
        my $pk= row2pk($r_tbh,$row);
        foreach my $colname (keys %$r_line)
          { my $this_col= colname2col($r_tbh,$colname);
            next if ($r_wp_flags->{$colname} eq 'P');
            # do not overwrite primary keys or foreign keys
            $Table->set("$row,$this_col", $r_line->{$colname});
          };
        return;
      };

    tkdie($r_glbl,"assertion in line " . __LINE__ .
          ", unknown mode: $mode");
  }

# put/get value callback:
#_______________________________________________________

sub cb_put_get_val
# global variables used: NONE
# if $visual, use visual column lists
  { my($r_tbh,$set,$row,$col,$val)= @_;

    if ($row==0) # row 0 has the column-names
      { return( $r_tbh->{vis_column_list}->[$col] ); };

    my($pk,$colname)= rowcol2pkcolname($r_tbh,$row,$col);

    if ($set)
      {
# @@@@@@@@@@@@@@@@@@@@
        if ($r_tbh->{sim_put})
          { # just simulate the put, do nothing real
            delete $r_tbh->{sim_put};
            return($val);
          };

        my $flag= $r_tbh->{write_protected_cols}->{$colname};

        if (defined $flag)
          { if ($flag eq 'P')
              { $r_tbh->{table_widget}->bell();
                # warn "no writing allowed on this column"
                return($r_tbh->{dbitable}->value($pk,$colname));
              };
            if ($flag eq 'T')
              { $r_tbh->{write_protected_cols}->{$colname}= 'P'; };
          };


        chomp($val);
        my $putval= $val;

        $flag= $r_tbh->{col_map_flags}->{$colname};
        if ($flag eq 'M') # column-map is active
          { my $r_h= $r_tbh->{col_maps}->{$colname}->{str_to_key};
            my $n= $r_h->{$val};
            if (defined $n)
              { $putval= $n; };
          };

        if (!defined($r_tbh->{dbitable}->value($pk,$colname,$putval)))
          { # writing was not allowed for some reason
            # return the old value
            return($r_tbh->{dbitable}->value($pk,$colname));
          };

        $r_tbh->{dbitable}->value($pk,$colname,$putval);
        $r_tbh->{changed_cells}->{"$pk;$colname"}= "$row,$col";
        tk_add_changed_cell_tag($r_tbh,cell=>"$row,$col");
        #warn "set tag to $row,$col";

        return($val);
      }
    else
      { my $flag= $r_tbh->{col_map_flags}->{$colname};

        return($r_tbh->{dbitable}->value($pk,$colname)) if ($flag ne 'M');

        my $r_h= $r_tbh->{col_maps}->{$colname}->{key_to_str};
        my $val= $r_tbh->{dbitable}->value($pk,$colname);
        return ("") if (!defined $val);
        my $n= $r_h->{$val};
        return($n) if (defined $n);
        return($val);
      };
  }

sub put_get_val_direct
  { my($r_tbh,$use_colmap, $pk,$column,$val)= @_;

    if (!$use_colmap)
      { return($r_tbh->{dbitable}->value($pk,$column,$val)); };

    my $flag= $r_tbh->{col_map_flags}->{$column};
    if ($flag ne 'M')
      { return($r_tbh->{dbitable}->value($pk,$column,$val)); };

    if (defined $val)
      { # set a value
        my $putval= $val;
        my $r_h= $r_tbh->{col_maps}->{$column}->{str_to_key};
        my $n= $r_h->{$val};
        if (defined $n)
          { $putval= $n; };
        if (!defined ($r_tbh->{dbitable}->value($pk,$column,$putval)))
          { # writing was not allowed for some reason 
            # return the old value:
            my $val= $r_tbh->{dbitable}->value($pk,$column);
            my $r_h= $r_tbh->{col_maps}->{$column}->{key_to_str};
            my $n= $r_h->{$val};
            return($n) if (defined $n);
            return($val);
          };    
        return($val);
      }
    else
      { # read a value
        my $r_h= $r_tbh->{col_maps}->{$column}->{key_to_str};
        my $val= $r_tbh->{dbitable}->value($pk,$column);
        my $n= $r_h->{$val};
        return($n) if (defined $n);
        return($val);
      };

  }

# insert-line callback:
#_______________________________________________________

sub cb_insert_line
 { my($r_glbl,$r_tbh)= @_;

   my @pk_cols;
   if (!$r_tbh->{no_pk_cols}) # if there are primary key columns at all
     { 
       if ($r_tbh->{pk_generate}<=0)
         { # enter the primary key manually:
           $r_tbh->{insert_line_values}= {};
           my @x= @{$r_tbh->{pks}};
           $r_tbh->{insert_line_pk_cols}= \@x;

#warn "insert_line_pk_cols: " . join("|",@x);

           cb_insert_line_pk_enter($r_glbl,$r_tbh,undef);


           return;
         };
     };
   cb_insert_line_finish($r_glbl,$r_tbh);

  }

sub cb_insert_line_pk_enter
  { my($r_glbl,$r_tbh,$value)= @_;

#warn "cb_insert_line_pk_enter value: $value";
    if (defined $value)
      { my $col= shift @{$r_tbh->{insert_line_pk_cols}};
        $r_tbh->{insert_line_values}->{$col}= $value;
#warn "storing $value to $col";
      };

    my $col= $r_tbh->{insert_line_pk_cols}->[0];
    
    if (!defined $col) # all pk-columns were processed
      { delete $r_tbh->{insert_line_pk_cols};
#warn "calling cb_insert_line_finish, values: ";
#print Dumper($r_tbh->{insert_line_values});
        cb_insert_line_finish($r_glbl,$r_tbh); 
        return;
      };
      
#warn "calling new dialog with col $col";
    BrowseDB::TkUtils::SimpleTextDialog($r_glbl,$r_tbh,
                      tag=> "primary_key_dialog",
                      title=> "enter a primary key",
                      text=> "enter a new primary key for column $col",
                      callback=> [\&cb_insert_line_pk_enter]
                     );
  }

sub cb_insert_line_finish
 { my($r_glbl,$r_tbh)= @_;
   my $no_pk_cols= $r_tbh->{no_pk_cols};
   my @pk_cols;
   my $r_pk_h;
   
   if (!$no_pk_cols)
     { @pk_cols= @{$r_tbh->{pks}}; 
       $r_pk_h= $r_tbh->{pks_h};
     };

   my $dbitable= $r_tbh->{dbitable};

   my $r_col_hash= $r_tbh->{column_hash};
   
   my $r_values= $r_tbh->{insert_line_values};
   if (!defined $r_values)
     { $r_values= {}; };

   foreach my $col (keys %$r_col_hash)
     { next if (exists $r_pk_h->{$col}); # primary key
       next if (defined $r_values->{$col});
       $r_values->{$col}= ""; 
     };

   # when the primary key is specified in add_line, it
   # will use that primary key and not a generated one

   # print "ADD LINE WITH ",join("|",%h),"\n";
   my $new_pk= $dbitable->add_line(%$r_values);
   
   if (exists $r_tbh->{insert_line_values})
     { delete $r_tbh->{insert_line_values}; };
   
   if (!defined $new_pk)
     { # error during insert of line
       return; 
     };

   my $Table= $r_tbh->{table_widget};

   # re-calc the number of rows, update the table- widget:
   # (there may be new lines inserted in the table)
   resize_table($r_tbh);

   my($row,$col)= pkcolname2rowcol($r_tbh,$new_pk,$pk_cols[0]);
   $Table->activate("$row,$col");
   $Table->see("$row,$col");
   tk_rewrite_active_cell($r_tbh);
 }

# delete-line dialog:
#_______________________________________________________

sub tk_delete_line_dialog
  { my($r_glbl,$r_tbh)= @_;

    my $Table= $r_tbh->{table_widget};

    # get row-column of the active cell in the current table
    my($row,$col)= split(",",$Table->index('active'));
    my($pk,$colname)= rowcol2pkcolname($r_tbh,$row,$col);

    my $Top= BrowseDB::TkUtils::MakeToplevel($r_glbl,
                         parent_widget=> $Table,
                         title=>"$r_tbh->{table_name}: delete");

    my $FrTop = $Top->Frame(-borderwidth=>2,-relief=>'raised',
                            theme_parameters($r_glbl,'main','-background')
                           )->pack(-side=>'top' ,-fill=>'x',
                                  -expand=>'y');
    my $FrDn  = $Top->Frame(theme_parameters($r_glbl,'main','-background')
                           )->pack(-side=>'top' ,-fill=>'y',
                                  -expand=>'y'
                                  );
    $FrTop->Label(-text=>"delete line with primary key $pk ?"
                 )->pack(-side=>'left');


    $FrDn->Button(-text => 'accept',
                 %std_button_options,
                  -command =>
                       sub { $r_tbh->{dbitable}->delete_line(
                                                 $r_tbh->{line_to_delete}
                                                           );

                             # re-calc the number of rows,
                             # update the table- widget:
                             resize_table($r_tbh);

                             # the active cell is not updated,
                             # when the line is deleted, so we have
                             # to do it ourselves:
                             tk_rewrite_active_cell($r_tbh);

                             $Top->destroy;
                           }
                 )->pack(-side=>'left', -fill=>'y');
    $FrDn->Button(-text => 'abort',
                 %std_button_options,
                 -command => sub { delete $r_tbh->{line_to_delete};
                                   $Top->destroy;
                                  }
                 )->pack(-side=>'left', -fill=>'y');

    $r_tbh->{line_to_delete}= $pk;

  }

# store and load to/from database:
#_______________________________________________________

sub cb_store_db
# global variables used: NONE
 { my($r_glbl,$r_tbh)= @_;

   my $pk_mode=  ($r_tbh->{pk_generate} > 0) ? 
                 'generate' : 'preserve';

   # do not reload if storing fails!
   if (!$r_tbh->{dbitable}->store(primary_key=> $pk_mode))
     { return; };

   tk_remove_changed_cell_tag($r_tbh);

   # reload the table, its safer to do this in case
   # that another person has also changed the table in the meantime
   $r_tbh->{dbitable}->load();

   # preliminary primary keys may have been changed, so
   # re-display the table:

   # re-calc list of primary keys:
   # (there may be new lines inserted in the table)

   # re-calc the number of rows, update the table- widget:
   # (there may be new lines inserted in the table)
   resize_table($r_tbh);

   # ^^^ resize_table does also a re-draw of the table-widget

   # update the displayed content in the active cell:
   tk_rewrite_active_cell($r_tbh);

   # the following would also force a redraw
   # $Table->configure(-padx => ($Table->cget('-padx')) );

   return(1);
 }

sub cb_reload_db
# global variables used: NONE
  { my($r_glbl, $r_tbh)= @_;

    if (tk_quit_table($r_glbl,$r_tbh,'reload'))
      { return; };

    my $Table= $r_tbh->{table_widget};
    BrowseDB::TkUtils::SetBusy($r_glbl,1);

    tk_remove_changed_cell_tag($r_tbh);

    if (get_dbitable($r_glbl, $r_tbh))
      { if ($r_tbh->{table_filter})
          {
            $r_tbh->{fastbar}->{filter}->insert(0, $r_tbh->{table_filter});
            push( @ {$r_tbh->{history}->{table_filter}}, $r_tbh->{table_filter});
            $r_tbh->{fastbar}->{order}->insert(0, $r_tbh->{table_order});
            push( @ {$r_tbh->{history}->{table_order}}, $r_tbh->{table_order});
          };
      }

    # re-calc the number of rows, update the table- widget:
    # (there may be new lines inserted in the table)
    resize_table($r_tbh);
    # ^^^ resize_table does also a re-draw of the table-widget

    # update the displayed content in the active cell:
    tk_rewrite_active_cell($r_tbh);

    BrowseDB::TkUtils::SetBusy($r_glbl,0);

    # the following would also force a redraw
    # $Table->configure(-padx => ($Table->cget('-padx')) );
  }


# handle column-maps:
#_______________________________________________________

sub tk_define_col_map
# define a map for a cell
  { my($r_glbl,$r_tbh,$column_name)= @_;

    my %options= ( tag=> "col_map_sql_dialog",
                   title=> "define cell map",
                   text=> "enter a valid SQL command",
                   callback=> [\&tk_define_col_map_finish,
                               $column_name]
                 );

    my $r_m= $r_tbh->{col_maps}->{$column_name};

    if (defined $r_m)
      { $options{default}= $r_m->{sql_command}; };

    BrowseDB::TkUtils::SimpleTextDialog($r_glbl,$r_tbh,%options);
  }

sub tk_define_col_map_finish
  { my($r_glbl,$r_tbh,$sql_command,$column_name)= @_;

    if (!set_column_map($r_glbl,$r_tbh,$sql_command,$column_name))
      { return; };

    tk_rewrite_active_cell($r_tbh);
    table_window_title_tags($r_tbh,$column_name);

    # the following forces a redraw
    my $Table= $r_tbh->{table_widget};
    $Table->configure(-padx => ($Table->cget('-padx')) );

  }

# select foreign key from column-map dialog:
#_______________________________________________________

sub tk_fk_select_dialog
  { my($r_glbl,$r_tbh)= @_;

    my $TableWidget= $r_tbh->{table_widget};

    my($row,$col)= split(",", $TableWidget->index('active'));
    my($pk,$colname)= rowcol2pkcolname($r_tbh,$row,$col);

    my $r_map= $r_tbh->{col_maps}->{$colname};
    return if (!defined $r_map);

    my @values= sort keys %{ $r_map->{str_to_key} };

    BrowseDB::TkUtils::ObjectDialog($r_glbl,$r_tbh,
                     tag=> "fk_select_dialog",
                     title=> "select a value",
                     items=> \@values,
                     text => 'double-click to select',
                     callback=> [\&tk_fk_select_dialog_finish,
                                 $pk,$colname]
                    );

  }

sub tk_fk_select_dialog_finish
  { my($r_glbl,$r_tbh,$str,$pk,$colname)= @_;

    my $flag= $r_tbh->{col_map_flags}->{$colname};
    if ($flag ne 'M') # col-map is inactive
      { my $r_h= $r_tbh->{col_maps}->{$colname}->{str_to_key};

        my $n= $r_h->{$str};
        if (!defined $n)
          { warn "assertion!";
            return;
          };
        $str= $n;
      };

    # remove cell write-protection temporarily:
    $r_tbh->{write_protected_cols}->{$colname}= 'T';
    my($row,$col)= pkcolname2rowcol($r_tbh,$pk,$colname);

    my $Table= $r_tbh->{table_widget};
    $Table->set("$row,$col",$str);
  }


# rewrite active cell (when value has changed):
#_______________________________________________________

sub tk_rewrite_active_cell
# updates the active cell by re-writing the value
# of the cell. Tk::TableMatrix sometimes displayes
# a wrong value in the active cell, e.g. when a line was
# deleted, the old value of the deleted cell
# still remains visible in the active cell
  { my($r_tbh)= @_;

    my $Table= $r_tbh->{table_widget};

    my($row,$col)= split(",",$Table->index('active'));
    $r_tbh->{sim_put}=1;
    # ^^^ tells cb_put_get_val(), which is called by set()
    # (I mean not that call in the line below!) to do (almost)
    # nothing, so no marking as "changed cell", no write protection
    # check and so on...
    $Table->set("$row,$col",cb_put_get_val($r_tbh,0,$row,$col));
  }

# activate cell (when value has changed):
#_______________________________________________________

sub tk_activate_cell
# makes a cell active, given by column-name and value
  { my($r_tbh,$use_colmap,$colname,$value)= @_;

    # currently not defined for display-mode 'form':
    return if ($r_tbh->{display_mode} ne 'table');

    my $row= find_next_col($r_tbh,
                           string=>$value,
                           colname=>$colname,
                           from=>'top',
                           direction=>'down',
                           use_colmap=> $use_colmap,
                           exact=>1);


    return if (!defined $row);

    my $col= colname2col($r_tbh,$colname);

    my $Table= $r_tbh->{table_widget};
    $Table->activate("$row,$col");


    #$Table->see("$row,$col");
    # somehow, yview works much more reliable
    # than see()

    $Table->yview($row-1);
  }

# add changed-cell tag:
#_______________________________________________________

sub tk_add_changed_cell_tag
# options: row=> row-number
#          cell=> "row,col"  (cell-index)
#          cells=> ["row,col", "row2,col2" ... ]
#          redraw=> trigger widget redraw
  { my($r_tbh,%options)= @_;

    my $Table_widget= $r_tbh->{table_widget};
    my $tagname;

    if ($r_tbh->{table_type} eq 'table')
      { $tagname= 'changed_cell'; }
    else
      { $tagname= 'changed_cell_ro'; }

    my $row= $options{row};
    if (defined $row)
      { $Table_widget->tagRow($tagname,$row);
      }
    else
      { if (exists $options{cell})
          { $Table_widget->tagCell($tagname,$options{cell});
          }
        else
          { foreach my $cell (@{$options{cells}})
              { $Table_widget->tagCell($tagname,$cell); };
          };
      };


    # the following forces a redraw
    # (maybe not necessary ???)
    if (exists $options{redraw})
      { $Table_widget->configure(-padx =>
                                 ($Table_widget->cget('-padx'))
                                );
      };
  }

# remove changed-cell tags:
#_______________________________________________________

sub tk_remove_changed_cell_tag
  { my($r_tbh)= @_;

    my $Table_widget= $r_tbh->{table_widget};

    { my $r_changed_cells= $r_tbh->{changed_cells};

      foreach my $k (keys %$r_changed_cells)
        { # set the default-tag
          $Table_widget->tagCell('',$r_changed_cells->{$k});
        };
    };

    { my $r_changed_rows= $r_tbh->{changed_rows};
      # a hash: pk => row-index

      foreach my $k (keys %$r_changed_rows)
        { # set the default-tag
          $Table_widget->tagRow('',$r_changed_rows->{$k});
        };
    };

    $r_tbh->{changed_cells}= {};
    $r_tbh->{changed_rows} = {};
  }

# resort a table:
#_______________________________________________________

sub tk_resort_and_redisplay
# global variables used: NONE
# if $col is undef, do not call put_new_sort_column_first
  { my($r_tbh,$col)= @_;

    my $Table_widget= $r_tbh->{table_widget};
    # remove the "changed" tag
    # it should be re-calculated!!

    # get row-column of the active cell in the current table
    my($a_row,$a_col)= split(",",$Table_widget->index('active'));
    my($a_pk,$a_colname)= rowcol2pkcolname($r_tbh,$a_row,$a_col);


    my $r_changed_cells= $r_tbh->{changed_cells};

    foreach my $k (keys %$r_changed_cells)
      { # set the default-tag
        $Table_widget->tagCell('',$r_changed_cells->{$k});
      };

    reorder_sort_columns($r_tbh,$col,'top') if (defined $col);


    $r_tbh->{pk_list}= get_pk_list($r_tbh);
    $r_tbh->{pk_hash}= calc_pk2index($r_tbh);
    # $r_tbh->{row_no} did NOT change in this case!

    # now re-calc the "changed-cell" tags:
    foreach my $k (keys %$r_changed_cells)
      { my($pk,$colname)= split(";",$k);
        my ($row,$col)= pkcolname2rowcol($r_tbh,$pk,$colname);
        $r_changed_cells->{$k}= "$row,$col";
        tk_add_changed_cell_tag($r_tbh,cell=>"$row,$col");
      };

    # the following forces a redraw
    $Table_widget->configure(-padx => ($Table_widget->cget('-padx')) );

    $a_row= pk2row($r_tbh,$a_pk);
    $Table_widget->activate("$a_row,$a_col");
    $Table_widget->yview($a_row-1);
  }

sub tk_sort_menu
  { my($r_glbl, $r_tbh)= @_;

    my %sort_popup;

    my $Top= BrowseDB::TkUtils::MakeToplevel($r_glbl,
                         title=>"$r_tbh->{table_name}: sort");

    $r_tbh->{sort_popup}= \%sort_popup;


    my $MnPopup= $Top->Menu(-type=> 'normal', -tearoff=>0);

    $sort_popup{popup_widget}= $MnPopup;

    $MnPopup->add('command',
                  -label=> 'move to top',
                  -command => [\&tk_sort_mv_top, $r_tbh, 'top']
                 );
    $MnPopup->add('command',
                  -label=> 'move up',
                  -command => [\&tk_sort_mv_top, $r_tbh, 'up']
                 );
    $MnPopup->add('command',
                  -label=> 'move down',
                  -command => [\&tk_sort_mv_top, $r_tbh, 'down']
                 );


    my $Listbox = $Top->Scrolled(
                                  "Listbox",
                                  -scrollbars=>"oe",
                                  #-width=>34,
                                  -selectmode=>"browse",
                                  -width=>0,
                                  -height=>0,
                                )->pack(-side=>'top',-fill=>'x',
                                        -expand=>'y');


    $Top->Label(-text => "right-button click to move\n" .
                         "close window to activate sort order"
               )->pack(-side=>'top' ,-fill=>'x');


    $sort_popup{listbox}= $Listbox;

    $Listbox->insert("end",@{$r_tbh->{sort_columns}});

    $Top->bind('<Destroy>', sub { delete $r_tbh->{sort_popup};
                                  tk_resort_and_redisplay($r_tbh);
                                }
              );

    $Listbox->bind('<3>',  [\&cb_sort_popup_menu, $r_glbl, $r_tbh, Ev('@')]);

    $Top->Popup(-popover => "cursor",
                    -popanchor => 'nw');

  }

sub cb_sort_popup_menu
  { my($parent_widget, $r_glbl, $r_tbh, $at)= @_;

    my $r_popup= $r_tbh->{sort_popup};

    my $MnPopup= $r_popup->{popup_widget};

    $r_popup->{at}= $at;

    $MnPopup->Popup(-popover => "cursor",
                    -popanchor => 'nw');
  }

sub tk_sort_mv_top
  { my($r_tbh,$mode)= @_;

    my $r_sort_popup= $r_tbh->{sort_popup};

    my $Listbox= $r_sort_popup->{listbox};

    #my $col= $Listbox->get('active');


    my $index= ($Listbox->curselection())[0];

    if (!$index)
      { # at is of the form "@x,y", this must be converted to
        # a listbox-index:
        $index= $Listbox->index($r_sort_popup->{at});
      };

    # now we can get the value of the column
    my $col= $Listbox->get($index);

    reorder_sort_columns($r_tbh,$col,$mode);
    $Listbox->delete(0, 'end');
    $Listbox->insert("end",@{$r_tbh->{sort_columns}});
  }


# collection dialogs:
#_______________________________________________________

sub tk_load_collection
# note: $widget is not really needed, it's just here
# since  this function can be called from via <bind>
  { my($widget,$r_glbl,$file)= @_;

    my $Top= $r_glbl->{main_menu_widget};

    if ((!defined $file) or (! -r $file))
      {
        $file= BrowseDB::TkUtils::simple_file_menu(widget=> $Top,
                                  type=> 'load',
                                  extension=>'.col',
                                  defaultdir=>$r_glbl->{dir},
                                  title=>'open collection',
                                  extension_description=>
                                              'browsedb collections');

      }
    # warn "filename: $file ";
    return if (!defined $file);


#print Dumper(\%save);
#print join(" ",keys %save),"\n";
    do $file;

#print Dumper(\%save);
#print join(" ",keys %save),"\n";

    my $r_all_tables= $save{open_tables};

    foreach my $tab (keys %$r_all_tables)
      { my $r_dat= $r_all_tables->{$tab};

        $r_dat->{tbh}= make_table_hash_and_window(
                            $r_glbl,
                             table_name=>$tab,
                             table_type=>$r_dat->{table_type},
                             sequel=> $r_dat->{sql},
                             geometry=> $r_dat->{geometry},
                             displayed_cols => $r_dat->{displayed_cols},
                             sort_columns=> $r_dat->{sort_columns},
                             col_map_flags=> $r_dat->{col_map_flags},
                             col_maps=> $r_dat->{colmaps}
                                                 );

      };


    foreach my $tab (keys %{$save{foreigners}})
      { my $r_tbh= $r_all_tables->{$tab}->{tbh};

        my $r_c= $save{foreigners}->{$tab};
        foreach my $o_tab (keys %$r_c)
          { my $r_columns= $r_c->{$o_tab};

            my $f_col= $r_columns->[0];
            for(my $i=1; $i<= $#$r_columns; $i++)
              { conn_add($r_glbl,
                         $tab,$r_columns->[$i],
                         $o_tab,$f_col);

                tk_mark_manual_foreign_key_col($r_tbh, $r_columns->[$i]);

              };
          };
      };

  }

sub tk_save_collection
# note: $widget is not really needed, it's just here
# since  this function can be called from via <bind>
# returns: <undef> if nothing was saved,
#          filename if something was saved
  {
    my($widget,$r_glbl)= @_;
    local(*F);

    my $Top= $r_glbl->{main_menu_widget};


    my $file= BrowseDB::TkUtils::simple_file_menu(widget=> $Top,
                                  type=> 'save',
                                  extension=>'.col',
                                  defaultdir=>$r_glbl->{dir},
                                  title=>'save collection',
                                  extension_description=>
                                              'browsedb collections');

    return if (!defined $file);

    my $r_all_tables= $r_glbl->{all_tables};

    my %open_tables;
    foreach my $table_name ( keys %$r_all_tables )
      { my $r_tbh= $r_all_tables->{$table_name};

        my %dat= (table_type => $r_tbh->{table_type},
                  sql        => $r_tbh->{dbitable}->{_fetch_cmd},
                  geometry   => $r_tbh->{top_widget}->geometry(),
                  displayed_cols => $r_tbh->{displayed_cols},
                  sort_columns => $r_tbh->{sort_columns},
                  col_map_flags=> $r_tbh->{col_map_flags},
                 );

        my %colmaps;
        my $r_cm= $r_tbh->{col_maps};
        if (defined $r_cm)
          { foreach my $c (keys %$r_cm)
              { $colmaps{$c}= $r_cm->{$c}->{sql_command}; };
            $dat{colmaps}= \%colmaps;
          };

        $open_tables{$table_name}= \%dat;
      };

    $save{open_tables}= \%open_tables;
    $save{foreigners} = $r_glbl->{foreigners};

    #$save{residents}  = $r_glbl->{residents};

    $Data::Dumper::Indent= 1;

#    my $file= $r_glbl->{dir} . join("_","/test",
#                            $r_glbl->{db_driver},
#                            $r_glbl->{db_source},
#                            $r_glbl->{user});

    open(F, ">$file") or die;
    print F Data::Dumper->Dump([\%save], [qw(*save)]);
    close(F);
    return($file);
  }



# tracing:
#_______________________________________________________

sub dbi_sql_trace
# uses a global variable !!
  { my $Text= $global_data{sql_commands_widget};
    $Text->insert('end',$_[0] . "\n");
    $Text->see('end');
  }

# error-handling:
#_______________________________________________________

sub dbiwarn
# uses a global variable !!
  {
    tkwarn(\%global_data,@_);
  }

sub dbidie
# uses a global variable !!
  {
#warn "dbidie was called";
    tkdie(\%global_data,@_);
  }


sub tkdie
  { my($r_glbl,$message)= @_;

#warn "MSG:$message\n";

    my $Top= $r_glbl->{main_menu_widget};
    if (!defined $Top)
      { $Top= $r_glbl->{login_widget}; };

    BrowseDB::TkUtils::fatal_err_dialog($Top,$message);
  }

sub tkwarn
  { my($r_glbl,$message)= @_;

    my $Top= $r_glbl->{main_menu_widget};
    if (!defined $Top)
      { $Top= $r_glbl->{login_widget}; };
    my $dialog= $Top->Dialog(
                             -title=>'warning',
                             -text=> $message
                            );
    $dialog->Show();
  }


#=======================================================
# routines that do not create menues or windows:
#=======================================================

# get parameters from the "theme" hash:
#_______________________________________________________

sub theme_parameters
  { my($r_glbl, $key, @keylist)= @_;
    my %local;
  
    my $r_h= $r_glbl->{theme}->{$key};
    my $r_h_glbl;
    
    if (!defined $r_h)
      { warn "warning: theme for $key not found\n" .
             "(was called from " . join(",",caller) . ")";
        return; 
      };
      
    if ($key=~ /^([^:]+):/)
      { $r_h_glbl= $r_glbl->{theme}->{$1}; }; 
      
    if (!@keylist)
      { if (!defined $r_h_glbl)
          { return(%$r_h); };
        %local= (%$r_h_glbl,%$r_h); # overlay both hashes
        return(%local);
      };
    # we use the fact here that
    # hashes and lists are a bit "the same"
    # when they are returned by functions
    # (hashes are then converted to lists)
    my @l;
    my $val;
    foreach my $k (@keylist)
      { next if (!defined $k); # special hack, <undef> 
                               # keys are not looked for
        $val= $r_h->{$k};
        if (!defined $val)
          { if (defined $r_h_glbl)
              { $val= $r_h_glbl->{$k}; };
            if (!defined $val)
              { warn "warning: theme for $key, property $k not found\n" .
                 "(was called from " . join(",",caller) . ")";
                next; 
              };        
          };
        $local{$k}= $val;
      };
    return(%local);      
  }

# find a value in a table:
#_______________________________________________________

sub find_next_col
# searches a value in a given column
# returns the row-number or undef
# known options:
# string => $string or reference to a string
# colname=> $colname
# from => "current","top"
# direction=> 'down', 'up'
# exact => 1 or undef
# case_insensitive => 1 or undef
# use_colmap => 1 (0 is default)
# NOTE: row 0 is the heading!!!
  { my($r_tbh,%options)= @_;

    my $Table= $r_tbh->{table_widget};

    my $str= $options{string};
    if (ref($str))
      { $str= $$str; };

    return if (!defined $str); # seems sometimes to happen

    my $dir= ($options{direction} eq 'down') ? 1 : -1;

    my $max= $r_tbh->{row_no};
    my $colname= $options{colname};

    my $use_colmap= $options{use_colmap};

    my $row;
    if ($options{from} eq 'top')
      { $row=0;
      }
    else
      { my $c;
        ($row,$c)= split(",",$Table->index('active'));
      };

    if ($options{exact})
      {
        # make things faster if the column to search is
        # a primary key column:
        if (!$options{case_insensitive})
          {
            if (exists $r_tbh->{pks_h}->{$colname}) # it's a primary key
              { if ($#{$r_tbh->{pks}}==0) # only one primary key
                  {
                    return($r_tbh->{pk_hash}->{$str});
                  };
              };
          };

        return if (!defined $str);

        my $case= $options{case_insensitive};
        $str= lc($str) if ($case);
        my $val;

        for(my $i=0; $i<$max; $i++)
          { $row+= $dir;
            if    ($row<=0)
              { $row= $max; }
            elsif ($row>$max)
              { $row=1; };

            $val= put_get_val_direct($r_tbh,$use_colmap,
                                   row2pk($r_tbh,$row),$colname);
            $val= lc($val) if ($case);

            if ($val eq $str)
              { return($row); };
          };
      }
    else
      { my $val;
        my $regexp;
        if ($options{case_insensitive})
          { $regexp= qr/$str/i; }
        else
          { $regexp= qr/$str/; }

        for(my $i=0; $i<$max; $i++)
          { $row+= $dir;
            if    ($row<=0)
              { $row= $max; }
            elsif ($row>$max)
              { $row=1; };
            $val= put_get_val_direct($r_tbh,$use_colmap,
                                   row2pk($r_tbh,$row),$colname);
            next if (!defined $val);
            if ($val=~ $regexp)
              { return($row); };
          };
      };
    return;
  }

# handle column-maps:
#_______________________________________________________

sub set_column_map
  { my($r_glbl,$r_tbh,$sql_command,$column_name)= @_;


    my($key_to_str,$r_str_to_key)=
            get_column_map($r_glbl,$sql_command,$column_name);

    return if (!defined $r_str_to_key);

    my %col_map;
    $col_map{key_to_str} = $key_to_str;
    $col_map{str_to_key} = $r_str_to_key;
    $col_map{sql_command}= dbdrv::format_sql_command($sql_command);

    $r_tbh->{col_map_flags}->{$column_name}= 'M';

    $r_tbh->{col_maps}->{$column_name}= \%col_map;

    return(1);
  }

sub column_has_a_map
  { my($r_tbh,$column_name)= @_;

    return( exists $r_tbh->{col_maps}->{$column_name} );
  }

sub get_column_map
  { my($r_glbl,$sql_command,$column_name)= @_;

    $sql_command= dbdrv::format_sql_command($sql_command);

    my $r_map_hash= $r_glbl->{map_hash};
    if (!defined $r_map_hash)
      { my %h;
        $r_glbl->{map_hash}= \%h;
        $r_map_hash= \%h;
      };

    if (exists $r_map_hash->{$sql_command})
      { return($r_map_hash->{$sql_command}->{key_to_str},
               $r_map_hash->{$sql_command}->{str_to_key}
              );
      };

    my $ntab= dbitable->new('view',$r_glbl->{dbh},
                             'col_map_query',"",$sql_command
                           );

    return if (!defined $ntab);

    $ntab->load();
    return if (!defined $ntab);

    my @columns= $ntab->column_list();
    my $c1= $columns[0];
    my $c2= $columns[1];

    my $key;
    my $str;
    my %key_to_str;
    my %str_to_key;
    foreach my $pk ($ntab->primary_keys())
      { $key= $ntab->value($pk,$c1);
        $str= $ntab->value($pk,$c2);
        $key_to_str{$key}= $str;
        $str_to_key{$str}= $key;
      };

    $r_map_hash->{$sql_command}->{key_to_str}= \%key_to_str;
    $r_map_hash->{$sql_command}->{str_to_key}= \%str_to_key;
    return(\%key_to_str,\%str_to_key);
  }

sub load_column_maps
  { my($r_glbl,$file)= @_;

    local(*F);

    my %h;

    if (!-e $file)
      { return; };

    if (!open(F, $file))
      { warn "opening of the column-map file failed";
        return;
      };
    while(my $line=<F>)
      { chomp($line);
        my ($table,$col,$sql) = &parse_line('\s+', 0, $line);
        if (!defined $sql)
          { warn "column-map entry ignored:\n$line\n";
            next;
          };
        $table= uc($table);
        $col  = uc($col);
        $h{$table}->{$col}= dbdrv::format_sql_command($sql);
      };
    close(F);
    return(\%h);
  }

sub add_to_local_column_maps
  { my($r_glbl,$r_tbh,$file)= @_;

    local(*F);

    my $r_colmaps= $r_tbh->{col_maps};
    return if (!defined $r_colmaps);

    my $r_h= load_column_maps($r_glbl,$file);

    my $tablename= $r_tbh->{table_name};
    foreach my $col (keys %$r_colmaps)
      {
        $r_h->{$tablename}->{$col}= $r_colmaps->{$col}->{sql_command};
      };

    # now weed out definitions that are already contained
    # in the global definitions:
    my $r_g_colmaps= $r_glbl->{column_map_definitions_global};
    if (defined $r_g_colmaps)
      { foreach my $tablename (keys %$r_g_colmaps)
          { next if (!exists $r_h->{$tablename});
            my $r_g_tmap= $r_g_colmaps->{$tablename};
            my $r_l_tmap= $r_h->{$tablename};
            foreach my $col (keys %$r_g_tmap)
              { next if (!exists $r_l_tmap->{$col});
                my $l_sql= $r_l_tmap->{$col};
                my $g_sql= $r_g_tmap->{$col};
                if ($l_sql eq $g_sql)
                  { delete $r_l_tmap->{$col}; };
              };
            if (!(keys %$r_l_tmap)) # empty list
              { delete $r_h->{$tablename}; };
          };
        if (!(keys %$r_h)) # nothing to save
          { return; # we could also delete the local
                    # column-map file...
          };
      };

    if (-e $file)
      { if (system("mv $file $file.old"))
          { warn "unable to make safety copy, aborted!";
            return;
          };
      };
    if (!open(F, ">$file"))
      { warn "unable to write file!\n";
      };

    foreach my $table (sort keys %$r_h)
      { my $r_c= $r_h->{$table};
        foreach my $col (sort keys %$r_c)
          { printf F "%-10s %-10s \"%s\"\n",$table,$col,$r_c->{$col};
          };
      };
    if (!close(F))
      { warn "unable to write file!\n";
      };


    # $r_glbl->{column_map_definitions_local}= $r_h;
  }

# show whether the table was changed:
#_______________________________________________________
sub table_changed
  { my($r_tbh)= @_;
  
    my $r_h= $r_tbh->{changed_cells};
    return if (!defined $r_h);
    
    if (%$r_h)
      { return(1); };
    return;
  }

# convert primary-key,column-name <--> indices:
#_______________________________________________________

sub colname2col
# map column-name to column-index
  { my($r_tbh,$col_name)= @_;

    my $col= $r_tbh->{vis_column_hash}->{$col_name};
    $col=0 if (!defined $col); # if it's a hidden column
    return($col);
  }

sub pk2row
# map primary-key, column-name to row,column
  { my($r_tbh,$pk)= @_;

    return( $r_tbh->{pk_hash}->{$pk} );
  }

sub pkcolname2rowcol
# map primary-key, column-name to row,column
  { my($r_tbh,$pk,$col_name)= @_;

    my $col= $r_tbh->{vis_column_hash}->{$col_name};
    $col=0 if (!defined $col); # if it's a hidden column
    return( $r_tbh->{pk_hash}->{$pk}, $col );
  }


sub col2colname
# map row,column to primary-key, column-name
  { my($r_tbh,$col)= @_;

    return($r_tbh->{vis_column_list}->[$col] );
  }

sub row2pk
# map row to primary-key
  { my($r_tbh,$row)= @_;

    return($r_tbh->{pk_list}->[$row-1] );
  }

sub rowcol2pkcolname
# map row,column to primary-key, column-name
  { my($r_tbh,$row,$col)= @_;

    return($r_tbh->{pk_list}->[$row-1], $r_tbh->{vis_column_list}->[$col] );
  }

sub get_pk_list
# requests a primary key list from the dbitable object
# the sort order is taken according to $r_tbh->{sort_columns}
  { my($r_tbh)= @_;

    my @pk;

    if ($r_tbh->{table_order})
      { @pk= $r_tbh->{dbitable}->primary_keys(order_native=>1); }
    else
      { my %col_hash;
        my $r_h= $r_tbh->{col_map_flags};
        my $r_colmaps= $r_tbh->{col_maps};

        foreach my $c (keys %$r_h)
          { next if ($r_h->{$c} ne 'M');
            $col_hash{$c}= $r_colmaps->{$c}->{key_to_str};
          };

        @pk= $r_tbh->{dbitable}->primary_keys(
                             order_by=> $r_tbh->{sort_columns},
                             col_maps=> \%col_hash
                                             );
      };

#warn "sort order:" . join ("|",@{$r_tbh->{sort_columns}});
    return(\@pk);
  }

sub calc_pk2index
# calculates pk_hash which maps the primary-key to a row-index
  { my($r_tbh)= @_;
    my $cnt=1;
    my %pkh= map { $_ => $cnt++ } (@{$r_tbh->{pk_list}});

    return(\%pkh);
  }

# sorting:
#_______________________________________________________

sub initialize_sort_columns
  { my($r_tbh)= @_;

    return if ($r_tbh->{no_pk_cols});

    my @pks= @{$r_tbh->{pks}};

    for(my $i= $#pks; $i>=0; $i--)
      { reorder_sort_columns($r_tbh, $pks[$i], 'top'); };
  }

#sub put_new_sort_column_first
sub reorder_sort_columns
# global variables used: NONE
# changes $r_tbh->{sort_columns}
# mode: top, up, down
  { my($r_tbh,$col_name,$mode)= @_;

    my $r_cols= $r_tbh->{sort_columns};
    my $i;
    my $max= $r_tbh->{column_no} - 1;

    for($i=0; $i<=$max; $i++)
      { if ($r_cols->[$i] eq $col_name)
          { last; };
      };

    if ($i>$max)
      { # not found
        BrowseDB::TkUtils::err_dialog($r_tbh->{table_widget},
                     "put_new_sort_column_first:\n" .
                     "column $col_name not found");
        return;
      };
    if    ($mode eq 'top')
      { return if ($i==0);
        splice( @$r_cols,$i,1 );
        unshift @$r_cols,$col_name;
      }
    elsif ($mode eq 'up')
      { return if ($i==0);
        splice( @$r_cols,$i,1 );
        splice( @$r_cols,$i-1,0,$col_name);
      }
    elsif ($mode eq 'down')
      { return if ($i==$max);
        splice( @$r_cols,$i,1 );
        splice( @$r_cols,$i+1,0,$col_name);
      }
    else
      { die "unknown mode: $mode"; # assertion
      };
  }

# load from database:
#_______________________________________________________

sub get_dbitable
# global variables used: $sim_oracle_access
# returns a new table object
#
# elements of $r_tbh (the table-hash):
#
#   dbh          => $database_handle
#   table_name   => $table_name
#   table_type   => $type, $type either 'table','view', 'sql' or
#                   'table_or_view'
#   table_filter => $WHERE_part
#        $WHERE_part is added after "WHERE" to the SQL fetch command
#        this is not allowed for the type "sql" (see above)
#   table_order => $ORDER_BY_part
#   sequel       => $sql_statement
#        only for the type "sql", specifies the SQL fetch command
  { my($r_glbl,$r_tbh)= @_;

    if ($sim_oracle_access)
      {
        my $tab= dbitable->new('file',"","Test-Table",
                               'PK','PK','NAME','VALUE'
                              );

        for(my $i=0; $i<20; $i++)
          { my %h;
            $tab->add_line(#PK=>  $i,
                           NAME=> (chr($i+ord('A')) x 5),
                           VALUE=> 10000-$i*100);
          };
        return($tab);
      };

#warn "get from oracle: $r_tbh->{table_name} as $r_tbh->{table_type} filtered
#by '$r_tbh->{table_filter}' ordered by '$r_tbh->{table_order}'";
    my $ntab;
    my %load_options;

    if ($r_tbh->{table_type} ne "sql")
      { if ($r_tbh->{table_type} eq 'table_or_view')
          {
            if (dbdrv::object_is_table($r_glbl->{dbh},
                                       $r_tbh->{table_name},
                                       $r_glbl->{user}))
              { $r_tbh->{table_type}= 'table'; }
            else
              { $r_tbh->{table_type}= 'view'; };
          };
        if (! defined($r_tbh->{dbitable}))
          {
            $ntab= dbitable->new('table',$r_tbh->{dbh},
                             $r_tbh->{table_name},
                            );
          }
        else
          {
            $ntab = $r_tbh->{dbitable};
          }
        if ($r_tbh->{table_filter})
          { $load_options{filter}  = ['SQL',$r_tbh->{table_filter}]; };
        if ($r_tbh->{table_order})
          { $load_options{order_by}= $r_tbh->{table_order}; };
      }
    else
      {
        $ntab= dbitable->new('view',$r_tbh->{dbh},
                             $r_tbh->{table_name},"",$r_tbh->{sequel}
                            );
      };

    if (!defined $ntab)
      { # dbitable prints an error-message of it's own, so there is
        # no need to print the same error here again
        return;
      };
    $ntab->load(%load_options);
    return($ntab);
  }

# string utilities:
#_______________________________________________________

sub same_start
# in a list of strings returns the longest
# substring that all strings start with
  { my($r_list)= @_;
    my $charno;

    return if ($#$r_list<0);

    return( $r_list->[0]) if ($#$r_list==0);

    my $len= length($r_list->[0]);
    my $loop=1;

    $charno=-1;
    $loop=1;

    while(($charno<$len) & $loop)
      { $charno++;
        my $c= substr($r_list->[0],$charno,1);
        for(my $i=1; $i<= $#$r_list; $i++)
          { if ( substr($r_list->[$i],$charno,1) ne $c)
              { $charno--; $loop=0; last; };
          };
      };
    if ($charno<0)
      { return; };
    return( substr($r_list->[0],0,$charno+1) );
  }

# handle connection lists:
#_______________________________________________________

sub conn_add
# $r_table must be a string !
  { my($r_glbl,$r_table,$r_col,$f_table,$f_col)= @_;

    tkdie($r_glbl,"assertion in line " . __LINE__)
      if (ref($r_table)); # assertion
    tkdie($r_glbl,"assertion in line " . __LINE__)
      if (ref($f_table)); # assertion

    push @{$r_glbl->{residents}->{$f_table}->{$f_col}->{$r_table}},
         $r_col;

    my $r_list= $r_glbl->{foreigners}->{$r_table}->{$f_table};
    if (!defined $r_list)
      { my @l= ($f_col);
        $r_glbl->{foreigners}->{$r_table}->{$f_table}= \@l;
        $r_list= \@l;
      };

    push @$r_list, $r_col;

  }

sub conn_delete_table
  { my($r_glbl,$table)= @_;

    # deleting a table is unfortunately rather complicated
    # especially, when a table "in the middle" with respect
    # to table->foreign_key->foreign_table->2nd. foreign_key->2nd foreign table
    # is deleted

    tkdie($r_glbl,"assertion in line " . __LINE__)
      if (ref($table)); # assertion

    my $r_residents = $r_glbl->{residents}->{$table};
    my $r_foreigners= $r_glbl->{foreigners}->{$table};

    # now find all resident_tables:
    my %resident_tables;
    if (defined $r_residents)
      { foreach my $col (keys %$r_residents)
          { foreach my $table_name (keys %{$r_residents->{$col}})
              { $resident_tables{$table_name}=1; };
          };
      };

    # now find all foreign tables
    my %foreign_tables;
    if (defined $r_foreigners)
      { foreach my $tab (keys %$r_foreigners)
          { $foreign_tables{$tab}=1; };
      };

    # clean up the global 'residents' hash:
    delete $r_glbl->{residents}->{$table};
    foreach my $ftab (keys %foreign_tables)
      { my $r_colhash= $r_glbl->{residents}->{$ftab};
        next if (!defined $r_colhash);
        foreach my $col (keys %$r_colhash)
          { delete $r_colhash->{$col}->{$table};
            if (!keys %{$r_colhash->{$col}})
              { delete $r_colhash->{$col}; };
          };
        if (!keys %$r_colhash)
          { delete $r_glbl->{residents}->{$ftab}; };
      };

    # clean up the global 'foreigners' hash
    delete $r_glbl->{foreigners}->{$table};
    foreach my $rtab (keys %resident_tables)
      { my $r_tabhash= $r_glbl->{foreigners}->{$rtab};
        next if (!defined $r_tabhash);
        delete $r_tabhash->{$table};
        if (!keys %$r_tabhash)
          { delete $r_glbl->{foreigners}->{$rtab}; };
      };

  }

sub conn_r_find
# find connections for a given resident-table
  { my($r_glbl,$r_tbh)= @_;

    my $r_table= $r_tbh->{table_name};

    return( $r_glbl->{foreigners}->{$r_table} );

    # return a hash-ref of this type: f_table => [f_col,r_col1,r_col2...]
  }

sub conn_f_find
# find connections for a given foreign-table
  { my($r_glbl,$f_tbh,$f_col)= @_;
    my $f_table= $f_tbh->{table_name};

    my $r_residents= $r_glbl->{residents}->{$f_table}->{$f_col};

    # return a hash-ref: res-table-name => [res_col1,res_col2...]
    return($r_residents);
  }

# beautify a file-path
#_______________________________________________________

sub path_beautify
  { my($path)= @_;
    my $old= cwd;

    if (!chdir($path))
      { chdir($old) or die "unable to chdir to $old!";
        return($path);
      };
    $path= cwd;
    chdir($old) or die "unable to chdir to $old!";
    return($path);
  }

# recursively find files
#_______________________________________________________

sub file_find
  { my($regexp,@dirs)= @_;

    # filter out dirs that are "undef"
    my @mydirs= grep { defined $_ } @dirs;
    return if (!@mydirs);

    @wanted_array= ();
    $wanted_regex= $regexp;


    find( { wanted => \&wanted, follow => 1 }, @mydirs);

    #print "found:\n",join("\n",@wanted_array);
    return(sort @wanted_array);
  }

sub wanted
  { my $file= $_;

    return unless (-f $file);
    return if (-z $file);
    return if (!-r $file);

    return if ($file!~ /$wanted_regex/);
    push @wanted_array,$File::Find::name;
  }

# recursive dump:
#_______________________________________________________

#sub trysplit
#  { my($st, $maxlen, $indent)= @_;
#    my $str;
#                         
#    my @tokens= &parse_line('\b', 1, $st);
#    
#    while(@tokens)
#      { my $line= shift @tokens; 
#        if (@tokens)
#         { my $l= length($line);
#            while($l+length($tokens[0]) < $maxlen)
#             { $line.= shift @tokens;
#               $l+= length($tokens[0]); 
#               last if (!@tokens);
#               next;  
#             };
#         };      
#       if (defined $str)
#         { $str.= "\\\n" . (" " x $indent); };
#       $str.= $line;
#      };
#    return($str);
#  }
    

sub rdump
#internal
  { my($r_buf,$val,$indent,$is_newline,$comma)= @_;

    $comma= '' if (!defined $comma);

    my $r= ref($val);
    if (!$r)
      { $val= "<undef>" if (!defined $val);
        $$r_buf.= " " x $indent if ($is_newline);
        
#       if (length($val)>50)
#         { $val= trysplit($val,40,$indent); };
        
        $$r_buf.= "\'$val\'$comma\n";
        return;
      };
    if ($r eq 'ARRAY')
      { $$r_buf.= "\n" . " " x $indent if ($is_newline);
        $$r_buf.= "[ \n"; $indent+=2;
        for(my $i=0; $i<= $#$val; $i++)
          { rdump($r_buf,$val->[$i],$indent,1,($i==$#$val) ? "" : ",");
          };
        $indent-=2; $$r_buf.= " " x $indent ."]$comma\n";
        return;
      };
    if ($r eq 'HASH')
      { $$r_buf.=  "\n" . " " x $indent if ($is_newline);
        $$r_buf.=  "{ \n"; $indent+=2;
        my @k= sort keys %$val;
        for(my $i=0; $i<= $#k; $i++)
          { my $k= $k[$i];
            my $st= (" " x $indent) . $k . " => ";
            my $nindent= length($st);
            if ($nindent-$indent > 20)
              { $nindent= $indent+20;
                $st.= "\n" . (" " x $nindent)
              };

            $$r_buf.= ($st);
            rdump($r_buf,$val->{$k},$nindent,0,($i==$#k) ? "" : ",");
          };
        $indent-=2; $$r_buf.= " " x $indent . "}$comma\n";
        return;
      };
    $$r_buf.=  " " x $indent if ($is_newline);
    $$r_buf.=  "REF TO: \'$r\'$comma\n";
  }


__END__

Verbesserungsvorschläge:

* (default für rechte Maustaste (bei Doppelclick rechts))

* entry-felder: return soll was aktivieren

* cb_activate_window is activating and deiconfied opened parent_window

* bei "SEQUEL": order-by beachten

BUGS:

Zeile ändern und später löschen führt zu fatalem Fehler
(programm beendet sich nicht aber funktioniert dann nicht mehr richtig)

delete-line minidialog muß über dem Cursor plaziert werden (->popup())

-----------------------------------------------------------
save und "save as" bei collections.
"save" fragt nicht nach dem Filenamen
-------------------------------------
info-Fenster readonly machen
ctrl-z Key Binding abschalten
-----------------------------------
foreign tables: die Zeilen filtern
-----------------------------------
drucken ??
-----------------------------------
column-map dialog besser machen
-----------------------------------
colum-map Ansicht als select-statement exportieren
-----------------------------------
doppel-click sollte das Feld-Edit Fenster öffnen
-----------------------------------
Reload im Fehlerfall lieber nicht machen (Store!)
-----------------------------------
Relogin funktioniert nicht, browsedb crashed !!!!!
-----------------------------------
evtl Store bei jeder Änderung (nur bei Autocommit off)
-----------------------------------
Save Preferences Dialog einbauen!

Doppelclick auf Feld sollte Edit Fenster fuer das Feld oeffnen

bei sql-update nur die geänderten Felder schreiben !

Hide Columns mit Selektion über mehrere Columns mit einem Schritt

4768 uninitialized Value in hash
4770 uninitialized value in string "ne"

====================
