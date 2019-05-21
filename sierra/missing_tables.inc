if [ ! -f "$CONFIG/config.yaml" ]; then
    echo "Missing $CONFIG/config.yaml"
    MISSING_FILE=1
    cp "$SCRIPTDIR/config_sample/config.yaml" "$CONFIG/"
fi
if [[ -z "${CONST_BRANCHCODE}" ]]; then
   if [ ! -f "$CONFIG/branchcodes.yaml" ]; then
       echo "Missing $CONFIG/branchcodes.yaml"
       MISSING_FILE=1
   fi
fi
if [ ! -f "$CONFIG/loc.yaml" ]; then
    table2config.pl "${TABLE_PARAMS[@]}" --name='Item' --key='0' --val='0' > "$CONFIG/loc.yaml"
    echo "Missing $CONFIG/loc.yaml"
    MISSING_FILE=1
fi
if [ ! -f "$CONFIG/ccode.yaml" ]; then
    echo "Missing $CONFIG/ccode.yaml"
    table2config.pl "${TABLE_PARAMS[@]}" --name='Item' --key='4' --val='4' --comment='4' > "$CONFIG/ccode.yaml"
    MISSING_FILE=1
fi
if [ ! -f "$CONFIG/patroncategories.yaml" ]; then
    table2config.pl "${TABLE_PARAMS[@]}" --name='Patrons' --key='(1, 2, 3)'  > "$CONFIG/patroncategories.yaml"
    echo "Missing $CONFIG/patroncategories.yaml"
    MISSING_FILE=1
fi
if [ ! -f "$CONFIG/damaged.yaml" ]; then
    echo "Missing $CONFIG/damaged.yaml"
    table2config.pl "${TABLE_PARAMS[@]}" --name='Item' --key='5'  > "$CONFIG/damaged.yaml"
    MISSING_FILE=1
fi
if [ ! -f "$CONFIG/lost.yaml" ]; then
    echo "Missing $CONFIG/lost.yaml"
    table2config.pl "${TABLE_PARAMS[@]}" --name='Item' --key='5'  > "$CONFIG/lost.yaml"
    MISSING_FILE=1
fi
if [ ! -f "$CONFIG/notforloan.yaml" ]; then
    echo "Missing $CONFIG/notforloan.yaml"
    table2config.pl "${TABLE_PARAMS[@]}" --name='Item' --key='5'  > "$CONFIG/notforloan.yaml"
    MISSING_FILE=1
fi
