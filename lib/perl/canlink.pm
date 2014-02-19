package canlink;

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


# ===========================================================
# note: to quickly see the man-page enter:
# pod2usage -verbose 3 canlink.pm
# ===========================================================

use strict;

BEGIN {

use Exporter   ();
use vars       qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
# set the version for version checking
$VERSION     = 1.0;

@ISA         = qw(Exporter);
@EXPORT      = qw();
%EXPORT_TAGS = ( );     # eg: TAG => [ qw!name1 name2! ],

# your exported package globals go here,
# as well as any optionally exported functions

@EXPORT_OK   = qw( &interview &explain &pretty_print
                   &encode &decode &complete &calc_cob
                   &calc_cidnidsob
                   &cob2cidnid &cidnid2cob &cob2sobnid &sobnid2cob
                 );


use vars qw (%char_list %type_list
             %inv_char_list %inv_type_list %explantions);

# ----------------------------------------------------------------
# Specificaion of the CAN link:

%char_list= ( 'a' => { server=>0, multi=>0,  access=>'r'  },
              'b' => { server=>0, multi=>0,  access=>'w'  },
              'c' => { server=>0, multi=>0,  access=>'rw' },
              'd' => { server=>0, multi=>1,  access=>'r'  },
              'e' => { server=>0, multi=>1,  access=>'w'  },
              'f' => { server=>0, multi=>1,  access=>'rw' },
              'g' => { server=>1, multi=>0,  access=>'r'  },
              'h' => { server=>1, multi=>0,  access=>'w'  },
              'i' => { server=>1, multi=>0,  access=>'rw' },
              'j' => { server=>1, multi=>1,  access=>'r'  },
              'k' => { server=>1, multi=>1,  access=>'w'  },
              'l' => { server=>1, multi=>1,  access=>'rw' },
            );


%type_list= ( 'a' => { type => 'string', raw=> 0, signed=> 0, array=> 0 },
              'b' => { type => 'string', raw=> 1, signed=> 0, array=> 0 },

              's' => { type => 'short',  raw=> 0, signed=> 1, array=> 0 },
              'S' => { type => 'short',  raw=> 0, signed=> 0, array=> 0 },
              't' => { type => 'short',  raw=> 0, signed=> 1, array=> 1 },
              'T' => { type => 'short',  raw=> 0, signed=> 0, array=> 1 },
              'u' => { type => 'short',  raw=> 1, signed=> 1, array=> 0 },
              'U' => { type => 'short',  raw=> 1, signed=> 0, array=> 0 },
              'v' => { type => 'short',  raw=> 1, signed=> 1, array=> 1 },
              'V' => { type => 'short',  raw=> 1, signed=> 0, array=> 1 },

              'l' => { type => 'long',   raw=> 0, signed=> 1, array=> 0 },
              'L' => { type => 'long',   raw=> 0, signed=> 0, array=> 0 },
              'm' => { type => 'long',   raw=> 0, signed=> 1, array=> 1 },
              'M' => { type => 'long',   raw=> 0, signed=> 0, array=> 1 },
              'n' => { type => 'long',   raw=> 1, signed=> 1, array=> 0 },
              'N' => { type => 'long',   raw=> 1, signed=> 0, array=> 0 },
              'o' => { type => 'long',   raw=> 1, signed=> 1, array=> 1 },
              'O' => { type => 'long',   raw=> 1, signed=> 0, array=> 1 },
              'c' => { type => 'char',   raw=> 0, signed=> 1, array=> 0 },
              'C' => { type => 'char',   raw=> 0, signed=> 0, array=> 0 },
              'd' => { type => 'char',   raw=> 0, signed=> 1, array=> 1 },
              'D' => { type => 'char',   raw=> 0, signed=> 0, array=> 1 },

              'e' => { type => 'mid' ,   raw=> 0, signed=> 1, array=> 0 },
              'E' => { type => 'mid' ,   raw=> 0, signed=> 0, array=> 0 },
              'f' => { type => 'mid' ,   raw=> 0, signed=> 1, array=> 1 },
              'F' => { type => 'mid' ,   raw=> 0, signed=> 0, array=> 1 },

              'g' => { type => 'mid' ,   raw=> 1, signed=> 1, array=> 0 },
              'G' => { type => 'mid' ,   raw=> 1, signed=> 0, array=> 0 },
              'h' => { type => 'mid' ,   raw=> 1, signed=> 1, array=> 1 },
              'H' => { type => 'mid' ,   raw=> 1, signed=> 0, array=> 1 },

	      'Z' => { type => 'zero',   raw=> 0, signed=> 0, array=> 0 },

            );


%explantions=
  ( server =>
            "This field specifies wether the host is a CAN server\n" .
            "(server==1) or not (server==0)\n",
    multi =>
            "This field specifies wether the CAN variable is of the \n" .
            "multiplex type (multi==1) or not (multi==0)\n",
    access =>
            "This field specifies the access type of the CAN variable\n" .
            "known access types are:\n" .
            "read-only   (access==\'r\')\n" .
            "write-only  (access==\'w\')\n" .
            "read-write  (access==\'rw\')\n",


    type => "the basic data type of the CAL variable. Known types are:\n" .
            "zero, string, char, short, mid, long. Note that \"mid\" is a \n" .
            "24-bit integer and \"zero\" is a datatype with a length\n" .
	    "of 0 bytes\n",

    raw  => "This field defines wether the data is processed before\n" .
            "it is sent to the CAN bus. For numbers (all non-strings)\n" .
            "it defines wether the numbers are converted to the \n" .
            "little-endian byte order (raw==0) or wether they are left\n" .
            "alone (raw==1)\n",
    signed =>
            "This field has only a meaning for non-string types. It \n" .
            "defines wether the number is signed (signed==1) or \n" .
            "unsigned (singed==0)\n",
    array =>
            "This field defines wether more than one varable of the\n" .
            "basic data type (type) is packed into one CAN bus frame\n" .
            "(array==1) or not (array==0)\n",

    maxlength =>
            "This is the actual length of the CAN object in bytes. \n" .
            "For non-array non-multiplex variables it equals the size\n" .
            "of the basic data-type (type).\n",
    port => "This is the port-number for which the CAN objects are defined\n",

    out_cob =>
            "This is the COB (can-object ID) for the outgoing (write-)\n" .
            "can-object.\n",
    in_cob =>
            "This is the COB (can-object ID) for the incoming (read-)\n" .
            "can-object.\n",
    multiplexor =>
            "This is the multiplexor-number. It has only a meaning for\n" .
            "CAN multiplex variables (multi==1)\n",
    inhibit =>
            "This is the inhibit time given in milliseconds. Note that \n" .
            "This parameter is a floating point number.\n",
    timeout =>
            "This is the timeout-time for the CAN objects, given in\n" .
            "milliseconds. Note that this parameter is an integer\n",
    arraysize =>
            "For arrays (array==1) this gives the number of elements of\n" .
            "the array.\n",
    nid =>  "This is the node-id of the server. Note that this parameter\n" .
            "is optional\n",
    cid =>  "This is the connection-id of the CAN variable. Note that\n" .
            " this parameter is optional\n",
    in_sob =>
            "This is the sub-object id of the incoming CAN object. Note\n" .
            "that this parameter is optional\n",
    out_sob =>
            "This is the sub-object id of the outgoing CAN object. Note\n" .
            "that this parameter is optional\n"
  );

%inv_char_list= invert_hash(\%char_list);
%inv_type_list= invert_hash(\%type_list);

# Specificaion of the CAN link ends here
# ----------------------------------------------------------------


sub key_from_hash_val
# needed for package initialization:
  { my($r_p)= @_;
    my $st;

    foreach my $key (sort keys %$r_p)
      { $st.= ":" if (defined $st);
        $st.= $r_p->{$key};
      };
    return($st);
  };

sub key_from_hash_val_list
# needed for package initialization:
  { my($r_p,@list)= @_;
    my $st;

    foreach my $key (sort @list)
      { $st.= ":" if (defined $st);
        $st.= $r_p->{$key};
      };
    return($st);
  };


sub invert_hash
# needed for package initialization:
  { my($r_p)= @_;
    my %new;

    foreach my $key (%$r_p)
      {
        $new{ key_from_hash_val( $r_p->{$key} ) }= $key;
      };
    return(%new);
  };


}; # of BEGIN


