eval 'exec perl -S $0 ${1+"$@"}' # -*- Mode: perl -*-
    if 0;
# the above is a more portable way to find perl
# ! /usr/bin/perl

use strict;

# search dbitable.pm ralative to the location of THIS script:
use lib "$FindBin::RealBin/../lib/perl";

#You may specify where to find Tk::TableMatrix, when
#it is not installed globally like this:
#use lib "$ENV{HOME}/project/perl/lib/site_perl";


# the following is only for my testing perl-environment:
#use lib "$ENV{HOME}/pmodules";
#use perl_site; 

use FindBin;
use Tk;
use Tk::Menu;
use Tk::Dialog;
#use Tk::Listbox;
use Tk::FileSelect;
use Tk::TableMatrix;
#use Tk::TableMatrix::Spreadsheet;

use Tk::ErrorDialog;

use warnings;
#use diagnostics;

use dbitable 1.7;

use Data::Dumper;

my $VERSION= "0.87";


my $PrgTitle= 'BrowseDB';

my $sim_oracle_access=0;

my $fast_test=0; # skip login dialog and open $fast_table
my $fast_table='p_insertion_value'; 

my $db_table_name;
if (!@ARGV)
  { $db_table_name= "p_insertion_value"; }
else
  { $db_table_name= shift; };


my $db_name      = "DBI:Oracle:bii_par";
my $db_username  = "guest";
my $db_password  = "bessyguest";

my $BG= "gray81";
my $BUTBG= "gray73";
my $ACTBG= "gray73";

# re-define the dbitable error-handler:
$dbitable::errorfunc  = \&dbidie;
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

tk_login(\%global_data, $db_name, $db_username, $db_password);


# --------------------- create some entry widgets


MainLoop();

sub tk_login
# r_glbl: hash with global entries
  { my($r_glbl,$db_name,$user,$password)= @_;
    
    $r_glbl->{db_name}     = $db_name;
    $r_glbl->{user}        = $user;
    $r_glbl->{password}    = $password;
    
    if ($fast_test)
      { tk_login_finish($r_glbl); 
        return;
      };
    
    my $Top= MainWindow->new(-background=>$BG);
    $Top->title("$PrgTitle:Login");

    $r_glbl->{login_widget}= $Top;

    my $FrTop = $Top->Frame(-background=>$BG
                	   )->pack(-side=>'top' ,-fill=>'both');
    my $FrDn  = $Top->Frame(-background=>$BG
                           )->pack(-side=>'top' );

    my $row=0;
    
    $FrTop->Label(-text => 'database:'
                 )->grid(-row=>$row++, -column=>0, -sticky=> "w");
    $FrTop->Label(-text => 'user:'
                 )->grid(-row=>$row++, -column=>0, -sticky=> "w");
    $FrTop->Label(-text => 'password:'
                 )->grid(-row=>$row++, -column=>0, -sticky=> "w");
    $row=0;		 
    $FrTop->Entry(-textvariable => \$r_glbl->{db_name}
                 )->grid(-row=>$row++, -column=>1, -sticky=> "w");
    $FrTop->Entry(-textvariable => \$r_glbl->{user}
                 )->grid(-row=>$row++, -column=>1, -sticky=> "w");
    $FrTop->Entry(-textvariable => \$r_glbl->{password},
                  -show => '*',
                 )->grid(-row=>$row++, -column=>1, -sticky=> "w");
    
    $FrDn->Button(-text => 'Login',
                  %std_button_options,
		  -command => [\&tk_login_finish, $r_glbl ],
        	   )->pack(-side=>'left', -anchor=>'nw');

    $FrDn->Button(-text => 'Quit',
                  %std_button_options,
		  -command => sub { $Top->destroy(); exit(0); }
        	   )->pack(-side=>'left', -anchor=>'nw');
  }
  
sub tk_login_finish
  { my($r_glbl)= @_;
  
    
    my $db_handle;
    if (!$sim_oracle_access)
      { $db_handle= dbitable::connect_database($r_glbl->{db_name},
                                               $r_glbl->{user},
                                               $r_glbl->{password});
        if (!defined $db_handle)
          { tk_err_dialog($r_glbl->{login_widget},
	                  "opening of the database failed");
	    return;
	  };  
      };
    $r_glbl->{password}=~ s/./\*/g;  
    
    $r_glbl->{dbh}= $db_handle;
   
    if (!$fast_test)
      { $r_glbl->{login_widget}->destroy;
        delete $r_glbl->{login_widget};
      };
      
    tk_main_window($r_glbl);
  }
    	       
sub tk_main_window
  { my($r_glbl)= @_;

    my $Top= MainWindow->new(-background=>$BG);
    $Top->title("$PrgTitle");

    $r_glbl->{main_menu_widget}= $Top;
    
    my $MnTop= $Top->Menu(-type=>'menubar');

    my $MnDb   = $MnTop->Menu();
    my $MnHelp = $MnTop->Menu();
    


    $MnTop->add('cascade',
	        -label=> 'Database',
	        #-accelerator => 'Meta+F',
                #-underline   => 0,
	        -menu=> $MnDb
	       );
    $MnTop->add('cascade',
	        -label=> 'Help',
	        #-accelerator => 'Meta+F',
                #-underline   => 0,
	        -menu=> $MnHelp
	       );

    $MnTop->pack(-side=>'left', -fill=>'x', -expand=>'y');
    
    
    # configure Database-menu:
    $MnDb->add('command',
               -label=> 'Open Table',
	       -command=> [\&tk_open_new_table, $r_glbl]
	      ); 
    $MnDb->add('command',
               -label=> 'show SQL commands',
	       -command=> [\&tk_sql_commands, $r_glbl]
	      ); 
    $MnDb->add('command',
               -label=> 'quit',
		 -command => sub { $Top->destroy(); exit(0); },
	      ); 

    # configure Help-menu:
    $MnHelp->add('command',
                 -label=> 'About',
	         -command=> [\&tk_about, $r_glbl]
	        ); 
    $MnHelp->add('command',
                 -label=> 'dump global datastructure',
		 -command => [\&tk_dump_global, $r_glbl],
	        ); 

    if ($fast_test)
      { tk_open_new_table($r_glbl); };	 
  }

