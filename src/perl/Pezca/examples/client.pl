eval 'exec perl -S $0 ${1+"$@"}' # -*- Mode: perl -*-
    if 0;                         
# the above is a more portable way to find perl
# ! /usr/bin/perl

use IO::Socket;

print "AAA\n";
$socket= new IO::Socket::INET( PeerAddr => 'steam',
			       PeerPort => 22222,
			       Proto    => 'tcp');
print "BBB\n";
die "unable to open socket, err msg: $!\n" unless $socket;
print "got connection !\n";
for($i=0; $i<10; $i++)
  { print "sleep 1 second...\n"; 
    sleep(1);
    print "send something to the socket...\n";
    print $socket "gimme\n"; $socket->flush();
    print "trying to read something from the socket...\n";
    $answer= <$socket>;
    print "answer: $answer\n";
  };
close($socket);

