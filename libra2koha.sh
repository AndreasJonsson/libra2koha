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

# Create the output dir, if it is missing
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

### CHECK FOR CONFIG FILES ###

# Force the user to create necessary config files, and provide skeletons
MISSING_FILE=0
if [ ! -f "$CONFIG/config.yaml" ]; then
    echo "Missing $CONFIG/config.yaml"
    MISSING_FILE=1
    cp "$SCRIPTDIR/config_sample/config.yaml" "$CONFIG/"
fi
if [ ! -f "$CONFIG/branchcodes.yaml" ]; then
    echo "Missing $CONFIG/branchcodes.yaml"
    MISSING_FILE=1
    perl ./table2config.pl "$DIR/utf8/Branches.txt" 0 2 > "$CONFIG/branchcodes.yaml"
fi
if [ ! -f "$CONFIG/loc.yaml" ]; then
    echo "Missing $CONFIG/loc.yaml"
    MISSING_FILE=1
    perl ./table2config.pl "$DIR/utf8/LocalShelfs.txt" 0 2 > "$CONFIG/loc.yaml"
fi
if [ ! -f "$CONFIG/ccode.yaml" ]; then
    echo "Missing $CONFIG/ccode.yaml"
    MISSING_FILE=1
    perl ./table2config.pl "$DIR/utf8/Departments.txt" 0 2 > "$CONFIG/ccode.yaml"
fi
if [ ! -f "$CONFIG/patroncategories.yaml" ]; then
    echo "Missing $CONFIG/patroncategories.yaml"
    MISSING_FILE=1
    perl ./table2config.pl "$DIR/utf8/BorrowerCategories.txt" 0 2 > "$CONFIG/patroncategories.yaml"
fi
if [ $MISSING_FILE -eq 1 ]; then
    exit
fi

### RECORDS ###

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
echo "DROP TABLE IF EXISTS BorrowerBarCodes    ;" | $MYSQL
echo "DROP TABLE IF EXISTS ItemBarCodes        ;" | $MYSQL


# Create tables and load the datafiles
echo -n "Going to create tables for active issues, and load data into MySQL... "
perl ./create_tables.pl --dir $DIR --tables "Transactions|BarCodes" > ./issues_tables.sql
mysql --local-infile -u libra2koha -ppass libra2koha < ./issues_tables.sql
# Now copy the BarCodes table so we can have one for items and one for borrowers
echo "CREATE TABLE BorrowerBarCodes LIKE BarCodes;" | $MYSQL
echo "INSERT BorrowerBarCodes SELECT * FROM BarCodes;" | $MYSQL
echo "RENAME TABLE BarCodes TO ItemBarCodes;" | $MYSQL
echo "ALTER TABLE BorrowerBarCodes DROP COLUMN IdItem;" | $MYSQL
echo "DELETE FROM BorrowerBarCodes WHERE IdBorrower = 0;" | $MYSQL
echo "ALTER TABLE ItemBarCodes DROP COLUMN IdBorrower;" | $MYSQL
echo "DELETE FROM ItemBarCodes WHERE IdItem = 0;" | $MYSQL
echo "ALTER TABLE BorrowerBarCodes ADD PRIMARY KEY (IdBorrower);" | $MYSQL
echo "ALTER TABLE ItemBarCodes ADD PRIMARY KEY (IdItem);" | $MYSQL
echo "done"

# Get the relevant info out of the database and into a .sql file
echo "Going to transform issues... "
ISSUESSQL="$OUTPUTDIR/issues.sql"
if [ -f $ISSUESSQL ]; then
   rm $ISSUESSQL
fi
perl issues.pl --config $CONFIG >> $ISSUESSQL
echo "done writing to $ISSUESSQL"
