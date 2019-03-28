if [ ! -f "$CONFIG/config.yaml" ]; then
    echo "Missing $CONFIG/config.yaml"
    MISSING_FILE=1
    cp "$SCRIPTDIR/config_sample/config.yaml" "$CONFIG/"
fi
if [ ! -f "$CONFIG/branchcodes.yaml" ]; then
    echo "Missing $CONFIG/branchcodes.yaml"
    MISSING_FILE=1
    table2config.pl --columndelim="$COLUMN_DELIMITER" --quote="$QUOTE_CHAR" --headerrows=$HEADER_ROWS --dir="$DIR" --name='Branches' --key=0 --comment=2 > "$CONFIG/branchcodes.yaml"
fi
if [ ! -f "$CONFIG/loc.yaml" ]; then
    echo "Missing $CONFIG/loc.yaml"
    MISSING_FILE=1
    table2config.pl --columndelim="$COLUMN_DELIMITER" --quote="$QUOTE_CHAR" --headerrows=$HEADER_ROWS --dir="$DIR" --name='LocalShelfs' --key=1 --comment=2 > "$CONFIG/loc.yaml"
fi
if [ ! -f "$CONFIG/ccode.yaml" ]; then
    echo "Missing $CONFIG/ccode.yaml"
    MISSING_FILE=1
    table2config.pl --columndelim="$COLUMN_DELIMITER" --quote="$QUOTE_CHAR" --headerrows=$HEADER_ROWS --dir="$DIR/" --name='Departments' --key=0 --comment=2 > "$CONFIG/ccode.yaml"
fi
if [ ! -f "$CONFIG/patroncategories.yaml" ]; then
    echo "Missing $CONFIG/patroncategories.yaml"
    MISSING_FILE=1
    table2config.pl --columndelim="$COLUMN_DELIMITER" --quote="$QUOTE_CHAR" --headerrows=$HEADER_ROWS --dir="$DIR" --name='BorrowerCategories' --key=0 --comment=2 > "$CONFIG/patroncategories.yaml"
fi
if [ ! -f "$CONFIG/damaged.yaml" ]; then
    echo "Missing $CONFIG/damaged.yaml"
    MISSING_FILE=1
    table2config.pl --columndelim="$COLUMN_DELIMITER" --quote="$QUOTE_CHAR" --headerrows=$HEADER_ROWS  --dir="$DIR" --name='StatusCodes' --key=0 --comment=2 > "$CONFIG/damaged.yaml"
fi
if [ ! -f "$CONFIG/lost.yaml" ]; then
    echo "Missing $CONFIG/lost.yaml"
    MISSING_FILE=1
    table2config.pl --columndelim="$COLUMN_DELIMITER" --quote="$QUOTE_CHAR" --headerrows=$HEADER_ROWS  --dir="$DIR" --name='StatusCodes' --key=0 --comment=2 > "$CONFIG/lost.yaml"
fi
if [ ! -f "$CONFIG/notforloan.yaml" ]; then
    echo "Missing $CONFIG/notforloan.yaml"
    MISSING_FILE=1
    table2config.pl --columndelim="$COLUMN_DELIMITER" --quote="$QUOTE_CHAR" --headerrows=$HEADER_ROWS  --dir="$DIR" --name='StatusCodes' --key=0 --comment=2 > "$CONFIG/notforloan.yaml"
fi