sub tk_about
 { my($r_glbl)= @_;

   my $Top= $r_glbl->{main_menu_widget}->Toplevel(-background=>$BG);
   $Top->title("About $PrgTitle");

   my @text= ("$PrgTitle $VERSION",
               "written by Goetz Pfeiffer",
	       "for BESSY GmbH, Berlin, Adlershof",
	       "Comments/Suggestions, please mail to:",
	       "pfeiffer\@mail.bessy.de"
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

sub tk_open_new_table  
  { my($r_glbl)= @_;
  
    if ($fast_test)
      { $r_glbl->{new_table_name}= $fast_table; 
        tk_open_new_table_finish($r_glbl);
	return; 
      }
    else
      { $r_glbl->{new_table_name}= ""; };
  
    #my $Top= MainWindow->new(-background=>$BG);
    my $Top= $r_glbl->{main_menu_widget}->Toplevel(-background=>$BG);
    
    $Top->Label(-text => 'please enter the table-name:'
                 )->pack(-side=>'left', -fill=>'y');
    $Top->Entry(-textvariable => \$r_glbl->{new_table_name}
                 )->pack(-side=>'left', -fill=>'y');
    $Top->Button(-text => 'accept',
                 %std_button_options,
		  -command => [\&tk_open_new_table_finish, $r_glbl ],
        	 )->pack(-side=>'left', -fill=>'y');
    $Top->Button(-text => 'abort',
                 %std_button_options,
		 -command => sub { $Top->destroy; 
		                    delete $r_glbl->{table_dialog_widget}
				  }
        	 )->pack(-side=>'left', -fill=>'y');
    $r_glbl->{table_dialog_widget}= $Top;
  }
  
sub tk_open_new_table_finish
  { my($r_glbl)= @_;
  
    make_table_hash_and_window($r_glbl,uc($r_glbl->{new_table_name}));

    if ($fast_test)
      { $fast_test=0;
        return; 
      };
      
    delete $r_glbl->{new_table_name};
    
    $r_glbl->{table_dialog_widget}->destroy();
    delete $r_glbl->{table_dialog_widget};
  }	

sub tk_sql_commands
  { my($r_glbl)= @_;
  
   # my $Top= MainWindow->new(-background=>$BG);
   my $Top= $r_glbl->{main_menu_widget}->Toplevel(-background=>$BG);

   $Top->title("SQL command trace");

   my $text= $Top->Scrolled('Text');
   $r_glbl->{sql_commands_widget}= $text;
   $text->pack(-fill=>'both',expand=>'y');
   
   $dbitable::sql_trace= \&dbi_sql_trace;
   
   $Top->bind('<Destroy>', sub { $dbitable::sql_trace= undef;
                                delete $r_glbl->{sql_commands_widget};
			      });
  }   
    
sub dbi_sql_trace
# uses a global variable !!
  { my $Text= $global_data{sql_commands_widget};
    $Text->insert('end',$_[0] . "\n");
    $Text->see('end');
  }
  

sub tk_foreign_key_dialog
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
    my $FrDn  = $Top->Frame(-background=>$BG
                	   )->pack(-side=>'top' ,-fill=>'y', 
			          );
    
    my $maxcolsz=0;
    my @cols= (sort keys %$fkh);
    foreach my $col (@cols)
      { $maxcolsz= length($col) if (length($col)>$maxcolsz); };

    my @lines;

    foreach my $col (@cols)
      { push @lines, 
             sprintf("%-" . $maxcolsz . "s -> %s",$col, $fkh->{$col}->[0])
      };
    my $maxlnsz=0;
    foreach my $l (@lines)
      { $maxlnsz= length($l) if (length($l)>$maxlnsz); };
    
    my $listbox= $FrTop->Listbox(-selectmode => 'single', 
                                 -width=>$maxlnsz,
			         -height=> $#lines+1);
    foreach my $l (@lines)
      { $listbox->insert('end', $l); };
      
    $listbox->pack(-fill=>'both',-expand=>'y');
    
    $FrDn->Button(-text => 'open table',
                  %std_button_options,
		 -command => [\&tk_foreign_key_dialog_finish, $r_glbl, $r_tbh],
        	 )->pack(-side=>'left' ,-fill=>'y');

    $FrDn->Button(-text => 'abort',
                  %std_button_options,
		  -command => sub { 
		                $Top->destroy; 
		                delete $r_glbl->{foreign_key_dialog_widget},
				delete $r_glbl->{foreign_key_dialog_listbox},
				delete $r_glbl->{foreign_key_cols}
				  }
        	 )->pack(-side=>'left' ,-fill=>'y');

    $r_glbl->{foreign_key_dialog_widget} = $Top;
    $r_glbl->{foreign_key_dialog_listbox}= $listbox;
    $r_glbl->{foreign_key_cols} = \@cols;
  } 
  
sub tk_foreign_key_dialog_finish
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
   
   my($fk_table,$fk_col)= @{$r_tbh->{foreign_key_hash}->{$colname}}; 

   $Top->destroy;  # @@@@

   my $r_all_tables= $r_glbl->{all_tables};
   tkdie($r_glbl,"assertion in line " . __LINE__)
     if (!defined $r_all_tables); # assertion, shouldn't happen

   my $r_tbh_fk= $r_all_tables->{$fk_table};
   if (!defined $r_tbh_fk)
     { # 'resident_there' must be given as parameter to
       # make_table_hash_and_window since make_table_window looks for
       # this part of the table-hash and creates the "select" button if
       # that member of the hash is found
       $r_tbh_fk= make_table_hash_and_window(
                       $r_glbl, 
                       $fk_table,
		       resident_there=>1
					    );

        conn_add($r_glbl,$r_tbh->{table_name},$colname,
	         $fk_table,$fk_col);

     };
   my $Table= $r_tbh->{table_widget};

   my($row,$col)= split(",",$Table->index('active'));
   my($pk)= row2pk($r_tbh,$row);
   # using Table->get() would be unnecessary slow
   my $cell_value= put_get_val_direct($r_tbh,$pk,$colname);

   tk_activate_cell($r_tbh_fk,$fk_col, $cell_value);
    
   delete $r_glbl->{foreign_key_dialog_widget};
   delete $r_glbl->{foreign_key_dialog_listbox};
   delete $r_glbl->{foreign_key_cols};

  }   
  
sub tk_dependency_dialog
  { my($r_glbl,$r_tbh)= @_;
  
    my $parent_widget= $r_tbh->{table_widget};
  
    my $r_resident_keys= $r_tbh->{dbitable}->resident_keys();
    
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
		 
		 
	    # print "$col_name:$r_sublist->[0]:$r_sublist->[1]\n";
	  
	  };
      };
      
    # my $Top= MainWindow->new(-background=>$BG);
    my $Top= $r_glbl->{main_menu_widget}->Toplevel(-background=>$BG);

    $Top->title("dependents from $r_tbh->{table_name}");



    my $FrTop = $Top->Frame(-borderwidth=>2,-relief=>'raised',
                           -background=>$BG
                	   )->pack(-side=>'top' ,-fill=>'both',
			          -expand=>'y');
    my $FrDn  = $Top->Frame(-background=>$BG
                	   )->pack(-side=>'top' ,-fill=>'y', 
			          );
    
    
    my @resident_table_list= sort keys %resident_tables;

    my $max_height= 10;
    my $max_width= 0;
    foreach my $r (@resident_table_list)
      { $max_width= length($r) if (length($r)>$max_width); };
    
    my $listbox;
    my %listbox_options= (-selectmode => 'single', 
                          -width=>$max_width,
			  -height=> $max_height);
    if ($#resident_table_list>$max_height)
      { $listbox= $FrTop->Scrolled( 'Listbox', %listbox_options ); }
    else
      { $listbox_options{-height}= $#resident_table_list + 1; 
        $listbox= $FrTop->Listbox(%listbox_options ); 
      };
      
    foreach my $res_table (@resident_table_list)
      { $listbox->insert('end', $res_table); };
      
    $listbox->pack(-fill=>'both',-expand=>'y');
    
    $FrDn->Button(-text => 'open table',
                  %std_button_options,
		 -command => [\&tk_dependency_dialog_finish, $r_glbl, $r_tbh],
        	 )->pack(-side=>'left' ,-fill=>'y');

    $FrDn->Button(-text => 'abort',
                  %std_button_options,
		  -command => sub { 
		             $Top->destroy; 
		             delete $r_tbh->{dependency_dialog_top_widget};
   			     delete $r_tbh->{dependency_dialog_listbox};
   			     delete $r_tbh->{resident_tables};
   			     delete $r_tbh->{resident_table_list};
				  }
        	 )->pack(-side=>'left' ,-fill=>'y');

    $r_tbh->{dependency_dialog_top_widget}= $Top;
    $r_tbh->{dependency_dialog_listbox}   = $listbox;
    $r_tbh->{resident_tables}             = \%resident_tables;
    $r_tbh->{resident_table_list}         = \@resident_table_list;
  }		     

