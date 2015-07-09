package Options;

# Copyright 2015 Helmholtz-Zentrum Berlin für Materialien und Energie GmbH
# <https://www.helmholtz-berlin.de>
#
# Author: Benjamin Franksen <Benjamin.Franksen@helmholtz-berlin.de>
# Contributions by:
#         Victoria Laux <victoria.laux@helmholtz-berlin.de>
#
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later
# version.
# 
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
# details.
# 
# You should have received a copy of the GNU General Public License along with
# this program.  If not, see <http://www.gnu.org/licenses/>.


require Exporter;

our @ISA = qw(Exporter);
our $VERSION = 1.00;

use Getopt::Long;
use strict;

our @options;
our $config;

my $option_options = {
  "" => "",
  "!" => "",
  "=s" => "=STRING",
  ":s" => "[=STRING]",
  "=i" => "=INTEGER",
  ":i" => "[=INTEGER]",
  "=f" => "=FLOAT",
  ":f" => "[=FLOAT]",
};

#------------------------------------------------------------------------------
# register
#------------------------------------------------------------------------------
sub register {
  push @options, @_;
}

#------------------------------------------------------------------------------
# BEGIN
#------------------------------------------------------------------------------
BEGIN {
  register(
    ["help",   "h", "",   "display this help"],
    ["verbose","v", "",   "print verbose messages"],
    ["log",    "l", ":s", "print messages to file instead of stdout"],#, "log filename", "$0.log"],
    ["not",    "n", "",   "do not perform any actual work"],
  );
}

our $help;

#------------------------------------------------------------------------------
# help
#------------------------------------------------------------------------------
sub help {
  return $help if defined $help;
    $help = join("\n",
      map(
        sprintf("  %s, --%-24s %s",
          $_->[1], "$_->[0]".$option_options->{$_->[2]}, $_->[3]),
          @options)) . "\n";
}

#------------------------------------------------------------------------------
# parse - main routine
#------------------------------------------------------------------------------
sub parse {
  my $usage = shift() . help();
  my $quiet = shift();
  if (not $config) {
    Getopt::Long::Configure("bundling");
    $config = {};
    GetOptions($config, map { "$_->[0]|$_->[1]$_->[2]" } @options)
      or die $usage;
    die $usage if $config->{"help"};
    # now ask the user for the interactive options
  	&ask_out() if not $quiet;
  }
  return $config or die $usage;
}

#------------------------------------------------------------------------------
# ask_out - for separate login
#------------------------------------------------------------------------------
sub ask_out {
    foreach my $opt (@options) {
      my $name = $opt->[0];
      my $prompt = $opt->[4];
      my $default = $opt->[5];
      my $secret = $opt->[6];
      if (defined $prompt) {
        if ($secret) {
          ask_secret($name, $prompt, $default);
        }
        else {
          ask($name, $prompt, $default);
        }
      }
    }
}

#------------------------------------------------------------------------------
# print_out
#------------------------------------------------------------------------------
sub print_out {
   if ($config->{"verbose"} > 0) {
      print $_[0];
   }
   if ($config->{"log"}) {
      open (H_LOG, ">>$0.log");
      print H_LOG $_[0];
      close (H_LOG);
   }
}

#------------------------------------------------------------------------------
# get_stdin - input per commandline
#------------------------------------------------------------------------------
sub get_stdin {
   my $input;
   if ($_[0] ne "") {
      print $_[0];
   } else {
      print "?";
   }
   if ($_[1] ne "") {
      print " [$_[1]]";
   }
   print ": ";
   $input = <STDIN>;
   chomp ($input);
   if (length($input) == 0 && length($_[1]) > 0) {
      $input = $_[1];
   }
   $input =~ s/  / /g;
   $input =~ s/[^\w\s_\,\.]//g;
   return $input;
}

#------------------------------------------------------------------------------
# ask - asking on commandline
#------------------------------------------------------------------------------
sub ask {
  my ($name, $prompt, $default) = @_;
  if (length($config->{$name}) == 0) {
    $config->{$name} = get_stdin($prompt, $default);
  }
}

#------------------------------------------------------------------------------
# ask_secret - password like asking on commandline
#------------------------------------------------------------------------------
sub ask_secret {
  my ($name, $prompt, $default) = @_;
  if (length($config->{$name}) == 0) {
    if (-t STDIN) {
      eval(system "stty -echo");
    }
    $config->{$name} = get_stdin($prompt, $default);
    if (-t STDIN) {
      eval(system "stty echo");
    }
    print "\n";
  }
}

1;
# Below is the short of documentation of the module.

=head1 NAME

Options - a Perl module for handling programm arguments,
commandline in and output inclusive login requests

=head1 SYNOPSIS

  use Options;

=head1 DESCRIPTION

=head2 Preface

This module contains functions that are used to get and  set simply
program arguments from commanline and small handling for
commandline in and output.
The following options are predefined for defining the argument types:

  my $option_options = {
    "" 			=> "",
    "!"			=> "",
    "=s"		=> "=STRING",
  ":s" 		=> "[=STRING]",
  "=i" 		=> "=INTEGER",
  ":i" 			=> "[=INTEGER]",
  "=f" 		=> "=FLOAT",
  ":f" 			=> "[=FLOAT]",
};

And in addition the predefined arguments:

  register(
    ["help",   			"h", "",   "display this help"],
    ["verbose",		"v", "",   "print verbose messages"],
    ["log",    			"l", ":s", "print messages to file instead of stdout"],#, "log filename", "$0.log"],
    ["not",    			"n", "",   "do not perform any actual work"],
  );

=head2 Implemented Functions:

=over 4

=item *

B<interview>

  $helpcontext = Options::help();

This function returns a formattedt string containing the help description of the program
including all the options defined by @options.

=item *

B<interview>

  $config = Options::parse($usagedescrion, $quiet);

This function parse all the options and setting the usagedescription for help. If the quiet
option is set, there will be no asks for inputtting arguments is accessed.

=item *

B<interview>

  Options::ask_out();

After the quiet Optins::parse you will need to complete the inputs on commandline ? Thats this
function is created for.

=item *

B<interview>

  Options::print_out($outputstring);

Prints the given string in dependency of verbosity and logging switches.

=item *

B<interview>

  $value = Options::get_stdin($prompt, $default);

For the completion of getting values this ask at stdin for the value with
the prompt and the default value concatenate in [] after.
the return is the well filtered value.

=item *

B<interview>

  Options::ask($name, $prompt, $default);

wrapper around get_stdin., which get value from stdin if in $config the value is not set.
$config->{$name} is updated. $prompt and $default for the default value.

=item *

B<interview>

  Options::ask_secret($name, $prompt, $default);

wrapper around get_stdin., which get value from stdin if in $config the value is not set.
$config->{$name} is updated. $prompt and $default for the default value. But the output
is hidden for secret values like passwords.

