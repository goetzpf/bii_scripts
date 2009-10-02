eval 'exec perl -S $0 ${1+"$@"}'  # -*- Mode: perl -*-
	if $running_under_some_shell;
use BDNS;
use Getopt::Long;
##  bdns_sort.pl 
#  **************
#
#  - Sort all from standard in that ends with a Bessy device name. Means a list 
#    of device names or a list of e.g. gadget paths that end with a device name.
#  - The default order is (where/what): 'FACILITY,DOMAIN,SUBDOMPRE,SUBDOMNUMBER,MEMBER,INDEX,SUBINDEX,FAMILY,COUNTER'
#
#    bdns_sort.pl [-h -o='ORDER'] <STDIN >STDOUT  
#  
#
#  *  ORDER  is the optional sort order with some elements of:
#
#     MEMBER,INDEX,SUBINDEX,FAMILY,COUNTER,SUBDOMPRE,SUBDOMNUMBER,DOMAIN,FACILITY
#
#  *  Example  :
#
#      bdns_lookup.pl -d devices -u anonymous -p bessyguest VMI%|bdns_sort.pl
#      gaget.pl /EPICS-TOPS/BII-Controls/VacuumApp/IOCS2G/% |./bdns_sort.pl -o 'DOMAIN,MEMBER'
#      gaget.pl -h /EPICS-TOPS/BII-Controls/VacuumApp/IOCS2G "where TYPEDPATH not like '%[is%'"|bdns_sort.pl
#

our ($opt_h);
my $optOrder;
my $usage=  "bdns_sort.pl [-h -o='ORDER'] <STDIN >STDOUT\n\n".
    	    "* ORDER is the optional sort order with some elements of:\n".
	    "  'MEMBER,INDEX,SUBINDEX,FAMILY,COUNTER,SUBDOMPRE,SUBDOMNUMBER,DOMAIN,FACILITY'\n\n".
	    "* Example:\n".
	    "  bdns_lookup.pl -d devices -u anonymous -p bessyguest VMI%|bdns_sort.pl\n".
	    "  gaget.pl /EPICS-TOPS/BII-Controls/VacuumApp/IOCS2G/% |./bdns_sort.pl -o 'DOMAIN,MEMBER'\n";
die $usage unless GetOptions("h","o=s"=>\$optOrder);
if( defined $opt_h)
{
    print $usage;
    exit();
}
BDNS::setOrder($optOrder) if defined $optOrder;
push @n,$_ while <> ; 
print foreach (BDNS::sortNames(\@n));

