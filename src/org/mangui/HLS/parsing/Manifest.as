package org.mangui.HLS.parsing {


    import flash.events.*;
    import flash.utils.ByteArray;
    import flash.net.*;
    import org.mangui.HLS.utils.*;

    /** Helpers for parsing M3U8 files. **/
    public class Manifest {


        /** Starttag for a fragment. **/
        public static const FRAGMENT:String = '#EXTINF:';
        /** Header tag that must be at the first line. **/
        public static const HEADER:String = '#EXTM3U';
        /** Starttag for a level. **/
        public static const LEVEL:String = '#EXT-X-STREAM-INF:';
        /** Tag that delimits the end of a playlist. **/
        public static const ENDLIST:String = '#EXT-X-ENDLIST';
        /** Tag that provides the sequence number. **/
        private static const SEQNUM:String = '#EXT-X-MEDIA-SEQUENCE:';
        /** Tag that provides the target duration for each segment. **/
        private static const TARGETDURATION:String = '#EXT-X-TARGETDURATION:';
        /** Tag that indicates discontinuity in the stream */
        private static const DISCONTINUITY:String = '#EXT-X-DISCONTINUITY';
        /** Tag that provides date/time information */
        private static const PROGRAMDATETIME:String = '#EXT-X-PROGRAM-DATE-TIME';
        /** Tag that provides fragment decryption info */
        private static const KEY:String = '#EXT-X-KEY:';

        /** Index in the array with levels. **/
        private var _index:Number;
        /** URLLoader instance. **/
        private var _urlloader:URLLoader;
        /** Function to callback loading to. **/
        private var _success:Function;
        /** URL of an M3U8 playlist. **/
        private var _url:String;


        /** Load a playlist M3U8 file. **/
        public function loadPlaylist(url:String,success:Function,error:Function,index:Number):void {
            _url = url;
            _success = success;
            _index = index;
            _urlloader = new URLLoader();
            _urlloader.addEventListener(Event.COMPLETE,_loaderHandler);
            _urlloader.addEventListener(IOErrorEvent.IO_ERROR,error);
            _urlloader.addEventListener(SecurityErrorEvent.SECURITY_ERROR,error);
            _urlloader.load(new URLRequest(url));
        };


        /** The M3U8 playlist was loaded. **/
        private function _loaderHandler(event:Event):void {
            _success(String(event.target.data),_url,_index);
        };

        private static function zeropad(str:String, length:uint):String {
           while(str.length < length) {
             str = "0" + str;
           }
           return str;
        }

        /** Extract fragments from playlist data. **/
        public static function getFragments(data:String,base:String=''):Array {
            var fragments:Array = [];
            var lines:Array = data.split("\n");
            //fragment seqnum
            var seqnum:Number = 0;
            // fragment start time (in sec)
            var start_time:Number = 0;
            var program_date:Number=0;
            /* URL of decryption key */
            var decrypt_url:String = null;
            /* Initialization Vector */
            var decrypt_iv:ByteArray = null;
            // fragment continuity index incremented at each discontinuity
            var continuity_index:Number = 0;
            var i:Number = 0;

            // first look for sequence number
            while (i < lines.length) {
                if(lines[i].indexOf(Manifest.SEQNUM) == 0) {
                    seqnum = Number(lines[i].substr(Manifest.SEQNUM.length));
                    break;
                 }
                 i++;
               }
            i = 0;
            while (i < lines.length) {
              if(lines[i].indexOf(Manifest.KEY) == 0) {
                //#EXT-X-KEY:METHOD=AES-128,URI="https://priv.example.com/key.php?r=52",IV=.....
                var keyLine:String= lines[i].substr(Manifest.KEY.length);
                // reset previous values
                decrypt_url = null;
                decrypt_iv = null;
                // remove space, single and double quote
                var replacespace:RegExp = new RegExp("\\s+","g");
                var replacesinglequote:RegExp = new RegExp("\\\'","g");
                var replacedoublequote:RegExp = new RegExp("\\\"","g");
                keyLine=keyLine.replace(replacespace,"");
                keyLine=keyLine.replace(replacesinglequote,"");
                keyLine=keyLine.replace(replacedoublequote,"");
                var keyArray:Array = keyLine.split(",");
                for each(var keyProperty:String in keyArray) {
                  var delimiter:Number = keyProperty.indexOf("=");
                  if(delimiter == -1) {
                    throw new Error("invalid playlist, no delimiter while parsing:" + keyProperty);
                  }
                  var tag:String = keyProperty.substr(0,delimiter).toUpperCase();
                  var value:String = keyProperty.substr(delimiter+1);
                  switch(tag) {
                    case "METHOD":
                      switch (value) {
                        case "NONE":
                        case "AES-128":
                          break;
                        case "AES-SAMPLE":
                        throw new Error("encryption method " + value + "not supported (yet ;-))");
                        default:
                        throw new Error("invalid encryption method " + value);
                          break;
                      }
                      break;
                    case "URI":
                      decrypt_url = _extractURL(value,base);
                      break;
                    case "IV":
                       var decrypt_iv_str:String = zeropad(value.substr("0x".length),32);
                       decrypt_iv = new ByteArray();
                       decrypt_iv.writeMultiByte(decrypt_iv_str,"ascii");
                      break;
                    case "KEYFORMAT":
                    case "KEYFORMATVERSIONS":
                    default:
                      break;
                  }
                }
              } else if(lines[i].indexOf(Manifest.PROGRAMDATETIME) == 0) {
                //Log.txt(lines[i]);
                var year:Number    = lines[i].substr(25,4);
                var month:Number   = lines[i].substr(30,2);
                var day:Number     = lines[i].substr(33,2);
                var hour:Number    = lines[i].substr(36,2);
                var minutes:Number = lines[i].substr(39,2);
                var seconds:Number = lines[i].substr(42,2);
                program_date = new Date(year,month,day,hour,minutes,seconds).getTime();
              } else if(lines[i].indexOf(Manifest.FRAGMENT) == 0) {
                var comma_position:Number = lines[i].indexOf(',');
                var duration:Number = (comma_position == -1) ? lines[i].substr(Manifest.FRAGMENT.length) : lines[i].substr(Manifest.FRAGMENT.length,comma_position-Manifest.FRAGMENT.length);
                // Look for next non-blank line, for url
                i++;
                while(lines[i].match(/^\s*$/)) {
                  i++;
                }
                var url:String = _extractURL(lines[i],base);
                
                /* as per HLS spec : 
                    if IV not defined, then use seqnum as IV :
                    http://tools.ietf.org/html/draft-pantos-http-live-streaming-11#section-5.2 
                 */
                var fragment_decrypt_iv:ByteArray;
                if(decrypt_url !=null) {
                  if(decrypt_iv != null) {
                    fragment_decrypt_iv = decrypt_iv;
                  } else {
                       fragment_decrypt_iv = new ByteArray();
                       fragment_decrypt_iv.writeMultiByte(zeropad(seqnum.toString(16),32),"ascii");
                  }
                  Log.txt("seqnum/decrypt_url/decrypt_iv:" +seqnum+"/"+decrypt_url+"/"+fragment_decrypt_iv.toString());
                } else {
                  fragment_decrypt_iv = null;
                }
                fragments.push(new Fragment(url,duration,seqnum++,start_time,continuity_index,program_date,decrypt_url,fragment_decrypt_iv));
                start_time+=duration;
                program_date = 0;
              } else if(lines[i].indexOf(Manifest.DISCONTINUITY) == 0) {
                continuity_index++;
                Log.txt("discontinuity found at seqnum " + seqnum);
              }
              i++;
            }
            if(fragments.length == 0) {
                //throw new Error("No TS fragments found in " + base);
                Log.txt("No TS fragments found in " + base);
            }
            return fragments;
        };


        /** Extract levels from manifest data. **/
        public static function extractLevels(data:String,base:String=''):Array {
            var levels:Array = [];
            var lines:Array = data.split("\n");
            var i:Number = 0;
            while (i<lines.length) {
                if(lines[i].indexOf(Manifest.LEVEL) == 0) {
                    var level:Level = new Level();
                    var params:Array = lines[i].substr(Manifest.LEVEL.length).split(',');
                    for(var j:Number = 0; j<params.length; j++) {
                        if(params[j].indexOf('BANDWIDTH') > -1) {
                            level.bitrate = params[j].split('=')[1];
                        } else if (params[j].indexOf('RESOLUTION') > -1) {
                            level.height  = params[j].split('=')[1].split('x')[1];
                            level.width = params[j].split('=')[1].split('x')[0];
                        } else if (params[j].indexOf('CODECS') > -1 && lines[i].indexOf('avc1') == -1) {
                            level.audio = true;
                        }
                    }
					// Look for next non-blank line, for url
                    i++;
					while(lines[i].match(/^\s*$/)) {
						i++;
					}
                    level.url = Manifest._extractURL(lines[i],base);
                    levels.push(level);
                }
                i++;
            }
            if(levels.length == 0) {
                throw new Error("No playlists found in Manifest: " + base);
            }
            levels.start_seqnum = -1;
            levels.end_seqnum = -1;
            levels.sortOn('bitrate',Array.NUMERIC);
            return levels;
        };


        /** Extract whether the stream is live or ondemand. **/
        public static function hasEndlist(data:String):Boolean {
            if(data.indexOf(Manifest.ENDLIST) > 0) {
                return true;
            } else {
                return false;
            }
        };

        public static function getTargetDuration(data:String):Number {
            var lines:Array = data.split("\n");
            var i:Number = 0;
            var targetduration:Number = 0;

            // first look for target duration
            while (i < lines.length) {
                if(lines[i].indexOf(Manifest.TARGETDURATION) == 0) {
                    targetduration = Number(lines[i].substr(Manifest.TARGETDURATION.length));
                    break;
                 }
                 i++;
            }
            return targetduration;
       }


        /** Extract URL (check if absolute or not). **/
        private static function _extractURL(path:String,base:String):String {
         var _prefix:String = null;
         var _suffix:String = null;
          if(path.substr(0,7) == 'http://' || path.substr(0,8) == 'https://') {
            return path;
          } else {
            // Remove querystring
            if(base.indexOf('?') > -1) {
              base = base.substr(0,base.indexOf('?'));
            }
            // domain-absolute
            if(path.substr(0,1) == '/') {
              // base = http[s]://domain/subdomain:1234/otherstuff
              // prefix = http[s]://
              // suffix = domain/subdomain:1234/otherstuff
              _prefix=base.substr(0,base.indexOf("//")+2);
              _suffix=base.substr(base.indexOf("//")+2);
              // return http[s]://domain/subdomain:1234/path
              return _prefix+_suffix.substr(0,_suffix.indexOf("/"))+path;
            } else {
              return base.substr(0,base.lastIndexOf('/') + 1) + path;
            }
          }
        };


    }


}