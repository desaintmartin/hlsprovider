FLEXPATH=../../flex_sdk_4.6

echo ""
echo "Compiling chromelessPlayer.swf"
echo ""

$FLEXPATH/bin/mxmlc ../src/ChromelessPlayer.as -sp ../src -o ../test/chromeless/chromelessPlayer.swf -use-network=false -optimize=true -incremental=false -target-player="11.1" -static-link-runtime-shared-libraries=true -default-size 480 270 -default-background-color=0x000000

echo ""
echo "Compiling HLSProvider5.swf"
echo ""

$FLEXPATH/bin/mxmlc ../src/com/mangui/jwplayer/media/HLSProvider.as -sp ../src -o ../test/jwplayer5/HLSProvider5.swf -library-path+=../lib/v5 -load-externs=../lib/v5/jwplayer-5-classes.xml  -use-network=false -optimize=true -incremental=false -target-player="10.1" -static-link-runtime-shared-libraries=true

echo ""
echo "Compiling HLSProvider6.swf"
echo ""

$FLEXPATH/bin/mxmlc ../src/com/mangui/jwplayer/media/HLSProvider6.as -sp ../src -o ../test/jwplayer6/HLSProvider6.swf -library-path+=../lib/v6 -load-externs=../lib/v6/jwplayer-6-classes.xml -use-network=false -optimize=true -incremental=false -target-player="10.1" -static-link-runtime-shared-libraries=true

#echo ""
#echo "Compiling chromelessPlayer_debug.swf"
#echo ""
#
#$FLEXPATH/bin/mxmlc ../src/ChromelessPlayer.as -sp ../src -o ../test/chromeless/chromelessPlayer_debug.swf -use-network=false -optimize=true -incremental=false -target-player="11.1" -static-link-runtime-shared-libraries=true -default-size 480 270 -default-background-color=0x000000 -debug=true -verbose-stacktraces=true
#
#
#echo ""
#echo "Compiling HLSProvider5_debug.swf"
#echo ""
#
#$FLEXPATH/bin/mxmlc ../src/com/mangui/jwplayer/media/HLSProvider.as -sp ../src -o ../test/jwplayer5/HLSProvider5_debug.swf -library-path+=../lib/v5 -load-externs=../lib/v5/jwplayer-5-classes.xml  -use-network=false -optimize=true -incremental=false -target-player="10.1" -static-link-runtime-shared-libraries=true -debug=true -verbose-stacktraces=true
#
#echo ""
#echo "Compiling HLSProvider6_debug.swf"
#echo ""
#
#$FLEXPATH/bin/mxmlc ../src/com/mangui/jwplayer/media/HLSProvider6.as -sp ../src -o ../test/jwplayer6/HLSProvider6_debug.swf -library-path+=../lib/v6 -load-externs=../lib/v6/jwplayer-6-classes.xml -use-network=false -optimize=true -incremental=false -target-player="10.1" -static-link-runtime-shared-libraries=true -debug=true -verbose-stacktraces=true