use vars      @EXPORT_OK;

# used modules

# non-exported package globals go here

sub interview
  { my %p;
    my $sel;

    if (1==question( 'client', 'server' ))
      { $p{server}=1; };

    $sel= question( 'read-only', 'write-only', 'read-write' );
    if    ($sel==0)
      { $p{access}= 'r'; }
    elsif ($sel==1)
      { $p{access}= 'w'; }
    else
      { $p{access}= 'rw'; };

    if (1==question( ('basic variable', 'multiplex variable') ))
      { $p{multi}=1; };


    $sel= question( qw(string char short mid long zero) );
    if    ($sel==0)
      { $p{type}= 'string'; }
    elsif ($sel==1)
      { $p{type}= 'char'; }
    elsif ($sel==2)
      { $p{type}= 'short'; }
    elsif ($sel==3)
      { $p{type}= 'mid'; }
    elsif ($sel==4)
      { $p{type}= 'long'; }
    else
      { $p{type}= 'zero'; };

    if ( $p{type} ne 'string')
      { if (0==question( 'signed', 'unsigned' ))
          { $p{signed}= 1; };

        if (1==question( 'simple', 'array' ))
          { $p{array}= 1;
            $p{arraysize}= num_question(1,8,1,
                                       "please enter the array-size:");

          };

      };

    if ($p{type} eq 'char')
      { # char is always "not raw" !!
        $p{raw}= 0;
      }
    else
      { if (1==question( 'not raw', 'raw' ))
          { $p{raw}= 1; }
      };

    $p{port}   = num_question(0,255,1,"please enter the port number:");

    $sel=question( 'specify in-cob,out-cob',
                    'specify sob, nid',
                    'specify cid, nid');

    my($r_needed,$w_needed)= (1,1);

    if (!$p{multi})
      { if    ($p{access} eq 'r')
          { 
	    if (!$p{server})
	      { $w_needed=0; } # outgoing cob is not needed
	    else
	      { $r_needed=0; } # incoming cob is not needed
	  }
        elsif ($p{access} eq 'w')
          { if (!$p{server})
	      { $r_needed=0; } # incoming cob is not needed
	    else  
	      { $w_needed=0; } # outgoing cob is not needed
	  } 
      }
    else
      { if    ($p{access} eq 'w')
          { if (!$p{server})
	      { $r_needed=0; } # incoming cob is not needed 
            else
	      { $w_needed=0; } # outgoing cob is not needed 
	  } 
      };

    if   ($sel==0)
      { if (!$w_needed)
          { $p{out_cob}= 0; }
        else
          { $p{out_cob}= num_question(0,2047,1,
                                      "please enter the cob of the " .
                                      "outgoing can object:");
          };

        if (!$r_needed)
          { $p{in_cob}= 0; }
        else
          { $p{in_cob} = num_question(0,2047,1,
                                      "please enter the cob of the " .
                                      "incoming can object:");
          };
      }
    elsif ($sel==1)
      { $p{nid}     = num_question(1,63,1,
                                  "please enter the server node-id:");
        if (!$r_needed)
          { $p{in_sob}= 0; }
        else
          { $p{in_sob}  = num_question(0,26,1,
                                      "please enter the in-sob:");
          };
        if (!$w_needed)
          { $p{out_sob}= 0; }
        else
          { $p{out_sob} = num_question(0,26,1,
                                      "please enter the out-sob:");
          }
      }
    else
      { $p{nid}     = num_question(1,63,1,
                                  "please enter the server node-id:");
        $p{cid}     = num_question(0,12,1,
                                  "please enter the channel-id:");
      };


    if ($p{multi})
      { $p{multiplexor} = num_question(0,127,1,
                                      "please enter the multiplexor:"); };

    $p{inhibit} = num_question(0,20000,0,
                               "please enter the inhibit-time in [ms]:");
    $p{timeout} = num_question(1,32767,1,
                               "please enter the timeout-time in [ms]:");


    return(complete(%p));
  }



