eval 'exec perl -S $0 ${1+"$@"}' # -*- Mode: perl -*-
    if 0;                         
# the above is a more portable way to find perl
# ! /usr/bin/perl

# !/opt/bin/perl5/perl

use IO::Socket;

my($sockmask);
my($host)= "steam";

print "connecting to host $host...\n";
$socket= new IO::Socket::INET( PeerAddr => "$host",
			       PeerPort => 22224,
			       Proto    => 'tcp');
die "unable to open socket, err msg: $!\n" unless $socket;
print "got connection !\n";

$sockmask= calcmask($socket);

for(;;)
  { print "\nplease enter a channel-name or 'q' to exit:\n";
    chomp($line=<STDIN>);
    if ($line=~ /^\s*[Qq]\s*$/)
      { last; };
    print $socket "$line\n"; $socket->flush();
    if (!ready($sockmask,3))
      { print "no answer from server !\n"; }
    else 
      { do { $answer= <$socket>;
            print "  -> $answer";
	  } until (!ready($sockmask,0.4));
      };	     
  };
close($socket);


sub calcmask
  { my($fh)= @_;
    my($mask)='';
    vec($mask,fileno($fh),1)=1;
    return($mask);
  }
    

sub ready
  { my($mask,$tmo)= @_;
    my($omask);
    my($ret);
    
    $ret= select($omask=$mask,undef,undef,$tmo);
    if (0<$ret)
      { return(1); };
    return(0);
  }

