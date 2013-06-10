HLSprovider
===========

HTTP Live Streaming provider (MediaProvider compatible with JWPlayer 5 and 6)

* supports live / VOD playlist
* supports adaptive streaming, using state of the art switching algorithm
* supports manual quality switching (JWPlayer 6 only)
* supports seeking (with live playlist, user can also seek inside live window)
* reports buffer size (on progress bar)

the following M3U8 tags are supported: 

* #EXTM3U
* #EXTINF
* #EXT-X-STREAM-INF (used to support multiple bitrate)
* #EXT-X-ENDLIST (supports live / event / VOD playlist)
* #EXT-X-MEDIA-SEQUENCE (value is used for live playlist update)
* #EXT-X-TARGETDURATION (value is used as live playlist reload interval)



see examples here :

http://streambox.fr/HLSProvider/jwplayer5<br>
http://streambox.fr/HLSProvider/jwplayer6