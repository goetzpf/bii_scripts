eval 'exec perl -S $0 ${1+"$@"}' # -*- Mode: perl -*-
    if 0;
# the above is a more portable way to find perl
# ! /usr/bin/perl

use strict;

use FindBin;

# search dbitable.pm ralative to the location of THIS script:
use lib "$FindBin::RealBin/../lib/perl";

#You may specify where to find Tk::TableMatrix, when
#it is not installed globally like this:
#use lib "$ENV{HOME}/project/perl/lib/site_perl";
#use lib "/home/unix/pfeiffer/project/perl/lib/site_perl";

# the following is only for my testing perl-environment:
#use lib "$ENV{HOME}/pmodules";
#use perl_site;
use Sys::Hostname;
use Config;

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
#use Tk::Balloon;

use Tk::TableMatrix;
#use Tk::TableMatrix::Spreadsheet;
use Tk::ProgressBar;
#use Tk::Date;
#use Tk::NumEntry;

use Text::ParseWords;
use IO::File;
#use Tk::ErrorDialog;

use warnings;
#use diagnostics;

use dbdrv 1.2;
use dbitable 2.1;

use Data::Dumper;
my $VERSION= "0.93";

#warn "TK Version: " . $Tk::VERSION;

my $os= $Config{osname};
my %forkable_os= map { $_=>1 } qw(hpux linux);
# MSWin32 on windows

if ($forkable_os{$os})
  {
    # switch myself to the background:
    # (doesn't work on windows)
    if (0 != fork)
      { # parent here
        exit(0);
      };
  };

our %save; # global configuration variable

my $home= $ENV{"HOME"};
if (!defined $home)
  { $home=""; };

my $PrgDir = $home."/.browsedb";
if (! -e $PrgDir)
  {
    mkdir($PrgDir, 00700) or
      die "Can not create configuration location at ".$PrgDir;
  };

my $column_map_file= 'column_maps.txt';

my $PrgTitle= 'BrowseDB';

my $sim_oracle_access=0;

my $guest_login=0; # for debuggin only, default: 0
my $fast_test=0; # skip login dialog and open $fast_table
my $fast_table='p_insertion';

my $db_table_name;
if (!@ARGV)
  { $db_table_name= "p_insertion_value"; }
else
  { $db_table_name= shift; };

my $db_driver    = "Oracle";
my $db_source    = "bii_par";
my $db_username  = "guest";
my $db_password  = "bessyguest";

my $db_proxy     = "ocean.acc.bessy.de";
my $db_proxy_port= 12109;

my $r_alias;

my $BG= "gray81";
my $BUTBG= "gray73";
my $ACTBG= "gray73";

# re-define the dbitable error-handler:
dbdrv::set_err_func(\&dbidie);
dbdrv::set_warn_func(\&dbiwarn);
$dbitable::sim_delete = 0;

my %std_button_options= (-font=> ['helvetica',10,'normal'],
                         -background=>$BUTBG, -activebackground=>$ACTBG);

my %std_menue_button_options=
                        (-font=> ['helvetica',10,'normal'],
                         -background=>$BUTBG, -activebackground=>$ACTBG,
                         -relief=> 'raised'
                         );

# --------------------- chdir to the directory where THIS SCRIPT is located
# change to the place where THIS SCRIPT is located:
chdir $FindBin::Bin;

# --------------------- database access

my %global_data;

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


    if ($fast_test || $guest_login)
      { tk_login_finish($r_glbl);
        return;
      };

    my $Top= $r_glbl->{main_menu_widget}->Toplevel(-background=>$BG);
    $Top->title("$PrgTitle:Login");

    $r_glbl->{login_widget}= $Top;
    my $FrTop = $Top->Frame(-background=>$BG
                           )->pack(-side=>'top' ,-fill=>'both');
    my $FrDn  = $Top->Frame(-background=>$BG
                           )->pack(-side=>'top' );

    my $row=0;

    $FrTop->Label(-text => 'driver:'
                 )->grid(-row=>$row++, -column=>0, -sticky=> "w");
    $FrTop->Label(-text => 'database:'
                 )->grid(-row=>$row++, -column=>0, -sticky=> "w");
    $FrTop->Label(-text => 'user:'
                 )->grid(-row=>$row++, -column=>0, -sticky=> "w");
    $FrTop->Label(-text => 'password:'
                 )->grid(-row=>$row++, -column=>0, -sticky=> "w");
    $FrTop->Label(-text => 'use dbi proxy:'
                 )->grid(-row=>$row++, -column=>0, -sticky=> "w");
    $FrTop->Label(-text => 'proxy server:'
                 )->grid(-row=>$row++, -column=>0, -sticky=> "w");
    $FrTop->Label(-text => 'proxy port:'
                 )->grid(-row=>$row++, -column=>0, -sticky=> "w");

    $row=0;

    my $e0= $FrTop->BrowseEntry(-textvariable => \$r_glbl->{db_driver},
                                -state=> 'readonly',
                         )->grid(-row=>$row++, -column=>1, -sticky=> "w");
    my $e1= $FrTop->Entry(-textvariable => \$r_glbl->{db_source},
                         )->grid(-row=>$row++, -column=>1, -sticky=> "w");
    my $e2= $FrTop->Entry(-textvariable => \$r_glbl->{user}
                         )->grid(-row=>$row++, -column=>1, -sticky=> "w");
    my $e3= $FrTop->Entry(-textvariable => \$r_glbl->{password},
                          -show => '*',
                         )->grid(-row=>$row++, -column=>1, -sticky=> "w");


    my $Button;
    my($e4,$e5);
    $Button = $FrTop->Checkbutton(
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
                       -state => 'disabled'
                      )->grid(-row=>$row++, -column=>1, -sticky=> "w");
    $e5= $FrTop->Entry(-textvariable => \$r_glbl->{proxy_port},
                       -state => 'disabled'
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
    $e3->bind('<Tab>', sub { tk_login_finish($r_glbl); } );

    $FrDn->Button(-text => 'Login',
                  %std_button_options,
                  -command => [\&tk_login_finish, $r_glbl ],
                   )->pack(-side=>'left', -anchor=>'nw');
    $FrDn->Button(-text => 'Quit',
                  %std_button_options,
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
    tk_set_busy($r_glbl,1);

    tk_progress($r_glbl,10);

    if (!$r_glbl->{use_proxy})
      { $r_glbl->{db_name} = "DBI:" . $r_glbl->{db_driver} . ":" .
                             $r_glbl->{db_source};
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
                                               $r_glbl->{password});
        if (!defined $db_handle)
          { tk_set_busy($r_glbl,0);
            tk_err_dialog($r_glbl->{main_menu_widget},
                          "opening of the database failed");

            tk_set_busy($r_glbl,0);
            tk_progress($r_glbl,0);
            $r_glbl->{login_widget}->raise();
            return;
          };
      };
    $r_glbl->{password}=~ s/./\*/g;

    $r_glbl->{dbh}= $db_handle;

    tk_progress($r_glbl,20);

    tk_set_busy($r_glbl,0);

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

    my $Top= MainWindow->new(-background=>$BG);
    $Top->protocol('WM_DELETE_WINDOW', [ \&tk_quit, $r_glbl ]);

#    $Top->bind('<Destroy>', sub { &tk_quit, $r_glbl ]);


#    $Top->minsize(400,400);
#    $Top->maxsize(800,800);

    $Top->title("$PrgTitle");
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
               -label=> 'open collection',
               -accelerator => 'Ctrl+o',
               -underline  => 0,
               -command=> [\&tk_load_collection,"",$r_glbl]
              );
    $Top->bind($Top,'<Control-s>'=> [\&tk_save_collection,$r_glbl]);
    $MnFile->add('command',
               -label=> 'save collection',
               -accelerator => 'Ctrl+s',
               -underline  => 0,
               -command=> [\&tk_save_collection,"",$r_glbl]
              );
    $MnFile->add('separator');
    $MnFile->add('command',
                    -label=> 'quit',
                    -accelerator => 'Ctrl+q',
                    -underline  => 0,
                    -command => [ \&tk_quit, $r_glbl ],
              );

    $Top->bind('<Control-q>' => [ \&tk_quit, $r_glbl ]);
    # configure Database-menu:
    $MnDb->add('command',
               -label=> 'Login',
               -underline  => 0,
               -command=> [\&tk_login, $r_glbl]
              );
    $MnDb->add('separator');

    my $autocommit_var=1;

    my $c_commit_i;
    my $c_rollback_i;

    $MnPref->add(
              'checkbutton',
               -label=> 'autocommit',
               -variable => \$autocommit_var,
               -command=>
                       sub {
                             my %h=(-state=> ($autocommit_var) ?
                                       "disabled" : "active");

                             $MnDb->entryconfigure($c_commit_i,%h);
                             $MnDb->entryconfigure($c_rollback_i,%h);

                             dbdrv::set_autocommit($r_glbl->{dbh},
                                                      $autocommit_var);
                           }
              );

    $MnDb->add('command',
               -label=> 'commit',
               -underline  => 0,
               -state=> 'disabled',
               -command=> sub { dbdrv::commit($r_glbl->{dbh}); }
              );
    $c_commit_i= $MnDb->index('end');
    $MnDb->add('command',
               -label=> 'rollback',
               -underline  => 0,
               -state=> 'disabled',
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
               -label=> 'show SQL commands',
               -underline  => 5,
               -command=> [\&tk_sql_commands, $r_glbl]
              );

    # configure Preferences-menu:
    # (see also above, $MnPref)
    $r_glbl->{primary_key_auto_generate}= 1;
    $MnPref->add(
                  'checkbutton',
                   -label=> 'auto-generate primary keys',
                   -variable => \$r_glbl->{primary_key_auto_generate},
                );

    # configure Help-menu:
    $MnHelp->add('command',
                 -label=> 'dump global datastructure',
                 -underline  => 5,
                 -command => [\&tk_dump_global, $r_glbl],
                );
    $MnHelp->add('command',
                 -label=> 'dump object dictionary',
                 -underline  => 5,
                 -command => [\&tk_object_dict_dump, $r_glbl],
                );
    $MnHelp->add('command',
                 -label=> 'dump reverse object dictionary',
                 -underline  => 5,
                 -command => [\&tk_r_object_dict_dump, $r_glbl],
                );
    $MnHelp->add('separator');
    $MnHelp->add('command',
                 -label=> 'About',
                 -underline  => 0,
                 -command=> [\&tk_about, $r_glbl]
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
    my $DlgEnt = $DlgTop->add("DlgEnt", -label=>"Short Exec");
    my $DlgTbl = $DlgTop->add("DlgTbl", -label=>"Tables");
    my $DlgVw  = $DlgTop->add("DlgVw", -label=>"Views");
    my $DlgSQL = $DlgTop->add("DlgSQL", -label=>"Sequel");
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

    $r_glbl->{MainWindow}->{table_browse_widget}=
         $DlgEnt->BrowseEntry(
                      -label=>'please enter the table-name:',
                      -labelPack=>=>[-side=>"left", -anchor=>"w"],
                      -width=>34,
                      -validate=> 'key',

                      #-textvariable=>$r_glbl->{browse_val},

                      -validatecommand=> [ \&tk_handle_table_browse_entry,
                                           $r_glbl]
                               )->pack( %dlg_def_labentry);

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
                            )->pack(
                                -padx=>2,-pady=>2,
                                -ipadx=>1,-ipady=>1,
                                -side=>"top",-anchor=>"e",
                            );

    my $DlgCollListbox = $DlgEnt->Scrolled(
            "Listbox",
            -label=>"Load your Collection :",
            -scrollbars=>"osoe",
            -width=>48,
            -selectmode=>"browse",
    )->packAdjust( %dlg_def_listbox,);
    $DlgEnt->Label( -justify=>"center",
                    -width=>10,
                    -height=>20,
                  )->pack(
                           -padx=>2,-pady=>2,
                           -ipadx=>1,-ipady=>1,
                           -anchor=>"se",
                           -expand=>0,
                         );

    my $DlgCollOk =
           $DlgEnt->Button( -state=>"disabled",
                            -text=>"load",
                            -underline=>1,
                            -justify=>"center",
                            -width=>20,
                            -command =>
                               sub { my $entry =
                                       $DlgCollListbox->get(
                                           $DlgCollListbox->curselection);
                                     tk_load_collection($Top, $r_glbl, $entry);
                                   },
                          )->pack(
                              -padx=>2,-pady=>2,
                              -ipadx=>1,-ipady=>1,
                              -anchor=>"se",
                          );
    my $DlgCollRefresh =
             $DlgEnt->Button( -state=>"normal",
                              -text=>"refresh dir",
                              -underline=>4,
                              -justify=>"center",
                              -width=>20,
                              -command =>
                               sub { $DlgCollListbox->delete(0, 'end');
                                     if (opendir (BROWSEDBCONFDIR, $PrgDir)) {
                                         while (my $collection =
                                                 readdir(BROWSEDBCONFDIR))
                                         {
                                           if ($collection =~ /\.col$/)
                                           {
                                             $DlgCollListbox->insert("end",
                                                 $PrgDir."/".$collection );
                                           }
                                         }
                                         closedir(BROWSEDBCONFDIR);
                                     }
                                   },
                            )->pack(
                                -padx=>2,-pady=>2,
                                -ipadx=>1,-ipady=>1,
                                -anchor=>"se",
                            );

        if (opendir (BROWSEDBCONFDIR, $PrgDir)) {
            while (my $collection = readdir(BROWSEDBCONFDIR))
              {
                if ($collection =~ /\.col$/)
                  {
                    $DlgCollListbox->insert("end",  $PrgDir."/".$collection );
                  }
              }
            closedir(BROWSEDBCONFDIR);
        }
        $DlgCollListbox->
            bind('<Button-1>' =>
                 sub { $DlgCollOk->configure(-state=>"active");
                     }
                );

        $DlgCollListbox->
            bind('<Control-r>' => sub
                 {  $DlgCollListbox->delete(0, 'end');
                    if (opendir (BROWSEDBCONFDIR, $PrgDir)) {
                        while (my $collection = readdir(BROWSEDBCONFDIR))
                        {
                            if ($collection =~ /\.col$/)
                            {
                                $DlgCollListbox->insert("end",
                                                 $PrgDir."/".$collection );
                            }
                        }
                        closedir(BROWSEDBCONFDIR);
                    }
                 }
               );
        $DlgCollListbox->
            bind('<Return>' =>
                 sub { my $entry =
                         $DlgCollListbox->get($DlgCollListbox->curselection);
                       tk_load_collection($Top, $r_glbl, $entry);
                     }
                );
        $DlgCollListbox->
            bind('<Double-1>' =>
                 sub { my $entry =
                         $DlgCollListbox->get($DlgCollListbox->curselection);
                       tk_load_collection($Top, $r_glbl, $entry);
                     }
                );

        # dialog tables
        my $DlgTblListbox = $DlgTbl->Scrolled(
                "Listbox",
                -scrollbars=>"oe",
                #-width=>34,
                -selectmode=>"browse",
                -width=>0
        )->pack( %dlg_def_listbox );


        my $DlgTblRowMin = $DlgTbl->LabEntry(
                -label=>'Lowest Rownumber :',
                -labelPack=>[-side=>"left", -anchor=>"w"],
                -textvariable=>$r_glbl->{varDBRowMin},
                -width=> 5,
        )->pack( %dlg_def_labentry,  );
        my $DlgTblRowMax = $DlgTbl->LabEntry(
                -label=>'Highest Rownumber :',
                -labelPack=>[-side=>"left", -anchor=>"w"],
                -textvariable=>$r_glbl->{varDBRowMin},
                -width=> 5,
        )->pack( %dlg_def_labentry );
        my $DlgTblRowId = $DlgTbl->Checkbutton(
                -text=>"Show RowId",
                -textvariable=>$r_glbl->{varDBRowId},
        )->pack( %dlg_def_labentry, );
        $DlgTbl->Label(
                -text=>"Where Clause :",
        )->pack( %dlg_def_labentry, );
        my $DlgTblWhere = $DlgTbl->Scrolled(
                "Text",
                -height=>5,
                -wrap=>"word",
                -width=>60
        )->pack( %dlg_def_labentry, );
        $DlgTbl->Label(
                -text=>"Order Clause :",
        )->pack( %dlg_def_labentry, );
        my $DlgTblOrder = $DlgTbl->Scrolled(
                "Text",
                -height=>5,
                -wrap=>"word",
                -width=>60
        )->pack( %dlg_def_labentry, );
        my $order;
        my $cond;
        my $DlgTblOk = $DlgTbl->Button(
                -state=>"disabled",
                -text=>"Show",
                -underline=>0,
                -justify=>"center",
                -command=>
                  sub { $cond= $DlgTblWhere->get('1.0','end');
                        $order= $DlgTblOrder->get('1.0','end');
                        $r_glbl->{new_table_name} =
                            $DlgTblListbox->get($DlgTblListbox->curselection);
                        tk_open_new_object($r_glbl, "table", $cond, $order);
                      }
        )->pack(%dlg_def_okbutton, );

        $DlgTblListbox->
            bind('<Button-1>' =>
                 sub { $DlgTblOk->configure(-state=>"active");
                     }
                );

        $DlgTblListbox->
            bind('<Return>' =>
                  sub { $cond= $DlgTblWhere->get('1.0','end');
                        $order= $DlgTblOrder->get('1.0','end');
                        $r_glbl->{new_table_name} =
                            $DlgTblListbox->get($DlgTblListbox->curselection);
                        tk_open_new_object($r_glbl, "table", $cond, $order);
                      }
                );
        $DlgTblListbox->
            bind('<Double-1>' =>
                  sub { $cond= $DlgTblWhere->get('1.0','end');
                        $order= $DlgTblOrder->get('1.0','end');
                        $r_glbl->{new_table_name} =
                            $DlgTblListbox->get($DlgTblListbox->curselection);
                        tk_open_new_object($r_glbl, "table", $cond, $order);
                      }
                );
        $r_glbl->{MainWindow}->{table_listbox_widget}=$DlgTblListbox;
