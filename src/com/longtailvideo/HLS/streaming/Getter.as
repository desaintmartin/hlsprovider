package com.longtailvideo.HLS.streaming {


    import com.longtailvideo.HLS.*;
    import com.longtailvideo.HLS.parsing.*;
    import com.longtailvideo.HLS.utils.*;
    import flash.events.*;
    import flash.net.*;
    import flash.utils.*;


    /** Loader for adaptive streaming manifests. **/
    public class Getter {


        /** Reference to the adaptive framework controller. **/
        private var _adaptive:Adaptive;
        /** Array with levels. **/
        private var _levels:Array = [];
        /** Object that fetches the manifest. **/
        private var _urlloader:URLLoader;
        /** Link to the M3U8 file. **/
        private var _url:String;
        /** Amount of playlists still need loading. **/
        private var _toLoad:Number;
        /** are all playlists filled ? **/
        private var _canStart:Boolean = false;
        /** initial reload timer **/
        private var _fragmentDuration:Number = 5000;
        /** Timeout ID for reloading live playlists. **/
        private var _timeoutID:Number;
        /** Streaming type (live, ondemand). **/
        private var _type:String;
        /** last reload manifest time **/
        private var _reload_playlists_timer:uint;

        /** Setup the loader. **/
        public function Getter(adaptive:Adaptive) {
            _adaptive = adaptive;
            _adaptive.addEventListener(AdaptiveEvent.STATE,_stateHandler);
            _levels = [];
            _urlloader = new URLLoader();
            _urlloader.addEventListener(Event.COMPLETE,_loaderHandler);
            _urlloader.addEventListener(IOErrorEvent.IO_ERROR,_errorHandler);
            _urlloader.addEventListener(SecurityErrorEvent.SECURITY_ERROR,_errorHandler);
        };


        /** Loading failed; return errors. **/
        private function _errorHandler(event:ErrorEvent):void {
            var txt:String = "Cannot load M3U8: "+event.text;
            if(event is SecurityErrorEvent) {
                txt = "Cannot load M3U8: crossdomain access denied";
            } else if (event is IOErrorEvent) {
                txt = "Cannot load M3U8: 404 not found";
            }
            _adaptive.dispatchEvent(new AdaptiveEvent(AdaptiveEvent.ERROR,txt));
        };

        /** return true if first two levels contain at least 2 fragments **/
        private function _areFirstLevelsFilled():Boolean {
           for(var i:Number = 0; (i < _levels.length) && (i < 2); i++) {
            if(_levels[i].fragments.length < 2) {
               return false;
            }
         }
         return true;
        };

        /** Return the current manifest. **/
        public function getLevels():Array {
            return _levels;
        };


        /** Return the stream type. **/
        public function getType():String {
            return _type;
        };


        /** Load the manifest file. **/
        public function load(url:String):void {
            _url = url;
            _levels = [];
            _reload_playlists_timer = getTimer();
            _urlloader.load(new URLRequest(_url));
        };


        /** Manifest loaded; check and parse it **/
        private function _loaderHandler(event:Event):void {
            _loadManifest(String(event.target.data));
        };



        /** First Load M3U8 playlist. **/
        private function _loadPlaylist(string:String,url:String,index:Number):void {
            if(string != null && string.length != 0) {
               var frags:Array = Manifest.getFragments(string,url);
               for(var i:Number = 0; i<frags.length; i++) {
                   _levels[index].push(frags[i]);
               }
            }
            if(--_toLoad == 0) {
               /** Loading all playlists has been completed. **/
               _levels.sortOn('bitrate',Array.NUMERIC);
               _allLoadCompleted(string);
            }
        };
        
        /** Compare a reloaded playlist to the original. **/
        private function _reloadPlaylist(string:String,url:String,index:Number):void {
            if(string != null && string.length != 0) {
               var frags:Array = Manifest.getFragments(string,url);
               var newFragIdx:Number = 0;
               if (_levels[index].fragments.length > 0) {
                  // retrieve last URL from level context
                  var lastURL:String = _levels[index].fragments[_levels[index].fragments.length-1].url;
                  // look for last URL in new fragments
                  for(newFragIdx = 0; newFragIdx < frags.length ; newFragIdx++) {
                     if(frags[newFragIdx].url == lastURL) {
                        newFragIdx++;
                        break;
                     }
                  }
               }
               // we need to push all URLs from newFragIdx
               for(var j:Number = newFragIdx; j < frags.length; j++) {
                   _levels[index].push(frags[j]);
               }
            }
            if(--_toLoad == 0) {
              _allLoadCompleted(string);
            }
        };

        /** load First Level Playlist **/
        private function _loadManifest(string:String):void {
            // Check for M3U8 playlist or manifest.
            if(string.indexOf(Manifest.HEADER) == 0) {
               //1 level playlist, create unique level and parse playlist
                if(string.indexOf(Manifest.FRAGMENT) > 0) {
                    var level:Level = new Level();
                    level.url = _url;
                    _levels.push(level);
                    _toLoad = 1;
                    Log.txt("1 Level Playlist, load it");
                    _loadPlaylist(string,_url,0);
                } else if(string.indexOf(Manifest.LEVEL) > 0) {
                  //adaptative playlist, extract levels from playlist, get them and parse them
                  _levels = Manifest.extractLevels(string,_url);
                  _toLoad = _levels.length;
                  Log.txt("adaptive Playlist, with " + _toLoad + " levels");
                  for(var i:Number = 0; i < _levels.length; i++) {
                      new Manifest().loadPlaylist(_levels[i].url,_loadPlaylist,_errorHandler,i);
                  }
                }
            } else {
                var message:String = "Manifest is not a valid M3U8 file" + _url;
                _adaptive.dispatchEvent(new AdaptiveEvent(AdaptiveEvent.ERROR,message));
            }
        };

        /** Reload all M3U8 playlists (for live). **/
        private function _reloadPlaylists():void {
            _reload_playlists_timer = getTimer();
            _toLoad = _levels.length;
            for(var i:Number = 0; i < _levels.length; i++) {
                new Manifest().loadPlaylist(_levels[i].url,_reloadPlaylist,_errorHandler,i);
            }
        };

        /** Compare a reloaded playlist to the original. **/
        private function _allLoadCompleted(string:String):void {
            // Check whether the stream is live or not finished yet
            if(Manifest.hasEndlist(string)) {
                _type = AdaptiveTypes.VOD;
            } else {
                _type = AdaptiveTypes.LIVE;
                var timeout:Number = Math.max(100,_reload_playlists_timer + _fragmentDuration - getTimer());
                Log.txt("Live Playlist parsing finished: reload in " + timeout + " ms");
                _timeoutID = setTimeout(_reloadPlaylists,timeout);
            }
               if (!_canStart && (_canStart =_areFirstLevelsFilled())) {
                  Log.txt("first 2 levels are filled with at least 2 fragments, notify event");
                  _fragmentDuration = _levels[0].fragments[0].duration*1000;
                  _adaptive.dispatchEvent(new AdaptiveEvent(AdaptiveEvent.MANIFEST,_levels));
              }
        }

        /** When the framework idles out, reloading is cancelled. **/
        public function _stateHandler(event:AdaptiveEvent):void {
            if(event.state == AdaptiveStates.IDLE) {
                clearTimeout(_timeoutID);
            }
        };
    }
}