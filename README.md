#HLSprovider

**HLSProvider** is a JWPlayer media provider (plugin) that allows you to play HLS playlist using JWPlayer Flash free edition.
It is compatible with both JWPlayer 5 and 6, and it is free of charge.

**HLSProvider** supports the following HLS features :

* supports VOD playlist
* supports live playlist
* supports multiple bitrate playlist / adaptive streaming
* supports automatic quality switching, using state of the art switching algorithm
* supports manual quality switching (JWPlayer 6 only)
* supports seeking in VoD and live playlist
* reports buffer progress

the following M3U8 tags are supported: 

* #EXTM3U
* #EXTINF
* #EXT-X-STREAM-INF (used to support multiple bitrate)
* #EXT-X-ENDLIST (supports live / event / VOD playlist)
* #EXT-X-MEDIA-SEQUENCE (value is used for live playlist update)
* #EXT-X-TARGETDURATION (value is used as live playlist reload interval)

##HLSProvider in action :

* http://streambox.fr/HLSProvider/jwplayer5
* http://streambox.fr/HLSProvider/jwplayer6

##How to use it :

download package : https://github.com/mangui/HLSprovider/archive/master.zip

###jwplayer5 based setup:
from zip, extract test/jwplayer5 folder, and get inspired by example.html

    <div style="width: 640px; height: 360px;" id="player"></div>
    <script type="text/javascript" src="jwplayer.js"></script>
    <script type="text/javascript">
    
    jwplayer("player").setup({
    width: 640,height: 360,
    modes: [
    { type:'flash', src:'player.swf', config: { provider:'HLSProvider5.swf', file:'http://mysite.com/stream.m3u8' } },
    { type:'html5', config: { file:'http://mysite.com/stream.m3u8' } }
    ]});
    
    </script>

###jwplayer6 based setup:
from zip, extract test/jwplayer6 folder, and get inspired by example.html

    jwplayer("player").setup({
    playlist: [{
    file:'http://mysite.com/stream.m3u8',
    provider:'HLSProvider6.swf',
    type:'mp4'
    }],
    width: 640,
    height: 480,
    primary: "flash"
    });