sub question
# internal
  { my(@options)= @_;
    my $r;
    my $max= $#options +1;

    print "please select one:\n";
    for(my $i=1; $i<= $max; $i++)
      { printf("%2d) %s\n", $i,$options[$i-1]); };
    for(;;)
      { $r= <STDIN>; chomp($r);
        if ($r!~ /^\s*\d+\s*$/)
          { print "please enter an integer!\n"; next; };
        if (($r<1) || ($r>$max))
          { print "please enter an integer between 1 and $max!\n"; next; };
        last;
      };
    return($r-1);
  }

sub num_question
# internal
  { my($min,$max,$is_int,$question)= @_;
    my($r);

    print $question;
    for(;;)
      { $r= <STDIN>; chomp($r);
        if ($is_int)
          { if ($r!~ /^\s*\d+\s*$/)
              { print "please enter an integer!\n"; next; };
          }
        else
          { if ($r!~ /^\s*[+-]?\d+\.?\d*\s*/)
              { print "please enter an integer or a floating point number!\n";
                next;
              };
          };
        if (($r<$min) || ($r>$max))
          { print "please enter number between $min and $max\n"; next; };
        last;
      };
    return($r);
  }


sub explain
  { my(%p)= @_;
    my @keys;

    my $st;

    if (!%p)
      { @keys= sort keys %explantions; }
    else
      { @keys= sort keys %p; };

    foreach my $key (@keys)
      { $st.= "$key:\n" . $explantions{$key} ."\n" };
    return($st);
  }

