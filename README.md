#HLSprovider

**HLSProvider** is an open-source HLS Flash plugin/player that allows you to play HLS streams and that is integrated with the following players :

* a home made **Chromeless** Flash Player, with js controls.
* **JWPlayer** free edition version **5.x**
* **JWPlayer** free edition version **6.x**
* **OSMF** version **2.0**
* **http://mediaelementjs.com** (support being added here : https://github.com/mangui/mediaelement)
* **http://www.videojs.com** (support being added here : https://github.com/mangui/video-js-swf)
 
HLSProvider could be used as library to build a custom flash player using a simple SDK/API.

**HLSProvider** supports the following features :

* VOD/live/DVR playlists
* adaptive streaming (multiple bitrate)
	* manual or automatic quality switching, using serial segment fetching method from [http://www.cs.tut.fi/%7Emoncef/publications/rate-adaptation-IC-2011.pdf](http://www.cs.tut.fi/%7Emoncef/publications/rate-adaptation-IC-2011.pdf)
* accurate seeking (seek to exact position,not to fragment boundary) in VoD and live
* buffer progress report
* error resilience
	* retry mechanism in case of I/O Errors
	* fallback parsing mechanism in case of badly segmented TS streams
* AES-128 decryption

the following M3U8 tags are supported: 

* #EXTM3U
* #EXTINF
* #EXT-X-STREAM-INF (multiple bitrate)
* #EXT-X-ENDLIST (live / VOD playlist)
* #EXT-X-MEDIA-SEQUENCE
* #EXT-X-TARGETDURATION
* #EXT-X-DISCONTINUITY
* #EXT-X-DISCONTINUITY-SEQUENCE
* #EXT-X-PROGRAM-DATE-TIME (optional, used to synchronize time-stamps and sequence number when switching from one level to another)
* #EXT-X-KEY (AES-128 method supported only, alpha stage)

the following containers are supported:

* MPEG2-Transport Stream
* AAC and MPEG1-Layer 3 Audio Elementary streams
	* as per HLS spec, Each Elementary Audio Stream segment MUST signal the timestamp of       its first sample with an ID3 PRIV tag at the beginning of the segment.  The ID3 PRIV owner identifier MUST be      "com.apple.streaming.transportStreamTimestamp".


##HLSProvider in action :

* http://streambox.fr/HLSProvider/chromeless
* http://streambox.fr/HLSProvider/jwplayer5
* http://streambox.fr/HLSProvider/jwplayer6
* http://streambox.fr/HLSProvider/osmf/GrindPlayer.html
* http://streambox.fr/HLSProvider/osmf/StrobeMediaPlayback.html
* http://streambox.fr/HLSProvider/mediaelement/demo/mediaelementplayer-hls.html
* http://streambox.fr/HLSProvider/videojs/flash_demo.html


##How to use it :

download package : https://github.com/mangui/HLSprovider/archive/master.zip

###chromeless based setup:
from zip, extract test/chromeless folder, and get inspired by example.html

###OSMF based setup:
from zip, extract test/osmf folder, and get inspired by index.html

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

    <div style="width: 640px; height: 360px;" id="player"></div>
    <script type="text/javascript" src="jwplayer.js"></script>
    <script type="text/javascript">

    jwplayer("player").setup({
    playlist: [{
    file:'http://mysite.com/stream.m3u8',
    provider:'HLSProvider6.swf',
    type:'hls'
    }],
    width: 640,
    height: 480,
    primary: "flash"
    });

###License
the following files (from [jwplayer.com](http://www.jwplayer.com)) are governed by a Creative Commons license:

* lib/jw5/jwplayer-5-lib.swc
* lib/jw5/jwplayer-5-classes.xml
* lib/jw6/jwplayer-6-lib.swc
* lib/jw6/jwplayer-6-classes.xml
* test/HLSProvider5/jwplayer.js
* test/HLSProvider5/player.swf
* test/HLSProvider6/jwplayer.js
* test/HLSProvider6/jwplayer.html5.js
* test/HLSProvider6/jwplayer.flash.swf

You can use, modify, copy, and distribute them as long as it's for non-commercial use, you provide attribution, and share under a similar license.

The license summary and full text can be found here: [CC BY-NC-SA 3.0](http://creativecommons.org/licenses/by-nc-sa/3.0/ "CC BY-NC-SA 3.0")

the following file (from [https://github.com/timkurvers/as3-crypto]) is governed by BSD License:

* lib/as3crypto.swc

The license full text of as3crypto lib can be found here: [as3-crypto](https://github.com/timkurvers/as3-crypto/blob/master/LICENSE.md)


**All other files (source code and executable) are governed by MPL 2.0** (Mozilla Public License 2.0).
The license full text can be found here: [MPL 2.0](http://www.mozilla.org/MPL/2.0/)

###Donate
If you'd like to support future development and new product features, please make a donation via PayPal - a secure online banking service.These donations are used to cover my ongoing expenses - web hosting, domain registrations, and software and hardware purchases.

[![Donate](https://www.paypalobjects.com/en_US/i/btn/btn_donate_LG.gif)](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=463RB2ALVXJLA)

[![githalytics.com alpha](https://cruel-carlota.pagodabox.com/c3d851ee2663072644e59cc07088cf97 "githalytics.com")](http://githalytics.com/mangui/HLSprovider)