#        $Top->update();

        # dialog view
        my $DlgVwListbox = $DlgVw->Scrolled(
                "Listbox",
                -scrollbars=>"oe",
                -width=>34,
                -selectmode=>"browse",
                -width=>0
        )->pack( %dlg_def_listbox, );
        $DlgVw->Label(
                -text=>"Where Clause :",
        )->pack( %dlg_def_labentry, );
        my $DlgVwWhere = $DlgVw->Scrolled(
                "Text",
                -height=>5,
                -wrap=>"word",
                -width=>60
        )->pack( %dlg_def_labentry, );
        $DlgVw->Label(
                -text=>"Order Clause :",
        )->pack( %dlg_def_labentry, );
        my $DlgVwOrder = $DlgVw->Scrolled(
                "Text",
                -height=>5,
                -wrap=>"word",
                -width=>60
        )->pack( %dlg_def_labentry, );
        my $DlgVwOk = $DlgVw->Button(
                -state=>"disabled",
                -text=>"Show",
                -underline=>0,
                -justify=>"center",
                -command=>
                  sub { $cond = $DlgVwWhere->get('1.0','end');
                        $order = $DlgVwOrder->get('1.0','end');
                        $r_glbl->{new_table_name} =
                            $DlgVwListbox->get($DlgVwListbox->curselection);
                        tk_open_new_object($r_glbl, "view", $cond, $order);
                      }
        )->pack( %dlg_def_okbutton, );

        $DlgVwListbox->
            bind('<Button-1>' =>
                 sub { $DlgVwOk->configure(-state=>"active");
                     }
                );

        $DlgVwListbox->
            bind('<Return>' =>
                  sub { $cond= $DlgVwWhere->get('1.0','end');
                        $order= $DlgVwOrder->get('1.0','end');
                        $r_glbl->{new_table_name} =
                            $DlgVwListbox->get($DlgVwListbox->curselection);
                        tk_open_new_object($r_glbl, "view", $cond, $order);
                      }
                );

        $DlgVwListbox->
            bind('<Double-1>' =>
                  sub { $cond= $DlgVwWhere->get('1.0','end');
                        $order= $DlgVwOrder->get('1.0','end');
                        $r_glbl->{new_table_name} =
                            $DlgVwListbox->get($DlgVwListbox->curselection);
                        tk_open_new_object($r_glbl, "view", $cond, $order);
                      }
                );

        $r_glbl->{MainWindow}->{view_listbox_widget}=$DlgVwListbox;

        # dialog sequel
        $DlgSQL->Label(
                -text=>"History :",
        )->pack( %dlg_def_labentry, );
        my $DlgSQLHistory = $DlgSQL->Scrolled(
                "ROText",
                -scrollbars=> "osoe",
                -height=> 10,
                -width=>80,
        )->packAdjust( -padx=>2, -pady=>2,
                 -ipadx=>1, -ipady=>1,
                 -fill=>"both",
                 -side=>"top",
                 -expand=> 1,
        );
        $DlgSQLHistory->tagConfigure("blue", -foreground => "blue");
        $DlgSQLHistory->tagConfigure("red", -foreground => "red");
        $DlgSQLHistory->tagConfigure("blue", -foreground => "green");
        tk_clear_undefkey($DlgSQLHistory);
        $r_glbl->{MainWindow}->{sql_history_widget}=$DlgSQLHistory;
        $DlgSQL->Label( -text=> "Statement :",
                      )->pack( %dlg_def_labentry, );
        my $DlgSQLCommand;
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
                -width=>80,
        )->pack( -anchor=> "s",
                 -padx=>2, -pady=>2,
                 -ipadx=>1, -ipady=>1,
                 -fill=>"both",
                 -side=>"bottom",
                 -expand=> 0, );

        tk_clear_undefkey($DlgSQLCommand);
        $DlgSQLCommand->
            bind('<Control-X>' =>
                 sub {  my $query_command;
                        $query_command = $DlgSQLCommand->get('1.0', 'end');
                        tk_execute_new_query($r_glbl, $query_command);
                     }
                );
        $DlgSQLCommand->
            bind('<Control-S>' =>
                 sub {  my $query_command;
                        $query_command = $DlgSQLCommand->get('1.0', 'end');
                        tk_execute_new_query($r_glbl, $query_command);
                     }
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
                        tk_execute_new_query($r_glbl, $query_command);
                     }
                );
        # read column-map definitions:
        my $r_c= load_column_maps($r_glbl,"$PrgDir/$column_map_file");
        if (defined $r_c)
          { $r_glbl->{column_map_definitions}= $r_c; };

        # dont remove these update, because of .toplevel
        # problems for destroy operations
        $Top->update();
        tk_login(\%global_data); # calls tk_main_window_finish
  }

