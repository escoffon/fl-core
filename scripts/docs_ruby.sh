#! /bin/bash

function shell_session_update {
    local X
}

if test "$(type -t yard)" = '' ; then
    echo "Please install the Yard document generator (gem install yard)."
    echo "See https://yardoc.org/"
    exit 1
fi

if test "x$1" = "x" ; then
    echo "usage: $0 [doc|stats|list|clean] [list-options]"
    exit 1
else
    OP=$1
fi

CFGFILE="doc/ruby/yard.cfg"

ORIGINALCWD=$(pwd)
while test ! -f $CFGFILE ; do
    OLDCWD=$(pwd)
    cd ..
    if test "x$(pwd)" = "x$OLDCWD" ; then
	echo "$ORIGINALCWD does not seem to be in a fl-core distribution"
	exit 1
    fi
done

RUBYDOCS="spec/FlCoreTestApp/public/doc/fl/core/ruby"

case $OP in
    doc) echo "generating documentation in $RUBYDOCS"
	 rm -rf $RUBYDOCS

	 if yard doc --yardopts $CFGFILE --output-dir=$RUBYDOCS ; then
	     echo "rebuilt the Ruby documentation"
	 else
	     echo "failed to rebuild the Ruby docs"
	     exit 1
	 fi
	 ;;

    clean) echo "removing documentation in $RUBYDOCS"
	 rm -rf $RUBYDOCS
	 ;;
    
    stats) echo "generating statistics (including undocumented items)"
	   if yard stats --yardopts $CFGFILE --list-undoc ; then
	       echo "generated statistics"
	   else
	       echo "failed to generate statistics"
	       exit 1
	   fi
	   ;;

    list) shift 
	  echo "running list command: $@"
	  yard list $@
	  ;;

    *) echo "unknown operation: $OP"
       exit 1
       ;;
esac

exit 0
