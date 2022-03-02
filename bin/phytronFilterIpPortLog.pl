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
    my @msta = ("Dir=",
         "DONE",
         "LS+",
         "LS_HOME",
         "nn",
         "POS",
         "SLIP_STALL",
         "HOME",
         "PRESENT",
         "PROBLEM",
         "MOVING",
         "GAIN_SUPPORT",
         "COMM_ERR",
         "LS-",
         "HOMEDone",
         "nn"
         );


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
    my $lineNr;
    my @result;
    while( <IN_FILE> )
    {
        my $matchFilter = undef;
        $line = $_;
        $lineNr++;
        $line = checkCaMonitorData($line,\@result); # return next line, if this is a monitor, same else
        if($line =~ /^.*?\s(.*?)\s.*?\s(\w+)/ && $2 eq 'write') {
            $timeWrite = $1;
            $line = <IN_FILE>;
            $lineNr++;
            $line = checkCaMonitorData($line,\@result); # return next line, if this is a monitor, same else
            if($line=~/\d(M.*):../) { # Axis command
                $command=$1;
            }
            elsif($line=~/(.*):../) { # other command
                $command=$1;
            }
            else {
                chomp $line;
                push @result, "$timeWrite\terr\tILLEGAL COMMAND in $lineNr: '$line'\t\n";
            }
            if( not ($command =~/$ignore/) ) {
                if( $command =~/$filter/) {
                    push @result, "$timeWrite\twr\t$command\n";
                    $matchFilter = 1;
                }
            }
            $line = <IN_FILE>;
            $lineNr++;
            $line = checkCaMonitorData($line,\@result); # return next line, if this is a monitor, same else
            if($line =~ /^.*?\s(.*?)\s.*?\s(\w+)/ && $2 eq 'read') {
                $timeRead = $1;
                $line = <IN_FILE>;
                $lineNr++;
                if($line=~/(.*):../) {
                    $reply = $1;
                    $reply = getStatus($reply) if($command=~/M\d+\.\dSE/)
                }
                else {
                    chomp($line);
                    $reply = "ILLEGAL REPLY: '$line'";
                }
                push @result,"$timeRead\trd\t$reply\n" if($matchFilter);
            }
            else {
                chomp($line);
                push @result, "$timeRead\terr\tMISS READ in $lineNr: '$line'\n";
            }

        }
        else {
            chomp($line);
            push @result, "\n$timeWrite\terr\tWRITE EXPECTED in $lineNr:\t'$line'";
        }
        
    } # end while
    close IN_FILE;

#    print $_ foreach (@result);
    print $_ foreach (sort(@result));

# n2str($value,@bitDescriptions)
sub n2str
{   my $value = shift @_;
    my $rDesc = shift @_;
    my $hex  = sprintf("%X",$value);
    my $msg;
    my $idx=0;

    foreach my $dsc (@$rDesc){
        my $bit = ($value >> $idx)&0x1;
        if($dsc=~/=/) {
            $dsc = $dsc.$bit;
        }
        if($dsc=~/!/) {
            $msg .= " $dsc" if($bit == 0);
        }
        else {
            $msg .= " $dsc" if($bit == 1);
        }
        $idx++;
    }
    return "0x$hex STAT:$msg";    
}

# check for camonitor data:
sub checkCaMonitorData
{   my ($line,$rResult) = @_;
    while($line =~ /^(.*?)\.([\w\d]+)\s+\d+-\d+-\d+\s+(.*?)\s+(.*)/) {
        my $pv=$1;
        my $field=$2;
        my $time=$3;
        my $value=$4;
        if($field eq "MSTA") {
            $value = "$value\t".n2str($value,\@msta);
        }
        push @$rResult, "$time\t$pv.$field\t$value\n";
        $line = <IN_FILE>;
        $lineNr++;
    }
    return $line;
}
sub getStatus 
{   my ($reply) = @_;
    my $hex  = sprintf("%X",$reply);
    my $msg;

    $msg .= " busy" if(($reply & 1));
    $msg .= " Illegal" if(($reply & 2));
    $msg .= " WaitSync" if(($reply & 4));
    $msg .= " isInit" if(($reply & 0x8));
    $msg .= " LS+" if(($reply & 0x10));
    $msg .= " LS-" if(($reply & 0x20));
    $msg .= " LSM" if(($reply & 0x40));
    $msg .= " SwLS+" if(($reply & 0x80));
    $msg .= " SwLS-" if(($reply & 0x100));
    $msg .= " SwLS-" if(($reply & 0x100));
    $msg .= " ready" if(($reply & 0x200));

    $msg .= " LS_Err" if(($reply & 0x1000));
    $msg .= " PwrStg_Err" if(($reply & 0x20000));

    $msg .= " RUN" if(($reply & 0x10000));
    $msg .= " DONE" if(($reply & 0x80000));
    return "$reply, 0x$hex STAT:$msg";    
}
