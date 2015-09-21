#!/bin/bash

# libra2db.sh

if [ "$#" != 2 ]; then
    echo "Usage: $0 /path/to/config /path/to/export"
    exit;
fi

CONFIG=$1
DIR=$2
EXPORTCAT="$DIR/exportCat.txt"
EXPORTCAT_FIXED="$DIR/exportCat-fixed.txt"
MARCXML="$DIR/bib/raw-records.marcxml"
SCRIPTDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

### RECORDS ###

## Get the relevant info into the database

if [ ! -d "$DIR/bib/" ]; then
    mkdir "$DIR/bib/"
fi
echo "Going to convert bibliographic records to MARCXML... "
cp $EXPORTCAT $EXPORTCAT_FIXED
perl -pi -e 's/\r\n/\n/g' "$EXPORTCAT_FIXED"
perl -pi -e '$/=undef; s/\^\n\*000/RECORD_SEPARATOR\n*000/g' "$EXPORTCAT_FIXED"
perl -pi -e 's/\^\n//g' "$EXPORTCAT_FIXED"
perl -pi -e 's/RECORD_SEPARATOR/^/g' "$EXPORTCAT_FIXED"

# FIXME Path to line2iso.pl should not be hardcoded
perl ~/scripts/libriotools/line2iso.pl -i "$EXPORTCAT_FIXED" -x > "$MARCXML"
echo $MARCXML
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
            iconv -f UTF-16 -t UTF-8 $f > "$DIR/utf8/$filename"
        fi
    fi
done
echo "done"

# The borrowers data needs some special treatment
# FIXME Does not handle multiline comments
perl -pi -e '$/=undef; s/\r\n\r\n//g' "$DIR/utf8/Borrowers.txt"
perl -pi -e '$/=undef; s/\r\n/\n/g'   "$DIR/utf8/Borrowers.txt"

# Create tables and load the datafiles
echo -n "Going to create tables and load data into MySQL... "
cd $SCRIPTDIR
perl ./create_tables.pl --dir $DIR > ./tables.sql
mysql --local-infile -u libra2koha -ppass libra2koha < ./tables.sql 
echo "ALTER TABLE Items ADD COLUMN done INT(1) DEFAULT 0;" | mysql --local-infile -u libra2koha -ppass libra2koha
echo "done"

## Get the relevant info out of the database and into a .marcxml file

echo -n "Going to transform records... "
perl records.pl --config $CONFIG --limit 1000 --infile $MARCXML --flag_done
echo "done"
