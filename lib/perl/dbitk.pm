#########################################################################
#   dbitk - a package for building tk-based dialogs
#
#   To learn more: enter "perldoc dbitk.pm" at the command prompt,
#   or search in this file for =head1 and read the text below it
#
#########################################################################

package dbitk;

use strict;

BEGIN {
    use Exporter   ();
    use vars       qw($VERSION);
    # set the version for version checking
    $VERSION     = 1.2;
};

use v5.6.0;

use Data::Dumper;

use Tk;
use Tk::Menu;
use Tk::Dialog;
use Tk::TextUndo;
use Tk::ROText;
use Tk::BrowseEntry;
use Tk::Listbox;
use Tk::FileSelect;
#use Tk::Balloon;

our $VERSION     = '1.2';

sub tk_quit
  {
# $r_glbl all the globals, if defined top_widget and $r_tbh so it is finally only a closing
# table_hash_window, otherwise it is a closing application call
# $noclose can be set to 1, then it is only a reload
# returns: <undef> if the window was closed
#           1 if the window was not closed (on request by the user)

    my($r_glbl, $r_tbh, $noclose)= @_;
    my $message = "\nor do you want to save your changes before?";
    my $choice;
    my $mode;
    my $Top;
    my @options;

    if (!defined ($r_tbh))
      { $Top = $r_glbl->{main_menu_widget};
        $mode= 'app-close';
        my $r_tab= $r_glbl->{all_tables};
        if ((!defined $r_tab) or (!%$r_tab)) # no open tables
          { $choice="close"; }
        else
          { $message = "Save your open tables as a collection before " .
                       "quitting?";
            @options= ('Save', 'Quit without save', 'Cancel');
          };
      }
    else
      {
        $Top = $r_tbh->{top_widget};
        if ($noclose)
          {
            $mode= 'table-reload';
            $message = "save changes in " .
                       $r_tbh->{table_type} . " " .
                       $r_tbh->{table_name} .
                       " before re-loading from the database ?";
            @options= ('Save to file', 'Reload without save', 'Cancel');
          }
        else
          {
            $mode= 'table-close';
            $message = "save changes in ".
                       $r_tbh->{table_type} . " " .
                       $r_tbh->{table_name} . "?";
            @options= ('Save to file', 'Save to database',
                       'Close without save', 'Cancel');
          }
      }

    if ($r_glbl->{fast_test})
      { $choice = "close";
      };

    if (($mode ne 'app-close') && (!table_changed($r_tbh)))
      { $choice = "close"; };

    while(!defined $choice)
      {


        my $DlgQuit = $Top->Dialog(
                    -title => 'Quit',
                    -text => $message,
                    -default_button => 'No',
                    -buttons => \@options,
                    );
        $choice = $DlgQuit->Show;

        if    ($choice eq 'cancel')
          { return 1; }
        elsif ($choice eq 'save')
          {
            if ($mode eq 'app-close')
              {
                if (!tk_save_collection ($Top, $r_glbl))
                  { $choice=undef;
                    next;
                  };
              }
            else
              { die "assertion: mode is \"$mode\""; };
          }
        elsif ($choice eq 'save to file')
          { if (!tk_save_to_file ("",$r_tbh))
              {
                $choice=undef;
                next;
              };
          }
        elsif ($choice eq 'save to database')
          { if (!cb_store_db($r_tbh))
              { $choice=undef;
                next;
              };
          }
        else
          { last; };
      }; # while()

    if (($mode eq 'app-close') && exists($r_glbl->{handle_sql_history}))
      {
        my $fh = $r_glbl->{handle_sql_history};
        $fh->flush();
        $fh->close();
      }


    if    ($mode eq 'table-reload')
      { return; }
    elsif ($mode eq 'table-close')
      { $Top->destroy();
        return;
      }
    elsif ($mode eq 'app-close')  # close application
      { my $r_tab= $r_glbl->{all_tables};

        if (defined $r_tab)
          { # now close every single table window
            foreach my $tab (keys %$r_tab)
              { if (tk_quit($r_glbl, $r_tab->{$tab}))
                  { return(1); };
              };
          };
        exit(0);
      }
    else
      {
        die "assertion: mode is \"$mode\"";
      }
  }

sub tk_about
  { my($r_glbl, $textvar)= @_;

    my $version = $r_glbl->{version};
    if (! defined($r_glbl->{version}))
      {
        $version = "0";
      }
    my $title = $r_glbl->{title};
    if (! defined($r_glbl->{title}) || $r_glbl->{title} == "")
      {
        $title = "this";
      }
    my $Top= mk_toplevel($r_glbl, "$textvar $title");
    my @text = $r_glbl->{$textvar};

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

    $Text->pack(-fill=>'both',-expand=>'y');
  }

#=======================================================
# routines that create Windows and Dialogs in a generic way
#=======================================================

