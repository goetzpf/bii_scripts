#!/bin/sh

CSS_SRC_PATH=../../../doc/html
CSS_SRC_FILE=docStyle.css 
DEST_DIR=blib/html

mkdir -p $DEST_DIR
cp $CSS_SRC_PATH/$CSS_SRC_FILE $DEST_DIR
pod2html -css $CSS_SRC_FILE Pezca.pm > $DEST_DIR/Pezca.html

