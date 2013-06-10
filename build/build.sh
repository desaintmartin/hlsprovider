FLEXPATH=../../flex_sdk_4.6

# echo ""
# echo "Compiling chromelessPlayer.swf"
# echo ""

# $FLEXPATH/bin/mxmlc ../src/ChromelessPlayer.as -sp ../src -o ../chromelessPlayer.swf -use-network=false -optimize=true -incremental=false -target-player="10.2" -static-link-runtime-shared-libraries=true -default-size 480 270 -default-background-color=0x000000

echo ""
echo "Compiling HLSProvider5.swf"
echo ""

$FLEXPATH/bin/mxmlc ../src/com/mangui/jwplayer/media/HLSProvider.as -sp ../src -o ../test/HLSProvider5.swf -library-path+=../lib/v5 -load-externs=../lib/v5/jwplayer-5-classes.xml  -use-network=false -optimize=true -incremental=false -target-player="10.1" -static-link-runtime-shared-libraries=true

echo ""
echo "Compiling HLSProvider6.swf"
echo ""

$FLEXPATH/bin/mxmlc ../src/com/mangui/jwplayer/media/HLSProvider6.as -sp ../src -o ../test/HLSProvider6.swf -library-path+=../lib/v6 -load-externs=../lib/v6/jwplayer-6-classes.xml -use-network=false -optimize=true -incremental=false -target-player="10.1" -static-link-runtime-shared-libraries=true