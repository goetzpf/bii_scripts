#!/usr/bin/env perl

# EXAMPLE Data from phyMotion IP-Port log
#
# asynSetTraceMask connMOU1YU5L  -1 9
# SIOC2S5L>
# 2022/02/22 16:05:47.956 mou1s05l.blc05.bessy.de:22222 write 14
# 0M1.1P20R:XX
# 2022/02/22 16:05:47.966 mou1s05l.blc05.bessy.de:22222 read 12
# -50188:25
# 2022/02/22 16:05:47.966 mou1s05l.blc05.bessy.de:22222 write 14
# 0M1.1P22R:XX
# 2022/02/22 16:05:47.975 mou1s05l.blc05.bessy.de:22222 read 7
# 0:0C

    use strict;
    use Getopt::Long;

    my $usage = "phytronFilterLog.pl [OPTIONS] phytronIpPortLogFile\n\t-h: help\n\t-f: filter e.g. M1.1 for motor 1\n";
    my $filter = ".*";     #default: get all
    my $ignore = "___";
    our($opt_h,$opt_f,$opt_i) = (undef,undef,undef);

    Getopt::Long::config(qw(no_ignore_case));
    die unless GetOptions("h","f=s","i=s");
    die $usage unless scalar(@ARGV) > 0;
    die $usage if( $opt_h);

    $filter = $opt_f if( $opt_f);
    $ignore = $opt_i if( $opt_i);
    my $inFileName = @ARGV[0];

    open(IN_FILE, "<$inFileName") or die "can't open input file: '$inFileName'";

    my $command;
    my $reply;
    my $timeWrite;
    my $timeRead;
    my $line;
    my $lineNr = 0;
    while( <IN_FILE> )
    {
        my $matchFilter = undef;
        $line = $_;
        $lineNr++;
        $timeWrite = $1;
# check write                    
        if($line =~ /^.*?\s(.*?)\s.*?\s(\w+)/ && $2 eq 'write') {
            $line = <IN_FILE>;
            $lineNr++;
            if($line=~/\d(M.*):../) { # Axis command
                $command=$1;
            }
            elsif($line=~/(.*):../) { # other command
                $command=$1;
            }
            else {
                $command = "ILLEGAL COMMAND: '$line'\n";
            }
            if( not ($command =~/$ignore/) ) {
                print "$lineNr\t$timeWrite\twr\t$command\n";
                $matchFilter = 1;
                if( $command =~/$filter/) {
                    print "$lineNr\t$timeWrite\twr\t$command\n";
                    $matchFilter = 1;
                }
            }
        }
        else {
            chomp($line);
            print "$lineNr\t$timeWrite\terr\tWRITE EXPECTED:\t'$line'\n";
        }
        
# next should be 'read'
        $line = <IN_FILE>;
        $lineNr++;
        $timeRead = $1;
        if($line =~ /^.*?\s(.*?)\s.*?\s(\w+)/ && $2 eq 'read') {
            $line = <IN_FILE>;
            $lineNr++;
            if($line=~/(.*):../) {
                $reply = $1;
            }
            else {
                chomp($line);
                $reply = "ILLEGAL REPLY: '$line'";
            }
            print "$lineNr\t$timeRead\trd\t$reply\n" if($matchFilter);
        }
        else {
            chomp($line);
            print "$lineNr\t$timeRead\terr\tMISS READ\t'$line'\n";
        }
    }
    close IN_FILE;
