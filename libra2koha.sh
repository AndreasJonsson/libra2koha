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
ACTIVE_CATEGORIES=
CHILDREN_CATEGORY=
CHILDREN_MAXAGE=15
YOUTH_CATEGORY=
YOUTH_MAXAGE=17
CLEAR_BARCODES_ON_ORDERED=no
ORDERED_STATUSES=
HIDDEN_ARE_ORDERED=no
MANAGER_ID=1
DEFAULT_CATEGORY=STANDARD
ISSUES_BRANCHCODE=
SPECENCODING=iso-8859-1
STRING_ORIGINAL_ID=no
SEPARATE_ITEMS=yes
RECORD_MATCH_FIELD=
DETECT_BARCODE_DUPLICATION=yes
LIMIT=
XML_OUTPUT=no
FORCE_XML_INPUT=no
ENCODING_HACK=no
IGNORE_PERSNUMMER=yes
RECORD_PROCS=
INCLUDE_PASSWORDS=no
HAS_ITEMTABLE=yes
RECORD_SRC=
ITEMS_FORMAT=
BIBEXTRA_TABLE=
SPECDIR_OVERRIDE=
TABLEDIR=

SOURCE_FORMAT=bookit

COLUMN_DELIMITER='|'
ROW_DELIMITER=
QUOTE_CHAR='"'
ESCAPE_CHAR='\\'
HEADER_ROWS=1

if [[ -n "$1" ]]; then
    . "$1"
    if [[ -z "$DBNAME" ]]; then
	DBNAME="libra2koha";
    fi
elif [[ -e "$dir"/config.inc ]]; then
    echo include config INSTANCE $INSTANCE
    . "$dir"/config.inc
    if [[ -z "$DBNAME" ]]; then
	DBNAME="libra2koha";
    fi
fi

CUSTOM_LIBDIR=
if [[ -d "$(dirname "$DIR")/lib" ]]; then
    CUSTOM_LIBDIR="$(cd "$(dirname "$DIR")/lib"; pwd)"
fi
CUSTOM_SCRIPTDIR=
if [[ -d "$(dirname "$DIR")/scripts" ]]; then
    CUSTOM_SCRIPTDIR="$(cd "$(dirname "$DIR")/scripts"; pwd)"
fi


if [[ -e "$dir"/overrides.inc ]]; then
    . "$dir"/overrides.inc
fi

echo DIR $DIR dirname DIR $(dirname "$DIR")

EXPORTCAT="$DIR/exportCat.txt"
OUTPUTDIR="$(dirname "$DIR")/out"

mkdir -p "$OUTPUTDIR"

OUTPUTDIR="$(cd "$OUTPUTDIR"; pwd -P)"
IDMAP="$OUTPUTDIR/IdMap.txt"
MYSQL_CREDENTIALS="-u libra2koha -ppass $DBNAME"
MYSQL="mysql $MYSQL_CREDENTIALS"
MYSQL_LOAD="mysql $MYSQL_CREDENTIALS --local-infile=1 --init-command='SET max_heap_table_size=4294967295;'"

RECORDS_INPUT_FORMAT=

run_format_script () {
    script=$1

    if [[ -e "$CUSTOM_SCRIPTDIR"/"$script" ]]; then
	. "$CUSTOM_SCRIPTDIR"/"$script"
    elif [[ -e "$SOURCE_FORMAT"/"$script" ]]; then
	. "$SOURCE_FORMAT"/"$script"
    else
	echo "Warning: missing script for format $script" 1>&2
    fi
}

if [[ -n "$INPUT_MARC" ]]; then
    MARC="$DIR/$INPUT_MARC"
else
    if [[ $SOURCE_FORMAT == bookit ]]; then
	MARC="$DIR/*iso2709*"
    elif [[ $SOURCE_FORMAT == micromarc ]]; then
	BUILD_MARC_FILE=yes
	MARC="$OUTPUTDIR/catalogue.marc"
	RECORDS_INPUT_FORMAT=--xml-input
    elif [[ $SOURCE_FORMAT == sierra ]]; then
	MARC="$DIR/Bibliographic.mrc"
    else
	MARC="$DIR/CatalogueExport.dat"
    fi
