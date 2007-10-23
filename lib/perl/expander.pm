package expander;

use strict;
use Cwd;
use Data::Dumper;
use IO::Scalar;
use File::Spec;
#use Carp;


BEGIN {
    use Exporter   ();
    use vars       qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
    # set the version for version checking
    $VERSION     = 2.5;

    @ISA         = qw(Exporter);
    @EXPORT      = qw();
    %EXPORT_TAGS = ( );     # eg: TAG => [ qw!name1 name2! ],

    # your exported package globals go here,
    # as well as any optionally exported functions
    @EXPORT_OK   = qw(&parse);
}

use vars      @EXPORT_OK;

our %m;
our $debug=0;

my $allow_round_brackets= 0;
my $forbid_nobracket_vars= 0;
my $allow_not_defined_vars= 0;

my @m_stack;

my $silent=0;

my $recursive=0;

my $callback;

my @include_paths;

use constant {
  SM_NO             => 0x00,

  SM_SIMPLE_SCALAR  => 0x01,
  SM_SIMPLE_INDEXED => 0x11,

  SM_CURLY_SCALAR   => 0x02,
  SM_CURLY_INDEXED  => 0x12,

  SM_ROUND_SCALAR   => 0x03,
  SM_ROUND_INDEXED  => 0x13,

  SM_SUBTYPE        => 0x0F,

  SM_EVAL           => 0x04,

  SM_FUNC           => 0x101,
  SM_KEYWORD        => 0x102,
  SM_ARGKEYWORD     => 0x103,

  SM_KEYWORD_OR_FUNC=> 0x100,

  SM_INDEXED        => 0x10,

             };

use constant {
  VE_FUNC => 1,
  VE_KEYWORD => 2,
  VE_ARGKEYWORD => 3,
  VE_DONE => 4
             };

use constant {
  KY_STD      => 0x01,
  KY_PRINT    => 0x02,
  KY_REPLACE  => 0x04,
  KY_BLOCK    => 0x08,
  KY_FUNCDEF  => 0x10,
             };

my %match_h= ( '(' => ')',
               '[' => ']',
               '{' => '}');

my %is_bracket= ( '(' => 1,
                  ')' => 1,
                  '[' => 1,
                  ']' => 1,
                  '{' => 1,
                  '}' => 1);

my %simple_keywords= map{ $_ => 1 } 
              qw (else endif endfor dumphash ifstack silent loud leave begin end);

my %arg_keywords= (set      => KY_STD|KY_BLOCK|KY_REPLACE,
                   eval     => KY_STD|KY_BLOCK|KY_REPLACE|KY_PRINT,
                   perl     => KY_STD|KY_BLOCK,
                   func     => KY_STD|KY_BLOCK|KY_FUNCDEF,
                   if       => KY_STD,
                   include  => KY_STD,
                   write_to => KY_STD,
                   append_to=> KY_STD,
                   for      => KY_STD,
                   for_noblock => KY_STD,
                   comment  => KY_STD,
                   debug    => KY_STD,
                   export   => KY_STD,
                   list     => KY_STD,
                   list_new => KY_STD,
                   );

my %functions;

my $err_pre;
my $err_post;
my $err_module="expander.pm";
my $err_line;
my $err_file;

my $gbl_err_pre;

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

sub declare_func
  { my($identifier,$funcname)= @_;
    $functions{$identifier}= $funcname;
  }

sub parse_file
  { my($filename, %options)= @_;
    my $var;
    my $old_err_file= $err_file;

    if (!defined $filename)
      { local($/);
        undef $/;
        $var= <>; 
      }
    else
      { local($/);
        local(*FI);
        undef $/;
        open(FI, $filename) or die "unable to open \"$filename\"";
        $var= <FI>;
        close(FI);
        $err_file= $filename;
      };        
    # perl seems to add a linefeed ("\n") at the
    # end of the scalar even if the file didn't contain one
    parse_scalar_i(\$var,%options);
    $err_file= $old_err_file;
  }    

sub parse_scalar
  { $err_file= undef;
    parse_scalar_i(@_);
  }