# get text input from a simple entry field:
#_______________________________________________________

sub tk_simple_text_dialog
# ADD a WIDTH parameter here!
# known options:
# title
# callback -> callback after something was selected
# text -> text at the bottom of the widget
# tag -> tag-name for the dialog data that
#        is stored in the table-handle
# default -> default-value of variable
  { my($r_glbl,$r_tbh,%options)= @_;

    my $tag= $options{tag};

    die if (!defined $tag); # assertion

    my $tagcnt;
    while(exists $r_tbh->{$tag.$tagcnt})
      { $tagcnt++; };
    $tag.= $tagcnt;

    my %h;
    my $width=20;

    if (exists $options{default})
      { $h{string}= $options{default};
        my $l= length($options{default});
        $width= $l if ($l > $width);
        $width=80 if ($width>80);
      };

    my $Top= mk_toplevel($r_glbl,
                         title=>$options{title});

    my $entry=
       $Top->Entry(-textvariable => \$h{string},
                   -width=>$width
                  )->pack(-side=>'top',-fill=>'x',-expand=>'y');

    $entry->focus();

    if (exists $options{text})
      { $Top->Label(-text => $options{text}
                   )->pack(-side=>'top' ,-fill=>'y',
                          );
      };

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

    # my $Top= MainWindow->new(-background=>$r_glbl->{theme}->{background});
    my $Top= mk_toplevel($r_glbl,
                         title=>$r_glbl->{title});

    $text{Top}= $Top;

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
               -label=> 'Save',
               -accelerator => 'Control-s',
               -underline   => 0,
               -command=>  [\&tk_text_save,"",$r_glbl,\%text]
              );

    # configure search-menu:
    $Top->bind($Top,'<Control-f>'=> [\&tk_text_search,$r_glbl,\%text]);
    $MnSearch->add('command',
                 -label=> 'Find',
                 -accelerator => 'Control-f',
                 -underline   => 0,
                 -command=> [\&tk_text_search,"",$r_glbl,\%text]
              );


    $Top->bind($Top,'<Control-g>'=>
               [\&tk_text_search_next,$r_glbl,'next',\%text]);
    $MnSearch->add('command',
                 -label=> 'Find next',
                 -accelerator => 'Control-g',
                 -command=> [\&tk_text_search_next,"",$r_glbl,'next',\%text]
              );

    $Top->bind($Top,'<Shift-Control-G>'=>
              [\&tk_text_search_next,$r_glbl,'prev',\%text]);
    $MnSearch->add('command',
                 -label=> 'Find prev',
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

    $text_widget->insert('end',$$r_content) if (defined $r_content);

    $text_widget->pack(-fill=>'both',-expand=>'y');

    return(\%text);
  }


