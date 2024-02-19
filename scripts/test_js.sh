#! /usr/bin/env bash

# use the local mocha
MOCHA="node_modules/.bin/mocha"
# use the global mocha
#MOCHA="mocha"

# We assume the test scripts are in the root of the gem distribution
TEST_FILES_ROOT="."
FLAGS="--recursive --reporter spec --file ${TEST_FILES_ROOT}/mocha/utils/setup.js -r chai/register-expect.js"
FILES=""

GET_FILE=0
GET_ARG=0

GET_ENV=0
USE_ENV="test"

GET_HTTP_URL=0
USE_HTTP_URL="http://localhost:3030"

for F in "$@" ; do
    case $F in
	--env)
	    GET_ENV=1
	    ;;
	--http)
	    GET_HTTP_URL=1
	    ;;
	--file)
	    FLAGS="$FLAGS $F"
	    GET_FILE=1
	    ;;
	-f | --fgrep | --reporter) FLAGS="$FLAGS $F"
	    GET_ARG=1
	    ;;
	-*)
	    FLAGS="$FLAGS $F"
	    ;;
	*)
	    if test $GET_FILE = 1 ; then
		FLAGS="$FLAGS $F"
		GET_FILE=0
	    elif test $GET_ARG = 1 ; then
		FLAGS="$FLAGS \"$F\""
		GET_ARG=0
	    elif test $GET_ENV = 1 ; then
		USE_ENV=$F
		GET_ENV=0
	    elif test $GET_HTTP_URL = 1 ; then
		USE_HTTP_URL=$F
		GET_HTTP_URL=0
	    else
		if test ${F:0:1} = "/" ; then 
		    FILES="$FILES $F"
		else
		    FILES="$FILES ${TEST_FILES_ROOT}/$F"
		fi
	    fi
	    ;;
    esac
done

echo "FLAGS=$FLAGS"
echo "FILES=$FILES"

if test "x$FILES" = "x" ; then
    FILES="${TEST_FILES_ROOT}/mocha/unit"
fi

export NODE_PATH="${TEST_FILES_ROOT}/mocha/utils:${TEST_FILES_ROOT}/app/javascript:${TEST_FILES_ROOT}/vendor/javascript:${TEST_FILES_ROOT}/node_modules"
export NODE_ENV="$USE_ENV"
export TEST_HTTP_URL="$USE_HTTP_URL"

echo "using node environment ${NODE_ENV}"
echo "using node path ${NODE_PATH}"
echo "using Rails server at ${TEST_HTTP_URL}"
echo "running test command: ${MOCHA} $FLAGS $FILES"
${MOCHA} $FLAGS $FILES

