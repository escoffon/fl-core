#! /usr/bin/env bash

USE_TESTAPP=Y

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

echo "RARGS: ${RARGS}"

if test ${USE_TESTAPP} = Y ; then
    APPARGS=""
    FCOUNT=0
    APPDIR="spec/FlCoreTestApp"

    for A in $RARGS ; do
	if test -f $A -o -d $A ; then 
	    APPARGS="$APPARGS ../../${A}"
	    ((FCOUNT++))
	else
	    APPARGS="$APPARGS ${A}"
	fi
    done

    if test "$FCOUNT" -eq 0 ; then
	APPARGS="$APPARGS ../../spec"
    fi
    
    echo "running in the test app directory ($APPDIR)"
    cd $APPDIR

    if test "x$PREPARE" != "x" ; then
	echo "preparing the $PREPARE database"
	rm "db/${PREPARE}.sqlite3"
	RAILS_ENV=$PREPARE rake db:migrate
    fi

    echo "running test command: bash $0 $APPARGS"
    bash $0 $APPARGS
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
