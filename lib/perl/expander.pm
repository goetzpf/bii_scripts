package expander;

use strict;
#use Carp;


BEGIN {
    use Exporter   ();
    use vars       qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
    # set the version for version checking
    $VERSION     = 1.3;

    @ISA         = qw(Exporter);
    @EXPORT      = qw();
    %EXPORT_TAGS = ( );     # eg: TAG => [ qw!name1 name2! ],

    # your exported package globals go here,
    # as well as any optionally exported functions
    @EXPORT_OK   = qw(&parse);
}

use vars      @EXPORT_OK;

our %m;
my $is_lazy=0;
my $use_arrays=0;
our $debug=0;

my $silent=0;

my $callback;

my %match_h= ( '(' => ')',
	       '[' => ']',
	       '{' => '}');

my %is_bracket= ( '(' => 1,
                  ')' => 1,
                  '[' => 1,
                  ']' => 1,
                  '{' => 1,
                  '}' => 1);
		  
my %keywords= map{ $_ => 1 } 
              qw (set eval perl if else endif include for endfor 
	          comment debug silent loud);		  


my $err_pre;
my $err_post;
my $err_module="expander.pm";
my $err_line;
my $err_file;


# used modules

sub get_var
  { my($name,$index)= @_;
  
    if (!defined $index)
      { return($m{$name}); };
    if (!exists $m{$name})
      { return; };
    return($m{$name}->[$index]);
  }
  
sub test_var
  { my($name,$index)= @_;
  
    if (!exists $m{$name})
      { return; };
      
    if (defined $index)
      { if (ref($m{$name}) ne 'ARRAY')
          { return; };
        return(  defined($m{$name}->[$index]) ? 1 : undef); 
      }  
    else
      { return(1); };
  }
  
sub set_var  
  { my($name,$index,$value)= @_;
  
    if (!defined $value)
      { $m{$name}= $index; 
        return;
      };
    $m{$name}->[$index]= $value;
  }

sub parse_file
  { my($filename, %options)= @_;
    local($/);
    local(*F);
    undef $/;
    my $var;
    
    if (!defined $filename)
      { $var= <>; }
    else
      { open(F, $filename) or die "unable to open $filename";
        $var= <F>;
        close(F);
	$err_file= $filename;
      };	
    parse_scalar(\$var,%options);
  }    

