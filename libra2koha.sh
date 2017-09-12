#!/bin/bash

# libra2db.sh

#if [ "$#" != 3 ]; then
#    echo "Usage: $0 /path/to/config /path/to/export <instance name>"
#    exit;
#fi

CONFIG=/home/aj/koha/Hjo/Config
DIR=/home/aj/koha/Hjo/Data
SPECDIR=/home/aj/spec
TABLEEXT=.csv
TABLEENC=utf16
INSTANCE="$3"
EXPORTCAT="$DIR/exportCat.txt"
MARC="$DIR/CatalogueExport.dat"
OUTPUTDIR="$DIR/out"
IDMAP="$OUTPUTDIR/IdMap.txt"
MYSQL_CREDENTIALS="-u libra2koha -ppass libra2koha"
MYSQL="mysql $MYSQL_CREDENTIALS"
MYSQL_LOAD="mysql $MYSQL_CREDENTIALS --local-infile=1 --init-command='SET max_heap_table_size=4294967295;'"

export PERLIO=:unix:utf8

if [[ -z "$SCRIPTDIR" ]]; then
   SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd -P)"
fi
if [[ "$LIBRA2KOHA_DELIMITED_FORMAT" == "1" ]]; then
  LINE2ISO_PARAMS=--delimited
  RECORDS_PARAMS=--explicit-record-id
else
  LINE2ISO_PARAMS=
  RECORDS_PARAMS=
fi
if [[ -z "$LIBRIOTOOLS_DIR" ]]; then
   export LIBRIOTOOLS_DIR=../LibrioTools
fi
if [[ -n "$PERL5LIB" ]]; then
   export PERL5LIB="$LIBRIOTOOLS_DIR"/lib:"$SCRIPTDIR"/lib:"$PERL5LIB"
else
   export PERL5LIB="$LIBRIOTOOLS_DIR"/lib:"$SCRIPTDIR"/lib
fi
if [[ -z "$LIBRA2KOHA_NOCONFIRM" ]] ; then
   export LIBRA2KOHA_NOCONFIRM=0
fi
export PATH="$SCRIPTDIR:$LIBRIOTOOLS_DIR:$PATH"

# Create the output dir, if it is missing
if [ ! -d "$OUTPUTDIR" ]; then
    mkdir "$OUTPUTDIR"
fi

#
# A temporary directory.
#
export TMPDIR=$(mktemp -d)

trap 'rm -rf "$TMPDIR"' EXIT INT TERM HUP

set -o errexit

### PREPARE FILES ###

if [ ! -d "$DIR/bib/" ]; then
    mkdir "$DIR/bib/"
fi


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
    echo table2config.pl --columndelim='	' --headerrows=2 --dir="$DIR" --name='Branches' --key=0 --comment=2 > "$CONFIG/branchcodes.yaml"
    table2config.pl --columndelim='	' --headerrows=2 --dir="$DIR" --name='Branches' --key=0 --comment=2 > "$CONFIG/branchcodes.yaml"
fi
if [ ! -f "$CONFIG/loc.yaml" ]; then
    echo "Missing $CONFIG/loc.yaml"
    MISSING_FILE=1
    table2config.pl --columndelim='	' --headerrows=2  --dir="$DIR" --name='LocalShelfs' --key=1 --comment=2 > "$CONFIG/loc.yaml"
fi
if [ ! -f "$CONFIG/ccode.yaml" ]; then
    echo "Missing $CONFIG/ccode.yaml"
    MISSING_FILE=1
    table2config.pl --columndelim='	' --headerrows=2  --dir="$DIR/" --name='Departments' --key=0 --comment=2 > "$CONFIG/ccode.yaml"
fi
if [ ! -f "$CONFIG/patroncategories.yaml" ]; then
    echo "Missing $CONFIG/patroncategories.yaml"
    MISSING_FILE=1
    table2config.pl --columndelim='	' --headerrows=2  --dir="$DIR" --name='BorrowerCategories' --key=0 --comment=2 > "$CONFIG/patroncategories.yaml"
fi
if [ $MISSING_FILE -eq 1 ]; then
    exit
fi


### RECORDS ###

#utf8dir="$(mktemp -d)"
utf8dir=/home/aj/utf8dir
mkdir -p "$utf8dir"