sub tk_dependency_dialog_finish
  { my($r_glbl,$r_tbh)= @_;
  
    my $Top                  = $r_tbh->{dependency_dialog_top_widget};
    my $listbox              = $r_tbh->{dependency_dialog_listbox};
    my $r_resident_table_list= $r_tbh->{resident_table_list};
    my $r_resident_tables    = $r_tbh->{resident_tables};
    
    
    my @selection= $listbox->curselection();
    
    if (!@selection)
      { tk_err_dialog($Top, "no table selected"); 
    	return;
      };
    
    my $res_table= $r_resident_table_list->[ $selection[0] ];
    
    # warn "open new table: $res_table";
    
    $Top->destroy;  # @@@@
    
    my $r_all_tables= $r_glbl->{all_tables};
    tkdie($r_glbl,"assertion in line " . __LINE__)
       if (!defined $r_all_tables); # assertion, shouldn't happen
    
    my $r_tbh_res= $r_all_tables->{$res_table};
    if (!defined $r_tbh_res)
      { # create a window fore the resident-table:
        $r_tbh_res= make_table_hash_and_window($r_glbl, $res_table);
      
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
	
    delete $r_tbh->{dependency_dialog_top_widget};
    delete $r_tbh->{dependency_dialog_listbox};
    delete $r_tbh->{resident_tables};
    delete $r_tbh->{resident_table_list};
  }  
    

sub tk_find_line
  { my($r_tbh)= @_;

    my $TableWidget= $r_tbh->{table_widget};

    # get row-column of the active cell in the current table
    my($row,$col)= split(",",$TableWidget->index('active'));
    my($pk,$colname)= rowcol2pkcolname($r_tbh,$row,$col);
 
    # my $Top= MainWindow->new(-background=>$BG);
    my $Top= $TableWidget->Toplevel(-background=>$BG);

    my $title= "$r_tbh->{table_name}: Find $colname";
    $Top->title($title);

    my $FrTop = $Top->Frame(-borderwidth=>2,-relief=>'raised',
                           -background=>$BG
                	   )->pack(-side=>'top' ,-fill=>'x',
			          -expand=>'y');
    my $FrDn  = $Top->Frame(-background=>$BG
                	   )->pack(-side=>'top' ,-fill=>'y',
			          -expand=>'y'
			          );
       
    $FrTop->Label(-text=>"string to find: ")->pack(-side=>'left');
    
    $r_tbh->{find_cell}= "";
    
    $FrTop->Entry(-textvariable => \$r_tbh->{find_cell},
                  -width=>20
                 )->pack(-side=>'left',-fill=>'x',-expand=>'y');
		 
    $FrDn->Button(-text => 'accept',
                 %std_button_options,
		  -command => sub { 
		                   my @pks=
				             $r_tbh->{dbitable}->find(
				                        $colname,
				                        $r_tbh->{find_cell}
							             );
        			   if (!@pks)
        			     { tk_err_dialog($Top,
	                                   "error: $r_tbh->{find_cell} " .
				           "not found in table");
				     }
				   else
				     { my $row= pk2row($r_tbh,$pks[0]);
				       $TableWidget->activate("$row,$col");
                                       $TableWidget->yview($row-1);
				     };
				   delete $r_tbh->{find_cell};
				   $Top->destroy;
				  }		      
        	 )->pack(-side=>'left', -fill=>'y');
    $FrDn->Button(-text => 'abort',
                 %std_button_options,
		 -command => sub { delete $r_tbh->{find_cell};
				   $Top->destroy; 
				  }
        	 )->pack(-side=>'left', -fill=>'y');
  }		 

sub tk_field_edit
  { my($r_tbh)= @_;
  
    my $TableWidget= $r_tbh->{table_widget};

    # get row-column of the active cell in the current table
    my($row,$col)= split(",",$TableWidget->index('active'));
    my($pk,$colname)= rowcol2pkcolname($r_tbh,$row,$col);
 
    # my $Top= MainWindow->new(-background=>$BG);
    my $Top= $TableWidget->Toplevel(-background=>$BG);

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
       
    $FrTop->Label(-text=>"$colname: ")->pack(-side=>'left');
    
    $r_tbh->{edit_cell}= put_get_val_direct($r_tbh,$pk,$colname);
    my $w= length($r_tbh->{edit_cell});
    
    $w=20 if ($w<20);
    
    $FrTop->Entry(-textvariable => \$r_tbh->{edit_cell},
                  -width=>$w
                 )->pack(-side=>'left',-fill=>'x',-expand=>'y');
		 
    $FrDn->Button(-text => 'accept',
                 %std_button_options,
		  -command => sub { $TableWidget->set("$row,$col",
		                                      $r_tbh->{edit_cell});
				   delete $r_tbh->{edit_cell};
				   $Top->destroy;
				  }		      
        	 )->pack(-side=>'left', -fill=>'y');
    $FrDn->Button(-text => 'abort',
                 %std_button_options,
		 -command => sub { delete $r_tbh->{edit_cell};
				   $Top->destroy; 
				  }
        	 )->pack(-side=>'left', -fill=>'y');
  }		 
    

sub make_table_hash_and_window
  { my($r_glbl,$table_name,%hash_defaults)= @_;
  
    if (!exists $r_glbl->{all_tables})
      { $r_glbl->{all_tables}= {}; };
    
    my $r_all_tables= $r_glbl->{all_tables};

    my $r_tbh= 
            make_table_hash($r_glbl,$table_name,%hash_defaults);

    if (!defined $r_tbh)
      { tk_err_dialog($r_glbl->{main_menu_widget}, 
                      "opening of the table failed!");
	return;
      };	      
    
    $r_all_tables->{$table_name}= $r_tbh;

    make_table_window($r_glbl,$r_tbh);
    
    return($r_tbh);
  }  


sub make_table_hash
  { my($r_glbl,$table_name,%hash_defaults)= @_;
  
    my $dbh= $r_glbl->{dbh};
    
    my %table_hash= %hash_defaults;
    
    # the database-handle:
    $table_hash{dbh}        = $dbh;

    # the table-name:
    $table_hash{table_name} = $table_name;

    # the dbitable object:
    $table_hash{dbitable}   = get_dbitable($r_glbl,\%table_hash);

    if (!defined $table_hash{dbitable})
      { 
        #warn "unable to open!!";
	return; 
      
      }; # was unable to open table


    # $table_hash{dbitable}->dump(); die;

    # the column-hash that maps column-names to indices:
    $table_hash{column_hash}= { $table_hash{dbitable}->column_hash() };

    # the column-list that maps column-indices to column-names:
    $table_hash{column_list}= [ $table_hash{dbitable}->column_list() ];

    # the number of columns:
    $table_hash{column_no}  = $#{$table_hash{column_list}} + 1;

    # the width of the columns:
    $table_hash{column_width}= 
                    [ $table_hash{dbitable}->max_column_widths(5,25) ];



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
        # the primary key column index
        $table_hash{pkis}       = 
                      [ $table_hash{dbitable}->primary_key_column_indices() ];
      }; 
      
    # the foreign-key hash
    # this is just the pure information from the database which
    # columns are foreign keys. This has nothing to do with the
    # fact wether that foreign key table is displayed or not
    $table_hash{foreign_key_hash}= $table_hash{dbitable}->foreign_keys();

    
    # the list with write-protected column-indices:
    # P: protected, T: temporarily writable, undef: writable
    my @wp;
    
    if (!$table_hash{no_pk_cols})
      { foreach my $i (@{$table_hash{pkis}})
          { $wp[ $i ]='P'; };
      };
    
    foreach my $col (keys %{$table_hash{foreign_key_hash}})
      { $wp[ colname2col(\%table_hash, $col) ]='P'; };
    $table_hash{write_protected_cols}= \@wp;
    
    # the hash that is used for sorting:
    $table_hash{sort_columns}= [ @{$table_hash{column_list}} ];
    
    initialize_sort_columns(\%table_hash);

    # this list of primary key values, maps the row-index to the primary key value
    $table_hash{pk_list} = get_pk_list(\%table_hash);

    $table_hash{pk_hash} = calc_pk2index(\%table_hash);

    # the number of rows:
    $table_hash{row_no}  = $#{$table_hash{pk_list}} + 1;

    # marker for changed cells in the table:
    $table_hash{changed_cells}  = {};
    $table_hash{changed_rows}   = {};

    $table_hash{curr_sort_col}= $table_hash{sort_columns}->[0]; 
                          # only needed to give the sort-
			  # radiobuttons a visible initial state
    
    return(\%table_hash);
  }

