#! /usr/bin/env bash

RSPEC="rspec"
PREPARE=""
RARGS=""

for A in "$@" ; do
    case $A in
	--prepare) PREPARE="test"
		   ;;
	*) RARGS="$RARGS $A"
	   ;;
    esac
done

if test "x$PREPARE" != "x" ; then
    echo "preparing the $PREPARE database"
    bash db/pg/prepare_db.sh $PREPARE
fi

echo "running test command: ${RSPEC} $RARGS"
${RSPEC} $RARGS
