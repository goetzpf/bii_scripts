#!/usr/bin/perl

=head1 NAME

expandStCmdConfig.pl - a program to output st.cmd configuration in various formats

=head1 SYNOPSIS

expandStCmdConfig.pl <format> IOC=<iocname> [VAR=sometext ...]

Currently supported formats are

=over

=item perl

Print as Perl expression (uses Data::Dumper)

=item json

Print in JSON format. This is the most compact presentation, no newlines,
no extra spaces.

=item json-pretty

Print in human readable JSON format.

=item python

Print as Python expression.

=back

Arbitrarily many variable substitutions may be given on the command line,
but IOC=<iocname> should be one of them and <iocname>.pm
should exist in the directory "..".

=cut

use lib "..";
use Standard;
#use stCmdTemplates;

use Data::Dumper;
use JSON;

### expand stCmd configuration and print in various formats

$Data::Dumper::Terse = 1;

sub expandStCmdConfig {
  my $fmt = shift @_;
  my $args = {@_};
  my $ioc = $args->{IOC};
  # merge in Standard
  my $std = Standard($args);
  while (my ($k,$v) = each %$std) {
    $args->{$k} = $v;
  }
  # merge in IOC
  require "$ioc.pm";
  my $ioc = &$ioc($args);
  while (my ($k,$v) = each %$ioc) {
    $args->{$k} = $v;
  }
  if ($fmt eq 'perl') {
    print(Dumper($args));
  } elsif ($fmt eq 'json') {
    print(to_json($args));
  } elsif ($fmt eq 'json-pretty') {
    print(to_json($args, {pretty => 1}));
  } elsif ($fmt eq 'python') {
    $Data::Dumper::Pair = " : ";       # specify hash key/value separator
    print(Dumper($args));
  }
}

### main

my $fmt = shift @ARGV;

expandStCmdConfig($fmt,map(split("=",$_),@ARGV));