sub make_table_window
  { my($r_glbl,$r_tbh)= @_;
  
    # create a new top-window
    # my $Top= MainWindow->new(-background=>$BG);
    my $Top= $r_glbl->{main_menu_widget}->Toplevel(-background=>$BG);
    $r_tbh->{top_widget}= $Top;

    # set the title
    $Top->title($r_tbh->{table_name});


    my $FrTop = $Top->Frame(-borderwidth=>2,-relief=>'raised',
                           -background=>$BG
                	   )->pack(-side=>'top' ,-fill=>'both');
    my $FrDn  = $Top->Frame(-background=>$BG
                	   )->pack(-side=>'top' ,-fill=>'both', 
			          -expand=>'y');
  
    my $MnTop= $FrTop->Menu(-type=>'menubar');

    my $MnFile  = $MnTop->Menu();
    my $MnDbase = $MnTop->Menu();
    my $MnEdit  = $MnTop->Menu();
    my $MnRela  = $MnTop->Menu();
    my $MnView  = $MnTop->Menu();
    
    $MnTop->add('cascade',
		-label=> 'File',
	        -accelerator => 'Meta+F',
                -underline   => 0,
		-menu=> $MnFile
		);
    $MnTop->add('cascade',
		-label=> 'Database',
	        -accelerator => 'Meta+D',
                -underline   => 0,
		-menu=> $MnDbase
		);
    $MnTop->add('cascade',
		-label=> 'Edit',
	        -accelerator => 'Meta+E',
                -underline   => 0,
		-menu=> $MnEdit
		);
    $MnTop->add('cascade',
		-label=> 'Relations',
	        -accelerator => 'Meta+R',
                -underline   => 0,
		-menu=> $MnRela
		);
    $MnTop->add('cascade',
		-label=> 'View',
	        -accelerator => 'Meta+V',
                -underline   => 0,
		-menu=> $MnView
		);
    
    $MnTop->pack(-side=>'left', -fill=>'x', -expand=>'y');
    
    
    # configure file-menu:
    $MnFile->add('command',
		 -label=> 'Save',
	         -accelerator => 'Meta+S',
                 -underline   => 0,
		 -command=> [\&tk_save_to_file, $r_tbh]
		); 
    $MnFile->add('command',
		 -label=> 'Load',
	         -accelerator => 'Meta+L',
                 -underline   => 0,
		 -command=> [\&tk_load_from_file, $r_tbh]
		); 

    # configure database-menu:
    $MnDbase->add('command',
		  -label=> 'Store',
	          -accelerator => 'Meta+S',
                  -underline   => 0,
		  -command => [\&cb_store_db, $r_tbh],
		); 
    $MnDbase->add('command',
		  -label=> 'Reload',
	          -accelerator => 'Meta+R',
                  -underline   => 0,
		  -command => [\&cb_reload_db, $r_tbh],
		); 


    # configure edit-menu:
    my $MnEditField= $MnEdit->Menu();
    my $MnEditLine = $MnEdit->Menu();
    
    
    $MnEdit->add('command',
		  -label=> 'find in column',
	          -accelerator => 'Meta+C',
                  -underline   => 8,
		  -command => [\&tk_find_line, $r_tbh],
		); 
    $MnEdit->add('cascade',
		  -label=> 'field',
		  -accelerator => 'Meta+F',
                  -underline   => 0,
		  -menu => $MnEditField,
		); 
    $MnEdit->add('cascade',
		  -label=> 'line',
		  -accelerator => 'Meta+L',
                  -underline   => 0,
		  -menu => $MnEditLine,
		); 
    
		     
    $MnEditLine->add('command',
		      -label=> 'insert',
		      -accelerator => 'Meta+I',
                      -underline   => 0,
		      -command => [\&cb_insert_line, $r_tbh],
		    ); 
    $MnEditLine->add('command',
		      -label=> 'delete',
		      -accelerator => 'Meta+D',
                      -underline   => 0,
		      -command => [\&tk_delete_line_dialog, $r_tbh],
		    ); 
    $MnEditLine->add('command',
		      -label=> 'copy',
		      -accelerator => 'Meta+C',
                      -underline   => 0,
		      -command => [\&cb_copy_paste_line, 
		        	   $r_glbl, $r_tbh, 'copy'],
		    ); 
    $MnEditLine->add('command',
		      -label=> 'paste',
		      -accelerator => 'Meta+P',
                      -underline   => 0,
		      -command => [\&cb_copy_paste_line, 
		        	   $r_glbl, $r_tbh, 'paste'],
		    ); 
		
    $MnEditField->add('command',
		       -label=> 'enter value',
		       -accelerator => 'Meta+E',
                       -underline   => 0,
		       -command => [\&tk_field_edit, $r_tbh],
		     ); 
		     
    $MnEditField->add('command',
		      -label=> 'copy',
		      -accelerator => 'Meta+C',
                      -underline   => 0,
		      -command => [\&cb_copy_paste_field, 
		        	   $r_glbl, $r_tbh, 'copy'],
		     ); 
    $MnEditField->add('command',
		       -label=> 'paste',
		       -accelerator => 'Meta+P',
                       -underline   => 0,
		       -command => [\&cb_copy_paste_field, 
		        	    $r_glbl, $r_tbh, 'paste'],
		     ); 


    # configure relations-menu:
    $MnRela->add('command',
		  -label=> 'Dependencies',
		  -accelerator => 'Meta+D',
                  -underline   => 0,
		  -command => [\&tk_dependency_dialog, $r_glbl, $r_tbh],
		); 
    $MnRela->add('command',
		  -label=> 'Foreign Keys',
		  -accelerator => 'Meta+F',
                  -underline   => 0,
		  -command => [\&tk_foreign_key_dialog, $r_glbl, $r_tbh],
		); 

    if ($r_tbh->{resident_there})
      { $MnRela->add('command',
                     -label=> 'Select value',
		     -accelerator => 'Meta+S',
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
    my $MnViewSort = $MnView->Menu();
    $MnView->add('cascade',
		  -label=> 'Sort rows',
		  -accelerator => 'Meta+S',
                  -underline   => 0,
		  -menu => $MnViewSort
		); 
    $MnView->add('command',
		  -label=> 'Object-Dump',
		  -command => [\&tk_table_dump, $r_tbh],
		); 
    $MnView->add('command',
		  -label=> 'dbitable-Dump',
		  -command => [\&tk_dbitable_dump, $r_tbh],
		); 



    foreach my $col (@{$r_tbh->{column_list}})
      { $MnViewSort->add('radiobutton',
                	 -value=> $col, 
			 -variable => \$r_tbh->{curr_sort_col},
			 -label=> $col,
			 -command=> [\&tk_resort_and_redisplay, 
		        	     $r_tbh,
				     $col],
		    );
      };
      

    
    # there is no Close Button, the function that
    # cleans up is bound to the window <Destroy> event
    #  (see further below, '<Destroy>'
    
    #$FrTop->Button(-text => 'Close',
    #               %std_button_options,
    #		   -command => [\&cb_close_window, $r_glbl, $r_tbh]
    #     	   )->pack(-side=>'left', -anchor=>'nw');



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
				  -cols => $r_tbh->{column_no},
				  -rows => $r_tbh->{row_no} + 1, # 1 more f.the heading 
				  -justify => "left",
				  -colstretchmode => "none",
				  -rowstretchmode => "unset",
				  #-flashmode=> 1, 
				  #-width => $dbi_column_no, 
                        	 );

    $Table->activate("1,0"); # one cell must be activated initially,
    			     # otherwise index('active') produces a
			     # Tk Error, when it is used
    
    { my $r_width= $r_tbh->{column_width};
    
      for(my $i=0; $i<= $#$r_width; $i++)
        { 
	  $Table->colWidth($i, $r_width->[$i]);
	};
    };

    # The table is "packed" at this place !!!!!!!!!!!!!!!!!!!
    
    $Table->grid(-row=>0, -column=>0, -sticky=> "nsew");

    my $xscroll = $FrDn->Scrollbar(-command => ['xview', $Table],
                        	   -orient => 'horizontal',
                        	  )->grid(-row=>1, -column=>0, -sticky=> "ew"); 

    $Table->configure(-xscrollcommand => ['set', $xscroll]); 

    my $yscroll = $FrDn->Scrollbar(-command => ['yview', $Table],
                        	   -orient => 'vertical',
                        	  )->grid(-row=>0, -column=>1, -sticky=> "ns"); 

    $Table->configure(-yscrollcommand => ['set', $yscroll]); 


    # mark changed cells by changing the foreground color to red
    $Table->tagConfigure('changed_cell', -foreground => 'red');

    # create a tag for the primary key column
    $Table->tagConfigure('pk_cell', -foreground => 'blue');
			 #-state => 'disabled');

    # mark the primary key, it may not be edited
    if (!$r_tbh->{no_pk_cols})
      { foreach my $i (@{$r_tbh->{pkis}})
          { $Table->tagCol('pk_cell', $i); };
      };
      
    # create a tag for the foreign key column
    $Table->tagConfigure('fk_cell', -foreground => 'LimeGreen');
			# -state => 'disabled');
    
    foreach my $fk_col (keys % {$r_tbh->{foreign_key_hash}})
      { 
        $Table->tagCol('fk_cell', colname2col($r_tbh,$fk_col) ); 
      };

    $r_tbh->{table_widget}= $Table;
    
    # bind the right mouse button to a function,
    # give it the current mouse position in the
    # form '@x,y' 
    $Table->bind('<3>', [\&cb_handle_right_button, $r_glbl, $r_tbh, Ev('@')] );

    $Table->bind('<Destroy>', [\&cb_close_window, $r_glbl, $r_tbh] );
      
  }

sub tk_save_to_file
  { my($r_tbh)= @_;
  
    # warn "save to file";
    my $Fs= $r_tbh->{top_widget}->FileSelect(
                                               -defaultextension=> ".dbt"
		                            );
    
    my $file= $Fs->Show();

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
  { my($r_tbh)= @_;

    my $Fs= $r_tbh->{top_widget}->FileSelect(
                  -defaultextension=> ".dbt"
		                            );
    
    my $file= $Fs->Show();

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

sub tk_dump_global
 { my($r_glbl)= @_;
# ommit dumping the tables-structures completely 
 
   # my $Top= MainWindow->new(-background=>$BG);
   my $Top= $r_glbl->{main_menu_widget}->Toplevel(-background=>$BG);

   $Top->title("Global Datastructure-Dump");

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

   my $text= $Top->Scrolled('Text');
   my $buffer;
   
   rdump(\$buffer,\%glbl_copy,0);
   
   $text->insert('end',$buffer);
     
   $text->pack(-fill=>'both',expand=>'y');
 }

sub tk_table_dump
 { my($r_tbh)= @_;
   my $name= $r_tbh->{table_name};
 
   # my $Top= MainWindow->new(-background=>$BG);
   my $Top= $r_tbh->{table_widget}->Toplevel(-background=>$BG);
   
   $Top->title("$name:Object-Dump");

   my $text= $Top->Scrolled('Text');
   my $buffer;
   
   rdump(\$buffer,$r_tbh,0);
   
   $text->insert('end',$buffer);
     
   $text->pack(-fill=>'both',expand=>'y');
 }

sub tk_dbitable_dump
 { my($r_tbh)= @_;
   my $name= $r_tbh->{table_name};
   my $dbitable= $r_tbh->{dbitable};
 
   # my $Top= MainWindow->new(-background=>$BG);
   my $Top= $r_tbh->{table_widget}->Toplevel(-background=>$BG);
   
   $Top->title("$name:DBITable-Dump");

   my $text= $Top->Scrolled('Text');
   
   my $r_buffer= $dbitable->dump_s(); 
   
   $text->insert('end',$$r_buffer);
     
   $text->pack(-fill=>'both',expand=>'y');
 }

sub tk_err_dialog
  { my($parent,$message)= @_;
   
    my $dialog= $parent->Dialog(
	                    -title=>'Error',
		            -text=> $message
		               );
    $dialog->Show();				     
  }

sub dbidie
# uses a global variable !!
  { 
#warn "dbidie was called";  
    tkdie(\%global_data,@_); 
  }

sub tkdie
  { my($r_glbl,$message)= @_;
   
    my $Top= $r_glbl->{main_menu_widget};
   
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
# warn "Table $table_name successfully deleted !\n";
 }

sub cb_handle_right_button
  { my($parent_widget, $r_glbl, $r_tbh, $at)= @_;
    
    # $at has the form '@x,y' 
    
    # determine row and column of the cell that was clicked:
    my($row,$col)= split(",",$parent_widget->index($at));
    my($pk,$colname)= rowcol2pkcolname($r_tbh,$row,$col);
    
    # using Table->get() would be unnecessary slow
    my $cell_value= put_get_val_direct($r_tbh,$pk,$colname);
    
    my $fkh= $r_tbh->{foreign_key_hash};
    return if (!defined $fkh); # no foreign keys defined
    
    my $fk_data= $fkh->{$colname};
    return if (!defined $fk_data); # no foreign key column!
    
    # now activate the cell:
    $parent_widget->activate($at);
    
    
    # the following should not be done in this callback:
    my $maxcol= $r_tbh->{column_no}-1;

    # marking as active is difficult, since the cell is not editable
    # per definition, the "active" tag (inverse colors) can never be
    # removed !
    # $parent_widget->tagCell('active','active');
    
    my($fk_table,$fk_col)= @{$fk_data};
    
    # print "foreign key data: $fk_table,$fk_col\n";
    
    my $r_all_tables= $r_glbl->{all_tables};
    tkdie($r_glbl,"assertion in line " . __LINE__)
      if (!defined $r_all_tables); # assertion, shouldn't happen
    
    my $r_tbh_fk= $r_all_tables->{$fk_table};
    if (!defined $r_tbh_fk)
      { # 'resident_there' must be given as parameter to
        # make_table_hash_and_window since make_table_window looks for
	# this part of the table-hash and creates the "select" button if
	# that member of the hash is found
        $r_tbh_fk= make_table_hash_and_window(
                        $r_glbl, 
                        $fk_table,
			resident_there=>1
					     );

         conn_add($r_glbl,$r_tbh->{table_name},$colname,
	          $fk_table,$fk_col);
	 
      }
	
    tk_activate_cell($r_tbh_fk,$fk_col, $cell_value);
  }

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
	   tk_activate_cell($f_tbh,$r_cols->[0],
                         put_get_val_direct($r_tbh,$pk,$r_cols->[1])
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
	           tk_activate_cell($f_tbh,$r_cols->[0],
                         put_get_val_direct($r_tbh,$pk,$colname)
                                );
		 };
             };
	   # when the current column is not a resident column do nothing    	
         };
     };
     		     
 }

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
   my $value= put_get_val_direct($r_tbh,$pk,$colname);
  
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
	       $res_tbh->{write_protected_cols}->[$res_col]= 'T';
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

