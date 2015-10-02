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
OUTPUTDIR="$DIR/out"
SCRIPTDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
MYSQL="mysql -u libra2koha -ppass libra2koha"

if [ ! -d "$OUTPUTDIR" ]; then
    mkdir "$OUTPUTDIR"
fi

### PREPARE FILES ###

# Fix encoding of Something.txt and Somethingspec.txt files 
if [ ! -d "$DIR/utf8/" ]; then
    mkdir "$DIR/utf8/"
fi
echo -n "Going to fix encoding of datafiles... "
for f in $DIR/*;  do
    if [ -f "$f" ]; then
        filename=$(basename "$f")
        if [ $filename != "exportCat.txt" ]; then
            # Fix the encoding
            iconv -f UTF-16 -t UTF-8 $f > "$DIR/utf8/$filename"
            # Remove lots of "null bytes" while we are at it
            perl -pi -e 's/\x00//g' "$DIR/utf8/$filename"
        fi
    fi
done
echo "done"

# FIXME Force the user to create necessary config files, and provide skeletons

### RECORDS ###

#if [ ! -d "$DIR/bib/" ]; then
#    mkdir "$DIR/bib/"
#fi
#echo "Going to convert bibliographic records to MARCXML... "
#cp $EXPORTCAT $EXPORTCAT_FIXED
#perl -pi -e 's/\r\n/\n/g' "$EXPORTCAT_FIXED"
#perl -pi -e '$/=undef; s/\^\n\*000/RECORD_SEPARATOR\n*000/g' "$EXPORTCAT_FIXED"
#perl -pi -e 's/\^\n//g' "$EXPORTCAT_FIXED"
#perl -pi -e 's/RECORD_SEPARATOR/^/g' "$EXPORTCAT_FIXED"

## FIXME Path to line2iso.pl should not be hardcoded
#perl ~/scripts/libriotools/line2iso.pl -i "$EXPORTCAT_FIXED" -x > "$MARCXML"
#echo $MARCXML
#echo "done"

## Create tables and load the datafiles
#echo -n "Going to create tables for records and items, and load data into MySQL... "
#cd $SCRIPTDIR
#perl ./create_tables.pl --dir $DIR --tables "exportCatMatch|Items|BarCodes|StatusCodes" > ./bib_tables.sql
#mysql --local-infile -u libra2koha -ppass libra2koha < ./bib_tables.sql
#echo "ALTER TABLE Items ADD COLUMN done INT(1) DEFAULT 0;" | mysql --local-infile -u libra2koha -ppass libra2koha
#echo "done"

## Get the relevant info out of the database and into a .marcxml file
#echo -n "Going to transform records... "
# FIXME Make records.pl write to $OUTPUTDIR
#perl records.pl --config $CONFIG --infile $MARCXML --flag_done
#echo "done"

### BORROWERS ###

## Clean up the database
#echo "DROP TABLE IF EXISTS exportCatMatch;" | $MYSQL
#echo "DROP TABLE IF EXISTS Items         ;" | $MYSQL
#echo "DROP TABLE IF EXISTS BarCodes      ;" | $MYSQL
#echo "DROP TABLE IF EXISTS StatusCodes   ;" | $MYSQL

## The borrowers data needs some special treatment
#perl fix_borrowers.pl "$DIR/utf8/Borrowers.txt"

## Create tables and load the datafiles
#echo -n "Going to create tables for borrowers, and load data into MySQL... "
#perl ./create_tables.pl --dir $DIR --tables "Borrowers|BorrowerPhoneNumbers|BarCodes" > ./borrowers_tables.sql
#mysql --local-infile -u libra2koha -ppass libra2koha < ./borrowers_tables.sql
#echo "DELETE FROM BarCodes WHERE IdBorrower = 0;" | $MYSQL
#echo "done"

## Get the relevant info out of the database and into a .sql file
#echo "Going to transform borrowers... "
#BORROWERSSQL="$OUTPUTDIR/borrowers.sql"
#if [ -f $BORROWERSSQL ]; then
#   rm $BORROWERSSQL
#fi
#perl borrowers.pl --config $CONFIG >> $BORROWERSSQL
#echo "done"

### ACTIVE ISSUES/LOANS ###

# Clean up the database
echo "DROP TABLE IF EXISTS Borrowers           ;" | $MYSQL
echo "DROP TABLE IF EXISTS BorrowerPhoneNumbers;" | $MYSQL
echo "DROP TABLE IF EXISTS BarCodes            ;" | $MYSQL

# Create tables and load the datafiles
echo -n "Going to create tables for active issues, and load data into MySQL... "
perl ./create_tables.pl --dir $DIR --tables "Borrowers|BorrowerPhoneNumbers|BarCodes" > ./issues_tables.sql
mysql --local-infile -u libra2koha -ppass libra2koha < ./issues_tables.sql
# echo "DELETE FROM BarCodes WHERE IdBorrower = 0;" | $MYSQL
echo "done"

# Get the relevant info out of the database and into a .sql file
echo "Going to transform issues... "
ISSUESSQL="$OUTPUTDIR/issues.sql"
if [ -f $ISSUESSQL ]; then
   rm $ISSUESSQL
fi
perl issuess.pl --config $CONFIG >> $ISSUESSQL
echo "done"
