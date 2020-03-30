if [ ! -f "$CONFIG/config.yaml" ]; then
    echo "Missing $CONFIG/config.yaml"
    MISSING_FILE=1
    cp "$SCRIPTDIR/config_sample/config.yaml" "$CONFIG/"
fi

if [ ! -f "$CONFIG/branchcodes.yaml" ]; then
    echo "Missing $CONFIG/branchcodes.yaml"
    MISSING_FILE=1
    for i in $MARC; do
        marcdump --field=998 "$i" | egrep '^......._a' | sort | uniq | sed "s/^.........\\(.*\\)/'\\1': '' /"  > "$CONFIG"/branchcodes.yaml
    done
fi

if [ ! -f "$CONFIG/itype.yaml" ]; then
    echo "Missing $CONFIG/itype.yaml"
    MISSING_FILE=1
    for i in $MARC; do
        marcdump --field=945 "$i" | egrep '^......._t' | sort | uniq | sed "s/^.........\\(.*\\)/'\\1': '' /"  > "$CONFIG"/itype.yaml
    done
fi

if [ ! -f "$CONFIG/loc.yaml" ]; then
    echo "Missing $CONFIG/loc.yaml"
    MISSING_FILE=1
    for i in $MARC; do
        marcdump --field=945 "$i" | egrep '^......._l' | sort | uniq | sed "s/^.........\\(.*\\)/'\\1': '' /"  > "$CONFIG"/loc.yaml
    done
fi

if [ ! -f "$CONFIG/lost.yaml" ]; then
    echo "Missing $CONFIG/lost.yaml"
    MISSING_FILE=1
    for i in $MARC; do
        marcdump --field=945 "$i" | egrep '^......._s' | sort | uniq | sed "s/^.........\\(.*\\)/'\\1': '' /"  > "$CONFIG"/lost.yaml
    done
fi

