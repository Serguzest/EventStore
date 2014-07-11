#!/usr/bin/env bash

version=$1
customMonoPrefix=$2

SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

function usage {
	echo "Usage:"
	echo "  $0 version monoprefix"
	echo ""
	echo "Note: By default, mono is assumed to be at the output of 'which mono'../lib"
    echo "      though it may be desirable to specify an actual location."
	exit
}

function writeLog {
	message=$1
	echo "[package-mono.sh] - $message"
}

if [[ "$version" == "" ]] ; then
	VERSIONSTRING="0.0.0.0"
	writeLog "Version defaulted to: 0.0.0.0"
else
	VERSIONSTRING=$version
	writeLog "Version set to: $VERSIONSTRING"
fi

if [[ "$customMonoPrefix" == "" ]]; then
    monopath=`which mono`
    toremove="/bin/mono"
    MONOPREFIX=${monopath:0:${#monopath}-${#toremove}}
    writeLog "Mono prefix defaulted to: $MONOPREFIX"
else
    MONOPREFIX=$customMonoPrefix
    writeLog "Mono prefix set to: $MONOPREFIX"
fi

MKBUNDLEPATH=$MONOPREFIX/bin/mkbundle
if [[ -f $MKBUNDLEPATH ]] ; then
	writeLog "Using mkbundle: $MKBUNDLEPATH"
else
	writeLog "Cannot find mkbundle"
	exit 1
fi

MACHINECONFIG=$MONOPREFIX/etc/mono/4.0/machine.config
if [[ -f $MACHINECONFIG ]] ; then
    writeLog "Using --machine-config: $MACHINECONFIG"
else
    writeLog "Cannot find machine config at $MACHINECONFIG"
    exit 1
fi

OS=`uname`
if [[ $OS == "Darwin" ]] ; then
    for SUBVER in 11 10 9 8
    do
        sdkpath=`xcodebuild -sdk -version | grep "MacOSX10.$SUBVER" | tail -1`
        if [[ $sdkpath != "" ]] ; then
            break
        fi
    done

    if [[ $sdkpath == "" ]] ; then
        writeLog "Can't find a MacOS SDK using xcodebuild -sdk -version"
        exit 1
    fi

    isysroot=${sdkpath:6}
    ES_COMPILE_FLAGS="-lobjc -liconv -framework CoreFoundation -isysroot $isysroot -I $MONOPREFIX/include/mono-2.0 -Wall"

    writeLog "Using MacOS Compile Flags: $ES_COMPILE_FLAGS"
fi

MONOCONFIG=$MONOPREFIX/etc/mono/config
if [[ -f $MONOCONFIG ]] ; then
    writeLog "Using --config: $MONOCONFIG"
else
    writeLog "Cannot find mono config at $MONOCONFIG"
    exit 1
fi

GCCPATH=`which gcc`
if [[ $? != 0 ]] ; then
	writeLog "Cannot find gcc"
	exit 1
else
	writeLog "Using gcc: $GCCPATH"
fi

OUTPUTDIR=$SCRIPTDIR../../bin/packaged
[[ -d $OUTPUTDIR ]] || mkir -p $OUTPUTDIR


if [[ $OS == "Darwin" ]] ; then
    soext="dylib"
    PACKAGEDIRECTORY="$OUTPUTDIR/EventStore-Mac-v$VERSIONSTRING"
else
    soext="so"
    PACKAGEDIRECTORY="$OUTPUTDIR/EventStore-Linux-v$VERSIONSTRING"
fi

if [[ -d $PACKAGEDIRECTORY ]] ; then
    rm -rf $PACKAGEDIRECTORY
fi
mkdir $PACKAGEDIRECTORY


pushd $SCRIPTDIR../../bin/singlenode/

if [[ $OS == "Darwin" ]] ; then
    mkbundle -c -o singlenode.c -oo singlenode.a EventStore.SingleNode.exe EventStore.Core.dll EventStore.BufferManagement.dll EventStore.Common.dll EventStore.Projections.Core.dll EventStore.SingleNode.Web.dll EventStore.Transport.Http.dll EventStore.Transport.Tcp.dll Newtonsoft.Json.dll NLog.dll protobuf-net.dll EventStore.Web.dll Mono.Security.dll --static --deps --config /opt/mono/etc/mono/config --machine-config /opt/mono/etc/mono/4.0/machine.config
    gcc -o singlenode $ES_COMPILE_FLAGS singlenode.c singlenode.a $MONOPREFIX/lib/libmonosgen-2.0.a $MONOPREFIX/lib/libMonoPosixHelper.a
else
    mkbundle -c -o singlenode.c -oo singlenode.a EventStore.SingleNode.exe EventStore.Core.dll EventStore.BufferManagement.dll EventStore.Common.dll EventStore.Projections.Core.dll EventStore.SingleNode.Web.dll EventStore.Transport.Http.dll EventStore.Transport.Tcp.dll Newtonsoft.Json.dll NLog.dll protobuf-net.dll EventStore.Web.dll Mono.Security.dll --static --deps --config $MONOCONFIG --machine-config $MACHINECONFIG
    cc -o singlenode -Wall `pkg-config --cflags monosgen-2` singlenode.c  `pkg-config --libs-only-L monosgen-2` -Wl,-Bstatic -lmonosgen-2.0 -Wl,-Bdynamic `pkg-config --libs-only-l monosgen-2 | sed -e "s/\-lmono-2.0 //"` singlenode.a
fi

cp -r es-common-web $PACKAGEDIRECTORY/
cp -r singlenode-web $PACKAGEDIRECTORY/
cp -r Prelude $PACKAGEDIRECTORY/
cp -r web-resources $PACKAGEDIRECTORY/
cp -r Users $PACKAGEDIRECTORY/
cp singlenode-config.dist.json $PACKAGEDIRECTORY/
cp libjs1.$soext $PACKAGEDIRECTORY/
cp libv8.$soext $PACKAGEDIRECTORY/
cp libicui18n.$soext $PACKAGEDIRECTORY/
cp libicuuc.$soext $PACKAGEDIRECTORY/
cp singlenode $PACKAGEDIRECTORY/
cp NLog.config $PACKAGEDIRECTORY/
cp $SCRIPTDIR/singlenode.sh $PACKAGEDIRECTORY/run-singlenode.sh

popd

pushd $SCRIPTDIR../../bin/clusternode/

if [[ $OS == "Darwin" ]] ; then
    mkbundle -c -o clusternode.c -oo clusternode.a EventStore.ClusterNode.exe EventStore.Core.dll EventStore.BufferManagement.dll EventStore.Common.dll EventStore.Projections.Core.dll EventStore.SingleNode.Web.dll EventStore.Transport.Http.dll EventStore.Transport.Tcp.dll Newtonsoft.Json.dll NLog.dll protobuf-net.dll EventStore.Web.dll Mono.Security.dll --static --deps --config $MONOCONFIG --machine-config $MACHINECONFIG
    gcc -o clusternode $ES_COMPILE_FLAGS clusternode.c clusternode.a $MONOPREFIX/lib/libmonosgen-2.0.a $MONOPREFIX/lib/libMonoPosixHelper.a
else
    mkbundle -c -o clusternode.c -oo clusternode.a EventStore.ClusterNode.exe EventStore.Core.dll EventStore.BufferManagement.dll EventStore.Common.dll EventStore.Projections.Core.dll EventStore.SingleNode.Web.dll EventStore.Transport.Http.dll EventStore.Transport.Tcp.dll Newtonsoft.Json.dll NLog.dll protobuf-net.dll EventStore.Web.dll Mono.Security.dll --static --deps --config $MONOCONFIG --machine-config $MACHINECONFIG
    cc -o clusternode -Wall `pkg-config --cflags monosgen-2` clusternode.c  `pkg-config --libs-only-L monosgen-2` -Wl,-Bstatic -lmonosgen-2.0 -Wl,-Bdynamic `pkg-config --libs-only-l monosgen-2 | sed -e "s/\-lmono-2.0 //"` clusternode.a
fi

cp -r clusternode-web $PACKAGEDIRECTORY/
cp -r es-common-web $PACKAGEDIRECTORY/
cp -r Prelude $PACKAGEDIRECTORY/
cp -r web-resources $PACKAGEDIRECTORY/
cp -r Users $PACKAGEDIRECTORY/
cp clusternode-config.dist.json $PACKAGEDIRECTORY/
cp libjs1.$soext $PACKAGEDIRECTORY/
cp libv8.$soext $PACKAGEDIRECTORY/
cp libicui18n.$soext $PACKAGEDIRECTORY/
cp libicuuc.$soext $PACKAGEDIRECTORY/
cp clusternode $PACKAGEDIRECTORY/
cp NLog.config $PACKAGEDIRECTORY/
cp $SCRIPTDIR/clusternode.sh $PACKAGEDIRECTORY/run-clusternode.sh

popd

pushd $OUTPUTDIR

tar -zcvf $PACKAGEDIRECTORY.tar.gz $PACKAGEDIRECTORY

rm -rf $PACKAGEDIRECTORY

popd
