eval 'exec perl -S $0 ${1+"$@"}' # -*- Mode: perl -*-
    if 0;                         
# the above is a more portable way to find perl
# ! /usr/bin/perl

# @STATUS: release
# @PLATFORM: home bessy 
# @CATEGORY: search


# pfind -- recursive file-finder
# NOTE: DOES NOT follow symbolic links

# 2nd parameter may be a regex (e.g. /\.c$/) or a regular file-mask (*.c)

use strict;

use FindBin;
use Getopt::Long;
use Cwd;

use File::Find;
use File::Spec;

use vars qw($opt_help $opt_summary
           $opt_text $opt_ccode $opt_make $opt_perl 
            $opt_progress
            $opt_perl_ex
            $opt_blank $opt_no_filenames $opt_list $opt_stdin_list);


my $version= "1.3";

my $file_assist=1;
# sometimes, when "file" scans a binary file, it recognizes a
# "lex command text" or "awk program text". With  $file_assist==1, 
# all *.o and *.a files are treated as binaries

# print join("|",@ARGV),"\n"; exit(1);

Getopt::Long::config(qw(no_ignore_case));
if (!GetOptions("help|h","summary",
                "text|t", "ccode|c", "make|m", "perl|p", 
                "perl_ex|P",
		"progress",
                "list|l", "blank|b", "no_filenames|n",
		"stdin_list|i",
		))
  { die "parameter error!\n"; };		


if ($opt_help)
  { help();
    exit;
  };  

if ($opt_summary)
  { print_summary();
    exit;
  };  

