package parse_subst;

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


use strict;


BEGIN {
    use Exporter   ();
    use vars       qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
    # set the version for version checking
    $VERSION     = 2.1;

    @ISA         = qw(Exporter);
    @EXPORT      = qw();
    %EXPORT_TAGS = ( );     # eg: TAG => [ qw!name1 name2! ],

    # your exported package globals go here,
    # as well as any optionally exported functions
    @EXPORT_OK   = qw(&parse);
}

use vars      @EXPORT_OK;

# used modules
use Data::Dumper;
use Text::ParseWords;
use Carp;

our $old_parser=0;


my $RX_space_or_comment    = qr/\s*(?:\s*(?:|\#[^\r\n]*)[\r\n]+)*\s*/;

my $RX_quoted_word         = qr/\"(\w+)\"/;
my $RX_unquoted_word       = qr/(\w+)/;

my $RX_quoted              = qr/\"(.*?)(?<!\\)\"/;
my $RX_unquoted_filename   = qr/([^\s\{\}]+)/;

my $RX_unquoted_value      = qr/([^\s\{\},]+)/;


my $RX_comma               = qr/,?/;

my $RX_global_head= 
            qr/\G
               global
               $RX_space_or_comment
                       \{
               /x;

my $RX_file_head= 
            qr/\G
               file
               $RX_space_or_comment

		 (?:$RX_quoted|$RX_unquoted_filename)

                 $RX_space_or_comment
                       \{
               /x;

my $RX_pattern  = 
            qr/\G  
	       $RX_space_or_comment
	       pattern
	       $RX_space_or_comment
	       \{ 
	       /x;

my $RX_var= 
            qr/\G  
               $RX_space_or_comment	
	       (?:$RX_quoted_word|$RX_unquoted_word)	      
               $RX_space_or_comment
	       $RX_comma
	       /x;

my $RX_val= qr/\G  
               $RX_space_or_comment	
	       (?:$RX_quoted|$RX_unquoted_value)	      
               $RX_space_or_comment
	       $RX_comma
	       /x;


my $RX_definition = 
            qr/\G
               $RX_space_or_comment	
	       (?:$RX_quoted_word|$RX_unquoted_word)	      
               $RX_space_or_comment
               = 	    	
               $RX_space_or_comment
	       (?:$RX_quoted|$RX_unquoted_value)	      
               $RX_space_or_comment
	       $RX_comma
	       /x;

sub get_or_mk_array
  { my($key,$r_hash)= @_;

    my $r= $r_hash->{$key};
    return $r if (defined $r);
    my @l;
    $r_hash->{$key}= \@l;
    return(\@l);
  }

sub get_or_mk_hash
  { my($key,$r_hash)= @_;

    my $r= $r_hash->{$key};
    return $r if (defined $r);
    my %l;
    $r_hash->{$key}= \%l;
    return(\%l);
  }

sub parse
  { my($arg, $mode)= @_;

    my %globals=();

    if (!defined $arg)
      { simple_parse_error(__LINE__,"<undef> cannot be parsed"); }
    
    my $r_db;
    my $ref = ref($arg);
    if    ($ref eq 'SCALAR')
      { $r_db= $arg; }
    elsif ($ref eq "")
      { $r_db= \$arg; }
    else
      { croak "parse: argument is neither a scalar nor " .
              "a reference to a scalar"; 
      };

    if (!defined $$r_db)
      { simple_parse_error(__LINE__,"<undef> cannot be parsed"); }
    if ($$r_db=~/^\s*$/)
      { simple_parse_error(__LINE__,"\"\" cannot be parsed"); }

    $mode= "templateHash" if (!defined $mode);

    if (($mode ne 'templateHash') && ($mode ne 'templateList'))
      { die "unknown mode: \"$mode\""; };

    my $quirks= ($mode eq 'templateList') ? 1 : 0;

    if ($old_parser && $quirks)
      { die "error: old_parser and 'templateList' are mutual exclusive"; };

    my $level= 'top';

# mode: default 
    my %templates;

    my @templates;
    my $lastfilename;

    my $r_file;
    # a ref to a list containing all
    # instances for a certain *.template file

    my $r_instance;
    # a ref to a hash containing all definitions
    # for a certain instance

    my $sub_block_type;

    my $field_index;
    # index within a pattern-field

    my @column_names;
    # names of columns within a pattern-field

    my $instance_no; 
    # only needed for $old_parser= 1

    my $upper_block_type="";
    # may be "top" or "file"

    for(;;)
      { 
#print "level:$level at\n", 
#      "  ---",substr($$r_db, pos($$r_db),20),"---\n";
        if ($level eq 'top')
          { 
            # skip comment-lines at level 0:
            $$r_db=~/\G$RX_space_or_comment/ogscx;
            last if ($$r_db=~/\G[\s\r\n]*$/gsc);

            if ($$r_db=~ /$RX_global_head/ogscx)
	      {
		$r_instance= \%globals;
		$level= 'sub-block';
		$upper_block_type='top';
		$sub_block_type= undef;
		$field_index= 0;
		next;
	      };

            if ($$r_db=~ /$RX_file_head/ogscx)
	      { my $filename= ($2 eq "") ? $1 : $2;

                if    ($old_parser)
		  { $r_file = get_or_mk_hash ($filename, \%templates); }
		elsif ($quirks)
		  { if ($lastfilename ne $filename)
		      { my @l= ($filename);
		        push @templates, \@l;
			$r_file= \@l;
			$lastfilename= $filename;
		      };
		  }       
		else
		  { $r_file = get_or_mk_array($filename, \%templates); 
		    if ($quirks)
		      { if (!@$r_file)
		          { @$r_file= ($filename); };
		      };	  
		  }


		$instance_no= 0;

		$level='file';
		next;
	      };
           parse_error(__LINE__,\$$r_db,pos($$r_db),"level \"$level\"");
	  };

	if ($level eq 'file')
	  { 
            if ($$r_db=~ /\G
                      $RX_space_or_comment
                      \}/ogscx)
              { $level= 'top';
                next;
              };

	    if ($$r_db=~ /$RX_pattern/ogscx)
	      { $level= 'pattern_cols';
	        @column_names= ();
	        next;
	      }

	    if ($$r_db=~ /\G
                      $RX_space_or_comment
                      \{/ogscx)
              { my %h= %globals; # import global definitions
	        if ($old_parser)
		  { $r_file->{$instance_no++}= \%h; }
		else
		  { push @$r_file, \%h; };

		$r_instance= \%h;
	        $level= 'sub-block';
		$upper_block_type='file';
		$sub_block_type= undef;
                $field_index= 0;
	        next;
              };
           parse_error(__LINE__,\$$r_db,pos($$r_db),"level \"$level\"");
	  }   

	if ($level eq 'pattern_cols')
          { if ($$r_db=~ /\G
                      $RX_space_or_comment
                      \}/ogscx)
              { $level= 'file';
                next;
              };

	    if ($$r_db=~ /$RX_var/ogscx)
	      { my $var= ($2 eq "") ? $1 : $2;
	        push @column_names, $var;
		next;
	      }
           parse_error(__LINE__,\$$r_db,pos($$r_db),"level \"$level\"");
	  } 

	if ($level eq 'sub-block')
	  { if ($$r_db=~ /\G
                      $RX_space_or_comment
                      \}/ogscx)
	      { $level= $upper_block_type; # 'top' or 'file'
	        next;
              } 

	    if ($sub_block_type ne 'pattern')
	      { if ($$r_db=~ /$RX_definition/ogscx)
		  { my $var= ($2 eq "") ? $1 : $2;
	            my $val= ($4 eq "") ? $3 : $4;
	            $r_instance->{$var}= $val;
		    $sub_block_type= 'regular' if (!defined $sub_block_type);
		    next;
	          }
	      };

	    if ($sub_block_type ne 'regular')
	      { if ($$r_db=~ /$RX_val/ogscx)
		  { my $value= ($2 eq "") ? $1 : $2;
		    my $colname= $column_names[$field_index++];
		    if (!defined $colname)
		      { parse_error(__LINE__,\$$r_db,pos($$r_db),"not enough columns"); 
		      };
		    $r_instance->{$colname}= $value;
		    $sub_block_type= 'pattern' if (!defined $sub_block_type);
                    next;
		  };
              };

           parse_error(__LINE__,\$$r_db,pos($$r_db),"level \"$level\"");
	  }; # for   

      };

    if ($quirks)
      { return(\@templates); };

    return(\%templates);;
  }

sub parse_file
# parse the db file and return the record hash
  { my($filename)= @_;
    local(*F);
    local($/);
    my $st;

    undef $/;

    if (!defined $filename) # read from STDIN
      { *F=*STDIN; }
    else
      { open(F,$filename) or die "unable to open $filename"; };
    $st= <F>;

    close(F) if (defined $filename);

    return(parse($st));
  }


sub create_instance
  { my($r_hash)= @_;
    print "    {\n";
    my @lines;
    foreach my $key (sort keys %$r_hash)
      { my $val= $r_hash->{$key};
        my $st= "      $key=";
	if ($val=~ /^\s*[+-]?\d+\.?\d*(e[+-]?|)\d*\s*$/) # a number
	  { $st.= $val; }
	else
	  { $st.= "\"$val\""; };
	push @lines, $st;
      };
    print join(",\n",@lines),"\n";
    print "    }\n";
  }    


sub create_instances
  { my($filename, $r_hash)= @_;
    my $r_instances= $r_hash->{$filename};

    print "file $filename\n  \{\n";
    foreach my $instance (@$r_instances)
      { create_instance($instance);
      };
    print "}\n\n";
  }

sub create
  { my($r_hash)= @_;

    foreach my $file (sort keys %$r_hash)
      { create_instances($file, $r_hash); 
      }
  }

sub simple_parse_error
  { my($prg_line, $msg)= @_;
    my $err= "Parse error at line $prg_line of parse_subst.pm,\n" .
             $msg . "\n";
    croak $err;
  }

sub parse_error
  { my($prg_line,$r_st,$pos,$filename)= @_;

    my($line,$column)= find_position_in_string($r_st,$pos);
    if (defined $filename)
      { $filename= "in file $filename "; };
    my $err= "Parse error ${filename} at line $prg_line of parse_subst.pm,\n" .
             "byte-position $pos\n" .
             "line $line, column $column in file\n ";
    croak $err;
  }



sub find_position_in_string
# gets a position as returned by pos(..) in a
# multi-line strings and returns a pair (row,column)
# the first row is 1, the first column is 0
  { my($r_str,$position)= @_;

    my $cnt=0;
    my $lineno=1;


    pos($$r_str)=0;
    my $oldpos=-1;

    while($$r_str=~ /\G(.*?)\r?\n/gms)
      { 
        if (pos($$r_str)<$position)
          { 
            $oldpos= pos($$r_str); 
            $lineno++;
            next;
          };
        return($lineno,$position-$oldpos);
      };
    return($lineno,$position-$oldpos);
  }      


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

sub dump
  { my($r_templates)= @_;

    my $r;

    rdump(\$r,$r_templates,0);
    print $r,"\n";
  }


1;

__END__
# Below is the short of documentation of the module.

=head1 NAME

parse_subst - a Perl module to parse epics substitution-files

=head1 SYNOPSIS

  use parse_subst;
  undef $/;

  my $st= <>;

  my $r_templates= parse_subst::parse($st);
  parse_subst::dump($r_templates);

=head1 DESCRIPTION

=head2 Preface

This module contains a parser function for epics substitution-files. The
contents of the db-file are returned in a perl hash-structure that 
can then be used for further evaluation.

=head2 Implemented Functions:

=over 4

=item *

B<parse()>

  my $r_templates= parse_subst::parse($st); 
    or
  my $r_templates= parse_subst::parse(\$st); 

This function parses a given scalar variable that must contain a complete
substitution-file. It returns a reference to a hash, where the parsed datais
stored. The parameter may either be a scalar variable containing the data or a
reference to a scalar variable.

The new "global" statement in substitution files is also supported. Globals are
resolved, meaning that definitions of global values are merged in the local
per-file definitions. Applications that use parse_subst.pm do not have to be
aware of the global statement.

=item *

B<parse_file()>

  my $r_templates= parse_subst::parse_file($filename);

This function parses the contents of the given filename. If the parameter
C<$filename> is not given it tries to read form STDIN. If the
file cannot be opened, it dies with an appropriate error message.
It returns a reference to a hash, where the parsed data
is stored.

=item *

B<dump()>

  my $r_templates= parse_subst::parse($st);
  parse_subst::dump($r_templates);

This function prints a dump of the created structure 
to the screen. 

=item *

B<create()>

  my $r_templates= parse_subst::parse($st);
  parse_db::create($r_templates)

Print the contents of the substitution data sorted and in the standard 
substitution format to the screen. 

=back

=head2 hash-structure

Each template-name is a key in the template-hash. It is a reference to 
an array that contains the data for that template. 

The array contains a reference to a hash for each instantiation of that
template.

Each instantiation hash contains a key for each field name that 
gives the value of that field. Note that undefined fields-values are 
empty strings (""), not the perl undef-value.

Example of a hash that parse() returns:

  $r_templates= { 'acsm.template' => 
                          [  {
                               'MCHAN' => 'A',
                               'MNAME' => 'PVBU49ID8R:',
                               'MNUM' => '0',
                               'BASE' => 'U49ID8R:'
                             },
                             {
                               'MCHAN' => 'B',
                               'MNAME' => 'PHBU49ID8R:',
                               'MNUM' => '1',
                               'BASE' => 'U49ID8R:'
                             },
		          ]

=head2 backwards compability:

Version 1.0 of the parser used a hash instead of the array as explained
above, with keys from "0" to .. "n". If you want a template-hash 
structure that is still compatible to this, set C<$old_parser> to 1 like
this:

  $parse_subst::old_parser=1;


=head1 AUTHOR

Goetz Pfeiffer,  Goetz.Pfeiffer@helmholtz-berlin.de

=head1 SEE ALSO

perl-documentation

=cut
