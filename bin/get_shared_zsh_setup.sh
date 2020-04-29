#!/usr/bin/zsh

REPO=repo.acc.bessy.de:/opt/repositories/controls/darcs/share/zsh
TARGET=share/zsh

yesno () {
    print -n $1 "(y/N): "
    read -k1 ans
    print
    [[ $ans:u = "Y" ]]
}

cd

print "Installing/updating shared zsh-environment in $TARGET"
print

if [[ -d $TARGET ]]
then
    if [[ -d $TARGET/_darcs ]]
    then
	print "You already seem to have a checked out version of the shared zsh environment."
	yesno "Would you like to update it?" && {
	    pushd $TARGET
	    darcs pull
	    popd
	}
	exit
    else
	print "An existing directory $TARGET is blocking installation!"
	print "Please move/rename/delete it to enable installation of the shared zsh-environment."
	exit 1
    fi
else
    print "Checking out shared zsh-environment from $REPO"
    mkdir -p $TARGET:h
    pushd $TARGET:h
    darcs get $REPO $TARGET:t || exit 1
    popd
    cd
    if [[ -e .zshenv ]]
    then
	print "Renaming existing ~/.zshenv to ~/.zshextraenv"
	mv .zshenv .zshextraenv
    fi
    print "Linking .zshenv to $TARGET/.zshenv"
    ln -s $TARGET/.zshenv .zshenv
fi
print "done.\n"
print "You may now re-start your shell."
