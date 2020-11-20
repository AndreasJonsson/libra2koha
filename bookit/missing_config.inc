if [ ! -f "$CONFIG/config.yaml" ]; then
    echo "Missing $CONFIG/config.yaml"
    MISSING_FILE=1
    cp "$SCRIPTDIR/config_sample/config.yaml" "$CONFIG/"
fi
if [ ! -f "$CONFIG/branchcodes.yaml" ]; then
    echo "Missing $CONFIG/branchcodes.yaml"
    MISSING_FILE=1
    table2config.pl --config "$CONFIG" "${TABLE_PARAMS[@]}" --query="SELECT GE_ORG_ID, NAME FROM GE_ORG" --key=0 --comment=1 --key=0 --comment=1 > "$CONFIG/branchcodes.yaml"
fi
if [ ! -f "$CONFIG/loc.yaml" ]; then
    echo "Missing $CONFIG/loc.yaml"
    MISSING_FILE=1
    table2config.pl --config "$CONFIG" "${TABLE_PARAMS[@]}"  --query="SELECT CA_LOC_ID, NAME, NAME FROM CA_LOC" --key=0 --comment=1 --value=1 > "$CONFIG/loc.yaml"
fi
if [ ! -f "$CONFIG/ccode.yaml" ]; then
    echo "Missing $CONFIG/ccode.yaml"
    MISSING_FILE=1
    table2config.pl --config "$CONFIG" "${TABLE_PARAMS[@]}" --query="SELECT GE_PREMISES_ID, NAME FROM GE_PREMISES" --key=0 --comment=1 > "$CONFIG/ccode.yaml"
fi
if [ ! -f "$CONFIG/patroncategories.yaml" ]; then
    echo "Missing $CONFIG/patroncategories.yaml"
    MISSING_FILE=1
    table2config.pl --config "$CONFIG" "${TABLE_PARAMS[@]}"   --query='SELECT CI_BORR_CAT_ID, DESCR FROM CI_BORR_CAT' --key=0 --comment=1 > "$CONFIG/patroncategories.yaml"
fi
if [ ! -f "$CONFIG/damaged.yaml" ]; then
    echo "Missing $CONFIG/damaged.yaml"
    MISSING_FILE=1
    table2config.pl --config "$CONFIG" "${TABLE_PARAMS[@]}" --query='SELECT CA_NOT_AVAILABLE_CAUSE_ID, DESCR FROM CA_NOT_AVAILABLE_CAUSE' --key=0 --comment=1 > "$CONFIG/damaged.yaml"
fi
if [ ! -f "$CONFIG/lost.yaml" ]; then
    echo "Missing $CONFIG/lost.yaml"
    MISSING_FILE=1
    table2config.pl --config "$CONFIG" "${TABLE_PARAMS[@]}" --query='SELECT CA_NOT_AVAILABLE_CAUSE_ID, DESCR FROM CA_NOT_AVAILABLE_CAUSE' --key=0 --comment=1 > "$CONFIG/lost.yaml"
fi
if [ ! -f "$CONFIG/notforloan.yaml" ]; then
    echo "Missing $CONFIG/notforloan.yaml"
    table2config.pl --config "$CONFIG" "${TABLE_PARAMS[@]}" --query='SELECT CI_CAT_ID, DESCR FROM CI_CAT WHERE NOT LOAN_ALLOWED' --key=0 --comment=1 > "$CONFIG/notforloan.yaml"
    
    MISSING_FILE=1
fi
if [ ! -f "$CONFIG/media_types.yaml" ]; then
    echo "Missing $CONFIG/media_types.yaml"
    table2config.pl --config "$CONFIG" "${TABLE_PARAMS[@]}"  --query='SELECT CA_MEDIA_TYPE_ID, DESCR FROM CA_MEDIA_TYPE' --key=0 --comment=1 > "$CONFIG/media_types.yaml"
    
    MISSING_FILE=1
fi
