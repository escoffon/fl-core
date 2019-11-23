#! /usr/bin/env bash

USE_TESTAPP=Y

if test ${USE_TESTAPP} = Y ; then
    RARGS=""

    for A in "$@" ; do
	RARGS="$RARGS ../../${A}"
    done

    if test "$RARGS" = "" ; then
	RARGS="../../spec"
    fi
    
    echo "running in the test app directory (spec/FlCoreTestApp)"
    cd spec/FlCoreTestApp

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
