package tokParse;

# Copyright 2015 Helmholtz-Zentrum Berlin für Materialien und Energie GmbH
# <https://www.helmholtz-berlin.de>
#
# Author: Bernhard Kuner <bernhard.kuner@helmholtz-berlin.de>
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

use strict;
use Data::Dumper;
BEGIN {

use Exporter   ( 
);
use vars       qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

# set the version number of the module to enable version checking
$VERSION     = 1.0;

@ISA       = qw(Exporter);
@EXPORT_OK = qw(
        	parse
        	dumpData
        	nextToken
	       );
%EXPORT_TAGS = ( );     # eg: TAG => [ qw!name1 name2! ],

# your exported package globals go here,
# as well as any optionally exported functions

# all functions this module exports:

@EXPORT   = qw( 
         );
};

## A Tokenizer: 
#
#  The Tokens are processed in the defined order.
#
#  *  Token definition  : a list of regexp containing one or three elements:
#
#  - One element: The regexp to rekognize the token
#  - Three elements: Token begin , Token content, Token limiter
#
#  *  Example  :
#
#    my @token = (
#        ['QUOTED_STR' , [qr(^"), qr(^(?:[^"\\\\]+|\\\\(?:.|\n))*), qr(")]],
#    	 ['SEPERATOR'  , [qr(^=)]]
#   	}
#
# *  Return:  a list of tokens
#
sub parse
{   my ($parse,     	# a string to be parsed
    	$rA_tokDefList, # the token definition list
	$mode  	    	# mode: 'undef' or 'ignoreSpace'
	)=@_;
    
    my $errStr;
    my @tokList;
    unshift @$rA_tokDefList, ['FORGETT_SPACE_CHARACTERS',[qr(^\s+)]] if $mode eq 'ignoreSpace';
#print Dumper($rA_tokDefList); 
    while($parse)
    {
    	my $tokContent;
	my $tokName;
	foreach (@$rA_tokDefList)
	{   
	    $tokName = $_->[0];
	    my $rA_tokDef = $_->[1];
	    my $tokRE = $rA_tokDef->[0];

	    if( $parse =~ $tokRE)
	    {	
#print "Found: token: '$tokName'='$tokRE' parse='$parse':";
	    	$parse=$';
    	    	$tokContent = $&;
	    	if( $tokName eq 'FORGETT_SPACE_CHARACTERS')
		{
#print "Ignore: token: '$tokName'='$tokRE' parse='$parse':";
		    $tokContent = undef;
		    last ;
		}
		$tokRE = $rA_tokDef->[1];
		if( defined $tokRE) # is a three RE token
		{
#print "\tTRY content: '$tokName', '$tokRE':";
		    if( $parse =~ $tokRE) # token content
		    {	
		    	$parse=$';
	    		$tokContent = $&;
		    	$tokRE = $rA_tokDef->[2];
#print "\t\tTRY delimiter: '$tokName', '$tokRE':";
			if( defined $tokRE && $parse =~ $tokRE) # token delimiter
			{
			    $parse=$';
			    last;
			}
			else
			{
			    $errStr .= "Can't find token delimiter for $tokContent***$parse";
			    last
			}
		    }
		    else
		    {
			$errStr .= "Can't find token Content for $parse";
		    }
		}
		else	# was a one RE token
		{
		    last;
		}
#print "END tokens";
	    }
	}
    	if( defined $tokContent && length($errStr)==0)
	{
#print "\nmatch '$tokName','$tokContent'\n";
	    push @tokList, [$tokName,$tokContent]
	}
	elsif( $tokName ne 'FORGETT_SPACE_CHARACTERS')
	{
	    $errStr = "Can't find token in: '$parse'" if( length($errStr)==0 );
	    warn "PARSE ERROR: ".$errStr;
	    return undef;
	}

    }
#print "TOK LIST = ",join(",",map{"$_->[0]='$_->[1]'"}@tokList),"\n";
    return \@tokList;
}

## Parse string for name value pairs.
#
#  *  Syntax:  NAME="VALUE",NAME2="VALUE2",...
#
#  *  Return:  Hash = {NAME=>"VALUE",NAME2=>"VALUE2"}
#
sub getSubstitutions
{   my($parse) = @_;

    my @token = (
        ['QSTR' , [qr(^"), qr(^(?:[^"\\\\]+|\\\\(?:.|\n))*), qr(")]],# matches a "quoted" string
    	['SEP_NV'  , [qr(^=)]],
    	['SEP_ITEM', [qr(^,)]],
        ['NAME' , [qr(^[a-zA-Z0-9_\-:\.\$]+)]]          # matches an unquoted string contains [a-zA-Z0-9_\-] followed by '='
	);

    my $rA_toks = tokParse::parse($parse,\@token,'ignoreSpace');
    die "PARSE ERROR" unless defined $rA_toks;
    my %subst;
#print " parse($parse) = ",Dumper($rA_toks);
    while(1)
    {
	my ($tokType,$tokVal) = nextToken($rA_toks);
#print "\t1 ($tokType,$tokVal) \tNAME || SEP_ITEM || undef\n";
	last unless defined $tokType;
     	($tokType,$tokVal) = nextToken($rA_toks) if $tokType eq 'SEP_ITEM';
	if($tokType eq 'NAME')
	{
	    my $name = $tokVal ;
	    ($tokType,$tokVal) = nextToken($rA_toks);;
#print "\t2 ($tokType,$tokVal) \tSEP_NV \n";
    	    return undef unless $tokType eq 'SEP_NV';
	    ($tokType,$tokVal) =nextToken($rA_toks);;
#print "\t3 ($tokType,$tokVal) \tQSTR\n";
    	    if($tokType eq 'QSTR' || $tokType eq 'NAME')
	    {
#print "FOUND: '$name' = '$tokVal'\n";
		$subst{$name} = $tokVal;
	    }
	    else
	    {
	    	return undef;
	    }
    	}
	else
	{
	    return undef;
	}
    }
    return \%subst;
}

## Get next token from token list returned from parse()
#
#  *  Return  : (tokType,tokValue) or (undef,undef) if list is empty
sub nextToken
{   my ($rA_tokList) = @_;
    
    my $nextTok = shift @$rA_tokList;
    return (undef,undef) unless defined $nextTok;
    return @$nextTok;
}
1;