sub pretty_print
  { my(%p)= @_;
    my $st;
    my $val;

    $st= "variable-type: ";

    if ($p{server})
      { $st.= "server "; }
    else
      { $st.= "client "; };

    if ($p{multi})
      { $st.= "multiplex "; }
    else
      { $st.= "basic "; };

    if    ($p{access} eq 'r')
      { $st.= "read-only "; }
    elsif ($p{access} eq 'w')
      { $st.= "write-only "; }
    else
      { $st.= "read-write "; }

    $st.= "\ndata-type    : ";

    if ($p{array})
      { $st.= "array of "; };

    if ($p{raw})
      { $st.= "raw "; };

    if ($p{type} eq 'string')
      { $st.= "string "; }
    else
      { if ($p{signed})
          { $st.= "signed "; }
        else
          { $st.= "unsigned "; };
        $st.= "$p{type} ";
      };
    $st=~ s/\s+$//;

    $st.= sprintf("\nlength       : %4d bytes", $p{maxlength} );
    $st.= sprintf("\nport         : %4d", $p{port} );
    $st.= sprintf("\nout-cob      : %4d", $p{out_cob} );
    $st.= sprintf("\nin-cob       : %4d", $p{in_cob} );

    if (exists $p{nid})
      { $st.= sprintf("\nnode-id      : %4d", $p{nid} ); };
    if (exists $p{cid})
      { $st.= sprintf("\nchannel-id   : %4d", $p{cid} ); };
    if (exists $p{in_sob})
      { $st.= sprintf("\nin-sob       : %4d", $p{in_sob} ); };
    if (exists $p{out_sob})
      { $st.= sprintf("\nout-sob      : %4d", $p{out_sob} ); };


    if ($p{multi})
      { $st.= sprintf("\nmultiplexor  : %4d", $p{multiplexor} );
      };
    $st.= sprintf("\ninhibit      : %6.1f [ms]", $p{inhibit} );
    $st.= sprintf("\ntimeout      : %4d   [ms]", $p{timeout} );
    if ($p{array})
      {
        $st.= sprintf("\narraysize    : %4d elements", $p{arraysize} );
      };
    $st.= "\n";
    return($st);
  }

sub tab_print
  { my(%p)= @_;

    if (!@_)
      { my $st= sprintf "%-7s %3s %2s %-4s %s %-6s %3s %3s %4s %4s %4s %6s %4s %3s",
               "srv/cln",
	       "mul",
	       "rw",
	       "arr",
	       "s",
	       "type",
	       "len",
	       "prt",
	       "in",
	       "out",
	       "mplx",
	       "inh",
	       "tmo",
	       "asz";
        return($st);
      };

    my $st= sprintf "%-7s %3s %2s %-4s %s %-6s %3d %3d %4d %4d %4d %6.1f %4d %3d",
               $p{server} ? "server" : "client",
	       $p{multi}  ? "mlt" : "bas",
               ($p{access} eq 'r') ? "r" :
	           ( ($p{access} eq 'w') ? "w" : "rw" ),
	       $p{array} ? "arr" : "sing",   
	       $p{signed} ? "s" : "u",
	       $p{type},
	       $p{maxlength}, 
	       $p{port},
	       $p{in_cob},
	       $p{out_cob},
	       $p{multi} ? $p{multiplexor} : -1,
	       $p{inhibit},
	       $p{timeout},
	       $p{arraysize};
    return($st);
  }	       




sub encode
  { my(%p)= @_;

    my @cl= qw(server multi access);
    my @tl= qw(type raw signed array);

    my $st;
    my $ch;

    %p= complete(%p);

    $st= '@';

    $ch= $inv_char_list{ key_from_hash_val_list(\%p,@cl) };
    die "encode(): internal error |$ch|!\n" if (!defined $ch);

    $st.= "$ch ";

    $ch= $inv_type_list{ key_from_hash_val_list(\%p,@tl) };
    die "encode(): internal error |$ch|!\n" if (!defined $ch);

    $st.= $ch;

    $st.= sprintf(" %x", $p{maxlength});
    $st.= sprintf(" %x", $p{port});
    $st.= sprintf(" %x", $p{out_cob});
    $st.= sprintf(" %x", $p{in_cob});
    $st.= sprintf(" %x", $p{multiplexor});
    $st.= sprintf(" %x", int($p{inhibit}*10) );
    $st.= sprintf(" %x", $p{timeout});
    $st.= sprintf(" %x", $p{arraysize});
    return($st);
  }


