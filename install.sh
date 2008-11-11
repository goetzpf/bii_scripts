echo "darcs pull is executed in order to prevent"
echo "you from installing old program versions by accident"
darcs pull
make all
make install
