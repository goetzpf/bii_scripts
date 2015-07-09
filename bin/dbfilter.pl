eval 'exec perl -S $0 ${1+"$@"}' # -*- Mode: perl -*-
    if 0;
# the above is a more portable way to find perl
# ! /usr/bin/perl

# Copyright 2015 Helmholtz-Zentrum Berlin für Materialien und Energie GmbH
# <https://www.helmholtz-berlin.de>
#
# Author: Goetz Pfeiffer <Goetz.Pfeiffer@helmholtz-berlin.de>
#
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later
# version.
# 
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
# details.
# 
# You should have received a copy of the GNU General Public License along with
# this program.  If not, see <http://www.gnu.org/licenses/>.


# @STATUS: release
# @PLATFORM: home bessy
# @CATEGORY: search


# [scriptname] -- describe the function here

use strict;

use FindBin;
use Getopt::Long;
use Data::Dumper;

use parse_db 1.3;
use analyse_db 1.0;
use canlink;

use vars qw($opt_help $opt_summary
            $opt_dump_internal $opt_recreate
            $opt_db
            $opt_short
            $opt_val_regexp @opt_field
            $opt_name
            $opt_notname
            $opt_name_file
            $opt_notname_file
            $opt_type
            $opt_value
            @opt_info
            $opt_infovalue
            $opt_dtyp
            $opt_fields
            $opt_empty
            $opt_rm_capfast_defaults
            $opt_skip_empty_records
            $opt_list
            $opt_dot
            $opt_rm_prefix
            $opt_percent
            $opt_unresolved_variables
            $opt_unresolved_links
            $opt_record_references
            $opt_allow_double
            $opt_single
            $opt_lowcal
            $opt_Lowcal
            $opt_sdo
            $opt_Sdo
            $opt_recursive
           );


my $sc_version= "1.7";

my $sc_name= $FindBin::Script;
my $sc_summary= "parse db files";
my $sc_author= "Goetz Pfeiffer";
my $sc_year= "2014";

my $debug= 0; # global debug-switch

#Getopt::Long::config(qw(no_ignore_case));

if (!@ARGV)
  { help();
    exit;
  };

Getopt::Long::config(qw(no_ignore_case));

if (!GetOptions("help|h","summary",
                "dump_internal|dump-internal|i",
                "recreate|r",
                "db",
                "val_regexp|v=s",
                "short|s",
                "field=s@",
                "name|NAME|n=s", "notname|NOTNAME=s",
                "name-file=s", "notname-file=s",
                "value=s",
                "info=s@",
                "infovalue=s",
                "dtyp|DTYP=s",
                "type|TYPE|t=s",
                "fields|FIELDS=s",
                "empty|e",
                "rm_capfast_defaults|rm-capfast-defaults|E",
                "skip_empty_records|skip-empty-records",
                "list|l",
                "dot",
                "rm-prefix=s",
                "percent=s",
                "unresolved_variables|unresolved-variables",
                "unresolved_links|unresolved-links:i",
                "record_references|record-references|R=s",
                "allow_double|allow-double|A",
                "single|S",
                "lowcal:s", "Lowcal:s",
                "sdo:s", "Sdo:s",
                "recursive|rec=i",
                ))
  { die "parameter error!\n"; };

if ($opt_help)
  { help();
    exit;
  };

if ($opt_summary)
  { print_summary();
    exit;
  };

if ($opt_lowcal ne "")
  { if ($opt_lowcal!~/=/)
      { push @ARGV,$opt_lowcal;
        $opt_lowcal="";
      };
  };

if ($opt_Lowcal ne "")
  { if ($opt_Lowcal!~/=/)
      { push @ARGV,$opt_Lowcal;
        $opt_Lowcal="";
      };
  };

if ($opt_sdo ne "")
  { if ($opt_sdo!~/=/)
      { push @ARGV,$opt_sdo;
        $opt_sdo="";
      };
  };

if ($opt_Sdo ne "")
  { if ($opt_Sdo!~/=/)
      { push @ARGV,$opt_Sdo;
        $opt_Sdo="";
      };
  };

if    (defined $opt_allow_double)
  { parse_db::handle_double_names(2); }
elsif (defined $opt_single)
  { parse_db::handle_double_names(0); }
else
  { # merging of double record-names is the default
    parse_db::handle_double_names(1);
  }

