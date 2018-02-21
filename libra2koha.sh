#!/bin/bash

# libra2db.sh

#if [ "$#" != 3 ]; then
#    echo "Usage: $0 /path/to/config /path/to/export <instance name>"
#    exit;
#fi

dir="$(cd "$(dirname "$BASH_SOURCE")"; pwd -P)"

if [[ -e "$dir"/config.inc ]]; then
    . "$dir"/config.inc
fi

TABLEEXT=.txt
TABLEENC=iso-8859-1
INSTANCE="$3"
EXPORTCAT="$DIR/exportCat.txt"
OUTPUTDIR="$DIR/out"
IDMAP="$OUTPUTDIR/IdMap.txt"
MYSQL_CREDENTIALS="-u libra2koha -ppass libra2koha"
MYSQL="mysql $MYSQL_CREDENTIALS"
MYSQL_LOAD="mysql $MYSQL_CREDENTIALS --local-infile=1 --init-command='SET max_heap_table_size=4294967295;'"
FULL=no
QUICK=yes

SOURCE_FORMAT=bookit

if [[ $SOURCE_FORMAT == bookit ]]; then
    MARC="$DIR/*.iso2709"
else
    MARC="$DIR/CatalogueExport.dat"
fi

SPECDIR="$dir/${SOURCE_FORMAT}/spec"

COLUMN_DELIMITER='|'
HEADER_ROWS=1

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
export PERL5LIB="/usr/share/koha/lib:$PERL5LIB"
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
    table2config.pl --encoding=$TABLEENC --columndelim="$COLUMN_DELIMITER" --headerrows=$HEADER_ROWS --dir="$DIR" --name='GE_ORG' --key=0 --comment=13 > "$CONFIG/branchcodes.yaml"
fi
if [ ! -f "$CONFIG/loc.yaml" ]; then
    echo "Missing $CONFIG/loc.yaml"
    MISSING_FILE=1
    table2config.pl --encoding=$TABLEENC --columndelim="$COLUMN_DELIMITER" --headerrows=$HEADER_ROWS  --dir="$DIR" --name='CA_LOC' --key=0 --comment=1 --value=1 > "$CONFIG/loc.yaml"
fi
if [ ! -f "$CONFIG/ccode.yaml" ]; then
    echo "Missing $CONFIG/ccode.yaml"
    MISSING_FILE=1
    table2config.pl --encoding=$TABLEENC --columndelim="$COLUMN_DELIMITER" --headerrows=$HEADER_ROWS  --dir="$DIR" --name='GE_PREMISES' --key=0 --comment=5 > "$CONFIG/ccode.yaml"
fi
if [ ! -f "$CONFIG/patroncategories.yaml" ]; then
    echo "Missing $CONFIG/patroncategories.yaml"
    MISSING_FILE=1
    table2config.pl --encoding=$TABLEENC --columndelim="$COLUMN_DELIMITER" --headerrows=$HEADER_ROWS  --dir="$DIR" --name='CI_BORR_CAT' --key=0 --comment=3 > "$CONFIG/patroncategories.yaml"
fi
if [ $MISSING_FILE -eq 1 ]; then
    exit
fi


### RECORDS ###

#utf8dir="$(mktemp -d)"
utf8dir="${OUTPUTDIR}"/utf8dir
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
		 echo "Converting table ${name}"
		 delimtabletransform  --encoding=$TABLEENC               \
                                   --column-delimiter="$COLUMN_DELIMITER" \
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
if [[ "$QUICK"z != "yesz" ]]; then
cat <<'EOF' | $MYSQL;
SET FOREIGN_KEY_CHECKS = 0;
SET GROUP_CONCAT_MAX_LEN=32768;
SET @tables = NULL;
SELECT GROUP_CONCAT('`', table_name, '`') INTO @tables
  FROM information_schema.tables
  WHERE table_schema = (SELECT DATABASE());
SELECT IFNULL(@tables,'dummy') INTO @tables;

SET @tables = CONCAT('DROP TABLE IF EXISTS ', @tables);
PREPARE stmt FROM @tables;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
SET FOREIGN_KEY_CHECKS = 1;
EOF
fi

## Create tables and load the datafiles
if [[ "$QUICK"z != "yesz" ]]; then
echo -n "Going to create tables for records and items, and load data into MySQL... "
. "$SOURCE_FORMAT"/create_item_tables.sh
fi

if [[ "$FULL" == "yes" || ! -e "$OUTPUTDIR"/records.marc ]]; then
    ## Get the relevant info out of the database and into a .marcxml file
    echo "Going to transform records... "
    records.pl --branchcode "$BRANCHCODE" --config $CONFIG --format $SOURCE_FORMAT --infile "$MARC" --outputdir "$OUTPUTDIR" --flag_done $RECORDS_PARAMS
fi
echo "done"

### BORROWERS ###
if [[ "$QUICK"z != "yesz" ]]; then
## Create tables and load the datafiles
$MYSQL < mysql/valid_person_number.sql
echo -n "Going to create tables for borrowers, and load data into MySQL... "
. "$SOURCE_FORMAT"/create_borrower_tables.sh
echo "done"
fi

## Get the relevant info out of the database and into a .sql file
BORROWERSSQL="$OUTPUTDIR/borrowers.sql"
if [[ "$FULL" == "YES" || ! -e $BORROWERSSQL ]]; then
    echo "Going to transform borrowers... "
    TMPPERLIO=$PERLIO
    ## Koha's hash_password function fails if PERLIO is set to :utf8
    unset PERLIO
    perl borrowers.pl --format "$SOURCE_FORMAT" --config "$CONFIG" > $BORROWERSSQL
    export PERLIO=$TMPPERLIO
    echo "done"
fi

### ACTIVE ISSUES/LOANS ###


if [[ "$QUICK"z != "yesz" ]]; then
# Create tables and load the datafiles
echo -n "Going to create tables for active issues, and load data into MySQL... "
. "$SOURCE_FORMAT"/create_issue_tables.sh
echo "done"
fi

# Get the relevant info out of the database and into a .sql file
ISSUESSQL="$OUTPUTDIR/issues.sql"
if [[ "$FULL" == "YES" || ! -e $ISSUESSQL ]]; then
  echo "Going to transform issues... "
  issues.pl --format "$SOURCE_FORMAT" --config $CONFIG >> $ISSUESSQL
  echo "done writing to $ISSUESSQL"
fi

#echo "Serials"
#serials.pl --branchcode "$BRANCHCODE" --outputdir "$OUTPUTDIR" --config "$CONFIG"
echo "Reservations"
reservations.pl --format "$SOURCE_FORMAT" --configdir "$CONFIG" > "$OUTPUTDIR"/reservations.sql
if [[ "$FULL" == "YES" || ! -e "$OUTPUTDIR"/old_issues.sql ]]; then
  echo "Old issues"
  old_issues.pl  --format "$SOURCE_FORMAT" --configdir "$CONFIG" --branchcode "$BRANCHCODE" > "$OUTPUTDIR"/old_issues.sql
fi
echo "Account lines"
accountlines.pl  --format "$SOURCE_FORMAT" --configdir "$CONFIG" > "$OUTPUTDIR"/accountlines.sql

exit 0
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

