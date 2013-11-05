#HLSprovider

**HLSProvider** is a media provider plugin that allows you to play HLS playlist using either :

* **JWPlayer** Flash free edition version **5.x**
* **JWPlayer** Flash free edition version **6.x**
* **OSMF** version **2.0** (early beta stage, any help welcomed !)

it is free of charge.


**HLSProvider** supports the following HLS features :

* VOD/live/DVR playlist
* multiple bitrate playlist / adaptive streaming
* automatic quality switching, using serial segment fetching method described in [http://www.cs.tut.fi/%7Emoncef/publications/rate-adaptation-IC-2011.pdf](http://www.cs.tut.fi/%7Emoncef/publications/rate-adaptation-IC-2011.pdf)
* manual quality switching (JWPlayer 6 only)
* seeking in VoD and live playlist
* buffer progress report
* error resilience (retry mechanism in case of I/O Errors)

the following M3U8 tags are supported: 

* #EXTM3U
* #EXTINF
* #EXT-X-STREAM-INF (used to support multiple bitrate)
* #EXT-X-ENDLIST (supports live / event / VOD playlist)
* #EXT-X-MEDIA-SEQUENCE (value is used for live playlist update)
* #EXT-X-TARGETDURATION (value is used as live playlist reload interval)
* #EXT-X-DISCONTINUITY

##HLSProvider in action :

* http://streambox.fr/HLSProvider/jwplayer5
* http://streambox.fr/HLSProvider/jwplayer6
* http://streambox.fr/HLSProvider/osmf

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
The use of the HLSProvider is governed by a Creative Commons license.
You can use, modify, copy, and distribute this edition as long as it's for non-commercial use, you provide attribution, and share under a similar license.

The license summary and full text can be found here: [CC BY-NC-SA 3.0](http://creativecommons.org/licenses/by-nc-sa/3.0/ "CC BY-NC-SA 3.0")

###Donate
If you'd like to support future development and new product features, please make a donation via PayPal - a secure online banking service.These donations are used to cover my ongoing expenses - web hosting, domain registrations, and software and hardware purchases.

[![Donate](https://www.paypalobjects.com/en_US/i/btn/btn_donate_LG.gif)](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=463RB2ALVXJLA)