my @files= @ARGV;
if ($#ARGV<0)
  { # no file given, read from STDIN
    @files= (undef);
  };

my $ext_db_hash= parse_db::parse_file(\@files,"extended");

if ($opt_rm_prefix)
  {
    my %link_fields= map {$_=>1} @analyse_db::link_fields;
    my $r_dbhash= $ext_db_hash->{"dbhash"};
    if ($r_dbhash)
      {
        rm_prefix_in_hash($opt_rm_prefix, $r_dbhash, 1, 0);
        foreach my $rec_hash (values %$r_dbhash)
          {
            rm_prefix_in_hash($opt_rm_prefix, $rec_hash->{FIELDS},
                                  0, 1, \%link_fields);
          }
      }
    my $r_aliasmap= $ext_db_hash->{"aliasmap"};
    if ($r_aliasmap)
      {
        rm_prefix_in_hash($opt_rm_prefix, $r_aliasmap, 1, 1);
      }
    my $r_realrecords= $ext_db_hash->{"realrecords"};
    if ($r_realrecords)
      {
        rm_prefix_in_hash($opt_rm_prefix, $r_realrecords, 1, 0);
      }
  }
    
if (defined $opt_name)
  { filter_name($ext_db_hash,$opt_name); };

if (defined $opt_notname)
  { filter_name($ext_db_hash,$opt_notname,1); };

if (defined $opt_name_file)
  { filter_name_file($ext_db_hash,$opt_name_file); };

if (defined $opt_notname_file)
  { filter_name_file($ext_db_hash,$opt_notname_file,1); };

if (defined $opt_type)
  { filter_type($ext_db_hash,$opt_type); };

if ($opt_dtyp)
  { filter_records($ext_db_hash,"DTYP",$opt_dtyp);
  };

if (@opt_info)
  { foreach my $fil (@opt_info)
      { my($field,$regexp)= split(",",$fil);

        find_info($ext_db_hash,$field,$regexp);
      };
  };

if (@opt_field)
  { foreach my $fil (@opt_field)
      { my($field,$regexp)= split(",",$fil);

        filter_records($ext_db_hash,$field,$regexp);
      };
  };

if (defined $opt_val_regexp)
  { find_val($ext_db_hash,$opt_val_regexp,0);
  };

if (defined $opt_fields)
  { my @fields= split(",",$opt_fields);
    filter_fields($ext_db_hash,\@fields);
  };

if (defined $opt_empty)
  { remove_empty_fields($ext_db_hash);
  };

if (defined $opt_rm_capfast_defaults)
  { remove_capfast_default_fields($ext_db_hash);
  };

if (defined $opt_percent)
  { filter_percent($ext_db_hash,$opt_percent); };

if ((!defined $opt_dump_internal) &&
    (!defined $opt_lowcal) &&
    (!defined $opt_Lowcal) &&
    (!defined $opt_sdo) &&
    (!defined $opt_Sdo) &&
    (!defined $opt_short) &&
    (!defined $opt_recreate) &&
    (!defined $opt_value) &&
    (!defined $opt_list) &&
    (!defined $opt_unresolved_variables) &&
    (!defined $opt_unresolved_links) &&
    (!defined $opt_record_references)
   )
  { $opt_recreate=1; };

if (defined $opt_value)
  { find_val($ext_db_hash,$opt_value,1);
    exit(0);
  };

if (defined $opt_infovalue)
  {
    find_info($ext_db_hash,undef,$opt_infovalue);
  };

if (defined $opt_unresolved_variables)
  {
    my %flags= ();
    if ($opt_recreate)
      { $flags{"add_records"}= 1; }
    if ($opt_db)
      { $flags{"only_records"}= 1; }
    list_unresolved_variables($ext_db_hash,\%flags);
    exit(0);
  };

if (defined $opt_unresolved_links)
  {
    if ($opt_unresolved_links eq "")
      { $opt_unresolved_links=2; } # default: 2
    my %flags= ();
    if ($opt_recreate)
      { $flags{"add_records"}= 1; }
    if ($opt_db)
      { $flags{"only_records"}= 1; }
    list_unresolved_links($ext_db_hash, $opt_unresolved_links, \%flags);
    exit(0);
  };

if (defined $opt_record_references)
  {
    my %flags= ();
    if ($opt_recreate)
      { $flags{"add_records"}= 1; }
    if ($opt_db)
      { $flags{"only_records"}= 1; }
    if ($opt_list)
      { $flags{"list"}= 1; };
    if ($opt_dot)
      { $flags{"dot"}= 1; };

    list_record_references($ext_db_hash,
                           $opt_record_references,
                           \%flags,
                           $opt_recursive);
    exit(0);
  };

if (defined $opt_list)
  { foreach my $r (sort keys %{$ext_db_hash->{dbhash}})
      { 
        print $r,"\n";
      };
    exit(0);
  };

if ((defined $opt_lowcal) || (defined $opt_Lowcal))
  { 
    my $par= $opt_lowcal;
    $par= $opt_Lowcal if (!defined $par);
    lowcal($ext_db_hash,(defined $opt_Lowcal),$par);
    exit(0);
  };

if ((defined $opt_sdo) || (defined $opt_Sdo))
  { 
    my $par= $opt_sdo;
    $par= $opt_Sdo if (!defined $par);
    sdo($ext_db_hash,(defined $opt_Sdo),$par);
    exit(0);
  };

if (defined $opt_skip_empty_records)
  { rem_empty_records($ext_db_hash); };

if (defined $opt_dump_internal)
  { dump_recs($ext_db_hash);
    exit(0);
  };

if (defined $opt_short)
  { 
    one_line_dump_recs($ext_db_hash);
    exit(0);
  };

if (defined $opt_recreate)
  { 
    parse_db::create($ext_db_hash->{realrecords});
    parse_db::create_aliases($ext_db_hash->{aliasmap});
    exit(0);
  };
exit(0);

sub rem_empty_records
  { my($r_ext_db)= @_;

    my $r_dbhash= $r_ext_db->{dbhash};
    my @delete;
    foreach my $rec (sort keys %$r_dbhash)
      { my $r_f= $r_dbhash->{$rec}->{FIELDS};
        if (!%$r_f)
          { push @delete, $rec; };
      };
    my $r_realrecords= $r_ext_db->{realrecords};
    my $r_aliasmap= $r_ext_db->{aliasmap};
    foreach my $r (@delete)
      {
        delete $r_dbhash->{$r};
        delete $r_realrecords->{$r};
        delete $r_aliasmap->{$r};
      };
  }

sub one_line_dump_recs
# dump all records, one record per line
  { my($r_ext_db)= @_;

    my $r_dbhash= $r_ext_db->{dbhash};
    foreach my $rec (sort keys %$r_dbhash)
      { 
        print $rec;
        my $r_f= $r_dbhash->{$rec};
        print ",",$r_f->{TYPE},",";
        my $r= $r_f->{FIELDS};
        my $comma;
        foreach my $f (sort keys %$r)
          { print $comma,$f,"=",$r->{$f};
            $comma= ",";
          }
        print "\n";
      };
  }

sub dump_recs
# dump the internal record-hash structure
  { my($r_ext_db_hash)= @_;

    parse_db::dump_real($r_ext_db_hash);
  }

sub dump_rec_fields
# print a simple fdump of a given list of fields in a record
  { my($rec,$r_fields)= @_;

    my $r_values= $rec->{FIELDS};
    foreach my $v (@$r_fields)
      { print "\t",$v," -> \"",$r_values->{$v},"\"\n"; };
  }

sub find_val_in_rec
# return all fields in a record that match a
# regular expression
  { my($rec)= @_;
    my @matches;

    my $r_values= $rec->{FIELDS};
    foreach my $v (sort keys %$r_values)
      {
        next if (!value_filter($r_values->{$v}));
        push @matches, $v;
      };
    return(@matches);
  }

sub filter_rec_fields
# remove all fields in a record that are not
# part of a given hash
  { my($rec, $r_field_hash)= @_;
    my @rem;

    my $r_values= $rec->{FIELDS};
    foreach my $v (sort keys %$r_values)
      { if (!exists $r_field_hash->{lc($v)})
          { push @rem, $v; };
      };
    foreach my $v (@rem)
      { delete $r_values->{$v}; };
  }

sub filter_fields
# remove all fields in all records that
# are part of a given list
  { my($r_ext_db,$r_fields)= @_;
    my %h= map { lc($_)=>1 } @$r_fields;

    my $r_dbhash= $r_ext_db->{dbhash};
    foreach my $rec (sort keys %$r_dbhash)
      { filter_rec_fields($r_dbhash->{$rec}, \%h); };
  }

sub remove_empty_fields
# remove empty fields in all records
  { my($r_ext_db)= @_;

    my $r_dbhash= $r_ext_db->{dbhash};
    foreach my $rec (sort keys %$r_dbhash)
      { my $r_values= $r_dbhash->{$rec}->{FIELDS};
        foreach my $f (keys %$r_values)
          { if ($r_values->{$f}=~ /^\s*$/)
              { delete $r_values->{$f}; };
          };
      };
  }

sub remove_capfast_default_fields
# remove empty fields in all records
  { my($r_ext_db)= @_;

    my $r_dbhash= $r_ext_db->{dbhash};
    analyse_db::rem_capfast_defaults($r_dbhash);
  }

sub match_fields
# return all fields of a record that
# match a given regexp, note:
# this function calls "field_matcher"
  { my($rec,$r_fields)= @_;
    my @matched;

    my $r_values= $rec->{FIELDS};
    foreach my $v (sort keys %$r_values)
      { if (field_matcher($v))
          { push @matched, $v; };
      };
    return(@matched);
  }

sub list_unresolved_variables
  { my ($r_ext_db,$r_flags)= @_;
    my $res;
    my %mac;
    my %recs;

    my $r_dbhash= $r_ext_db->{dbhash};
    foreach my $rec (sort keys %$r_dbhash)
      { $res= add_macros(\%mac, $rec);
        my $r_fields= $r_dbhash->{$rec}->{FIELDS};
        foreach my $fieldname (keys %$r_fields)
          { $res|= add_macros(\%mac, $r_fields->{$fieldname}); };
        if ($res)
          { $recs{$rec}= 1; };
      };
    if (!$r_flags->{"only_records"})
      {
        print "=" x 40,"\n";
        print "unresolved macros in these records:\n";
        print "-" x 40,"\n";
        print join("\n", sort keys %recs);
        print "\n\nList of unresolved macros:\n";
        print "-" x 40,"\n";
        print join("\n",sort keys %mac),"\n";
      }
    if ($r_flags->{"add_records"} || $r_flags->{"only_records"})
      {
        if (!$r_flags->{"only_records"})
          { print "=" x 40,"\nRecords:\n"; }
        my @reclist= sort keys %recs;
        parse_db::create($r_dbhash,\@reclist);
      }
  }

sub list_record_references
# recs: this complete list of records to work on
  { my ($r_ext_db,$record_name,$r_flags,$recursive)= @_;

    my %references;
    my %referenced_by;
    my @reclist;
    my %to_print;

    # add information about which record is linked
    # to which other record
    my $linkset_hash;
    my $post_filter;

    my $r_dbhash= $r_ext_db->{dbhash};
    analyse_db::add_link_info($r_dbhash);
    if ($record_name !~ /^(all|\/\/)$/i)
      { if ($record_name=~/^([^,]+),(.+)$/)
          { # form: record-name, regexp
            $record_name= $1;
            $post_filter= $2;
          }
        create_regexp_func("ref_name_filter",$record_name);
        if (defined $post_filter)
          { create_regexp_func("post_name_filter",$post_filter); }
        foreach my $rec (sort keys %$r_dbhash)
          {
            if (ref_name_filter($rec))
              {
                push @reclist,$rec;
              };
          };
        if (!@reclist)
          { die "no record-names match the given pattern: $record_name\n"; };
        if (defined $recursive)
          { # recursively get a list of records that depend
            # on the given one
            my $filter_func= undef;
            if ($post_filter)
              {
                $filter_func= \&post_name_filter;
              }
            $linkset_hash= analyse_db::linkset_hash($r_dbhash,
                                                    \@reclist,$recursive,
                                                    $filter_func);
            @reclist= sort{ $linkset_hash->{$a} <=> $linkset_hash->{$b} }
                      (sort keys %$linkset_hash);
#die "reclist:".join("|",@reclist);
          }
      }
    else
      { @reclist=(sort keys %$r_dbhash); };

    #print parse_db::dump($recs->{$reclist[0]}); die;

    if ($r_flags->{"list"})
      {
        foreach my $recname (@reclist)
          {
            print $recname,"\n";
          }
        return;
      }
    if ($r_flags->{"dot"})
      {
        my %links;
        foreach my $recname (@reclist)
          { 
            my $r_references_hash   = analyse_db::references_hash($r_dbhash,$recname);
            my @references= keys %$r_references_hash;
            #my @referenced_by= analyse_db::referenced_by_list($r_dbhash,$recname);

            if ($post_filter)
              { 
                @references= grep { post_name_filter($_) } @references;
                #@referenced_by= grep { post_name_filter($_) } @referenced_by;
              }
            foreach my $r (@references)
              { 
                my $label= $r_references_hash->{$r};
                $links{"\"$recname\" -> \"$r\" [label=\"$label\"]"}= 1;
              }
            # foreach my $r (@referenced_by)
            # { 
            #   $links{"\"$r\" -> \"$recname\""}= 1;
            # }
          }
        print "digraph \"record-dependencies\" {\n";
        print "    margin=\"0.3\";\n";
        print "    ratio=\"fill\";\n";
        print "    size=\"11.7,8.3!\";\n";

        foreach my $l (sort keys %links)
          {
            print "    $l;\n";
          }
        print "}\n";
        return;
      }
    if (!$r_flags->{"only_records"})
      {
        foreach my $recname (@reclist)
          { my @references   = analyse_db::references_list($r_dbhash,$recname);
            my @referenced_by= analyse_db::referenced_by_list($r_dbhash,$recname);

            if ($post_filter)
              { 
                @references= grep { post_name_filter($_) } @references;
                @referenced_by= grep { post_name_filter($_) } @referenced_by;
              }

            if ((!@references) && (!@referenced_by))
              { next; };

            #if (defined $post_filter)
            #  { @references   = grep { post_name_filter($_) } @references;
            #    @referenced_by= grep { post_name_filter($_) } @referenced_by;
            #  };

            print $recname;
            # print "distance" to source records:
            if ($linkset_hash)
              { print "(",$linkset_hash->{$recname},")"; };

            print "\n";

            if (@references)
              {
                my $ref_h= analyse_db::references_hash($r_dbhash, $recname);
                print "  references:\n";
                foreach my $r (@references)
                  {
                    printf("\t%-30s %s\n", $r, $ref_h->{$r});
                  }
              };
            if (@referenced_by)
              {
                my $ref_h= analyse_db::referenced_by_hash($r_dbhash, $recname);
                print "  referenced by:\n";
                foreach my $r (@referenced_by)
                  {
                    printf("\t%-30s %s\n", $r, $ref_h->{$r});
                  }
              };
            print "\n";
          };
      };
    if ($r_flags->{"add_records"} || $r_flags->{"only_records"})
      {
        if (!$r_flags->{"only_records"})
          { print "=" x 40,"\nRecords:\n"; }
        #my %my_recs= map { $_ => $recs->{$_} } (keys %to_print);
        #parse_db::create(\%my_recs);
        parse_db::create($r_dbhash,\@reclist);
      };
  }

sub list_unresolved_links
  { my ($r_ext_db,$verbosity,$r_flags)= @_;
    my $res;
    my %mac;
    my %found_recs;

    my $r_dbhash= $r_ext_db->{dbhash};
    foreach my $rec (sort keys %$r_dbhash)
      {
        my $r_ref_fields= analyse_db::rec_link_fields($r_dbhash,$rec);
        foreach my $f (keys %$r_ref_fields)
          { if (exists $r_dbhash->{$r_ref_fields->{$f}->[0]})
              { delete $r_ref_fields->{$f}; };
          };
        if (!%$r_ref_fields)
          { next; };
        $found_recs{$rec}= $r_ref_fields;
      };

    if (!$r_flags->{"only_records"})
      {
        if ($verbosity==0)
          { # just list all items (values) that are missing
            my %values;
            foreach my $recname (keys %found_recs)
              { my $r_f= $found_recs{$recname};
                foreach my $field (keys %$r_f)
                  { $values{$r_f->{$field}->[0]}= 1; };
              };
            print join("\n",sort keys %values),"\n";
          }
        else
          {
            if ($verbosity>1)
              {
                print "=" x 40,"\n";
                print "unresolved links in these records:\n";
                print "-" x 40,"\n";
                print join("\n", sort keys %found_recs);
                print "\n\n";
              };
            print "List of fields with unresolved links\n";
            print "-" x 40,"\n";
            foreach my $recname (sort keys %found_recs)
              { my $r_f= $found_recs{$recname};
                print "record: $recname\n";
                foreach my $field (sort keys %$r_f)
                  { print "\t$field : ",$r_f->{$field}->[0],"\n"; };
              };
          }
      };
    if ($r_flags->{"add_records"} || $r_flags->{"only_records"})
      {
        if (!$r_flags->{"only_records"})
          { print "=" x 40,"\nRecords:\n"; }
        my @reclist= sort keys %found_recs;
        parse_db::create($r_dbhash,\@reclist);
      }
  }

sub add_macros
  { my($r_h, $st)= @_;
    my @l= collect_macros($st);
    return if (!@l);
    foreach my $m (@l)
      { $r_h->{$m}=1; };
    return(1);
  }

sub collect_macros
  { my($st)= @_;
    my @l;

    while ($st=~ /\$\(([^\)]*)\)/g)
      { push @l,$1; };
    return(@l);
  }

