#!/bin/bash

# libra2db.sh

#if [ "$#" != 3 ]; then
#    echo "Usage: $0 /path/to/config /path/to/export <instance name>"
#    exit;
#fi

dir="$(cd "$(dirname "$BASH_SOURCE")"; pwd -P)"

TABLEEXT=.txt
TABLEENC=iso-8859-1
FULL=no
QUICK=yes
BUILD_MARC_FILE=no
TRANSFORM_TABLES=yes
EXPIRE_ALL_BORROWERS=no
CHILDREN_CATEGORY=

SOURCE_FORMAT=bookit

COLUMN_DELIMITER='|'
ROW_DELIMITER="
"
QUOTE_CHAR='"'
ESCAPE_CHAR='\\'
HEADER_ROWS=1


if [[ -e "$dir"/config.inc ]]; then
    . "$dir"/config.inc
fi

INSTANCE="$3"
EXPORTCAT="$DIR/exportCat.txt"
OUTPUTDIR="$DIR/out"
IDMAP="$OUTPUTDIR/IdMap.txt"
MYSQL_CREDENTIALS="-u libra2koha -ppass libra2koha"
MYSQL="mysql $MYSQL_CREDENTIALS"
MYSQL_LOAD="mysql $MYSQL_CREDENTIALS --local-infile=1 --init-command='SET max_heap_table_size=4294967295;'"

echo "Source format: $SOURCE_FORMAT"

RECORDS_INPUT_FORMAT=

if [[ $SOURCE_FORMAT == bookit ]]; then
    MARC="$DIR/*.iso2709"
elif [[ $SOURCE_FORMAT == micromarc ]]; then
    BUILD_MARC_FILE=yes
    MARC="$OUTPUTDIR/catalogue.marc"
    RECORDS_INPUT_FORMAT=--xml
else
    MARC="$DIR/CatalogueExport.dat"
fi

SPECDIR="$dir/${SOURCE_FORMAT}/spec"

export PERLIO=:unix:utf8

if [[ -z "$SCRIPTDIR" ]]; then
   SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd -P)"
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
. "$SOURCE_FORMAT/missing_tables.inc"
if [ $MISSING_FILE -eq 1 ]; then
    exit
fi


### RECORDS ###

if [[ "$TRANSFORM_TABLES" != "yes" || "$TABLEENC" == "utf-8" ]]; then
    tabledir="$DIR"
else
    tabledir="${OUTPUTDIR}"/utf8dir
    mkdir -p "$tabledir"

    for file in "$DIR"/*"${TABLEEXT}"  ; do
	if [[ -f  "$file" ]] ; then
	    if [[ ! ( "$file" =~ spec\.txt$ ) ]]; then
		name="$(basename -s "${TABLEEXT}" "$file")"
		specName="$name"spec
		specFile="$SPECDIR/$specName".txt
		if [[ ! -e "$specFile" && "$name" != 'exportCat' && "$name" != 'exportCatMatch' ]]; then
		    echo "No specification file corresponding to $file!" 1>&2
		elif [[ ! -e "$tabledir"/"$name""${TABLEEXT}" ]]; then
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
 			touch "$tabledir"/"$name""${TABLEEXT}"
		    else
			echo "Converting table ${name}"
			delimtabletransform  --encoding=$TABLEENC               \
					     --column-delimiter="$COLUMN_DELIMITER" \
					     --row-delimiter='\n'               \
					     --row-delimiter='\r\n'             \
					     --enclosed-by="$QUOTE_CHAR"        \
					     --null-literal                     \
					     "$file" > "$tabledir"/"${name}${TABLEEXT}"
		    fi
		fi
	    fi
	fi
    done


fi

## Clean up the database
if [[ "$QUICK"z != "yesz" ]]; then
    echo "Cleaning database!"
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

if [[ "$BUILD_MARC_FILE" == "yes" && ( "$FULL" == "yes" || ! -e "$MARC" ) ]]; then
   . "$SOURCE_FORMAT"/create_marc_records.sh
fi

## Create tables and load the datafiles
if [[ "$QUICK"z != "yesz" ]]; then
echo -n "Going to create tables for records and items, and load data into MySQL... "
. "$SOURCE_FORMAT"/create_item_tables.sh
fi

if [[ "$FULL" == "yes" || ! -e "$OUTPUTDIR"/records.marc ]]; then
    ## Get the relevant info out of the database and into a .marcxml file
    echo "Going to transform records... "
    records.pl --batch "$BATCH" --default-branchcode "$BRANCHCODE" --config $CONFIG --format $SOURCE_FORMAT --infile "$MARC" --outputdir "$OUTPUTDIR" $RECORDS_PARAMS $RECORDS_INPUT_FORMAT
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
if [[ "$FULL" == "yes" || ! -e $BORROWERSSQL ]]; then
    echo "Going to transform borrowers... "
    TMPPERLIO=$PERLIO
    ## Koha's hash_password function fails if PERLIO is set to :utf8
    unset PERLIO
    BORROWERS_FLAGS="--batch $(printf %q "$BATCH") --format $(printf %q "$SOURCE_FORMAT") --config $(printf %q "$CONFIG")"
    if [[ "$EXPIRE_ALL_BORROWERS" == "yes" ]]; then
	BORROWERS_FLAGS="$BORROWERS_FLAGS --expire-all"
    fi
    if [[ -n "$CHILDREN_CATEGORY" ]]; then
	BORROWERS_FLAGS="$BORROWERS_FLAGS --children-category=$(printf %q "$CHILDREN_CATEGORY")"
    fi
    echo perl borrowers.pl $BORROWERS_FLAGS
    perl borrowers.pl $BORROWERS_FLAGS > $BORROWERSSQL
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
if [[ "$FULL" == "yes" || ! -e $ISSUESSQL ]]; then
  echo "Going to transform issues... "
  issues.pl --format "$SOURCE_FORMAT" --config $CONFIG >> $ISSUESSQL
  echo "done writing to $ISSUESSQL"
fi

if [[ "$FULL" == "yes" || ! -e "$OUTPUTDIR"/serials.sql ]]; then
    echo "Serials"
    serials.pl --branchcode "$BRANCHCODE" --outputdir "$OUTPUTDIR" --config "$CONFIG"
fi


if [[ "$FULL" == "yes" || ! -e "$OUTPUTDIR"/reservations.sql ]]; then
    echo "Reservations"
    reservations.pl --format "$SOURCE_FORMAT" --configdir "$CONFIG" > "$OUTPUTDIR"/reservations.sql
fi
if [[ "$FULL" == "yes" || ! -e "$OUTPUTDIR"/old_issues.sql ]]; then
  echo "Old issues"
  old_issues.pl  --format "$SOURCE_FORMAT" --configdir "$CONFIG" --branchcode "$BRANCHCODE" > "$OUTPUTDIR"/old_issues.sql
fi
#echo "Account lines"
if [[ "$FULL" == "yes" || ! -e "$OUTPUTDIR"/accountlines.sql ]]; then
    echo "Accountlines"
    accountlines.pl  --format "$SOURCE_FORMAT" --configdir "$CONFIG" > "$OUTPUTDIR"/accountlines.sql
fi

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

