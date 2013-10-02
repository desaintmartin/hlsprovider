package com.mangui.HLS.streaming {


    import com.mangui.HLS.*;
    import com.mangui.HLS.muxing.*;
    import com.mangui.HLS.parsing.*;
    import com.mangui.HLS.streaming.*;
    import com.mangui.HLS.utils.*;
    
    import flash.events.*;
    import flash.net.*;
    import flash.text.engine.TabStop;
    import flash.utils.ByteArray;
    import flash.utils.Timer;
    
    import mx.core.ByteArrayAsset;


    /** Class that fetches fragments. **/
    public class FragmentLoader {
        /** Reference to the HLS controller. **/
        private var _hls:HLS;
        /** Bandwidth of the last loaded fragment **/
        private var _last_bandwidth:int = 0;
        /** fetch time of the last loaded fragment **/
        private var _last_fetch_duration:Number = 0;
        /** duration of the last loaded fragment **/
        private var _last_segment_duration:Number = 0;
        /** Callback for passing forward the fragment tags. **/
        private var _callback:Function;
        /** sequence number that's currently loading. **/
        private var _seqnum:Number;
        /** Quality level of the last fragment load. **/
        private var _level:int = 0;
        /* overrided quality_manual_level level */
        private var _manual_level:int = -1;
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
        /** The current TS packet being read **/
        private var _ts:TS;
        /** The current tags vector being created as the TS packet is read **/
        private var _tags:Vector.<Tag>;
        /** switch up threshold **/
        private var _switchup:Array = null;
        /** switch down threshold **/
        private var _switchdown:Array = null;
        /* variable to deal with IO Error retry */
        private var _bIOError:Boolean=false; 
        private var _nIOErrorCount:Number=0;
        /** boolean to track playlist PTS loading/loaded state */
        private var _playlist_pts_loading:Boolean=false;
        private var _playlist_pts_loaded:Boolean=false;

        /** Create the loader. **/
        public function FragmentLoader(hls:HLS):void {
            _hls = hls;
            _hls.addEventListener(HLSEvent.MANIFEST, _levelsHandler);
            _urlstreamloader = new URLStream();
            _urlstreamloader.addEventListener(IOErrorEvent.IO_ERROR, _errorHandler);
            //_urlstreamloader.addEventListener(HTTPStatusEvent.HTTP_STATUS, _httpStatusHandler);
            _urlstreamloader.addEventListener(Event.COMPLETE, _completeHandler);
        };

         private function _httpStatusHandler(event:HTTPStatusEvent):void {
            //Log.txt("httpStatusHandler: " + event);
          }

        /** Fragment load completed. **/
        private function _completeHandler(event:Event):void {
            //Log.txt("loading completed");
            _nIOErrorCount = 0;
            _bIOError = false;
            // Calculate bandwidth
            _last_fetch_duration = (new Date().valueOf() - _started);
            _last_bandwidth = Math.round(_urlstreamloader.bytesAvailable * 8000 / _last_fetch_duration);
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
      _nIOErrorCount = 0;
      _bIOError = false;
		}


        /** Catch IO and security errors. **/
        private function _errorHandler(event:ErrorEvent):void {
            _bIOError=true;
            _nIOErrorCount++;
            if (_nIOErrorCount >= 5) {
              _hls.dispatchEvent(new HLSEvent(HLSEvent.ERROR, event.toString()));
            }
        };
        
        public function getIOError():Boolean { 
          return _bIOError;
        };

        /** Get the quality level for the next fragment. **/
        public function getLevel():Number {
            return _level;
        };

        /** Get the suggested buffer length from rate adaptation algorithm **/
        public function getBufferLength():Number {
            if(_levels != null) {
               return _levels[_level].averageduration*Math.max((_levels[_levels.length-1].bitrate/_levels[0].bitrate),6);
            } else {
               return 10;
            }
        };

        /** Get the current QOS metrics. **/
        public function getMetrics():Object {
            return { bandwidth:_last_bandwidth, level:_level, screenwidth:_width };
        };

        /** Get the playlist start PTS. **/
        public function getPlayListStartPTS():Number {
            return _levels[_level].getLevelstartPTS();
        };

        /** Get the playlist duration **/
        public function getPlayListDuration():Number {
            return _levels[_level].duration;
        };

        /** Get segment average duration **/
        public function getSegmentAverageDuration():Number {
            return _levels[_level].averageduration;
        };

        /** Load a fragment **/
        public function loadfragment(position:Number, pts:Number, buffer:Number,callback:Function, restart:Boolean):Number {
          //Log.txt("loadfragment(position/pts):(" + position + "/" + pts + ")");
          
            if(_urlstreamloader.connected) {
                _urlstreamloader.close();
            }
            var level:Number;
            
            /* in case IO Error has been raised, stick to same level */
            if(_bIOError == true) {
              level = _level;
            /* else if last fragment was loaded for PTS analysis,
            stick to same level */
            } else if(_playlist_pts_loaded == true) {
              _playlist_pts_loaded = false;
              level = _level;
              } else {
              if (_manual_level == -1) {
                 level = _getnextlevel(buffer);
              } else {
                 level = _manual_level;
              }
            }
            // reset IO Error when loading new fragment
            _bIOError = false;
                        
            var seqnum:Number;
            if(pts != 0) {
               var playliststartpts:Number = _levels[level].getLevelstartPTS();
               if(playliststartpts == Number.NEGATIVE_INFINITY) {
                  seqnum = _levels[level].fragments[1].seqnum;
                  Log.txt("loadfragment : requested pts:" + pts + ",playlist pts undefined, get PTS from 2nd segment:"+seqnum);
                  _playlist_pts_loading = true;
                } else if(pts < getPlayListStartPTS()) {
                  Log.txt("loadfragment : requested pts:" + pts + ",playliststartpts:"+playliststartpts);
                  return -1;
               } else {
                  seqnum= _levels[level].getSeqNumNearestPTS(pts);
                  Log.txt("loadfragment : requested pts:" + pts + ",seqnum:"+seqnum);
                  // check if PTS is greater than max PTS of this playlist
                  if(Number.POSITIVE_INFINITY == seqnum) {
                     // if greater, load last fragment if not already loaded
                     if (_levels[level].end_seqnum != _levels[level].pts_seqnum) {
                      seqnum = _levels[level].end_seqnum;
                      Log.txt("loadfragment : requested pts:" + pts + ",out of bound, load PTS from last fragment:"+seqnum);
                      _playlist_pts_loading = true;
                    } else {
                      // last fragment already loaded, return 1 to tell caller that seqnum is not yet available in playlist
                      return 1;
                    }
                  }
               }
            } else {
               if (_hls.getType() == HLSTypes.LIVE) {
                  var seek_position:Number;
               /* follow HLS spec :
                  If the EXT-X-ENDLIST tag is not present 
                  and the client intends to play the media regularly (i.e. in playlist 
                  order at the nominal playback rate), the client SHOULD NOT
                  choose a segment which starts less than three target durations from
                  the end of the Playlist file */
                  var maxLivePosition:Number = Math.max(0,_levels[level].duration -3*_levels[level].averageduration);                  
                  if (position == 0) {
                     // seek 3 fragments from end
                     seek_position = maxLivePosition;
                  } else {
                     seek_position = Math.min(position,maxLivePosition);
                  }
                  Log.txt("loadfragment : requested position:" + position + ",seek position:"+seek_position);
                  position = seek_position;
               }
               seqnum= _levels[level].getSeqNumNearestPosition(position);
            }
            if(seqnum <0) {
               //fragment not available yet
               return 1;
            }
            _callback = callback;
            if(level != _level) {
                _level = level;
                _switchlevel = true;
                _hls.dispatchEvent(new HLSEvent(HLSEvent.SWITCH,_level));
            }

            if(restart == true) {
                _switchlevel = true;
            }
            _started = new Date().valueOf();
            var frag:Fragment = _levels[_level].getFragmentfromSeqNum(seqnum);
            _seqnum = seqnum;
            //Log.txt("Loading SN "+ _seqnum +  " of [" + (_levels[_level].start_seqnum) + "," + (_levels[_level].end_seqnum) + "],level "+ _level + ",URL=" + frag.url);
            Log.txt("Loading SN "+ _seqnum +  " of [" + (_levels[_level].start_seqnum) + "," + (_levels[_level].end_seqnum) + "],level "+ _level);
            try {
               _urlstreamloader.load(new URLRequest(frag.url));
            } catch (error:Error) {
                _hls.dispatchEvent(new HLSEvent(HLSEvent.ERROR, error.message));
            }
            return 0;
        };

        /** Store the manifest data. **/
        private function _levelsHandler(event:HLSEvent):void {
            _levels = event.levels;
            _level = 0;
        };


        /** Parse a TS fragment. **/
        private function _parseTS():void {
            _ts = new TS(_loaderData);
			_ts.addEventListener(TS.READCOMPLETE, _readHandler);
			_ts.startReading();
        };
		
		
    /** Handles the actual reading of the TS fragment **/
    private function _readHandler(e:Event):void {
       var min_pts:Number = Number.POSITIVE_INFINITY;
       var max_pts:Number = Number.NEGATIVE_INFINITY;
       
       /* in case we are loading first fragment of a playlist, just retrieve 
       minimum PTS value to synchronize playlist PTS / sequence number. 
       then return an error. this will force the Buffer Manager to reload the
       fragment at right offset */
       if(_playlist_pts_loading == true) {
          for(var k:Number=0; k < _ts.audioTags.length; k++) {
             min_pts = Math.min(min_pts,_ts.audioTags[k].pts);
             max_pts = Math.max(max_pts,_ts.audioTags[k].pts);
         }
         _levels[_level].pts_value = min_pts;
         _levels[_level].pts_seqnum = _seqnum;
         Log.txt("Loaded  SN " + _seqnum +  " of [" + (_levels[_level].start_seqnum) + "," + (_levels[_level].end_seqnum) + "],level "+ _level + " min/max PTS:" + min_pts +"/" + max_pts);
         
         _playlist_pts_loading = false;
         _playlist_pts_loaded = true;
         _bIOError = true;
         return;
       }

      // Save codecprivate when not available.
      if(!_levels[_level].avcc && !_levels[_level].adif) {
        _levels[_level].avcc = _ts.getAVCC();
        _levels[_level].adif = _ts.getADIF();
      }
      // Push codecprivate tags only when switching.
      if(_switchlevel) {
        if (_ts.videoTags.length > 0) {
          // Audio only file don't have videoTags[0]
          var avccTag:Tag = new Tag(Tag.AVC_HEADER,_ts.videoTags[0].pts,_ts.videoTags[0].dts,true);
          avccTag.push(_levels[_level].avcc,0,_levels[_level].avcc.length);
          _tags.push(avccTag);
        }
        if (_ts.audioTags.length > 0) {
          if(_ts.audioTags[0].type == Tag.AAC_RAW) {
            var adifTag:Tag = new Tag(Tag.AAC_HEADER,_ts.audioTags[0].pts,_ts.audioTags[0].dts,true);
            adifTag.push(_levels[_level].adif,0,2)
            _tags.push(adifTag);
          }
        }
      }


      // Push regular tags into buffer.
      for(var i:Number=0; i < _ts.videoTags.length; i++) {
         //min_pts = Math.min(min_pts,_ts.videoTags[i].pts);
         //max_pts = Math.max(max_pts,_ts.videoTags[i].pts);
        _tags.push(_ts.videoTags[i]);
      }
      for(var j:Number=0; j < _ts.audioTags.length; j++) {
         min_pts = Math.min(min_pts,_ts.audioTags[j].pts);
         max_pts = Math.max(max_pts,_ts.audioTags[j].pts);
        _tags.push(_ts.audioTags[j]);
      }
      
      // change the media to null if the file is only audio.
      if(_ts.videoTags.length == 0) {
        _hls.dispatchEvent(new HLSEvent(HLSEvent.AUDIO));
      }
      
      try {
         _switchlevel = false;
         _levels[_level].pts_value = min_pts;
         _levels[_level].pts_seqnum = _seqnum;

         Log.txt("Loaded  SN " + _seqnum +  " of [" + (_levels[_level].start_seqnum) + "," + (_levels[_level].end_seqnum) + "],level "+ _level + " min/max PTS:" + min_pts +"/" + max_pts);
         _last_segment_duration = max_pts-min_pts;
         var frag:Fragment = _levels[_level].getFragmentfromSeqNum(_seqnum);
         if ((frag != null) && (frag.duration !=  (_last_segment_duration/1000))) {
           frag.duration = _last_segment_duration/1000;
           _levels[_level].updateStart();
         }
         _callback(_tags,min_pts,max_pts);
         _hls.dispatchEvent(new HLSEvent(HLSEvent.FRAGMENT, getMetrics()));
      } catch (error:Error) {
        _hls.dispatchEvent(new HLSEvent(HLSEvent.ERROR, error.toString()));
      }
    }


        /** Update the quality level for the next fragment load. **/
        private function _getnextlevel(buffer:Number):Number {
         var i:Number;
            if (_switchup == null) {
               var maxswitchup:Number=0;
               var minswitchdwown:Number=Number.MAX_VALUE;
               _switchup = new Array(_levels.length);
               _switchdown = new Array(_levels.length);
               
               for(i=0 ; i < _levels.length-1; i++) {
                  _switchup[i] = (_levels[i+1].bitrate - _levels[i].bitrate) / _levels[i].bitrate;
                  maxswitchup = Math.max(maxswitchup,_switchup[i]);
               }
               for(i=0 ; i < _levels.length-1; i++) {
                  _switchup[i] = Math.min(maxswitchup,2*_switchup[i]);
                  //Log.txt("_switchup["+i+"]="+_switchup[i]);
               }
 
 
               for(i = 1; i < _levels.length; i++) {
                  _switchdown[i] = (_levels[i].bitrate - _levels[i-1].bitrate) / _levels[i].bitrate;
                  minswitchdwown  =Math.min(minswitchdwown,_switchdown[i]);
               }
               for(i = 1; i < _levels.length; i++) {
                  _switchdown[i] = Math.max(2*minswitchdwown,_switchdown[i]);
                  //Log.txt("_switchdown["+i+"]="+_switchdown[i]);
               }
            }
         
            var level:Number = -1;
            // Select the lowest non-audio level.
            for(i = 0; i < _levels.length; i++) {
                if(!_levels[i].audio) {
                    level = i;
                    break;
                }
            }
            if(level == -1) {
                Log.txt("No other quality levels are available"); 
                return -1;
            }
            if(_last_fetch_duration == 0 || _last_segment_duration == 0) {
               return 0;
            }
            var fetchratio:Number = _last_segment_duration/_last_fetch_duration;
            var bufferratio:Number = 1000*buffer/_last_segment_duration;
            //Log.txt("fetchratio:" + fetchratio);
            //Log.txt("bufferratio:" + bufferratio);
            
            if((_level < _levels.length-1) && (fetchratio > (1+_switchup[_level]))) {
               //Log.txt("fetchratio:> 1+_switchup[_level]="+(1+_switchup[_level]));
               Log.txt("switch to level " + (_level+1));
                  //level up
                  return (_level+1);
            } else if(_level > 0 &&((fetchratio < (1-_switchdown[_level])) || (bufferratio < 2)) ) {
                  //Log.txt("bufferratio < 2 || fetchratio: < 1-_switchdown[_level]="+(1-_switchdown[_level]));
                  // find suitable level matching current bandwidth, starting from current level
                  for(var j:Number = _level; j > 0; j--) {
                     if( _levels[j].bitrate <= _last_bandwidth) {
                          Log.txt("switch to level " + j);
                          return j;
                      }
                  }
                  Log.txt("switch to level 0");
                  return 0;
               }
            return _level;
        }

        /** Provide the loader with screen width information. **/
        public function setWidth(width:Number):void {
            _width = width;
        }
        
        /* update playback quality level */
        public function setPlaybackQuality(level:Number):void {
           _manual_level = level;
        };
    }
}