sub tk_main_window_finish
  { my($r_glbl)= @_;

    tk_set_busy($r_glbl,1);

    my $infotext= $r_glbl->{user} . "@" . $r_glbl->{db_driver} . ':' .
                  $r_glbl->{db_source};

    if ($r_glbl->{use_proxy})
      { $infotext.= " (proxy $r_glbl->{proxy}:$r_glbl->{proxy_port})"; };

    $r_glbl->{MainWindow}->
             {login_info}->configure(-text =>$infotext);

    $r_glbl->{accessible_objects_views} =
             [ dbdrv::accessible_objects($r_glbl->{'dbh'},
                                         $r_glbl->{user},
                                         "VIEW",
                                         "PUBLIC,USER")
             ];

    tk_progress($r_glbl,40);

    my $view_listbox_widget= $r_glbl->{MainWindow}->{view_listbox_widget};
    $view_listbox_widget->delete(0, 'end');
    $view_listbox_widget->
             insert("end", @{ $r_glbl->{accessible_objects_views} } );

    $r_glbl->{accessible_objects_tables} =
             [ dbdrv::accessible_objects($r_glbl->{'dbh'},
                                         $r_glbl->{user},
                                         "TABLE",
                                         "PUBLIC,USER")
             ];

    tk_progress($r_glbl,60);

    my $table_listbox_widget= $r_glbl->{MainWindow}->{table_listbox_widget};
    $table_listbox_widget->delete(0, 'end');
    $table_listbox_widget->
             insert("end",  @{ $r_glbl->{accessible_objects_tables} } );
    $r_glbl->{accessible_objects_all} =
             [ dbdrv::accessible_objects($r_glbl->{'dbh'},
                                         $r_glbl->{user},
                                         "TABLE,VIEW",
                                         "PUBLIC,USER")
             ];

   tk_progress($r_glbl,80);

    $r_glbl->{MainWindow}->{table_browse_widget}->delete(0, 'end');
    $r_glbl->{MainWindow}->{table_browse_widget}->
             insert("end",  @{  $r_glbl->{accessible_objects_all} } );

    # opens or create a new history file
    $r_glbl->{filename_sql_history} =
                   $PrgDir . join("_","/history",
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
    tk_progress($r_glbl,100);
    tk_set_busy($r_glbl,0);

    $fh->flush();
    if ($fast_test)
      { $r_glbl->{new_table_name}= $fast_table;
            tk_open_new_object($r_glbl, 'table_or_view');
      };

    tk_progress($r_glbl,0);

  }

sub tk_quit
  {
    my($r_glbl, $widget)= @_;
    my $choice = "No";
    my $Top;

    if ((!$fast_test) && (defined $r_glbl))
      {
        $Top = $r_glbl->{main_menu_widget};
        my $DlgQuit = $Top->Dialog(
                    -title => 'Quit',
                    -text => 'Do you really want to quit?',
                    -default_button => 'No',
                    -buttons => ['No', 'Yes'],
                    );
        $choice = $DlgQuit->Show;
      }
    else
      {
        $choice = "Yes";
        warn "Quit without warning!";
      }
    if ($choice =~ /Yes/)
      {
        if (exists($r_glbl->{handle_sql_history}))
          {
            my $fh = $r_glbl->{handle_sql_history};
            $fh->flush();
            $fh->close();
          }
        if (defined $Top)
          {
            $Top->destroy();
          }
        exit(0);
      }
    else
      {
        return -1;
      }
  }

sub tk_about
 { my($r_glbl)= @_;

   my $Top= $r_glbl->{main_menu_widget}->Toplevel(-background=>$BG);
   $Top->title("About $PrgTitle");

   my @text= ("$PrgTitle $VERSION",
               "written by Goetz Pfeiffer",
               "updated and improved by Patrick Laux",
               "BESSY GmbH, Berlin, Adlershof",
               "Comments/Suggestions, please mail to:",
               "pfeiffer\@mail.bessy.de",
               "laux\@mail.bessy.de",
             );

   my $h= $#text+1;
   my $w=0;
   foreach my $l (@text)
     { $w=length($l) if ($w<length($l)); };

   foreach my $l (@text)
     { my $len= length($l);
       next if ($len>=$w);
       my $d= $w-$len;
       my $dl= int($d / 2);
       $l= (' ' x $dl) . $l . (' ' x ($d-$dl));
     };


   my $Text= $Top->Text(-width=> $w, -height=>$h);

   foreach my $l (@text)
     { $Text->insert('end',$l . "\n"); };

   $Text->pack(-fill=>'both',expand=>'y');
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

    tk_make_text_widget($r_glbl,"global datastructure dump",\$buffer);

  }

sub tk_object_dict_dump
 { my($r_glbl)= @_;

   my $r_buffer= dbdrv::dump_object_dict_s();

   tk_make_text_widget($r_glbl,"object dictionary dump",$r_buffer);

 }

sub tk_r_object_dict_dump
 { my($r_glbl)= @_;

   my $r_buffer= dbdrv::dump_r_object_dict_s();

   tk_make_text_widget($r_glbl,"reverse object dictionary dump",$r_buffer);
 }

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

   tk_set_busy($r_glbl,1);

    foreach my $table (keys %$r_all_tables)
      { my $r_tbh= $r_all_tables->{$table};
        cb_reload_db($r_glbl,$r_tbh);
      };

   tk_set_busy($r_glbl,0);

  }


