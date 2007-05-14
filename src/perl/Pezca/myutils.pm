package myutils;

use strict;

BEGIN {
    use Exporter   ();
    use vars       qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
    # set the version for version checking
    $VERSION     = 1.0;

    @ISA         = qw(Exporter);
    @EXPORT      = qw();
    %EXPORT_TAGS = ( );     # eg: TAG => [ qw!name1 name2! ],

    # your exported package globals go here,
    # as well as any optionally exported functions
    @EXPORT_OK   = qw();
}
use vars      @EXPORT_OK;

# used modules
use Config; 			# access information about the platform we're running
use File::Spec;
use Carp;

# functions -------------------------------------------------

#### defines for the supported platforms:

my $debug=1;

my $platform;

my @platforms=('linux-x86','win32-x86','hpux-11','hpux','solaris');

sub platform
  { my $osname   = $Config{'osname'};		#linux=linux                   win32=MSWin32
    my $osvers   = $Config{'osvers'};
    my $archname = $Config{'archname'};		#linux=i386-linux-thread-multi win32=MSWin32-x86-multi-thread

    if (defined $ENV{PLATFORM})
      { warn "take platform \"$ENV{PLATFORM}\" from environment"; 
	$platform= $ENV{PLATFORM};
      }
    else
      {
	if    (($osname =~ /linux/i) && ($archname =~ /i[3-9]86/i)) 
	  {  $platform = 'linux-x86'; }
	elsif ( $osname =~ /MSWin32/i )                             
	  {  $platform = 'win32-x86'; }
	elsif    ($osname=~ /hp.?ux/i)
	  { if ($osvers >=11)
	      { $platform= 'hpux-11'; }
	    else 
	      { $platform= 'hpux'; }
	  }
	elsif ($osname=~ /solaris/i)
	  { $platform= 'solaris'; }
      }
    my %h= map{ $_ => 1 } @platforms;
    if (!exists $h{$platform})
      { die "error, platform \"$platform\" is not supported"; };
    return($platform);
  }

sub c2obj   
  { my($x)= @_;
    Die("assertion") if (!defined $platform);
    if ($platform eq 'win32-x86')
      { $x=~ s/\.c{1,2}\b/\.obj/g; }
    else
      { $x=~ s/\.c{1,2}\b/\.o/g; };
    return($x);
  }

sub empty
# returns 1 if the string is not defined or empty
  { return 1 if (!defined $_[0]);
    return 1 if ($_[0] eq "");
  }

sub checkdir
# aborts the program if a directory does not exist
# if you know what you are doing you can skip this step
# by removing the "#" before the following "return":
  { my($dir,$is_file,$no_check_existence)= @_;
    
    if (!-e $dir)
      { Die("error, \"$dir\" does not exist!\n") if (!$no_check_existence);
        return;
      };
    if ($is_file)
      { if (!-f $dir)
          { Die("error, \"$dir\" is not plain file!\n"); };
      }
    else
      { if (!-d $dir)
          { Die("error, \"$dir\" is not a directory!\n"); };
      }
  }  

sub compose_many
# compose a compiler option string.
# $r_pairs: a reference to an array of arrays.
#           The parts of each sub-array are concatenated
#           in order to form a valid paths for the currently
#           used platform. It is then checked wether that path 
#           exists. The function performs "die" if it doesn't.
#           The resulting list of paths (variable "@list") is 
#           then concatenated with a "$option_str" prepended to
#           each path. 
# $option_str: this string is prepended to each substring
# $do_quote: add quotes ('"') to each path
# $is_file: must be 1, if the given paths result in a file-path, not
#           a directory path
# $no_check_existence: no fatal error when file/directory does not exist
# example:
# compose_many([["/usr/lib","epics","base"],["/usr/lib","epics","extensions"]
#              "-I", undef)
# returns this (on Linux):
# "-I/usr/lib/epics/base -I /usr/lib/epics/extensions"
  { my($r_pairs,$option_str,$do_quote,$is_file,$no_check_existence)= @_;
  
    my @list;
    if (ref($r_pairs) ne "ARRAY")
      { Die("assertion, 1st parameter is not an array ref but " .
               ref($r_pairs));
      }
        
    foreach my $pair (@$r_pairs)
      { Die("assertion, an element of the array-ref is not an array")
            if (ref($pair) ne "ARRAY");
        
	my $path;
	
	if (!defined $pair->[0])
	  { $path= File::Spec->catfile(@$pair[1..$#$pair]); }
	else
	  { $path= File::Spec->catfile(@$pair); };
	
	checkdir($path,$is_file,$no_check_existence);
	$path= "\"$path\"" if ($do_quote);
	push @list, $path;
      };
    return($option_str . join(" $option_str",@list));
  }    

sub add_prefix
# adds a prefix, which may be a scalar or list to a list of lists
# example:
# add_prefix(["A","B"],[ [1,2,3], [4,5,6] ] gives
#    [ ["A","B",1,2,3], ["A","B",4,5,6] ]
  { my($prefix, $r_l)= @_;
    my @new;
    
    if (!defined $prefix)
      { @new= @$r_l;
      }
    if    (ref($prefix) eq "") # a skalar
      { foreach my $sublist (@$r_l)
          { push @new, [$prefix,@$sublist]; };
      }
    elsif (ref($prefix) eq "ARRAY") # list reference
      { foreach my $sublist (@$r_l)
          { push @new, [@$prefix,@$sublist]; };
      }
    else
      { die "assertion:ref is:" . ref($prefix); }
    return(\@new);
  }

sub mklist
# converts a string to an array reference,
# the string is splitted along <$sep> characters,
# $str: input string
# $sep: separation character, default: '/'
# returns: an array reference
  { my($str,$sep)=@_; 
    
    $sep= '/' if (!defined $sep);
    my @a= split(/$sep/,$str); 
    return(\@a);
  }

sub dump
  { my($r_h)= @_;
  
    print "-" x 50,"\n";
    foreach my $tag (sort keys %$r_h)
      { my $str= $r_h->{$tag};
        
        if (ref($str) eq 'ARRAY')
          { $str= join("|",@$str); }
        else
          { my @a= split(/\s+/,$str);
            $str= join(" ",sort @a);
          };
        printf "%-10s: %s\n",$tag, $str;
      };
    #die "\n";
  }

sub Die
  { die(@_) if (!$debug);
    confess(@_) if (!$debug);
  }

1;
