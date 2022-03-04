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

    # Bits set in state done are inverted by '!'
    my @msta = ("Dir=",
         "DONE",
         "LS+",
         "LS_HOME",
         "nn",
         "POS",
         "SLIP_STALL",
         "HOME!",
         "PRESENT!",
         "PROBLEM",
         "MOVING",
         "GAIN_SUPPORT",
         "COMM_ERR",
         "LS-",
         "HOMEDone!",
         "nn"
         );
    my @SystemStat_SE = ("busy", # 1
        "IllegalCommand",        # 2      
        "waitSync",              # 4
        "isInit",                # 8 _______ 1
        "LS+",                   # 10
        "LS-",                   # 20
        "LSM",                   # 40
        "SwLS+",                 # 80 ______ 2
        "SwLS-",                 # 100
        "PwrStgReady!",          # 200
        "Ramp",                  # 400
        "internErr",             # 800 _____ 3 
        "LS_Err",                # 1000
        "PwrStgErr",             # 2000
        "SFI_Err",               # 4000
        "ENDAT_Err",             # 8000 ____ 4
        "RUN",                   # 10000
        "calmDownTm",  # 20000
        "inBoost",               # 40000
        "DONE",                  # 80000 ___ 5
        "APS_ready!",            # 100000
        "PosMode",          # 200000
        "FreeRunMode",           # 400000
        "MultiFRun",             # 800000 __ 6
        "SyncEna");           # 1000000 _ 

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
    my $leave=undef;
    # is pv with field
    if($line =~ /^(.*?)\.([\w\d]+)\s+\d+-\d+-\d+\s+(.*?)\s+(.*)/) {
        my $pv=$1;
        my $field=$2;
        my $time=$3;
        my $value=$4;
        if($field eq "MSTA") {
            $value = "$value\t".n2str($value,\@msta);
        }
        push @$rResult, "$time\t$pv.$field\t$value\n";
    }
    # is pv without field
    elsif($line =~ /^(.*?)\s+\d+-\d+-\d+\s+(.*?)\s+(.*)/) { 
        my $pv=$1;
        my $time=$2;
        my $value=$3;
        push @$rResult, "$time\t$pv\t$value\n";
    }
    # is asyn driver read/write failed message
    elsif($line =~ /^.*?\s(.*?)\s(.*reason \d+)/) {
        my $time=$1;
        my $value=$2;
        push @$rResult, "$time\t$value\n";
    }
    # no camonitor data line
    else {
        return $line;
    }
    $line = <IN_FILE>;
    $lineNr++;
    checkCaMonitorData($line,$rResult);
}
sub getStatus 
{   my ($reply) = @_;
    my $hex  = sprintf("%X",$reply);
    

    return "$reply, 0x$hex STAT:".n2str($reply,\@SystemStat_SE);    
}
