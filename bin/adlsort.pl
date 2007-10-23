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


use strict;

use Getopt::Long;
use Text::ParseWords;
#use File::Spec;

use Data::Dumper;
use Text::Tabs;


use vars qw($opt_help $opt_debug $opt_file $opt_backup
	    $opt_dump $opt_perldump $opt_import $opt_legacy $opt_new_sort);

my $version="1.0";

our $VAR; # used for perl-dump

my $metachar= "\\\$";
my $raw_metachar= '$';

my %s_index= ( type    => "!0",
               level   => "!1",
	       start   => "!2",
	       end     => "!3",
	       start_lc=> "!4",
	       end_lc  => "!5",
	     );

my %special_tags= (file => "\r0",
                   display=> "\r1",
		   'color map' => "\r2",
		  );


if (!GetOptions("help|h","debug", "file|f=s", "backup|b",
		"dump|d", "perldump|p", "import|i=s","legacy",
		"new_sort|new-sort"
		))
  { die "parameter error!\n"; };


if ($opt_help)
  { help();
    exit;
  };

if ($opt_legacy)
  { $metachar= '#'; 
    $raw_metachar= '#';
  }

my %sort_keys;

my $r_p;

if    (defined $opt_import)
  { $r_p= import_dump($opt_import); }
else
  { $r_p= parse_file($opt_file); }

if (defined $opt_backup)
  { system("cp $opt_file $opt_file.bak"); };

if ((defined $opt_dump) || (defined $opt_perldump))
  { mydump($r_p,$opt_perldump);
    exit(0);
  };


#mydump($r_p) if ($opt_debug);
#die;
my $oldfh;

if (defined $opt_backup)
  { open(F, ">$opt_file") or die "unable to create $opt_file"; 

    $oldfh= select(F); 
  };

print_parse_tree($r_p, $opt_new_sort ? "SORT-NEW" : "SORT-STANDARD");

if (defined $opt_backup)
  { select $oldfh;
    close(F);
  };

exit(0);
#print "----------------------------------------\n";

sub import_dump
  { my($filename)= @_;

    do $filename or die "assertion";
    return($VAR);
  }


sub parse_file
  { my($filename)= @_;

    my $r_lines= read_expanded_file($filename);

    my $data= join("",@$r_lines);

    my $r_p= parse_top(\$data);
    return($r_p);
  }


sub read_expanded_file
  { my($filename)=@_;
    local(*F);
    my $use_stdin= (!defined $filename) || ($filename eq "");
    my @lines;

    if (!$use_stdin)
      { open(F, $filename) or die "unable to open $filename"; }
    else
      { *F= *STDIN; };

    while(my $line=<F>)
      { push @lines, expand($line); # Text::Tabs
      };

    close(F) if (!$use_stdin);
    return(\@lines);
  }



sub line_indices
  { my($r_data)= @_;
    my @lines;
    my $cr= ord("\n");

    my $last=0;
    for(my $i=0; $i< length($$r_data); $i++)
      { 
        #my $ch= substr $$r_data,$i,1;
        #printf("%s:%d ",$ch,ord($ch));
        next if ord(substr $$r_data,$i,1) != $cr;
	push @lines, $last;
	$last= $i+1;
      };
    #print "\n"; die;

    return(\@lines);  
  }   

