#!/bin/bash

# libra2db.sh

if [ "$#" != 1 ]; then
    echo "Usage: $0 /path/to/export"
    exit;
fi

DIR=$1
SCRIPTDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

# Convert bibliographic records to MARCXML - line2iso.pl from LibrioTools
if [ ! -d "$DIR/bib/" ]; then
    mkdir "$DIR/bib/"
fi
echo -n "Going to convert bibliographic records to MARCXML... "
perl ~/scripts/libriotools/line2iso.pl -i $DIR/exportCat.txt -x -l 1 > "$DIR/bib/raw-records.marcxml"
echo "done"

# Fix encoding of Something.txt and Somethingspec.txt files 
if [ ! -d "$DIR/utf8/" ]; then
    mkdir "$DIR/utf8/"
fi
echo -n "Going to fix encoding of datafiles... "
for f in $DIR/*;  do
    if [ -f "$f" ]; then
        filename=$(basename "$f")
        if [ $filename != "exportCat.txt" ]; then
            iconv -f utf-16 -t utf-8 $f > "$DIR/utf8/$filename"
        fi
    fi
done
echo "done"

# The borrowers data needs some special treatment
# FIXME Does not handle multiline comments
perl -pi -e '$/=undef; s/\r\n\r\n//g' "$DIR/utf8/Borrowers.txt"
perl -pi -e '$/=undef; s/\r\n/\n/g'   "$DIR/utf8/Borrowers.txt"

# Create tables and load the datafiles
echo -n "Going to load data into MySQL... "
cd $SCRIPTDIR
perl ./create_tables.pl --dir $DIR > ./tables.sql
mysql --local-infile -u libra2koha -ppass libra2koha < ./tables.sql 
echo "done"
