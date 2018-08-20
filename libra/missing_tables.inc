if [ ! -f "$CONFIG/config.yaml" ]; then
    echo "Missing $CONFIG/config.yaml"
    MISSING_FILE=1
    cp "$SCRIPTDIR/config_sample/config.yaml" "$CONFIG/"
fi
if [ ! -f "$CONFIG/branchcodes.yaml" ]; then
    echo "Missing $CONFIG/branchcodes.yaml"
    MISSING_FILE=1
    table2config.pl --columndelim='	' --headerrows=2 --dir="$DIR" --name='Branches' --key=0 --comment=2 > "$CONFIG/branchcodes.yaml"
fi
if [ ! -f "$CONFIG/loc.yaml" ]; then
    echo "Missing $CONFIG/loc.yaml"
    MISSING_FILE=1
    table2config.pl --columndelim='	' --headerrows=2  --dir="$DIR" --name='LocalShelfs' --key=1 --comment=2 > "$CONFIG/loc.yaml"
fi
if [ ! -f "$CONFIG/ccode.yaml" ]; then
    echo "Missing $CONFIG/ccode.yaml"
    MISSING_FILE=1
    table2config.pl --columndelim='	' --headerrows=2  --dir="$DIR/" --name='Departments' --key=0 --comment=2 > "$CONFIG/ccode.yaml"
fi
if [ ! -f "$CONFIG/patroncategories.yaml" ]; then
    echo "Missing $CONFIG/patroncategories.yaml"
    MISSING_FILE=1
    table2config.pl --columndelim='	' --headerrows=2  --dir="$DIR" --name='BorrowerCategories' --key=0 --comment=2 > "$CONFIG/patroncategories.yaml"
fi
