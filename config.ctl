# Configuration of bii_scripts installation at Bessy development hosts
# --------------------------------------------------------------------

# Variables that can be used to distribute the documentation files
# with rsync:

# Rsync configuration for program, library and share files installation:
# Rsync destination, may be "localhost", HOST or USER@HOST:
INSTALL_RSYNC_HOST=opiadm@nfs.ctl.bessy.de
# Rsync options, you usually don't have to change these:
INSTALL_RSYNC_OPTS=-crlEogC --chmod=a+r,Da+x
# Directory creation command. A make function, $(1) is the directory list:
INSTALL_MKDIR=mkdir -m 775 -p $(1)

# Rsync configuration HTML file installation:
# Rsync destination, may be "localhost", HOST or USER@HOST:
HTML_RSYNC_HOST=
# Rsync options, you usually don't have to change these:
HTML_RSYNC_OPTS=-crlEogC --chmod=a+r,Da+x
# Directory creation command. A make function, $(1) is the directory list:
HTML_MKDIR=mkdir -m 775 -p $(1)

# install directories .......................................

# INSTALL_PREFIX must be defined here or on the command line:
INSTALL_PREFIX=/opt/OPI/bii_scripts

# Directory where "share" files are installed:
SHARE_INSTALL_DIR=$(INSTALL_PREFIX)/share

# Directory where scripts are installed:
SCRIPT_INSTALL_DIR=$(INSTALL_PREFIX)/bin

# Directory where perl modules are installed:
PERLLIB_INSTALL_DIR=$(INSTALL_PREFIX)/lib/perl

# Directory where python 2 modules are installed. You may use variable
# PYTHON2VERSION here which contains the major and minor version number of
# python 2:
PYTHON2LIB_INSTALL_DIR=$(INSTALL_PREFIX)/lib/python

# Directory where python 3 modules are installed. You may use variable
# PYTHON2VERSION here which contains the major and minor version number of
# python 3:
PYTHON3LIB_INSTALL_DIR=$(INSTALL_PREFIX)/lib/python

# Root directory where the html documentation is copied to. If empty, do
# not install html documentation.
#HTML_INSTALL_DIR=$(INSTALL_PREFIX)/share/html/bii_scripts
HTML_INSTALL_DIR=