for file in "$DIR"/*"${TABLEEXT}"  ; do
   if [[ -f  "$file" ]] ; then
      if [[ ! ( "$file" =~ spec\.txt$ ) ]]; then
         name="$(basename -s "${TABLEEXT}" "$file")"
	 specName="$name"spec
	 specFile="$SPECDIR/$specName".txt
         if [[ ! -e "$specFile" && "$name" != 'exportCat' && "$name" != 'exportCatMatch' ]]; then
	    echo "No specification file corresponding to $file!" 1>&2
         elif [[ ! -e "$utf8dir"/"$name""${TABLEEXT}" ]]; then
             if [[ "$name" == exportCat || "$name" == exportCatMatch ]] ; then
		 enc=utf8
		 numColumns=8
             else
		 numColumns=$(wc -l $specFile | awk '{ print $1 }')
		 enc=$TABLEENC
             fi
	     
             if [[ $(stat -c %s "$file") == 2 ]] ; then
		 # Skip, due to a bug in the GHC IO library that generates an error on a file containing
		 # only the unicode byte order marker.  The bug exists in ghc 7.6.3-21 (Debian jessie) but appears to
		 # have been fixed in ghc 7.10.3-7 (Ubuntu xenial)
 		touch "$utf8dir"/"$name""${TABLEEXT}"
	     else
		 delimtabletransform  --encoding=$TABLEENC               \
                                   --column-delimiter='\t'            \
                                   --row-delimiter='\n'               \
                                   --row-delimiter='\r\n'             \
                                   --enclosed-by='"'                  \
				   --null-literal                     \
                                   "$file" > "$utf8dir"/"${name}${TABLEEXT}"
             fi
         fi
      fi
   fi
done


tabledir="$utf8dir"
#tabledir="$DIR"

## Clean up the database
echo "DROP TABLE IF EXISTS exportCatMatch;" | $MYSQL
echo "DROP TABLE IF EXISTS Items         ;" | $MYSQL
echo "DROP TABLE IF EXISTS BarCodes      ;" | $MYSQL
echo "DROP TABLE IF EXISTS StatusCodes   ;" | $MYSQL
echo "DROP TABLE IF EXISTS Borrowers           ;" | $MYSQL
echo "DROP TABLE IF EXISTS BorrowerAddresses     ;" | $MYSQL
echo "DROP TABLE IF EXISTS BorrowerPhoneNumbers;" | $MYSQL
echo "DROP TABLE IF EXISTS BorrowerRegId;" | $MYSQL

## Create tables and load the datafiles
echo -n "Going to create tables for records and items, and load data into MySQL... "
bib_tables="$(mktemp)"
create_tables.pl --quote='"' --headerrows=2 --encoding=utf8 --ext=.csv --spec "$SPECDIR" --columndelimiter='	' --rowdelimiter='\r\n' --dir "$tabledir" --table 'Items' --table 'BarCodes' --table 'StatusCodes' --table 'CA_CATALOG' > "$bib_tables"
eval $MYSQL_LOAD < "$bib_tables"
eval $MYSQL_LOAD <<EOF 
ALTER TABLE Items ADD COLUMN done INT(1) DEFAULT 0;
CREATE UNIQUE INDEX ca_catalog_title_no_index  ON CA_CATALOG (TITLE_NO);
CREATE UNIQUE INDEX items_itemid_index ON Items (IdItem);
CREATE INDEX barcode_iditem_index ON BarCodes (IdItem);
CREATE INDEX items_catid_index ON Items (IdCat);
CREATE INDEX CA_CATALOG_ID_index ON CA_CATALOG (CA_CATALOG_ID);
EOF

## Get the relevant info out of the database and into a .marcxml file
echo "Going to transform records... "
if [[ ! -e "$OUTPUTDIR"/records.marc ]]; then
    records.pl --config $CONFIG --infile $MARC --outputdir "$OUTPUTDIR" --flag_done $RECORDS_PARAMS
fi
echo "done"

### BORROWERS ###

## Create tables and load the datafiles
echo -n "Going to create tables for borrowers, and load data into MySQL... "
create_tables.pl  --quote='"' --headerrows=2 --encoding=utf8 --ext=.csv  --spec "$SPECDIR" --columndelimiter='	' --rowdelimiter='\r\n' --dir "$tabledir" --table "Borrowers" --table "BorrowerPhoneNumbers" --table "BarCodes" --table "BorrowerAddresses" --table "BorrowerRegId"
create_tables.pl  --quote='"' --headerrows=2 --encoding=utf8 --ext=.csv  --spec "$SPECDIR" --columndelimiter='	' --rowdelimiter='\r\n' --dir "$tabledir" --table "Borrowers" --table "BorrowerPhoneNumbers" --table "BarCodes" --table "BorrowerAddresses" --table "BorrowerRegId" | eval $MYSQL_LOAD
echo "DELETE FROM BarCodes WHERE IdBorrower = 0;" | $MYSQL
echo "done"

## Get the relevant info out of the database and into a .sql file
echo "Going to transform borrowers... "
BORROWERSSQL="$OUTPUTDIR/borrowers.sql"
if [ -f $BORROWERSSQL ]; then
   rm $BORROWERSSQL
fi
perl borrowers.pl --config $CONFIG >> $BORROWERSSQL
echo "done"

### ACTIVE ISSUES/LOANS ###

# Clean up the database
echo "DROP TABLE IF EXISTS Transactions        ;" | $MYSQL
echo "DROP TABLE IF EXISTS BarCodes            ;" | $MYSQL
echo "DROP TABLE IF EXISTS BorrowerBarCodes    ;" | $MYSQL
echo "DROP TABLE IF EXISTS ItemBarCodes        ;" | $MYSQL
# Don't confuse Isses"${TABLEEXT}", which corresponds to issues of a serial, with issues,
# as in outstanding loans (in issues.sql).
echo "DROP TABLE IF EXISTS Issues              ;" | $MYSQL


# Create tables and load the datafiles
echo -n "Going to create tables for active issues, and load data into MySQL... "
create_tables.pl  --quote='"' --headerrows=2 --encoding=utf8 --ext=.csv  --spec "$SPECDIR" --columndelimiter='	' --rowdelimiter='\r\n' --dir "$tabledir" --table "Transactions" --table "BarCodes" --table "Issues" | eval $MYSQL_LOAD
# Now copy the BarCodes table so we can have one for items and one for borrowers
$MYSQL <<EOF
CREATE TABLE BorrowerBarCodes LIKE BarCodes;
INSERT BorrowerBarCodes SELECT * FROM BarCodes;
RENAME TABLE BarCodes TO ItemBarCodes;
ALTER TABLE BorrowerBarCodes DROP COLUMN IdItem;
DELETE FROM BorrowerBarCodes WHERE IdBorrower IS NULL;
ALTER TABLE ItemBarCodes DROP COLUMN IdBorrower;
DELETE FROM ItemBarCodes WHERE IdItem IS NULL;
ALTER TABLE BorrowerBarCodes ADD PRIMARY KEY (IdBorrower);
ALTER TABLE ItemBarCodes ADD PRIMARY KEY (IdItem);
CREATE INDEX transaction_idborrower_index ON Transactions (IdBorrower);
CREATE INDEX transaction_iditem_index ON Transactions (IdItem);
EOF
echo "done"

# Get the relevant info out of the database and into a .sql file
echo "Going to transform issues... "
ISSUESSQL="$OUTPUTDIR/issues.sql"
if [ -f $ISSUESSQL ]; then
   rm $ISSUESSQL
fi
issues.pl --config $CONFIG >> $ISSUESSQL
echo "done writing to $ISSUESSQL"

if [[ $LIBRA2KOHA_NOCONFIRM != '1' ]]; then
    confirm="no"
    read -e -i no -p "Are you prepared to import to $INSTANCE? (This will delete existing records.)" confirm

    if [[ "$confirm" != "yes" ]]; then
        echo "Answer is not 'yes', exiting..." 1>&2
        exit 0
    fi
fi

##
## XXX
##
echo "TODO: The -idmap parameter to the bulkmarcimport.pl script doesn't work as expected.  To make this work you will need to hack the bulkmarcimport.pl script." 2>&1
echo "      (This is only needed to generate serials.sql, though)." 2>&1
exit 0
sudo koha-shell -c "/usr/share/koha/bin/migration_tools/bulkmarcimport.pl -b -file '$OUTPUTDIR'/records.marc -v -commit 100 -m MARCXML -d -fk -idmap '$IDMAP'" "$INSTANCE"

eval $MYSQL_LOAD <<EOF
DROP TABLE IF EXISTS IdMap;
CREATE TABLE IdMap (
  original BIGINT UNIQUE NOT NULL,
  biblioitem BIGINT UNIQUE NOT NULL,
  PRIMARY KEY(original),
  KEY(biblioitem)
) ENGINE=MEMORY;
LOAD DATA LOCAL INFILE '$IDMAP' INTO TABLE IdMap CHARACTER SET utf8 FIELDS TERMINATED BY '|' LINES TERMINATED BY '\\n';
EOF

serials.pl --outputdir "$OUTPUTDIR" --config "$CONFIG"
