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