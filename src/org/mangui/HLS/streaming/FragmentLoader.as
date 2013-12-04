package org.mangui.HLS.streaming {


    import org.mangui.HLS.*;
    import org.mangui.HLS.muxing.*;
    import org.mangui.HLS.parsing.*;
    import org.mangui.HLS.streaming.*;
    import org.mangui.HLS.utils.*;

    import flash.events.*;
    import flash.net.*;
    import flash.text.engine.TabStop;
    import flash.utils.ByteArray;
    import flash.utils.Timer;

    /** Class that fetches fragments. **/
    public class FragmentLoader {
        /** Reference to the HLS controller. **/
        private var _hls:HLS;
        /** reference to auto level manager */
        private var _autoLevelManager:AutoLevelManager;
        /** Bandwidth of the last loaded fragment **/
        private var _last_bandwidth:int = 0;
        /** fetch time of the last loaded fragment **/
        private var _last_fetch_duration:Number = 0;
        /** duration of the last loaded fragment **/
        private var _last_segment_duration:Number = 0;
        /** duration of the last loaded fragment **/
        private var _last_segment_start_pts:Number = 0;
        /** continuity counter of the last fragment load. **/
        private var _last_segment_continuity_counter:Number = 0;
        /** program date of the last fragment load. **/
        private var _last_segment_program_date:Number = 0;
        /** last updated level. **/
        private var _last_updated_level:Number = 0;
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
        /** Did a discontinuity occurs in the stream **/
        private var _hasDiscontinuity:Boolean;
        /** Width of the stage. **/
        private var _width:Number = 480;
	/* flag handling load cancelled (if new seek occurs for example) */
        private var _cancel_load:Boolean;
        /* variable to deal with IO Error retry */
        private var _bIOError:Boolean=false;
        private var _nIOErrorDate:Number=0;

        /** boolean to track playlist PTS loading/loaded state */
        private var _playlist_pts_loading:Boolean=false;
        private var _playlist_pts_loaded:Boolean=false;


        /** Create the loader. **/
        public function FragmentLoader(hls:HLS):void {
            _hls = hls;
            _autoLevelManager = new AutoLevelManager(hls);
            _hls.addEventListener(HLSEvent.MANIFEST_LOADED, _manifestLoadedHandler);
            _hls.addEventListener(HLSEvent.LEVEL_UPDATED,_levelUpdatedHandler);
            _urlstreamloader = new URLStream();
            _urlstreamloader.addEventListener(IOErrorEvent.IO_ERROR, _errorHandler);
            _urlstreamloader.addEventListener(Event.COMPLETE, _completeHandler);
        };


        /** Fragment load completed. **/
        private function _completeHandler(event:Event):void {
            //Log.txt("loading completed");
            _bIOError = false;
            // Calculate bandwidth
            _last_fetch_duration = (new Date().valueOf() - _started);
            _last_bandwidth = Math.round(_urlstreamloader.bytesAvailable * 8000 / _last_fetch_duration);
            // Collect stream loader data
            if( _urlstreamloader.bytesAvailable > 0 ) {
              var loaderData:ByteArray = new ByteArray();
              _urlstreamloader.readBytes(loaderData,0,0);
              var ts:TS = new TS(loaderData,_readHandler);
              _cancel_load = false;
            }
        };


		/** Kill any active load **/
		public function clearLoader():void {
			if(_urlstreamloader.connected) {
				_urlstreamloader.close();
			}
			_cancel_load = true;
      _bIOError = false;
		}


        /** Catch IO and security errors. **/
        private function _errorHandler(event:ErrorEvent):void {
            /* usually, errors happen in two situations :
            - bad networks  : in that case, the second or third reload of URL should fix the issue
            - live playlist : when we are trying to load an out of bound fragments : for example,
                              the playlist on webserver is from SN [51-61]
                              the one in memory is from SN [50-60], and we are trying to load SN50.
                              we will keep getting 404 error if the HLS server does not follow HLS spec,
                              which states that the server should keep SN50 during EXT-X-TARGETDURATION period
                              after it is removed from playlist
                              in the meantime, ManifestLoader will keep refreshing the playlist in the background ...
                              so if the error still happens after EXT-X-TARGETDURATION, it means that there is something wrong
                              we need to report it.
            */

            if(_bIOError == false) {
              _bIOError=true;
              _nIOErrorDate = new Date().valueOf();
            } else if((new Date().valueOf() - _nIOErrorDate) > 1000*_levels[_last_updated_level].averageduration ) {
              _hls.dispatchEvent(new HLSEvent(HLSEvent.ERROR, "I/O Error"));
            }
        };

        public function needReload():Boolean {
          return (_bIOError || _playlist_pts_loaded);
        };

        /** Get the quality level for the next fragment. **/
        public function getLevel():Number {
            return _level;
        };


        /** Get the current QOS metrics. **/
        public function getMetrics():Object {
            return { bandwidth:_last_bandwidth, level:_level, screenwidth:_width };
        };

       private function updateLevel(buffer:Number):Number {
          var level:Number;
          /* in case IO Error has been raised, stick to same level */
          if(_bIOError == true) {
            level = _level;
          /* in case fragment was loaded for PTS analysis, stick to same level */
          } else if(_playlist_pts_loaded == true) {
            _playlist_pts_loaded = false;
            level = _level;
            /* in case we are switching levels (waiting for playlist to reload), stick to same level */
          } else if(_switchlevel == true) {
            level = _level;
          } else if (_manual_level == -1 ) {
            level = _autoLevelManager.getnextlevel(_level,buffer,_last_segment_duration,_last_fetch_duration,_last_bandwidth);
          } else {
            level = _manual_level;
          }
          if(level != _level) {
            _level = level;
            _switchlevel = true;
            _hls.dispatchEvent(new HLSEvent(HLSEvent.QUALITY_SWITCH,_level));
          }
          return level;
       }

        public function loadfirstfragment(position:Number,callback:Function):Number {
        //Log.txt("loadfirstfragment(" + position + ")");
             if(_urlstreamloader.connected) {
                _urlstreamloader.close();
            }
            _switchlevel = true;
            // reset IO Error when loading new fragment
            _bIOError = false;
            updateLevel(0);

            // check if we received playlist for new level. if live playlist, ensure that new playlist has been refreshed
            if ((_levels[_level].fragments.length == 0) || (_hls.getType() == HLSTypes.LIVE && _last_updated_level != _level)) {
              // playlist not yet received
              //Log.txt("loadfirstfragment : playlist not received for level:"+level);
              return 1;
            }

            if (_hls.getType() == HLSTypes.LIVE) {
               var seek_position:Number;
               /* follow HLS spec :
                  If the EXT-X-ENDLIST tag is not present
                  and the client intends to play the media regularly (i.e. in playlist
                  order at the nominal playback rate), the client SHOULD NOT
                  choose a segment which starts less than three target durations from
                  the end of the Playlist file */
               var maxLivePosition:Number = Math.max(0,_levels[_level].duration -3*_levels[_level].averageduration);
               if (position == 0) {
                  // seek 3 fragments from end
                  seek_position = maxLivePosition;
               } else {
                  seek_position = Math.min(position,maxLivePosition);
               }
               Log.txt("loadfirstfragment : requested position:" + position + ",seek position:"+seek_position);
               position = seek_position;
            }
            var seqnum:Number= _levels[_level].getSeqNumBeforePosition(position);
            _callback = callback;
            _started = new Date().valueOf();
            var frag:Fragment = _levels[_level].getFragmentfromSeqNum(seqnum);
            _seqnum = seqnum;
            _hasDiscontinuity = true;
            _last_segment_continuity_counter = frag.continuity;
            _last_segment_program_date = frag.program_date;
            //Log.txt("Loading SN "+ _seqnum +  " of [" + (_levels[_level].start_seqnum) + "," + (_levels[_level].end_seqnum) + "],level "+ _level + ",URL=" + frag.url);
            Log.txt("Loading       "+ _seqnum +  " of [" + (_levels[_level].start_seqnum) + "," + (_levels[_level].end_seqnum) + "],level "+ _level);
            try {
               _urlstreamloader.load(new URLRequest(frag.url));
            } catch (error:Error) {
                _hls.dispatchEvent(new HLSEvent(HLSEvent.ERROR, error.message));
            }
            return 0;
        }

        /** Load a fragment **/
        public function loadnextfragment(buffer:Number,callback:Function):Number {
          //Log.txt("loadnextfragment(buffer):(" + buffer+ ")");

            if(_urlstreamloader.connected) {
                _urlstreamloader.close();
            }
            // reset IO Error when loading new fragment
            _bIOError = false;

            updateLevel(buffer);
            // check if we received playlist for new level. if live playlist, ensure that new playlist has been refreshed
            if ((_levels[_level].fragments.length == 0) || (_hls.getType() == HLSTypes.LIVE && _last_updated_level != _level)) {
              // playlist not yet received
              //Log.txt("loadnextfragment : playlist not received for level:"+level);
              return 1;
            }

            var new_seqnum:Number;
            var last_seqnum:Number = -1;
            var log_prefix:String;
            var frag:Fragment;

            if(_switchlevel == false) {
              last_seqnum = _seqnum;
            } else  { // level switch
              // trust program-time : if program-time defined in previous loaded fragment, try to find seqnum matching program-time in new level.
              if(_last_segment_program_date) {
                last_seqnum = _levels[_level].getSeqNumFromProgramDate(_last_segment_program_date);
                Log.txt("loadnextfragment : getSeqNumFromProgramDate(level,date,cc:"+_level+","+_last_segment_program_date+")="+last_seqnum);
              }
              if(last_seqnum == -1) {
                // if we are here, it means that no program date info is available in the playlist. try to get last seqnum position from PTS + continuity counter
                last_seqnum = _levels[_level].getSeqNumNearestPTS(_last_segment_start_pts,_last_segment_continuity_counter);
                //Log.txt("loadnextfragment : getSeqNumNearestPTS(level,pts,cc:"+_level+","+_last_segment_start_pts+","+_last_segment_continuity_counter+")="+last_seqnum);
                if (last_seqnum == -1) {
                // if we are here, it means that we have no PTS info for this continuity index, we need to do some PTS probing to find the right seqnum
                  /* we need to perform PTS analysis on fragments from same continuity range
                  get first fragment from playlist matching with criteria and load pts */
                  last_seqnum = _levels[_level].getFirstSeqNumfromContinuity(_last_segment_continuity_counter);
                  //Log.txt("loadnextfragment : getFirstSeqNumfromContinuity(level,cc:"+_level+","+_last_segment_continuity_counter+")="+last_seqnum);
                  if (last_seqnum == Number.NEGATIVE_INFINITY) {
                    // playlist not yet received
                    return 1;
                  }
                  /* when probing PTS, take previous sequence number as reference if possible */
                  new_seqnum=Math.min(_seqnum+1,_levels[_level].getLastSeqNumfromContinuity(_last_segment_continuity_counter));
                  new_seqnum = Math.max(new_seqnum,_levels[_level].getFirstSeqNumfromContinuity(_last_segment_continuity_counter));
                  _playlist_pts_loading = true;
                  log_prefix = "analyzing PTS ";
                }
              }
            }

            if(_playlist_pts_loading == false) {
              if(last_seqnum == _levels[_level].end_seqnum) {
              // if last segment was last fragment of VOD playlist, notify last fragment loaded event, and return
              if (_hls.getType() == HLSTypes.VOD)
                _hls.dispatchEvent(new HLSEvent(HLSEvent.LAST_VOD_FRAGMENT_LOADED));
              return 1;
              } else {
                // if previous segment is not the last one, increment it to get new seqnum
                new_seqnum = last_seqnum + 1;
                if(new_seqnum < _levels[_level].start_seqnum) {
                  // we are late ! report to caller
                  return -1;
                }
                frag = _levels[_level].getFragmentfromSeqNum(new_seqnum);
                // update program date
                _last_segment_program_date = frag.program_date;
                // update discontinuity counter
                _last_segment_continuity_counter = frag.continuity;
                // check whether there is a discontinuity between last segment and new segment
                _hasDiscontinuity = (_levels[_level].getFragmentfromSeqNum(last_seqnum).continuity != _last_segment_continuity_counter);
                log_prefix = "Loading       ";
              }
            }
            _seqnum = new_seqnum;
            _callback = callback;
            _started = new Date().valueOf();
            frag = _levels[_level].getFragmentfromSeqNum(_seqnum);
            //Log.txt("Loading SN "+ _seqnum +  " of [" + (_levels[_level].start_seqnum) + "," + (_levels[_level].end_seqnum) + "],level "+ _level + ",URL=" + frag.url);
            Log.txt(log_prefix + _seqnum +  " of [" + (_levels[_level].start_seqnum) + "," + (_levels[_level].end_seqnum) + "],level "+ _level);
            try {
               _urlstreamloader.load(new URLRequest(frag.url));
            } catch (error:Error) {
                _hls.dispatchEvent(new HLSEvent(HLSEvent.ERROR, error.message));
            }
            return 0;
        };

        /** Store the manifest data. **/
        private function _manifestLoadedHandler(event:HLSEvent):void {
            _levels = event.levels;
            _level = 0;
        };

        /** Store the manifest data. **/
        private function _levelUpdatedHandler(event:HLSEvent):void {
          _last_updated_level = event.level;
        };

    /** Handles the actual reading of the TS fragment **/
    private function _readHandler(audioTags:Vector.<Tag>,videoTags:Vector.<Tag>,adif:ByteArray,avcc:ByteArray):void {
       var min_pts:Number = Number.POSITIVE_INFINITY;
       var max_pts:Number = Number.NEGATIVE_INFINITY;
       // Tags used for PTS analysis
       var ptsTags:Vector.<Tag>;

       if (audioTags.length > 0) {
        ptsTags = audioTags;
      } else {
      // no audio, video only stream
        ptsTags = videoTags;
      }

      for(var k:Number=0; k < ptsTags.length; k++) {
         min_pts = Math.min(min_pts,ptsTags[k].pts);
         max_pts = Math.max(max_pts,ptsTags[k].pts);
      }

       /* in case we are probing PTS, just retrieve
       minimum PTS value to synchronize playlist PTS / sequence number.
       then return. this will force the Buffer Manager to reload the
       fragment at right offset */
       if(_playlist_pts_loading == true) {
         _levels[_level].updatePTS(_seqnum,min_pts,max_pts);
         Log.txt("analyzed  PTS " + _seqnum +  " of [" + (_levels[_level].start_seqnum) + "," + (_levels[_level].end_seqnum) + "],level "+ _level + " m/M PTS:" + min_pts +"/" + max_pts);
         _playlist_pts_loading = false;
         _playlist_pts_loaded = true;
         return;
       }

      var tags:Vector.<Tag> = new Vector.<Tag>();
      // Save codecprivate when not available.
      if(!_levels[_level].avcc && !_levels[_level].adif) {
        _levels[_level].avcc = avcc;
        _levels[_level].adif = adif;
      }
      // Push codecprivate tags only when switching.
      if(_switchlevel) {
        if (videoTags.length > 0) {
          // Audio only file don't have videoTags[0]
          var avccTag:Tag = new Tag(Tag.AVC_HEADER,videoTags[0].pts,videoTags[0].dts,true);
          avccTag.push(_levels[_level].avcc,0,_levels[_level].avcc.length);
          tags.push(avccTag);
        }
        if (audioTags.length > 0) {
          if(audioTags[0].type == Tag.AAC_RAW) {
            var adifTag:Tag = new Tag(Tag.AAC_HEADER,audioTags[0].pts,audioTags[0].dts,true);
            adifTag.push(_levels[_level].adif,0,2)
            tags.push(adifTag);
          }
        }
      }
      // Push regular tags into buffer.
      for(var i:Number=0; i < videoTags.length; i++) {
        tags.push(videoTags[i]);
      }
      for(var j:Number=0; j < audioTags.length; j++) {
        tags.push(audioTags[j]);
      }

      // change the media to null if the file is only audio.
      if(videoTags.length == 0) {
        _hls.dispatchEvent(new HLSEvent(HLSEvent.AUDIO_ONLY));
      }

      if (_cancel_load == true)
        return;

      try {
         _switchlevel = false;
         _last_segment_duration = max_pts-min_pts;
         _last_segment_start_pts = min_pts;

         Log.txt("Loaded        " + _seqnum +  " of [" + (_levels[_level].start_seqnum) + "," + (_levels[_level].end_seqnum) + "],level "+ _level + " m/M PTS:" + min_pts +"/" + max_pts);
         var start_offset:Number = _levels[_level].updatePTS(_seqnum,min_pts,max_pts);
         _hls.dispatchEvent(new HLSEvent(HLSEvent.PLAYLIST_DURATION_UPDATED,_levels[_level].duration));
         _callback(tags,min_pts,max_pts,_hasDiscontinuity,start_offset);
         _hls.dispatchEvent(new HLSEvent(HLSEvent.FRAGMENT_LOADED, getMetrics()));
      } catch (error:Error) {
        _hls.dispatchEvent(new HLSEvent(HLSEvent.ERROR, error.toString()));
      }
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