sub tk_text_search
# note: $widget is not really needed, it's just here
# since  this function can be called from via <bind>
  { my($widget, $r_glbl,$r_text)= @_;

    my $text= $r_text->{text_widget};

    my $Top= mk_toplevel($r_glbl,
                         parent_widget=> $r_text->{Top},
                         title=>"search");

    $r_text->{search_widget}= $Top;

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
                                  type=> 'Save',
                                  extension=>'.txt',
                                  defaultdir=>$r_glbl->{dir},
                                  title=>'Save text',
                                  extension_description=>
                                              'ASCII text files');

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

    my $tagcnt="";
    while(exists $r_tbh->{$tag.$tagcnt})
      { $tagcnt++; };
    $tag.= $tagcnt;

    my %h;

    my $Top= mk_toplevel($r_glbl,
                         title=>$options{title});

    my $FrTop = $Top->Frame(-borderwidth=>2,
                           -background=>$r_glbl->{theme}->{background}
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

# create new toplevel window:
#_______________________________________________________

sub mk_toplevel
# options:  title: window title
#           geometry: geometry string
#           parent_widget
  { my($r_glbl,%options)= @_;
    my $MainWidget;

    if (exists $options{parent_widget})
      { $MainWidget= $options{parent_widget}; }
    else
      { $MainWidget= $r_glbl->{main_menu_widget}; };

    my $Top= $MainWidget->Toplevel(-background=>$r_glbl->{theme}->{background});

    # add new toplevel widget to the BrowseDB group
    # looks nice in gnome-panel and kde-panel
    $Top->group($r_glbl->{main_menu_widget});

    if (exists $options{title})
      { $Top->title($options{title}); };

    if (exists $options{geometry})
      { $Top->geometry($options{geometry}); };

    return($Top);
  }

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

    $widget->bind('<Button-4>',['yview','scroll',-5,'units']);
    $widget->bind('<Button-5>',['yview','scroll', 5,'units']);

    $widget->bind('<Shift-Button-4>',['yview','scroll',-1,'units']);
    $widget->bind('<Shift-Button-5>',['yview','scroll', 1,'units']);

    $widget->bind('<Control-Button-4>',['yview','scroll',-1,'pages']);
    $widget->bind('<Control-Button-5>',['yview','scroll', 1,'pages']);

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

        if ($r_glbl->{os} ne "MsWin32")
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

1;

__END__

# Below is the short of documentation of the module.

=head1 NAME

dbitk - an Perl module for building tk-GUI.

=head1 SYNOPSIS

  use dbitable;

=head1 DESCRIPTION

=head2 Preface

This module contains main event/callback and dialog routines which is used
in browsedb. They using the tk enhancement to build GUI-elements.

At the moment you will found subs. May be converting in future to objects.

Most of the subs need to sets the global hash for instance $r_glbl to bind
the window to the parent window or getting the content of global context.

=head2 Dialogs

=item tk_quit()

    $return = tk_quit ($r_glbl, $r_tbh, $noclose);

Need $r_glbl and $r_tbh for checking the status of childs and parent windows.

As options u need $r_glbl all the globals, if defined top_widget and $r_tbh
so it is finally only a closing table_hash_window, otherwise it is a
closing application call $noclose can be set to 1, then it is only a reload
The routine returns <undef> if the window was closed and 1 if the window
was not closed (on request by the user)

need:
=item tk_about()

    $r_glbl->{title} = "abc";
    $r_glbl->{version} = "0123";
    $r_glbl->{textvar} = ("abc", "def", "ghi ...);
    tk_about($r_glbl, "textvar");

This simple Dialog will show the title and version on top and print the output
of hash content list wich is saved in textvar. So you can output different
text as normal ok-window.

=item tk_simple_text_dialog()

    tk_simple_text_dialog($title, $callback, $text, $tag, $dialog);
    tk_simple_text_dialog_finish ($widget, $r_glbl, $r_tbh, $tag);

ADD a WIDTH parameter here!
known options:
    title
    callback -> callback after something was selected
    text -> text at the bottom of the widget
    tag -> tag-name for the dialog data that
        is stored in the table-handle
    default -> default-value of variable

    sub tk_simple_text_dialog_finish is the routine for resuming operations.

=item make_text_widget()

    make_text_widget($r_glbl,$title,$r_content);

Well needs global hash $r_glbl the title $title and the content $content
Additional the menu will be enhance for the handling of text like cut 'n paste.
Also the short cuts will be bind.

    tk_text_search($widget, $r_glbl,$r_text);
    tk_text_search_next($widget, $r_glbl, $dir, $r_text)= @_;

tk_text_search build a search dialog for find or search in widgets like text
widget given in $widget ($widget is not really needed, it's just here
since  this function can be called from via <bind>) and the text in $r_text.

    tk_text_save($widget, $r_glbl, $r_text);

Save text $r_text at parent widget $widget and infos from $r_glbl (global hash).
If you want to edit the text widget and want to save selected text in a
textwidget, use this sub.

=item tk_simple_file_menu()

    tk_simple_file_menu(%options};

This is a dialog for filehandling dialog. It is enhanced for real using
Here are the options:
    type: 'load' or 'save'
    extension: extension
    defaultdir: dir
    title: title
    extension_description
    widget: parent widget

=item  tk_object_dialog()

    tk_object_dialog($r_glbl,$r_tbh,%options);
    tk_object_dialog_finish($widget, $r_glbl, $r_tbh, $tag);

tk_object_dialog builds the dialogwhich is  more for debugging than useable
dialog. It will show content of objects. Here are the options

    title
    items -> reference to a list of items
    text -> text at the bottom of the widget
    callback -> callback after something was selected
    tag -> tag-name for the dialog data that is stored in the table-handle

tk_object_dialog_finish made the callback actions for object dialog.
(note: $widget is not really needed, it's just here
 since  this function can be called from via <bind>)

=head2 Utilities

=item mk_toplevel

    mk_toplevel

Create a top_level window and make as positioning.
Options are
    title: window title
    geometry: geometry string
    parent_widget

=item sub tk_delete_char
  { $_[0]->delete('insert - 1 char'); }

# remove useless key-bindings in text-widget:
#_______________________________________________________

=item tk_clear_undefkey()

    tk_clear_undefkey();

Undefine key bindings, that not will be used in text widgets.

List:   Control-<0-9|q|r|u|g|s|l|m>

=item tk_bind_scroll_wheel

    tk_bind_scroll_wheel($widget);

Bind all scroll variation of normal, shiftet and controled to the widget $widget.

=item tk_set_busy

    tk_set_busy($r_glbl, $val);

Yepp, here the classical Neumann prpblem hold on all till the programm
pointer is free.

=item tk_progress()

    tk_progress ($r_glbl, $val);

Build a nice Progress and updates with teh percentage in $val.