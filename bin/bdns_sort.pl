eval 'exec perl -S $0 ${1+"$@"}'  # -*- Mode: perl -*-
	if $running_under_some_shell;
use BDNS;
use Getopt::Long;
##  bdns_sort.pl [-h -o='ORDER'] <STDIN >STDOUT  
#  
#
# *  ORDER  is the optional sort order with some elements of:
#
# 'MEMBER,INDEX,SUBINDEX,FAMILY,COUNTER,SUBDOMPRE,SUBDOMNUMBER,DOMAIN,FACILITY'
#
# *  Example  :
#    gaget.pl /EPICS-TOPS/BII-Controls/VacuumApp/IOCS2G/% |./bdns_sort.pl -o 'DOMAIN,MEMBER'
#

our ($opt_h);
my $optOrder;
my $usage=  "bdns_sort.pl [-h -o='ORDER'] <STDIN >STDOUT\n\n".
    	    "* ORDER is the optional sort order with some elements of:\n".
	    "  'MEMBER,INDEX,SUBINDEX,FAMILY,COUNTER,SUBDOMPRE,SUBDOMNUMBER,DOMAIN,FACILITY'\n\n".
	    "* Example:\n".
	    "\gaget.pl /EPICS-TOPS/BII-Controls/VacuumApp/IOCS2G/% |./bdns_sort.pl -o 'DOMAIN,MEMBER'\n";
	    
die $usage unless GetOptions("h","o=s"=>\$optOrder);
if( defined $opt_h)
{
    print $usage;
    exit();
}
BDNS::setOrder($optOrder) if defined $optOrder;
push @n,$_ while <> ; 
print foreach (BDNS::sortNames(\@n));