sub decode
  { my($str)= @_;
    my %result;

    $str=~ s/^\s+//; $str=~ s/\s+$//;

    my(@f)= split(/\s+/,$str);

    if ($#f!=9)
      { warn "decode(): unknown can link format (element no) " .
             "\"$str\"\n"; 
	return; 
      };

    if ($f[0] !~ /^\@\w$/)
      { warn "decode(): unknown can link format (at-sign not found) " .
             "\"$str\"\n"; 
	return; 
      };

    my $ch= substr($f[0],1,1);

    if (!exists $char_list{$ch})
      { warn "decode(): unknown variable-type char $ch in this link: " .
             "\"$str\"\n"; 
        return; 
      };

    my %result = %{$char_list{$ch}};

    if (!exists $type_list{$f[1]})
      { warn "decode(): unknown data-type char: $f[1] in this link: " .
             "\"$str\"\n"; 
        return; 
      };

    my $r_datatype= $type_list{$f[1]};


    %result= (%{$char_list{$ch}}, %{$type_list{$f[1]}});

    for(my $i=2; $i<= 9; $i++)
      { if ($f[$i] !~ /^[0-9a-fA-F]+/)
          { warn "decode(): error in field no $i, not a hex-number, link: " .
                 "\"$str\"\n"; 
            return;
          };
      };

    $result{maxlength}   = hex($f[2]);
    $result{port}        = hex($f[3]);
    $result{out_cob}     = hex($f[4]);
    $result{in_cob}      = hex($f[5]);
    $result{multiplexor} = hex($f[6]);
    $result{inhibit}     = hex($f[7]) * 0.1; # unit: [ms]
    $result{timeout}     = hex($f[8]);       # unit: [ms]
    $result{arraysize}   = hex($f[9]);

    calc_cidnidsob(\%result);

    return(%result);
  }


sub complete
# complete the properties-hash if some properties are missing
# returns undef in case of an error
  { my (%p)= @_;

    check_set(\%p,'server',0);
    check_set(\%p,'multi',0);

    return if (!check_exists(\%p,'access','access type','complete()'));
    if ($p{access} !~ /^(r|w|rw)$/)
      { warn "complete(): unknown access type!\n";
        return;
      };

    return if (!check_exists(\%p,'type','data type','complete()'));

    if ($p{type} !~ /^(string|short|long|char|mid|zero)$/)
      { warn "complete(): unknown data type!\n";
        return;
      };

    check_set(\%p,'raw',0);

    if (($p{type} eq 'char') && ($p{raw}))
      { warn "complete(): error \"char\" and \"raw\" now allowed\n";
        return;
      };

    check_set(\%p,'signed',0);
    check_set(\%p,'array',0);

    return if (!check_exists(\%p,'port'   ,'port','complete()'));

    calc_cob(\%p);
    calc_cidnidsob(\%p);

    my($needs_r,$needs_w)= calc_rw_needs(\%p);

    if ($needs_r)
      { return if (!check_exists(\%p,'in_cob' ,'in-cob','complete()')); };
    if ($needs_w)
      { return if (!check_exists(\%p,'out_cob','out-cob','complete()')); };


    if ($p{multi})
      { return if (!check_exists(\%p,'multiplexor','multiplexor','complete()')); }
    else
      { check_set(\%p,'multiplexor',0); };


    my $l= maxlen(\%p);

    if (exists $p{maxlength})
      { if ($p{maxlength}<$l)
          { warn "complete(): maxlength is too small\n";
            return;
          };
      }
    else
      { $p{maxlength}= $l;
      };
    return(%p);
  }


sub calc_cob
# calculates in_cob and out_cob from nid and cid or nid and in_sob and out_sob
  { my ($r_p)= @_;

    my($needs_r,$needs_w)= calc_rw_needs($r_p);
    my $calc_r;
    my $calc_w;

    if ($needs_r)
      { if (!exists $r_p->{in_cob})
          { $calc_r=1; };
      };
    if ($needs_w)
      { if (!exists $r_p->{out_cob})
          { $calc_w=1; };
      };

    return unless ($calc_r || $calc_w);

    return if (!check_exists($r_p,'nid' ,'nid','calc_cob()'));

    if (exists $r_p->{cid})
      { my $c1= cidnid2cob( $r_p->{cid}, 0, $r_p->{nid} ); # writeobj on srvr
        my $c2= cidnid2cob( $r_p->{cid}, 1, $r_p->{nid} ); # readobj on srvr

        if ($r_p->{server})
          { $r_p->{in_cob}  = $c2 if ($calc_r);
            $r_p->{out_cob} = $c1 if ($calc_w);
          }
        else
          { $r_p->{in_cob}  = $c1 if ($calc_r);
            $r_p->{out_cob} = $c2 if ($calc_w);
          };
      }
    else
      { if ($calc_r)
          { return if (!check_exists($r_p,'in_sob' ,'in_sob','calc_cob()'));
            $r_p->{in_cob} = sobnid2cob( $r_p->{in_sob} , $r_p->{nid} );
          };

        if ($calc_w)
          { return if (!check_exists($r_p,'out_sob' ,'out_sob','calc_cob()'));
            $r_p->{out_cob}= sobnid2cob( $r_p->{out_sob}, $r_p->{nid} );
          };

#       if (!$r_p->{multi}) # special treatment for basic-variables
#         { if    ($r_p->{access} eq 'r')
#             { # outgoing cob is not needed
#               if (!exists $r_p->{out_cob})
#                 { $r_p->{out_cob}=0; };
#             }
#           elsif ($r_p->{access} eq 'w')
#             { # incoming cob is not needed
#               if (!exists $r_p->{in_cob})
#                 { $r_p->{in_cob}=0; };
#             };
#         };

      };
  }

sub calc_cidnidsob
# tries to calculate cid,nid or cid,in_sob,out_sob from in_cob and out_cob
  { my ($r_p)= @_;
    my $me= 'calc_cidnidsob()';

    my($needs_r,$needs_w)= calc_rw_needs($r_p);

    if ($needs_r)
      { return if (!check_exists($r_p,'in_cob' ,'in_cob' , $me)); };
    if ($needs_w)
      { return if (!check_exists($r_p,'out_cob','out_cob', $me)); };

    return if ((exists $r_p->{cid}) && (exists $r_p->{nid}));

    if (exists $r_p->{nid})
      { if (($needs_r && exists $r_p->{in_sob}) &&
            ($needs_w && exists $r_p->{out_sob}))
          { return; };
      };

    my($cid1,$d1,$nid1);
    my($cid2,$d2,$nid2);

    ($cid1,$d1,$nid1)= cob2cidnid( $r_p->{in_cob} )  if ($needs_r);
    ($cid2,$d2,$nid2)= cob2cidnid( $r_p->{out_cob} ) if ($needs_w);

    my $set_cid;
    my $set_nid;
    my $is_server= $r_p->{server};

    if ($needs_r && $needs_w)
      { if (($cid1==$cid2) && ($nid1==$nid2))
          { $set_cid=$cid1; $set_nid=$nid1; };
      };

    if ($needs_r) # so $d1 is defined, $is_server==$d1 demanded
      { if ($is_server == $d1)
          { $set_cid=$cid1; $set_nid=$nid1; };
      };
    if ($needs_w) # so $d2 is defined, $is_server!=$d2 demanded
      { if ($is_server != $d2)
          { $set_cid=$cid2; $set_nid=$nid2; };
      };

    if (defined $set_cid)
      { $r_p->{cid}= $set_cid; };
    if (defined $set_nid)
      { $r_p->{nid}= $set_nid; };

    my($sob_in ,$nid_in);
    my($sob_out,$nid_out);

    ($sob_in ,$nid_in) = cob2sobnid( $r_p->{in_cob} )  if ($needs_r);
    ($sob_out,$nid_out)= cob2sobnid( $r_p->{out_cob} ) if ($needs_w);

    if ($needs_r && $needs_w && ($nid_in!=$nid_out))
      { # warn "$me: contradicting NID's were calculated\n";
        return;
      }; # nid_in!=nid_out is an error!

    $r_p->{nid}    = $nid_in;
    if ($needs_r)
      { $r_p->{in_sob} = $sob_in;
        $r_p->{nid}    = $nid_in;
      };
    if ($needs_w)
      { $r_p->{out_sob}= $sob_out;
        $r_p->{nid}    = $nid_out;
      };
  }


sub cob2cidnid
  { my($cob)= @_;
# bit 0-5: nid
# 6: direction : 1 for read-objects on server
# 7-10 cid

    if (($cob<0) || ($cob>2047))
      { warn "cob2cidnid(): cob is invalid: $cob\n"; return; };

    my $nid= $cob & 0x3F;
    my $d  = ($cob & 0x40) ? 1 : 0;
    my $cid= $cob >> 7;

    return($cid,$d,$nid);
  }

sub cidnid2cob
  { my($cid,$d,$nid)= @_;

    if (($cid<0) || ($cid>12))
      { warn "cidnid2cob(): cid out of range: $cid\n"; return; };
    if (($d!=0) && ($d!=1))
      { warn "cidnid2cob(): dd out of range: $d\n"; return; };
    if (($nid<1) || ($nid>63))
      { warn "cidnid2cob(): nid out of range: $nid\n"; return; };

    return( ($cid << 7) | ($d << 6) | $nid );
  }

sub cob2sobnid
  { my($cob)= @_;
# bit 0-5: nid
# 6-10 sob

    if (($cob<0) || ($cob>2047))
      { warn "cob2sobnid(): cob is invalid: $cob\n"; return; };

    my $nid= $cob & 0x3F;
    my $sob= $cob >> 6;

    return($sob,$nid);
  }

sub sobnid2cob
  { my($sob,$nid)= @_;

    if (($sob<0) || ($sob>26))
      { warn "sobnid2cob(): sob out of range: $sob\n"; return; };
    if (($nid<1) || ($nid>63))
      { warn "cidnid2cob(): nid out of range: $nid\n"; return; };
    return( ($sob << 6) | $nid );
  }

sub maxlen
#internal
  { my($r_properties)= @_;
    my $l;

    my $type= $r_properties->{type};

    if    ($type eq 'char')
      { $l=1; }
    elsif  ($type eq 'short')
      { $l=2; }
    elsif  ($type eq 'mid')
      { $l=3; }
    elsif  ($type eq 'long')
      { $l=4; }
    elsif  ($type eq 'zero')
      { $l=0; }
    else
      { return; };

    if ($r_properties->{array})
      { $l*= $r_properties->{arraysize}; };

    if ($r_properties->{multi} or $r_properties->{access} eq 'rw')
      { $l++ };

    return($l);
  }

sub calc_rw_needs
  { my ($r_p)= @_;
    my $access= $r_p->{access};
    my $needs_r=0;
    my $needs_w=0;

    if ($r_p->{multi})
      { if ($access eq 'w')
          { if ($r_p->{server})
              { $needs_r=1; }
            else
              { $needs_w=1; };
          }
        else
          { $needs_r=1; $needs_w=1; };
      }
    elsif ($access eq 'rw')
      { $needs_r=1; $needs_w=1; }
    elsif ($access eq 'w')
      { if ($r_p->{server})
          { $needs_r=1; }
        else
          { $needs_w=1; };
      }
    elsif ($access eq 'r')
      { if ($r_p->{server})
          { $needs_w=1; }
        else
          { $needs_r=1; };
      };
    return($needs_r,$needs_w);
  }

sub check_set
# internal
  { my($r_p,$key,$val)= @_;

    if (!exists $r_p->{$key})
      { $r_p->{$key}= $val; };
  }

sub check_exists
# internal
  { my($r_p,$key,$name,$func)= @_;

    if (!exists $r_p->{$key})
      { warn "$func: $name is not specified!\n";
        return;
      };
    return 1;
  }


1;

__END__
# Below is the short of documentation of the module.

=head1 NAME

canlink - a Perl module for the encoding and decoding of the
MultiCAN Cryptic CAN Link definition.

=head1 SYNOPSIS

  use canlink;

=head1 DESCRIPTION

=head2 Preface

This module contains functions that are used to decode and encode
the EPICS hardware link definition that is used in MultiCAN. The EPICS
device and driver support for the CAN bus that was developed for the
HZB II control system.
Note that HZB has the copyright on this software. It may not be used
or copied without permission from HZB.

=head2 Implemented Functions:

=over 4

=item *

B<interview>

  %link_definition= canlink::interview()

This functions creates a CAN link definition by asking the user
several questions. Note that this function is interactive and
uses simple terminal I/O.

=item *

B<explain>

  print canlink::explain(%link_definition)

This function returns a string that contains a short explanation on
each hash key that is used in %link_definition. When called with no
parameter, is returns an explanation on each hash-key known in this
module.

=item *

B<pretty_print>

  print canlink::pretty_print(%link_definition)

This function returns a string that can be used to print the contents
of the link-definition in a human-readable form.

=item *

B<tab_print>

  print canlink::tab_print(%link_definition)

This function is similar to pretty_print. It returns a string that 
can be used to print the contents of the link-definition 
in a human-readable form, but in a single line. So this function can be used
to print tables. If called without any parameter, it returns the 
table-heading. Note that strings returned by tab_print are NOT terminated
with a linefeed ("\n").

=item *

B<encode>

  $link_string= canlink::encode(%link_definition)

This function returns the string that is used in the MultiCAN implementation
in the hardware-link field.

=item *

B<decode>

  %link_definition= canlink::decode($link_string)

This function takes the string that is used in the MultiCAN implementation
in the hardware-link field as parameter and returns the link-definition
in form of a hash.

=item *

B<complete>

  %completed_link_definition= canlink::complete(%link_definition)

This function completes the link-definition by adding default-values
for some missing hash-keys. E.g. if the "signed" field is missing, the
default, signed==0 which means "unsigned" is added. It also calculates
node-id and connection-id (nid,cid) or node-id and sub-object-ids (SOBs)
from the given can-object-ids (COBs).

=item *

B<calc_cob>

  %completed_link_definition= canlink::calc_cob(%link_definition)

This function completes the link-definition by calculating the
can-object-ids (COBs) from the given node-id and connection-id
(nid,cid) or node-id and sub-object-ids (SOBs).

=item *

B<calc_cidnidsob>

  %completed_link_definition= canlink::calc_cidnidsob(%link_definition)

This function completes the link-definition by calculating the
node-id and connection-id (nid,cid) or node-id and sub-object-ids (SOBs)
from the given can-object-ids (COBs)

=item *

B<cob2cidnid>

  ($cid,$d,$nid)= canlink::cob2cidnid($cob)

This function calculates the connection-id, direction-flag and node-id,
(cid,d,cid) from the given can-object-id (COB)

=item *

B<cidnid2cob>

  $cob= canlink::cidnid2cob($cid,$d,$nid)

This function calculates the can-object-id (COB) from the given
connection-id, direction-flag and node-id  (cid,d,cid)

=item *

B<cob2sobnid>

  ($sob,$nid)= canlink::cob2sobnid($cob)

This function calculates the sub-object-id and node-id
(sob,nid) from the given can-object-id (COB)

=item *

B<sobnid2cob>

  $cob= canlink::sobnid2cob($sob,$nid)

This function calculates the can-object-id (COB) from the given
sub-object-id and node-id

=back

=head2 the property hash

The property-hash may have the following contents:

=over 4

=item B<server>

This field specifies wether the host is a CAL server or a CAL server. Set
this field to "1" for a server, and "0" for a client.

=item B<multi>

This field specifies the multiplex-type. Set this field "1" \
for a multiplex-variable, and "0" for a basic-variable.

=item B<access>

This field specifies the accessability of the CAL variable. Set is to
"r" for a read-only variable, to "w" for a write-only variable and
to "rw" for a read-write variable.

=item B<type>

This specifies the basic data-type of the CAL variable. Known types
are "zero", "string", "char", "short", "mid" and "long". "mid" is a
special, 24-bit integer, "zero" is a datatyoe with a length of 
0 bytes.

=item B<raw>

This field specifies, whether the CAL byte-order is used (little-endian
format) or wether the byte-order is left as it is. Set "0" to enforce CAL
byte-order, and "1" for current byte order.

=item B<signed>

This field is only used, when the C<type> is not "string". Set it to
"1" if the basic type (see C<type>) is signed, or "0" if it is
unsigned.

=item B<array>

This field defines, wether a CAL array-variable is used. In this
case, several elements of the basic type (see C<type>) are packed
into a single CAN frame. But note, that a CAN frame has a maximum
length of 8 bytes. Set to "1" for array-variables or "0" else.

=item B<maxlength>

This is the actual length of the CAN frame in bytes.

=item B<port>

This is the number of the output-port (see sci - documentation for
details).

=item B<out_cob>

This is the COB for the outgoing CAN-object.

=item B<in_cob>

This is the COB for the incoming CAN-object.

=item B<multiplexor>

This is the multiplexor-index. It is only needed for multiplex variables
(see C<multi>).

=item B<inhibit>

This is the inhibit-time in milliseconds. Note that this is a floating-point
number.

=item B<timeout>

This is the timeout in milliseconds. This parameter is an integer.

=item B<arraysize>

This is the size (that means number of elements) of the CAL array. This
field is only needed, if the CAL variable is an array (see C<array>).

=item B<nid>

This is the node-id of the CAL-server.

=item B<cid>

This is the channel-id of the CAL variable.

=item B<in_sob>

This is the sub-object id of the incoming CAN object.

=item B<out_sob>

This is the sub-object id of the outgoing CAN object.

=back

=head2 specification of a CAL variable via the property hash

In order to define a CAL variable by using the property hash,
the following fields are always mandatory:

=over 4

=item B<access>

=item B<type>

=item B<port>

=item B<inhibit>

=item B<timeout>

=back

Here is a list of fields that can be used, but have a default, when
they are not specified:

=over 4

=item B<server>

default: 0

=item B<multi>

default: 0

=item B<multiplexor>

mandatory when C<multi> is "1"

=item B<signed>

default: 0

=item B<array>

default: 0

=item B<arraysize>

mandatory when C<array> is "1"

=item B<raw>

default:0
mandatory when C<type> is neither "string" nor "char"

=back

Specifying the COB's that are actually used, is a bit complicated. There
are 3 ways:

=over 4

=item 1.

Specify the COB's directly. In this case, the fields C<in_cob> and
C<out_cob> must be specified.

=item 2.

Specify NID and IN-SOB and OUT-SOB. In this case, the node-id of the
server, C<nid>, the IN-SOB, C<in_sob> and the OUT-SOB, C<out_sob>
must be specified.

=item 3.

Specify NID and CID, in this case, define C<nid> and C<cid>

=back

=head1 EXAMPLES

=head2 format a user-defined can-link:

  use canlink;

  print "please specify a can link:";
  my %link= canlink::interview();
  print canlink::encode(%link),"\n";

=head2 decode and pretty-print a given MultiCAN link-string

  use canlink;

  print "please enter a can link string:";
  my $str= <STDIN>;
  my %link= canlink::decode($str);
  die if (!%link);
  print canlink::pretty_print(%link),"\n";

=head2 explain all known hash-fields

  use canlink;

  print canlink::explain();

=head1 AUTHOR

Goetz Pfeiffer,  pfeiffer@mail.bessy.de

=head1 SEE ALSO

MultiCAN-documentation

=cut
