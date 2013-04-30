package com.longtailvideo.HLS.streaming {


    import com.longtailvideo.HLS.*;
    import com.longtailvideo.HLS.muxing.*;
    import com.longtailvideo.HLS.streaming.*;
    import com.longtailvideo.HLS.utils.*;
    
    import flash.events.*;
    import flash.net.*;
    import flash.text.engine.TabStop;
    import flash.utils.ByteArray;
    import flash.utils.Timer;
    
    import mx.core.ByteArrayAsset;


    /** Class that fetches fragments. **/
    public class Loader {


        /** Multiplier for bitrate/bandwidth comparison. **/
        public static const BITRATE_FACTOR:Number = 0.9;
        /** Multiplier for level/display width comparison. **/
        public static const WIDTH_FACTOR:Number = 1.50;


        /** Reference to the adaptive controller. **/
        private var _adaptive:Adaptive;
        /** Bandwidth of the last fragment load. **/
        private var _bandwidth:int = 0;
        /** Callback for passing forward the fragment tags. **/
        private var _callback:Function;
        /** Fragment that's currently loading. **/
        private var _fragment:Number;
        /** Quality level of the last fragment load. **/
        private var _level:int = 0;
        /** Reference to the manifest levels. **/
        private var _levels:Array;
        /** Util for loading the fragment. **/
        private var _urlstreamloader:URLStream;
         /** Data read from stream loader **/
        private var _loaderData:ByteArray;
        /** Time the loading started. **/
        private var _started:Number;
        /** Did the stream switch quality levels. **/
        private var _switchlevel:Boolean;
        /** Width of the stage. **/
        private var _width:Number = 480;
        /** Buffer size in seconds. **/
        private var _buffer:Number = 0;
		/** The current TS packet being read **/
		private var _ts:TS;
		/** The current tags vector being created as the TS packet is read **/
		private var _tags:Vector.<Tag>;


        /** Create the loader. **/
        public function Loader(adaptive:Adaptive):void {
            _adaptive = adaptive;
            _adaptive.addEventListener(AdaptiveEvent.MANIFEST, _levelsHandler);
            _urlstreamloader = new URLStream();
            _urlstreamloader.addEventListener(IOErrorEvent.IO_ERROR, _errorHandler);
            _urlstreamloader.addEventListener(Event.COMPLETE, _completeHandler);
        };


        /** Fragment load completed. **/
        private function _completeHandler(event:Event):void {
			   //Log.txt("loading completed");
            // Calculate bandwidth
            var delay:Number = (new Date().valueOf() - _started) / 1000;
            _bandwidth = Math.round(_urlstreamloader.bytesAvailable * 8 / delay);
			// Collect stream loader data
			if( _urlstreamloader.bytesAvailable > 0 ) {
				_loaderData = new ByteArray();
				_urlstreamloader.readBytes(_loaderData,0,0);
			}
            // Extract tags.     
			_tags = new Vector.<Tag>();
            _parseTS();
        };
		
		
		/** Kill any active load **/
		public function clearLoader():void {
			if(_urlstreamloader.connected) {
				_urlstreamloader.close();
			}
			_ts = null;
			_tags = null;
		}


        /** Catch IO and security errors. **/
        private function _errorHandler(event:ErrorEvent):void {
            _adaptive.dispatchEvent(new AdaptiveEvent(AdaptiveEvent.ERROR, event.toString()));
        };


        /** Get the quality level for the next fragment. **/
        public function getLevel():Number {
            return _level;
        };


        /** Get the current QOS metrics. **/
        public function getMetrics():Object {
            return { bandwidth:_bandwidth, level:_level, screenwidth:_width , buffer:_buffer};
        };


        /** Load a fragment **/
        public function load(seqnum:Number, callback:Function, buffer:Number):void {
            if(buffer == 0) {
                _switchlevel = true;
            }
            if(_urlstreamloader.connected) {
                _urlstreamloader.close();
            }
            _started = new Date().valueOf();
            _updateLevel();
            
            _fragment = _levels[_level].getindex(seqnum);
            _callback = callback;
            Log.txt("Loading frag "+ _fragment +  "/" + (_levels[_level].fragments.length-1) + ",level "+ _level + " seqnum " + seqnum + "/" + _levels[_level].maxseqnum);
            //Log.txt("loading "+_levels[_level].fragments[_fragment].url);
            try {
               _urlstreamloader.load(new URLRequest(_levels[_level].fragments[_fragment].url));
            } catch (error:Error) {
                _adaptive.dispatchEvent(new AdaptiveEvent(AdaptiveEvent.ERROR, error.message));
            }
        };

        /** Store the manifest data. **/
        private function _levelsHandler(event:AdaptiveEvent):void {
            _levels = event.levels;
        };


        /** Parse a TS fragment. **/
        private function _parseTS():void {
            _ts = new TS(_loaderData);
			_ts.addEventListener(TS.READCOMPLETE, _readHandler);
			_ts.startReading();
        };
		
		
		/** Handles the actual reading of the TS fragment **/
		private function _readHandler(e:Event):void {
			// Save codecprivate when not available.
			if(!_levels[_level].avcc && !_levels[_level].adif) {
				_levels[_level].avcc = _ts.getAVCC();
				_levels[_level].adif = _ts.getADIF();
			}
			// Push codecprivate tags only when switching.
			if(_switchlevel) {
				if (_ts.videoTags.length > 0) {
					// Audio only file don't have videoTags[0]
					var avccTag:Tag = new Tag(Tag.AVC_HEADER,_ts.videoTags[0].pts,_ts.videoTags[0].dts,true,_level,_fragment);
					avccTag.push(_levels[_level].avcc,0,_levels[_level].avcc.length);
					_tags.push(avccTag);
				}
				if (_ts.audioTags.length > 0) {
					if(_ts.audioTags[0].type == Tag.AAC_RAW) {
						var adifTag:Tag = new Tag(Tag.AAC_HEADER,_ts.audioTags[0].pts,_ts.audioTags[0].dts,true,_level,_fragment);
						adifTag.push(_levels[_level].adif,0,2)
						_tags.push(adifTag);
					}
				}
			}
			// Push regular tags into buffer.
			for(var i:Number=0; i < _ts.videoTags.length; i++) {
				_ts.videoTags[i].level = _level;
				_ts.videoTags[i].fragment = _fragment;
				_tags.push(_ts.videoTags[i]);
			}
			for(var j:Number=0; j < _ts.audioTags.length; j++) {
				_ts.audioTags[j].level = _level;
				_ts.audioTags[j].fragment = _fragment;
				_tags.push(_ts.audioTags[j]);
			}
			
			// change the media to null if the file is only audio.
			if(_ts.videoTags.length == 0) {
				_adaptive.dispatchEvent(new AdaptiveEvent(AdaptiveEvent.AUDIO));
			}
			
			try {
				_switchlevel = false;
				_callback(_tags);
				_adaptive.dispatchEvent(new AdaptiveEvent(AdaptiveEvent.FRAGMENT, getMetrics()));
			} catch (error:Error) {
				_adaptive.dispatchEvent(new AdaptiveEvent(AdaptiveEvent.ERROR, error.toString()));
			}
		}


        /** Update the quality level for the next fragment load. **/
        private function _updateLevel():void {
            var level:Number = -1;
            // Select the lowest non-audio level.
            for(var i:Number = 0; i < _levels.length; i++) {
                if(!_levels[i].audio) {
                    level = i;
                    break;
                }
            }
            if(level == -1) {
				Log.txt("No other quality levels are available"); 
				return;
            }
            // Then update with highest possible level.
            for(var j:Number = _levels.length - 1; j > 0; j--) {
				if( _fitsLevel(j) ) {
                    level = j;
                    break;
                }
            }
            //Log.txt("current Level " + _level + " fits Level " + level);
            // Next restrict upswitches to 1 level at a time.
            if(level != _level) {
                if(level > _level) {
                    _level++;
                } else {
                    _level = level;
                }
                _switchlevel = true;
                _adaptive.dispatchEvent(new AdaptiveEvent(AdaptiveEvent.SWITCH,_level));
            }
            ///Log.txt("updated Level " + _level);
        };
		
		
		/** Check if level fits bandwidth and width conditions **/
		private function _fitsLevel(level:Number):Boolean {
			if( _levels[level].bitrate <= _bandwidth * BITRATE_FACTOR && _levels[level].width <= _width * WIDTH_FACTOR ) {
				return true; 
			}
			else {
				return false;
			}
		};
		
		
        /** Provide the loader with screen width information. **/
        public function setWidth(width:Number):void {
            _width = width;
        }

        /** Provide the loader with buffer information. **/
        public function setBuffer(buffer:Number):void {
            _buffer = buffer;
            _adaptive.dispatchEvent(new AdaptiveEvent(AdaptiveEvent.BUFFER, getMetrics()));
        }
    }
}