sub filter_records
# remove all records where a field does not
# match a given regular expression
  { my($r_ext_db,$field,$regexp)= @_;
    my @nomatch;
    my $field_is_regexp;

#die "$field,$regexp";
    if ($field=~ /\//)
      { # field is a regular expression
        create_regexp_func("field_matcher",$field);
        $field_is_regexp= 1;
      };

    create_regexp_func("field_filter",$regexp);

    my $r_dbhash= $r_ext_db->{dbhash};
    foreach my $rec (sort keys %$r_dbhash)
      {
        if (!$field_is_regexp)
          { if (!field_filter( $r_dbhash->{$rec}->{FIELDS}->{$field} ))
              { push @nomatch, $rec ;
              };
          }
        else
          { my @f= match_fields($r_dbhash->{$rec});
#print "F: " . join("|",@f) . "\n";
            my $match;
            foreach my $f (@f)
              { if (field_filter( $r_dbhash->{$rec}->{FIELDS}->{$f}))
                  { $match=1; last; };
              };
            if (!$match)
              { push @nomatch, $rec ;
              };
          }
      };
    my $r_realrecords= $r_ext_db->{realrecords};
    my $r_aliasmap= $r_ext_db->{aliasmap};
    foreach my $r (@nomatch)
      {
        delete $r_dbhash->{$r};
        delete $r_realrecords->{$r};
        delete $r_aliasmap->{$r};
      };
  }

sub filter_type
# remove all records whose type does not
# match a given regular expression
  { my($r_ext_db,$regexp)= @_;
    my @nomatch;

#die "$r_rec,$regexp";
    create_regexp_func("type_filter",$regexp);

    my $r_dbhash= $r_ext_db->{dbhash};
    foreach my $rec (sort keys %$r_dbhash)
      { if (!type_filter($r_dbhash->{$rec}->{TYPE}))
          { push @nomatch, $rec ;
          };
      };
    my $r_realrecords= $r_ext_db->{realrecords};
    my $r_aliasmap= $r_ext_db->{aliasmap};
    foreach my $r (@nomatch)
      {
        delete $r_dbhash->{$r};
        delete $r_realrecords->{$r};
        delete $r_aliasmap->{$r};
      };
  }

sub scan_file
# scan contents of a file with a list of records
  { my($filename)= @_;
    local *IN;
    my %recs;
    open(IN, $filename) || die "unable to open $filename\n";
    while(my $line=<IN>)
      { 
	chomp($line);
        $line=~ s/^\s+//;
        my @names= split(/\s+/,$line);
        foreach my $n (@names)
          {
            $recs{$n}= 1;
          };
      };
    close(IN);
    return \%recs;
  }

sub filter_name
# remove all records whose name do or do not match a
# given regular expression
  { my($r_ext_db,$regexp,$invert)= @_;
    my @nomatch;

    create_regexp_func("name_filter",$regexp,$invert);

    my $r_dbhash= $r_ext_db->{dbhash};
    foreach my $rec (sort keys %$r_dbhash)
      { if (!name_filter($rec))
          { push @nomatch, $rec ;
          };
      };
    my $r_realrecords= $r_ext_db->{realrecords};
    my $r_aliasmap= $r_ext_db->{aliasmap};
    foreach my $r (@nomatch)
      {
        delete $r_dbhash->{$r};
        delete $r_realrecords->{$r};
        delete $r_aliasmap->{$r};
      };
  }

sub filter_name_file
# remove all records whose name do or do not match a
# list of records in a file
  { my($r_ext_db,$filename,$invert)= @_;
    my @nomatch;

    my $r_recs= scan_file($filename);

    my $r_dbhash= $r_ext_db->{dbhash};
    foreach my $rec (sort keys %$r_dbhash)
      { 
        if (exists $r_recs->{$rec})
          {
            if ($invert)
              { 
                push @nomatch, $rec ;
              };
          }
        else
          {
            if (!$invert)
              { 
                push @nomatch, $rec ;
              };
          }
      };
    my $r_realrecords= $r_ext_db->{realrecords};
    my $r_aliasmap= $r_ext_db->{aliasmap};
    foreach my $r (@nomatch)
      {
        delete $r_dbhash->{$r};
        delete $r_realrecords->{$r};
        delete $r_aliasmap->{$r};
      };
  }

sub filter_percent
  { my($r_ext_db,$percent)= @_;

    my $r_dbhash= $r_ext_db->{dbhash};
    my @rem_recs= (sort keys %$r_dbhash);
    my $len= $#rem_recs+1;

    if ($percent>0) # remove last <no> percent
      { my $n= int($percent/100*$len+0.5); # one more for safety reasons
        @rem_recs= splice @rem_recs,$n+1,($len-$n);
      }
    else
      { my $n= int((100+$percent)/100*$len+0.5);
        @rem_recs= splice @rem_recs,0,$n+1;
      };
    my $r_realrecords= $r_ext_db->{realrecords};
    my $r_aliasmap= $r_ext_db->{aliasmap};
    foreach my $r (@rem_recs)
      {
        delete $r_dbhash->{$r};
        delete $r_realrecords->{$r};
        delete $r_aliasmap->{$r};
      };
  }


sub find_val
# remove all records where not one of the
# fields matches a given regular expression
  { my($r_ext_db,$regexp,$filter_fields)= @_;
    my @fields;
    my @delete;

    create_regexp_func("value_filter",$regexp);

    my $r_dbhash= $r_ext_db->{dbhash};
    foreach my $rec (sort keys %$r_dbhash)
      {
        @fields= find_val_in_rec( $r_dbhash->{$rec});
        if (!@fields)
          { push @delete, $rec; };
        if ((@fields) && ($filter_fields))
          { 
            print "\"$rec\": \n";
            dump_rec_fields($r_dbhash->{$rec}, \@fields);
          };
      };
    if ($filter_fields)
      { return; };
    my $r_realrecords= $r_ext_db->{realrecords};
    my $r_aliasmap= $r_ext_db->{aliasmap};
    foreach my $r (@delete)
      {
        delete $r_dbhash->{$r};
        delete $r_realrecords->{$r};
        delete $r_aliasmap->{$r};
      };
  }

sub find_info
# remove all records where not one of the
# info fields matches a given regular expression
  { my($r_ext_db,$wanted_info_name,$regexp_value)= @_;
    my @fields;
    my @delete;

    if (defined $regexp_value)
      {
        create_regexp_func("info_value_filter",$regexp_value);
      }

    my $r_dbhash= $r_ext_db->{dbhash};
    foreach my $rec (sort keys %$r_dbhash)
      {
        my $r_info= $r_dbhash->{$rec}->{INFO};
        if (defined $wanted_info_name)
          {
            my $val= $r_info->{$wanted_info_name};
            if (!defined $val)
              {
                push @delete, $rec;
                next;
              }
            if (defined $regexp_value)
              {
                if (!info_value_filter($val))
                  {
                    push @delete, $rec;
                    next;
                  }
              }
          }
        else
          {
            my $match= 0;
            foreach my $infoname (keys %$r_info)
              {
                if (defined $regexp_value)
                  {
                    if (info_value_filter($r_info->{$infoname}))
                      {
                        $match= 1;
                        next;
                      }
                  }
              }
            if (!$match)
              {
                push @delete, $rec;
              }
          }
      }

    my $r_realrecords= $r_ext_db->{realrecords};
    my $r_aliasmap= $r_ext_db->{aliasmap};
    foreach my $r (@delete)
      {
        delete $r_dbhash->{$r};
        delete $r_realrecords->{$r};
        delete $r_aliasmap->{$r};
      };
  }

sub lowcal
  { my($r_ext_db,$reverse,$filters)= @_;
    my %filter_hash;

    my %filter_map=
      ( srv=> 'server',
        mul=>'multi',
        rw => 'access',
        arr=> 'array',
        s => 'signed',
        len => 'maxlength',length => 'maxlength',l => 'maxlength',
        prt => 'port', p => 'port',
        in => 'in_cob',
        out => 'out_cob',
        mplx=> 'multiplexor', mux=> 'multiplexor',
        inh=> 'inhibit',
        tmo=> 'timeout',
        asz=> 'arraysize',
      );
    my %value_map=
      ( server=> '^1',
        client=> '^0',
        mlt=> '^1',
        bas=> '^0',
        arr=>  '^1',
        sing=>  '^0',
        s=>  '^1',
        u=>  '^0',
      );


    if (defined $filters)
      { my @args= split(/\s*,\s*/,$filters);
        foreach my $a (@args)
          { if ($a!~/^\s*(\w+)\s*=\s*(\S*)/)
              { warn "not understood: \"$a\"\n";
                next;
              };
            my $f= $1;
            my $v= $2;
            if (exists $filter_map{$f})
              { $f=$filter_map{$f}; };
            if (exists $value_map{$v})
              { $v=$value_map{$v}; };
            if    ($v=~/\/(.+)\/(.+)/) # regexp-flags present
              { $v= '(?' . $2 . ')' . $1; }
            elsif ($v=~/\/(.*)\//)
              { $v= $1; };
#die "|$f|$v|\n";
            $filter_hash{$f}= qr($v);
          };
      };

#die "f:" . join("|",%filter_hash);

    filter_records($r_ext_db,"DTYP","lowcal");
    filter_fields($r_ext_db,['INP','OUT']);

    if (!$reverse)
      { printf "%-25s%-3s %s\n","recordname","dir",canlink::tab_print(); }
    else
      { printf "%s %-3s %-25s\n",canlink::tab_print(),"dir","recordname"; }

    my $r_dbhash= $r_ext_db->{dbhash};
    foreach my $rec (sort keys %$r_dbhash)
      { my $r= $r_dbhash->{$rec}->{FIELDS};
        my $link= $r->{OUT};
        my $dir= "OUT";
        if (!defined $link)
          { $link= $r->{INP};
            $dir="INP";
          };

        my %h= canlink::decode($link);

        $h{dir}= $dir; # put 'dir' into the hash in order
                       # to be able to filter it

        my $skip;
        foreach my $field (keys %filter_hash)
          {
            if ($h{$field}!~ $filter_hash{$field})
              { $skip=1; last; };
          };
        next if ($skip);

        if (!$reverse)
          { printf "%-25s%-3s %s\n",$rec,$dir,canlink::tab_print(%h); }
        else
          { printf "%s %-3s %-25s\n",canlink::tab_print(%h),$dir,$rec; }
      };
  }

sub sdo
  { my($r_ext_db,$reverse,$params)= @_;
    my $use_hex= 0;

    if (defined $params)
      { my @args= split(/\s*,\s*/,$params);
        foreach my $a (@args)
          { if ($a!~/^\s*(\w+)\s*=\s*(\S*)/)
              { warn "not understood: \"$a\"\n";
                next;
              };
            my $f= $1;
            my $v= $2;
            if ($f eq 'hex')
              { $use_hex= $v;
                next;
              };
            warn "not recognized: \"$a\"\n";
          };
      };

    filter_records($r_ext_db,"DTYP","SDO");
    filter_fields($r_ext_db,['INP','OUT']);

    if (!$reverse)
      { printf "%-28s%-3s %s\n","recordname","dir",sdo_tab_print(); }
    else
      { printf "%s %-3s %-28s\n",sdo_tab_print(),"dir","recordname"; }

    my $r_dbhash= $r_ext_db->{dbhash};
    foreach my $rec (sort keys %$r_dbhash)
      { my $r= $r_dbhash->{$rec}->{FIELDS};
        my $link= $r->{OUT};
        my $dir= "OUT";
        if (!defined $link)
          { $link= $r->{INP};
            $dir="INP";
          };

        my %h= sdo_decode($link);

        $h{USE_HEX}= $use_hex;

        if (!$reverse)
          { printf "%-28s%-3s %s\n",$rec,$dir,sdo_tab_print(%h); }
        else
          { printf "%s %-3s %-28s\n",sdo_tab_print(%h),$dir,$rec; }
      };
  }

sub sdo_decode
  { my($str)= @_;
    my($connection_char,$port,$node,$index,
       $subindex,$datasize,$conversion_char,$timeout);

    my %h;

    if   ($str=~/^\@C:(.)\s+A:(\d+),(\d+),(\d+),(\d+)\s+
                 V:(\d+),(.)\s+T:(\d+)\s*$/x)
      { $connection_char= $1;
        $port           = $2;
        $node           = $3;
        $index          = $4;
        $subindex       = $5;
        $datasize       = $6;
        $conversion_char= $7;
        $timeout        = $8;
      }
    elsif ($str=~/^\@C:(.)\s+
                  X:([0-9A-Fa-f]+),([0-9A-Fa-f]+),
                    ([0-9A-Fa-f]+),([0-9A-Fa-f]+)\s+
                  V:(\d+),(.)\s+T:(\d+)\s*$/x)
      { $connection_char= $1;
        $port           = hex($2);
        $node           = hex($3);
        $index          = hex($4);
        $subindex       = hex($5);
        $datasize       = $6;
        $conversion_char= $7;
        $timeout        = $8;
      }
    else
      { die "link not parsable:\"$str\""; };

    if    (lc($connection_char) eq 's')
      { $h{HOSTTYPE}= "SERVER"; }
    elsif (lc($connection_char) eq 'c')
      { $h{HOSTTYPE}= "CLIENT"; }
    else
      { die "link tot parsable:\"$str\""; };

    if    (lc($conversion_char) eq 'r')
      { $h{DATATYPE}= "RAW"; }
    elsif (lc($conversion_char) eq 'i')
      { $h{DATATYPE}= "INT"; }
    else
      { die "link not parsable (conv.char):\"$str\""; };

    if ($subindex>255)
      { die "link not parsable (subindex range):\"$str\""; };

    $h{PORT}    = $port;
    $h{NODE}    = $node;
    $h{INDEX}   = $index;
    $h{SUBINDEX}= $subindex;
    $h{DATASIZE}= $datasize;
    $h{TIMEOUT} = $timeout;
    return(%h);
  }

# w-r: seen from the server's side
sub sdo_rcob
  { my($node)= @_;
    return(0x600+$node);
  }

sub sdo_wcob
  { my($node)= @_;
    return(0x580+$node);
  }

sub sdo_tab_print
  { my(%p)= @_;

    # HOSTTYPE, PORT, NODE, INDEX, SUBINDEX, DATASIZE, DATATYPE, TIMEOUT
    if (!@_)
      { my $st= sprintf "%-7s %3s %3s %5s %4s %3s %3s %5s %5s %6s",
                        "hosttp",
                        "prt",
                        "nod",
                        "idx",
                        "sidx",
                        "dsz",
                        "dtp",
                        "tmo",
                        "inCOB",
                        "outCOB",
                        ;
        return($st);
      };

    my  $format= "%-7s %3d %3d %5d %4d %3d %3s %5d %5d %6d";
    if ($p{USE_HEX})
      { $format= "%-7s %3d %3d %5x %4x %3d %3s %5d %5x %6x"; };

    my $st= sprintf $format,
               lc($p{HOSTTYPE}),
               $p{PORT},
               $p{NODE},
               $p{INDEX},
               $p{SUBINDEX},
               $p{DATASIZE},
               lc($p{DATATYPE}),
               $p{TIMEOUT},
               sdo_rcob($p{NODE}),
               sdo_wcob($p{NODE}),
               ;

    return($st);
  }

sub rm_prefix_in_hash
# modifies the hash in-place
  { my($prefix,$r_h,$change_keys,$change_values,$r_allowed_keys)= @_;

    if (!$prefix)
      { return $r_h; }

    my @all_keys= keys %$r_h;
    my $val;

    foreach my $key (@all_keys)
      {
        if ($r_allowed_keys)
          {
            if (!$r_allowed_keys->{$key})
              { next; }
          }
        if ($change_keys)
          {
            $val= delete $r_h->{$key};
            $key=~ s/^$prefix//;
          }
        else
          { 
            $val= $r_h->{$key};
          }
        if ($change_values)
          {
            $val=~ s/^$prefix//;
          }
        $r_h->{$key}= $val;
      }
  }

sub create_regexp_func
# create a function for regular expression
# matching
  { my($funcname,$regexp,$invert)= @_;
    my $str;

    if (!defined $regexp)
      { $regexp= '//'; };

    if ($regexp=~ s/^!//)
    # leading '!' is an inverted regular expression
      { $invert= 1; }

    if ($regexp !~ /\//)
      { $regexp= "/$regexp/"; };

    if ($regexp eq '//')
      { $str= "sub $funcname " .
           " { return( defined(\$_[0]) ); }";
        eval( $str );
      }
    else
      { if (!$invert)
          { $str= "sub $funcname " .
                  " { return( scalar (\$_[0]=~$regexp) ); }";
            eval( $str );
          }
        else
          { $str= "sub $funcname " .
                  " { return( scalar (\$_[0]!~$regexp) ); }";
            eval( $str );
          };
      };

    #warn "func created:\n$str\n";

    if ($@)
      { die "error: eval() failed, error-message:\n" . $@ . " "  };
  }


# fit in program text here

# ------------------------------------------------

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
    my $l= $#analyse_db::link_fields/2;
    my $links1= join(",",@analyse_db::link_fields[0..$l]);
    my $links2= 
      join(",",@analyse_db::link_fields[($l+1)..$#analyse_db::link_fields]);
    print <<END;

$l1
$l2

Syntax:
  $sc_name {options} [file1] [file2...]

  options:

    -h: help
    --summary: give a summary of the script

  specify the type of output:

    -i dump internal hash structure
    -r print results in db-file format (default)
    -s --short print results, one line per record
    -l just list the names of the matching records

  remove/filter records:
    --skip_empty_records: records that have no fields (due to
       filtering options that remove fields) are not printed

  remove/filter fields:
    --fields --FIELDS [field1,field2...]
      print only these fields

    -e --empty remove empty fields

    -E --rm-capfast-defaults
      remove fields that have still their capfast default value.
      CAUTION: used together with "-v" or "--fields" this option
      may remove the very fields you are looking for.

  regular expressions:
    [regexp] stands for a perl regular expression. A leading '!'
    means that the filter is inverted ('do not match'). The regexp
    may be enclosed in '/' characters, but the may be omitted.

  special options:

    --percent [+-number]
      keep the first or last n percent of all records
      if number is negative, filter the LAST n percent of all
      records, otherwise filter the FIRST n percent of all records

    --unresolved-variables
      List all unresolved variables like \$(VARNAME) in the db file.
      This option can be combined with "-r", in this case
      all the contents of the shown records are printed in
      db-file format. With "--db" just the records in db format
      are printed.

    --unresolved-links {verbosity}
      Try to find unresolved links in the db-file.
      list all links that cannot be resolved within the
      db file. Currently the followings list of fields is expected to
      contain links:
      $links1
      $links2
      All values that seem to be a number or an empty string are ignored

      verbosity may be a number between 0 and 2.
      0   : just list the link values (the default)
      1   : list record names and link values
      2   : print a list of record names, then a list of
            record names and link values

      This option can be combined with "-r", in this case
      all the contents of the shown records are printed in
      db-file format. With "--db" just the records in db format
      are printed.

    --record-references -R [regexp{,regexp2}]
      list which record (whose name matches regexp) is connected
      to which other record. regexp may be "all" or "//" in which
      case all records that are connected to other records are
      shown.

      Effects of [regexp2]:

      If given, all dependencies must match this regular expression.
      Dependencies that to not match are not shown. With option "--rec" (see
      below) records that do not match are not followed. Note that this may be
      an inverse regular expression (see "regular expressions:" further above). 

      Effects of other options:

      -r  : additionally show all records in db-file format
      -l  : just list the record names
      --db: only show records in db-file format, do not show dependency
            details.
      --dot :
            produce a graphviz file. Use for example 
              dbfilter.pl {options...} --dot | dot -Tpdf > plot.pdf 
            to create a pdf file with a dependency plot.
      --rec [distance]: recursively look for connected records up to
            [distance]. A direct connection has distance 1. 

    --recursive --rec [distance]
      this option can be used together with --record-references.
      no specifies the maximum path length that is allowed for
      indirectly connected records in order to be printed.

    --dot
      this option can be used with --record-references. It produces an output
      suitable for graphviz. 

    --rm-prefix [PREFIX]
      Remove PREFIX in all record names in all reports.

    --allow_double -A : allow double record names
      (for debugging faulty databases)

    --single -S : forbid double record names
      (for debugging faulty databases)

    --lowcal {filters}
      print records with DTYP=lowcal and decode
      the CAN link. Record names and can-link properties are
      printed in a table format.
      The optional <filters> parameter is comma-separated a
      list in the form
        name=regexp
      where name is a property of the CAN link and regexp is
      a perl regular expression. Note that <name> is actually
      the field-name of the canlink-hash as defined in
      the perl-module canlink.pm (see "man canlink").
      Among others, the following field names are recognized:
        dir          : either "INP" or "OUT", the type of the record
        srv,server   : the server-type, "1" for server, "0" for client
                       NOTE: you may match for "1" or "0" in your
                       regexp or the string printed in the table.
        mul, multi   : the multiplex type, "1" for multiplex vars, "0" else
                       NOTE: you may match for "1" or "0" in your
                       regexp or the string printed in the table.
        rw,access    : the type of the CAL variable (r,w or rw)
        arr,array    : array type, 1 for array variables, 0 else
                       NOTE: you may match for "1" or "0" in your
                       regexp or the string printed in the table.
        s,signed     : the signed type, ("1" for signed, "0" for unsigend)
                       NOTE: you may match for "1" or "0" in your
                       regexp or the string printed in the table.
        type         : the variable type (zero,string,char,short,mid,long)
        len,length,l : the length of the CAN object
        prt,port,p   : the port number
        in,in_cob    : the CAN object ID of the IN-object
        out,out_cob  : the CAN object ID of the OUT-object
        mplx,mux,multiplexor: the value of the multiplexor
        inh,inhibit  : the inhibit-time
        tmo,timeout  : the timeout-value
        asz,arraysize: the arraysize

    --Lowcal {filters}
      identical to --lowcal except that the record
      names are in the last, not in the first column

    --sdo {options}
      print records with DTYP=SDO and decode
      the CAN link. Record names and can-link properties are
      printed in a table format
      The optional <options> parameter is comma-separated a
      list in the form
        name=value
      currently known options are:
        hex          : when not 1, print everything in decimal
                       when 1, print the index, subindex, in-cob
                       and out-cob in hex

    --Sdo {options}
      identical to --sdo except that the record
      names are in the last, not in the first column

   filter info fields:
    --infovalue [regexp]
      process only records where any info value matches a regular expression.
    --info [infoname,regexp]|[infoname]
      process only records where an infoname is defined. If regexp is omitted
      just test for the existence of that info name. If regexp is defined,
      process only records where for the given info name the info value matches
      the given regexp.

   filter field values:

    --value [regexp]
      print a list of all fields in records where the field-value matches a
      regular expression,

    -v [regexp]
      filter records where at least one field matches the given regular
      expression

    --field [field,regexp]|[field]
      process only records where field matches regexp  if regexp is omitted
      just test for the existence of that field if field is a perl-regular
      expression starting enclosed in '//' it is treated as a regular
      expression

    --NAME|--name|-n [regexp]
      filter records whose name match the given regular expression

    --NOTNAME|--notname [regexp]
      same as above but filter records whose names DO NOT match the regular
      expression

    --name-file [file]
      filter records that are listed in the given file

    --notname-file [file]
      filter records that are NOT listed in the given file

    --DTYP [regexp] : filter DTYP field

    --TYPE|-t [regexp] : filter record type

    if no file is given $sc_name reads from standard-input
END
  }