sub tk_sql_commands
  { my($r_glbl)= @_;

    my $r_text= tk_make_text_widget($r_glbl,"SQL command trace");

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

    my $r_all_objects= $r_glbl->{accessible_objects_all};

    if (uc($proposed) ne $proposed)
      { $proposed= uc($proposed);
        $rewrite_value= 1;
      };

    # print join(",",$proposed, $chars_added,
    #            $value_before, $index, $action),"\n";

    my @matches= grep { $_ =~ /^$proposed/ } (@$r_all_objects);

    if (!@matches)
      { # the table doesnt exist
        $table_browse_widget->bell();
        return(0);
      };

    if ($#matches != $#{$r_glbl->{MainWindow}->{table_browse_objs}})
      { #  $r_glbl->{table_browse_widget}->configure(-choices=>\@matches);
        $table_browse_widget->delete(0,'end');
        $table_browse_widget->insert('end', @matches);
        $r_glbl->{MainWindow}->{table_browse_objs}= \@matches;
      };

    my $completion= same_start(\@matches);
    if ((defined $completion) && ($action==1)) # action=1: insert
      {
        if (length($completion)>length($proposed))
          { $proposed= $completion;
            $rewrite_value= 1;
          };
      };

    my @exact  = grep { $_ eq $proposed } (@$r_all_objects);
    my $table_browse_button= $r_glbl->{MainWindow}->{table_browse_button};
    if ($#exact<0)
      { $table_browse_button->configure(-state=>"disabled"); }
    else
      { $table_browse_button->configure(-state=>"active");

        $r_glbl->{new_table_name}= $proposed;
      };

    if ($rewrite_value)
      { my $Entry= $table_browse_widget->Subwidget('entry');
        my $r_var= ($Entry->configure('-textvariable'))[4];
        $$r_var= $proposed;
        $Entry->icursor('end');
        return(0);
      };

    return(1);
  }



sub tk_execute_new_query
# routine for executing free sequel
  { my($r_glbl, $sqlinput)= @_;
    my $fh = $r_glbl->{handle_sql_history};
    my $sql_history_widget= $r_glbl->{MainWindow}->{sql_history_widget};
    my @sqlcommands = dbdrv::split_sql_command($sqlinput);

    tk_progress($r_glbl, 0);
    my $size = $#sqlcommands;
    my $counter = 0;
    for (my $counter = 0; $counter < $size + 1; $counter++)
    {
        my $sqlquery = $sqlcommands[$counter];
        my ($sqlcommand, $sqlargs) = ($sqlquery =~ /^\s*(\w+)\b(.*)/);
        if (! defined ($sqlcommand))
        { tk_err_dialog($r_glbl->{main_menu_widget},
                        "Invalid SQL commandstring");
            return;
        }
        if (dbdrv::check_alias($sqlcommand))
        { $sqlargs=~ s/^\s+//;
            my @sqloptions = &parse_line('(\s+|\s*,\s*)', 0, $sqlargs);
            $sqlquery = dbdrv::get_alias($sqlcommand, @sqloptions);
            if ($sqlquery=~ /^ERROR/i)
            { tk_err_dialog($r_glbl->{main_menu_widget},
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
                { tk_err_dialog($r_glbl->{main_menu_widget},
                                $DBI::errstr
                                );
                }
            }
            else
            {
                    tk_err_dialog($r_glbl->{main_menu_widget},
                                $DBI::errstr
                                );
            }

        }
        tk_progress($r_glbl, ($counter/$size)*100);
        if (! defined ($r_glbl->{dbh}->err))
        {
            $sql_history_widget->insert('end', "\n");
            $sql_history_widget->insert('end', "$sqlquery;", "green");
            $sql_history_widget->insert('end', "\n");
            print $fh "\n".$sqlquery.";\n";

        }

    }
    tk_progress($r_glbl, 100);
    $sql_history_widget->see("end");
    $fh->flush();
    tk_progress($r_glbl, 0);
    return $size;
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

    if ($fast_test)
      { $fast_test=0;
        return;
      };
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
      { tk_err_dialog($r_glbl->{main_menu_widget},
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

    tk_set_busy($r_glbl,1);
    tk_progress($r_glbl,10);

    $r_tbh= make_table_hash($r_glbl,%options);

    if (!defined $r_tbh)
      { tk_set_busy($r_glbl,0);
        tk_progress($r_glbl,0);
        tk_err_dialog($r_glbl->{main_menu_widget},
                      "opening of the table failed!");
        return;
      };

    $r_all_tables->{$table_name}= $r_tbh;

    tk_progress($r_glbl,90);

    make_table_window($r_glbl,$r_tbh);

    # Note: calling tk_progress before tk_set_busy
    # creates a dubious warning:
    #    Use of uninitialized value in subroutine entry at
    #    ./browsedb.pl line 586.
    # which is the update() call in tk_progress

    tk_set_busy($r_glbl,0);

    #tk_progress($r_glbl,100);

    tk_progress($r_glbl,0);

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

    tk_progress($r_glbl,30);

    # the dbitable object:
    $table_hash{dbitable}   = get_dbitable($r_glbl,\%table_hash);

    tk_progress($r_glbl,50);

    if (!defined $table_hash{dbitable})
      {
        #warn "unable to open!!";
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

    table_hash_init_columns(\%table_hash);

    tk_progress($r_glbl,70);

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

    tk_progress($r_glbl,80);

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

    # get column-maps from the database:
    my $r_col_maps= $table_hash{col_maps};
    if (defined $r_col_maps)
      { my %maps= %{$table_hash{col_maps}};
        delete $table_hash{col_maps};

        foreach my $c (keys %maps)
          { set_column_map($r_glbl,\%table_hash,$maps{$c},$c);
          };
      };

    $r_col_maps= $r_glbl->{column_map_definitions};
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
# top_widget    => $top-widget
# table_widget  => $table_widget
# column_popup  => \%column_popup_data_hash
# default_popup => \%default_popup_data_hash
#
  { my($r_glbl,$r_tbh)= @_;

    # create a new top-window
    # my $Top= MainWindow->new(-background=>$BG);
    #my $Top= $r_glbl->{main_widget}->Toplevel(-background=>$BG);
    my $Top = cf_open_window($r_glbl->{main_menu_widget}, $r_glbl,
                             $r_tbh->{table_name},
                             $r_tbh->{geometry});

    delete $r_tbh->{geometry}; # no longer needed

    $r_tbh->{top_widget}= $Top;

    # set the title
    #$Top->title($r_tbh->{table_name});


    my $FrDn  = $Top->Frame(-background=>$BG
                           )->pack(-side=>'top' ,-fill=>'both',
                                  -expand=>'y');

    # the Menu-Bar is now created in a way that works on
    # windows to0. Note that this is a property of the
    # top widget, $MnTop MUST NOT be packed

    my $MnTop= $Top->Menu();
    $Top->configure(-menu => $MnTop );

    my $MnFile  = $MnTop->Menu();
    my $MnDbase = $MnTop->Menu();
    my $MnEdit  = $MnTop->Menu();
    my $MnRela  = $MnTop->Menu();
    my $MnView  = $MnTop->Menu();

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
                -label=> 'Edit',
                -underline   => 0,
                -menu=> $MnEdit
                );
    $MnTop->add('cascade',
                -label=> 'Relations',
                -underline   => 0,
                -menu=> $MnRela
                );
    $MnTop->add('cascade',
                -label=> 'View',
                -underline   => 0,
                -menu=> $MnView
                );

    # configure file-menu:
    my $MnFileOpen= $MnFile->Menu();
    my $MnFileSave= $MnFile->Menu();

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
    $MnDbase->add('command',
                  -label=> 'Store',
                  -underline   => 0,
                  -command => [\&cb_store_db, $r_tbh],
                );
    $MnDbase->add('command',
                  -label=> 'Reload',
                  -underline   => 0,
                  -command => [\&cb_reload_db, $r_glbl, $r_tbh],
                );


    # configure edit-menu:
    my $MnEditField= $MnEdit->Menu();
    my $MnEditLine = $MnEdit->Menu();


    $Top->bind($Top,'<Control-f>'=> [\&tk_find_line,$r_tbh]);
    $MnEdit->add('command',
                  -label=> 'find in column',
                  -accelerator => 'Ctrl+f',
                  -underline   => 8,
                  -command => [\&tk_find_line, "", $r_tbh],
                );
    $Top->bind($Top,'<Control-g>'=> [\&tk_find_line_next,
                                     $r_glbl, $r_tbh,'next']);
    $MnEdit->add('command',
                  -label=> 'find next column',
                  -accelerator => 'Ctrl+g',
                  -underline   => 5,
                  -command => [\&tk_find_line_next, "",
                               $r_glbl, $r_tbh,'next'],
                );
    $Top->bind($Top,'<Shift-Control-G>'=> [\&tk_find_line_next,
                                           $r_glbl, $r_tbh,'prev']);
    $MnEdit->add('command',
                  -label=> 'find prev column',
                  -accelerator => 'Shift+Ctrl+g',
                  -underline   => 5,
                  -command => [\&tk_find_line_next, "",
                               $r_glbl, $r_tbh,'next'],
                );
    $MnEdit->add('cascade',
                  -label=> 'field',
                  -underline   => 0,
                  -menu => $MnEditField,
                );
    $MnEdit->add('cascade',
                  -label=> 'line',
                  -underline   => 0,
                  -menu => $MnEditLine,
                );


    $MnEditLine->add('command',
                      -label=> 'insert',
                      -underline   => 0,
                      -command => [\&cb_insert_line, $r_glbl, $r_tbh],
                    );
    $MnEditLine->add('command',
                      -label=> 'delete',
                       -underline   => 0,
                      -command => [\&tk_delete_line_dialog, $r_tbh],
                    );
    $MnEditLine->add('command',
                      -label=> 'copy',
                      -underline   => 0,
                      -command => [\&cb_copy_paste_line,
                                   $r_glbl, $r_tbh, 'copy'],
                    );
    $MnEditLine->add('command',
                      -label=> 'paste',
                      -underline   => 0,
                      -command => [\&cb_copy_paste_line,
                                   $r_glbl, $r_tbh, 'paste'],
                    );

    $MnEditField->add('command',
                       -label=> 'enter value',
                       -underline   => 0,
                       -command => [\&tk_field_edit, $r_tbh],
                     );

    $MnEditField->add('command',
                      -label=> 'copy',
                      -underline   => 0,
                      -command => [\&cb_copy_paste_field,
                                   $r_glbl, $r_tbh, 'copy'],
                     );
    $MnEditField->add('command',
                       -label=> 'paste',
                       -underline   => 0,
                       -command => [\&cb_copy_paste_field,
                                    $r_glbl, $r_tbh, 'paste'],
                     );


    # configure relations-menu:
    if ($r_tbh->{table_type} eq 'table')
      { $MnRela->add('command',
                      -label=> 'dependend tables',
                      -underline   => 10,
                      -command => [\&tk_dependency_dialog, $r_glbl, $r_tbh],
                    );
      };

    if ($r_tbh->{table_type} ne 'sql')
      {
        $MnRela->add('command',
                      -label=> 'dependend views',
                      -underline   => 10,
                      -command => [\&tk_dependend_views_dialog, $r_glbl, $r_tbh],
                    );
      };

    if ($r_tbh->{table_type} eq 'table')
      { $MnRela->add('command',
                      -label=> 'referenced tables',
                      -underline   => 0,
                      -command => [\&tk_references_dialog, $r_glbl, $r_tbh],
                    );
      };
    if ($r_tbh->{table_type} eq 'view')
      { $MnRela->add('command',
                      -label=> 'referenced objects',
                      -underline   => 11,
                      -command => [\&tk_view_dependency_dialog, $r_glbl, $r_tbh],
                    );
      };

    if ($r_tbh->{table_type} eq 'table')
      { $MnRela->add('command',
                      -label=> 'add column map to file',
                      -underline   => 0,
                      -command =>
                        sub { add_to_column_maps($r_glbl,$r_tbh,
                                                 "$PrgDir/$column_map_file");
                            }
                    );
      };

    $MnRela->add('command',
                  -label=> 'add scroll-relation',
                  -underline   => 0,
                  -command => [\&tk_add_relation_dialog, $r_glbl, $r_tbh],
                );

    $MnRela->add('command',
                  -label=> 'tk_show_scroll_relations',
                  -underline   => 0,
                  -command => [\&tk_show_scroll_relations, $r_glbl, $r_tbh],
                );

    if ($r_tbh->{resident_there})
      { $MnRela->add('command',
                     -label=> 'select value',
                     -underline   => 0,
                     -command => [\&cb_select, $r_glbl, $r_tbh],
                    );
      }
    else
      {
        # warn "NO resident_key in table $r_tbh->{table_name} !!!";
      };


    # configure view-menu:
    # create the sub-menue:

    $MnView->add('command',
                  -label=> 'sort rows',
                  -underline   => 0,
                  -command=> [\&tk_sort_menu, $r_glbl, $r_tbh]
                );
    my $MnViewHCol = $MnView->Menu();
    $MnView->add('cascade',
                  -label=> 'hide/unhide columns',
                  -underline   => 0,
                  -menu => $MnViewHCol
                );
    $MnView->add('command',
                  -label=> 'info',
                  -underline   => 0,
                  -command => [\&tk_table_info, $r_glbl, $r_tbh],
                );
    $MnView->add('command',
                  -label=> 'Dump Object',
                  -underline   => 0,
                  -command => [\&tk_table_dump, $r_glbl, $r_tbh],
                );
    $MnView->add('command',
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

   # --------------------- table widget

    $FrDn->gridRowconfigure   (0,-weight=>1); # make it stretchable
    $FrDn->gridColumnconfigure(0,-weight=>1); # make it stretchable

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

    tk_bind_scroll_wheel($Table);

    $Table->configure(-yscrollcommand => ['set', $yscroll]);


    # mark changed cells by changing the foreground color to red
    $Table->tagConfigure('changed_cell', -foreground => 'red');

    # create a tag for the primary key column
    $Table->tagConfigure('pk_cell', -foreground => 'blue');
                         #-state => 'disabled');

    # create a tag for the foreign key column
    $Table->tagConfigure('fk_cell', -foreground => 'LimeGreen');
                        # -state => 'disabled');

    # create a tag for the manually added foreign key column
    $Table->tagConfigure('m_fk_cell', -foreground => 'ForestGreen');
                        # -state => 'disabled');


    table_window_tag_columns($r_tbh);

    # popup-menu for the columns in the tablematrix widget
    my $itemcnt=0;
    my $r_itemhash={};
    my %column_popup;

    my $MnColPopup= $Table->Menu(-type=> 'normal', -tearoff=>0);
    $r_itemhash->{'sort by column'}= $itemcnt++;
    $MnColPopup->add('command',
                     -label=> 'sort by column',
                     -command =>
                        sub { tk_resort_and_redisplay(
                                    $r_tbh,
                                    $column_popup{current_col});
                            }
                    );
    $r_itemhash->{'find in column'}= $itemcnt++;
    $MnColPopup->add('command',
                     -label=> 'find in column',
                     -command =>
                        sub { tk_find_line("",
                                    $r_tbh,
                                    $column_popup{current_col});
                            }
                    );
    $r_itemhash->{'open/raise foreign table'}= $itemcnt++;
    $MnColPopup->add('command',
                     -label=> 'open/raise foreign table',
                     -command =>
                        sub { cb_open_foreign_table(
                                     $r_glbl, $r_tbh,
                                     $column_popup{current_col});
                            }
                    );
    $r_itemhash->{'unhide all columns'}= $itemcnt++;
    $MnColPopup->add('command',
                     -label=> 'unhide all columns',
                     -command =>
                        sub { foreach my $c (@{$r_tbh->{column_list}})
                                { $r_tbh->{displayed_cols}->{$c}=1; };
                              cb_set_visible_columns($r_glbl, $r_tbh);
                            }
                    );
    $r_itemhash->{'hide column'}= $itemcnt++;
    $MnColPopup->add('command',
                     -label=> 'hide column',
                     -command =>
                        sub { my $c= $column_popup{current_col};
                              $r_tbh->{displayed_cols}->{$c}=0;
                              cb_set_visible_columns($r_glbl, $r_tbh);
                            }
                    );

    my $MnColMap = $MnColPopup->Menu(-tearoff=>0);
    $r_itemhash->{'column map'}= $itemcnt++;
    $MnColPopup->add('cascade',
                     -label=> 'column map',
                     -menu => $MnColMap
                    );

    $MnColMap->add('command',
                   -label=> 'define',
                   -command =>
                        sub { tk_define_col_map($r_glbl, $r_tbh,
                                                 $column_popup{current_col}
                                                );
                              tk_rewrite_active_cell($r_tbh);
                            }
                   );
    $MnColMap->add('command',
                   -label=> 'toggle map usage',
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
                                };
                            }
                  );

    $column_popup{popup_items} = $itemcnt;
    $column_popup{popup_item_h}= $r_itemhash;

    $column_popup{popup_disable_lists}=
                 { default        => ['open/raise foreign table'],
                 };

    $column_popup{popup_enable_lists} =
                 { foreign_key => ['open/raise foreign table'] };


    $r_tbh->{column_popup}= \%column_popup;
    $column_popup{popup_widget}= $MnColPopup;

    # popup-menu for the tablematrix widget:
    $itemcnt=0;
    $r_itemhash={};
    my $MnPopup= $Table->Menu(-type=> 'normal', -tearoff=>0);
    $r_itemhash->{edit}= $itemcnt++;
    $MnPopup->add('command',
                   -label=> 'edit',
                   -command => [\&tk_field_edit, $r_tbh],
                 );


    $r_itemhash->{'new value from list'}= $itemcnt++;
    $MnPopup->add('command',
                   -label=> 'new value from list',
                   -command => [\&tk_fk_select_dialog, $r_glbl, $r_tbh],
                 );

    $r_itemhash->{'edit all in selection'}= $itemcnt++;
    $MnPopup->add('command',
                   -label=> 'edit all in selection',
                   -command => [\&tk_field_edit, $r_tbh, 'selected'],
                 );
    $r_itemhash->{copy}= $itemcnt++;
    $MnPopup->add('command',
                  -label=> 'copy',
                  -command => [\&cb_copy_paste_field,
                               $r_glbl, $r_tbh, 'copy'],
                 );
    $r_itemhash->{paste}= $itemcnt++;
    $MnPopup->add('command',
                   -label=> 'paste',
                   -command => [\&cb_copy_paste_field,
                                $r_glbl, $r_tbh, 'paste'],
                 );
    $r_itemhash->{'find in column'}= $itemcnt++;
    $MnPopup->add('command',
                  -label=> 'find in column',
                  -command => [\&tk_find_line, "", $r_tbh],
                );
    $r_itemhash->{'select THIS as foreign key'}= $itemcnt++;
    $MnPopup->add('command',
                   -label=> 'select THIS as foreign key',
                   -command => [\&cb_select, $r_glbl, $r_tbh],
                 );
    $r_itemhash->{'open foreign table'}= $itemcnt++;
    $MnPopup->add('command',
                  -label=> 'open foreign table',
                  -command => [\&cb_open_foreign_table, $r_glbl, $r_tbh],
                );
    $r_itemhash->{'export selection'}= $itemcnt++;
    $MnPopup->add('command',
                  -label=> 'export selection',
                  -command => [\&cb_export_selection, $r_glbl, $r_tbh],
                );

# @@@@@@@@@@@@@@@@
    my %default_popup;
    $r_tbh->{default_popup}= \%default_popup;

    $default_popup{popup_widget}= $MnPopup;
    $default_popup{popup_items} = $itemcnt;
    $default_popup{popup_item_h}= $r_itemhash;

    $default_popup{popup_disable_lists}=
                  { default => ['open foreign table',
                                'select THIS as foreign key',
                                'new value from list'],
                    write_protected =>
                                ['edit','paste','edit all in selection']
                  };

    $default_popup{popup_enable_lists} =
                  { foreign_key => ['open foreign table'],
                    primary_key => ['select THIS as foreign key'],
                    column_map  => ['new value from list']
                  };

    if ($r_tbh->{resident_there})
      { $default_popup{popup_enable_lists}->{primary_key}=
                             ['select THIS as foreign key'];
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

  }

sub cf_open_window
  { my($parent_window, $r_glbl, $window_title, $geometry) = @_;
    my $NewTop = $parent_window->Toplevel(-background=>$BG);

    if (defined $geometry)
      { $NewTop->geometry($geometry); };

    $NewTop->configure(-title=>$window_title);

    tk_update_window_menu($r_glbl);

    $NewTop->eventAdd('<<Paste>>' => '<Control-v>');
    $NewTop->eventAdd('<<Copy>>' => '<Control-c>');
    $NewTop->eventAdd('<<Save>>' => '<Control-s>');
    $NewTop->eventAdd('<<Quit>>' => '<Control-q>');

    return $NewTop;
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

    #my $Top= MainWindow->new(-background=>$BG);
    my $Top= $r_glbl->{main_menu_widget}->Toplevel(-background=>$BG);

    $relation_hash{Top}= $Top;

    my @open_tables= grep {$_ ne  $myname}
                           (sort keys %{$r_glbl->{all_tables}});

    $Top->title("add relation in $r_tbh->{table_name}");

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
      { tk_err_dialog($Top, "local column not selected");
        return;
      };

    if (!defined$o_tab)
      { tk_err_dialog($Top, "other table not selected");
        return;
      };

    if (!defined$o_col)
      { tk_err_dialog($Top, "other column not selected");
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
  { my($r_tbh,$col_name)= @_;

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
      { tk_err_dialog($parent_widget,
                      "there are no foreign keys in this table");
        return;
      };

    if (!keys %$fkh) # no foreign keys defined
      { tk_err_dialog($parent_widget,
                      "there are no foreign keys in this table");
        return;
      };


    #my $Top= MainWindow->new(-background=>$BG);
    my $Top= $r_glbl->{main_menu_widget}->Toplevel(-background=>$BG);

    $Top->title("foreign keys in $r_tbh->{table_name}");

    my $FrTop = $Top->Frame(-borderwidth=>2,-relief=>'raised',
                           -background=>$BG
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
      { tk_err_dialog($Top, "no table selected");
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

    tk_set_busy($r_glbl,1);
    my $r_resident_keys= $r_tbh->{dbitable}->resident_keys();
    tk_set_busy($r_glbl,0);
    if (!defined $r_resident_keys)
      { tk_err_dialog($parent_widget,
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

    tk_object_dialog($r_glbl,$r_tbh,
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

    tk_set_busy($r_glbl,1);
    my $dbh= $r_glbl->{dbh};

    my ($object_name, $object_owner)=
          dbdrv::real_name($dbh, $r_glbl->{user},$r_tbh->{table_name});

    my @dependents=
          dbdrv::object_dependencies($dbh,$object_name,$object_owner);

    tk_set_busy($r_glbl,0);

    # filter-out views
    if (@dependents)
      { @dependents= grep { $_->[2] eq 'VIEW' } @dependents; };

    if (!@dependents)
      { tk_err_dialog($parent_widget,
                      "no view depends on this object");
        return;
      };

    my @objects= map{ dbdrv::canonify_name($r_glbl->{dbh},$r_glbl->{user},
                                           $_->[1], $_->[0]) } @dependents;
    @objects= sort @objects;

    tk_object_dialog($r_glbl,$r_tbh,
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

    tk_set_busy($r_glbl,1);
    my $dbh= $r_glbl->{dbh};

    my ($object_name, $object_owner)=
          dbdrv::real_name($dbh, $r_glbl->{user},$r_tbh->{table_name});

    my @referenced=
          dbdrv::object_references($dbh,$object_name,$object_owner);

    tk_set_busy($r_glbl,0);

    if (!@referenced)
      { tk_err_dialog($parent_widget,
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

    tk_object_dialog($r_glbl,$r_tbh,
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
  { my($widget, $r_tbh, $given_colname)= @_;

    my $TableWidget= $r_tbh->{table_widget};

    my %col_search_data;

    $r_tbh->{col_search_data}= \%col_search_data;

    # get row-column of the active cell in the current table
    my($row,$col)= split(",",$TableWidget->index('active'));
    my($pk,$colname)= rowcol2pkcolname($r_tbh,$row,$col);

    if (defined $given_colname)
      { $colname= $given_colname; };

    $col_search_data{colname}= $colname;

    # my $Top= MainWindow->new(-background=>$BG);
    my $Top= $TableWidget->Toplevel(-background=>$BG);

    my $title= "$r_tbh->{table_name}: Find $colname";
    $Top->title($title);

    my $FrTop = $Top->Frame(-borderwidth=>2,-relief=>'raised',
                           -background=>$BG
                           )->pack(-side=>'top' ,-fill=>'x',
                                  -expand=>'y');

    my $entry=
       $FrTop->Entry(-textvariable => \$col_search_data{string},
                     -width=>20
                    )->pack(-side=>'left',-fill=>'x',-expand=>'y');
    $entry->focus();

    $Top->bind('<Return>',
            sub {  my $row= find_next_col($r_tbh,
                                          string=>\$col_search_data{string},
                                          colname=>$colname,
                                          use_colmap=>1,
                                          from=>'current',
                                          direction=>'down');

                   if (!defined $row)
                     { tk_err_dialog($Top,
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
      { tk_err_dialog($r_glbl->{main_menu_widget},
                      "no search string specified");
        return;
      };

    my $colname= $r_col_search_data->{colname};

    my $row= find_next_col($r_tbh,
                           string=> $r_col_search_data->{string},
                           colname=>$colname,
                           use_colmap=>1,
                           from=>'current',
                           direction=> ($dir eq 'next') ? 'down' : 'up');

    if (!defined $row)
      { tk_err_dialog($r_glbl->{main_menu_widget},
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
  { my($r_tbh, $mode)= @_;

    if (!defined $mode)
      { $mode= 'active'; };

    my $TableWidget= $r_tbh->{table_widget};

#my($wi,$h,$x,$y)= split(/[x\+\-]/,$TableWidget->geometry());
#warn join("|",$wi,$h,$x,$y),"\n";

    my @cells;
    if ($mode eq 'active')
      { $cells[0]= $TableWidget->index('active'); }
    else
      { @cells=  $TableWidget->curselection(); };

    # get row-column of the active cell in the current table
    my($row,$col)= split(",",$cells[0]);
    my($pk,$colname)= rowcol2pkcolname($r_tbh,$row,$col);


    # my $Top= MainWindow->new(-background=>$BG);
    my $Top= $TableWidget->Toplevel(-background=>$BG);
    #$Top->Popup(-popover    => 'cursor');

    #my $title= "$r_tbh->{table_name}: Edit $colname";
    $Top->title("$r_tbh->{table_name}");

    my $FrTop = $Top->Frame(-borderwidth=>2,-relief=>'raised',
                           -background=>$BG
                           )->pack(-side=>'top' ,-fill=>'x',
                                  -expand=>'y');
    my $FrDn  = $Top->Frame(-background=>$BG
                           )->pack(-side=>'top' ,-fill=>'y',
                                  -expand=>'y'
                                  );

    if ($mode eq 'active')
      { $FrTop->Label(-text=>"$colname: ")->pack(-side=>'left'); };

    $r_tbh->{edit_cells}= \@cells;

    # edit_cell is a temporary variable
    # 1: use column-maps
    $r_tbh->{edit_cell}= put_get_val_direct($r_tbh,1,$pk,$colname);
    my $w;

    if (defined $r_tbh->{edit_cell})
      { $w= length($r_tbh->{edit_cell}); };

    $w=20 if ($w<20);

    my $Entry= $FrTop->Entry(-textvariable => \$r_tbh->{edit_cell},
                             -width=>$w
                            )->pack(-side=>'left',-fill=>'x',-expand=>'y');

    $FrDn->Button(-text => 'accept',
                  %std_button_options,
                  -command => sub { foreach my $c (@{$r_tbh->{edit_cells}})
                                      { $TableWidget->set(
                                                       $c,
                                                       $r_tbh->{edit_cell});
                                      };
                                   delete $r_tbh->{edit_cell};
                                   delete $r_tbh->{edit_cells};
                                   $Top->destroy;
                                  }
                 )->pack(-side=>'left', -fill=>'y');


    $FrDn->Button(-text => 'abort',
                 %std_button_options,
                 -command => sub { delete $r_tbh->{edit_cell};
                                   delete $r_tbh->{edit_cells};
                                   $Top->destroy;
                                  }
                 )->pack(-side=>'left', -fill=>'y');

    #$Top->Popup(-popover    => 'cursor');

    $Top->bind('<Destroy>',
               sub { delete $r_tbh->{edit_cell};
                     delete $r_tbh->{edit_cells};
                   }
              );


    $Entry->bind('<Return>',
                 sub { foreach my $c (@{$r_tbh->{edit_cells}})
                          { $TableWidget->set(
                                           $c,
                                           $r_tbh->{edit_cell});
                          };
                       delete $r_tbh->{edit_cell};
                       delete $r_tbh->{edit_cells};
                       $Top->destroy;
                     }
                );

    # let the window appear near the mouse-cursor:
    $Top->Popup(-popover    => 'cursor');

  }

# file dialog:
#_______________________________________________________

sub tk_save_to_file
# note: $widget is not really needed, it's just here
# since  this function can be called from via <bind>
  { my($widget,$r_tbh)= @_;

    # warn "save to file";

    my $file= tk_simple_file_menu(widget=> $r_tbh->{top_widget},
                                  type=> 'save',
                                  extension=>'.dbt',
                                  #defaultdir=>$PrgDir,
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
  }

sub tk_load_from_file
# note: $widget is not really needed, it's just here
# since  this function can be called from via <bind>
  { my($widget,$r_tbh)= @_;

    my $file= tk_simple_file_menu(widget=> $r_tbh->{top_widget},
                                  type=> 'load',
                                  extension=>'.dbt',
                                  #defaultdir=>$PrgDir,
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
        $Table->tagRow('changed_cell',$row);
      };

    foreach my $pk ($dbitable->primary_keys(filter=>'inserted'))
      { $row= pk2row($r_tbh,$pk);
        $r_chg->{$pk}= $row;
        $Table->tagRow('changed_cell',$row);
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

    my $file= tk_simple_file_menu(widget=> $r_tbh->{top_widget},
                                  type=> 'save',
                                  extension=>'.csv',
                                  #defaultdir=>$PrgDir,
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

    my $file= tk_simple_file_menu(widget=> $r_tbh->{top_widget},
                                  type=> 'load',
                                  extension=>'.csv',
                                  #defaultdir=>$PrgDir,
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
        $Table->tagRow('changed_cell',$row);
      };

    foreach my $pk ($dbitable->primary_keys(filter=>'inserted'))
      { $row= pk2row($r_tbh,$pk);
        $r_chg->{$pk}= $row;
        $Table->tagRow('changed_cell',$row);
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

   tk_set_busy($r_glbl,1);

   my $r_text= tk_make_text_widget($r_glbl,"$name:Object-Info");

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
     { ($object_name, $object_owner)=
          dbdrv::real_name($dbh,$r_glbl->{user},$r_tbh->{table_name});

       my @dependents=
              dbdrv::object_dependencies($dbh,$object_name,$object_owner);
       if (@dependents)
         { $text->insert('end',"\ndependents:\n");
           foreach my $r_s (@dependents)
             { my $st= sprintf("%s.%s (%s)\n",@$r_s);
               $text->insert('end',$st);
             };
         };

       my @referenced=
             dbdrv::object_references($dbh,$object_name,$object_owner);
       if (@referenced)
         { $text->insert('end',"\nreferenced objects:\n");
           foreach my $r_s (@referenced)
             { my $st= sprintf("%s.%s (%s)\n",@$r_s);
               $text->insert('end',$st);
             };
         };

       my @constraints_triggers=
             dbdrv::object_addicts($dbh,$object_name,$object_owner);
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
#warn "$object_name, $object_owner";
       my $sql= dbdrv::read_viewtext($dbh,$object_name, $object_owner);

#warn $sql;

       $str= "\nSQL command of the view:\n" . $sql. "\n";
       $text->insert('end',$str);
     };

   $text->pack(-fill=>'both',expand=>'y');

   tk_set_busy($r_glbl,0);

 }

# dump routines:
#_______________________________________________________


sub tk_table_dump
 { my($r_glbl, $r_tbh)= @_;
   my $name= $r_tbh->{table_name};

   my $buffer;
   rdump(\$buffer,$r_tbh,0);
   tk_make_text_widget($r_glbl,"$name:Object-Dump",\$buffer);

 }

sub tk_dbitable_dump
 { my($r_glbl, $r_tbh)= @_;
   my $name= $r_tbh->{table_name};
   my $dbitable= $r_tbh->{dbitable};

   my $r_buffer= $dbitable->dump_s();

   tk_make_text_widget($r_glbl,"$name:DBITable-Dump",$r_buffer);

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

    my $file= tk_simple_file_menu(widget=> $r_tbh->{top_widget},
                                  type=> 'save',
                                  extension=>'.csv',
                                  #defaultdir=>$PrgDir,
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
       tk_err_dialog($Table,
                     "the selected column \"$colname\" is no " .
                     "foreign key in any of the currently displayed " .
                     "tables");
       return;
     };

   my @res_table_list= keys %$r_residents;

   if ($#res_table_list>0)
     {
# warn "SELECT WARN2\n";
       tk_err_dialog($Table,
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
           tk_err_dialog($Table,
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
                # warn "no writing allowed on this column
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

        $r_tbh->{dbitable}->value($pk,$colname,$putval);
        $r_tbh->{changed_cells}->{"$pk;$colname"}= "$row,$col";
        $r_tbh->{table_widget}->tagCell('changed_cell',"$row,$col");
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
        $r_tbh->{dbitable}->value($pk,$column,$putval);
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
     { @pk_cols= @{$r_tbh->{pks}}; };

   if ($#pk_cols>0)
     { tk_err_dialog($r_tbh->{table_widget},
                     "this table has more than one " .
                     "primary key column. Direct inserting " .
                     "of an empty line is not possible here!"
                     );
       return;
     };

   if (!$r_glbl->{primary_key_auto_generate})
     { tk_simple_text_dialog($r_glbl,$r_tbh,
                             tag=> "primary_key_dialog",
                             title=> "enter a primary key",
                             text=> "enter a new primary key",
                             callback=> [\&cb_insert_line_check]
                            );
       return;
     };

   cb_insert_line_finish($r_glbl,$r_tbh,undef);

  }

sub cb_insert_line_check
  { my($r_glbl,$r_tbh,$pk)= @_;

    if (exists $r_tbh->{pk_hash}->{$pk})
      {
        tk_err_dialog($r_tbh->{table_widget},
                     "error: primary key \"$pk\" is already taken");
        return;
      };
    cb_insert_line_finish($r_glbl,$r_tbh,$pk);
  }

sub cb_insert_line_finish
 { my($r_glbl,$r_tbh,$pk)= @_;
   my @pk_cols;

   if (!$r_tbh->{no_pk_cols}) # if there are primary key columns at all
     { @pk_cols= @{$r_tbh->{pks}}; };

   if ($#pk_cols>0)
     { tk_err_dialog($r_tbh->{table_widget},
                     "this table has more than one " .
                     "primary key column. Direct inserting " .
                     "of an empty line is not possible here!"
                     );
       return;
     };


   my $dbitable= $r_tbh->{dbitable};

   my $r_col_hash= $r_tbh->{column_hash};
   my %h;
   foreach my $col (keys %$r_col_hash)
     { next if ($col eq $pk_cols[0]);
       $h{$col}="";
     };

   if (defined $pk)
     { $h{ $r_tbh->{pks}->[0] } = $pk; };

   # if the primary key is specified in add_line, it
   # will use that primary key and not a generated one
   my $new_pk= $dbitable->add_line(%h);

   my $Table= $r_tbh->{table_widget};

   # re-calc the number of rows, update the table- widget:
   # (there may be new lines inserted in the table)
   resize_table($r_tbh);

   my($row,$col)= pkcolname2rowcol($r_tbh,$new_pk,$pk_cols[0]);
   $Table->activate("$row,$col");
   $Table->see("$row,$col");

 }

# delete-line dialog:
#_______________________________________________________

sub tk_delete_line_dialog
  { my($r_tbh)= @_;

    my $Table= $r_tbh->{table_widget};

    # get row-column of the active cell in the current table
    my($row,$col)= split(",",$Table->index('active'));
    my($pk,$colname)= rowcol2pkcolname($r_tbh,$row,$col);

    # my $Top= MainWindow->new(-background=>$BG);
    my $Top= $Table->Toplevel(-background=>$BG);

    $Top->title($r_tbh->{table_name});

    my $FrTop = $Top->Frame(-borderwidth=>2,-relief=>'raised',
                           -background=>$BG
                           )->pack(-side=>'top' ,-fill=>'x',
                                  -expand=>'y');
    my $FrDn  = $Top->Frame(-background=>$BG
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
 { my($r_tbh)= @_;
   tk_remove_changed_cell_tag($r_tbh);

   $r_tbh->{dbitable}->store();

   # reload the table, it's safer to do this in case
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
 }

sub cb_reload_db
# global variables used: NONE
 { my($r_glbl, $r_tbh)= @_;

   my $Table= $r_tbh->{table_widget};

   tk_set_busy($r_glbl,1);

   tk_remove_changed_cell_tag($r_tbh);

   $r_tbh->{dbitable}->load();

   # re-calc the number of rows, update the table- widget:
   # (there may be new lines inserted in the table)
   resize_table($r_tbh);
   # ^^^ resize_table does also a re-draw of the table-widget

   # update the displayed content in the active cell:
   tk_rewrite_active_cell($r_tbh);

   tk_set_busy($r_glbl,0);

   # the following would also force a redraw
   # $Table->configure(-padx => ($Table->cget('-padx')) );
 }

# $Table->tag
# $Table->tagCell(tagName, ?)


# handle column-maps:
#_______________________________________________________

sub tk_define_col_map
# define a map for a cell
  { my($r_glbl,$r_tbh,$column_name)= @_;

    tk_simple_text_dialog($r_glbl,$r_tbh,
                          tag=> "col_map_sql_dialog",
                          title=> "define cell map",
                          text=> "enter a valid SQL command",
                          callback=> [\&tk_define_col_map_finish,
                                      $column_name]
                         );
  }

sub tk_define_col_map_finish
  { my($r_glbl,$r_tbh,$sql_command,$column_name)= @_;

    if (!set_column_map($r_glbl,$r_tbh,$sql_command,$column_name))
      { return; };

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

    tk_object_dialog($r_glbl,$r_tbh,
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

#    my @pks= $r_tbh->{dbitable}->find($colname,$value,
#                                     warn_not_pk=>1);


    my $row= find_next_col($r_tbh,
                           string=>$value,
                           colname=>$colname,
                           from=>'top',
                           direction=>'down',
                           use_colmap=> $use_colmap,
                           exact=>1);
#warn "search val $value, col $colname result $row";


#    if (!@pks)
#      { tk_err_dialog($r_tbh->{table_widget},
#                     "tk_activate_cell: table $r_tbh->{table_name}\n" .
#                     "col $colname, val \"$value\" not found");
#        return;
#      };
#    if (scalar @pks !=1 )
#      { tk_err_dialog($r_tbh->{table_widget},
#                     "tk_activate_cell: table $r_tbh->{table_name}\n" .
#                     "col $colname, val $value found more than once");
#        return;
#      };

    return if (!defined $row);

    my $col= colname2col($r_tbh,$colname);

    my $Table= $r_tbh->{table_widget};
    $Table->activate("$row,$col");


    #$Table->see("$row,$col");
    # somehow, yview works much more reliable
    # than see()

    $Table->yview($row-1);
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
        $Table_widget->tagCell('changed_cell',"$row,$col");
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

    my $Top= $r_glbl->{main_menu_widget}->Toplevel(-background=>$BG);
    $Top->title("sort $r_tbh->{table_name}");

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
                                        expand=>'y');


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
        $file= tk_simple_file_menu(widget=> $Top,
                                  type=> 'load',
                                  extension=>'.col',
                                  defaultdir=>$PrgDir,
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
  {
    my($widget,$r_glbl)= @_;
    local(*F);

    my $Top= $r_glbl->{main_menu_widget};


    my $file= tk_simple_file_menu(widget=> $Top,
                                  type=> 'save',
                                  extension=>'.col',
                                  defaultdir=>$PrgDir,
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

#    my $file= $PrgDir . join("_","/test",
#                            $r_glbl->{db_driver},
#                            $r_glbl->{db_source},
#                            $r_glbl->{user});

    open(F, ">$file") or die;
    print F Data::Dumper->Dump([\%save], [qw(*save)]);
    close(F);

  }


#=======================================================
# routines that create Windows and Dialogs in a generic way
#=======================================================

# get text input from a simple entry field:
#_______________________________________________________

sub tk_simple_text_dialog
# known options:
# title
# callback -> callback after something was selected
# text -> text at the bottom of the widget
# tag -> tag-name for the dialog data that
#        is stored in the table-handle
  { my($r_glbl,$r_tbh,%options)= @_;

    my $tag= $options{tag};

    die if (!defined $tag); # assertion

    my %h;

    my $Top= $r_glbl->{main_menu_widget}->Toplevel(-background=>$BG);
    $Top->title($options{title});

    my $entry=
       $Top->Entry(-textvariable => \$h{string},
                   -width=>20
                  )->pack(-side=>'top',-fill=>'x',-expand=>'y');

    $entry->focus();

    $Top->Label(-text => $options{text}
               )->pack(-side=>'top' ,-fill=>'y',
                      );


    $Top->bind('<Return>',[ \&tk_simple_text_dialog_finish, $r_glbl,$r_tbh,$tag ]);

    $Top->bind('<Destroy>',  sub {
                                   delete $r_tbh->{$tag};
                                 }
              );

    $h{top}     = $Top;
    $h{callback}= $options{callback};

    $r_tbh->{$tag}= \%h;

    # let the window appear near the mouse-cursor:
    $Top->Popup(-popover    => 'cursor');
  }

sub tk_simple_text_dialog_finish
  { my($widget,$r_glbl,$r_tbh,$tag)= @_;

    my $r_h = $r_tbh->{$tag};
    my $Top = $r_h->{top};

    my $str=  $r_h->{string};
    chomp($str);

    $Top->destroy;  # @@@@

    my @callback= @{$r_h->{callback}};

    delete $r_tbh->{$tag};

    if (@callback)
      { my $r_f= shift @callback;
        &$r_f($r_glbl,$r_tbh,$str,@callback);
      }
  }


# create a text-widget with a standard-menu:
#_______________________________________________________


sub tk_make_text_widget
  { my($r_glbl,$title,$r_content)= @_;

    my %text;

    # my $Top= MainWindow->new(-background=>$BG);
    my $Top= $r_glbl->{main_menu_widget}->Toplevel(-background=>$BG);

    $text{Top}= $Top;

    $Top->title("$title");

    my $text;

    # the Menu-Bar is now created in a way that works on
    # windows to0. Note that this is a property of the
    # top widget, $MnTop MUST NOT be packed

    my $MnTop= $Top->Menu();
    $Top->configure(-menu => $MnTop );

    my $MnFile   = $MnTop->Menu();
    my $MnSearch = $MnTop->Menu();
    $MnTop->add('cascade',
                -label=> 'File',
                -underline   => 0,
                -menu=> $MnFile
               );
    $MnTop->add('cascade',
                -label=> 'Search',
                -underline   => 0,
                -menu=> $MnSearch
               );

    # configure File-menu:
    $Top->bind($Top,'<Control-s>'=> [\&tk_text_save,$r_glbl,\%text]);
    $MnFile->add('command',
               -label=> 'save',
               -accelerator => 'Control-s',
               -underline   => 0,
               -command=>  [\&tk_text_save,"",$r_glbl,\%text]
              );

    # configure search-menu:
    $Top->bind($Top,'<Control-f>'=> [\&tk_text_search,$r_glbl,\%text]);
    $MnSearch->add('command',
                 -label=> 'find',
                 -accelerator => 'Control-f',
                 -underline   => 0,
                 -command=> [\&tk_text_search,"",$r_glbl,\%text]
              );


    $Top->bind($Top,'<Control-g>'=>
               [\&tk_text_search_next,$r_glbl,'next',\%text]);
    $MnSearch->add('command',
                 -label=> 'find next',
                 -accelerator => 'Control-g',
                 -command=> [\&tk_text_search_next,"",$r_glbl,'next',\%text]
              );

    $Top->bind($Top,'<Shift-Control-G>'=>
              [\&tk_text_search_next,$r_glbl,'prev',\%text]);
    $MnSearch->add('command',
                 -label=> 'find prev',
                 -accelerator => 'Shift-Control-G',
                 -command=> [\&tk_text_search_next,"",$r_glbl,'prev',\%text]
              );


    my $text_widget=  $Top->Scrolled('Text',
                                     -scrollbars=>"ose",
                                    );

    # ----------------------------------------------------
    # special handling for Control Keyboard bindings:
    # this is needed in order avoid that strange square chars
    # appear in the text-widget whenever control characters are
    # pressed:
    my $fr_delchar= sub{$text_widget->delete('insert - 1 char')};

    foreach my $key ('<Control-s>',
                     # '<Control-f>', not on Ctrl-F!!
                     '<Control-g>','<Shift-Control-G>')
      { $text_widget->bind($key,$fr_delchar); };
    # ----------------------------------------------------

    $text{text_widget}= $text_widget;

#    $text_widget->bind('<Control-s>'=> sub{ Tk->break(); } );
#    $text_widget->bind('<Control-f>'=> sub{ Tk->break(); });
#    $text_widget->bind('<Control-g>'=> sub{ Tk->break(); });
#    $text_widget->bind('<Shift-Control-G>'=> sub{ Tk->break(); });

    $text_widget->insert('end',$$r_content) if (defined $r_content);

    $text_widget->pack(-fill=>'both',expand=>'y');

    return(\%text);
  }


sub tk_text_search
# note: $widget is not really needed, it's just here
# since  this function can be called from via <bind>
  { my($widget, $r_glbl,$r_text)= @_;

    my $text= $r_text->{text_widget};

    my $Top= $r_text->{Top}->Toplevel(-background=>$BG);

    $r_text->{search_widget}= $Top;

    $Top->title("search");

    my $Entry= $Top->Entry(-textvariable => \$r_text->{search},
                           -width=>20
                          )->pack(-side=>'left',-fill=>'x',-expand=>'y');


    $Entry->bind('<Return>',
                 sub {
                       my $r= $text->search(-count=> \$r_text->{search_cnt},
                                            $r_text->{search},'1.0'
                                           );
                       if (!$r)
                          { my $s= $r_text->{search};
                           $r_text->{search_widget}->destroy;
                           delete $r_text->{search_widget};
                           delete $r_text->{search};
                           delete $r_text->{last_search};
                           tk_err_dialog($r_glbl->{main_menu_widget},
                                         "\"$s\" not found");
                         }
                       else
                         {
                           $r_text->{last_found}= $r;
                           $r_text->{last_search}= $r_text->{search};
                           $text->see($r);
                           $text->tagRemove('FOUNDTAG','1.0','end');
                           $text->tagAdd('FOUNDTAG',
                                         $r,
                                         $r . '+ ' . $r_text->{search_cnt} .
                                         ' chars');

                           $text->tagConfigure('FOUNDTAG',-foreground=>'red');
                           $r_text->{search_widget}->destroy;
                           delete $r_text->{search_widget};
                         };
                     }
                );

    $Top->bind('<Destroy>',
                 sub {
                       delete $r_text->{search_widget};
                       delete $r_text->{search};
                     }
                );

    $Entry->focus();

    $Top->Popup(-popover    => 'cursor');

  }

sub tk_text_search_next
# note: $widget is not really needed, it's just here
# since  this function can be called from via <bind>
  { my($widget, $r_glbl,$dir,$r_text)= @_;

    my $text= $r_text->{text_widget};

    if (!defined $r_text->{last_search})
      { tk_err_dialog($r_glbl->{main_menu_widget},
                      "no search string specified");
        return;
      }


    my @args= (-count, \$r_text->{search_cnt});
    my $from;
    if ($dir eq 'next')
      { $from= $r_text->{last_found} . '+ ' .
               $r_text->{search_cnt} . ' chars';
      }
    else
      { push @args, '-backwards';
        $from= $r_text->{last_found} . '- 1 chars';
      };

    my $r= $text->search(@args,
                         $r_text->{last_search},
                         $from
                        );
    if (!$r)
      { tk_err_dialog($r_glbl->{main_menu_widget},
                      "not found");
      };


    $r_text->{last_found}= $r;
    $text->see($r);
    $text->tagRemove('FOUNDTAG','1.0','end');
    $text->tagAdd('FOUNDTAG',
                  $r,
                  $r . '+ ' . $r_text->{search_cnt} .
                  ' chars'
                 );

    $text->tagConfigure('FOUNDTAG',-foreground=>'red');

  }

sub tk_text_save
# note: $widget is not really needed, it's just here
# since  this function can be called from via <bind>
  { my($widget,$r_glbl,$r_text)= @_;


    my $file= tk_simple_file_menu(widget=> $r_text->{Top},
                                  type=> 'save',
                                  extension=>'.txt',
                                  defaultdir=>$PrgDir,
                                  title=>'save text',
                                  extension_description=>
                                              'ascii text files');

    # warn "filename: $file ";
    return if (!defined $file);

    my $text= $r_text->{text_widget}->get('1.0','end');
    local(*F);
    if (!open(F, ">$file"))
      { tk_err_dialog($r_glbl->{main_menu_widget},
                      "unable to open $file for writing");
        return;
      };
    print F $text;
    if (!close(F))
      { tk_err_dialog($r_glbl->{main_menu_widget},
                      "error while closing $file");
        return;
      };
  }



# a simple file menu for loading or storing of a file:
#_______________________________________________________

sub tk_simple_file_menu
# options:
# type: 'load' or 'save'
# extension: extension
# defaultdir: dir
# title: title
# extension_description
# widget: parent widget
  { my(%options)= @_;

    my $ext= $options{extension};
    die if (!defined $ext); #assertion
    $ext=~ s/\.//;

    my $type= $options{type};
    die if (!defined $type); #assertion
    die if (($type ne 'load') && ($type ne 'save'));

    my $widget= $options{widget};
    die if (!defined $widget);

    my %args;

    $args{-filetypes}= [ [$options{extension_description},"*.$ext",undef],
                         ['All Files', '*',undef] ];

    if (exists $options{defaultdir})
      { $args{-initialdir}= $options{defaultdir}; };

    if (exists $options{title})
      { $args{-title}= $options{title}; };

    $args{-defaultextension}= ".$ext";

    if ($type eq 'load')
      { return( $widget->getOpenFile(%args)); }
    else
      { my $file= $widget->getSaveFile(%args);
        return if (!defined $file);
        if ($file!~ /\.\w+$/)
          { $file.= ".$ext"; };
        return($file);
      }
  }


# object-dialog, select an element in a list:
#_______________________________________________________


sub tk_object_dialog
# known options:
# title
# items -> reference to a list of items
# text -> text at the bottom of the widget
# callback -> callback after something was selected
# tag -> tag-name for the dialog data that is stored in the table-handle
  { my($r_glbl,$r_tbh,%options)= @_;

    my $tag= $options{tag};

    die if (!defined $tag); # assertion

    my %h;

    my $Top= $r_glbl->{main_menu_widget}->Toplevel(-background=>$BG);
    $Top->title($options{title});

    my $FrTop = $Top->Frame(-borderwidth=>2,
                           -background=>$BG
                           )->pack(-side=>'top' ,-fill=>'both',
                                  -expand=>'y');

    my $itemno=0;
    if ($#{$options{items}} > 20)
      { $itemno=20; };

    my $Listbox= $FrTop->Scrolled( 'Listbox',
                                   -scrollbars=>"oe",
                                   -selectmode => 'single',
                                   -width=>0,
                                   -height=>$itemno);

    $Listbox->insert('end', @{$options{items}});
    $Listbox->pack(-fill=>'both',-expand=>'y');

    $Top->bind('<Return>',
               [\&tk_object_dialog_finish, $r_glbl, $r_tbh, $tag]);

    $Listbox->bind('<Double-1>',
                   [\&tk_object_dialog_finish, $r_glbl, $r_tbh, $tag]);

    $Top->bind('<Destroy>', sub {
                             delete $r_tbh->{$tag};
                                }
              );

    $FrTop->Label(-text => $options{text}
                 )->pack(-side=>'left' ,-fill=>'y',
                        );

    $h{top}     = $Top;
    $h{listbox} = $Listbox;
    $h{callback}= $options{callback};

    $r_tbh->{$tag}= \%h;

    # let the window appear near the mouse-cursor:
    $Top->Popup(-popover    => 'cursor');
  }

sub tk_object_dialog_finish
# note: $widget is not really needed, it's just here
# since  this function can be called from via <bind>
  { my($widget,$r_glbl,$r_tbh,$tag)= @_;

    my $r_h= $r_tbh->{$tag};

    my $Top     = $r_h->{top};
    my $Listbox = $r_h->{listbox};

    my @selection= $Listbox->curselection();

    if (!@selection)
      { tk_err_dialog($Top, "nothing selected");
        return;
      };

    my $obj= $Listbox->get($selection[0]);
    $Top->destroy;  # @@@@

    my @callback= @{$r_h->{callback}};

    delete $r_tbh->{$tag};

    if (@callback)
      { my $r_f= shift @callback;
        &$r_f($r_glbl,$r_tbh,$obj,@callback);
      }
  }

#=======================================================
# small Tk utilies:
#=======================================================

# delete last inserted char in text widget:
#_______________________________________________________

sub tk_delete_char
  { $_[0]->delete('insert - 1 char'); }

# remove useless key-bindings in text-widget:
#_______________________________________________________

sub tk_clear_undefkey
  {
    my @keys= ('<Control-1>', '<Control-2>', '<Control-3>', '<Control-4>',
               '<Control-5>', '<Control-6>', '<Control-7>', '<Control-8>',
               '<Control-9>', '<Control-0>', '<Control-q>', '<Control-r>',
               '<Control-u>', '<Control-g>', '<Control-s>', '<Control-l>',
               '<Control-m>');

    my ($this_widget) = @_;
    if (defined ($this_widget))
      {
        foreach my $k (@keys)
          { $this_widget->bind($k => [\&tk_delete_char]); };
      }
  }

# scroll-wheel:
#_______________________________________________________

sub tk_bind_scroll_wheel
  { my($widget)= @_;

    $widget->bind('<4>',['yview','scroll',-5,'units']);
    $widget->bind('<5>',['yview','scroll', 5,'units']);

    $widget->bind('<Shift-4>',['yview','scroll',-1,'units']);
    $widget->bind('<Shift-5>',['yview','scroll', 1,'units']);

    $widget->bind('<Control-4>',['yview','scroll',-1,'pages']);
    $widget->bind('<Control-5>',['yview','scroll', 1,'pages']);

  }


# sand-clock:
#_______________________________________________________

sub tk_set_busy
  { my($r_glbl,$val)= @_;

    if (!$val)
      { if (--$r_glbl->{busy_count} <=0)
          { $r_glbl->{busy_count}=0;
            $r_glbl->{main_menu_widget}->Unbusy(-recurse => 1);
          };
        return;
      };

    if ($r_glbl->{busy_count}++ <=0)
      { $r_glbl->{main_menu_widget}->Busy(-recurse => 1);

        if ($os ne "MsWin32")
          { $r_glbl->{main_menu_widget}->grabRelease(); }
        else
          { $r_glbl->{main_menu_widget}->focus(); };
      };
  }

# progress-bar:
#_______________________________________________________

sub tk_progress
  { my($r_glbl,$val)= @_;

#my ($p,$f,$l)= caller; print "**** $p $f $l\n";
#my $x= $r_glbl->{main_menu_widget};
#print "main-menu-widget: $x\n";
    my $progress_widget= $r_glbl->{MainWindow}->{progress_widget};
    return if (!defined $progress_widget);

    $progress_widget->value($val);

    #$r_glbl->{progress_widget}->update();
    $r_glbl->{main_menu_widget}->update();
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

    #$Top->afterIdle([\&tkdie2,$Top,$message]);
    tkdie2($Top,$message);
  }

sub tkdie2
  { my($parent_widget,$message)= @_;

    my $dialog= $parent_widget->Dialog(
                                       -title=>'Fatal Error',
                                       -text=> $message
                                      );
    $dialog->Show();
    exit(0);
  }

sub tk_err_dialog
  { my($parent,$message)= @_;

    my $dialog= $parent->Dialog(
                                 -title=>'Error',
                                 -text=> $message
                               );
    $dialog->Show();
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
# use_colmap => 1 (0 is default)
# NOTE: row 0 is the heading!!!
  { my($r_tbh,%options)= @_;

    my $Table= $r_tbh->{table_widget};

    my $str= $options{string};
    if (ref($str))
      { $str= $$str; };

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
        if (exists $r_tbh->{pks_h}->{$colname}) # it's a primary key
          { if ($#{$r_tbh->{pks}}==0) # only one primary key
              {
                return($r_tbh->{pk_hash}->{$str});
              };
          };

        return if (!defined $str);

        for(my $i=0; $i<$max; $i++)
          { $row+= $dir;
            if    ($row<=0)
              { $row= $max; }
            elsif ($row>$max)
              { $row=1; };

            if (put_get_val_direct($r_tbh,$use_colmap,
                                   row2pk($r_tbh,$row),$colname) eq $str)
              { return($row); };
          };
      }
    else
      {
        for(my $i=0; $i<$max; $i++)
          { $row+= $dir;
            if    ($row<=0)
              { $row= $max; }
            elsif ($row>$max)
              { $row=1; };
            if (put_get_val_direct($r_tbh,$use_colmap,
                                   row2pk($r_tbh,$row),$colname)=~/$str/)
              { return($row); };
          };
      };
    return;
  }

# handle column-maps:
#_______________________________________________________

sub set_column_map
  { my($r_glbl,$r_tbh,$sql_command,$column_name)= @_;


    my($r_key_to_str,$r_str_to_key)=
            get_column_map($r_glbl,$sql_command,$column_name);

    return if (!defined $r_str_to_key);

    my %col_map;
    $col_map{key_to_str} = $r_key_to_str;
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

sub add_to_column_maps
  { my($r_glbl,$r_tbh,$file)= @_;

    local(*F);

    my $r_colmaps= $r_tbh->{col_maps};
    return if (!defined $r_colmaps);

    my $r_h= load_column_maps($r_glbl,$file);

    my $tablename= $r_tbh->{table_name};
    foreach my $col (keys %$r_colmaps)
      { $r_h->{$tablename}->{$col}= $r_colmaps->{$col}->{sql_command}; };
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

    $r_glbl->{column_map_definitions}= $r_h;
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
        tk_err_dialog($r_tbh->{table_widget},
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

# warn "get from oracle: $r_tbh->{table_name} ";

    my $ntab;
    my %load_options;

    if ($r_tbh->{table_type} ne "sql")
      { if ($r_tbh->{table_type} eq 'table_or_view')
          { if (dbdrv::object_is_table($r_glbl->{dbh},$r_tbh->{table_name}))
              { $r_tbh->{table_type}= 'table'; }
            else
              { $r_tbh->{table_type}= 'view'; };
          };

        $ntab= dbitable->new('table',$r_tbh->{dbh},
                             $r_tbh->{table_name},
                            );
        if ($r_tbh->{table_filter})
          { $load_options{filter}  = ['SQL',$r_tbh->{table_filter}]; };
        if ($r_tbh->{table_order})
          { $load_options{order_by}= $r_tbh->{table_order}; };
      }
    else
      { $ntab= dbitable->new('view',$r_tbh->{dbh},
                             $r_tbh->{table_name},"",$r_tbh->{sequel}
                            );
      };

    if (!defined $ntab)
      { # dbitable prints an error-message of it's own, so there is
        # no need to print the same error here again

        #tk_err_dialog($r_glbl->{main_menu_widget},
        #              $dbitable::last_error);
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

# recursive dump:
#_______________________________________________________

sub rdump
#internal
  { my($r_buf,$val,$indent,$is_newline,$comma)= @_;

    $comma= '' if (!defined $comma);

    my $r= ref($val);
    if (!$r)
      { $val= "<undef>" if (!defined $val);
        $$r_buf.= " " x $indent if ($is_newline);
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
"share" Verzeichnis fuer globale Einstellungen verwenden
-----------------------------------------------
info-Fenster readonly machen
ctrl-z Key Binding abschalten
-----------------------------------
foreign tables: die Zeilen filtern
-----------------------------------
mapped columns markieren
-----------------------------------
Toplevel Window so erzeugen, das es in Gnome/KDE Taskbar besser
aussieht
----------------------------------------------------------
