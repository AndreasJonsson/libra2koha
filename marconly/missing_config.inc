if [ ! -f "$CONFIG/config.yaml" ]; then
    echo "Missing $CONFIG/config.yaml"
    MISSING_FILE=1
    cp "$SCRIPTDIR/config_sample/config.yaml" "$CONFIG/"
fi

if [ ! -f "$CONFIG/branchcodes.yaml" ]; then
    echo "Missing $CONFIG/branchcodes.yaml"
    MISSING_FILE=1
    for i in $MARC; do
        marcdump "$i" | egrep '^998    _a' | sort | uniq | sed "s/^.........\\(.*\\)/'\\1': '' /"  > "$CONFIG"/branchcodes.yaml
    done
fi

