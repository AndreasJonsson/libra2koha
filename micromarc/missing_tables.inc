if [ ! -f "$CONFIG/config.yaml" ]; then
    echo "Missing $CONFIG/config.yaml"
    MISSING_FILE=1
    cp "$SCRIPTDIR/config_sample/config.yaml" "$CONFIG/"
fi
if [ ! -f "$CONFIG/branchcodes.yaml" ]; then
    echo "Missing $CONFIG/branchcodes.yaml"
    MISSING_FILE=1
    table2config.pl --encoding=$TABLEENC --columndelim="$COLUMN_DELIMITER" --quote="$QUOTE_CHAR" --headerrows=$HEADER_ROWS --dir="$DIR" --name='shLocalUnit' --key=0 --comment=0 > "$CONFIG/branchcodes.yaml"
fi
if [ ! -f "$CONFIG/ccode.yaml" ]; then
    echo "Missing $CONFIG/ccode.yaml"
    MISSING_FILE=1
    table2config.pl --encoding=$TABLEENC --columndelim="$COLUMN_DELIMITER"  --quote="$QUOTE_CHAR" --headerrows=$HEADER_ROWS  --dir="$DIR" --name='caDocumentGroup' --key=0 --comment=1 > "$CONFIG/ccode.yaml"
fi
if [ ! -f "$CONFIG/patroncategories.yaml" ]; then
    echo "Missing $CONFIG/patroncategories.yaml"
    MISSING_FILE=1
    table2config.pl --encoding=$TABLEENC --columndelim="$COLUMN_DELIMITER"  --quote="$QUOTE_CHAR" --headerrows=$HEADER_ROWS  --dir="$DIR" --name='shBorrowerGroup' --key=0 --comment=1 > "$CONFIG/patroncategories.yaml"
fi
if [ ! -f "$CONFIG/damaged.yaml" ]; then
    echo "Missing $CONFIG/damaged.yaml"
    MISSING_FILE=1
fi
if [ ! -f "$CONFIG/lost.yaml" ]; then
    echo "Missing $CONFIG/lost.yaml"
    MISSING_FILE=1
fi
if [ ! -f "$CONFIG/notforloan.yaml" ]; then
    echo "Missing $CONFIG/notforloan.yaml"
    MISSING_FILE=1
fi
