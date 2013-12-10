FLEXPATH=../../flex_sdk_4.6

echo ""
echo "Compiling HLSProvider5.swf"
echo ""

$FLEXPATH/bin/mxmlc ../src/org/mangui/jwplayer/media/HLSProvider.as -sp ../src -o ../test/jwplayer5/HLSProvider5.swf -library-path+=../lib/jw5 -load-externs=../lib/jw5/jwplayer-5-classes.xml  -use-network=false -optimize=true -incremental=false -target-player="10.1" -static-link-runtime-shared-libraries=true

echo ""
echo "Compiling HLSProvider6.swf"
echo ""

$FLEXPATH/bin/mxmlc ../src/org/mangui/jwplayer/media/HLSProvider6.as -sp ../src -o ../test/jwplayer6/HLSProvider6.swf -library-path+=../lib/jw6 -load-externs=../lib/jw6/jwplayer-6-classes.xml -use-network=false -optimize=true -incremental=false -target-player="10.1" -static-link-runtime-shared-libraries=true

echo ""
echo "Compiling HLSProviderChromeless.swf"
echo ""

$FLEXPATH/bin/mxmlc ../src/org/mangui/chromeless/ChromelessPlayer.as -sp ../src -o ../test/chromeless/HLSProviderChromeless.swf -use-network=false -optimize=true -incremental=false -target-player="11.1" -static-link-runtime-shared-libraries=true -default-size 480 270 -default-background-color=0x000000

echo ""
echo "Compiling HLSProviderOSMF.swf"
echo ""

$FLEXPATH/bin/mxmlc ../src/org/mangui/osmf/plugins/HLSDynamicPlugin.as -sp ../src -o ../test/osmf/HLSProviderOSMF.swf -library-path+=../lib/OSMF -externs org.osmf.net.httpstreaming.HTTPNetStream -use-network=false -optimize=true -incremental=false -target-player="10.1" -static-link-runtime-shared-libraries=true #-compiler.verbose-stacktraces=true -link-report=../test/osmf/link-report.xml
