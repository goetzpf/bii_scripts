package Options;

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

sub register {
  push @options, @_;
}

BEGIN {
  register(
    ["help",   "h", "",   "display this help"],
    ["verbose","v", "",   "print verbose messages"],
    ["log",    "l", ":s", "print messages to file instead of stdout"],#, "log filename", "$0.log"],
    ["not",    "n", "",   "do not perform any actual work"],
  );
}

our $help;

sub help {
  return $help if defined $help;
  $help = join("\n",
    map(
      sprintf("  %s, --%-24s %s", 
        $_->[1], "$_->[0]".$option_options->{$_->[2]}, $_->[3]),
      @options)) . "\n";
}

sub parse {
  my $usage = shift() . help();
  if (not $config) {
    Getopt::Long::Configure("bundling");
    $config = {};
    GetOptions($config, map { "$_->[0]|$_->[1]$_->[2]" } @options)
      or die $usage;
    die $usage if $config->{"help"};
    # now ask the user for the interactive options
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
  return $config or die $usage;
}

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

sub ask {
  my ($name, $prompt, $default) = @_;
  if (length($config->{$name}) == 0) {
    $config->{$name} = get_stdin($prompt, $default);
  }
}

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
