#!/usr/bin/zsh

# Copyright 2022 Helmholtz-Zentrum Berlin für Materialien und Energie GmbH
# <https://www.helmholtz-berlin.de>
#
# Author: Goetz Pfeiffer <Goetz.Pfeiffer@helmholtz-berlin.de>
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
