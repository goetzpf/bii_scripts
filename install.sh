echo "darcs pull is executed in order to prevent"
echo "you from installing old program versions by accident"
darcs pull
make all
if test $(uname -n) != "aragon"; then
  sg scrptdev -c "make install"
else
  make install
fi
