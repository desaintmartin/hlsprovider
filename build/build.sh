#!/bin/bash
FLEXPATH=../../flex_sdk_4.6

echo "Compiling HLSProvider.swc"
$FLEXPATH/bin/compc -include-sources ../src/org/mangui/HLS -output ../lib/HLSProvider.swc -library-path+=../lib/as3crypto.swc -use-network=false -optimize=true -incremental=true -target-player="10.1" -static-link-runtime-shared-libraries=true

echo "Compiling HLSProvider5.swf"
$FLEXPATH/bin/mxmlc ../src/org/mangui/jwplayer/media/HLSProvider.as -source-path ../src -o ../test/jwplayer5/HLSProvider5.swf -library-path+=../lib/as3crypto.swc -library-path+=../lib/jw5 -load-externs=../lib/jw5/jwplayer-5-classes.xml  -use-network=false -optimize=true -incremental=true -target-player="10.1" -static-link-runtime-shared-libraries=true

echo "Compiling HLSProvider6.swf"
$FLEXPATH/bin/mxmlc ../src/org/mangui/jwplayer/media/HLSProvider6.as -source-path ../src -o ../test/jwplayer6/HLSProvider6.swf -library-path+=../lib/as3crypto.swc -library-path+=../lib/jw6 -load-externs=../lib/jw6/jwplayer-6-classes.xml -use-network=false -optimize=true -incremental=true -target-player="10.1" -static-link-runtime-shared-libraries=true

echo "Compiling HLSProviderChromeless.swf"
$FLEXPATH/bin/mxmlc ../src/org/mangui/chromeless/ChromelessPlayer.as -source-path ../src -o ../test/chromeless/HLSProviderChromeless.swf -library-path+=../lib/as3crypto.swc -use-network=false -optimize=true -incremental=true -target-player="11.1" -static-link-runtime-shared-libraries=true -default-size 480 270 -default-background-color=0x000000

echo "Compiling HLSProviderFlowPlayer.swf"
$FLEXPATH/bin/mxmlc ../src/org/mangui/flowplayer/HLSPluginFactory.as -source-path ../src -o ../test/flowplayer/HLSProviderFlowPlayer.swf -library-path+=../lib/as3crypto.swc -library-path+=../lib/flowplayer  -load-externs=../lib/flowplayer/flowplayer-classes.xml -use-network=false -optimize=true -incremental=true -target-player="11.1" -static-link-runtime-shared-libraries=true

echo "Compiling HLSProviderOSMF.swf"
$FLEXPATH/bin/mxmlc ../src/org/mangui/osmf/plugins/HLSDynamicPlugin.as -source-path ../src -o ../test/osmf/HLSProviderOSMF.swf -library-path+=../lib/as3crypto.swc -library-path+=../lib/osmf -externs org.osmf.net.httpstreaming.HTTPNetStream -use-network=false -optimize=true -incremental=true -target-player="10.1" -static-link-runtime-shared-libraries=true #-compiler.verbose-stacktraces=true -link-report=../test/osmf/link-report.xml

echo "Compiling HLSProviderOSMF.swc"
$FLEXPATH/bin/compc -include-sources ../src/org/mangui/osmf -output ../lib/HLSProviderOSMF.swc -library-path+=../lib/as3crypto.swc -library-path+=../lib/HLSProvider.swc -library-path+=../lib/osmf  -use-network=false -optimize=true -incremental=true -target-player="10.1" -static-link-runtime-shared-libraries=true -debug=false -external-library-path+=../lib/osmf