sub cb_copy_paste_field
  { my($r_glbl,$r_tbh,$mode)= @_;
  
    my $Table= $r_tbh->{table_widget};

    # get actibe cell:
    my($row,$col)= split(",",$Table->index('active'));

    if ($mode eq 'copy')
      { 
        $r_tbh->{paste_buffer}= cb_put_get_val($r_tbh,0,$row,$col);
        return;
      };
    if ($mode eq 'paste')
      { my $r_wp_flags= $r_tbh->{write_protected_cols};
        if ($r_wp_flags->[$col] eq 'P')
	  { $r_wp_flags->[$col]= 'T';
	    # remove write protection temporarily
	  };  
        $Table->set("$row,$col",$r_tbh->{paste_buffer} );

        return;
      };

    tkdie($r_glbl,"assertion in line " . __LINE__ .
          ", unknown mode: $mode");
  }

sub cb_copy_paste_line
  { my($r_glbl,$r_tbh,$mode)= @_;
  
    my $Table= $r_tbh->{table_widget};

    # get actibe cell:
    my($row,$col)= split(",",$Table->index('active'));

    if ($mode eq 'copy')
      { my %line;
        my $pk= row2pk($r_tbh,$row);
        foreach my $colname (keys %{$r_tbh->{column_hash}})
	  { $line{$colname}= put_get_val_direct($r_tbh,$pk,$colname); };
	  
        $r_tbh->{paste_linebuffer}= \%line;
        return;
      };
      
    if ($mode eq 'paste')
      { my $r_line= $r_tbh->{paste_linebuffer};
        my $r_wp_flags= $r_tbh->{write_protected_cols};
	my $pk= row2pk($r_tbh,$row);
        foreach my $colname (keys %$r_line)
	  { my $this_col= colname2col($r_tbh,$colname);
	    next if ($r_wp_flags->[$this_col] eq 'P'); 
	    # do not overwrite primary keys or foreign keys
	    $Table->set("$row,$this_col", $r_line->{$colname});
          };
        return;
      };

    tkdie($r_glbl,"assertion in line " . __LINE__ .
          ", unknown mode: $mode");
  }



