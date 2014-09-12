#!/bin/bash
# warning: this doesn't work if any filenames contain whitespace, because I
# really just can't be ared with that right now.

cd "$(dirname "$0")" || exit 1

rm -rf .includes
mkdir .includes
# note: the vim trigger patten is broken up here deliberately
echo "# vim"": set syntax=make:" > include/dependencies.mf
echo "# vim"": set syntax=make:" > include/dependencies.mf_

function ingit() {
    git ls-files --error-unmatch "$1" &>/dev/null
    return $?
}

CHANGED_INGIT=
CHANGED_NOGIT=
    while read -d '' HDR; do
        git check-ignore "$HDR" >/dev/null && continue
        HDR=${HDR#./}
        FILE=../../$HDR
        for i in $(grep -o / <<<"$HDR"); do
            FILE=../$FILE
        done
        WRAP=include/je4d/${HDR%.hpp}
        mkdir -p $(dirname "$WRAP")
        mkdir -p ".$(dirname "$WRAP")"
        touch ".$WRAP"
        CONTENT="#include \"$FILE\""
        if [ ! -f "$WRAP" -o "$(cat "$WRAP" 2>/dev/null)" != "$CONTENT" ]; then
            echo "$WRAP" changed
            echo -n "$CONTENT" > "$WRAP"
            if ingit "$HDR"; then
                CHANGED_INGIT="$CHANGED_INGIT $WRAP"
            else
                CHANGED_NOGIT="$CHANGED_NOGIT $WRAP"
            fi
        elif ingit "$HDR"; then
            if ! ingit "$WRAP"; then
                CHANGED_INGIT="$CHANGED_INGIT $WRAP"
            fi
        elif ingit "$WRAP"; then
            CHANGED_NOGIT="$CHANGED_NOGIT $WRAP"
        fi

# sometimes, a custom wrapper is scanned and resolved to a target, then that
# target is removed. because of ../s in the gcc-generated dependency path,
# it won't get rebuilt
#
# recog.d contains
#   recog.o: \
#       include/je4d/cpp/generated/../../../../cpp/generated/cpp_tables.hpp
#       include/je4d/cpp/generated/../../../../cpp/generated/../../build/cpp/generated/source/cpp_tables.hpp
# we can't reason about what the full path of the second dep may be because that
#  depends on a hand-written file, but we can map the first to a dependency on
#  the real path of the header, which allows the hand-written makefile to
#  map that to a dependency on the real path the generated thing it includes
        TGT=""
        TGT_NEXT="$(dirname "$WRAP")/$FILE"
        while [ "$TGT" != "$TGT_NEXT" ]; do
            TGT=$TGT_NEXT
            if ingit "$HDR"; then
                echo "$TGT: "$'\\\n\t\t'"$HDR" \
                    >> include/dependencies.mf
            fi
            echo "$TGT: "$'\\\n\t\t'"$HDR" \
                >> include/dependencies.mf_
            TGT_NEXT=$(sed 's/\/[^./][^/]*\/\.\.\//\//'<<<"$TGT")
        done
    done < <(find . ! -path 'include/*' \
               ! -path '*/build/*' \
               ! -path 'external/*' \
               -type f -name '*.hpp' -print0)
while read -d '' WRAP; do
    if [ ! -f ".$WRAP" ]; then
        if git ls-files --error-unmatch "$WRAP" &>/dev/null; then
            GONE_INGIT="$GONE_INGIT $WRAP"
        else
            GONE_NOGIT="$GONE_NOGIT $WRAP"
        fi
    fi
done < <(find include/je4d ! -type d -print0)
[ -n "$GONE_INGIT" ] && git rm -f $GONE_INGIT
[ -n "$GONE_NOGIT" ] && rm -f $GONE_NOGIT
[ -n "$CHANGED_INGIT" ] && git add $CHANGED_INGIT
[ -n "$CHANGED_NOGIT" ] && git reset $CHANGED_NOGIT
git update-index --no-assume-unchanged include/dependencies.mf
git add include/dependencies.mf
git update-index --assume-unchanged include/dependencies.mf
mv include/dependencies.mf{_,}
rm -rf .include
find include -depth -type d -empty -exec rmdir {} \;

