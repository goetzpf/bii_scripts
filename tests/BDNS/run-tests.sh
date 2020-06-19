#!/bin/bash

cat PVLIST | perl test_bdns.pl > PERL
cat PVLIST | python2 test_bdns.py > PYTHON
cat PVLIST | python3 test_bdns3.py > PYTHON3

echo "Difference of files PERL and PYTHON:"
diff PERL PYTHON
echo
echo "Difference of files PERL and PYTHON3:"
diff PERL PYTHON3