sub cb_put_get_val
# global variables used: NONE
  { my($r_tbh,$set,$row,$col,$val)= @_;
  
    if ($row==0) # row 0 has the column-names
      { return( $r_tbh->{column_list}->[$col] ); };
  
    my($pk,$colname)= rowcol2pkcolname($r_tbh,$row,$col);
    
    if ($set)
      { if ($r_tbh->{sim_put})
          { # just simulate the put, do nothing real
	    delete $r_tbh->{sim_put};
	    return($val);
	  };
      
        my $flag= $r_tbh->{write_protected_cols}->[$col];
      
        if (defined $flag)
	  { if ($flag eq 'P')
              { $r_tbh->{table_widget}->bell();
		# warn "no writing allowed on this column
        	return($r_tbh->{dbitable}->value($pk,$colname));
	      };
	    if ($flag eq 'T')  
	      { $r_tbh->{write_protected_cols}->[$col]= 'P'; };   
          };
	  
        chomp($val);
        $r_tbh->{dbitable}->value($pk,$colname,$val);
	$r_tbh->{changed_cells}->{"$pk;$colname"}= "$row,$col";
	$r_tbh->{table_widget}->tagCell('changed_cell',"$row,$col");
	#warn "set tag to $row,$col";
	
        return($val);
      }
    else
      { return($r_tbh->{dbitable}->value($pk,$colname));
      };
  }

