eval 'exec perl -S $0 ${1+"$@"}' # -*- Mode: perl -*-
    if 0;                         
# the above is a more portable way to find perl
# ! /usr/bin/perl

# The "raw socket" protocol:
# "<Channel-Name>"          : get double from channel
# "<Channel-Name>,string"   : get string from channel
# "status"                  : get status from tserver


#timings:
# with debug=on, running local to local:
#  1000 requests: 39 seconds
# with debug=off, running local to local:
#  1000 requests: 36 seconds
# -> 39ms per request !

# specials: Recordname,string e.g. U49ID5R:BaseCmdMcmd,string 
# fetches a string instead of a number 

use lib "../blib/lib";  # <-- not necessary when Pezca is installed !
use lib "../blib/arch"; # <-- not necessary when Pezca is installed !

use Pezca;

use IO::Socket;
use Net::hostent;

use strict;

my($debug)=1;

my(%domains)= ('acc.bessy.de' => 1,
               'blc.bessy.de' => 1,
	       'exp.bessy.de' => 1);

my(@sockarray);
my($mask);
my(%reclist);
my($ticktime)=10;
my($maxidle)= 60; # 60 #maxidle * ticktime= max. idle time bef. connection is closed
my($initial_idle)= $maxidle-60/$ticktime;
                 # when the channel is new and the first access failes, it is
		 # removed after 60 seconds
my($request_count)=0;
my($runtime)=0;

my($i)   =-1;   # loop variable 
my($i_stop)=0;  # used for loop variable 
my($i_inc)=0;   # used for loop variable 

Pezca::SetTimeout(0.05);
Pezca::SetRetryCount(9); # overall timeout: 0.5 seconds

$SIG{CHLD}= sub {wait()};
print "opening listen-socket...\n" if ($debug);
my $mainsocket= new IO::Socket::INET( #LocalAddr => 'apache', 
				      LocalAddr => 'steam',
                                      LocalPort => 22224,
				      Listen    => 5,
				      Proto     => 'tcp',
				      Reuse     => 1
                                    );

push(@sockarray,$mainsocket);
$mask= fhbits(@sockarray);

    
for(;;)
  { my $rout;
    my $nfound= select($rout=$mask,undef,undef, $ticktime); # return every 10 seconds
    if ($nfound<=0)
      { $runtime+= $ticktime;
        # perform a kind of garbage collection:
        idle_channel_check();
	next;  
      };

    if (vec($rout,fileno($mainsocket),1))
      { if (new_connection())
	  { next; };
      };	  
   
    if ($i<1)
      { $i= 1;           $i_stop= $#sockarray+1; $i_inc= 1; }
    else
      { $i= $#sockarray; $i_stop= 0;             $i_inc=-1; }
    for(; $i!=$i_stop; $i+= $i_inc)
      { my($fh)= $sockarray[$i];
        if (vec($rout,fileno($fh),1))
	  { if ($i==0) # perform accept
              { if (new_connection())
	          { last; };
	      }	  
            else
	      { # ordinary socket
                print "in ordinary socket-part\n" if ($debug);
		my $buffer;
		if (!defined($buffer= <$fh>))
		  { # close connection
		    del_connection();
		    last; # force the loop to be left
		  }
		else
		  { chomp($buffer);
		    print "got from socket: $buffer\n" if ($debug);
		    if ($buffer eq 'status')
		      { show_status($fh); }
		    else
		      { $request_count++;
		        give_value($fh,$buffer); 
		      };
                    # $fh->flush();
		  };
              };
	  };
      };
  };  


sub fhbits
  { my(@fhlist)= @_;
    my($bits)="";
    for(@fhlist)
      { vec($bits,fileno($_),1)=1; };
    return($bits);
  }    
      
sub check_peer_name
  { my($peername)= @_;
    my($domain);
    
    chomp($peername);
    
    foreach $domain (keys %domains)
      { if (eval '$peername=~ /' . "$domain" . '$/')
          { return(1); }; # it's a known domain 
      };
    print "unknown domain in $peername\n" if ($debug);
    return(0);
  }; 

sub idle_channel_check
  { my($rec,$err);
    foreach $rec (keys %reclist)
      { if (++($reclist{$rec}) > $maxidle)
	  { $err= Pezca::ClearMonitor($rec);
	    print "closing connection to $rec\n" if ($debug);
	    delete $reclist{$rec};
	    if ($err!=0)
	      { print "warning: ClearMonitor on $rec caused error $err\n" 
	          if ($debug);
	      };
          };
      };
  }
  
sub new_connection
  { 
    my($newsocket);
    my($peerinfo);
    
    if (!($newsocket = $mainsocket->accept()))
      { warn "unexpected error!\n"; }
    else
      { $peerinfo= gethostbyaddr($newsocket->peeraddr);
	if ($debug)
	  { printf "[Connect from %s]\n", 
	       $peerinfo->name || $newsocket->peerhost;
	  };     

	if (!check_peer_name($peerinfo->name))
	  { print "connection refused!\n" if ($debug);
	    close $newsocket;
	    return(0);
	  }
	else
	  { push(@sockarray,$newsocket);
            $mask= fhbits(@sockarray);
	    return(1);
	  };		
      };
   }
   
sub del_connection
  { splice(@sockarray,$i,1);
    $mask= fhbits(@sockarray);
    print "connection closed!\n" if ($debug);
  }  
   
sub give_value
  { my($socket,$param)=@_;
    my($err);
    my($val);
    
    $param=~ s/[\r\n]+$//;
    
    my($channel,$spec)= split(/,/,$param);
    if (!exists($reclist{$channel}))
      { # a new record was given:
	
	#if ($channel!~ /idcp\d{1,2}:/)
	#  { print $socket "invalid channelname!\n"; 
	#    return;
	#  };
	
	$err= Pezca::SetMonitor($channel);
	if ($err!=0)
	  { print $socket "error-code $err\n";
	    return;
	  };
	$reclist{$channel}= $initial_idle;
      }
    else
      { # the record is already known: 	
	Pezca::Delay(0.01); # is this really necessary ??
      };
    if ($spec eq "string")
      { ($val,$err)= Pezca::GetS($channel); 
      }
    else  
      { ($val,$err)= Pezca::Get($channel); };
    print "value: $val, err: $err\n" if ($debug);
    if ($err==0)
      { print $socket "$val\n"; 
        $reclist{$channel}=0;
        return;
      }
    else
      { print $socket "error-code $err\n";
        return; 
      };
  }
  
sub show_status
  { my($socket)= @_;
    my($st);
  
    print $socket "no. of peers: $#sockarray\n" .
                  "uptime: $runtime seconds, requests: $request_count\n" .
		  "known channels: \n";
    print $socket "[ ",join(' ',(keys %reclist))," ]\n";
    return;
  }  