fi

SPECDIR="$dir/${SOURCE_FORMAT}/spec:$DIR"
if [[ -n "$SPECDIR_OVERRIDE" ]]; then
    SPECDIR="$SPECDIR_OVERRIDE:$SPECDIR"
fi

if [[ "$FORCE_XML_INPUT" == yes ]]; then
    RECORDS_INPUT_FORMAT=--xml-input
fi

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
if [[ -n "$CUSTOM_LIBDIR" ]]; then
    export PERL5LIB="$CUSTOM_LIBDIR:$PERL5LIB"
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

if [[ "$SOURCE_FORMAT" == "marconly" ]]; then
    HAS_ITEMTABLE=no
fi

### RECORDS ###

if [[ "$TRANSFORM_TABLES" != "yes" || "$TABLEENC" == "utf-8" || "$TABLEENC" == "utf8" ]]; then
    transformed_tables=no
    if [[ -n "$TABLEDIR" ]]; then
	tabledir="$TABLEDIR"
    else
	tabledir="$DIR"
    fi
    mkdir -p "$tabledir"

    # Remove BOM if present
    for file in "$DIR"/*"${TABLEEXT}"; do
	if egrep '^\xEF\xBB\xBF' "$file" ; then
	    LC_ALL=C sed -i '1s/^\xEF\xBB\xBF//' "$file"
	fi
    done

else
    transformed_tables=yes
    if [[ -n "$TABLEDIR" ]]; then
	tabledir="$TABLEDIR"
    else
	tabledir="${OUTPUTDIR}"/utf8dir
    fi
    mkdir -p "$tabledir"

    for file in "$DIR"/*"${TABLEEXT}"  ; do
	if [[ -f  "$file" ]] ; then
	    if [[ ! ( "$file" =~ spec\.txt$ ) ]]; then
		name="$(basename -s "${TABLEEXT}" "$file")"
		specName="$name"spec
		while IFS=':' read -ra specdir ; do
		    for i in "${specdir[@]}"; do
			if [[ -e "$i/$specName".txt ]]; then
			    specFile="$i/$specName".txt
			    break 2
			fi
		    done
		done <<<"$SPECDIR"
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
					     --output-row-delimiter='\n'        \
					     --enclosed-by="$QUOTE_CHAR"        \
					     --null-literal                     \
					     "$file" > "$tabledir"/"${name}${TABLEEXT}"
		    fi
		fi
	    fi
	fi
    done


fi

declare -a TABLE_PARAMS=(--headerrows="$HEADER_ROWS" --spec="$SPECDIR" --specencoding="$SPECENCODING" --columndelimiter="$COLUMN_DELIMITER" --dir="$tabledir")

if [[ "$TRANSFORM_TABLES" == "yes" ]]; then
    TABLE_PARAMS[$((${#TABLE_PARAMS[*]} + 1))]=--encoding=utf-8
else
    TABLE_PARAMS[$((${#TABLE_PARAMS[*]} + 1))]=--encoding="$TABLEENC"
fi
if [[ -n "$QUOTE_CHAR" ]]; then
    TABLE_PARAMS[$((${#TABLE_PARAMS[*]} + 1))]=--quote="$QUOTE_CHAR"
fi
if [[ -n "$ESCAPE_CHAR" ]]; then
    TABLE_PARAMS[$((${#TABLE_PARAMS[*]} + 1))]=--escape="$ESCAPE_CHAR"
fi
if [[ -n "$TABLEEXT" ]]; then
    TABLE_PARAMS[$((${#TABLE_PARAMS[*]} + 1))]=--ext="$TABLEEXT"
fi
if [[ -n "$ROW_DELIMITER" && "$transformed_tables" != "yes" ]]; then
    TABLE_PARAMS[$((${#TABLE_PARAMS[*]} + 1))]=--rowdelimiter="$ROW_DELIMITER"
fi


### CHECK FOR CONFIG FILES ###

# Force the user to create necessary config files, and provide skeletons
MISSING_FILE=0
if [[ -e "$CUSTOM_SCRIPTDIR"/missing_config.inc ]] ; then
    . "$CUSTOM_SCRIPTDIR"/missing_config.inc
fi
. "$SOURCE_FORMAT/missing_config.inc"
if [ $MISSING_FILE -eq 1 ]; then
    exit
fi


## Clean up the database
if [[ "$QUICK"z != "yesz" ]]; then
    echo "Cleaning database! $MYSQL"
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
if [[ "$QUICK"z != "yesz" && "$HAS_ITEMTABLE"z == "yes" ]]; then
    echo -n "Going to create tables for records and items, and load data into MySQL... "
    run_format_script create_item_tables.sh
    echo "done"
fi

### BORROWERS ###
if [[ "$QUICK"z != "yesz" ]]; then
    ## Create tables and load the datafiles
    $MYSQL < "$dir"/mysql/valid_person_number.sql
    echo -n "Going to create tables for borrowers, and load data into MySQL... "
    run_format_script create_borrower_tables.sh
    echo "done"
fi

### ACTIVE ISSUES/LOANS ###
if [[ "$QUICK"z != "yesz" ]]; then
    # Create tables and load the datafiles
    echo -n "Going to create tables for active issues, and load data into MySQL... "
    run_format_script create_issue_tables.sh
    echo "done"
fi

if [[ "$QUICK"z != "yesz" ]]; then
    run_format_script create_serials_tables.sh
fi

if [[ "$QUICK"z != "yesz" && -n "$BIBEXTRA_TABLE" ]]; then
    echo BIBEXTRA_TABLE "$BIBEXTRA_TABLE"
    bib_tables="$(mktemp)"
    create_tables.pl --format="$SOURCE_FORMAT" "${TABLE_PARAMS[@]}" --table "$BIBEXTRA_TABLE" > "$bib_tables"
    eval $MYSQL_LOAD < "$bib_tables"
fi

if [[ "$FULL" == "yes" || ! -e "$OUTPUTDIR"/records.marc ]]; then
    ## Get the relevant info out of the database and into a .marcxml file
    echo "Going to transform records... "
    RECORDS_FLAGS=""
    if [[ "$CLEAR_BARCODES_ON_ORDERED" == "yes" ]]; then
	RECORDS_FLAGS+=" --clear-barcodes-on-ordered"
    fi
    if [[ "$TRUNCATE_PLESSEY" == "yes" ]]; then
	RECORDS_FLAGS+=" --truncate-plessey"
    fi
    if [[ "$HIDDEN_ARE_ORDERED" == "yes" ]]; then
	RECORDS_FLAGS+=" --hidden-are-ordered"
    fi
    if [[ "$STRING_ORIGINAL_ID" == "yes" ]]; then
	RECORDS_FLAGS+=" --string-original-id"
    fi
    if [[ "$SEPARATE_ITEMS" == "yes" ]]; then
	RECORDS_FLAGS+=" --separate-items"
    fi
    if [[ -n "$RECORD_MATCH_FIELD" ]]; then
	RECORDS_FLAGS+=" --record-match-field=$RECORD_MATCH_FIELD"
    fi
    if [[ "$DETECT_BARCODE_DUPLICATION" == "yes" ]]; then
	RECORDS_FLAGS+=" --detect-barcode-duplication"
	if [[ "$SEPARATE_ITEMS" != "yes" ]]; then
	    echo "DETECT_BARCODE_DUPLICATION requires SEPARATE_ITEMS!" 1>&2
	    exit 1
	fi
    fi
    if [[ -n "$LIMIT" ]]; then
	RECORDS_FLAGS+=" --limit=$LIMIT"
    fi
    if [[ "$XML_OUTPUT" == "yes" ]]; then
	RECORDS_FLAGS+=" --xml-output"
    fi
    if [[ "$ENCODING_HACK" == "yes" ]]; then
	RECORDS_FLAGS+=" --encoding-hack"
    fi
    if [[ -n "$RECORD_SRC" ]]; then
	RECORDS_FLAGS+=" --recordsrc=$RECORD_SRC"
    fi
    if [[ -n "$RECORD_PROCS" ]]; then
	RECORDS_FLAGS+=" --record-procs=$RECORD_PROCS"
    fi
    if [[ -n "$ITEM_PROCS" ]]; then
	RECORDS_FLAGS+=" --item-procs=$ITEM_PROCS"
    fi
    if [[ -n "$ORDERED_STATUSES" ]]; then
	RECORDS_FLAGS+=" --ordered-statuses=$ORDERED_STATUSES"
    fi
    if [[ "$HAS_ITEMTABLE" != "yes" ]] ; then
	RECORDS_FLAGS+=" --no-itemtable"
    else
	RECORDS_FLAGS+=" --flag-done"
    fi
    if [[ -n "$ITEMS_FORMAT" ]]; then
	RECORDS_FLAGS+=" --items-format=$ITEMS_FORMAT"
    fi
    echo -- records.pl $RECORDS_FLAGS --batch "$BATCH" --default-branchcode "$BRANCHCODE" --config $CONFIG --format $SOURCE_FORMAT --infile "$MARC" --outputdir "$OUTPUTDIR" $RECORDS_PARAMS $RECORDS_INPUT_FORMAT
    records.pl $RECORDS_FLAGS --batch "$BATCH" --default-branchcode "$BRANCHCODE" --config $CONFIG --format $SOURCE_FORMAT --infile "$MARC" --outputdir "$OUTPUTDIR" $RECORDS_PARAMS $RECORDS_INPUT_FORMAT
fi
echo "done"

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
    if [[ -n "$CHILDREN_MAXAGE" ]]; then
	BORROWERS_FLAGS="$BORROWERS_FLAGS --children-maxage=$(printf %q "$CHILDREN_MAXAGE")"
    fi
    if [[ -n "$YOUTH_CATEGORY" ]]; then
	BORROWERS_FLAGS="$BORROWERS_FLAGS --youth-category=$(printf %q "$YOUTH_CATEGORY")"
    fi
    if [[ -n "$YOUTH_MAXAGE" ]]; then
	BORROWERS_FLAGS="$BORROWERS_FLAGS --youth-maxage=$(printf %q "$YOUTH_MAXAGE")"
    fi
    if [[ -n "$MANAGER_ID" ]]; then
	BORROWERS_FLAGS+=" --manager-id=$MANAGER_ID"
    fi
    if [[ -n "$DEFAULT_CATEGORY" ]]; then
	BORROWERS_FLAGS+=" --default-category=$DEFAULT_CATEGORY"
    fi
    if [[ "$STRING_ORIGINAL_ID" == "yes" ]]; then
	BORROWERS_FLAGS+=" --string-original-id"
    fi
    if [[ "$IGNORE_PERSNUMMER" == "yes" ]]; then
        BORROWERS_FLAGS+=" --ignore-persnummer"
    fi
    if [[ "$INCLUDE_PASSWORDS" == "yes" ]]; then
	BORROWERS_FLAGS+=" --passwords"
    fi
    if [[ -n "$BORROWER_PROCS" ]]; then
	BORROWERS_FLAGS+=" --borrower-procs=$BORROWER_PROCS"
    fi
    if [[ -n "$ACTIVE_CATEGORIES" ]]; then
	BORROWERS_FLAGS+=" --active-categories=$ACTIVE_CATEGORIES"
    fi
    if [[ -n "$BORROWER_MATCHPOINT" ]]; then
	BORROWERS_FLAGS+=' '$(printf %q "--matchpoint=$BORROWER_MATCHPOINT")
    fi
    if [[ -n "$BORROWER_MATCHPOINT_EXPRESSION" ]]; then
	BORROWERS_FLAGS+=' '$(printf %q "--matchpoint-expression=$BORROWER_MATCHPOINT_EXPRESSION")
    fi
    if [[ -n "$BORROWER_MATCHPOINT_TYPE" ]]; then
	BORROWERS_FLAGS+=" --matchpoint-type='$BORROWER_MATCHPOINT_TYPE'"
    fi

    echo perl borrowers.pl "$BORROWERS_FLAGS"
    eval perl borrowers.pl $BORROWERS_FLAGS > $BORROWERSSQL
    echo "done"
    export PERLIO=$TMPPERLIO
fi


# Get the relevant info out of the database and into a .sql file
ISSUESSQL="$OUTPUTDIR/issues.sql"
if [[ "$FULL" == "yes" || ! -e $ISSUESSQL ]]; then
    echo "Going to transform issues... "

    ISSUES_FLAGS=
    if [[ -n "$ISSUES_BRANCHCODE" ]]; then
	ISSUES_FLAGS+=' '$(printf %q "--branchcode=$ISSUES_BRANCHCODE")
    fi
    if [[ "$STRING_ORIGINAL_ID" == "yes" ]]; then
	ISSUES_FLAGS+=" --string-original-id"
    fi

    eval issues.pl $ISSUES_FLAGS --batch "$BATCH" --format "$SOURCE_FORMAT" --config $CONFIG > $ISSUESSQL
    echo "done writing to $ISSUESSQL"
fi

if [[ "$FULL" == "yes" || ! -e "$OUTPUTDIR"/reservations.sql ]]; then
    echo "Reservations"
    RESERVATIONS_FLAGS=
    if [[ -n "$RECORD_MATCH_FIELD" ]]; then
	RESERVATIONS_FLAGS+=" --record-match-field=$RECORD_MATCH_FIELD"
    fi
    if [[ "$STRING_ORIGINAL_ID" == "yes" ]]; then
	RESERVATIONS_FLAGS+=" --string-original-id"
    fi

    reservations.pl $RESERVATIONS_FLAGS --batch "$BATCH" --format "$SOURCE_FORMAT" --configdir "$CONFIG" > "$OUTPUTDIR"/reservations.sql
fi

if [[ "$FULL" == "yes" || ! -e "$OUTPUTDIR"/orders.sql ]]; then
  echo "Orders"
  ORDERS_FLAGS=
  if [[ -n "$RECORD_MATCH_FIELD" ]]; then
     ORDERS_FLAGS+=" --record-match-field=$RECORD_MATCH_FIELD"
  fi
  if [[ "$STRING_ORIGINAL_ID" == "yes" ]]; then
     ORDERS_FLAGS+=" --string-original-id"
  fi
  orders.pl  $ORDERS_FLAGS --batch "$BATCH" --format "$SOURCE_FORMAT" --configdir "$CONFIG" --branchcode "$BRANCHCODE" > "$OUTPUTDIR"/orders.sql
fi

if [[ "$FULL" == "yes" || ! -e "$OUTPUTDIR"/old_issues_update.sql ]]; then
  echo "Old issues"
  old_issues.pl --batch "$BATCH" --format "$SOURCE_FORMAT" --configdir "$CONFIG" --branchcode "$BRANCHCODE" > "$OUTPUTDIR"/old_issues_update.sql
fi


if [[ true || "$FULL" == "yes" || ! -e "$OUTPUTDIR"/serials.sql ]]; then
    echo "Serials"
    serials.pl --batch "$BATCH" --format "$SOURCE_FORMAT" --branchcode "$BRANCHCODE" --outputdir "$OUTPUTDIR" --config "$CONFIG"
fi


if [[ "$FULL" == "yes" || ! -e "$OUTPUTDIR"/accountlines.sql ]]; then
    echo "Accountlines"
    accountlines.pl  --format "$SOURCE_FORMAT" --configdir "$CONFIG" > "$OUTPUTDIR"/accountlines.sql
fi

