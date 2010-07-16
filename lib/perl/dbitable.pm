package dbitable;

# This software is copyrighted by the
# Helmholtz-Zentrum Berlin fuer Materialien und Energie GmbH (HZB),
# Berlin, Germany.
# The following terms apply to all files associated with the software.
#
# HZB hereby grants permission to use, copy and modify this
# software and its documentation for non-commercial, educational or
# research purposes provided that existing copyright notices are
# retained in all copies.
#
# The receiver of the software provides HZB with all enhancements,
# including complete translations, made by the receiver.
#
# IN NO EVENT SHALL HZB BE LIABLE TO ANY PARTY FOR DIRECT, INDIRECT,
# SPECIAL, INCIDENTAL OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE
# OF THIS SOFTWARE, ITS DOCUMENTATION OR ANY DERIVATIVES THEREOF, EVEN
# IF HZB HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
# HZB SPECIFICALLY DISCLAIMS ANY WARRANTIES, INCLUDING, BUT NOT LIMITED
# TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
# PURPOSE, AND NON-INFRINGEMENT. THIS SOFTWARE IS PROVIDED ON AN "AS IS"
# BASIS, AND HZB HAS NO OBLIGATION TO PROVIDE MAINTENANCE, SUPPORT,
# UPDATES, ENHANCEMENTS OR MODIFICATIONS.


#########################################################################
#   dbitable - a object oriented package for managing database tables
#
#   To learn more: enter "perldoc dbitable.pm" at the command prompt,
#   or search in this file for =head1 and read the text below it
#
#########################################################################

#use v5.6.0;

use strict;

BEGIN {

       #use DBI;
       if (!$ENV{DBITABLE_NO_DBI})
         { require DBI;
           import DBI;
         };
      };
use dbdrv 1.2;

use Data::Dumper;
use Text::Wrap;
use Text::ParseWords;
use File::Spec;
use Cwd;
use IO::Scalar;
use IO::File;

# use DBD::AnyData;

our $VERSION     = '2.1';

our $export_version= "1.0";

our $default_dbdrv= "Oracle"; # used by dbdrv.pm
our $dbdrv_loaded;

our $db_trace  =0;
our $prelim_key=0;
our $sim_delete=1; # deletions in the DB are only simulated

our $last_error;

my $proxy_patch=1;

my $mod= "dbitable";

my $slim_format=0; # do not save all elements of "table" element

my $key_fact= 100000; # for pseudo-random key generation
                      # the primary keys in the table should not
                      # be greater than this value !

my $max_colwidth= 40; # used for pretty-format (store to file)

# variables for the gen_sort function:
my $gen_sort_href;
my @gen_sort_cols;
my $gen_sort_r_coltypes;
my @gen_sort_colmaps; # hashes that map a column-value to another
                      # always strings

sub std_database_handle
  { return($dbdrv::std_dbh); }

sub load_dbdrv_driver
  { my($driver_name)= @_;

    return if ($dbdrv_loaded);
    $driver_name= $default_dbdrv if (!defined $driver_name);
    if (!dbdrv::load($driver_name))
      { dbdrv::dberror($mod,'load_dbdrv_driver',__LINE__,
                       "dbdrv::load failed");
        return;
      };
    $dbdrv_loaded=1;
    return(1);
  }

sub connect_database
# if dbname=="", use DBD::AnyData
  { my($dbname,$username,$password)= @_;

    load_dbdrv_driver();
    return(dbdrv::connect_database($dbname,$username,$password));
  }

sub disconnect_database
  { return(dbdrv::disconnect_database(@_)); }

sub new
  { # perl-Kochbuch, S. 486 "Klassen,Objekte und Ties
    my $proto= shift;

    my $class;
    my $parent;

    if (ref($proto)) # a parent object is given
      { $parent= $proto;
        $class = ref($proto);
      }
    else             # no parent, just the class-name is given
      { $class= $proto; }; # parent remains undef

    my $self;

    # the base-class mechanism is not yet tested!
#    if (@ISA && $class->SUPER::can('new')
#      { $self= $class->SUPER::new(@_); }
#    else
      { $self= {}; };

    bless($self, $class);

    if (defined $parent)
      { my $newtype= shift; # this is optional

        # deep copy of the parent data-structure
        foreach my $k (keys %$parent)
          {
            if ($k eq '_lines')
              {
                my %h;
                my $r_src_lines= $parent->{$k};
                foreach my $pk (keys %{$r_src_lines})
                  { my @a= @{$r_src_lines->{$pk}};
                    $h{$pk}= \@a;
                  };
                $self->{$k}= \%h;
                next;
              };
            my $ref= ref($self->{$k});
            if (!$ref)
              { $self->{$k}= $parent->{$k};
                next;
              };
            if ($ref eq 'HASH')
              { my %h= %{$parent->{$k}};
                $self->{$k}= \%h;
                next;
              };
            if ($ref eq 'ARRAY')
              { my @l= @{$parent->{$k}};
                $self->{$k}= \@l;
                next;
              };
          };

        if (defined $newtype)
          {
# the following is better done always, regardless wether the
# type is changed. For example, the user might simply want to change
# the database-handle, not the type
#           if ($newtype ne $self->{_type})
#             {
                if ($newtype eq 'file')
                  { if (!$self->init_filetype($newtype,@_))
                      { return; };
                  }

                elsif (($newtype eq 'table') || ($newtype eq 'view') ||
                      ($newtype eq 'new_table')
                      )
                  { if (!$self->init_tableviewtype($newtype,@_))
                      {
                        return;
                      };
                  }
                else
                  { dbdrv::dberror($mod,'new',
                                   __LINE__,"unknown type: $newtype");
                    return;
                  };
#              };
          };
        return($self);
      }
    else
      { # direct initialization

        my $type= shift; $type= lc($type);
        $self->{_type}= $type;

        if   ($type eq 'file')
          { if (!$self->init_filetype('file',@_))
              { return; };
          }

        elsif (($type eq 'table') || ($type eq 'view'))
          { if (!$self->init_tableviewtype($type,@_))
              { return; };
          }
        else
          { dbdrv::dberror($mod,'new',__LINE__,
                           "unknown dbitable-type: \"$type\"");
            return;
          };
        return($self);
      };
    return($self);
  }

sub init_filetype
#internal
  { my $self= shift;

    $self->{_type}= shift;
    my $filename= shift;

    if (!defined $filename)
      { dbdrv::dberror($mod,'init_filetype',__LINE__,
                       "type \'file\': filename parameter missing");
        return;
      };

    my $fref= ref($filename);
    if (($fref ne "") && ($fref ne 'SCALAR'))
      { dbdrv::dberror($mod,'init_filetype',__LINE__,
                       "type \'file\': filename must be scalar or scalar reference");
        return;
      };

    $self->{_filename}= $filename;
    my $tag= shift;
    if (!defined $tag)
      { dbdrv::dberror($mod,'init_filetype',__LINE__,
                       "type \'file\': tag parameter missing");
        return;
      };


    $self->{_tag}= $tag;
    return(1) if (!@_); # optional, primary key + column-list

    return( $self->init_columns(@_) );
  }