sub pos_to_line_ch
  { my($r_indices,$pos)= @_;

    for(my $i=$#$r_indices; $i>= 0; $i--)
      { 
        if ($r_indices->[$i]<=$pos)
          { 
	    return($i+1,$pos-$r_indices->[$i]); 
	  };
      };
    warn "line not found for $pos!!";
    return(-1,-1);
  }


sub parse_top
  { my($r_data)= @_;

    my $r_indices;

    if ($opt_debug)
      { $r_indices= line_indices($r_data); };

    #print "line-array: " . join(",",@$r_indices) . "\n"; 
    #my($a,$b)= pos_to_line_ch($r_indices,46); print "$a $b\n";     die;

    my @top;

    pos($$r_data)=0;
    my ($p,$r_struc)=(0,undef);

    for(;;)
      { ($p,$r_struc)= parse($r_data,$p,0,$r_indices);
        last if (!defined $r_struc);
	push @top, $r_struc;
      };

    return(\@top);  
  }      

sub print_parse_tree
  { my($r_list,$sortmode)= @_;

#print "xxxxxxxxxxxxxxxxxxxxxxx\n";
#    foreach my $elm (@$r_list)
    if ($sortmode eq "SORT-NEW")
      { foreach my $elm (@$r_list)
          { calc_key($elm); };
      }

    foreach my $elm (sort_elements($sortmode,@$r_list))
      { 
        print_p_elm($elm,0,$sortmode);
      };
  }

sub print_p_elm
  { my($elm,$level,$sortmode)= @_;

    if ($elm->{type} eq 'if')
      { print $elm->{tag},"\n";
        my $if_elm  = $elm->{value}->[0];
        my $else_elm= $elm->{value}->[1];
	foreach my $s (sort_elements($sortmode,@$if_elm))
	  { print_p_elm($s,$level,$sortmode); };
	if (@$else_elm)
	  { print "${raw_metachar}else\n";
	    foreach my $s (sort_elements($sortmode,@$else_elm))
	      { print_p_elm($s,$level,$sortmode); };
	  };
	print "${raw_metachar}endif\n";
        return;
      };  

    if ($elm->{type} eq 'struct')
      { print "\t" x $level;
	print quote($elm->{tag}) . " {\n";

	if ($elm->{tag} eq 'colors')
	  { $sortmode= ""; 
	    # we MUST NOT sort the colormap
	  }

	foreach my $s (sort_elements($sortmode,@{$elm->{value}}))
	  { print_p_elm($s,$level+1,$sortmode); };
	print "\t" x $level,"}\n"; 
	return;
      };
    if ($elm->{type} eq 'value')
      { print "\t" x $level;
        print quote($elm->{tag}),"=",$elm->{value},"\n";
	return;
      };
    if ($elm->{type} eq 'array-elm')
      { print "\t" x $level;
        print $elm->{value},",\n";
	return;
      };
    if ($elm->{type} eq 'point-elm')
      { print "\t" x $level;
        print $elm->{value},"\n";
	return;
      };
  }

sub key_of_type_subtype_tag
  { my($r_s)= @_;

    my $ref= ref($r_s);
    if ($ref eq '') # a simple value
      { return(mk_subkey($r_s)); }
    if ($ref eq 'HASH') 
      { my $t= substr($r_s->{type},0,10);
	my $st=substr($r_s->{subtype},0,10);
	my $tg=substr($r_s->{tag},0,10);

	my $special= $special_tags{$r_s->{tag}};
	if (defined $special)
	  { return( $special); 
	  };

	return( sprintf((" " x 10) . "-%-10s%-10s%-10s%s",
	                $t,$st,$tg,mk_subkey($r_s->{value})));
      };
    die "assertion, type: $ref";
  }

sub smallest
  { my($r_list);

    if ($#$r_list < 0)
      { return; }
    if ($#$r_list == 0)
      { return($r_list->[0]); }

    my $key= $r_list->[0];
    for(my $i=1; $i<=$#$r_list; $i++)
      { if ($key gt $r_list->[$i])
          { $key= $r_list->[$i]; }
      };
  }


sub mk_subkey
  { my($val)= @_;

    my $ref= ref($val);
    if ($ref ne '')
      { # a reference
        if ($ref eq 'SCALAR')
	  { return(mk_subkey($$val)); }
	if ($ref eq 'ARRAY')
	  { my @keys= map{ mk_subkey($_) } @$val;
	    return(smallest(\@keys));
	  }
	if ($ref eq 'HASH')
	  { 
	    my @keys= map{ mk_subkey($_) } (values %$val);
	    return(smallest(\@keys));
	  }
        die "assertion";
      }    
    if ((!defined $val) || ($val eq ''))
      { return(" " x 10); };
    if ($val=~/^\s*\d+\s*$/)
      { return(sprintf("%010d",$val)); }
    return(sprintf("%-10s",substr($val,0,10)));
  }


sub key_of_scalar
  { my($r_s)= @_;
    return(substr($$r_s,0,10));
  }

sub key_of_array
  { my($r_array)= @_;
    my @l;
    foreach my $e (@$r_array)
      { push @l, calc_key($e);
      };
    return (join(",",sort @l));
  } 

sub key_of_hash
  { my($r_hash)= @_;
    my @hashkeys= sort(keys %$r_hash);
    my @l;

    foreach my $k (@hashkeys)
      { push @l,calc_key($r_hash->{$k}); }
    return( key_of_type_subtype_tag($r_hash) . 
            join("|",@hashkeys) . "-" . join(";",@l)
	  );
  }    

sub calc_key
  { my($elm)= @_;
    my $key;
    my $ref= ref($elm);

    if (exists $sort_keys{$elm})
      { return($sort_keys{$elm}); };

    if    ($ref eq '')
      { $key= key_of_scalar(\$elm); 
      }
    elsif ($ref eq 'SCALAR')
      { $key= key_of_scalar($elm); 
      }
    elsif ($ref eq 'ARRAY')
      { $key= key_of_array($elm); 
      }
    elsif ($ref eq 'HASH')
      { $key= key_of_hash($elm); 
      }
    else
      { die "assertion"; };
    $sort_keys{$elm}= $key;
    return($key);
  }

sub sort_elements
# sort a list of elements
  { my($sortmode,@elm_list)= @_;
    my %tags;

    if (!$sortmode)
      { return(@elm_list); }; 

    if ($sortmode eq "SORT-STANDARD")
      {
	for(my $i=0; $i<= $#elm_list; $i++)
	  { my $elm= $elm_list[$i];
            if (($elm->{type} eq 'array-elm') ||
        	($elm->{type} eq 'point-elm'))
              { # do not re-sort in this case
		return(@elm_list);
	      };
	    my $tag= ($elm->{tag});
	    $tag= "!0" if ($tag eq 'file'); 
	    $tag= "!1" if ($tag eq 'display'); 
	    $tag= "!3" if ($tag eq 'object'); 
	    $tag.= sprintf("%4d",$i);

	    $tags{$tag}= $elm;
	  };
        return map { $tags{$_} } (sort keys %tags);
      }
    elsif ($sortmode eq "SORT-NEW")
      { 
#die;
	return (sort { key_of_type_subtype_tag($a) cmp key_of_type_subtype_tag($b) } 
	        @elm_list);
      }
    else
      { die "unknown sortmode:$sortmode (assertion)"; }

  }       


sub quote
  { my($st)= @_;
    if ($st=~ /\s/)
      { return '"' . $st . '"'; };
    return($st);
  }  


#      
#sub sort_elements
# { my($a,$b)= @_;
#  
#    my $level= $a->{level};    


sub parse
  { my($r_data,$pos,$bracketlevel,$r_indices)= @_;
    my $curtag;
# [start,end,type,val] 


    if ($opt_debug)
      { 
        my($l,$p)= pos_to_line_ch($r_indices,$pos);
        print "parse called at pos: $pos, line-ch: $l, $p";

        print "\n-------------------- at: \n" . 
              substr($$r_data,$pos,20) . "\n--------------------\n";
      };
    my %struc; 
    pos($$r_data)= $pos;  

    for(;;)
      {

        # match "#if <variable>" :
	if ($$r_data=~ /\G\s*^\s*(${metachar}if.*)$/gmo)
	  { $struc{type}= "if"; 
	    $struc{tag}= $1;
#warn;	    
	    $struc{value}= [[],[]];
	    my $val= $struc{value}->[0];
	    print "if-struc found: $1\n" if ($opt_debug);
	    my($p,$r_struc)=(pos($$r_data),undef);
	    for(;;)
	      { 
#warn;	    
                # match "#else" :
	        if ($$r_data=~ /\G\s*^\s*(${metachar}else)\s*$/gmo)
                  { $val= $struc{value}->[1]; };

                # match "#endif" :
	        if ($$r_data=~ /\G\s*^\s*(${metachar}endif)\s*$/gmo)
                  { #warn "ENDIF";
		    last; 
		  };

	        ($p,$r_struc)= parse($r_data,$p,$bracketlevel+1,$r_indices);
		if (!defined $r_struc)
		  { pos($$r_data)= $pos;  # restore pos  
	            if ($$r_data=~ /\G\s*^\s*(${metachar}endif)\s*$/gmo)
                      { # warn "ENDIF";
			last; 
		      };
		    # block-end within if-structure: ERROR
		    if ($opt_debug)
		      { my ($line,$ch)= pos_to_line_ch($r_indices,$pos);
	        	warn "assertion at line $line, char $ch:\n";
		      }
		    else
		      { warn "assertion at byte position $pos:\n";
		      };
		    warn "string:\"",substr($$r_data,$pos,20),"\"\n";
		    die "assertion";
		  };

	        $pos= $p;
	        pos($$r_data)= $pos;  # restore pos  
		push @$val, $r_struc;
	      };

	    return(pos($$r_data),\%struc); 
          }

	pos($$r_data)= $pos;  # restore pos  

        # match "<identifier>=<value>" :
	if ($$r_data=~ /\G\s*(\w+|\"[^\"]+\")(\s*=\s*)(\w+|\"[^\"]*\")/g)
	  { $struc{type}= "value"; 
	    $struc{tag}= $1;
            $struc{value}= $3;

	    $struc{tag}  =~ s/\"//g;


	    if ($opt_debug)
	      { 
		$struc{start}= pos($$r_data) - 
		               length($1)-length($2)-length($3);
		$struc{end}  = pos($$r_data) - 1;

		$struc{start_lc}= [pos_to_line_ch($r_indices,$struc{start})];
		$struc{end_lc}  = [pos_to_line_ch($r_indices,$struc{end})];
	        $struc{level}= $bracketlevel;
	      };

	    warn "val found: $1 = $3\n" if ($opt_debug);
	    return(pos($$r_data),\%struc);
	  };		       

	pos($$r_data)= $pos; # restore pos 

        # match "<identifier> { " (block construct):
	if ($$r_data=~ /\G\s*(\w[\w\[\]]*|\"[^\"]+\")(\s*)\{/g)
	  { 
	    $struc{type}= "struct";
	    $struc{tag}= $1;

	    $struc{tag}  =~ s/\"//g;

	    if ($opt_debug)
	      { 
		$struc{start}= pos($$r_data) - length($1)-length($2)-1;
		$struc{level}= $bracketlevel;
		$struc{start_lc}= [pos_to_line_ch($r_indices,$struc{start})];
              };

	    $struc{value}= [];
	    print "tag found: $1\n" if ($opt_debug);
	    my($p,$r_struc)=(pos($$r_data),undef);
	    $pos= $p; # @@@ BUGFIX, needed when there is noting
	              # in-between the brackets '{' and '}' and
		      # parse in the following for-loop returns
		      # <undef> the first time it is called
		      # in this case $pos must have a new value in
		      # order for the parse to advance it's parse
		      # position in the string
	    for(;;)
	      { 
	        ($p,$r_struc)= parse($r_data,$p,$bracketlevel+1,$r_indices);
		last if (!defined $r_struc);
	        $pos= $p;
		push @{ $struc{value} }, $r_struc;
	      };
 	    $struc{subtype}= "list";

	    if ($struc{value}->[0]->{type} eq "array-elm")
	      { $struc{subtype}= "array"; };

            if ($struc{value}->[0]->{type} eq "point-elm")
	      { $struc{subtype}= "point-list"; };

	    pos($$r_data)= $pos;

            if ($$r_data=~ /\G(\s*\})/g)
	      { 
	        if ($opt_debug)
	          { 
	            $struc{end}= pos($$r_data) - 1; 
	            $struc{end_lc}  = [pos_to_line_ch($r_indices,$struc{end})];
                  };
		return(pos($$r_data),\%struc); 
	      };

	    pos($$r_data)= $pos;

	    if ($opt_debug)
	      { my ($line,$ch)= pos_to_line_ch($r_indices,$pos);
	        warn "assertion at line $line, char $ch:\n";
	      }
	    else
	      { warn "assertion at byte position $pos:\n";
	      };
	    warn "string:\"",substr($$r_data,$pos,20),"\"\n";
	    die;
	  };

	pos($$r_data)= $pos; # restore pos 

        # match "<identifier>," (list element):
	if ($$r_data=~ /\G\s*(\w+),/g)
	  { $struc{type}= "array-elm";
	    $struc{value}= $1;

	    if ($opt_debug)
	      { 
		$struc{start}= pos($$r_data) - length($1);
		$struc{end}  = pos($$r_data) - 1;
		$struc{start_lc}= [pos_to_line_ch($r_indices,$struc{start})];
		$struc{end_lc}  = [pos_to_line_ch($r_indices,$struc{end})];
	        $struc{level}= $bracketlevel;
              };	    
	    warn "array-elm found: $1\n" if ($opt_debug);
	    return(pos($$r_data),\%struc);
	  };

	pos($$r_data)= $pos; # restore pos 

        # match "(<identifier1>,<identifier2>)" (point):
	if ($$r_data=~ /\G\s*(\(\d+,\d+\))/g)
	  { $struc{type}= "point-elm";
	    $struc{value}= $1;

	    if ($opt_debug)
	      { 
		$struc{start}= pos($$r_data) - length($1);
		$struc{end}  = pos($$r_data) - 1;
		$struc{start_lc}= [pos_to_line_ch($r_indices,$struc{start})];
		$struc{end_lc}  = [pos_to_line_ch($r_indices,$struc{end})];
	        $struc{level}= $bracketlevel;
              };
	    warn "point-elm found: $1\n" if ($opt_debug);
	    return(pos($$r_data),\%struc);
	  };



	# nothing more to match, return undef
	return;  
      };	
  };

sub mydump
  { my($val,$perldump)= @_;
    my $buf;
    if ($perldump)
      { print "\$VAR=\n"; };
    rdump(\$buf,$val,0,undef,undef,1);
    print $buf;
    if ($perldump)
      { print ";\n"; };
  }


sub mysort
  { my $A= $a;
    my $B= $b; 

    $A= $s_index{$A} if (exists $s_index{$A});
    $B= $s_index{$B} if (exists $s_index{$B});

    return $A cmp $B;
  }

sub rdump
#internal
  { my($r_buf,$val,$indent,$is_newline,$comma,$special)= @_;

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
          { rdump($r_buf,$val->[$i],$indent,1,
	          ($i==$#$val) ? "" : ",",
		  ,$special);
          };
        $indent-=2; $$r_buf.= " " x $indent ."]$comma\n";
        return;
      };
    if ($r eq 'HASH')
      { $$r_buf.=  "\n" . " " x $indent if ($is_newline);
        $$r_buf.=  "{ \n"; $indent+=2;

	my @k;
	if (!defined $special)
	  { @k= sort keys %$val; }
	else
	  { @k= sort mysort (keys %$val); };

        for(my $i=0; $i<= $#k; $i++)
          { my $k= $k[$i];
            my $st= (" " x $indent) . $k . " => ";
            my $nindent= length($st);
            if ($nindent-$indent > 20)
              { $nindent= $indent+20;
                $st.= "\n" . (" " x $nindent)
              };

            $$r_buf.= ($st);
            rdump($r_buf,$val->{$k},$nindent,0,
	          ($i==$#k) ? "" : ",",
		  ,$special);
          };
        $indent-=2; $$r_buf.= " " x $indent . "}$comma\n";
        return;
      };
    $$r_buf.=  " " x $indent if ($is_newline);
    $$r_buf.=  "REF TO: \'$r\'$comma\n";
  }

sub print_from_to
  { my ($r_data,$from,$to)= @_;
    print (substr $$r_data, $from, $to-$from+1);
  }

sub help
  { my $p= $FindBin::Script;

    print <<END

           **** $p $version -- adl parser
                              Goetz Pfeiffer 2005

  options:
    -h: help
    -f [file], neither -i not -f are given, read from stdin
    -b : replace existing file, make a backup
    --dump -d : dump internal parse tree to stdout
    --perldump: dump perl-compatible parse-tree
    --import -i [file]: import data from perl-dump file
    --debug: used to debug this script
    --legacy: allow old-style meta-commands in *.cdl files
      (like #if and #endif)
    --new-sort: use new sorting method  
END
  }
