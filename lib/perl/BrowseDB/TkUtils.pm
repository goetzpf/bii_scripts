#########################################################################
#   BrowseDB::TkUltils - a package for building tk-based dialogs
#
#   To learn more: enter "perldoc dbitk.pm" at the command prompt,
#   or search in this file for =head1 and read the text below it
#
#########################################################################

package BrowseDB::TkUtils;

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

our $VERSION     = '1.0';

sub About
  { my($r_glbl, $r_textvar)= @_;

    my $version = $r_glbl->{version};
    if (! defined($r_glbl->{version}))
      {
        $version = "0";
      }
    my $title = $r_glbl->{title};
    my $Top= MakeToplevel($r_glbl,
                         title=>"about $title $version",
                         popover=>1);
    my $h= $#$r_textvar+1;
    my $w=0;
    foreach my $l (@$r_textvar)
      { $w=length($l) if ($w<length($l)); };

    foreach my $l (@$r_textvar)
      { my $len= length($l);
        next if ($len>=$w);
        my $d= $w-$len;
        my $dl= int($d / 2);
        $l= (' ' x $dl) . $l . (' ' x ($d-$dl));
      };

    my $Text= $Top->Text(-width=> $w, -height=>$h);

    foreach my $l (@$r_textvar)
      { $Text->insert('end',$l . "\n"); };

    $Text->pack(-fill=>'both',-expand=>'y');
  }

#=======================================================
# routines that create Windows and Dialogs in a generic way
#=======================================================

# get text input from a simple entry field:
#_______________________________________________________

