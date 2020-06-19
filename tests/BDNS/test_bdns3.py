#/usr/bin/env python

import sys
from bii_scripts3 import BDNS

pvs=[]
for l in sys.stdin:
    l= l.rstrip()
    pvs.append(l)

print("parse test:")
for pv in pvs:
    x= BDNS.parse(pv)
    if x is None:
        print("%s:" % pv)
    else:
        print("%s:%s" % (pv,"|".join(x)))

print("\ntest of default sort:")

sort_pvs= BDNS.sortNames(pvs)
for pv in sort_pvs:
    print(pv)

order=["SUBDOMPRE", "COUNTER", "INDEX", "MEMBER", "FACILITY"]
print("\ntest of sort"," ".join(order))
BDNS.setOrder(order)
sort_pvs= BDNS.sortNames(pvs)
for pv in sort_pvs:
    print(pv)

print("\ntest of sort by"," ".join(order))
BDNS.setOrder("DEFAULT")
r_o= BDNS.mkOrder(order)
sort_pvs= BDNS.sortNamesBy(pvs,r_o)
for pv in sort_pvs:
    print(pv)