if ($#ARGV<0)
  { die "parameters are missing, use -h for help!\n"; };
  
my $path   = '.';
my $f_regex= '*';
my $s_regex;

if    (($#ARGV==0) || (defined $opt_stdin_list))
  { $s_regex= $ARGV[0]; }
elsif ($#ARGV==1)
  { ($f_regex,$s_regex)= @ARGV; }
elsif ($#ARGV==2)
  { ($path,$f_regex,$s_regex)= @ARGV; }
else
  { die "too many parameters, use -h for help\n"; };
 
if (!defined $opt_stdin_list) # search recursively for files 
  { if ($f_regex!~ /^\/[^\/]*\/\w*$/ )
      { $f_regex= filemask_convert($f_regex); };

    # print "****|$f_regex|\n";

    eval( "sub file_filter " .
	  " { return( scalar (\$_[0]=~$f_regex) ); }" );
    if ($@)
      { die "error: eval() failed, error-message:\n" . $@ . " "  };
  };
  

if ($s_regex !~ /^\//)
  { $s_regex= "/$s_regex/"; };
      
# print "****|$s_regex|\n";

eval( "sub line_filter " .
      " { return( scalar (\$_[0]=~$s_regex) ); }" );
if ($@)
  { die "error: eval() failed, error-message:\n" . $@ . " "  };
      
my $option_filter= ($opt_ccode || $opt_perl || $opt_make);
my $text_filter  = ($opt_perl_ex || $opt_text);

if (!defined $opt_stdin_list) # search recursively for files 
  { find(\&wanted, $path); }
else
  { while (my $file=<STDIN>)
      { check_($file);
      };
  };
	
sub check_
  { my($path)= @_;
    chomp($path);
    my $old= cwd;
  
    my ($volume,$dirs,$file) = File::Spec->splitpath($path);
    if (!-d $dirs)
      { 
        warn "$path does not exist!\n"; 
	return;
      };
    chdir($dirs) || die "unable to chdir to $dirs\n";
    if (!-e $file)
      { 
        warn "$path does not exist!\n"; 
      }
    else
      { check_file($path,$file); };
    chdir($old) || die "unable to chdir to $old\n";
  }  
    

sub wanted 
  { my $file= $_;
    my $is_perl;
  
    if ($opt_progress)
      { printf(STDERR "\r%-78s\r", $File::Find::dir . "/$file"); }
    
    return unless (-f $file);
    return if (-z $file);
    if (!(-r $file)) 
      { warn "file $file is unreadable !\n"; return; };

    if ($option_filter)
      { for(;;)
          { if ($opt_ccode)
              { last if ($file =~ /\.(c|cc|CC|cpp|h)$/); };

            if ($opt_perl)
              { if ($file =~ /\.(p|pl|pm)$/)
	          { $is_perl= 1; last; }; 
	      };

            if ($opt_make)
              { last if ($file =~ /(^[Mm]akefile$|\.mak$)/); };
	      
	    # return if the filename didn't match the wanted file-scheme
	    # AND if not one of the text-file search filters is on
	    if (!$text_filter)
	      { return; }
	    else
	      { last; }; 
          };
      }; 
    
    return unless (file_filter($file));

    if (($opt_perl_ex) && (!$is_perl))
      { my $type= `file $file`;
        if ($type !~ /\bperl\b/i)
	  { return if ($type !~ /\btext\b/i);
	    my $l= `head -n 1 $file`;
	    return if ($l !~ /^\s*eval\s*\'exec\s+perl\b/);
	  };
	$is_perl= 1;
      };
        
    
    if (($opt_text) && (!$is_perl))
      { if ($file_assist)
          { return if ($file =~ /\.[ao]$/); };
	
      
        my $type= `file $file`;
        # print "$_ : |$type|\n";
	
	return if ($type !~ /\btext\b/i);
      };
    
    check_file($File::Find::name,$file);
  }

sub check_file
  { my($fullname,$name)= @_;
    my($line);
    my($lineno)=0;
    if (!open(F,$name))
      { warn "unable to open file $name in path $File::Find::dir\n";
        return; 
      };
    while ($line=<F>)
      { $lineno++;
        next unless line_filter($line);
	if (!$opt_no_filenames)
	  { if ($fullname)
	      { if ($opt_list)
		  { print "$fullname\n"; }
		else
		  { print "\n-------> $fullname\n"; };
		$fullname= undef;
	      }; 
	  };
	next if ($opt_list);
        chomp($line);
	if ($opt_blank)
	  { print "$line\n"; }
	else
	  { printf("%5d: %s\n",$lineno,$line); };
      };
    close(F);
  }	  	
	
sub filemask_convert
  { my($r)= @_;
   
    if ($r eq '*')
      { return('/.*/'); };
    
    $r=~ s/^([^\*])/\^$1/; # line-start sign   
    $r=~ s/([^\*])$/$1\$/; # line-end sign
    $r=~ s/^\*//;          # rem. * at line-start
    $r=~ s/\*$//;          # rem. * at line-end
    $r=~ s/\./\\\./g;      # point-quoting
    $r=~ s/\?/\./g;        # ? - conversion
    $r=~ s/\*/\.\*/g;      # * - conversion
    
    
    if ($r=~ /\//)
      { die "error: filemask must NOT contain a path\n"; };
    
    $r= '/' . $r . '/';
    
    return($r);
  }  

sub print_summary
  { printf("%-20s: a universal recursive regular expression search\n",
           $FindBin::Script);
  }

sub help
  { my $p= $FindBin::Script;
  
    print <<END;

           **** $p $version -- the file-tree regexp-search program ****
	   	              Goetz Pfeiffer 2002

Syntax: 
  $p {options} [path] [file-regexp] [search-regexp] or 
  $p {options} [file-regexp] [search-regexp] or 
  $p {options} [search-regexp] 

  compares two directory-trees recursively
  
  regular expressions for files may be perl-regexps or file-regexps
  a perl-regexp may or may not be enclosed in '/' characters
  (it is sometimes handy to use '/' in order to add modifiers like 
   'i' after the finishing '/').
  
  options:
    -h: help
    -t: use the "file" command to search only text-files
    -c: only check c and c++ files, this means all files matching
        *.c, *.cc. *.CC. *.cpp. *.h 
    -p: search only for perl-files: *.p *.pl *.pm
    -P: extended perl search, find perl-files by analysing their content
        should only be used together with '-p', since recognizing a
	perl-file is not always easy
    -m: only check makefiles: Makefile, makefile, *.mak
        -c, -p and -m may be combined
    -l: just list the files that matched
    -b: blank, print just matching lines, no line-numbers
    -n: no filenames, do not print the filenames
    -i: take list of files to search from STDIN, this allows searching
        for two items at different lines of the file: 
        e.g. "$p -c -l printf | $p -i include"
    --progress: show progress on stderr	
END
  }
