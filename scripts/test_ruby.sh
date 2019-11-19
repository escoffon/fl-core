#! /usr/bin/env bash

IS_ENGINE=N

if test ${IS_ENGINE} = Y ; then
    RARGS=""

    for A in "$@" ; do
	RARGS="$RARGS ${A/test\/FlCoreTestApp\//}"
    done

    echo "running in the test app directory (test/FlCoreTestApp)"
    cd test/FlCoreTestApp

    echo "running test command: bash $0 $RARGS"
    bash $0 $RARGS
else
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
fi