sub parse_scalar
  { my($r_line,%options)= @_;
    local(*F);
    my $p;
    my(@ifcond)=(1);
    my @forstack;
  
    my $pre;
    my $post;
    
    my $fh= $options{filehandle};
    if (!defined $fh)
      { my $filename= $options{filename};
        if (!defined $filename)
	  { $fh= \*STDOUT; }
	else
	  { open(F, ">$filename") or die "unable to create $filename";
	    $fh= \*F;
	  }
      };
      
    if (exists $options{lazy})
      { $is_lazy= $options{lazy}; };
      
    if (exists $options{arrays})  
      { $use_arrays= $options{arrays}; };
    
    if (exists $options{callback}) 
      { $callback= $options{callback}; }; 
    
    for(pos($$r_line)= 0, $p=0;
        $$r_line=~ /\G(.*?)(\\\$|\$|\\\\n|\\n|\\$|\s+|$)/gsm;
        #$$r_line=~ /\G(.*?)(\\\$|\$|\\\\n|\\n|\\$)/gsm;
	$p= pos($$r_line))
      {

        $pre= $1;
	$post= $2;
        
	if ($pre ne "")
	  { print $fh $pre if ($ifcond[-1]>0); };
	  
        if ($post=~ /\s+/)
	  { next if ($silent);
	    print $fh $post if ($ifcond[-1]>0);
	    next;
	  };
	  
	if ($post eq "")
	  { 
	    next if ($silent);
	    print $fh "\n";
	    next;
	  };

	if ($post eq "\\\\n") # backslash-backslash-n
	  { print $fh "\\n" if ($ifcond[-1]>0);
	    next; 
	  };

	if ($post eq "\\n") # backslash-n
	  { print $fh "\n" if ($ifcond[-1]>0);
	    next; 
	  };

	if ($post eq "\\\$") # backslashed dollar
	  { print $fh '$' if ($ifcond[-1]>0);
	    next; 
	  };
	  
	if ($post eq "\\") # backslash at end of line
	  { 
            $p= pos($$r_line);
	    if ($$r_line!~ /\G(.*?)^/gsm)
	      { pos($$r_line)= $p; };
	    next;  
	  }
	
	$p= pos($$r_line); # pos after "$"
	my $ex= variable_expand($r_line, $p);
	if (defined $ex)
	  { print $fh $ex if ($ifcond[-1]>0);
	    next;
	  };

	if ($$r_line=~ /\G(set|eval|perl|if|include|for|comment|debug)\s*\(/gs)
	  { 
	    if ($debug)
	      { warn "--- \"$1\" recognized,\n"; };

	    if (($1 eq 'eval') || ($1 eq 'set') || ($1 eq 'perl'))
	      {	my $word= $1;
	      
	        if ($ifcond[-1]<=0)
	          { $err_line= __LINE__;
		    my $end= skip_bracket_block($r_line,pos($$r_line)-1);
		    pos($$r_line)= $end+1;    
		    next; 
		  };

		$err_line= __LINE__;
		my($res,$end)= 
		   eval_bracket_block($r_line,pos($$r_line)-1,($word eq 'perl'));
		print $fh $res if ($word eq 'eval');
		pos($$r_line)= $end+1;
		next;
              }
	    elsif  ($1 eq 'if')
	      { 
		# if command
		$err_line= __LINE__;
		my($res,$end)= 
		   eval_bracket_block($r_line,pos($$r_line)-1);

	        if ($ifcond[-1]<=0) # already within an ignore-part
	          { if ($debug)
		      { warn "--- skip complete if-block\n"; };
		    push @ifcond, 0;  # 0: ignore from IF to ENDIF !! 
		  } 
                else
		  { if ($debug)
		      { if ($res)
		          { warn "--- evaluated TRUE, continue\n"; }
			else
		          { warn "--- evaluated FALSE, skip 1st if-part\n"; }
		      };
		    push @ifcond, ($res) ? 1 : -1; 
		  
		  };
		pos($$r_line)= $end+1;
		next;
	      }
	    elsif  ($1 eq 'for')
	      { 
#warn "start matching at: " . (pos($$r_line)-1);
                my($start,$end)= match($r_line,pos($$r_line)-1);
#warn "matched at: $start,$end";
		if (!defined $start)
		  { $err_pre= "malformed for-block";
		    $err_line= __LINE__;
		    fatal_parse_error($r_line,$p,); 
		  };
		my $sub= substr($$r_line,$start+1,$end-$start-1);
#warn "substr: |$sub|";
		my($pre,$cond,$loop)= split(/;/,$sub);
		if (!defined $loop)
		  { $err_pre= "malformed for-block";
		    $err_line= __LINE__;
		    fatal_parse_error($r_line,$p); 
		  };
		
		$err_line= __LINE__;
		eval_part($pre,$r_line,$p);
		push @forstack, [$end+1,$cond,$loop];
		pos($$r_line)= $end+1;
	        next;	
	      }
	    elsif  (($1 eq 'comment') || ($1 eq 'debug'))
	      { 
	        my $word= $1;
                my($start,$end)= match($r_line,pos($$r_line)-1);
#warn "matched at: $start,$end";
		if (!defined $start)
		  { 
		    $err_pre= "malformed for-block";
		    $err_line= __LINE__;
		    fatal_parse_error($r_line,$p); 
		  };
		if ($word eq 'debug')
		  { 
		    my $str= substr($$r_line,$start+1,$end-$start-1);
		    print $fh $str;
		  }; 
		pos($$r_line)= $end+1;
		next;
	      }
	    elsif  ($1 eq 'include')
	      {
#die "include encountered\n";
		$err_line= __LINE__;
		my($res,$end)= 
		   eval_bracket_block($r_line,pos($$r_line)-1);

	        if (!-r $res)
		  { $err_pre= "unable to open file $res";
		    $err_line= __LINE__;
		    fatal_parse_error($r_line,$p); 
		  };
#die "res: $res\n";
		my %local_options= %options;
		$local_options{filehandle}= $fh;
		parse_file($res,%local_options);  
		pos($$r_line)= $end+1;
		next;
	      }
	    else
	      { die "internal error"; }  
	   }      
	
	pos($$r_line)= $p;
	if ($$r_line=~ /\G(else|endif|endfor|silent|loud)/gs)
          { 
	    if ($debug)
	      { warn "--- \"$1\" recognized,\n"; };
	  
	    if ($1 eq 'silent')
	      { $silent=1; 
	        next;
	      };
	    
	    if ($1 eq 'loud')
	      { $silent=0; 
	        next;
	      };
	    
	    if   ($1 eq 'else')
	      { 
	        if ($#ifcond<1)
	          { $err_pre= "else without if";
		    $err_line= __LINE__;
		    fatal_parse_error($r_line,$p); 
	          };
    	        $ifcond[-1]= -$ifcond[-1]; # 1 --> -1, -1-->1, 0-->0
                
		if ($debug)
		  { if ($ifcond[-1]<=0)
		      { warn "--- skipping\n"; }
		    else
		      { warn "--- parse this block\n"; };
		  };
		next;
	      }

	    elsif  ($1 eq 'endif')
              { if ($#ifcond<1)
	          { $err_pre= "endif without if";
		    $err_line= __LINE__;
		    fatal_parse_error($r_line,$p); 
		  };
	        pop @ifcond; 
	        next; 
              }
	    elsif  ($1 eq 'endfor')
	      { if ($#forstack<0)
	          { $err_pre= "endfor without for";
		    $err_line= __LINE__;
		    fatal_parse_error($r_line,$p); 
		  };
		my($pos1,$cond,$loop)= @{$forstack[-1]};
		
		$err_line= __LINE__;
		eval_part($loop,$r_line,$pos1);
                $err_line= __LINE__;
		my $res= eval_part($cond,$r_line,$pos1);
		
		if ($debug)
		  { if ($res)
		      { warn "--- looping\n"; }
		    else
		      { warn "--- leaving loop\n"; };
		  };
		if ($res)
		  { pos($$r_line)= $pos1; }
		else
		  { pop @forstack; };
		next;
	      }
	    else
	      { die "internal error"; }  
	  };

	pos($$r_line)= $p;
      } # for 
    
    if ($#ifcond !=0 )
      {  
        $err_pre= "unfinished if-blocks";
	$err_line= __LINE__;
        fatal_parse_error($r_line,$p); 
      };
      
    print $fh substr($$r_line,$p);

    if (exists $options{filename})
      { close(F); };
  }

sub eval_part
  { my($sub,$r_line,$pos,$do_not_replace)= @_;
  
#warn "before:|" . $sub . "|\n";
#warn "after:|" . mk_perl_varnames($sub,$comment) . "|\n";

    my $subst;
    
    if (!$do_not_replace)
      { $subst= mk_perl_varnames($sub); 
        if ($debug)
          { warn "--- evaluate \"$sub\",\n--- after perlify: \"$subst\"\n"; };
      }
    else
      { $subst= $sub; 
        if ($debug)
          { warn "--- evaluate \"$subst\"\n"; };
      };    
    
    my $res= eval($subst);
    if ((!defined ($res)) && ($@ ne ""))
      { 
	$err_pre= "eval-error:$@";
	fatal_parse_error($r_line,$pos); 
      };
    return($res);
  }

sub skip_bracket_block
  { my($r_line,$start_at)= @_;
  
    my($start,$end)= match($r_line,$start_at);

    if (!defined $start)
      { 
        $err_pre= "bracketed-block is malformed";
	fatal_parse_error($r_line,$start_at); 
      };
    return($end);
  }

sub eval_bracket_block
  { my($r_line,$start_at,$do_not_replace)= @_;
  
    my($start,$end)= match($r_line,$start_at);

    if (!defined $start)
      { 
        $err_pre= "eval-block is malformed";
	fatal_parse_error($r_line,$start_at); 
      };
    my $sub= substr($$r_line, $start+1, $end-$start-1);
#warn "evaluate: $sub";

    my $res= eval_part($sub,$r_line,$start_at,$do_not_replace); 

    return($res,$end);
  }

sub match
# starts at str[pos], tries to find the end of a bracket-block
# or a string. All special characters may be escaped with a 
# backslash
  { my($r_str,$pos,$in_string)= @_;
    
#warn "called at pos $pos\n";
    my $o= substr($$r_str,$pos,1);
    my $c;
    
    if (($o eq '"') || ($o eq "'"))
      { $c= $o; 
        $in_string=1;
      }
    else
      { $c= $match_h{$o}; };

#warn "o:" . $o . "c:" . $c . "\n";    
    if (!defined $c)
      { return;
      };

    pos($$r_str)= $pos+1;
    while ($$r_str=~ /\G.*?([\\\[\]\(\)\{\}\"\'])/gs) 
      { if ($1 eq $c)
          { return($pos,pos($$r_str)-1); };
	if ($1 eq "\\")
	  { pos($$r_str)= pos($$r_str)+1;
	    next;
	  };
	  
	if ($in_string)
	  { if (exists $is_bracket{$1})
	      { next; };
          };
	  
	my($start,$end)= match($r_str,pos($$r_str)-1);
#warn "returned substr: " . substr($$r_str,$start,$end-$start+1) . "\n";
	return if (!defined $start);
	pos($$r_str)= $end+1;
      };
    return;
  }
      
sub fatal_parse_error
  { my($r_str,$position,$pline,$message)= @_; 
  
    my($line,$column)= find_position_in_string($r_str,$position);
    
    my $err= "fatal error\n" .
             "module: $err_module";
    $err.= " line: $err_line" if (defined $err_line);
    $err.= "\n$err_pre\n" if (defined $err_pre);    
    $err.= "position in file";
    $err.= " $err_file" if (defined $err_file);
    $err.= ": line $line, column $column\n";
    $err.= "\n$err_post\n" if (defined $err_post);    
    die $err;
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
#    while($$r_str=~ /\G.*?^(.*?)$/gms)
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

sub variable_expand
  { my($r_line, $p)= @_;
  
    pos($$r_line)= $p;
    
    if ($use_arrays)
      { 
	if ($$r_line=~ /\G\{(\w+)\[(\d+)\]\}/gs)
	  { # a variable is to expand
	    
	    if (defined $callback)
	      { &$callback($1,$2); };
	    if (!exists $m{$1})
	      { 
		$err_pre= "macro \$\{$1\} is not defined";
		fatal_parse_error($r_line,$p)
	      };
	    if ($debug)
	      { warn "--- expand \$\{$1\[$2\]\} to " . $m{$1}->[$2] . "\n"; };

	    return($m{$1}->[$2]);
	  };
        pos($$r_line)= $p;
      }	  
    
    pos($$r_line)= $p;

    if ($$r_line=~ /\G\{\$(eval|perl)(\s*)\(/gs)
      { my $startpos= pos($$r_line)-4-length($2)-3;
        
#warn "at startpos:" . substr($$r_line,$startpos);	
	my $st_pos= pos($$r_line);
        my $word= $1;
        my($name,$end)= 
	   eval_bracket_block($r_line,$st_pos-1,($word eq 'perl'));
        # a variable is to expand
	if (defined $callback)
	  { &$callback($name); };
	if (!exists $m{$name})
	  { 
            #warn "parsed: |$1|";
	    $err_pre= "macro \$\{$name\} is not defined";
	    fatal_parse_error($r_line,$p)
	  };
	if ($debug)
	  { warn "--- expand \$\{\$$word" . 
	         substr($$r_line, $st_pos-1,$end-$st_pos+1) .
		 "\} to " . $m{$name} . "\n"; };
	$end= skip_bracket_block($r_line,$startpos);
	pos($$r_line)= $end+1;    
		    
	return($m{$name});
      };

    pos($$r_line)= $p;		


    if ($$r_line=~ /\G\{(\w+)\}/gs)
      { # a variable is to expand
	if (defined $callback)
	  { &$callback($1); };
	if (!exists $m{$1})
	  { 
#warn "parsed: |$1|";
	    $err_pre= "macro \$\{$1\} is not defined";
	    fatal_parse_error($r_line,$p)
	  };
	if ($debug)
	  { warn "--- expand \$\{$1\} to " . $m{$1} . "\n"; };
	return($m{$1});
      };

    pos($$r_line)= $p;

    if ($is_lazy)
      { if ($use_arrays)
          {
            if ($$r_line=~ /\G(\w+)\[(\d+)\]/gs)
	      { 
		# a variable is to expand
		if (!exists $keywords{$1})
		  { 
		    if (defined $callback)
		      { &$callback($1,$2); };
		    if (!exists $m{$1})
		      { 
			$err_pre= "macro  \$$1 is not defined";
			fatal_parse_error($r_line,$p); 
		      };
	            if ($debug)
	              { warn "--- expand \$$1\[$2\] to " . $m{$1}->[$2] . "\n"; };
		    return($m{$1}->[$2]);
		  }
	      };
	    pos($$r_line)= $p;
	  };
      
        if ($$r_line=~ /\G(\w+)/gs)
	  { 
	    # a variable is to expand
	    if (!exists $keywords{$1})
	      { 
		if (defined $callback)
		  { &$callback($1); };
		if (!exists $m{$1})
		  { $err_pre= "macro  \$$1 is not defined";
		    fatal_parse_error($r_line,$p); 
		  };
	        if ($debug)
	          { warn "--- expand \$$1 to " . $m{$1} . "\n"; };
		return($m{$1});
	      }
	  };
	pos($$r_line)= $p;
      };

    pos($$r_line)= $p;
    return;  
  }
          

sub mk_perl_varnames
# internal
  { my($line)= @_;
  
#print "in: |$line|\n";
    if ($use_arrays)
      { # replace ${a[n]} with \$m{a}->[n]
        $line=~ s/(?<!\\)\$\{(\w+)\[(\d+)\]\}/\\\$m\{$1\}->\[$2\]/gs;
      };
    
    # replace ${a} with \$m{a}
    $line=~ s/(?<!\\)\$(\{\w+\})/\\\$m$1/gs;
  
    if ($is_lazy)
      { if ($use_arrays)
          { 
#warn;	  
	    $line=~ s/(?<!\\)\$(\w+)\[(\d+)\]/\\\$m\{$1\}->\[$2\]/gs; 
	  }; 
	  
        $line=~ s/(?<!\\)\$(\w+)/\\\$m\{$1\}/gs; 
      };

    # replace \$ with $
    $line=~ s/\\\$/\$/gs;

    if (defined $callback)
      { pos($line)=0;
        while ($line=~/\G.*?\$m\{(\w+)\}/g) 
	  { &$callback($1); };
        if ($use_arrays)
	  { pos($line)=0;
            while ($line=~/\G.*?\$m\{(\w+)\}->\[(\d+)\]/g) 
	      { &$callback($1,$2); };
	  };
      };

#print "out: |$line|\n";

    return($line); 
  }
  


1;

__END__
# Below is the short of documentation of the module.

=head1 NAME

expander - a Perl module to perform macro expansions in ascii-files

=head1 SYNOPSIS

  use expander;
  undef $/;

  my $st= <>;

  parse_scalar($st,lazy=>1);

=head1 DESCRIPTION

=head2 Preface

This package provides functions in order to perform macro
substitutions in ascii files. Aside from simple substitution,
calculations of complex expressions are also possible. 

=head2 Basic concepts

The module provides two parse-functions that take either a 
scalar variable the filename of the file that contain the text to 
parse.

Both functions scan for variables, expressions or keywords in the
text. If one of these is encountered, the text printed is altered. 
Otherwise the input-text is printed unchanged.

=over 4

=item I<Variables>

Variables have the following form:

  ${name}
  ${name[index]}
  
If lazy mode is active, this form is recognized too:

  $name
  $name[index]
  
This first lines in the examples are simple variables. A variable
of this type can hold numbers or strings. The second lines are the
array form. In this case the variable is an array of values, each value 
can be accessed by an index.

=item I<expressions>

An expression consists of variables and operators or functions. 
Almost all expressions that are valid in perl can be used. For example
this expression defines and sets a variable

  $myvar=1
  
This expression does a simple calculation

  $myvar*2
  
=item I<keywords>

Keywords always start with a dollar sign. They may be followed by
an expression that is enclosed in brackets. Examples:

  $if (<expression>)
  $else
  $endif

In this case, $if is followed by an expression, $else and $endif aren't.

=item I<quoting>

If the dollar sign is preceeded by a backslash, the following sequence
is not interpreted as a variable or keyword. The backslash, however, is removed.
So

  \$myvar
  
expands to $myvar.

=item I<line concatenation>

A single \ at the end of a line concatenates this line with the 
next one. This technique can be used in order to avoid unwanted
empty lines in the output.

=item I<forced linefeed>

A "\n" is always replaced with a line-feed.

=back

=head2 The following keywords are recognized:

=over 4

=item I<set>

  $set(<expression>)
  
The expression is evaluated, but the result is not printed.

=item I<eval>

  $eval(<expression>)
  
The expression is evaluated and the result is printed.
Note that is can also be used to calculate the name of a 
variable and expand it:

  ${$eval(<expression>)}

=item I<perl>

  $perl(<statements>)
  
The given statements are evaluated without further changes
by the perl-interpreter. This can be used to include perl-modules

  $perl(require modulename;) 
  
or to define functions
  
  $perl(sub myfunc { print "$_[0]\n"; })
  
Note that variables of expander cannot be used here, since they 
are represented internally in a perl-hash. In principle you could
access the variables here by directly accessing the hash, but that
would not be portable and bad style. If you define new functions here,
the functions should take parameters instead of trying to access the
expander-variables directly.  

Note that is can also be used to calculate the name of a 
variable and expand it:

  ${$perl(<expression>)}

=item I<if>

  $if (<expression>)
  
The expression is evaluated. It it is logical true, the following
part is further parsed until $else or $endif is encountered.

=item I<else>

  $else

This belongs to an $if statement before. It the if-expression was true,
everything between else and endif is ignored. If the if-expression was
false, everything between if and else was ignored, everything between
else and endif is parsed.  

=item I<endif>

  $endif

This finishes an if-statement. 

=item I<include>

  $include(<expression>)
  
This command includes and parses the file specified by <expression>  
  
=item I<comment>

  $comment(<comment>)
  
Everything between the brackets is ignored. Note however, that
bracket-pairs (round, square and curly) within the comment 
must be matching, nested pairs.

=item I<for>

  $for(<init expression>;<condition>;<loop statement>)
  
This starts a loop very similar to the loop in c or perl.
The text between for end endfor is printed several times.
The init and loop-expression can be used to count a counter-variable
up or down.

=item I<endfor>
  
  $endfor
  
This ends a for-expression

=item I<silent>
  
  $silent
  
This option changes to mode to silent-mode. In this mode, 
spaces and line-feeds are not printed. This mode is useful
if large parts of the input only consist of variable definitions.
Usually, each empty line that is often used to separate definitions,
would be printed.

=item I<loud>
  
  $loud
  
This switches back from silent-mode to the normal mode of operation.  
  
=back

=head2 The option hash

parse_scalar and parse_file take an option-hash as optional
second parameter. For this hash the following keys are defined:

=over 4

=item I<filehandle>

  parse_scalar($myvar, filehandle=>\*MYFILE)

If this hash key is provided, the output is printed to the
given filehandle.

=item I<filename>

  parse_scalar($myvar, filename=>"output.txt")

If this hash key is provided, a file with the given name is 
created and the output is printed to that file. If neither "filehandle"
nor "filename" is given, all ouput is printed to STDOUT.

=item I<lazy>

  parse_scalar($myvar, lazy=>1)
  
If lazy is not zero or undefined, the extended lazy syntax is also accepted

=item I<arrays>

  parse_scalar($myvar, arrays=>1)

If arrays is not zero or undefined, arrays are also accepted

=item I<callback>

  parse_scalar($myvar, callback=> \&mycallback)

With this option, a user-defined callback function is defined
that is called every time a variable is to be expanded. The callback
function is given the name of the variable and (optional) the 
array-index. If the variable does not yet exist, the callback function
must take care of setting this variable with set_var(), otherwise
a run-time error is raised.

=back

=head2 Implemented Functions:

=over 4

=item *

B<parse_scalar()>

  parse_scalar($st,%options)
  
This function parses a (multi-line) scalar and prints the results.
See also the description of the option-hash further up.

=item *

B<parse_file()>

  parse_file($filename,%options)
  
This function parses given file and prints the results.
See also the description of the option-hash further up.

=item *

B<get_var()>

  get_var($varname)
  get_var($varname,$index)

This function returns the value of the internal variable with the
name $varname. If $index is given, an index-variable is assumed.
  
=item *

B<set_var()>

  set_var($varname,$value)
  set_var($varname,$index,$value)

This function sets the value of the internal variable with the
name $varname. If $index is given, an index-variable is assumed.

=item *

B<test_var()>

  test_var($varname,$index)

This function returns 1 if the variable (and optional with this index)
is defined, otherwise it returns undef.

=back

=head1 AUTHOR

Goetz Pfeiffer,  goetzp@gmx.net

=head1 SEE ALSO

perl-documentation

=cut


