#!/bin/bash

# libra2db.sh

if [ "$#" != 3 ]; then
    echo "Usage: $0 /path/to/config /path/to/export <instance name>"
    exit;
fi

CONFIG="$1"
DIR="$2"
INSTANCE="$3"
EXPORTCAT="$DIR/exportCat.txt"
MARCXML="$DIR/bib/raw-records.marcxml"
OUTPUTDIR="$DIR/out"
IDMAP="$OUTPUTDIR/IdMap.txt"
MYSQL_CREDENTIALS="-u libra2koha -ppass libra2koha"
MYSQL="mysql $MYSQL_CREDENTIALS"
MYSQL_LOAD="mysql $MYSQL_CREDENTIALS --local-infile=1 --init-command='SET max_heap_table_size=4294967295;'"


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

if [[ ! -e "$MARCXML" ]]; then
   echo "Going to convert bibliographic records to MARCXML... "
   line2iso.pl -i "$EXPORTCAT" --xml $LINE2ISO_PARAMS > "$MARCXML"
   echo $MARCXML
   echo "done"
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
    table2config.pl "$DIR/Branches.txt" 0 2 > "$CONFIG/branchcodes.yaml"
fi
if [ ! -f "$CONFIG/loc.yaml" ]; then
    echo "Missing $CONFIG/loc.yaml"
    MISSING_FILE=1
    table2config.pl "$DIR/LocalShelfs.txt" 1 2 > "$CONFIG/loc.yaml"
fi
if [ ! -f "$CONFIG/ccode.yaml" ]; then
    echo "Missing $CONFIG/ccode.yaml"
    MISSING_FILE=1
    table2config.pl "$DIR/Departments.txt" 0 2 > "$CONFIG/ccode.yaml"
fi
if [ ! -f "$CONFIG/patroncategories.yaml" ]; then
    echo "Missing $CONFIG/patroncategories.yaml"
    MISSING_FILE=1
    table2config.pl "$DIR/BorrowerCategories.txt" 0 2 > "$CONFIG/patroncategories.yaml"
fi
if [ $MISSING_FILE -eq 1 ]; then
    exit
fi


### RECORDS ###

utf8dir="$(mktemp -d)"

for file in "$DIR"/*.txt  ; do
   if [[ -f  "$file" ]] ; then
      if [[ ! ( "$file" =~ spec\.txt$ ) ]]; then
         name="$(basename -s .txt "$file")"
	 specName="$name"spec
	 specFile="$DIR/$specName".txt
         if [[ ! -e "$specFile" && "$name" != 'exportCat' && "$name" != 'exportCatMatch' ]]; then
	    echo "No specification file corresponding to $file!" 1>&2
         else
	    if [[ "$name" == exportCat || "$name" == exportCatMatch ]] ; then
               enc=utf8
               numColumns=8
            else
               iconv -f utf16 -t utf8 "$specFile" > "$utf8dir"/"$specName".txt
               numColumns=$(wc -l "$utf8dir"/"$specName".txt | awk '{ print $1 }')
	       enc=utf16
	    fi
            if [[ $(stat -c %s "$file") == 2 ]] ; then
               # Skip, due to a bug in the GHC IO library that generates an error on a file containing
               # only the unicode byte order marker.  The bug exists in ghc 7.6.3-21 (Debian jessie) but appears to
               # have been fixed in ghc 7.10.3-7 (Ubuntu xenial)
               touch "$utf8dir"/"$name".txt
            elif [[ "$name" != exportCatMatch ]]; then
   	       delimtabletransform --num-columns=$numColumns          \
                                   --encoding=$enc                    \
                                   --column-delimiter='!*!'           \
                                   --row-delimiter='\n'               \
                                   --row-delimiter='\r\n'             \
                                   --enclosed-by='"'                  \
                                   --output-row-delimiter='!#!\r\n' "$file" > "$utf8dir"/"$name".txt
            else
               cp "$file" "$utf8dir"/exportCatMatch.txt
            fi
         fi
      fi
   fi
done

## Clean up the database
echo "DROP TABLE IF EXISTS exportCatMatch;" | $MYSQL
echo "DROP TABLE IF EXISTS Items         ;" | $MYSQL
echo "DROP TABLE IF EXISTS BarCodes      ;" | $MYSQL
echo "DROP TABLE IF EXISTS StatusCodes   ;" | $MYSQL

## Create tables and load the datafiles
echo -n "Going to create tables for records and items, and load data into MySQL... "
bib_tables="$(mktemp)"
create_tables.pl --dir "$utf8dir" --tables "exportCatMatch|Items|BarCodes|StatusCodes" > "$bib_tables"
eval $MYSQL_LOAD < "$bib_tables"
echo "ALTER TABLE Items ADD COLUMN done INT(1) DEFAULT 0;" | eval $MYSQL_LOAD
echo "done"


## Get the relevant info out of the database and into a .marcxml file
echo "Going to transform records... "
records.pl --config $CONFIG --infile $MARCXML --outputdir "$OUTPUTDIR" --flag_done $RECORDS_PARAMS
echo "done"

### BORROWERS ###

## Create tables and load the datafiles
echo -n "Going to create tables for borrowers, and load data into MySQL... "
create_tables.pl --dir "$utf8dir" --tables "Borrowers|BorrowerPhoneNumbers|BarCodes" | eval $MYSQL_LOAD
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
echo "DROP TABLE IF EXISTS Borrowers           ;" | $MYSQL
echo "DROP TABLE IF EXISTS Transactions        ;" | $MYSQL
echo "DROP TABLE IF EXISTS BorrowerPhoneNumbers;" | $MYSQL
echo "DROP TABLE IF EXISTS BarCodes            ;" | $MYSQL
echo "DROP TABLE IF EXISTS BorrowerBarCodes    ;" | $MYSQL
echo "DROP TABLE IF EXISTS ItemBarCodes        ;" | $MYSQL
# Don't confuse Isses.txt, which corresponds to issues of a serial, with issues,
# as in outstanding loans (in issues.sql).
echo "DROP TABLE IF EXISTS Issues              ;" | $MYSQL


# Create tables and load the datafiles
echo -n "Going to create tables for active issues, and load data into MySQL... "
create_tables.pl --dir "$utf8dir" --tables "Transactions|BarCodes|Issues" | eval $MYSQL_LOAD
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

sudo koha-shell -c "/usr/share/koha/bin/migration_tools/bulkmarcimport.pl -b -file '$OUTPUTDIR'/records.marcxml -v -commit 100 -m MARCXML -d -fk -idmap '$IDMAP'" "$INSTANCE"

$MYSQL_LOAD <<EOF
CREATE TABLE `IdMap` (
  original BIGINT UNIQUE NOT NULL,
  biblioitem BIGINT UNIQUE NOT NULL,
  PRIMARY KEY(`original`),
  KEY(`biblioitem`)
) ENGINE=MEMORY;
LOAD DATA LOCAL INFILE '$IDMAP' INTO TABLE `IdMap` CHARACTER SET utf8 FIELDS TERMINATED BY '|' LINES TERMINATED BY '\n';
EOF