sub init_tableviewtype
#internal
# the type-parameter was already checked
  { my $self= shift;
    my $type= shift;
    $self->{_type}= $type;

    my $dbh= shift;

    $dbh= dbdrv::check_dbi_handle($dbh);
    return if (!defined $dbh);

    $self->{_dbh}= $dbh;

    # if self->{_table} already exists, take this if no table
    # parameter is found in the argument-list
    my $table= shift;
    if ((!defined $table) || ($table eq ""))
      { if (exists $self->{_table})
          { $table= $self->{_table}; }
      };
    if (!defined $table)
      { $last_error= "table name missing";
        return;
      };

    if ($type eq 'table')
      { my $user;
        $user= $dbdrv::std_username if ($dbh==$dbdrv::std_dbh);
        if (!dbdrv::check_existence($dbh,$table,$user))
          { $last_error= "table \"$table\" doesn\'t exist";

            return;
          };
        $self->{_owner} = $user;
      };

    # if self->{_pks} already exists, take this if no primary-key
    # parameter is found in the argument-list
    my $primary_key_par= shift;
    my @primary_keys;

    if ((defined $primary_key_par) && ($primary_key_par ne ""))
      {
        if (!ref($primary_key_par))
          { push @primary_keys, $primary_key_par; }
        elsif (ref($primary_key_par) eq 'ARRAY')
          { @primary_keys= @$primary_key_par; }
        else
          { dbdrv::dberror($mod,'init_tableviewtype',__LINE__,
                           "error: primary key is neither scalar not " .
                           "ARRAY reference");
            return;
          };
      };

    if (!@primary_keys)
      {
        if (exists $self->{_pks})
          {
            @primary_keys= @{$self->{_pks}};
          }
        else
          {
            if    ($type eq 'table')
              { # try to determine primary key by a tricky SQL statement:

                my $user;
                $user= $dbdrv::std_username if ($dbh==$dbdrv::std_dbh);

                @primary_keys= dbdrv::primary_keys($dbh,$user,$table);
                if (!@primary_keys)
                  { $last_error= "error: primary key(s) not found via SQL";

                    # use a "simulated" primary key, with is just
                    # a line counter
                    @primary_keys= (undef);
                    $self->{_counter_pk}= 1;
                    # a "undef" in the list indicates a counter-pk
                  };

              }
            elsif ($type eq 'view')
              { # use a "simulated" primary key, with is just
                # a line counter
                @primary_keys= (undef);
                $self->{_counter_pk}= 1;
                # a "undef" in the list indicates a counter-pk
              };
          };
      };

    if (!@primary_keys)
      {
        dbdrv::dberror($mod,'init_tableviewtype',__LINE__,
                       "primary key name(s) missing");
        return;
      };


    # change primary key(s) to upper case :
    foreach my $p (@primary_keys)
      { $p= uc($p); };

    $self->{_table}= $table;
    $self->{_pks}   = \@primary_keys;
    if ($#primary_keys>0)
      { $self->{_multi_pk}=1; };

    my $sql_statement= "select * from $table";
    if ($type eq 'view')
      { $sql_statement= shift;
        if (!defined $sql_statement)
          { dbdrv::dberror($mod,'init_tableviewtype',__LINE__,
                           "sql-statement missing");
            return;
          };
      };
    $self->{_fetch_cmd}= $sql_statement;

    if ($type eq 'new_table') # no column-lookup in this case
      { $self->{_type}= 'table'; # change type to 'table'
        return;
      };
    # no SQL Trace here:

    my $sth;

    if (!$proxy_patch)
      { $sth= $dbh->prepare($self->{_fetch_cmd}); }
    else
      { my $cmd= $self->{_fetch_cmd};
        $cmd=~ s/\bwhere.*//i;    # remove "where" part
        $cmd=~ s/\border\s+by//i; # remove "where" part

        my($st,$at)= dbdrv::query_limit_rows_str(1);
        if ($at eq 'add_after_where')
          { $cmd.= " where $st"; }
        else
          { $cmd.= " $st"; };

        $sth= $dbh->prepare($cmd);
      };

    if (!$sth)
      {
        dbdrv::dbwarn($mod,'init_tableviewtype',__LINE__,
                     "prepare failed, error-code: \n$DBI::errstr");
        #dbdrv::dberror($mod,'init_tableviewtype',__LINE__,
        #               "prepare failed, error-code: \n$DBI::errstr");
        return;
      };

    if ($proxy_patch)
      { if (!$sth->execute())
          {
            dbdrv::dbwarn($mod,'init_tableviewtype',__LINE__,
                         "execute failed, error-code: \n$DBI::errstr");
            #dbdrv::dberror($mod,'init_tableviewtype',__LINE__,
            #               "prepare failed, error-code: \n$DBI::errstr");
            $sth->finish();
            return;
          };
      };

    my $colcount=0;
    my @column_list= @{$sth->{NAME_uc}};

    my @x= dbdrv::get_simple_column_types($dbh,$sth,$table);

    if ($proxy_patch)
      { $sth->finish(); };

    $self->{_types}= \@x;

#warn join("|",@x);
#print Dumper($dbh->type_info_all);
    if ($type eq 'table')
      { my $r_col_prop= dbdrv::column_properties($dbh,$self->{_owner},$table);
        $self->{_column_properties}= $r_col_prop if (defined $r_col_prop);
      };


    return($self->init_columns(\@primary_keys,@column_list));
    # ^^^ sets also $self->{_pkis}
  }

sub init_columns
#internal
# no sql queries in this function!
  { my $self= shift;
    my ($pk_par,@columns)= @_;

    my @primary_keys;

    if (!ref($pk_par))
      { push @primary_keys, $pk_par; }
    elsif (ref($pk_par) eq 'ARRAY')
      { @primary_keys= @$pk_par; }
    else
      { dbdrv::dberror($mod,'init_columns',__LINE__,
                       "error: primary key is neither scalar not " .
                       "ARRAY reference");
        return;
      };

    # change primary key(s) to upper case :
    foreach my $p (@primary_keys)
      { $p= uc($p); };

    foreach my $c (@columns)
      { $c= uc($c); };

    my $exist_columns= $self->{_column_list};
    my $exist_pks= $self->{_pks};
    if (defined $exist_pks)
      { if (!lists_equal($exist_pks,\@primary_keys))
          { dbdrv::dberror($mod,'init_columns',__LINE__,
                           "error: existing primary key(s)" .
                           " != new primary key (s)");
            return;
          };
      }
    else
      { $self->{_pks}= \@primary_keys;
        if ($#primary_keys>0)
          { $self->{_multi_pk}=1; };
      };

    if (defined $exist_columns)
      { if (!lists_equal($exist_columns,\@columns))
          { dbdrv::dberror($mod,'init_columns',__LINE__,
                           "error: existing columns != new columns:\n" .
                           "exist: " . join(",",@$exist_columns) . "\n" .
                           "new  : " . join(",",@columns));
            return;
          };
      }
    else
      { $self->{_column_list}= \@columns;
        my $i=0;
        my %h= map { $_ => $i++ } @columns;
        $self->{_columns}= \%h;
      };

    my @pki;
    my $i;
    my $r_col_hash= $self->{_columns};

    # ref to the list of column-types:
    my $r_types= $self->{_types};

    my $pk_is_numeric=1;

    if ($self->{_counter_pk})
      { @pki= (undef); }
    else
      { foreach my $pk (@primary_keys)
          { $i= $r_col_hash->{$pk};
            if (!defined $i)
              { dbdrv::dberror($mod,'init_columns',__LINE__,
                               "assertion failed, primary key " .
                               "column $pk not found");
                return;
              };
            $pk_is_numeric=0 if ($r_types->[$i] ne 'number');
            push @pki, $i;
          };
      };
    $self->{_pk_is_numeric}= $pk_is_numeric;
    $self->{_pkis}= \@pki;
    return(1); # OK
  }


sub load
  { my $self= shift;
    my $type= $self->{_type};

    if (($type eq 'table') || ($type eq 'view'))
      { return( $self->load_from_db(@_) ); }
    if ($type eq 'file')
      { return( $self->load_from_file(@_) ); };
    dbdrv::dberror($mod,'load',__LINE__,"unknown type: $type");
  }


sub store
  { my $self= shift;
    my $type= $self->{_type};

    if (($type eq 'table') || ($type eq 'view'))
      { return( $self->store_to_db(@_) ); }
    if ($type eq 'file')
      { return( $self->store_to_file(@_) ); };
    dbdrv::dberror($mod,'store',__LINE__,"unknown type: $type");
  }

sub export_csv
# known options: 'order_by' => column-name   OR
#                   'order_by' => [column-name1,column-name2...]
#                'col_selection'=> [column-name1,column-name2]
#                'pk_selection'=> [pk1,pk2, ...pkn]
#                'col_maps => { colname1 => \%col_map1,
#                               colname2 => \%col_map2
#                                   ...
#                               colnamen => \%col_mapn
#                             }
#                        not all column-maps must be defined
  { my $self= shift;
    my $filename= shift;
    my %options= @_;
    my $sep= ';';
    my $is_stdout;

    my $is_multi_pk= $self->{_multi_pk};

    $self->gen_sort_prepare(\%options);

    my $r_columns    = $self->{_columns};
    my $r_column_list= $options{col_selection};
    if (!defined $r_column_list)
      { $r_column_list= $self->{_column_list}; };


    my @col_i_list;
    for(my $i=0; $i<= $#$r_column_list; $i++)
      { push @col_i_list, $r_columns->{ $r_column_list->[$i] }; };

#warn join("|",@col_i_list);

    local(*G);

    if ((!defined $filename) || ($filename eq ""))
      { *G= *STDOUT;
        $is_stdout= 1;
      }
    else
      { if (!open(G,">$filename"))
          { dbdrv::dbwarn($mod,'export_csv',__LINE__,
                          "unable to write $filename");
            return;
          };
      };
    print G join($sep,@$r_column_list),"\n";

    my $r_l= $self->{_lines};

    my $r_keylist= $options{pk_selection};
    if (!defined $r_keylist)
      { $gen_sort_href= $r_l;
        my @k= sort gen_sort (keys %$r_l);
        $r_keylist= \@k;
      };

    my @cells;
    my @strtype= map { ($_ eq 'number') ? 0 : 1 } @{$self->{_types}};
    foreach my $pk (@$r_keylist)
      { my $r_line= $r_l->{$pk};

        @cells= ();

        foreach my $i (@col_i_list)
          { push @cells, $r_line->[$i]; };

        my $c;
        for(my$i=0; $i<= $#cells; $i++)
          { $c= $cells[$i];
            if ($strtype[$i])
              { $c= '"' . $c . '"'; };
            $c=~ s/'/\\'/g; # quote quotes ("'" -> "\'")
            # if ($c=~ /[\|;]/);
            $cells[$i]= $c;
          };

        print G join($sep,@cells),"\n";
      };
    if (!$is_stdout)
      { if (!close(G))
          { dbdrv::dbwarn($mod,'export_csv',__LINE__,
                         "unable to close $filename");
            return;
          };
      };
  }

sub import_csv
  { my $self= shift;
    my $filename= shift;
    my %options= @_;

    my $sep= ';';

    local(*G);

    if (!open(G,"$filename"))
      { dbdrv::dbwarn($mod,'import_csv',__LINE__,
                      "unable to read $filename");
        return;
      };

    my $line= <G>;
    if (!$line)
      { dbdrv::dbwarn($mod,'import_csv',__LINE__,
                      "unable to read 1st line from $filename");
        return;
      };
    $line=~ s/\s+$//;
    $line= uc($line);
    my @cols= split($sep,$line);
    my $c_index= 0;
    my $table_columns= $self->{_columns};
    my $column_no= $#{$self->{_column_list}} + 1;
#warn "column-no: $column_no";

    my $r_pkis= $self->{_pkis};
    my $r_self_lines  = $self->{_lines};

    my %file2tabindex;
    for(my $i=0; $i<= $#cols; $i++)
      { my $c= $cols[$i];
        my $table_index= $table_columns->{$c};
        next if (!defined($table_index));
        $file2tabindex{$i}= $table_index;
      };

    if (!%file2tabindex)
      { dbdrv::dbwarn($mod,'import_csv',__LINE__,
                     "no columns found to import !");
        close(G);
        return;
      };

#warn "mapping:",join("|",%file2tabindex);

    my %found_pk_list;
    while($line=<G>)
      { chomp($line);
        next if ($line=~ /^[\s\t]*$/);
        #my @a= split($sep,$line);

        my @a = &parse_line('[;]', 0, $line);

        my @new;
        foreach my $i (keys %file2tabindex)
          { $new[$file2tabindex{$i}]= $a[$i]; };

#warn "new-array:",join("|",@new),"\n";
        my $self_pk = compose_primary_key_str($r_pkis,\@new);
        if (!defined $self_pk)
          { dbdrv::dbwarn($mod,'import_csv',__LINE__,
                         "warning: no primary key found in csv");
            next;
          };
        if ($found_pk_list{$self_pk})
          { dbdrv::dbwarn($mod,'import_csv',__LINE__,
                         "warning: duplicate primary keys found in csv");
            next;
          };
        $found_pk_list{$self_pk}=1;

        my $r_self_line= $r_self_lines->{$self_pk};
        if (defined $r_self_line)
          { my $updated;
            for(my $i=0; $i<= $#new; $i++)
              { next if (!defined $new[$i]);
                if ($r_self_line->[$i] ne $new[$i])
                  { $r_self_line->[$i]= $new[$i];
                    $updated=1;
                  };
              };
            $self->{_updated}->{$self_pk}= 1 if ($updated);
          }
        else
          { for(my $i=0; $i< $column_no; $i++)
              { $new[$i]= "" if (!defined $new[$i]); };
            $r_self_lines->{$self_pk}= \@new;
            $self->{_inserted}->{$self_pk}= 1;
            $self->{_aliases}->{$self_pk}= $self_pk;
          };
      };

    if (!close(G))
      { dbdrv::dbwarn($mod,'import_csv',__LINE__,
                     "unable to close $filename");
        return;
      };
  }


sub import_table
# options: mode=> 'add_lines' or 'set_lines
#          primary_key=> 'generate', 'preserve'
#          column_aliases=> hash reference
  { my $self= shift;
    my $other= shift;
    my %options= @_;
    my $v;

    my $is_multi_pk  = $self->{_multi_pk};
    my $counter_pk   = $self->{_counter_pk};
    my $pk_is_numeric= $self->{_pk_is_numeric};
    my $single_pki;

    $v= $options{mode};
    if    (!defined $v)
      { $options{mode}= 'add_lines'; }
    elsif (($v ne 'add_lines') && ($v ne 'set_lines'))
      { dbdrv::dberror($mod,'import_table',__LINE__,
                       "unknown import-mode:$v");
        return;
      };

    $v= $options{primary_key};
    if    (defined $v)
      { if (($v ne 'preserve') && ($v ne 'generate'))
          { dbdrv::dberror($mod,'import_table',__LINE__,
                           "unknown primary-key-mode:$v");
            return;
          };
      }
    else
      { if (!$is_multi_pk && $pk_is_numeric)
          { $options{primary_key}= 'generate'; }
        else
          { $options{primary_key}= 'preserve'; }
      };

    if (($is_multi_pk) && ($v eq 'generate'))
      { dbdrv::dberror($mod,'import_table',__LINE__,
                       "primary_key=generate not allowed for tables\n" .
                       "with more than one primary key column!!");
        return;
      };

    if (($counter_pk) && ($v ne 'generate'))
      { dbdrv::dberror($mod,'import_table',__LINE__,
                       "primary_key=preserve not allowed for tables\n" .
                       "with counter-primary key");
        return;
      };

    my $r_column_aliases= $options{column_aliases};
      # self->other column mapping
      # may be omitted if tables have the same columns
    my $self_columns = $self->{_columns};
    my $other_columns= $other->{_columns};

    my @pkis= @{$self->{_pkis}};

    if (!$is_multi_pk)
      { $single_pki= $pkis[0]; };

    my $self_column_no= $#{$self->{_column_list}} + 1;

    my %col_mapping;

    foreach my $scol (keys %$self_columns)
      { my $s_i= $self_columns->{$scol}; # self col-index
        my $o_i;
        $o_i= $other_columns->{$scol};   # other col-index
        if (defined $r_column_aliases) # if col-mapping exists
          { # test wether a column-alias for this column exists
            my $o= $r_column_aliases->{$scol};
            if (defined $o)
              { $o_i= $other_columns->{$o}; };
          };

        if (defined $o_i)               # if an associated col was found:
          { $col_mapping{$s_i}= $o_i; };
      };

    my @mapped_pkis;
    if (!$counter_pk)
      { foreach my $pki (@pkis)
          { my $mpki= $col_mapping{$pki};
            if (!defined $mpki)
              { dbdrv::dberror($mod,'import_table',__LINE__,
                               "error: no mapping for primary key " .
                               "(index $pki) defined, cannot import");
                return;
              };
            push @mapped_pkis, $mpki;
          };
      };

    my $r_other_lines= $other->{_lines};
    my $r_self_lines  = $self->{_lines};
    my $r_self_aliases= $self->get_hash("_aliases");

    my %found_lines;

    foreach my $other_pk (keys %{$r_other_lines})
      { my $r_other_line= $r_other_lines->{$other_pk};

        # now find the corresponding line in THIS table:
        my $self_pk;
        my $r_self_line;

        if ($counter_pk)
          { $self_pk= $self->new_counter_key(); }
        else
          { $self_pk = compose_primary_key_str(\@mapped_pkis,$r_other_line);
          };

        $r_self_line= $r_self_lines->{$self_pk};
        my $operation;
        if (!defined $r_self_line)
          { # a new line has to be inserted
            if (!$counter_pk)
              { if ($options{primary_key} eq 'generate')
                  { $self_pk= $self->new_prelim_key();
                    $self->{_preliminary}->{$self_pk}= 1;
                  };
              };
            my @l;
            $r_self_line= \@l;
            $r_self_lines->{$self_pk}= \@l;
            $r_self_aliases->{$self_pk}= $self_pk;
            if ((!$counter_pk) && (!$is_multi_pk))
               # only one primary key, set it in the table
              { $r_self_line->[$single_pki]= $self_pk; };
            $self->{_inserted}->{$self_pk}= 1;
            $operation= 'inserted';
          };
        $found_lines{$self_pk}=1;

        for(my $i=0; $i<$self_column_no; $i++)
          {
            if ((!$counter_pk) && (!$is_multi_pk))
                # only one primary key, set it in the table
              { # then the primary key field is already set
                next if ($i==$single_pki);
              };

            my $other_val="";
            my $index= $col_mapping{$i};
            if (defined $index) # if a col-mapping exists
              { $other_val= $r_other_line->[ $index ]; };
            # $other_val= "" if (!defined $other_val);
            if (!$operation)
              {
                if ($r_self_line->[$i] ne $other_val)
                  {
                    $operation= "updated";
                  };
              };
            $r_self_line->[$i]= $other_val;
          };
        if ($operation eq "updated")
          { $self->{_updated}->{$self_pk}= 1; };
      };
    # delete lines not found in the "other" table
    if ($options{mode} eq 'set_lines')
      { foreach my $self_pk (keys %{$r_self_lines})
          { if (!exists $found_lines{$self_pk})
              { delete $r_self_lines->{$self_pk};
                $self->{_deleted}->{$self_pk}=1;
              };
          };
        my $r_aliases= $self->{_aliases};
        if (defined $r_aliases)
          { foreach my $key (keys %$r_aliases)
              { if (!exists $found_lines{$r_aliases->{$key}})
                  { delete $r_aliases->{$key}; }; # delete was missing
              };
          };
      };
  }

sub mark_inserted
  { my $self= shift;
    my $pk= shift;
    my $r_l= $self->{_lines};

    return if (!defined $r_l);

    if (defined $pk)
      { if (exists $r_l->{$pk})
          { $self->{_inserted}->{$pk}=1; };
      }
    else
      { my %h;
        foreach my $pk (keys %{$r_l})
          { $h{$pk}= 1; };
        $self->{_inserted}= \%h;
        # since everything is marked, the old "inserted" hash can
        # safely be deleted
      };
  }

sub primary_keys
#                'col_maps => [\%col_map1,\%col_map2 ... \%col_mapn]
#                              col-map references may be "undef"
  { my $self= shift;
    my %options= @_;

    if (!%options)
      { return(keys %{$self->{_lines}} ); };

    if ($options{order_native})
      { my $pk_list= $self->{_native_pk_list};
        if ((!defined $pk_list) || (!@$pk_list))
          { return(keys %{$self->{_lines}} ); }
        else
          { return(@$pk_list); }
      };

    $self->gen_sort_prepare(\%options);

    my $s_lines= $self->{_lines};
    $gen_sort_href= $s_lines;

    my $filter_opt= $options{filter};
    if (!defined $filter_opt)
      { return( sort gen_sort (keys %$s_lines) ); };

    my @keys;
    if ($filter_opt eq 'inserted')
      { my $r_k= $self->{_inserted};
        return if (!defined $r_k);
        @keys= keys (%$r_k);
      }
    elsif ($filter_opt eq 'updated')
      { my $r_k= $self->{_updated};
        return if (!defined $r_k);
        @keys= keys (%$r_k);
      }
    else
      { dbdrv::dberror($mod,'primary_keys',__LINE__,
                       "unknown filter-option: $filter_opt");
        return;
      };

    return( sort gen_sort (@keys) );

  }

sub primary_key_columns
  { my $self= shift;

    return if ($self->{_counter_pk});
    return( @{$self->{_pks}} );
  }

sub primary_key_column_indices
  { my $self= shift;

    return if ($self->{_counter_pk});
    return( @{$self->{_pkis}} );
  }

sub primary_keys_are_numeric
  { my $self= shift;

    return(1) if ($self->{_counter_pk});
    return( $self->{_pk_is_numeric} );
  }

sub primary_key_auto_generate_possible
  { my $self= shift;

    return(0) if ($self->{_counter_pk});
    return(0) if ($self->{_multi_pk});
    return(0) if (!$self->{_pk_is_numeric});
    return(1);
  }

sub column_list
  { my $self= shift;

    return( @{$self->{_column_list}} );
  }

sub column_hash
  { my $self= shift;

    return( %{$self->{_columns}} );
  }

sub get_column_property
  { my $self= shift;
    my ($colname, $colproperty) = @_;

    return if (!exists $self->{_column_properties});

    if (!defined $colname)
      { # return everything if no specific column was requested
        return( %{$self->{_column_properties}} );
      };


    my $col_prop= $self->{_column_properties}->{$colname};

    return if (!defined $col_prop);

    return( $col_prop->{$colproperty} );
  }

sub get_column_type
  { my $self= shift;
    my ($colname) = @_;
    return if (!exists $self->{_types}->[$self->{_columns}->{$colname}]);
    return( $self->{_types}->[$self->{_columns}->{$colname}] );
  }

sub get_object_type
  { my $self= shift;
    return ($self->{_type});
  }

sub max_column_widths
  { my $self= shift;
    my($minwidth,$maxwidth)= @_;

    my $r_cols= $self->{_column_list};
    my $r_l   = $self->{_lines};

    my @col_widths= map { length($_) } (@$r_cols);
    my @widths= @col_widths;

    foreach my $pk (keys %$r_l)
      { my $r_line= $r_l->{$pk};
        for(my $i=0; $i<= $#$r_line; $i++)
          { my $l= length($r_line->[$i]);
            $widths[$i]= $l if ($l>$widths[$i]);
          };
      };

    for(my $i=0; $i<= $#widths; $i++)
      { if ($widths[$i] < $minwidth)
          { $widths[$i] = $minwidth; };

        if ($widths[$i] > $maxwidth)
          { $widths[$i] = $maxwidth;
            if ($widths[$i] < $col_widths[$i])
              { $widths[$i] = $col_widths[$i]; };
          };
      };
    return(@widths)
  }

sub foreign_keys
  { my $self= shift;

    if ($self->{_type} ne 'table')
      { warn " foreign_keys does only work on type \"table\"";
        return;
      };

    my $r_foreign_keys= $self->{_foreign_keys};
    return($r_foreign_keys) if (defined $r_foreign_keys);

    my $dbh= $self->{_dbh};
    my $user;
    $user= $dbdrv::std_username if ($dbh==$dbdrv::std_dbh);

    $r_foreign_keys= dbdrv::foreign_keys($dbh,$user,$self->{_table});

    $self->{_foreign_keys}= $r_foreign_keys;

    return($r_foreign_keys);
  }

sub resident_keys
  { my $self= shift;

    if ($self->{_type} ne 'table')
      { warn " resident_keys does only work on type \"table\"";
        return;
      };

    my $r_resident_keys= $self->{_resident_keys};
    return($r_resident_keys) if (defined $r_resident_keys);

    my $dbh= $self->{_dbh};
    my $user;
    $user= $dbdrv::std_username if ($dbh==$dbdrv::std_dbh);

    $r_resident_keys= dbdrv::resident_keys($dbh,$user,$self->{_table});

    $self->{_resident_keys}= $r_resident_keys;

    return($r_resident_keys);
  }

sub value
# get or set a value
  { my $self= shift;
    my $key = shift;
    my $column= shift; $column= uc($column);
    my $newval= shift;

    my $pk;
    if (!exists $self->{_aliases})
      { $pk= $key; }
    else
      { $pk= $self->{_aliases}->{$key}; };

    return if (!defined $pk);

    my $line= $self->{_lines}->{$pk};
    return if (!defined $line);

    if (!defined $newval)
      { my $i= $self->{_columns}->{$column};
        if (!defined $i)
          { dbdrv::dberror($mod,'value',__LINE__,
                           "error: unknown column: $column");
            return;
          };

        return $line->[ $i ];
      }
    else
      { my $i= $self->{_columns}->{$column};
        if (!defined $i)
          { dbdrv::dberror($mod,'value',__LINE__,
                           "error: unknown column: $column");
            return;
          };

        if (!$self->{_counter_pk})
          { # check weather the primary key is to be changed:
            my $pk_change=0;
            if (!$self->{_multi_pk})
              { if ($self->{_pkis}->[0] == $i)
                  { $pk_change=1; };
              }
            else
              { # a search, maybe it's a bit slow ?
                foreach my $pki ( @{$self->{_pkis}} )
                  { if ($pki==$i)
                      { $pk_change=1;
                        last;
                      };
                  };
              };
            if ($pk_change)
              { my @localline= @$line;
                $localline[$i] =$newval;
                my $new_pk= build_primary_key_str_l($self->{_pkis},
                                                    \@localline);
                if (exists $self->{_lines}->{$new_pk})
                  { dbdrv::dbwarn($mod,'value',__LINE__,
                                  "error: primary key(s) already exist!");
                    return;
                  };
                $self->{_lines}->{$new_pk}= $self->{_lines}->{$pk};
                delete $self->{_lines}->{$pk};
                my $r_aliases= $self->{_aliases};
                foreach my $key (keys %$r_aliases)
                  { $r_aliases->{$key}= $new_pk
                      if ($r_aliases->{$key} eq $pk);
                  };
                $self->{_deleted}->{$pk}=1;
                $self->{_inserted}->{$new_pk}=1;
                $pk= $new_pk;
              };
          };

        $line->[ $i ] =$newval;
        # lines that are marked inserted, do not need to be
        # marked as updated, too
        if (!exists $self->{_inserted}->{$pk})
          { $self->{_updated}->{$pk}=1; };
        return($newval);
      };
  }

sub find
# find lines where column has a certain value
# Note: this function does string-compare!
# flags: find_first=>1 : find only the first match
#        warn_not_pk   : warn if column is not the primary key
#        warn_multiple : warn more than one line was found
  { my $self= shift;
    my $column= shift; $column= uc($column);
    my $value= shift;
    my %flags= @_;

    my @pk_list;
    my $r_l= $self->{_lines};
    my $is_multi_pk= $self->{_multi_pk};
    my $counter_pk   = $self->{_counter_pk};

    my $colindex= $self->{_columns}->{$column};
    if (!defined $colindex)
      { dbdrv::dberror($mod,'find',__LINE__,
                       "error: unknown column: $column");
        return;
      };

    my $r_pkis= $self->{_pkis};
    if ((!$counter_pk) && (!$is_multi_pk))
      # there is only one primary key
      { if ($colindex == $r_pkis->[0])
          { # the primary key is given, this is the simple case
            if (exists $r_l->{$value})
              { return($value); }
            else
              { return; };
          };
      };

    if (($flags{warn_not_pk}) && (!$is_multi_pk) && (!$counter_pk))
      { warn "$column is not the primary key (dbitable::find)\n"; };

    # from here: the complicated case, a real search

    foreach my $pk (keys %$r_l)
      { if ($r_l->{$pk}->[$colindex] eq $value)
          { if ($flags{find_first})
              { return($pk); };
            push @pk_list, $pk;
          };
      };
    if ($flags{warn_multiple})
      { if ($#pk_list>0)
          { warn "more than one line found for value $value " .
                                            "in column $column\n" .
                 " (dbitable::find)\n";
          };
      };
    return(@pk_list);
  }

sub add_line
  { my $self= shift;
    my $dbh= $self->{_dbh};
    my %values= @_;

    # usually this key should be unique, even if several instances of
    # dbitable are running, they shouldn't 'collide'

    my $r_pkis= $self->{_pkis};
    my $is_multi_pk= $self->{_multi_pk};
    my $counter_pk   = $self->{_counter_pk};
    my $pk_is_numeric= $self->{_pk_is_numeric};

    my $new_key;
    if ($counter_pk)
      { $new_key= $self->new_counter_key(); }
    else
      { $new_key= build_primary_key_str($self->{_pks},\%values); };

    if (!defined $new_key)
      { if ($is_multi_pk)
          { dbdrv::dbwarn($mod,'add_line',__LINE__,
                           "error:the primary key columns MUST " .
                           "be set for a \n" .
                           "table with more than one primary key");
            return;
          };
        if (!$pk_is_numeric)
          { dbdrv::dbwarn($mod,'add_line',__LINE__,
                           "error:the primary key column(s) MUST " .
                           "be set when at least one primary key\n" .
                           "column is not numeric");
            return;
          };
        # if the primary key is not given, create one
        $new_key= $self->new_prelim_key();
        $self->{_preliminary}->{$new_key}= 1;
      };

    my $r_lines  = $self->get_hash("_lines");
    my $r_aliases= $self->get_hash("_aliases");

    if (exists $r_lines->{$new_key})
      { dbdrv::dbwarn($mod,'add_line',__LINE__,
                      "error, primary key already exists\n");
        return;
      };


    my @line;
    my $first_pk= $self->{_pks}->[0];

    $r_aliases->{ $new_key }= $new_key;
    foreach my $col (@{$self->{_column_list}})
      { if ((!$counter_pk) && (!$is_multi_pk))
        # there is only one primary key
          { if ($col eq $first_pk)
              { push @line, $new_key; next; };
          };

        if (!exists $values{$col})
          { dbdrv::dberror($mod,'add_line',__LINE__,
                           "add_line: field \"$col\" is missing");
            return;
          };
        push @line, $values{$col};
      };
    $r_lines->{$new_key}= \@line;
    $self->{_inserted}->{$new_key}=1;
    return($new_key);
  }

sub delete_line
  { my $self= shift;
    my $pk= shift;
    my $r_lines= $self->{_lines};
    my $r_aliases= $self->{_aliases};

    return if (!exists $r_lines->{$pk});
    if (defined $r_aliases)
      { foreach my $key (keys %$r_aliases)
          { delete $r_aliases->{$key} if ($r_aliases->{$key} eq $pk); };
      };
    delete $r_lines->{$pk};
    $self->{_deleted}->{$pk}=1;
  }

sub add_column_aliases
  { my $self= shift;
    my $column= shift; $column= uc($column);
    my %options= @_;

    my $r_a= $self->get_hash("_aliases");

    my $col_index= $self->{_columns}->{$column};
    if (!defined $col_index)
      { dbdrv::dberror($mod,'value',__LINE__,
		       "error: unknown column: $column");
	return;
      };
    while ( my($pk,$line)= each(%{$self->{_lines}}) )
      { 
	my $key= $line->[$col_index];
	if ($options{lowercase})
	  { $key= lc($key); };
	if ($options{uppercase})
	  { $key= uc($key); };
        $r_a->{$line->[$col_index]}= $pk;
      }
  }

sub add_aliases
  { my $self= shift;
    my %aliases= @_;
    my $r_a= $self->get_hash("_aliases");
    my($alias,$pk);
    my $lines= $self->{_lines};

    while (($alias,$pk) = each %aliases)
      { if (!exists $lines->{$pk})
          { warn "primary key $pk doesn\'t exist!"; next; };
        $r_a->{$alias}= $pk;
      };
  }

sub resolve_alias
  { my $self= shift;
    my $alias= shift;

    my $r_aliases= $self->{_aliases};
    return if (!defined $r_aliases);
    return($r_aliases->{$alias});
  }

sub max_key
# 'capped' as parameter: return largest primary key below $key_fact
  { my $self= shift;
    my $arg= shift;
    my $dbh= $self->{_dbh};

    if ($self->{_multi_pk})
      { dbdrv::dberror($mod,'max_key',__LINE__,
                       "max_key only works for tables with a " .
                       "single primary key!");
        return;
      };

    if (!$self->{_pk_is_numeric})
      { dbdrv::dberror($mod,'max_key',__LINE__,
                       "max_key only works for tables with a " .
                       "numeric single primary key!");
        return;
      };

    my $pk= $self->{_pks}->[0];

    if ($self->{_type} ne 'table')
      { dbdrv::dberror($mod,'max_key',__LINE__,
                       "sorry, \'maxkey\' is only " .
                       "allowed for type \'table\'");
        return;
      };

    my $cmd= "select max( $pk ) from $self->{_table}";
    if ($arg eq 'capped')
      { $cmd.= " where $pk<$key_fact"; };

    dbdrv::sql_trace($cmd) if ($dbdrv::sql_trace);

    my @array = $dbh->selectrow_array($cmd);
    if (!@array)
      { dbdrv::dberror($mod,'max_key',__LINE__,
                       "selectall_arrayref failed, errcode:\n$DBI::errstr");
        return;
      };
    return($array[0]);
  }

#sub dump
#  { my $self= shift;
#
#    my $obj= Data::Dumper->new([$self]); #,[$name]);
#    $obj->Terse(1);
#    $obj->Indent(1);
#    print $obj->Dump;
#  }

sub dump
  { my $self= shift;
    my $filename= shift;
    my $fh= \*STDOUT;
    local(*F);

    if (defined $filename)
      { if (!open(F,">$filename"))
          { dbdrv::dberror($mod,'dump',__LINE__,"unable to open file");
            return;
          };
        $fh= \*F;
      };

    my %h= %$self;

    dbdrv::rdump($fh,\%h,0);
    if (defined $filename)
      { if (!close(F))
          { dbdrv::dberror($mod,'dump',__LINE__,"unable to close file");
            return;
          };
      };
  }

sub dump_s
  { my $self= shift;
    my $buffer;

    my %h= %$self;

    dbdrv::rdump_s(\$buffer,\%h,0);
    return(\$buffer);
  }


sub pretty_print
  { my $self= shift;
    my %options= @_;

    my @widths;
    my @lines;

    $self->gen_sort_prepare(\%options);

    my $s_lines= $self->{_lines};
    $gen_sort_href= $s_lines;
    my @keys= sort gen_sort (keys %$s_lines);

    push @lines, $self->{_column_list};

    push @lines, (map { $s_lines->{$_} } (@keys));

    @widths= col_widths(@lines);

    #foreach my $r_line (@lines)
    #  { for(my $i=0; $i<= $#$r_line; $i++)
    #      { my $l= length($r_line->[$i]);
    #       $widths[$i]= $l if ($l>$widths[$i]);
    #      };
    #  };
    my $oolen;
    map { $oolen+= $_ + 1 } @widths; $oolen--;
    my $format= join(" ",(map{ '%-' . $_ . 's' } @widths)) . "\n";
    printf($format, @{$lines[0]});
    print "-" x $oolen,"\n";
    for(my $i=1; $i<=$#lines; $i++)
      { printf($format, @{$lines[$i]}); };
  }


# ------------------ database load and store

sub load_from_db
# internal
  { my $self= shift;
    my %options= @_;

    my $select_trailer;
    my $filter_field;
    my $filter_value;

    my $dbh   = $self->{_dbh};
    my $r_pkis= $self->{_pkis};
    my $counter_pk   = $self->{_counter_pk};

    my $r;
    my $errstr= "selectall_arrayref() failed, errcode:\n";

    my $mode= $options{mode};
    if    (!defined $mode)
      { $mode= 'set'; }
    elsif (($mode ne 'add') && ($mode ne 'set') &&
          ($mode ne 'subtract') && ($mode ne 'overwrite'))
      { # a kind of assertion, therefore an error
        dbdrv::dberror($mod,'load_from_db',__LINE__,
                       "unknown load-mode:$mode");
        return;
      };


    if (exists $options{order_by})
      { $options{save_native_order}=1; };

    my $save_native_order= $options{save_native_order};
    my $r_native_pk_list;
    if ($save_native_order)
      { $r_native_pk_list= $self->get_array("_native_pk_list");
      };


    if (exists $options{filter})
      { if ($self->{_type} ne 'table')
          { dbdrv::dberror($mod,'load_from_db',__LINE__,
                           "sorry, filters are only " .
                           "allowed for type \'table\'");
            return;
          };

        my $r_filter= $options{filter};
        if (ref($r_filter) ne 'ARRAY')
          { # a kind of assertion, therefore an error
            dbdrv::dberror($mod,'load_from_db',__LINE__,
                           "err: \"filter\" is not an array reference");
            return;
          };

        my $filter_type= $r_filter->[0];
        if ($filter_type eq 'equal')
          { my($filter_field,$filter_value)= @$r_filter[1..2];

            if (!defined($filter_value))
              { # kind of usage error
                dbdrv::dbwarn($mod,'load_from_db',__LINE__,
                               "err: filter specification is incomplete");
                return;
              };
            $filter_type= lc($filter_type);
            $filter_field= uc($filter_field);
            if ($filter_value!~ /^\'/)
              { $filter_value= "\'$filter_value\'"; };
            if (!exists $self->{_columns}->{$filter_field})
              { # kind of usage error
                dbdrv::dbwarn($mod,'load_from_db',__LINE__,"unknown field");
                return;
              };

            $select_trailer= "where $filter_field = $filter_value";
          }
        elsif ($filter_type eq 'SQL')
          { $select_trailer= "WHERE " . $r_filter->[1]; }
        else
          { # a kind of assertion, therefore an error
            dbdrv::dberror($mod,'load_from_db',__LINE__,
                           "unsupported filter-type: $filter_type");
            return;
          };
      };
    if (exists $options{order_by})
      { if ($self->{_type} ne 'table')
          { # a kind of assertion, therefore an error
            dbdrv::dberror($mod,'load_from_db',__LINE__,
                           "sorry, order-by is only " .
                           "allowed for type \'table\'");
            return;
          };
        $select_trailer.=" " if ($select_trailer);
        $select_trailer.="ORDER BY " . $options{order_by};
      };


    my $last_fetch_cmd= $self->{_fetch_cmd};

    if ($self->{_type} eq 'table')
      { $self->{_fetch_cmd}= "select * from $self->{_table} " .
                             "$select_trailer";
      };

    my $cmd= $self->{_fetch_cmd};
    dbdrv::sql_trace($cmd) if ($dbdrv::sql_trace);

#warn "|$cmd|\n";
    $r= $dbh->selectall_arrayref($cmd);
    if (!$r)
      { # restore the fetch-command
        $self->{_fetch_cmd}= $last_fetch_cmd;
        dbdrv::dbwarn($mod,'load_from_db',__LINE__,$errstr . $DBI::errstr);
        return;
      };


    my $r_lines;

    if ($mode eq 'set')
      { # delete all lines that are already there
        delete $self->{_lines};
      }

    $r_lines= $self->get_hash("_lines");

    my $r_aliases= $self->get_hash("_aliases");
    my $pk;


    my %deleted;
    my %updated;
    my %inserted;

    if ($mode ne 'set')
      { # 1: assume all lines to be inserted
        %inserted = map { $_ => 1 } (keys %$r_lines);
      };



    foreach my $rl (@$r) # for all lines than came from the DB
      {
        if ($counter_pk)
          { $pk= $self->new_counter_key(); }
        else
          { $pk= compose_primary_key_str($r_pkis,$rl); };

        if ($save_native_order)
          { push @$r_native_pk_list, $pk; };

        if ($mode ne 'set')
          {
            $inserted{$pk}=0;
            if (exists $r_lines->{$pk}) # if line is already in table
              { if ($mode ne 'overwrite')
                  {
                    if (!lists_equal($r_lines->{$pk},$rl))
                      {
                        $updated{$pk}= 1;
                      };
                    next;
                  };
              }
            else
              { #line is not already in table
                if ($mode eq 'subtract')
                  { # line is in db, but not in table. Mark that line
                    # deleted
                    $deleted{$pk}= 1;
                  };
              };
          };
        if ($mode ne 'subtract')
          { $r_lines->  { $pk } = $rl;
            $r_aliases->{ $pk } = $pk;
          };
      };

    if ($mode eq 'set')
      { delete $self->{_updated};
        delete $self->{_inserted};
      }
    else
      { if (%updated)
          { $self->{_updated}= \%updated; }
        else
          { delete $self->{_updated}; };

        # all lines that were not found in the database are marked as inserted
        my %n_inserted= map { $_ => 1} grep {$inserted{$_}} (keys %inserted);
        if (%n_inserted)
          { $self->{_inserted}= \%n_inserted; }
        else
          { delete $self->{_inserted}; };

        if (%deleted)
          { $self->{_deleted}= \%deleted; };
      };

    if ($save_native_order)
      { my @reversed_list= reverse @$r_native_pk_list;
        my %h;

        my @new_list;
        foreach my $k (@reversed_list)
          { next if (exists $h{$k});
            $h{$k}=1;
            unshift @new_list,$k;
          };

        foreach my $k (keys %$r_lines)
          { next if (exists $h{$k});
            unshift @new_list,$k;
          };

        $self->{_native_pk_list}= \@new_list;
      };

    # change table name if the user wants it:
    if (exists $options{new_name})
      { $self->{_table}= $options{new_name}; };

    return($self);
  }

sub store_to_db
#internal
# see comment on "%options" in insert()
  { my $self= shift;

    if ($self->{_type} ne 'table')
      { dbdrv::dberror($mod,'store_to_db',__LINE__,
                       "sorry, \'store\' is only " .
                       "allowed for type \'table\'");
        return;
      };

    return if (!$self->delete_(@_));
    return if (!$self->insert(@_));
    return if (!$self->update(@_));
    return($self);
 }

sub delete_
# internal
  { my $self= shift;
    my $dbh= $self->{_dbh};
    my $lines= $self->{_lines};

    return(1) if (!$self->{_deleted});

    if ($sim_delete)
      { print STDERR "In table $self->{_table} the following\n";
        print STDERR "primary keys from lines would be deleted:\n";
        print STDERR join(",",(keys %{$self->{_deleted}})),"\n";
        print STDERR "set \$dbitable::sim_delete to 0 if you want\n" .
                    "deletions to be carried out\n";
        return(1);
      };

    my $format;

    my $r_pks= $self->{_pks};

    if ($self->{_counter_pk})
      { # no primary key defined
        # build a complete "where" clause:
        my @conditions= map { "$_ = ?" } (@{$self->{_column_list}});
        my $condition= join(" AND ",@conditions);
        my $sth= dbdrv::prepare(\$format,$dbh,
                                "delete from $self->{_table} " .
                                "where $condition ");
        if (!$sth)
          { dbdrv::dbwarn($mod,'store_to_db',__LINE__,
                           "prepare failed," .
                           " error-code: \n$DBI::errstr");
            return;
          };
        foreach my $pk (keys %{$self->{_deleted}})
          { if (!dbdrv::execute($format,$dbh,$sth,
                           $self->{_lines}->{$pk}))
              { dbdrv::dbwarn($mod,'store_to_db',__LINE__,
                               "execute() returned an error," .
                               " error-code: \n$DBI::errstr");
                $sth->finish;
                return;
              };
          };
        $sth->finish;
      }
    elsif (!$self->{_multi_pk}) # only one primary key column
      { my $sth= dbdrv::prepare(\$format,$dbh,
                                "delete from $self->{_table} " .
                                "where $r_pks->[0] = ? ");
        if (!$sth)
          { dbdrv::dbwarn($mod,'store_to_db',__LINE__,
                           "prepare failed, error-code: \n$DBI::errstr");
            return;
          };
        # update :
        foreach my $pk (keys %{$self->{_deleted}})
          { if (!dbdrv::execute($format,$dbh,$sth, $pk))
              { dbdrv::dbwarn($mod,'store_to_db',__LINE__,
                               "execute() returned an error," .
                               " error-code: \n$DBI::errstr");
                $sth->finish;
                return;
              };
          };
        $sth->finish;
      }
    else
      {
        # build the "where" clause:
        my @conditions= map { "$_ = ?" } (@$r_pks);
        my $condition= join(" AND ",@conditions);
        my $sth= dbdrv::prepare(\$format,$dbh,
                                "delete from $self->{_table} " .
                                "where $condition ");
        if (!$sth)
          { dbdrv::dbwarn($mod,'store_to_db',__LINE__,
                           "prepare failed," .
                           " error-code: \n$DBI::errstr");
            return;
          };
        # that should work, but who gives me the opportunity to test it ??
        # update :
        foreach my $pk (keys %{$self->{_deleted}})
          { if (!dbdrv::execute($format,$dbh,$sth,
                           decompose_primary_key_str($pk)))
              { dbdrv::dbwarn($mod,'store_to_db',__LINE__,
                               "execute() returned an error," .
                               " error-code: \n$DBI::errstr");
                $sth->finish;
                return;
              };
          };
        $sth->finish;
      };

    delete $self->{_deleted}; # all updates are finished
    return(1);
   }


sub update
#update
  { my $self= shift;
    my $dbh= $self->{_dbh};
    my $lines= $self->{_lines};

    # @fields was used in db_prepare instead of @{$self->{_column_list}}

    my $format;

    my $r_pks= $self->{_pks};
    my $r_pkis= $self->{_pkis};
    my $is_multi_pk= $self->{_multi_pk};

    if ($self->{_counter_pk})
      { dbdrv::dbwarn($mod,'update',__LINE__,
                           "update() impossible when there's no " .
                           "primary key");
        return;
      };


    my $condition;
    if (!$is_multi_pk) # only one primary key column
      { $condition= "$r_pks->[0] = ?"; }
    else
      { my @conditions= map { "$_ = ?" } (@$r_pks);
        $condition= join(" AND ",@conditions);
      };

    my $sth= dbdrv::prepare(\$format,$dbh,
                      "update $self->{_table} set " .
                       join(" = ?, ",@{$self->{_column_list}}) . " = ? " .
                      "where $condition ");
    if (!$sth)
      { dbdrv::dbwarn($mod,'update',__LINE__,
                       "prepare failed," .
                       " error-code: \n$DBI::errstr");
        return;
      };


    # update :

    my $line;

    if (!$is_multi_pk) # only one primary key column
      { foreach my $pk (keys %{$self->{_updated}})
          { $line= $lines->{$pk};
            next if (!defined $line);
            # can happen with changing, then deleting a line
            if (!dbdrv::execute($format,$dbh,$sth,
                       @$line, $line->[ $r_pkis->[0] ] ))
              {
#print "caller:",join(" ",caller),"\n";
                dbdrv::dbwarn($mod,'update',__LINE__,
                               "execute() returned an error," .
                               " error-code: \n$DBI::errstr");
                $sth->finish;
                return;
              };
          }
      }
    else
      { foreach my $pk (keys %{$self->{_updated}})
          { $line= $lines->{$pk};
            next if (!defined $line);
            # can happen with changing, then deleting a line
            if (!dbdrv::execute($format,$dbh,$sth,
                       @$line, map { $line->[$_] } (@$r_pkis) ))
              { dbdrv::dbwarn($mod,'update',__LINE__,
                               "execute() returned an error," .
                               " error-code: \n$DBI::errstr");
                $sth->finish;
                return;
              };
          }
      }

    $sth->finish;
    delete $self->{_updated}; # all updates are finished
    return(1);
  }

sub insert
# insert
# internal
# note; primaray_key=>generate is forbidden with
#   tables that have more than one primary key column
  { my $self= shift;
    my %options= @_;

    my $dbh= $self->{_dbh};
    my $lines= $self->{_lines};
    my $is_multi_pk= $self->{_multi_pk};
    my $pk_is_numeric= $self->{_pk_is_numeric};

    my @fields= @{$self->{_column_list}};

    my $format;
    my $pk_opt;

#warn "insert options: ",join("|",%options);

    return(1) if (!$self->{_inserted});

    for(;;) #not a real loop...
      { $pk_opt= $options{primary_key};

        if (defined $pk_opt)
          { if (($pk_opt ne 'preserve') && ($pk_opt ne 'generate'))
            { dbdrv::dberror($mod,'insert',__LINE__,
                             "unknown primary-key-mode:$pk_opt");
              return;
            };
          };

        if ($self->{_counter_pk})
          { if ($self->{_foreign_keys})
              { # a table just with foreign key(s), no
                # primary key, this is OK
                $pk_opt='none';
                last;
              }
            else
              { dbdrv::dberror($mod,'insert',__LINE__,
                               "insert() called with table or view of type \n" .
                               "counter-pk! (assertion)");
                return;
              };
          };

        if ($is_multi_pk)
          { # more than one primary key,
            # force 'preserve' mode
            # NOTE: the given primary key mode is overridden here !
            $pk_opt= 'preserve';
            last;
          };

        if (!$pk_is_numeric)
          { # at least one pk is not numeric,
            # force 'preserve' mode
            # NOTE: the given primary key mode is overridden here !
            $pk_opt= 'preserve';
            last;
          };

        # default primary key mode is this:
        $pk_opt= 'generate' if (!defined $pk_opt);
        last;
      };

    my $sth= dbdrv::prepare(\$format,$dbh,
                            "insert into $self->{_table} " .
                            " ( " . join(", ",@fields) . ") " .
                            "values( " .
                            ("?, " x $#fields) . " ? )" );
    if (!$sth)
      { dbdrv::dbwarn($mod,'insert',__LINE__,
                       "prepare failed, error-code: \n$DBI::errstr");
        return;
      };

    my $r_aliases= $self->get_hash("_aliases");

    # insert :
    my $failcount=0;
    my $line;
    foreach my $pk (keys %{$self->{_inserted}})
      { $line= $lines->{$pk};

        if (!dbdrv::execute($format,$dbh,$sth, @{$line}))
          { dbdrv::dbwarn($mod,'insert',__LINE__,
                           "execute() returned an error," .
                           " error-code: \n$DBI::errstr");
            $sth->finish;
            return;
          };
      };

    $sth->finish;

#warn "pkopt: $pk_opt";
    if ($pk_opt eq 'generate')
      { my $r_p= $self->{_preliminary};
        if (!defined $r_p)
          { my %h;
            $self->{_preliminary}= \%h;
            $r_p= \%h;
          };
        foreach my $k (keys %{$self->{_inserted}})
          { $r_p->{$k}= 1; };
      };

    my @prelim_keys= (keys %{$self->{_preliminary}});

#warn "preliminary keys: " . join("|",@prelim_keys);

    if (@prelim_keys)
      {
       if (!$pk_is_numeric)
          { dbdrv::dberror($mod,'insert',__LINE__,
                           "preliminary keys found with" .
                           "non-numeric pk column (assertion)");
            return;
          };
       if ($is_multi_pk)
          { dbdrv::dberror($mod,'insert',__LINE__,
                           "preliminary keys found with " .
                           "multi-pk table (assertion)");
            return;
          };

        if (!exists $self->{_types})
          { @prelim_keys= sort { $a <=> $b } @prelim_keys; }
        elsif ($self->{_types}->[ $self->{_pkis}->[0] ] eq 'number')
          { @prelim_keys= sort { $a <=> $b } @prelim_keys; }
        else
          { @prelim_keys= sort { $a cmp $b } @prelim_keys; };

        my $pk= $self->{_pks}->[0];

        $sth=    dbdrv::prepare(\$format,$dbh,
                                "update $self->{_table} set $pk= ? " .
                                "where $pk= ?");
        if (!$sth)
          { dbdrv::dbwarn($mod,'insert',__LINE__,
                           "prepare failed," .
                           " error-code: \n$DBI::errstr");
            return;
          };

        my $max= $self->max_key('capped');

        foreach my $pk (@prelim_keys)
          { $line= $lines->{$pk};

            for(;;)
              { if (!dbdrv::execute($format,$dbh,$sth, ++$max, $pk))
                  { if ($DBI::errstr=~ /constraint.*violated/i)
                      { # probably conflict with another task that was just adding
                        # THAT key
                        # give it another try
                        if ($failcount++ < 5)
                          { next; };
                        dbdrv::dbwarn($mod,'insert',__LINE__,
                          "error: changing of primary key $pk failed\n" .
                          "again and again, giving up, last DBI error\n" .
                          "message was: $DBI::errstr");
                        $sth->finish;
                        return;
                      }
                    else
                      { dbdrv::dbwarn($mod,'insert',__LINE__,
                                 "execute() failed, errstring:\n" .
                                 $DBI::errstr);
                        $sth->finish;
                        return;
                      };
                  }
                else
                  { $failcount=0;
                    last;
                  };
              };

            $sth->finish;

            # now change the primary key, retain the old one as an alias
            $r_aliases->{$pk} = $max;
            $r_aliases->{$max}= $max;
            $lines->{$max}= $lines->{$pk};
            delete $lines->{$pk};
          };
      };
    delete $self->{_inserted};    # all updates are finished
    delete $self->{_preliminary}; # all updates are finished
    return(1);
  }

# ------------------ file load and store
sub load_from_file
# known options:
# pretty => 1 or 0
#       1 removes spaces at the end of fields
#       needed for files that were created with the pretty-option
# primary_key=> 'generate', 'preserve',
#           generate: only done where pk==0 !!!!
# new_name=> $name
#       change $self->{_table} to the new name
# no_aliases => 1 or 0
#       if "1", do not read the [Aliases] section
  { my $self= shift;
    my %options= @_;

    my $is_multi_pk= $self->{_multi_pk};

    my $v= $options{primary_key};
    if (!$is_multi_pk)
      { $v= 'preserve' if (!defined $v); }
    else
      { $v= 'preserve' if (!defined $v); };

    if (($is_multi_pk) && ($v ne 'preserve'))
      { dbdrv::dberror($mod,'load_from_file',__LINE__,
                       "primary key mode must be \"preserve\" for a \n" .
                       "table with more than one primary key column");
        return;
      };

    if (($v ne 'preserve') && ($v ne 'generate'))
      { dbdrv::dberror($mod,'load_from_file',__LINE__,
                       "unknown primary-key-mode:$v");
        return;
      };

    if ($self->{_type} ne 'file')
      { dbdrv::dberror($mod,'load_from_file',__LINE__,
                       "sorry, \'store_to_file\' is only " .
                       "allowed for type \'file\'");
        return;
      };

    my $filename= $self->{_filename};
    my $tag= $self->{_tag};

    my $fh;

    if    ($filename eq "")
      { # read the complete file and buffer it since it may
        # contain information on some tables or tags that we
        # don't want to read this time but next time
        if (!exists $self->{_buffered_lines})
          { local $/;
            undef $/;
            my $buffered_lines= <>; # read everything from stdin
            $self->{_buffered_lines}= \$buffered_lines;
          }
        $fh= new IO::Scalar $self->{_buffered_lines};
      }
    elsif (ref $filename eq 'SCALAR')
      { $fh= new IO::Scalar $filename;
        if (!defined $fh)
          { die "assertion"; };
      }
    elsif (ref $filename eq '')
      { $fh= new IO::File;

        if (!$fh->open("$filename"))
          { dbdrv::dberror($mod,'load_from_file',__LINE__,
                           "unable to read from $filename");
            return;
          };
      }
    else
      { die "assertion"; }

    my $line;
    my $part;
    my $version;
    my $found;

    my @line_list;

    while($line=<$fh>)
      {
        chomp($line);
        next if ($line=~ /^\s*$/);
        next if ($line=~ /^#/);
        if (!defined $part)
          { next if ($line !~ /^\[Tag ([^\]\s]+)\s*\]\s*$/);
            next if ($1 ne $tag);
            $part= 'search_version';
            $found=1;
            next;
          };

        if ($line =~ /^\[Tag ([^\]\s]+)\s*\]\s*$/)
          { last; }; # stop when a new part begins

        if ($part eq 'search_version')
          { next if ($line !~ /^\[Version ([^\]\s]+)\s*\]\s*$/);
            if ($export_version < $1)
              { dbdrv::dberror($mod,'load_from_file',__LINE__,
                               "unsupported export-file version: $1");
                return;
              };
            $version= $1;
            $part= 'scan';
            next;
          };

        if ($line =~ /^\[([^\]]+)\]\s*$/) # a new PART
          { $part= $1;
            next;
          };

        if (($part eq 'Properties') && (!$slim_format))
          { my @tokens = &parse_line('[\s=]+', 0, $line);
            if (!($#tokens % 2))
              { dbdrv::dberror($mod,'load_from_file',__LINE__,
                               "unrecognized line: \n\"$line\"");
                return;
              };
            for(my $i=0; $i< $#tokens; $i+=2)
              { my $t= $tokens[$i];
                if    ($t eq 'TABLE')
                  { $self->{_table}= $tokens[$i+1]; }
                elsif ($t eq 'PK')
                  { if (!$tokens[$i+1])
                      { # no PK set, this means : counter_pk mode !
                        $self->{_pks}= [undef];
                        $self->{_counter_pk}= 1;
                      }
                    else
                      { $self->{_pks}   = [ split(/\s+/, uc($tokens[$i+1])) ];
                      };
                  }
                elsif ($t eq 'TYPE')
                  { $self->{_type} = $tokens[$i+1]; }
                elsif ($t eq 'FETCH_CMD')
                  { $self->{_fetch_cmd} = $tokens[$i+1]; }
                else
                  { warn "unrecognized token: $t"; };
              };
            next;
          };

        if (($part eq 'Aliases') && (!$slim_format))
          { 
	    my @tokens = &parse_line('[\s,]+', 0, $line);
	    if (!$options{no_aliases})
	      {
		foreach my $t (@tokens)
		  { next if (!defined $t); # don't know why this happens
		    my($a,$pk)= ($t=~ /^\s*(.*?)\s*=>\s*(.*?)\s*$/);
		    if (!defined $pk)
		      { dbdrv::dberror($mod,'load_from_file',__LINE__,
				       "unrecognized line: \n\"$line\"");
			return;
		      };
		    $self->{_aliases}->{$a}= $pk;
		  };
	      };
            next;
          };

        if ($part eq 'Column-Types')
          { my @tokens = &parse_line('[\s,]+', 0, $line);
            my $r_t= $self->get_array("_types");
            foreach my $t (@tokens)
              { next if (!defined $t);
                push @{$r_t}, $t;
              };
            next;
          };

        if ($part eq 'Columns')
          { my @tokens = &parse_line('[\s,]+', 0, $line);
            my $r_t= $self->get_array("_column_list");
            foreach my $t (@tokens)
              { next if (!defined $t);
                push @{$r_t}, $t;
              };
            next;
          };

        if ($part eq 'Table')
          { my @values;
            if ($options{pretty})
              {
                @values=&parse_line('[;\|]',0,$line);
                # $values= split(/[;\|]/,$line);
                foreach my $v (@values)
                  { $v=~ s/\s+$//; };
              }
            else
              {
                @values=&parse_line(';',0,$line);
                #@values= split(/;/,$line);
              };

            if ($#values != $#{$self->{_column_list}})
              { dbdrv::dberror($mod,'load_from_file',__LINE__,
                               "format error");
                return;
              };

            push @line_list,\@values;
          };
      };

    if ($filename ne "")
      { $fh->close(); };

    if (!$found)
      { 
        dbdrv::dberror($mod,'load_from_file',__LINE__,
                       "tag \"$tag\" not found in file $filename");
        return;
      };

    # final clean-up work:
    # 1st: column-hash
    my @primary_keys= @{$self->{_pks}};
    my $r_c= $self->{_column_list};
    my %colindices;
    for(my $i=0; $i<= $#$r_c; $i++)
      { $colindices{ $r_c->[$i] } = $i; };
    $self->{_columns}= \%colindices;

    my @pkis;

    if ($self->{_counter_pk})
      { @pkis= (undef);
      }
    else
      { my $r_col_hash= $self->{_columns};
        my $i;
        foreach my $pk (@primary_keys)
          { $i= $r_col_hash->{$pk};
            if (!defined $i)
              { dbdrv::dberror($mod,'load_from_file',__LINE__,
                               "assertion failed, primary key column $pk" .
                               " not found");
                return;
              };
            push @pkis, $i;
          };
      };

    $self->{_pkis}= \@pkis;

    # 2nd: lines
    my $r_aliases= $self->get_hash("_aliases");
    my %lines_hash;
    my $single_pki= $pkis[0];
    my $pk;
    my $gen_pk= exists($options{primary_key}) && ($options{primary_key} eq 'generate');
    if ($is_multi_pk && $gen_pk)
      { dbdrv::dberror($mod,'load_from_file',__LINE__,
                       "can\'t generate pk on multi-pk " .
                       "tables (assertion)");
        return;
      };
    my $counter_pk   = $self->{_counter_pk};

    foreach my $rl (@line_list)
      { if ($counter_pk)
          { $pk= $self->new_counter_key(); }
        else
          { $pk= compose_primary_key_str(\@pkis,$rl); };

        if (($gen_pk) && ($pk==0))
          { $pk= $self->new_prelim_key();
            $self->{_preliminary}->{$pk}= 1;
            $rl->[$single_pki]= $pk;
          };

        $lines_hash{ $pk } = $rl;
        $r_aliases->{ $pk }= $pk;
      };
    $self->{_lines}= \%lines_hash;

    # change table name if the user wants it:
    if (exists $options{new_name})
      { $self->{_table}= $options{new_name}; };

    return($self);
  }


sub store_to_file
#internal
# known options: 'order_by' => column-name
#            or  'order_by' => [column-name1,column-name2...]
#                'pretty' => 1 or 0
#                'no_aliases' => 1 or 0
#                             if "1", do not store the [Aliases] section
  { my $self= shift;
    my %options= @_;
    my $is_multi_pk= $self->{_multi_pk};
    my $is_scalarref;
    my $is_stdout;

    $self->gen_sort_prepare(\%options);

    if ($self->{_type} ne 'file')
      { dbdrv::dberror($mod,'store_to_file',__LINE__,
                       "sorry, \'store_to_file\' is only " .
                       "allowed for type \'file\'");
        return;
      };

    # volume is ignored !!
    my ($volume,$dir,$filename,$filepath);

    if (ref($self->{_filename}) eq "") # ordinary filename
      { if ($self->{_filename} eq "")
          { $is_stdout= 1; }
        else
          {
            ($volume,$dir,$filename) = File::Spec->splitpath( $self->{_filename} );
            $filepath= $filename;
            # catfile makes an error when $dir is equal to "", so the
            # following "if" is needed
            if ($dir) # dir not empty
              { $filepath= File::Spec->catfile($dir,$filename); };
            # NOTE: $dir ends with a '/' !!
          }
      }
    else
      { $filename= $self->{_filename};
        $is_scalarref= 1;
      }

    my $tag= $self->{_tag};

    my $fh_r;
    my $fh_w;
    my $tempname;
    my $temppath;
    my $buf;

    if ($is_stdout || $is_scalarref || (-e $filepath))
      { if    ($is_stdout)
          { if (exists $self->{_buffered_lines})
              { $fh_r= new IO::Scalar $self->{_buffered_lines}; }
            $fh_w= \*STDOUT;
          }
        elsif ($is_scalarref)
          { $fh_r= new IO::Scalar $filename;
            $fh_w= new IO::Scalar \$buf;
          }
        else
          {
            $fh_r= new IO::File;
            $fh_w= new IO::File;
            $tempname= "dbitable-$$";
            $temppath= $tempname;
            # catfile makes an error when $dir is equal to "", so the
            # following "if" is needed
            if ($dir) # dir not empty
              { $temppath= File::Spec->catfile($dir,$tempname); };
            # NOTE: $dir ends with a '/' !!

            if (!$fh_r->open($filepath))
              { dbdrv::dberror($mod,'store_to_file',__LINE__,
                               "unable to read $filepath");
                return;
              };
            if (!$fh_w->open(">$temppath"))
              { dbdrv::dberror($mod,'store_to_file',__LINE__,
                               "unable to write $temppath");
                return;
              };
          }
        my $line;
        my $ftag;
        if (defined $fh_r)
          {
            while($line=<$fh_r>)
              { if ($tag ne $ftag)
                  {
                    if ($line !~ /^\[Tag ([^\]\s]+)\s*\]\s*$/)
                      { print $fh_w $line; next; };
                    $ftag= $1;
                    if ($tag ne $ftag)
                      { print $fh_w $line; };
                    next;
                  };
                if ($line !~ /^\[Tag ([^\]\s]+)\s*\]\s*$/)
                  { next; };
                $ftag= $1;
                if ($tag ne $ftag)
                  { print $fh_w $line; };
                next;
              }
            $fh_r->close();
          };
      }
    else
      { $fh_w= new IO::File;
        if (!$fh_w->open(">$filepath"))
          { dbdrv::dberror($mod,'store_to_file',__LINE__,
                           "unable to write $filepath");
            return;
          };
      };

    print $fh_w "[Tag $tag]\n";
    print $fh_w "[Version $export_version]\n";
    if (!$slim_format)
      { print $fh_w "[Properties]\n";
        my @defines;
        foreach my $prop (qw(_table _type))
          { my $val= $self->{$prop};
            next if (!defined $val);
            push @defines, (uc(substr($prop,1)) . '=' . $val);
          };
        print $fh_w wrap('', '', join(" ",@defines)),"\n";
        print $fh_w "PK=\"",join(" ",@{$self->{_pks}}),"\"\n";
        if (exists $self->{_fetch_cmd})
          { # fetch_cmd is a long quoted string and MUST NOT
            # be handled by wrap() !!!
            print $fh_w "FETCH_CMD=\"",$self->{_fetch_cmd},"\"\n";
          };
        print $fh_w "\n";


        #print $fh_w "TABLE=",$self->{_table}," PK=",$self->{_pk},
        #        " TYPE=",$self->{_type},"\n";
        #print $fh_w "FETCH_CMD=\"",$self->{_fetch_cmd},"\"\n";
	if (!$options{no_aliases})
	  {
	    print $fh_w "[Aliases]\n";
	    my $r_a= $self->{_aliases};

	    my @text;
	    $Text::Wrap::columns = 72;
	    foreach my $k (sort keys %$r_a)
	      { my $val= $r_a->{$k};
		next if ($val eq $k);
		push @text, ($k . "=>" . $val);
	      };
	    print $fh_w wrap('', '', join(", ",@text)),"\n";
	  };
      };

    if (exists $self->{_types})
      { print $fh_w "[Column-Types]\n";
        print $fh_w wrap('', '', join(", ",@{$self->{_types}})),"\n";
      };

    print $fh_w "[Columns]\n";
    print $fh_w wrap('', '', join(", ",@{$self->{_column_list}})),"\n";

    print $fh_w "[Table]\n";
    my $r_l= $self->{_lines};

    $gen_sort_href= $r_l;
    my @keylist= sort gen_sort (keys %$r_l);


   #@@@@
    if ($options{'pretty'})
      { my @widths= col_widths( map { $r_l->{$_} } @keylist);
        my $oolen;
        map { $oolen+= $_ + 1 } @widths; $oolen--;
        my $format= join("|",(map{ '%-' . $_ . 's' } @widths)) . "\n";
        my @cells;
        foreach my $pk (@keylist)
          { @cells= @{$r_l->{$pk}};
            foreach my $c (@cells)
              { $c=~ s/'/\\'/g; # quote quotes ("'" -> "\'")
                next if ($c!~ /[\|;]/);
                $c= "'" . $c . "'";
              };
            printf $fh_w ($format,@cells);
          }
      }
    else
      { my @cells;
        foreach my $pk (@keylist)
          { @cells= @{$r_l->{$pk}};
            foreach my $c (@cells)
              { $c=~ s/'/\\'/g; # quote quotes ("'" -> "\'")
                next if ($c!~ /[\|;]/);
                $c= "'" . $c . "'";
              };
            print $fh_w join(";",@cells),"\n";
          };
      };

    if ($options{'pretty'})
      { print $fh_w "#","=" x 70,"\n"; };

    if (defined $tempname)
      { $fh_w->close();
        if (1!=unlink($filepath))
          { dbdrv::dberror($mod,'store_to_file',__LINE__,
                           "unable to delete $filepath");
            return;
          };

        # now rename the thing...
        my $old;
        if ($dir ne "")
          { $old= getcwd(); # function from Cwd module
            $old=~ /^(.*)$/; $old= $1; # explicit untaint
                                      # else taint mode make problems
            if (!chdir($dir))
              { dbdrv::dberror($mod,'store_to_file',__LINE__,
                               "unable to chdir to $dir");
                return;
              };
          };

        if (!rename($tempname,$filename))
          { dbdrv::dberror($mod,'store_to_file',__LINE__,
                           "renaming $temppath to $filepath failed!");
            if (!chdir($old))
              { dbdrv::dberror($mod,'store_to_file',__LINE__,
                               "unable to chdir back to $old");
              };
            return;
          };
        if ($dir ne "")
          { if (!chdir($old))
              { dbdrv::dberror($mod,'store_to_file',__LINE__,
                               "unable to chdir back to $old");
              };
          };

        #rename($tempname,$filename) or
      }
    else
      { if (!$is_stdout)
          { $fh_w->close(); };
        if ($is_scalarref)
          { # copy:
            $$filename= $buf;
          }
      };
    return($self);
  }

sub get_array
#internal
# returns the array-reference, creates it, if it's not already there
  { my $self= shift;
    my $arrayname= shift;

    my $r= $self->{$arrayname};
    return($r) if (defined $r);
    my @a;
    $self->{$arrayname}= \@a;
    return(\@a);
  }

sub get_hash
#internal
# returns the hash-reference, creates it, if it's not already there
  { my $self= shift;
    my $hashname= shift;

    my $r= $self->{$hashname};
    return($r) if (defined $r);
    my %h;
    $self->{$hashname}= \%h;
    return(\%h);
  }

sub new_counter_key
#internal
  { my $self= shift;

    my $counter_pk   = $self->{_counter_pk};
    if (!$counter_pk)
      { dbdrv::dberror($mod,'new_counter_key',__LINE__,
                       "table or view is not of " .
                       "type counter-pk! (assertion)");
        return;
      };
    $self->{_counter_pk}= ++$counter_pk;
    return($counter_pk);
  }

sub new_prelim_key
#internal
  { my $self= shift;

    if ($self->{_multi_pk})
      { dbdrv::dberror($mod,'new_prelim_key',__LINE__,
                       "preliminary key must not be used on " .
                       "tables with more than one primary " .
                       "key column! (assertion)");
        return;
      };

# @@@@@@@@@@@@@@@ add here:
# preliminary key generation for String-Columns

    if (!$prelim_key)
      { $prelim_key= int($key_fact*rand())+$key_fact; }
    else
      { $prelim_key++; };
    return($prelim_key);
  }

sub col_widths
# internal
  { my (@line_list)= @_;
    my @widths;

    foreach my $r_line (@line_list)
      { for(my $i=0; $i<= $#$r_line; $i++)
          { my $l= length($r_line->[$i]);

            # limit the maximum column width to $max_colwidth
            $l= $max_colwidth if ($l>$max_colwidth);

            $widths[$i]= $l if ($l>$widths[$i]);
          };
      };
    return(@widths);
  }

sub compose_primary_key_str
# internal
# especially for tables where more than one column fo the
# primary key
  { my($r_pkis, $r_line)= @_;

    if ($#$r_pkis==0) # only one primary key
      { return( $r_line->[ $r_pkis->[0] ] ); };

    join("||", (map { $r_line->[$_] } (@$r_pkis)) );
  }

sub build_primary_key_str
# internal
# especially for tables where more than one column fo the
# primary key
# build primary key from a given hash in the form
# colname1 => col_value1, colname2 => col_value2
# returns undef when (at least one) of the needed columns is
# missing
  { my($r_pks, $r_values)= @_;

    if ($#$r_pks==0) # only one primary key
      { return( $r_values->{ $r_pks->[0] } ); };

    my $str;
    my $val;
    foreach my $pk_col (@$r_pks)
      { $val= $r_values->{$pk_col};
        return if (!defined $val);
        if (!$str)
          { $str= $val; }
        else
          { $str.= '||' . $val; };
      };
    return($str);
  }

sub build_primary_key_str_l
# internal
# especially for tables where more than one column fo the
# primary key
# build primary key from a given list of column-values
# returns undef when (at least one) of the needed columns is
# missing
  { my($r_pkis, $r_values)= @_;

    if ($#$r_pkis==0) # only one primary key
      { return( $r_values->[0] ); };

    my $str;
    my $val;
    foreach my $pki (@$r_pkis)
      { $val= $r_values->[$pki];
        return if (!defined $val);
        if (!$str)
          { $str= $val; }
        else
          { $str.= '||' . $val; };
      };
    return($str);
  }

sub decompose_primary_key_str
# internal
# especially for tables where more than one column fo the
# primary key
  { return( split(/\|\|/, $_[0]) ); }


sub gen_sort_prepare
# internal
  { my $self= shift;
    my $r_options= shift;

    # @gen_sort_cols and $gen_sort_r_coltypes are global variables
    # used by gen_sort()
    @gen_sort_cols= $self->{_pkis}; # default

    if (exists $self->{_types})
      { $gen_sort_r_coltypes= $self->{_types}; }
    else
      { my @coltypes= map { "number" } @{$self->{_column_list}};
        $gen_sort_r_coltypes= \@coltypes;
      };

    @gen_sort_colmaps= ();
    if (exists $r_options->{col_maps})
      { my $r_cm= $r_options->{col_maps};
        my $r_colhash= $self->{_columns};

        foreach my $colname (keys %$r_cm)
          { $gen_sort_colmaps[ $r_colhash->{$colname} ] =
              $r_cm->{$colname};
          };
      }

    if (exists $r_options->{order_by})
      { my $cnt= $#gen_sort_cols;
        my %sort_h= map { $_ => $cnt-- } @gen_sort_cols;
        # ^^^ see further up, @gen_sort_cols is $self->{_pkis}, the
        # list of primary key indices
        $cnt= 10000;

        my $r= $r_options->{order_by};
        if (!ref($r)) # directly given
          { my $ci= $self->{_columns}->{uc($r)};
            if (!defined $ci)
              { dbdrv::dberror($mod,'gen_sort_prepare',__LINE__,
                               "unknown column: $r");
                return;
              };
            $sort_h{$ci}= $cnt--;
          }
        else
          { if (ref($r) ne 'ARRAY')
              { dbdrv::dberror($mod,'gen_sort_prepare',__LINE__,
                               "not an array");
                return;
              };
            # an array is given
            foreach my $c (@$r)
              { my $ci= $self->{_columns}->{uc($c)};
                if (!defined $ci)
                  { dbdrv::dberror($mod,'gen_sort_prepare',__LINE__,
                                   "unknown column: $c");
                    return;
                  };
                $sort_h{$ci}= $cnt--;
                #push @gen_sort_cols, $ci;
              };
          };
        @gen_sort_cols= sort { $sort_h{$b} <=> $sort_h{$a} } (keys %sort_h);
      };
  }

# given: gen_sort_href gen_sort_params
# gen_sort_cols   : a list of column-indices
# gen_sort_r_coltypes: a ref to an array: [number,string....]

sub gen_sort
  { my($r,$col,$t);

    my $r_map;

    for(my $i=0; $i<= $#gen_sort_cols; $i++)
      { $col= $gen_sort_cols[$i];
        $t  = $gen_sort_r_coltypes->[$col];

        $r_map= $gen_sort_colmaps[$col];

        if (defined $r_map)
          { $r= $r_map->{$gen_sort_href->{$a}->[$col]} cmp
                $r_map->{$gen_sort_href->{$b}->[$col]};
            return($r) if ($r!=0);
          }
        elsif ($t eq 'number')
          { $r= $gen_sort_href->{$a}->[$col] <=> $gen_sort_href->{$b}->[$col];
            return($r) if ($r!=0);
          }
        else
          { $r= $gen_sort_href->{$a}->[$col] cmp $gen_sort_href->{$b}->[$col];
            return($r) if ($r!=0);
          };
      };
    return(0); # nothing else to do
  }


sub lists_equal
  { my($r_l1,$r_l2)= @_;

    return if ($#$r_l1 != $#$r_l2);

    for(my $i=0; $i<= $#$r_l1; $i++)
      { return if ($r_l1->[$i] ne $r_l2->[$i]); };
    return(1);
  }

1;

__END__

# Below is the short of documentation of the module.

=head1 NAME

dbitable - an object-oriented Perl module for handling
single tables from an SQL database.

=head1 SYNOPSIS

  use dbitable;

  my $tab= dbitable->new('table', $database_handle,
                         $table_name, $primary_key)->load();

  $tab->value($key1,$column_name,$new_value);
  $tab->store();
  $tab->pretty_print();

=head1 DESCRIPTION

=head2 Preface


This module defines the dbitable - class. A dbitable-object can
hold some or all parts of a table of an SQL database. It is also
possible, to load the results of a user-defined view into a dbitable-object.
And a dbitable-object can also be used to read or write to an ASCII file
in a (more or less) human-readable format.

dbitable is based on the DBI module, see also the DBI manpage for more
information.

Two basic methods for a table are C<load> and C<store>. These
methods are used to load data from the database or store data
to the database or the file.

The usual way of handling a dbitable-object is to create it,
fetch some data with C<load>, inspect or modify the data, and,
optionally, write the table back to the database using C<store>.

To do all this, the user of this module doesn't need to know
the SQL language. Knowledge on the basics of relational databases,
however, will be needed.

=head2 utilities to access the database:

In order to access the database and create a database-handle, the
following two functions can be used:

=over 4

=item dbitable::connect_database()

  my $dbh= dbitable::connect_database($dbname,$username,$password)

This method creates a connection to the database. The database corresponds
to the first parameter of the C<connect> function of the DBI module. See
also the DBI manpage. The function returns the DBI-handle or C<undef>
in case of an error. The DBI-handle is also stored in the internal global
handle variable. This variable is used as default in the dbitable constructor
function C<new()> when it's DBI-handle parameter is an empty string ("") or
C<undef>.

=item dbitable::disconnect_database()

  dbitable::disconnect_database($dbi_handle)

This function is used to disconnect from the database. If the parameter
C<$dbi_handle> is an empty string, the default DBI-handle is used (see
also description of C<connect_database>).

=back

=head2 creation of a dbitable-object:

A dbitable object is created using the C<new> method:

  my $tab= dbitable->new('table',$database_handle,
                         $table_name, $primary_key);

  my $tab= dbitable->new('view',$database_handle,
                         $table_name, $primary_key, $sql_query);

  my $tab= dbitable->new('file',$filename,$tag);

  my $tab= dbitable->new('file',$filename,$tag,@column_list);

  # clone the existing structure:
  my $tab2= $tab->new();

  my $tab2= $tab->new('table',$database_handle,
                      $table_name, $primary_key);

  my $tab2= $tab->new('view',$database_handle,
                      $table_name, $primary_key, $sql_query);

  my $tab2= $tab->new('file',$filename,$tag);

The C<new> method currently knows three parameter formats. Note that,
if new is called as method of a parent dbitable-object, the parent object
is cloned and the type (table,view or file) is changed to the type
specified in the first parameter.

The C<$database_handle> parameter may be a valid database-handle, e.g.
created with the C<connect_database> function, or an empty string. In
this case, the default database-handle is used (see description of
C<connect_database>).

Notes on the primary key:

The primary key is a single column or a combination of columns that
is unique for each line in a table and gives a means to access single
lines of the table. However, dbitable also supports tables, where such
a column with unique values doesn't exist. In this case, dbitable just
assigns a number to all lines in the table, starting with "1".

The primary key is set or found in the following way:

=over 4

=item direct specification of a single column

In this case, the user supplies the information, which column is to
use as primary key. The C<$primary_key> parameter in the examples
above is a string with the name of that column. Note that this column
must have a value that is unique for each line. Otherwise several
lines will occupy the same space in the dbitable-object which means
that some lines in the dbitable-object will be missing.

=item direct specification several columns

In this case, the user supplies the information, which columns are to
use as primary key. The C<$primary_key> parameter is in this case
a reference to an array of column names. The primary key is then
composed by the value of all the columns concatenated with the
character seqeuence "||". Example:

  my $tab= dbitable->new('table',$database_handle,
                         $table_name,
                         [$primary_key1_column1,
                          $primary_key1_column2 ...]
                         );

=item automatic determination of the primary key columns

If you give "" (the empty string) or <undef> as value for the
C<$primary_key> parameter, dbitable tries to find out the
primary key columns itself by querying the database. In many cases,
dbitable will determine the correct primary key columns, which are
then used to identify each single line of the table. If dbitable
is not able to find the primary key columns, it will use line-numbering
(see below) to access the lines of the table.

=item line numbering

For tables of the type "view" when the user didn't specify the
primary key columns like shown above or for tables of the type
"table" where the user didn't specify and dbitable couldn't find the
primary key columns by another database query, the lines of the table
are simply numbered. Each line of the table is accessed with a number,
starting with "1" for the first line. There are no primary key columns
in this case. Note that functions like C<primary_keys()> return
C<undef> for such an object.

=back


The three object types

=over 4

=item *

"table"

With "table" the dbi-table object will hold a some or all parts of a
single table. The name of the table is given with the C<$table_name> parameter,
the name of the primary key is given with the C<$primary_key> parameter
(see the section above on primary keys).
Note that dbitable will not work correctly, if the primary key is not
unique for each line of the table. Note too, that usually the
primary key is a numeric (integer) field in the table.

=item *

"view"

With "view", the dbi-table object will hold the result of an arbitrary
SQL-query. Note that in this query, each column must be named with a
unique name. This means that for columns that are calculated or assembled,
they must be given a unique name with the "AS" SQL-statement. Of course,
a dbitable object, that was created as "view" cannot be written back to
the database, so C<store> will return an error. The table-name parameter
has in this case no special meaning.
The name of the primary key is given with the C<$primary_key> parameter
(see the section above on primary keys).

=item *

"file"

With "file", the C<load> and C<store> functions on this object will
will not connect to the database, but work on an ASCII file instead.
A single ASCII file can hold several dbitable-objects,
they are distinguished in the file by their "tag", basically a unique string
that identifies them. With C<store>, if there is already a section with the
tag C<$tag> in the file, it will simply be overwritten.

If the C<$filename> parameter is a reference to a scalar variable, this
scalar variable will be used instead of a file. load() will then read from
the contents of that variable and store() will write to that variable.

If the C<$filename> parameter is an empty string, standard-in and standard-out
will be used to when load() or store() is called on this table.

Note that as an option, a list (C<@column_list>) can be specified for a
table-object that is created as an empty object with no data. The C<@column_list>
has to be a list consisting of the name of the primary key, and a list of
the names of all columns.

This is not needed, if the table is loaded later (see C<load>) from a
file, since the file already contains a list of all columns and the
name of the primary key.

=back

=head2 loading:

  $table->load()

  $table->load(%options)

  my $tab= dbitable->new($database_handle,
                         'table',$table_name, $primary_key)->load();

This method loads the table from the database (for the type "table")
or from a file (type "file") or via a user-defined SQL statement
(type "view"). C<%options> is a hash that is used to pass optionial
parameters to the function. The function returns the object itself,
so it can be cascaded with C<new> in a single call, as you can see in
the third example.

In case of an error, the function calls C<dbdrv::dberror> or C<dbdrv::dbwarn>
and returns C<undef>. If the dbitable-object already contains data and
the SQL command issued fails, the data will be left intact.

Known options are:

=over 4

=item *

"filter"

A filter can only be used for the type "table". It is a way to
specify that only a part of the table shall be fetched. A typical
call of the C<load> function with a filter is:

  $table->load(filter=> ["equal",$column_name,$column_value])

As you can see, filter is a hash-key that has as a value a list-reference.
The list consists of at least one element, the filter-type. This
is possibly followed by a list of filter-parameters.

known filters:

=over 4

=item equal

  $table->load(filter=> ["equal",$column_name,$column_value])

In this case, only lines of the table, where column C<$column_name> has
a value that equals C<$column_value> are fetched.

=item SQL

  $table->load(filter=> ["SQL",$sql_statement])

This is used to specify the "WHERE" part of the SQL "SELECT"
statement directly. Note that C<$sql_statement> must not contain
the word "WHERE" itself, dbitable adds this automatically.

=back


=item *

"primary_key"

  $table->load(primary_key=>"preserve")

This option can only be used for the type "file" and defines the
primary_key mode. It must be either "preserve" or "generate". With "preserve",
the column that is the primary key is simply taken from the file as it is.
"preserve" is the default, if the primary_key mode is not specified.

With "generate" however, when the primary key is zero (0), a new
(for that table-line unique-) primary key is generated. This is useful,
when many lines are added to the file with a simple text editor. In this
case, the primary key field is set to zero. When the file is loaded with
the C<load> method, a new unique primary key is created while loading the file.
Otherwise, the user would have to count lines, and create unique numbers for each
new line he adds, which would be a rather dull task... ;)

Note that "generate" is not allowed for tables, where only a combination
of several columns forms the primary key.

=item *

"save_native_order"

  $table->load(save_native_order=>1)

This option can only be used for the type "table" or "view".
In this case the order of the table-lines as they come from the
database request is stored. This order of primary keys can later be
requested by calling C<primary_keys()> with the option "order_native".

=item *

"order_by"

  $table->load(order_by=> $sql_command)

This is used to specify the "ORDER BY" part of the SQL "SELECT"
statement directly. Note that C<$sql_statement> must not contain
the words "ORDER BY" itself, dbitable adds this automatically.
This option implies the option "save_native_order" (see above).

=item *

"mode"

  $table->load(mode=>'overwrite')

This option can only be used for the type 'table'. It defines what
to do, if the table already contains data before C<load()> is executed.
Three modes are known:

=over 4

=item "set"

This is the default. With "set", all lines from the table are removed,
before new lines are loaded from the database.

=item "add"

 With "add", the lines from the database are added to the
lines already in the table. Lines that were not loaded from the
database are marked "inserted". Lines that found in the table
already but are different from that in the database are marked
"updated".

=item "overwrite"

"overwrite" is similar to "add', but in this case lines that are
found already in the table but also in the database are overwritten
with the values from the database. The internal marking of lines
as "inserted" or "updated" has a meaning when a C<store()> is executed
for that table-object later.

=back

=item *

"pretty"

  $table->load(pretty=>1)

This option can only be used for the type "file". "pretty" must be
either "0" or "1". With "0", the file is just read as it is, this is the
default, when "pretty" is not defined. With "1", spaces at the end of fields
are removed. This option is needed, when the file was created (via C<store>)
with the "pretty" option also active (see C<store>).

=item *

"no_aliases"

  $table->load(no_aliases=>1)

This option can only be used for the type "file". "no_aliases" must be
either "0" or "1". With "0", the [Aliases] section from the file is not
read.

=item *

"new_name"

  $table->load(new_name=>"my_new_table_name")

By this option, the internal table name is changed to the new given
name. This may be useful when a table is loaded and shall then be stored
under a different name.

=back

=head2 storing:

  $table->store()

  $table->store(%options)

This method writes the content of the table back to the
database (for type "table") or to the file (for type "file").

Known options are:

=over 4

=item *

"primary_key"

  $table->store(primary_key=>"preserve")

This option can only be used for the type "table" and defines the
primary_key mode. This is only relevant for lines that were added to the table
and that are not yet in the database (C<store> uses the SQL command
"INSERT" in this case).

The primary-key mode must be either "preserve" or "generate", "generate"
is the default, when this option is not specified.

With "generate" , the primary key is calculated as a small unique number
for each new line in the table (note that it must be ensured that each
line in the table has a unique primary key). Before C<store>, each
added line in the table has a preliminary primary key (a rather large
number). During store, the value of the primary key changes, the old,
preliminary one however, remains valid as an alias (see C<add_aliases>).

With "preserve", the value of the primary key in the table is just taken
as it is. The user must ensure, that this key is unique for the new
inserted lines in the table-object. This mode is only useful, when
the primary key was directly set by the user.

Note that "generate" is not allowed for tables where only a combination
of columns forms the primary key.

=item *

"pretty"

  $table->store(pretty=>1)

This option can only be used for the type "file". "pretty" must be
either "0" or "1". With "0", the file is written in a space-saving
format. With "1", spaces are added at the end of fields, to make
the file more look like a real table. Files that were written
with the "pretty" option enabled, should only be read (via C<load>)
with the "pretty" option also enabled.

=item *

"no_aliases"

  $table->store(no_aliases=>1)

This option can only be used for the type "file". "no_aliases" must be
either "0" or "1". With "0", the file is written with aliases, keys that
reference single lines of the table. With "1" this section is omitted.

=item *

"order_by"

  $table->store(order_by=>[$column_name1,$column_name2])

This option can only be used for the type "file". It defines, wether lines
should be sorted by certain colums. The value may be the name of a single
column or (as shown above) a reference to a list
of column names.

=item *

"col_maps"

  $table->store(col_maps=>{ $column1 => \%col_map1,
                            $column2 => \%col_map2, ... } )

By this option, column-maps can be specified. These map
the values of a column to another value. Currently these are
only used for sorting (see above).

=back

=head2 export/import to files:

  $table->export_csv($filename, %options)

This method exports to a table to a file using the csv format,
which means comma separated value. If C<$filename> is an empty
string or <undef>, the table is written to standard-out.
The following options are
known:

=over 4

=item *

"order_by"

  $table->export_csv($filename,
                     order_by=>[$column_name1,$column_name2])

This option can only be used for the type "file". It defines, wether lines
should be sorted by certain colums. The value may be the name of a single
column or (as shown above) a reference to a list
of column names.

=item *

"col_maps"

  $table->export_csv($filename,
                     col_maps=>{ $column1 => \%col_map1,
                                 $column2 => \%col_map2, ... } )

By this option, column-maps can be specified. These map
the values of a column to another value. Currently these are
only used for sorting (see above).

=item *

"col_selection"

  $table->export_csv($filename, col_selection=> \@colum_names)

This exports only the columns of a table that are listed in @colum_names

=item *

"pk_selection"

  $table->export_csv($filename, pk_selection=> \@pk_selection)

This exports only lines of the table whose primary key are listed
in the given array C<@pk_selection>.

=back

  $table->import_csv($filename, %options)

This method imports a table from a file using the csv format.

=head2 importing a table:

  $dest_tab->import_table($source_tab,%options);

This method is used to import the contents of an existing table-object
into a new one. It is not necessary, that both tables are of the same type.
Known options are:

=over 4

=item *

"mode"

  $dest_tab->import_table($source_tab, mode=>"set_lines");

This is the import mode. Two modes are known, "add_lines" and "set_lines",
"add_lines" is the default. With "add_lines", the lines of the source-tables
are added to the lines that already exist in the destination table.
With "set_lines" however, the destination table is made equal to the
source-table. All lines that are not present in the source-table
(as defined by the primary-key) are deleted.

=item *

"primary_key"

  $dest_tab->import_table($source_tab, primary_key=>"generate");

This option defines the primary_key mode. It must be either "preserve"
or "generate", "generate" is the default.

It is only relevant for lines that were added to the table.

With "generate" , the primary key is calculated as a large unique number
for each new line in the table, called preliminary key. If the
table is written to the database (see "store"), this key is replaced with
a small unique number, the old one, however, remains valid as an alias
(see C<add_aliases>).

With "preserve", the value of the primary key is just taken from the source-table
and remains unchanged. If the table-object is written to the database
(see C<store>), the user must ensure, that this key is unique for new
inserted lines.

Note that "generate" is not allowed for tables, where only a combination
of several columns forms the primary key.

=item *

"column_aliases"

  $dest_tab->import_table($source_tab,
                          column_aliases=>
                                 { $dest_col1 => $src_col1,
                                   $dest_col2 => $src_col2 });

column-aliases are used to map colums of the source-table to columns
of the destination-table that have a different name. Note that for
columns, where a column-alias is not defined, columns of the source
are just mapped to columns of the destination that have the same name.

=back

=head2 miscelanious functions:

=over 4

=item std_database_handle()

  my $dbh= dbitable::std_database_handle();

This returns the internal standard database-handle. This
database-handle is used, when the C<undef> or an empty string
is used where otherwise a database-handle is expected. The standard
database-handle is simply the last database-handle that was returned
by the function C<dbitable::connect_database>. If
C<dbitable::connect_database> was never called, C<std_database_handle>
returns C<undef>.

=item primary_keys()

  my @keys= $table->primary_keys(%options)

This method returns a list consisting of the primary key of each
line of the table. If no options are given, all the primary keys
are given in a more or less random order.

The following options are known:

=over 4

=item native_order

  my @keys= $table->primary_keys(order_native=>1)

returns the primary keys just in the order they were returned
from the database. Note that this only works when each C<load>
command on the dbitable object had the option "save_native_order"
set.

=item order_by

  my @keys= $table->primary_keys(order_by=>[@column_names_list])

the primary keys are sorted according to the contents of the
columns given in the list. The first column has the highest precedence.
When the 1st column is equal in two lines, then the second column is
used for further sorting and so on.

=item col_maps

  my @keys= $table->primary_keys(col_maps=>{ $column1 => \%col_map1,
                                 $column2 => \%col_map2, ... } )

By this option, column-maps can be specified. These map
the values of a column to another value. Currently these are
only used for sorting (see above).

=item filter

  my @keys= $table->primary_keys(filter=>'updated')

  my @keys= $table->primary_keys(filter=>'inserted')

In this case, only primary keys of lines are returned, that are marked
as "updated" or marked as "inserted".

=back

=item primary_key_columns()

  my @pk_cols= $table->primary_key_columns()

This method returns the names of the primary-key columns in upper case.
In most cases there is exactly one primary key column. Note that
a table may also have no primary key columns at all (see comments on
primary keys at the start of this document). The function returns
C<undef> in this case.

=item primary_key_column_indices()

  my @pk_col_indices= $table->primary_key_column_indices()

This method returns the indices of the primary-keys in the list
of all columns. The index numbering of all columns starts with C<0>.
Note that a table may also have no primary key columns at all
(see comments on primary keys at the start of this document).
The function returns C<undef> in this case.

=item primary_keys_are_numeric()

  if ($table->primary_keys_are_numeric())
    { ... }

This function returns 1 when all primary key columns are numbers.
When there is only one primary key column and it is numeric, the
primary key generation feature (primary key mode: "generate") can
be used.

=item primary_key_auto_generate_possible()

  if ($table->primary_key_auto_generate_possible())
    { ... }

This function returns 1 when it is with the current table possible
to use auto-generated primary keys (see above).

=item column_list()

  my @columns= $table->column_list()

This method returns a list consisting of all column names
in upper case. The columns have the same sort order as in
the oracle database.

=item column_hash()

  my %columns= $table->column_hash()

This method returns a hash that maps each column-name it's column-index.
Columns are numbered starting with 0.

=item get_column_property()

  my %columns= $table->column_properties()
  my $length= $table->column_properties($columnname, $propertyname)

This method returns a hash that maps each column-name it's type, length,
precision, null-flag and default value if no columnname and one of the
property names given as argument. If columnname and propertyname given
the value will be returned.

=item get_column_type

    my $type= get_column_type($columnname)

This method returns the kind of logical columntype for $columnname.
(string, number, date, file or <undef>)

=item get_object_type

    my $object = get_object_type()

If you want to know what there is received from database (table, view
or sql (query)), use this simple function.

=item max_column_widths()

  my %columns= $table->max_column_widths($minwidth,$maxwidth)

This method returns a list that contains the maxmimum width for
each column. It is guaranteed that the returned values are
larger than C<$minwidth> and smaller than C<$maxwidth>.

=item foreign_keys()

  my $r_foreign_keys= $table->foreign_keys()

This method returns a reference to a hash that maps column-names to a list
containing two elements, the name of the foreign table and the
column-name in the foreign table. Note that this function works only
for the type 'table'.

=item resident_keys()

  my $r_resident_keys= $table->resident_keys()

This method returns a reference to a hash that maps column-names to a list
of lists. Each sub-list contains two elements, the name of the
resident table and the column-name in the resident table. "Resident" is
used here in opposition to "foreign". Viewed from the perspective of
the resident table, the current table is the foreign table.
The same relation is between foreign key and resident key.
A foreign key is always unique, it belongs to a single foreign
table. Viewed from the other side, this uniqueness is not guaranteed. That
is the reason that the hash contains a list of lists.
Note that this function works only for the type 'table'.

=item value()

  my $value= $table->value($primary_key, $column_name)

  $table->value($primary_key, $column_name, $value)

This method is used to get or set a value, that means a single field of
a single line. In the first form, the value is returned, in the 2nd form,
the value is set. Note that changes do only take effect in the database
or file, when C<store()> is called later on.
Note too, that in the 2nd form, the function returns C<$value> when
everything was ok, and C<undef> if setting the value was impossible
due to constraints dbitable.pm knows of (e.g. primary keys must be
always unique in the table).

=item find()

  my @pk_list= $table->find($column_name, $value, %flags)

This method searches the table to find a row where the value
in the specified column matches the given value. Note that this
method may be slow (a linear search) for columns that are
not the primary key column. The method returns a list of primary
keys that fullfill the match criteria. The C<%flags> parameter is
used to pass certain options. Known options are:

=over 4

=item find_first

If this is set (non-zero) the find function returns only the
primary key of the first line that matches, nothing more.

=item warn_not_pk

If this is set (non-zero) the function warns when the given
column us not the primary-key column.

=item warn_multiple

If this is set (non-zero) the function warns when more than
one line was found that matches the given value.

=back

=item add_line()

  my $primary_key= $table->add_line(%values)

This method is used add a line to the table. C<%values> is a hash, that
contains "column-name" "value" -pairs for the line. Note that each
column must be specified and column-names must be upper-case!
Currently there are no defaults supported.
Note that the method returns the primary key for the new line. Note
too, that this primary key changes with the next call of
C<store()>, see also C<store()>, but via aliasing (see C<add_aliases>)
it can then still be used to access the line.
If the value of the primary key is specified in the list of values,
it is taken as it is, and no new primary key is generated.

=item delete_line()

  $table->delete_line($primary_key)

This method deletes a line from the table. Note that this change is
made in the database or file only at the next call of C<store()>.

=item add_column_aliases()

  $table->add_column_aliases($column_name,%options)

This method is used to add aliases for a specific column to the
column-aliases. Two options are known, "uppercase" and "lowercase".
The alias is forced to be upper- or lowercase if one of these 
options is set.

=item add_aliases()

  $table->add_aliases(%aliases)

This method is used to add aliases to the table. An alias is a key that is
different from the value of the primary key, that can be used to access
a single line. An arbitrary number of aliases can be defined for a line.
Note however, that each alias must be unique. The C<%aliases> parameter
is a hash, containing pairs of the alias and the corresponding
primary key.

=item resolve_alias()

  my $primary_key= $table->resolve_alias($alias)

This method returns the primary key that is associated with a given alias.

=item max_key()

  my $max= $table->max_key()

This function returns the maximum primary key for a given table. Note that
this value is obtained directly by an SQL query from the database, no
matter what the current content of the table-object is.

=item dump()

  $table->dump()

This method dumps the complete internal data-structure of a table-object
and is for debugging purposes only.

=item dump_s()

  my $r_buffer= $table->dump_s()

This method dumps the complete internal data-structure of a table-object
to a text variable and returns a reference to that variable. It
is for debugging purposes only.

=item pretty_print()

  $table->pretty_print()

  $table->pretty_print(%options)

This method is used to pretty-print a given table.

Known options are:

=over 4

=item *

"order_by"

  $table->pretty_print(order_by=>[$column_name1,$column_name2])

This option defines, wether lines should be sorted by certain colums. The
value may be the name of a single column or (as shown above) a reference
to a list of column names.

=item *

"col_maps"

  $table->pretty_print(col_maps=>{ $column1 => \%col_map1,
                                   $column2 => \%col_map2, ... } )

By this option, column-maps can be specified. These map
the values of a column to another value. Currently these are
only used for sorting (see above).

=back

=back

=head2 miscelanious variables:

=over 4

=item $sim_delete

when set to 1, the deletion of lines in the table is only simulated
and not done for real. The default of this variable is 1, so deleting
lines is disabled as default !

=item $last_error

This variable contains the error-message for the last error
non-fatal that occured. An example is the case, when a new object
of type "table" is created, but the table doesn't exist. C<new()>
returns C<undef> in this case and C<$last_error> is set to
"table doesn't exist".

=back

=head1 EXAMPLES

=head2 query a database (type "table")

This example queries the p_insertion table here at HZB. It connects to
the database and creates a "table" object. C<new> and C<load> are called
in one line:

  use strict;
  use dbitable;

  my $dbname= "DBI:Oracle:bii_par";

  my $user="guest";
  my $pass="bessyguest";

  dbitable::connect_database($dbname,$user,$pass) or die;

  my $tab= dbitable->new('table',"",'p_insertion',
                         'insertion_key')->load();

  $tab->pretty_print();

  dbitable::disconnect_database();

=head2 arbitrary SQL query (type "view")

In this example, the insertion-device name-key (a number) is mapped
to the insertion-device name. For this, the "view" type is used. The
device-name has to be constructed (a simple string concatenation) by
querying 5 tables. Note that the "constructed" column consists of a
concatenation of "part_name", "part_index", "part_family", "part_subdomain",
"part_postfix" and "part_domain" and is named (naming is imperative!) to
"device_name" by the "... AS device_name" part of the statement.
The resulting table-object is just like any other table object, except
that a call of the store() method is not allowed.

  use strict;
  use dbitable;

  my $dbname= "DBI:Oracle:bii_par";

  my $user="guest";
  my $pass="bessyguest";

  dbitable::connect_database($dbname,$user,$pass) or die;


  my $tab= dbitable->new('view',"",'v_names','name_key',
        "select N.name_key, " .
        "       part_name || part_index || part_family || " .
        "                    part_subdomain || part_postfix || " .
        "                    part_domain AS device_name " .
        "  from p_insertion I, p_name N, p_subdomain S, " .
        "       p_family F, p_domain D " .
        "  where I.name_key = N.name_key AND " .
        "        N.subdomain_key = S.subdomain_key AND " .
        "        N.family_key = F.family_key AND " .
        "        S.domain_key = D.domain_key"
                             )->load();


  $tab->pretty_print();

  dbitable::disconnect_database();

=head2 reading of a table and writing to a file (type "file")

The following example reads the table "p_insertion" and writes it to a file.
Since the original table-object is of the type "table", a new object of
the type "file" is created by calling the C<new> method on the first
table-object. Using C<dbitable->new(...)> and calling <$ntab->import_table(..)>
would have been another possibility to achive this. After the program was
executed, you may have a look at the file "TEST.TXT", which is created by
this little application.

  use strict;
  use dbitable;

  my $dbname= "DBI:Oracle:bii_par";

  my $user="guest";
  my $pass="bessyguest";

  dbitable::connect_database($dbname,$user,$pass) or die;

  my $tab= dbitable->new('table',"",'p_insertion',
                         'insertion_key')->load();

  my $ntab= $tab->new('file',"TEST.TXT","TEST-TAG")->store();

  dbitable::disconnect_database();

=head2 modifying a table and writing back to the database (type "table")

This script reads the table, adds a line and writes back to the database.
Note that the primary key 'insertion_key' must not be specified when
C<add_line> is called, a new primary key is created automagically.
Note too, that if you really try to execute this script, it will fail,
since the guest-user has no write priviledges.
C<$dbdrv::sql_trace=1> will force the dbitable module to print all
SQL commands to the screen, before they are executed.

  use strict;
  use dbdrv;
  use dbitable;

  $dbdrv::sql_trace=1;

  my $dbname= "DBI:Oracle:bii_par";

  my $user="guest";
  my $pass="bessyguest";

  dbitable::connect_database($dbname,$user,$pass) or die;

  my $tab= dbitable->new('table',"",'p_insertion',
                         'insertion_key')->load();

  $tab->add_line(NAME_KEY=> 1,
                 INTERNAL_NAME=> "XX",
                 IOC_KEY=> 2,
                 DESCRIPTION=>"test",
                 DEVICE_CONDITION=>1);

  $tab->pretty_print();

  $tab->store();

  dbitable::disconnect_database();

=head2 writing a file back to the database

This script reads a table from an existing file. Then it reads
from the database and kind of compares this with the data from the
file. The changed lines are then stored back to the database. The advantage
of reading from the database before writing to it is that the
SQL "update" command is only executed for lines that have found to be
different from the lines stored in the database.

  use strict;
  use dbdrv;
  use dbitable;

  $dbdrv::sql_trace=1;

  my $dbname= "DBI:Oracle:bii_par";

  my $user="guest";
  my $pass="bessyguest";

  dbitable::connect_database($dbname,$user,$pass) or die;

  my $ftab= dbitable->new('file',"TEST.TXT","TEST-TAG")->load();

  my $tab = $ftab->new('table',"",'','');
  # 1st '': take table-name from $ftab
  # 2nd '': take primary key from $ftab

  $tab->load(mode=>"add");

  $tab->store();
  dbitable::disconnect_database();


=head1 AUTHOR

Goetz Pfeiffer,  pfeiffer@mail.bessy.de

=head1 SEE ALSO

perl-documentation, DBI manpage

=cut

internal data-structure
The table-Object is a hash. Summary of hash-keys:
_aliases:     ref of a hash, that contains aliases
_column_list: ref of a list of columns, all upper-case
_columns:     ref of a hash that maps column-names to column-numbers,
              the first column has index 0, all column-names upper case
_dbh:         the DBI-handle the table object uses
_fetch_cmd:   the last SQL command,
_lines:       a ref to a hash, each primary key points to a reference
              to a list. Each list contains the values in the order of the
              columns (see also "_column_list")
_pks:         the column-name(s) of the primary key, usually lower-case
_pkis:        the column-index/indices of the primary key(s)
_pk_is_numeric 1 if (all) primary key(s) are numeric
_multi_pk     1 if there's more than one primary key
_counter_pk   1 if the primary key is just a line-counter
_table:       the name of the table, as it's used in oracle
_type:        the type of the table, "table","view" or "file"
_types:       the types of the columns, "number" or "string"

_foreign_keys ref to a hash, col_name => [foreign_table,foreign_column]
              this contains information about foreign keys
_resident_keys
              ref to a hash,
                 col_name => [ [foreign_table1,foreign_column1],
                               [foreign_table2,foreign_column2]
                                 ...
                             ]
              this contains information about resident keys

SELECT a.owner, a.table_name, b.column_name
  FROM all_constraints a, all_cons_columns b
 WHERE a.constraint_type='P'
   AND a.constraint_name=b.constraint_name
   AND a.table_name = 'P_INSERTION_VALUE';

