eval 'exec perl -S $0 ${1+"$@"}'  # -*- Mode: perl -*-
	if $running_under_some_shell;
#     Usage: prel2txt.pl filename.pl
  use strict;
  my $inFileName = shift @ARGV;

# for creation of outfile name with installpath from infile name
#  my $installPath=".";
#  if( @ARGV ){ $installPath = shift @ARGV;}

  print "Create asci documentation text from: $inFileName \n";
  chomp $inFileName;
  open(IN_FILE, "<$inFileName") or die "can't open input file $inFileName: $!";

  my $parse;
  my $out_file;

  while( $parse = <IN_FILE> )
  {
# print "PARSE:|$parse|\n";

    my $paragraph;	# hold a complete comment block
    if( $parse =~ /## (.*)/ )	# Get Comment block
    {
        $paragraph = "$1\n";
#	print "$1\n";
	while( $parse = <IN_FILE> )
	{ 
	    if( $parse =~ /^#\s{0,2}(.*)/)
	    {
	        $paragraph .= "$1\n";
#		print "$1\n";
	    }
	    else
	    {	last;
	    }
	}
    }

# get a subroutine definition maybe with preceeded comment block
# but ommit subroutienes with more than 2 spaces between sub and funcName ;-)
    if( $parse =~/^\s*sub {1,2}([^ ].*)\s*/s )	
    { 
    	my $subName = $1;
	   chomp $subName;
	my $parameterNames;	# as parsed from: { my(.*) = @;
	my $parameterString;	# if there is a description to the parameters
				# { my ( $xx # is a xx 
				#        $yy # is a yy ) = @_;
	next unless defined $1;
       $parse = <IN_FILE>;
# print "PARSE:$parse\n";
#       if( $parse =~ /^\s*\{\s*my\s*\((.*)\)\s*=\s*\@_\s*;/ )
#       {    
#	   $parameterNames = $1;
#       }
#       elsif( $parse =~ /^\s*\{\s*$/ ) # may be next line contains params
#       {
#	  $parse = <IN_FILE>;
#	  if( $parse =~ /\s*my\s*\((.*)\)\s*=\s*\@_\s*;/ )
#	  {
#	      $parameterNames = $1;
#	  }
#       }
        if( $parse =~ /^\s*\{\s*my\s*\((.*)\)\s*=\s*\@_\s*;/ )	# '{ my ($a, $b)=@_' all in one line
        {
	    $parameterNames = $1;
        }
        else 
	{
          if( $parse =~ /^\s*\{\s*my\s*\((.*)/ )		# '{ my ( ' $1 = any parameters
	  {
	      ($parameterNames,$parameterString) = checkSubParameters($1);
	  }
	  elsif( $parse =~ /^\s*\{\s*$/ ) # '{' may be next line contains params
	  {
	      $parse = <IN_FILE>;
	      if( $parse =~ /\s*my\s*\((.*)\)\s*=\s*\@_\s*;/ ) # 'my ($a, $b)=@_' all in one line
	      {
		  $parameterNames = $1;
	      }
              elsif( $parse =~ /^\s*\{\s*my\s*\((.*)/ )		# 'my ( '  $1 = any parameters
	      {
		  ($parameterNames,$parameterString) = checkSubParameters($1);
	      }
           }
        }

	$paragraph = "(anchor:#$subName)\n\n$subName($parameterNames)\n............\n\n$paragraph\n";
	$paragraph .= $parameterString if defined $parameterString;
    }

# look for @EXPORT_OK, exported function block
    my @exportedFuncs;
    if( $parse =~ /\@EXPORT_OK\s*=\s*qw\(\s*(.*)\s*\);\s*/s ) # check '@EXPORT_OK = qw( funcName funcName2...);\n'
    {  
        #print "single EXP line:$1.\n";
	@exportedFuncs = split /\s+/, $1;

    }
    elsif( $parse =~ /\@EXPORT_OK\s*=\s*qw\(\s*(.*)\s*$/s )	# check '@EXPORT_OK = qw( funcName funcName2...\n'
    {  							# and more in folowing lines
        
	@exportedFuncs = split /\s+/, $1;
#	print "EXPORTED: $1";
	while( $parse = <IN_FILE> )
	{ 
	    if( $parse =~ /^\s*(.*)\s*\);\s*$/)		# end with '  func_m func_n  );'
	    {
	        push @exportedFuncs, split /\s+/, $1;
#		print " $1 |endExp\n";
		last;
	    }
	    elsif( $parse =~ /\)/s)			# end with '  );'
	    {	
#	        print "just endExp\n";
	        last;
	    }
	    elsif( $parse =~ /^\s*(.*)\s*$/)		# still in '  func_m func_n ...'
	    {
	        push @exportedFuncs, split /\s+/, $1;
#		print "inExp $1\n";
	    }
	}
    }

    if( scalar(@exportedFuncs) > 0 )			# create text for exported funcs
    {
	@exportedFuncs = map  {"($_:#$_)"} (sort(@exportedFuncs));
        $paragraph = "------------\n\nExported Functions\n==================\n\n" . join( ', ',@exportedFuncs) ."\n\n------------\n\n";
#	print "EXPORTED: $paragraph";
    }    
#    print $paragraph;
    $out_file .= $paragraph;
  }  # end while

#sub processSubParam
#{ my ($param) = @_;
#
#   my @params = split(/,\s*/, $param);
#
#   $param = undef;
#   foreach (@params)
#   {
#      $param .= "- $_\n";
#   }
#   
#   $param = "Parameters:\n.........\n\n$param\n" if( defined $param );
#   
#   return $param;
#}

# outfilename an optional 2'nd parameter, not used here, because 
# make copies the file to its destination
# if no outfilename is given, it becomes infilename.html withhout path
  my $outFileName;
  if( @ARGV ){ $outFileName = shift @ARGV;}

  if( ! $outFileName )
  { $outFileName = $inFileName;
#    $outFileName =~ s/(\w+)\.(\w+$)/$1.txt/;  # omit path
    $outFileName =~ s/(.*)\.\w+$/$1.txt/;     # with path
  } 
  print "write $outFileName\n";
  open(OUT_FILE, ">$outFileName") or die "can't open output file: $outFileName: $!";
  print OUT_FILE $out_file;
  close OUT_FILE;

# check parameters of the function. The '{ my(' is allready striped, 
# so there have to be some parameters! First parameter has to occur in the line with the '{ my('
#
#  look for parameters	| '$param   # description'
#  end flag		| ' ) = @_;'
sub   checkSubParameters
{ 
    my($parse) = @_;

    my $parameterNames;
    my $parameterString = "\n";
    while( $parse =~ /\s*\$\s*(.*)\s*\)*\s*\#\s*(.*)\s*$/ )
    {
	my $parName = $1;
	my $parDesc = $2;
	$parName =~ /^\s*([^, ]+)/;
	$parameterNames  .= "$1, ";
	$parameterString .= "$1\t| $parDesc\n";
	last if( $parse =~ /\)/ );
	$parse = <IN_FILE>;
    }

    $parameterString = "*  Parameter  :\n\n".$parameterString."\n\n";
    return ($parameterNames,$parameterString);
}