sub parse_scalar_i
  { my($r_line,%options)= @_;
    # CAUTION: due to the use of the same file-handle
    # when parse_scalar_i is called recursivly when
    # $include() is executed, F MUST NOT be local here
    # local(*F);
    my $must_close_fh;
    my $p;
    my $was_left;
    my(@ifcond)=(1);
    my @forstack;

    my $m_stack_init= $#m_stack;

    my $pre;
    my $post;

    my $fh;

    if ($options{forbit_nobrackets})
      { $forbid_nobracket_vars= 1; };

    if ($options{roundbrackets})
      { $allow_round_brackets= 1; };

    if ($options{allow_not_defined_vars})
      { $allow_not_defined_vars= 1; };

    if ($options{recursive})
      { $recursive= 1; };

    # it is important to have absolute paths here,
    # see also how find_file() works...
    if (exists $options{includepaths})
      { @include_paths= @{$options{includepaths}}; 
      };
# die "I:" . join("|",@include_paths);

    if (exists $options{silent})
      { $silent= $options{silent}; };

    $gbl_err_pre= $options{errmsg};

    my $scalar_ref= $options{scalarref};
    if (defined $scalar_ref)
      { $fh= new IO::Scalar $scalar_ref; 
        $must_close_fh= 1;
      }
    else
      { $fh= $options{filehandle};
        if (!defined $fh)
          { my $filename= $options{filename};
            if (!defined $filename)
              { $fh= \*STDOUT; }
            else
              { open(F, ">$filename") or die "unable to create $filename";
                $fh= \*F;
		$must_close_fh= 1;
              }
          };
      };

    if (exists $options{callback}) 
      { $callback= $options{callback}; }; 


    my $max= length($$r_line);

    for(pos($$r_line)= 0, $p=0;
        $$r_line=~ /\G(.*?)(\\\$|\$|\\\\n|\\n|\\\\$|\\$|\s+|$)/gsm;
        #                    \$  $   \\n   \n  \\eol  \eol
        #$$r_line=~ /\G(.*?)(\\\$|\$|\\\\n|\\n|\\$)/gsm;
        $p= pos($$r_line))
      {
        $err_line= -1;

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
#           next if ($silent);
#           print $fh "\n";
            next;
          };

        if ($post eq "\\\$") # backslashed dollar
          { print $fh '$' if ($ifcond[-1]>0);
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

        if ($post eq "\\\\") # backslash-backslash at end of line
          { print $fh "\\" if ($ifcond[-1]>0);
            next;
          };

        if ($post eq "\\") # backslash at end of line
          { 
            $p= pos($$r_line);
            if ($$r_line!~ /\G(.*?)^/gsm)
              { pos($$r_line)= $p; 
              };
            next;  
          }

        # from here, $pos must be '$'
        die "internal error" if ($post ne '$'); # assertion

        $p= pos($$r_line); # pos after "$"

        # no variable expansion in a skipped part:
        my ($tp,$ex, $st, $en)= variable_expand($r_line, $p, $ifcond[-1]<=0); 

        if ($tp == VE_DONE) 
          { print $fh $ex if ($ifcond[-1]>0);   
                             # not needed here: if ($ifcond[-1]>0);
                             # since variable_expand's 3rd parameter...
            next;
          };

        if ($tp == VE_FUNC)
          { 
            if ($debug)
              { warn "--- \"$ex\" recognized,\n"; };
            $err_line= __LINE__;
            print $fh eval_func_block($ex,$r_line,$st,$en);;
            pos($$r_line)= $en+1;
            next;
          };

        if ($tp == VE_ARGKEYWORD)
          { 
            if ($debug)
              { warn "--- \"$ex\" recognized,\n"; };

            my $ky_flag= $arg_keywords{$ex};

            if ($ky_flag & KY_BLOCK)
              { if ($ifcond[-1]<=0)
                  { $err_line= __LINE__;
                    pos($$r_line)= $en+1;    
                    next; 
                  };

#strdump($r_line, pos($$r_line), 40, "TRACE"); # 

                $err_line= __LINE__;
                my $res= eval_bracket_block($r_line,$st,$en,$ky_flag);

                print $fh $res if ($ky_flag & KY_PRINT);
                pos($$r_line)= $en+1;
                next;
              }
            elsif  ($ex eq 'export')
              { 
                my $sub= substr($$r_line,$st+1,$en-$st-1);
                my @symbols= split(/\s*,\s*/,$sub);
                if (!@symbols)
                  { $err_pre= "malformed export-command";
                    $err_line= __LINE__;
                    fatal_parse_error($r_line,$p); 
                  };
                if ($#m_stack<0)
                  { $err_pre= "export is not within begin..end";
                    $err_line= __LINE__;
                    fatal_parse_error($r_line,$p); 
                  };
                my $r_backup= $m_stack[-1];
                foreach my $sym (@symbols)
                  { if ($sym!~/^[\$\@](\w+)$/)
                      { $err_pre= "symbol \"$sym\" is not a valid symbol";
                        $err_line= __LINE__;
                        fatal_parse_error($r_line,$p); 
                      };
                    my $s= $1;
                    if (!exists $m{$s})
                      { $err_pre= "symbol \"$sym\" is not defined here";
                        $err_line= __LINE__;
                        fatal_parse_error($r_line,$p); 
                      };
                    $r_backup->{$s}= $m{$s};
                  };     
                pos($$r_line)= $en+1;
                next;
              }  
            elsif  ($ex eq 'if')
              { 
                # if command
                $err_line= __LINE__;
                my $res= 
                   eval_bracket_block($r_line,$st,$en,KY_REPLACE);
                if ($ifcond[-1]<=0) # already within an ignore-part
                  { 
                    if ($debug)
                      { warn "--- skip complete if-block\n"; };
                    push @ifcond, 0;  # 0: ignore from IF to ENDIF !! 
                  } 
                else
                  { 
                    if ($debug)
                      { if ($res)
                          { warn "--- evaluated TRUE, continue\n"; }
                        else
                          { warn "--- evaluated FALSE, skip 1st if-part\n"; }
                      };
                    push @ifcond, ($res) ? 1 : -1; 

                  };
                pos($$r_line)= $en+1;
                next;
              }
            elsif  (($ex eq 'for') || ($ex eq 'for_noblock'))
              { 
#warn "start matching at: " . (pos($$r_line)-1);
                my $sub= substr($$r_line,$st+1,$en-$st-1);
#warn "substr: |$sub|";
                my($pre,$cond,$loop)= split(/;/,$sub);
                if (!defined $loop)
                  { $err_pre= "malformed for-command";
                    $err_line= __LINE__;
                    fatal_parse_error($r_line,$p); 
                  };

                my $m_stacked;
                if ($ifcond[-1]>0) 
                  { # do not evalutate the for-condition
                    # when we are within an ignore-block
                    $err_line= __LINE__;
                    # do a backup of all variables, like "$begin" does:
                    if ($ex eq 'for')
                      { my %backup= %m;
                        push @m_stack, \%backup;
                        $m_stacked= 1;
                      };
                    eval_part($pre,$r_line,$p);
                  };
                push @forstack, [$en+1,$cond,$loop,$m_stacked];
                pos($$r_line)= $en+1;
                next;   
              }
            elsif  (($ex eq 'comment') || ($ex eq 'debug'))
              { 
                my $word= $ex;
                if ($word eq 'debug')
                  { 
                    my $str= substr($$r_line,$st+1,$en-$st-1);
                    print STDERR $str;
                  }; 
                pos($$r_line)= $en+1;
                next;
              }
            elsif  ($ex eq 'include')
              {
#die "include encountered\n";
                $err_line= __LINE__;
                my $res= 
                   eval_bracket_block($r_line,$st,$en,KY_REPLACE);

                if ($ifcond[-1]>0) 
                  { # do not actually do the include 
                    # when we are within an ignore-block
                    my $f= find_file($res,\@include_paths);
                    if (!defined $f)
                      { $err_pre= "unable to open file \"$res\"";
                        $err_line= __LINE__;
                        fatal_parse_error($r_line,$p); 
                      };
#die "res: $res\n";
                    my %local_options= %options;
                    $local_options{filehandle}= $fh;
		    parse_file($f,%local_options); 
                  } 
                pos($$r_line)= $en+1;
                next;
              }
            elsif  (($ex eq 'write_to') || ($ex eq 'append_to'))
              {
#die "include encountered\n";
                $err_line= __LINE__;
                my $res= 
                   eval_bracket_block($r_line,$st,$en,KY_REPLACE);

                if ($ifcond[-1]>0) 
                  { # do not actually do the thing 
                    # when we are within an ignore-block
                    close(F) if ($must_close_fh);
		    if ($ex eq 'write_to')
		      {  open(F, ">$res")  or die "unable to create $res"; 
		      }
		    else
		      { open(F, ">>$res") or die "unable to create $res"; 
		      }
                    $fh= \*F;
		    $must_close_fh= 1;
                  } 
                pos($$r_line)= $en+1;
                next;
              }
            elsif  (($ex eq 'list') || ($ex eq 'list_new')) 
              { 
                if ($ifcond[-1]>0) 
                  {
                    my $sub= substr($$r_line,$st+1,$en-$st-1);

                    if ($sub!~ /^\s*(\d*)\s*(?:,\s*"(.+)"|)\s*(?:,\s*(.+)|)$/) 
                      { $err_pre= "argument error in \$list: \"$sub\""; 
                        $err_line= __LINE__;
                        fatal_parse_error($r_line,$p); 
                      };

                    my $len= $1;
                    my $sep= $2;
                    my $rest= $3;
                    my %keep;
                    if (defined $rest)
                      { my @elms= split(/\s*,\s*/,$rest);
                        foreach my $elm (@elms)
                          { 
                            if ($elm!~/[\$\@](\w+)/)
                              { $err_pre= "argument error in \$list: \"$sub\""; 
                                $err_line= __LINE__;
                                fatal_parse_error($r_line,$p); 
                              };
                            $keep{$1}= 1;
                          };
                      };  


                    my $format= "%-${len}s=\"%s\"$sep\n";

                    my @l= sort keys %m;
                    if (($ex eq 'list_new') && ($#m_stack>=0))
                      { my $r_backup= $m_stack[-1];
                        @l= grep { (!exists($r_backup->{$_})) ||
                                   (exists $keep{$_}) 
                                 } @l;
                      };   

                    my $last= pop @l;
                    foreach my $k (@l)
                      { printf $format, $k, $m{$k}; };
                    printf "%-${len}s=\"%s\"\n", $last, $m{$last};

                  };
                pos($$r_line)= $en+1;
                next; 
              }
            else
              { die "internal error"; }  
           }      

        if ($tp == VE_KEYWORD)
          { 

            if ($debug)
              { warn "--- \"$ex\" recognized,\n"; };


            if ($ex eq 'begin')
              { if ($ifcond[-1]>0) 
                  { # make a backup of variables only if 
                    # not within an ignore-block
                    my %backup= %m;
                    push @m_stack, \%backup;
                  }
                next;
              }

            if ($ex eq 'end')
              { if ($ifcond[-1]>0) 
                  { # restore the backup of variables only if 
                    # not within an ignore-block
                    if ($#m_stack<0)
                      { $err_pre= "end without begin";
                        $err_line= __LINE__;
                        fatal_parse_error($r_line,$p);  
                      };
                    my $r_back= pop @m_stack;
                    %m= %$r_back;
                  }  
                next;
              }

            if ($ex eq 'dumphash')
              { 
                print STDERR "HASH-DUMP:\n",Data::Dumper->Dump([\%m], ['m']),"\n";
                next;
              };

            if ($ex eq 'ifstack')
              { 
                print STDERR "IF-STACK-DUMP:\n",join(",",@ifcond),"\n";
                next;
              };

            if ($ex eq 'leave')
              { $was_left=1; 
                last; 
              };

            if ($ex eq 'silent')
              { $silent=1; 
                next;
              };

            if ($ex eq 'loud')
              { $silent=0; 
                next;
              };

            if   ($ex eq 'else')
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

            elsif  ($ex eq 'endif')
              { 
                if ($#ifcond<1)
                  { $err_pre= "endif without if";
                    $err_line= __LINE__;
                    fatal_parse_error($r_line,$p); 
                  };
                pop @ifcond; 
                next; 
              }
            elsif  ($ex eq 'endfor')
              { if ($#forstack<0)
                  { $err_pre= "endfor without for";
                    $err_line= __LINE__;
                    fatal_parse_error($r_line,$p); 
                  };

                if ($ifcond[-1]<=0) 
                  { # within ignore-block
                    pop @forstack; 
                    next;
                  };

                my($pos1,$cond,$loop,$m_stacked)= @{$forstack[-1]};

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
                  { # leave for-loop:
                    pop @forstack; 
                    if ($m_stacked)
                      { 
                        if ($#m_stack<0)
                          { $err_pre= "single \"end\" within for-block";
                            $err_line= __LINE__;
                            fatal_parse_error($r_line,$p);  
                          };
                        my $r_back= pop @m_stack;
                        %m= %$r_back;
                      };
                  };
                next;
              }
            else
              { die "internal error"; }  
          }
        else
          { $err_pre= "internal error: unknown keyword";
            $err_line= __LINE__;
            fatal_parse_error($r_line,$p);  
          }  

        pos($$r_line)= $p;
      } # for 

    if ($#ifcond !=0 )
      {  
        $err_pre= "unfinished if-blocks";
        $err_line= __LINE__;
        fatal_parse_error($r_line,$p); 
      };

    if ($#forstack>=0)
      { $err_pre= "unfinished for-blocks";
        $err_line= __LINE__;
        fatal_parse_error($r_line,$p); 
      };

    if ($#m_stack>$m_stack_init)
      { $err_pre= "unfinished begin-blocks";
        $err_line= __LINE__;
        fatal_parse_error($r_line,$p); 
      };

    print $fh substr($$r_line,$p) if (!$was_left);

    if ($must_close_fh)
      { close(F); };
  }

sub eval_part
  { my($sub,$r_line,$pos,$do_not_replace)= @_;

#warn "before:|" . $sub . "|\n";
#warn "after:|" . mk_perl_varnames($sub,$comment) . "|\n";

    my $subst;

    if (!$do_not_replace)
      { $subst= mk_perl_varnames($sub,$r_line,$pos); 
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
        $err_pre= "in expression \"$subst\":\neval-error:$@";
        fatal_parse_error($r_line,$pos); 
      };
    return($res);
  }

sub rec_eval
  { my($sub,$r_line,$pos)= @_;

    for(my $cnt=0; $cnt<100; $cnt++)
      { 
#warn "rec_eval:\"$sub\"";
        if ($sub!~ /(?<!\\)\$/)
          { return($sub); };
        $sub= eval_part('"' . $sub . '"',$r_line,$pos);
      };

    $err_pre= "recursion error in expression";
    fatal_parse_error($r_line,$pos); 
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

sub is_user_func
  { my($funcname)= @_;
    return(exists $functions{$funcname});
  }

sub eval_func_block
  { my($funcname,$r_line,$start,$end)= @_;

    my $sub= substr($$r_line, $start+1, $end-$start-1);
#warn "evaluate: $sub";

    $sub= $functions{$funcname} . "($sub)";

    my $res= eval_part($sub,$r_line,$start); 

    return($res);
  }

sub eval_bracket_block
  { my($r_line,$start,$end,$ky_flags)= @_;

    my $sub= substr($$r_line, $start+1, $end-$start-1);
#warn "evaluate: $sub";

    if ($ky_flags & KY_FUNCDEF)
      { $sub=~ s/^\s+//;

        my($funcname)= ($sub=~ /^(\w+)/);
        if (!defined $funcname)
          { 
            $err_pre= "func-block is malformed";
            fatal_parse_error($r_line,$start); 
          };
        $sub= "sub m_" . $sub;
        $functions{$funcname}= "m_" . $funcname;
        # hash maps function-name to real-function-name
      }  

    my $res= eval_part($sub,$r_line,$start,!($ky_flags & KY_REPLACE));

    return($res);
  }

sub match
# starts at str[pos], tries to find the end of a bracket-block
# or a string. All special characters may be escaped with a 
# backslash
# returns the position of opening and closing bracket 
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
  { my($r_str,$position,$pline,$message,$do_not_die)= @_; 

    my($line,$column)= find_position_in_string($r_str,$position);

    my $err;
    $err= $gbl_err_pre if ($gbl_err_pre);

    $err.= $do_not_die ? "warning\n" : "fatal error\n";

    $err.= "module: $err_module";
    $err.= " line: $err_line" if (defined $err_line);
    $err.= "\n$err_pre\n" if (defined $err_pre);    
    $err.= "position in file";
    $err.= " $err_file" if (defined $err_file);
    $err.= ": line $line, column $column\n";
    $err.= "\n$err_post\n" if (defined $err_post);
    if ($do_not_die)
      { warn $err; 
        return;
      };     
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

sub simple_match
# match a single variable or array-element or keyword or function
# returns: 
#   <type> 
#   <start of var (pointing at '$' char)>, <end of var>, 
#   <match1=varname>, <match2=possible index>
# (the last character of the variable), name of the var, index-expression
  { my($r_line, $p)= @_;

    pos($$r_line)= $p;

    # form $a (...)
    if ($$r_line=~ /\G(\w+)\s*\(/gs)
      { my $name= $1;
        if (exists $arg_keywords{$name})
          { return(SM_ARGKEYWORD, $p-1, pos($$r_line)-1, $name); };
        if (is_user_func($name))
          { return(SM_FUNC, $p-1, pos($$r_line)-1, $name); };
      }; 

    pos($$r_line)= $p;

    # form $a[...]
    if ($$r_line=~ /\G(\w+)\[([^\]]+)\]/gs)
      { return(SM_SIMPLE_INDEXED, $p-1, pos($$r_line)-1, $1,$2); }; #name, key

    pos($$r_line)= $p;

    # form $a
    # NOTE: this may also be a keyword or a function
    if ($$r_line=~ /\G(\w+)/gs)
      { my $name= $1;
        if (exists $simple_keywords{$name})
          { return(SM_KEYWORD, $p-1, pos($$r_line)-1, $name); };
        return(SM_SIMPLE_SCALAR, $p-1, pos($$r_line)-1, $name); 
      };    #name

    pos($$r_line)= $p;


    # form ${a[..]}
    if ($$r_line=~ /\G\{(\w+)\[([^\]]+)\]\}/gs)
      { return(SM_CURLY_INDEXED, $p-1, pos($$r_line)-1, $1,$2); }; #name, key

    pos($$r_line)= $p;

    # form ${a}
    if ($$r_line=~ /\G\{(\w+)\}/gs)
      { return(SM_CURLY_SCALAR, $p-1, pos($$r_line)-1, $1, undef); };    #name

    pos($$r_line)= $p;


    # form $(a[...])
    if ($$r_line=~ /\G\((\w+)\[([^\]]+)\]\)/gs)
      { return(SM_ROUND_INDEXED, $p-1, pos($$r_line)-1, $1,$2); }; #name, key

    pos($$r_line)= $p;

    # form $(a)
    if ($$r_line=~ /\G\((\w+)\)/gs)
      { return(SM_ROUND_SCALAR, $p-1, pos($$r_line)-1, $1, undef); };    #name

    pos($$r_line)= $p;


#return;  
    # form ${$eval(...)}        
    if ($$r_line=~ /\G\{\$eval\(/gs)
      { my $pi= pos($$r_line)-1; # pos of 1st round bracket
        my($start,$end)= match($r_line,pos($$r_line)-1);

       if (!defined $start)
         { $err_pre= "malformed eval";
           $err_line= __LINE__;
           fatal_parse_error($r_line,$p); 
         };
       pos($$r_line)= $end+1; 

       if ($$r_line!~ /\G\}/gs)
         { $err_pre= "malformed var-block";
           $err_line= __LINE__;
           fatal_parse_error($r_line,$p); 
         };

       my $e= pos($$r_line)-1;

       return(SM_EVAL, $p-1, $e, substr($$r_line,$pi+1,$end-$pi-1), undef);
      };

    pos($$r_line)= $p;
    return(SM_NO);  
  }  

sub variable_expand
  { my($r_line, $p, $in_ignore_part)= @_;

    # match a single variable or array-element or keyword or function
    my($type,$start,$end,$var,$index)= simple_match($r_line, $p);

    if ($type == SM_KEYWORD)
      { return(VE_KEYWORD, $var); }

    if (($type == SM_ARGKEYWORD) || ($type == SM_FUNC))
      { my($m_start,$m_end)= match($r_line,$end);
        if (!defined $m_start)
          { $err_pre= "malformed bracket-block";
            $err_line= __LINE__;
            fatal_parse_error($r_line,$p); 
          }

        # user functions within an ignore-part are:
	#  ignored ;-)
	if (($in_ignore_part) && ($type == SM_FUNC))
	  { pos($$r_line)= $p;
            return(VE_DONE,'$'); 
          }; 

	return(($type == SM_ARGKEYWORD) ? VE_ARGKEYWORD : VE_FUNC, 
               $var, $m_start, $m_end); 
       }

    if ($type == SM_NO)
      { # could not find a variable expression

        pos($$r_line)= $p;
        return(VE_DONE,'$'); 
      }

    if ($type == SM_EVAL) 
      { # SM_EVAL: the name of the variable has to be evalutated,
        # don't do this within an ignore-part
        # (e.g. an if--then block that is to be skipped)
        if (!$in_ignore_part)
          { $var= eval_part($var,$r_line,$start); 
            pos($$r_line)= $end+1;
          };  
#pos($$r_line)= $p;
#return;  
        # this is now the name of the variable

      };

    if (!$allow_round_brackets)
      { if (($type & SM_SUBTYPE)==SM_ROUND_SCALAR)
          { pos($$r_line)= $p;
            return(VE_DONE,'$'); 
          }
      }

    if ($forbid_nobracket_vars)
      { if (($type & SM_SUBTYPE)==SM_SIMPLE_SCALAR)
          { pos($$r_line)= $p;
            return(VE_DONE,'$'); 
          }
      }

    if ($type == SM_SIMPLE_SCALAR)
      { pos($$r_line)= $p;

        if (exists $simple_keywords{$var})
          { return(VE_KEYWORD, $var); }; 
      }   

    # from here it's an variable that is to expand

    if ($in_ignore_part)
      { # do not lookup variables when within an ignore-part
        # (e.g. an if--then block that is to be skipped)
        pos($$r_line)= $p;
        return(VE_DONE,''); 
      }

    if (!($type & SM_INDEXED))
      { # not an array expression

        if (defined $callback)
          { 
            &$callback($var); 
          }
        if (!exists $m{$var})
          { 
#warn "parsed: |$var|";
            $err_pre= "macro \$\{$var\} is not defined";
            $err_line= __LINE__;
            if (!$allow_not_defined_vars)
              { fatal_parse_error($r_line,$p); }; #this does call die()
            fatal_parse_error($r_line,$p,undef,undef,1);
            pos($$r_line)= $end+1;
            # just return the original string
#print "RETURNING:\"",substr($$r_line,$start,$end-$start+1),"\"\n";
#print "SE:$start,$end\n";
            return(VE_DONE, substr($$r_line,$start,$end-$start+1));
          };
        if ($debug)
          { warn "--- expand \$\{$var\} to " . $m{$var} . "\n"; };
        pos($$r_line)= $end+1;
        if (!$recursive)
          { return(VE_DONE,$m{$var}); }
        else
          { # recursive evaluation: evaluate until there is 
	    # no more macro to expand:
	    return(VE_DONE,rec_eval($m{$var},$r_line,$p)); 
	  };
      };

    # from here: it's an index expression
    if ($index=~/\$/)
      { # a "complicated" expression
        $index= eval_part($index, $r_line, $p);
      };


        if (defined $callback)
          { 
            &$callback($var,$index); 
          }

    if (!exists $m{$var})
      { 
        $err_pre= "macro \$\{$var\} is not defined";
        if (!$allow_not_defined_vars)
          { fatal_parse_error($r_line,$p) }; #this does call die()
        fatal_parse_error($r_line,$p,undef,undef,1);
        pos($$r_line)= $end+1;
        # just return the original string
        return(VE_DONE, substr($r_line,$start,$end-$start+1));
      };

    if ($debug)
      { warn "--- expand \$\{$var\[$index\]\} to " . $m{$var}->[$index] . "\n"; };

    pos($$r_line)= $end+1;
    if (!$recursive)
      { return(VE_DONE,$m{$var}->[$index]); }
    else
      { return(VE_DONE,rec_eval($m{$var}->[$index],$r_line,$p)); };
  }


sub mk_perl_varnames
# internal
  { my($line,$r_line,$pos)= @_;

#print "in: |$line|\n"; 
    # replace ${a[..]} with \$m{a}->[..]
    #   Note: ".." must NOT contain ']'
    $line=~ s/(?<!\\)\$\{(\w+)\[([^\]]+)\]\}/\\\$m\{$1\}->\[$2\]/gs;

    #replace @{a} with \@{\$m{a}}
    $line=~ s/(?<!\\)\@\{(\w+)\}/\@\{\\\$m\{$1\}\}/gs;

    # replace ${a} with \$m{a}
    $line=~ s/(?<!\\)\$(\{\w+\})/\\\$m$1/gs;

#warn;    
    #replace $a[..] with \$m{a}->[..]
    #   Note: ".." must NOT contain ']'
    $line=~ s/(?<!\\)\$(\w+)\[([^\]]+)\]/\\\$m\{$1\}->\[$2\]/gs; 

    #replace @a with \@{\$m{a}}
    $line=~ s/(?<!\\)\@(\w+)/\@\{\\\$m\{$1\}\}/gs;

    # replace $a with \$m{a}
    $line=~ s/(?<!\\)\$(\w+)/\\\$m\{$1\}/gs; 

    # replace \$ with $
    $line=~ s/\\\$/\$/gs;

    # replace \@ with @
    $line=~ s/\\\@/\@/gs;

#print "here: |$line|\n";
    if (defined $callback)
      { pos($line)=0;
        # perform callback for all simple variables
	while ($line=~/\G.*?\$m\{(\w+)\}/g) 
          { 
            &$callback($1); 

          };
        pos($line)=0;
        # perform callback for all array variables
        while ($line=~/\G.*?\$m\{(\w+)\}->\[([^\]]+)\]/g) 
          { my $name= $1;
	    my $index= $2;

	    if ($index!~/^\d+/)
	      { # if index is not a simple number but an
	        # expression, try to evaluate it:
	        my $res= eval($index);
		if ((!defined ($res)) && ($@ ne ""))
		  { 
        	    $err_pre= "in expression \"$index\":\neval-error:$@";
        	    fatal_parse_error($r_line,$pos); 
		  };
		$index= $res;
              }
            &$callback($name,$index); 
          };
      };

#print "out: |$line|\n";

    return($line); 
  }

sub strdump
  { my($r_line, $p, $len, $prefix)= @_;

    $len= 20 if (!defined $len);

    my $x= substr($$r_line,$p,$len);
    $x=~ s/\n/\\n/g;
    warn "$prefix DUMP AT POS $p:$x\n";
  }

sub find_file
  { my($file,$r_paths)= @_;

    return($file) if (-r $file);

    return if (!@$r_paths);

    my $test;
    for(my $i=0; $i<= $#$r_paths; $i++)
      { if (!-d $r_paths->[$i]) 
          { warn "warning: path \"$r_paths->[$i]\" is not valid"; 
            next;
          };
        $test= File::Spec->catfile($r_paths->[$i], $file);
	if (-r $test)
	  { # move the path that matched to the front
	    my $e=splice(@$r_paths,$i,1); unshift @$r_paths,$e;
            return($test);
	  };
      };
    return;
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

  parse_scalar($st,%options);

=head1 DESCRIPTION

=head2 Preface

This package provides functions in order to perform macro
substitutions in ascii files. Aside from simple substitution,
the calculation of complex expressions is also possible. 

=head2 Basic concepts

The module provides two parse-functions that take either a 
scalar variable that contains a reference to the text or 
the filename of the file that contains the text to 
parse.

Both functions scan for variables, expressions or keywords in the
text. If one of these is encountered, the text printed is altered. 
Otherwise the input-text is printed unchanged.

=over 4

=item I<Variables>

Variables have the following form:

  ${name}
  ${name[index]}

or

  $name
  $name[index]

The first two lines above show simple variables. A variable
of this type can hold numbers or strings. The third and fourth lines 
show the array form. In this case the variable is an array of values, 
each value can be accessed by an index. The index can be a number or
a perl expression. Note however, that the perl expression MUST not 
contain the closing bracket ']'. 

CAUTION: In opposition to ordinary perl-programs, scalar and array
variables are in the same namespace. You cannot have for example
a variable 
  $var and @var
at the same time !

=item I<expressions>

An expression consists of variables and operators or functions. 
Almost all expressions that are valid in perl can be used. For example
this expression defines and sets a variable

  $myvar=1

This expression does a simple calculation:

  $myvar*2

This expression initializes an array:

  @my_array=("X", "Y", "Z")

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

The given statements are evaluated directly by the 
perl-interpreter. This is a significant difference to
$set or $eval since with these certain replacements are
done in the given expression before it is evaluated.
This can be used to include perl-modules

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

=item I<func>

  $func(myfunc { my($a,$b)= @; return($a+$b); })

This is a definition of a function. It is actually a shortcut for
$perl(myfunc { my($a,$b)= @; return($a+$b); }). The advantage of
this construct is, however, that such a function is evaluated 
without the need to use $eval(). Whenever "$myfunc(..)" is found in
the source, it is evaluated, e.g. "$myfunc(1,2)" would return "3" in
the example above. 

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

=item I<write_to>

  $write_to(<expression>)

This command opens a file with the name of the given expression
and writes expander's output from now on to that file.

=item I<append_to>

  $append_to(<expression>)

This command opens a file with the name of the given expression
in append mode and writes expander's output from now on to that file.

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
up or down. The for-block implicitly contains a $begin statement
so all variable definitions within $for..$endfor are local to
this block. This is also the case for the variable defined and
used in the init-expression, condition and loop-statement.

Here is an example:

  $for($i=0; $i<5; $i++)
    NAME= "Axle$i"
  $endfor

Here is another example with arrays:

  $set(@chars=qw(X Y Z))
  $for($i=0; $i<@a; $i++)
    NAME= "element: $chars[$i]"
  $endfor

=item I<for_noblock>

  $for_noblock(<init expression>;<condition>;<loop statement>)

This command is similar to $for except that it doesn not implicitly
start a new $begin-$end block.

=item I<endfor>

  $endfor

This ends a for-expression. This statement contains also an implicit 
$end which ends restores all variables to the state they had before
the block started. 

=item I<begin>

  $begin

This statement opens a new block. All variable definitions and changes
within a block are reversed when the block ends with $end

=item I<end>

  $end

This statement ends a block. All variable definitions are restored
to the state they had before the block started.  

=item I<export>

  $export($var1,$var2)

This statement can be used within a block (see $begin). It exports
the local variables (given as a comma-separated list) to
the variable-settiing outside the block.  

=item I<list>

  $list(10,",")

Prints a list of all defined variables in the form of key=value 
pairs. The first parameter is the width of the key column, 
the second parameter is the separator string that separates
each key-value pair.

=item I<list_new>

  $list_new(10,",",$var1,$var2)

This command is similar to $list except that it prints only 
variables that have been new defined in the current block
(see $begin and $end). The parameters after the 2nd parameter
are an optional list of variables, which will also be printed
although they were already defined in the previous block. This
is useful, when the current block has re-defined a variable 
that already existed, and this variable shall be printed, too.

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

=item I<leave>

  $leave

This immediately leaves the parse-function producing no more output. 

=item I<debug>

  $debug(<text>)

This statement emits arbitrary text to STDERR. 

=item I<dumphash>

  $dumphash

This dumps the internal hash %m that is used to hold all
defined variables. This is only useful for debugging.

=item I<ifstack>

  $ifstack

This dumps the internal if-stack that is used to
track if-else-endif blocks.
This is only useful for debugging.

=back

=head2 The option hash

parse_scalar and parse_file take an option-hash as optional
second parameter. For this hash the following keys are defined:

=over 4

=item I<errmsg>

  parse_scalar($myvar, errmsg=> "my_message")

In case of a fatal parse error, this message is printed
just before the error message of the module.

=item I<scalarref>

  parse_scalar($myvar, scalarref=>\$result)

If this hash key is provided, the output written (appended) to
the given scalar variable.

=item I<filehandle>

  parse_scalar($myvar, filehandle=>\*MYFILE)

If this hash key is provided, the output is printed to the
given filehandle.

=item I<filename>

  parse_scalar($myvar, filename=>"output.txt")

If this hash key is provided, a file with the given name is 
created and the output is printed to that file. If neither "filehandle"
nor "filename" is given, all ouput is printed to STDOUT.

=item I<callback>

  parse_scalar($myvar, callback=> \&mycallback)

With this option, a user-defined callback function is defined
that is called every time a variable is to be expanded. The callback
function is given the name of the variable and (optional) the 
array-index. If the variable does not yet exist, the callback function
must take care of setting this variable with set_var(), otherwise
a run-time error is raised.

=item I<silent>

  parse_scalar($myvar, silent=> 1)

With this option, the parser can be started in "silent" mode.
See also description of the $silent command.

=item I<includepaths>

  parse_scalar($myvar, includepaths=> [$dir1,$dir2])

With this option, search-paths for the $include() command
can be specified.

=item I<allow_not_defined_vars>

  parse_scalar($myvar, allow_not_defined_vars=> 1)

With this option, variables that are not defined 
just produce a warning and do not terminate the 
program.

=item I<forbit_nobrackets>

  parse_scalar($myvar, forbit_nobrackets=> 1)

With this option, the parser ignores (does not expand) variables
of the form $var or $var[index]. Only the bracketed variants
lile ${var} of (see below) $(var) and their index variants are
allowed.

=item I<roundbrackets>

  parse_scalar($myvar, roundbrackets=> 1)

With this option, the parser allows round brackets for
variables, so $(myvar) is treated like ${myvar}.

=item I<recursive>

  parse_scalar($myvar, recursive=> 1)

Allow recursive variable expansion. Each variable that contains
a non-quoted '$' sign is evaluated again until that condition
is no longer true.

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

=item *

B<declare_func()>

  declare_func($identifier,$funcname)

Declare (make known) a function to the parser. $identifier is the 
name of the function in the parsed text, $funcname is the 
perl-name of the function that is called. The function declared this
way works similar to a function defined with "$func" in the text.

=back

=head1 AUTHOR

Goetz Pfeiffer,  goetzp@gmx.net

=head1 SEE ALSO

perl-documentation

=cut


