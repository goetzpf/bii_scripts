eval 'exec perl -S $0 ${1+"$@"}' # -*- Mode: perl -*-
    if 0;                         
# the above is a more portable way to find perl
# ! /usr/bin/perl

use lib "../blib/lib";  # <-- not necessary when Pezca is installed !
use lib "../blib/arch"; # <-- not necessary when Pezca is installed !

use Pezca;

use IO::Socket;
$SIG{CHLD}= sub {wait()};
print "opening listen-socket...\n";
$mainsocket= new IO::Socket::INET( LocalHost => 'steam', 
                                   LocalPort => 22222,
				   Listen    => 5,
				   Proto     => 'tcp',
				   Reuse     => 1
                                 );

die "unable to open main-socket, err-msg: $!\n" unless defined ($mainsocket);
print "entering accept-loop...\n";
while ($newsocket = $mainsocket->accept())
  { 
    print "got connection !\n";
    $pid= fork();
    die "unable to fork: $!\n" unless defined($pid);
    if ($pid==0)
      { print "a new process was started...\n"; 
        while (defined ($buffer= <$newsocket>))
          { print "received something from the socket!\n"; 
            ($val,$err)= Pezca::Get('U49ID5R:BasePmEnergy');
            print $newsocket "$val\n";
            $newsocket->flush();
          };
        # the socket was closed...
        print "one connection was closed!\n";
        exit(0); 
      };
  };
close($mainsocket);