sub put_get_val_direct
  { my($r_tbh,$pk,$column,$val)= @_;
 
    return($r_tbh->{dbitable}->value($pk,$column,$val));
  }

sub rdump
#internal
  { my($r_buf,$val,$indent,$is_newline,$comma)= @_;
  
    my $r= ref($val);
    if (!$r)
      { $$r_buf.= " " x $indent if ($is_newline);
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
	    $$r_buf.= ($st); 
            rdump($r_buf,$val->{$k},$nindent,0,($i==$#k) ? "" : ",");
	  };
        $indent-=2; $$r_buf.= " " x $indent . "}$comma\n";
        return;
      };
    $$r_buf.=  " " x $indent if ($is_newline);
    $$r_buf.=  "REF TO: \'$r\'$comma\n"; 
  }

sub cb_insert_line
 { my($r_tbh)= @_;
 
   my @pk_cols;
   
   if (!$r_tbh->{no_pk_cols})
     { @pk_cols= @{$r_tbh->{pks}}; };
     
   my $dbitable= $r_tbh->{dbitable};
   
   if ($#pk_cols>0)
     { tk_err_dialog($r_tbh->{table_widget},
                     "this table has more than one " .
		     "primary key column. Direct inserting " .
		     "of an empty line is not possible here!"
		     );
       return;
     };
   my $r_col_hash= $r_tbh->{column_hash};
   my %h;
   foreach my $col (keys %$r_col_hash)
     { next if ($col eq $pk_cols[0]);
       $h{$col}="";
     };
     
   my $new_pk= $dbitable->add_line(%h);

   my $Table= $r_tbh->{table_widget};

   # re-calc the number of rows, update the table- widget:
   # (there may be new lines inserted in the table)
   resize_table($r_tbh);
     	     
   my($row,$col)= pkcolname2rowcol($r_tbh,$new_pk,$pk_cols[0]);
   $Table->activate("$row,$col");
   $Table->see("$row,$col");

  }

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
 { my($r_tbh)= @_;

   my $Table= $r_tbh->{table_widget};

   tk_remove_changed_cell_tag($r_tbh);
   
   $r_tbh->{dbitable}->load();

   # re-calc the number of rows, update the table- widget:
   # (there may be new lines inserted in the table)
   resize_table($r_tbh);
   # ^^^ resize_table does also a re-draw of the table-widget

   # update the displayed content in the active cell:
   tk_rewrite_active_cell($r_tbh);
   
   # the following would also force a redraw
   # $Table->configure(-padx => ($Table->cget('-padx')) );
 }

# $Table->tag
# $Table->tagCell(tagName, ?)

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

sub tk_activate_cell
# makes a cell active, given by column-name and value
  { my($r_tbh,$colname,$value)= @_;
  
    my @pks= $r_tbh->{dbitable}->find($colname,$value,
                                     warn_not_pk=>1);
    if (!@pks)
      { tk_err_dialog($r_tbh->{table_widget},
                     "tk_activate_cell: table $r_tbh->{table_name}\n" .
                     "col $colname, val $value not found");
	return;
      };
    if (scalar @pks !=1 )  
      { tk_err_dialog($r_tbh->{table_widget},
                     "tk_activate_cell: table $r_tbh->{table_name}\n" .
                     "col $colname, val $value found more than once");
	return;
      };
     
    my($row,$col)= pkcolname2rowcol($r_tbh,$pks[0],$colname);
    my $Table= $r_tbh->{table_widget};
    $Table->activate("$row,$col");
    
    
    #$Table->see("$row,$col");
    # somehow, yview works much more reliable
    # than see()

    $Table->yview($row-1);
  }
    

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
      

sub tk_resort_and_redisplay
# global variables used: NONE
  { my($r_tbh,$col)= @_;
  
    my $Table_widget= $r_tbh->{table_widget};
    # remove the "changed" tag
    # it should be re-calculated!!
 
    my $r_changed_cells= $r_tbh->{changed_cells};
    
    foreach my $k (keys %$r_changed_cells)
      { # set the default-tag
        $Table_widget->tagCell('',$r_changed_cells->{$k});
      };

    put_new_sort_column_first($r_tbh,$col);
 

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
  }    

sub colname2col
# map column-name to column-index 
  { my($r_tbh,$col_name)= @_;
  
    return( $r_tbh->{column_hash}->{$col_name} );
  }

sub pk2row
# map primary-key, column-name to row,column 
  { my($r_tbh,$pk)= @_;
  
    return( $r_tbh->{pk_hash}->{$pk} );
  }

sub pkcolname2rowcol
# map primary-key, column-name to row,column 
  { my($r_tbh,$pk,$col_name)= @_;
  
    return( $r_tbh->{pk_hash}->{$pk},
            $r_tbh->{column_hash}->{$col_name} );
  }


sub col2colname
# map row,column to primary-key, column-name
  { my($r_tbh,$col)= @_;
    
    return($r_tbh->{column_list}->[$col] );
  }
    
sub row2pk
# map row,column to primary-key, column-name
  { my($r_tbh,$row,$col)= @_;
    
    return($r_tbh->{pk_list}->[$row-1] );
  }

sub rowcol2pkcolname
# map row,column to primary-key, column-name
  { my($r_tbh,$row,$col)= @_;
    
    return($r_tbh->{pk_list}->[$row-1], $r_tbh->{column_list}->[$col] );
  }

sub get_pk_list
# requests a primary key list from the dbitable object
# the sort order is taken according to $r_tbh->{sort_columns}
  { my($r_tbh)= @_;
  
    my @pk= $r_tbh->{dbitable}->primary_keys(
	                     order_by=> $r_tbh->{sort_columns}
		                           );

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


sub initialize_sort_columns
  { my($r_tbh)= @_;
  
    return if ($r_tbh->{no_pk_cols});
    
    my @pks= @{$r_tbh->{pks}};
    
    for(my $i= $#pks; $i>=0; $i--)
      { put_new_sort_column_first($r_tbh, $pks[$i] ); };
  }

sub put_new_sort_column_first
# global variables used: NONE
# changes $r_tbh->{sort_columns}
  { my($r_tbh,$col_name)= @_;

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
    splice( @$r_cols,$i,1 );
    unshift @$r_cols,$col_name;    
  }  

sub get_dbitable
# global variables used: $sim_oracle_access
# sets $r_tbh->{dbitable}
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
  
    my $ntab= dbitable->new('table',$r_tbh->{dbh},
                           $r_tbh->{table_name},
                           );
    if (!defined $ntab)
      { tk_err_dialog($r_glbl->{main_menu_widget},
                      $dbitable::last_error);
	return;
      };	      
      
    $ntab->load();
			   
    return($ntab); 
  }

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
