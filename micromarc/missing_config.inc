if [ ! -f "$CONFIG/config.yaml" ]; then
    echo "Missing $CONFIG/config.yaml"
    MISSING_FILE=1
    cp "$SCRIPTDIR/config_sample/config.yaml" "$CONFIG/"
fi
if [ ! -f "$CONFIG/branchcodes.yaml" ]; then
    echo "Missing $CONFIG/branchcodes.yaml"
    MISSING_FILE=1
    table2config.pl --config "$CONFIG" "${TABLE_PARAMS[@]}" --query='SELECT Id, shContact.Name FROM shLocalUnit JOIN shContact USING(Id) ' --key=0 --comment=1 > "$CONFIG/branchcodes.yaml"
fi
if [ ! -f "$CONFIG/loc.yaml" ]; then
    echo "Missing $CONFIG/loc.yaml"
    MISSING_FILE=1
    table2config.pl --config "$CONFIG" "${TABLE_PARAMS[@]}" --name='caItem' --key=5 --comment=5 > "$CONFIG/loc.yaml"
fi
if [ ! -f "$CONFIG/ccode.yaml" ]; then
    echo "Missing $CONFIG/ccode.yaml"
    MISSING_FILE=1
    table2config.pl --config "$CONFIG" "${TABLE_PARAMS[@]}" --name='caDocumentGroup' --key=0 --comment=1 > "$CONFIG/ccode.yaml"
fi
if [ ! -f "$CONFIG/patroncategories.yaml" ]; then
    echo "Missing $CONFIG/patroncategories.yaml"
    MISSING_FILE=1
    table2config.pl --config "$CONFIG" "${TABLE_PARAMS[@]}" --name='shBorrowerGroup' --key=0 --comment=1 > "$CONFIG/patroncategories.yaml"
fi
if [ ! -f "$CONFIG/damaged.yaml" ]; then
    echo "Missing $CONFIG/damaged.yaml"
    MISSING_FILE=1
    table2config.pl --config "$CONFIG" "${TABLE_PARAMS[@]}" --name='caItemStatusCode' --key=0 --comment=4 > "$CONFIG/damaged.yaml"
fi
if [ ! -f "$CONFIG/lost.yaml" ]; then
    echo "Missing $CONFIG/lost.yaml"
    MISSING_FILE=1
    table2config.pl --config "$CONFIG" "${TABLE_PARAMS[@]}" --name='caItemStatusCode' --key=0 --comment=4 > "$CONFIG/lost.yaml"
fi
if [ ! -f "$CONFIG/notforloan.yaml" ]; then
    echo "Missing $CONFIG/notforloan.yaml"
    MISSING_FILE=1
    table2config.pl --config "$CONFIG" "${TABLE_PARAMS[@]}" --name='caItemStatusCode' --key=0 --comment=4 > "$CONFIG/notforloan.yaml"
fi