sub SimpleTextDialog
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

    my $Top= MakeToplevel($r_glbl,
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

    $Top->bind('<Return>',[ \&simple_text_dialog_finish, $r_glbl,$r_tbh,$tag ]);

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

sub simple_text_dialog_finish
# INTERNAL FUNCTION
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


sub MakeTextWidget
  { my($r_glbl,$title,$r_content)= @_;

    my %text;

    # my $Top= MainWindow->new(-background=>$r_glbl->{theme}->{background});
    my $Top= MakeToplevel($r_glbl,
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
    $Top->bind($Top,'<Control-s>'=> [\&text_save,$r_glbl,\%text]);
    $MnFile->add('command',
               -label=> 'Save',
               -accelerator => 'Control-s',
               -underline   => 0,
               -command=>  [\&text_save,"",$r_glbl,\%text]
              );

    # configure search-menu:
    $Top->bind($Top,'<Control-f>'=> [\&text_search,$r_glbl,\%text]);
    $MnSearch->add('command',
                 -label=> 'Find',
                 -accelerator => 'Control-f',
                 -underline   => 0,
                 -command=> [\&text_search,"",$r_glbl,\%text]
              );


    $Top->bind($Top,'<Control-g>'=>
               [\&text_search_next,$r_glbl,'next',\%text]);
    $MnSearch->add('command',
                 -label=> 'Find next',
                 -accelerator => 'Control-g',
                 -command=> [\&text_search_next,"",$r_glbl,'next',\%text]
              );

    $Top->bind($Top,'<Shift-Control-G>'=>
              [\&text_search_next,$r_glbl,'prev',\%text]);
    $MnSearch->add('command',
                 -label=> 'Find prev',
                 -accelerator => 'Shift-Control-G',
                 -command=> [\&text_search_next,"",$r_glbl,'prev',\%text]
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


sub text_search
# INTERNAL FUNCTION
# note: $widget is not really needed, it's just here
# since  this function can be called from via <bind>
  { my($widget, $r_glbl,$r_text)= @_;

    my $text= $r_text->{text_widget};

    my $Top= MakeToplevel($r_glbl,
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
                           err_dialog($r_glbl->{main_menu_widget},
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

sub text_search_next
# INTERNAL FUNCTION
# note: $widget is not really needed, it's just here
# since  this function can be called from via <bind>
  { my($widget, $r_glbl,$dir,$r_text)= @_;

    my $text= $r_text->{text_widget};

    if (!defined $r_text->{last_search})
      { err_dialog($r_glbl->{main_menu_widget},
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
      { err_dialog($r_glbl->{main_menu_widget},
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

sub text_save
# INTERNAL FUNCTION
# note: $widget is not really needed, it's just here
# since  this function can be called from via <bind>
  { my($widget,$r_glbl,$r_text)= @_;


    my $file= simple_file_menu(widget=> $r_text->{Top},
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
      { err_dialog($r_glbl->{main_menu_widget},
                      "unable to open $file for writing");
        return;
      };
    print F $text;
    if (!close(F))
      { err_dialog($r_glbl->{main_menu_widget},
                      "error while closing $file");
        return;
      };
  }

# a simple file menu for loading or storing of a file:
#_______________________________________________________

sub simple_file_menu
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


sub ObjectDialog
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

    my $Top= MakeToplevel($r_glbl,
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
               [\&object_dialog_finish, $r_glbl, $r_tbh, $tag]);

    $Listbox->bind('<Double-1>',
                   [\&object_dialog_finish, $r_glbl, $r_tbh, $tag]);

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

sub object_dialog_finish
# INTERNAL FUNCTION
# note: $widget is not really needed, it's just here
# since  this function can be called from via <bind>
  { my($widget,$r_glbl,$r_tbh,$tag)= @_;

    my $r_h= $r_tbh->{$tag};

    my $Top     = $r_h->{top};
    my $Listbox = $r_h->{listbox};

    my @selection= $Listbox->curselection();

    if (!@selection)
      { err_dialog($Top, "nothing selected");
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

sub MakeToplevel
# options:  title: window title
#           geometry: geometry string
#           parent_widget: parent-widget
#           popover: 1: if 1 open window just above parent widget
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

    if ($options{popover})
      { $Top->Popup(-popover=> $MainWidget ); };

    return($Top);
  }

# delete last inserted char in text widget:
#_______________________________________________________

sub delete_char
# INTERNAL FUNCTION
  { $_[0]->delete('insert - 1 char'); }

# remove useless key-bindings in text-widget:
#_______________________________________________________

sub clear_undef_keys
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
          { $this_widget->bind($k => [\&delete_char]); };
      }
  }

# scroll-wheel:
#_______________________________________________________

sub bind_scroll_wheel
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

sub SetBusy
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

sub Progress
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

# simple error-dialog:
#_______________________________________________________

sub err_dialog
  { my($parent,$message)= @_;

    my $dialog= $parent->Dialog(
                                 -title=>'Error',
                                 -text=> $message
                               );
    $dialog->Show();
  }

sub fatal_err_dialog
  { my($parent_widget,$message)= @_;

    my $dialog= $parent_widget->Dialog(
                                       -title=>'Fatal Error',
                                       -text=> $message
                                      );
    $dialog->Show();
    exit(0);
  }


1;

__END__

# Below is the short of documentation of the module.

=head1 NAME

BrowseDB::TkUtils - Perl-Tk utilities for browsedb

=head1 SYNOPSIS

  use BrowseDB::TkUtils;

=head1 DESCRIPTION

=head2 Preface

This module contains utilites and dialogs for the browsedb applicataion.
Most of these can only be used by that application, others however,
are more generic.

=head2 simple dialogs

=over 4

=item About()

    About( { title  => $window_title,
             version=> $program version },
           [ "this is the XXX application",
             "you can use it to do many interesting things..."
           ]
         )

This simple Dialog will show the title and version on top and print the output
of the given list, one elent per line.

=item SimpleTextDialog()

    simple_text_dialog($r_glbl,$r_tbh,%options)

This function opens a dialog window where the user can enter some
text. After the user has pressed <Return>, a callback function is
called with that text as a parameter.

C<$r_glbl> is the global hash that is needed by C<MakeToplevel()>
and a possible callback function. C<$r_tbh> is the table-hash as it
is used in browsedb.

These are known options:

=over 4

=item *

"title"

The title of the window.

=item *

"text"

The text that is displayed at the bottom of the widget, like
"enter a new value" or something.

=item *

"tag"

The tag-name under which the internal data of the widget is stored
in the table-hash (C<$r_tbh>). Note that this entry in the hash
is removed, when the window is closed.

=item *

"default"

The default value of the text-variable.

=item *

"callback"

This specifies the callback function that is called when the user
has entered some text. It has to be a reference to list. The first
element must be the reference to the function, the following elements
are optional and are arbitrary parameters for the function. Note that
the function is also gets C<$r_glbl>, C<$r_tbh> and the entered
text as a parameter. For example

  callback=> [\&tk_field_edit_finish,$abc,$def]

causes that the given function is called that way:

  tk_field_edit_finish($r_glbl,$r_tbh,$value,$abc,$def)

where C<$value> is the value that was entered.


=back


=item MakeTextWidget()

  MakeTextWidget($r_glbl,$title,$r_content);

This function displays a text in a separate window. The window has scroll
bars and a simple menu which allows to save the contents to a file and
to search strings within the text. It also defines some control-keys
as shortcuts for saving and searching.

C<$r_glbl> is the global hash that is needed by by C<MakeToplevel()>,
which is called by this function. C<$title> is the window-title and
C<$r_content> is a reference to a scalar variable which contains the text
to be displayed. The text may containt new-line characters and span
several lines.

=item simple_file_menu()

    simple_file_menu(%options};

This is a simple filedialog. The following options are known:

=over 4

=item *

"widget"

The parent widget. This option is mandatory

=item *

"type"

This option can be either "load" or "save". This option specifies wether
the dialog is opened for loading or for saving a file.

=item *

"extension"

This is the default-extension of the file(s). This option is mandatory.
Note that it must contain the dot, e.g.

  simple_file_menu(... ,extension => ".txt", ...)

=item *

"defaultdir"

This is the default directory for which files are displayed. This option
is optional.

=item *

"title"

This is just the title of the window (optional).

=item *

"extension_description"

This should be a short decription what the files with the
given extension are (optional).

=back

=item  ObjectDialog()

    ObjectDialog($r_glbl,$r_tbh,%options);

This dialog displays a vertical list of items from which the user
can choose one by simply double-clicking onto it.

C<$r_glbl> is the global hash that is needed by C<MakeToplevel()>
and a possible callback function. C<$r_tbh> is the table-hash as it
is used in browsedb.

The following options are known:

=over 4

=item *

"title"

This is just the window title (optional)

=item *

"text"

This is a text that is displayed at the bottom of the widget,
for example "double click to select".

=item *

"tag"

The tag-name under which the internal data of the widget is stored
in the table-hash (C<$r_tbh>). Note that this entry in the hash
is removed, when the window is closed.

=item *

"callback"

This specifies the callback function that is called when the user
has entered some text. It has to be a reference to list. The first
element must be the reference to the function, the following elements
are optional and are arbitrary parameters for the function. Note that
the function is also gets C<$r_glbl>, C<$r_tbh> and the entered
text as a parameter. For example

  callback=> [\&tk_field_edit_finish,$abc,$def]

causes that the given function is called that way:

  tk_field_edit_finish($r_glbl,$r_tbh,$value,$abc,$def)=

where C<$value> is the value that was selected.

=back

=back

=head2 Utilities

=over 4

=item MakeToplevel

  MakeToplevel($r_glbl,%options)

This function creates a new toplevel window. The window is
a Tk-MainWidget and is an heir of $r_glbl->{main_menu_widget}.
The new window is grouped with the Tk "group" command in one
group together with all other windows that were created with
this function.

The following options are known:

=over 4

=item *

"title"

This is just the window title.

=item *

"geometry"

This is a X11 geometry string, this parameter is optional.

=item *

"parent_widget"

This is the parent widget that the new widget is derived from.
If this parameter is missing, the parent widget is
C<$r_glbl->{main_menu_widget}>.

=item *

"popover"

If this option is "true" (defined and unequal to zero) the new widget
is placed over it's parent with the "Popup" method from Tk. Otherwise
it is placed somewhere else on the screen.

=back


=item clear_undefkey()

    clear_undefkey();

This fixes a bug with Tk text widgets. Certain control characters
let little squares appear at the cursor positions, which is not what
we want. This function fixes this effect for several control characters
(crtl-0 .. ctrl-9, crtl-q,r,u,g,s,l and ctrl-m)

=item bind_scroll_wheel

    bind_scroll_wheel($widget);

This function binds the mouse scroll wheel to the "yview" methos of
the given widget (it just makes the scroll wheel work on
widgets where it doesn't work as a default).

=item SetBusy

    SetBusy($r_glbl, $val);

Changes the mouse-cursor to a sand-clock and back again.
Used when an action may take a longer time. If C<$val> is true
the sandclock is shown, if it is false, the sandclock is removed.
Note that several calls of this function can be nested e.g.

  SetBusy($r_glbl,1);
    ...
    SetBusy($r_glbl,1);
    ...
    SetBusy($r_glbl,0);
    ...
  SetBusy($r_glbl,0);

in this case, only the outmost ones have an effect.

=item Progress()

    Progress($r_glbl, $val);

This is used to set the program's progress bar to a certain
value (C<$val>).

=item err_dialog()

    err_dialog($parent,$message);

This just displays a dialog box which is derived from the parent
widget.

=item fatal_err_dialog()

    fatal_err_dialog($parent,$message);

This just displays a dialog box which is derived from the parent
widget, but it does an "exit" when the box is closed.

=back

=head1 AUTHOR

S<Goetz Pfeiffer E<lt>pfeiffer@mail.bessy.deE<gt>>, 
S<Patrick Laux E<lt>laux@mail.bessy.deE<gt>>

=head1 SEE ALSO

perl-documentation, browsedb.pl (use the source... ;-)

=cut


