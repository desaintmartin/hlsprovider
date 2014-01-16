package org.mangui.HLS.streaming {


    import org.mangui.HLS.*;
    import org.mangui.HLS.muxing.*;
    import org.mangui.HLS.parsing.*;
    import org.mangui.HLS.streaming.*;
    import org.mangui.HLS.utils.*;

    import com.hurlant.util.Hex;

    import flash.events.*;
    import flash.net.*;
    import flash.utils.ByteArray;

    /** Class that fetches fragments. **/
    public class FragmentLoader {
        /** Reference to the HLS controller. **/
        private var _hls:HLS;
        /** reference to auto level manager */
        private var _autoLevelManager:AutoLevelManager;
        /** overall processing bandwidth of last loaded fragment (fragment size divided by processing duration) **/
        private var _last_bandwidth:int = 0;
        /** overall processing time of the last loaded fragment (loading+decrypting+parsing) **/
        private var _last_process_duration:Number = 0;
        /** duration of the last loaded fragment **/
        private var _last_segment_duration:Number = 0;
        /** last loaded fragment size **/
        private var _last_segment_size:Number = 0;
        /** duration of the last loaded fragment **/
        private var _last_segment_start_pts:Number = 0;
        /** continuity counter of the last fragment load. **/
        private var _last_segment_continuity_counter:Number = 0;
        /** program date of the last fragment load. **/
        private var _last_segment_program_date:Number = 0;
        /** decrypt URL of last segment **/
        private var _last_segment_decrypt_key_url:String;
        /** IV of  last segment **/
        private var _last_segment_decrypt_iv:ByteArray;
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
        private var _levels:Vector.<Level>;
        /** Util for loading the fragment. **/
        private var _fragstreamloader:URLStream;
        /** Util for loading the key. **/
        private var _keystreamloader:URLStream;
        /** key map **/
        private var _keymap:Object = new Object();
        /** fragment bytearray **/
        private var _fragByteArray:ByteArray;
        /** fragment bytearray write position **/
        private var _fragWritePosition:Number;        
        /** AES decryption instance **/
        private var _decryptAES:AES;
        /** Time the loading started. **/
        private var _frag_loading_start_time:Number;
        /** Time the decryption started. **/
        private var _frag_decrypt_start_time:Number;
        /** Time the parsing started. **/
        //private var _frag_parsing_start_time:Number;
        /** Did the stream switch quality levels. **/
        private var _switchlevel:Boolean;
        /** Did a discontinuity occurs in the stream **/
        private var _hasDiscontinuity:Boolean;
        /** Width of the stage. **/
        private var _width:Number = 480;
        /* flag handling load cancelled (if new seek occurs for example) */
        private var _cancel_load:Boolean;
        /* variable to deal with IO Error retry */
        private var _bIOError:Boolean;
        private var _nIOErrorDate:Number=0;

        /** boolean to track playlist PTS in loading */
        private var _pts_loading_in_progress:Boolean=false;
        /** boolean to indicate that PTS of new playlist has just been loaded */
        private var _pts_just_loaded:Boolean=false;
        /** boolean to indicate whether Buffer could request new fragment load **/
        private var _need_reload:Boolean=true;

        /** Create the loader. **/
        public function FragmentLoader(hls:HLS):void {
            _hls = hls;
            _autoLevelManager = new AutoLevelManager(hls);
            _hls.addEventListener(HLSEvent.MANIFEST_LOADED, _manifestLoadedHandler);
            _hls.addEventListener(HLSEvent.LEVEL_UPDATED,_levelUpdatedHandler);
            _fragstreamloader = new URLStream();
            _fragstreamloader.addEventListener(IOErrorEvent.IO_ERROR, _fragErrorHandler);
            _fragstreamloader.addEventListener(ProgressEvent.PROGRESS,_fragProgressHandler);
            _fragstreamloader.addEventListener(HTTPStatusEvent.HTTP_STATUS,_fragHTTPStatusHandler);
            _keystreamloader = new URLStream();
            _keystreamloader.addEventListener(IOErrorEvent.IO_ERROR, _keyErrorHandler);
            _keystreamloader.addEventListener(Event.COMPLETE, _keyCompleteHandler);
        };


        /** key load completed. **/
        private function _keyCompleteHandler(event:Event):void {
            Log.debug("key loading completed");
            // Collect key data
            if( _keystreamloader.bytesAvailable > 0 ) {
              var keyData:ByteArray = new ByteArray();
              _keystreamloader.readBytes(keyData,0,0);
              var frag:Fragment = _levels[_level].getFragmentfromSeqNum(_seqnum);
              _keymap[frag.decrypt_url] = keyData;
              // now load fragment
              try {
                 _fragstreamloader.load(new URLRequest(frag.url));
              } catch (error:Error) {
                  _hls.dispatchEvent(new HLSEvent(HLSEvent.ERROR, error.message));
              }
            }
        };

        private function _fraghandleIOError(message:String):void {
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
            Log.error("I/O Error while loading fragment:"+message);
            if(_bIOError == false) {
              _bIOError=true;
              _nIOErrorDate = new Date().valueOf();
            } else if((new Date().valueOf() - _nIOErrorDate) > 1000*_levels[_last_updated_level].averageduration ) {
              _hls.dispatchEvent(new HLSEvent(HLSEvent.ERROR, "I/O Error :" + message));
            }
            _need_reload = true;
        }

        private function _fragHTTPStatusHandler(event:HTTPStatusEvent):void {
          if(event.status >= 400) {
            _fraghandleIOError("HTTP Status:"+event.status.toString());
          }
        }

        private function _fragProgressHandler(event:ProgressEvent):void {
          if(_fragByteArray == null) {
            _fragByteArray = new ByteArray();
            _last_segment_size = event.bytesTotal;
            _fragWritePosition = 0;
            //decrypt data if needed
            if (_last_segment_decrypt_key_url != null) {
              _frag_decrypt_start_time = new Date().valueOf();
              _decryptAES = new AES(_keymap[_last_segment_decrypt_key_url],_last_segment_decrypt_iv);
              _decryptAES.decrypt(_fragByteArray,_fragDecryptCompleteHandler);
            } else {
              _decryptAES = null;
            }
          }
          // append new bytes into fragByteArray
          _fragByteArray.position = _fragWritePosition;
          _fragstreamloader.readBytes(_fragByteArray,_fragWritePosition,0);
          _fragWritePosition=_fragByteArray.length;
          Log.debug2("bytesLoaded/bytesTotal:"+event.bytesLoaded + "/"+ event.bytesTotal);
          if(_decryptAES != null) {	  
            _decryptAES.notifyappend();
          }
          if(event.bytesLoaded == event.bytesTotal) {
            Log.debug("loading completed");
            _cancel_load = false;
            if(_decryptAES != null) {
              _decryptAES.notifycomplete();
            } else {
              _fragDemux(_fragByteArray);
            }
          }
        }

    private function _fragDecryptCompleteHandler(data:ByteArray):void {
      var decrypt_duration:Number = (new Date().valueOf() - _frag_decrypt_start_time);
      _decryptAES = null;
      Log.debug("Decrypted     duration/length/speed:"+decrypt_duration+ "/" + data.length + "/" + ((8000*data.length/decrypt_duration)/1024).toFixed(0) + " kb/s");
      _fragDemux(data);
    }

      private function _fragDemux(data : ByteArray) : void {
         // _frag_parsing_start_time = new Date().valueOf();
         /* probe file type */
         data.position = 0;
         Log.debug("probe fragment type");
         if (TS.probe(data) == true) {
            Log.debug("MPEG2-TS found");
            new TS(data, _fragReadHandler);
         } else if (AAC.probe(data) == true) {
            Log.debug("AAC ES found");
            new AAC(data,_fragReadHandler);
         } else {
            Log.error("unknown fragment type");
            if(Log.LOG_DEBUG2_ENABLED) {
              data.position = 0;
              var ba:ByteArray = new ByteArray();
              data.readBytes(ba,0,512);
              Log.debug2("frag dump(512 bytes)");
              Log.debug2(Hex.fromArray(ba));
            }
            // invalid fragment
            _fraghandleIOError("invalid content received");
            return;
         }
      }

		/** Kill any active load **/
		public function clearLoader():void {
			if(_fragstreamloader.connected) {
				_fragstreamloader.close();
			}
			if(_decryptAES) {
			 _decryptAES.cancel(); 
			 _decryptAES = null;
			}
			_fragByteArray = null;
			_cancel_load = true;
      _bIOError = false;
		}


        /** Catch IO and security errors. **/
        private function _keyErrorHandler(event:ErrorEvent):void {
          _hls.dispatchEvent(new HLSEvent(HLSEvent.ERROR, "cannot load key"));
        };

        /** Catch IO and security errors. **/
        private function _fragErrorHandler(event:ErrorEvent):void {
          _fraghandleIOError(event.text);
        };

        public function needReload():Boolean {
          return _need_reload;
        };

        /** Get the quality level for the next fragment. **/
        public function getLevel():Number {
            return _level;
        };


        /** Get the current QOS metrics. **/
        public function getMetrics():HLSMetrics {
            return new HLSMetrics(_level, _last_bandwidth, _width);
        };

       private function updateLevel(buffer:Number):Number {
          var level:Number;
          /* in case IO Error has been raised, stick to same level */
          if(_bIOError == true) {
            level = _level;
          /* in case fragment was loaded for PTS analysis, stick to same level */
          } else if(_pts_just_loaded == true) {
            _pts_just_loaded = false;
            level = _level;
            /* in case we are switching levels (waiting for playlist to reload), stick to same level */
          } else if(_switchlevel == true) {
            level = _level;
          } else if (_manual_level == -1 ) {
            level = _autoLevelManager.getnextlevel(_level,buffer,_last_segment_duration,_last_process_duration,_last_bandwidth);
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
            Log.debug("loadfirstfragment(" + position + ")");
             if(_fragstreamloader.connected) {
                _fragstreamloader.close();
            }
            // reset IO Error when loading first fragment
            _bIOError = false;
            _need_reload = false;
            updateLevel(0);
            _switchlevel = true;

            // check if we received playlist for new level. if live playlist, ensure that new playlist has been refreshed
            if ((_levels[_level].fragments.length == 0) || (_hls.getType() == HLSTypes.LIVE && _last_updated_level != _level)) {
              // playlist not yet received
              Log.debug("loadfirstfragment : playlist not received for level:"+_level);
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
               Log.debug("loadfirstfragment : requested position:" + position + ",seek position:"+seek_position);
               position = seek_position;
            }
            var seqnum:Number= _levels[_level].getSeqNumBeforePosition(position);
            _callback = callback;
            _frag_loading_start_time = new Date().valueOf();
            var frag:Fragment = _levels[_level].getFragmentfromSeqNum(seqnum);
            _seqnum = seqnum;
            _hasDiscontinuity = true;
            _last_segment_continuity_counter = frag.continuity;
            _last_segment_program_date = frag.program_date;
            Log.debug("Loading       "+ _seqnum +  " of [" + (_levels[_level].start_seqnum) + "," + (_levels[_level].end_seqnum) + "],level "+ _level);
            
            
            _last_segment_decrypt_key_url = frag.decrypt_url;
            if(_last_segment_decrypt_key_url != null && (_keymap[_last_segment_decrypt_key_url] == undefined)) {
              _last_segment_decrypt_iv = frag.decrypt_iv;
              // load key
              _keystreamloader.load(new URLRequest(_last_segment_decrypt_key_url));
            } else {
              try {
                 _fragByteArray = null;
                 _fragstreamloader.load(new URLRequest(frag.url));
              } catch (error:Error) {
                  _hls.dispatchEvent(new HLSEvent(HLSEvent.ERROR, error.message));
              }
            }
            return 0;
        }

        /** Load a fragment **/
        public function loadnextfragment(buffer:Number,callback:Function):Number {
          Log.debug("loadnextfragment(buffer):(" + buffer+ ")");

            if(_fragstreamloader.connected) {
                _fragstreamloader.close();
            }
            // in case IO Error reload same fragment
            if(_bIOError) {
              _seqnum--;
            }
            _need_reload = false;

            updateLevel(buffer);
            // check if we received playlist for new level. if live playlist, ensure that new playlist has been refreshed
            if ((_levels[_level].fragments.length == 0) || (_hls.getType() == HLSTypes.LIVE && _last_updated_level != _level)) {
              // playlist not yet received
              Log.debug("loadnextfragment : playlist not received for level:"+_level);
              return 1;
            }

            var new_seqnum:Number;
            var last_seqnum:Number = -1;
            var log_prefix:String;
            var frag:Fragment;

            if(_switchlevel == false || _last_segment_continuity_counter == -1) {
              last_seqnum = _seqnum;
            } else  { // level switch
              // trust program-time : if program-time defined in previous loaded fragment, try to find seqnum matching program-time in new level.
              if(_last_segment_program_date) {
                last_seqnum = _levels[_level].getSeqNumFromProgramDate(_last_segment_program_date);
                Log.debug("loadnextfragment : getSeqNumFromProgramDate(level,date,cc:"+_level+","+_last_segment_program_date+")="+last_seqnum);
              }
              if(last_seqnum == -1) {
                // if we are here, it means that no program date info is available in the playlist. try to get last seqnum position from PTS + continuity counter
                last_seqnum = _levels[_level].getSeqNumNearestPTS(_last_segment_start_pts,_last_segment_continuity_counter);
                Log.debug("loadnextfragment : getSeqNumNearestPTS(level,pts,cc:"+_level+","+_last_segment_start_pts+","+_last_segment_continuity_counter+")="+last_seqnum);
                if (last_seqnum == -1) {
                // if we are here, it means that we have no PTS info for this continuity index, we need to do some PTS probing to find the right seqnum
                  /* we need to perform PTS analysis on fragments from same continuity range
                  get first fragment from playlist matching with criteria and load pts */
                  last_seqnum = _levels[_level].getFirstSeqNumfromContinuity(_last_segment_continuity_counter);
                  Log.debug("loadnextfragment : getFirstSeqNumfromContinuity(level,cc:"+_level+","+_last_segment_continuity_counter+")="+last_seqnum);
                  if (last_seqnum == Number.NEGATIVE_INFINITY) {
                    // playlist not yet received
                    return 1;
                  }
                  /* when probing PTS, take previous sequence number as reference if possible */
                  new_seqnum=Math.min(_seqnum+1,_levels[_level].getLastSeqNumfromContinuity(_last_segment_continuity_counter));
                  new_seqnum = Math.max(new_seqnum,_levels[_level].getFirstSeqNumfromContinuity(_last_segment_continuity_counter));
                    _pts_loading_in_progress = true;
                    log_prefix = "analyzing PTS ";
                }
              }
            }

            if(_pts_loading_in_progress == false) {
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
                if (frag == null) {
                  Log.warn("error trying to load "  + new_seqnum +  " of [" + (_levels[_level].start_seqnum) + "," + (_levels[_level].end_seqnum) + "],level "+ _level);
                  return 1;
                }
                // update program date
                _last_segment_program_date = frag.program_date;
                // check whether there is a discontinuity between last segment and new segment
                _hasDiscontinuity = (frag.continuity != _last_segment_continuity_counter);
					 // update discontinuity counter
                _last_segment_continuity_counter = frag.continuity;
                log_prefix = "Loading       ";
              }
            }
            _seqnum = new_seqnum;
            _callback = callback;
            _frag_loading_start_time = new Date().valueOf();
            frag = _levels[_level].getFragmentfromSeqNum(_seqnum);
            Log.debug(log_prefix + _seqnum +  " of [" + (_levels[_level].start_seqnum) + "," + (_levels[_level].end_seqnum) + "],level "+ _level);
            
            _last_segment_decrypt_key_url = frag.decrypt_url;
            if(_last_segment_decrypt_key_url != null && (_keymap[_last_segment_decrypt_key_url] == undefined)) {
              _last_segment_decrypt_iv = frag.decrypt_iv;
              // load key
              _keystreamloader.load(new URLRequest(frag.decrypt_url));
            } else {
              try {
                 _fragByteArray = null;
                 _fragstreamloader.load(new URLRequest(frag.url));
              } catch (error:Error) {
                  _hls.dispatchEvent(new HLSEvent(HLSEvent.ERROR, error.message));
              }
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
    private function _fragReadHandler(audioTags:Vector.<Tag>,videoTags:Vector.<Tag>,adif:ByteArray,avcc:ByteArray):void {
       var min_pts:Number = Number.POSITIVE_INFINITY;
       var max_pts:Number = Number.NEGATIVE_INFINITY;
       // Tags used for PTS analysis
       var ptsTags:Vector.<Tag>;

      // reset IO error, as if we reach this point, it means fragment has been successfully retrieved and demuxed
      _bIOError = false;

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

      /* in case we are probing PTS, retrieve PTS info and synchronize playlist PTS / sequence number */
      if(_pts_loading_in_progress == true) {
        _levels[_level].updatePTS(_seqnum,min_pts,max_pts);
        Log.debug("analyzed  PTS " + _seqnum +  " of [" + (_levels[_level].start_seqnum) + "," + (_levels[_level].end_seqnum) + "],level "+ _level + " m/M PTS:" + min_pts +"/" + max_pts);
        /* check if fragment loaded for PTS analysis is the next one
            if this is the expected one, then continue and notify Buffer Manager with parsed content
            if not, then exit from here, this will force Buffer Manager to call loadnextfragment() and load the right seqnum
         */
        var next_seqnum:Number = _levels[_level].getSeqNumNearestPTS(_last_segment_start_pts,_last_segment_continuity_counter)+1;
        //Log.info("seq/next:"+ _seqnum+"/"+ next_seqnum);
        if (next_seqnum != _seqnum) {
          _pts_loading_in_progress = false;
          _pts_just_loaded = true;
          // tell that new fragment could be loaded
          _need_reload = true;
          return;
        }
      }

      var tags:Vector.<Tag> = new Vector.<Tag>();
      // Push codecprivate tags only when switching.
      if(_switchlevel) {
        if (videoTags.length > 0) {
          var avccTag:Tag = new Tag(Tag.AVC_HEADER,videoTags[0].pts,videoTags[0].dts,true);
          avccTag.push(avcc,0,avcc.length);
          tags.push(avccTag);
        }
        if (audioTags.length > 0) {
          if(audioTags[0].type == Tag.AAC_RAW) {
            var adifTag:Tag = new Tag(Tag.AAC_HEADER,audioTags[0].pts,audioTags[0].dts,true);
            adifTag.push(adif,0,2);
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

      // Calculate bandwidth
      _last_process_duration = (new Date().valueOf() - _frag_loading_start_time);
      _last_bandwidth = Math.round(_last_segment_size * 8000 / _last_process_duration);

      try {
         _switchlevel = false;
         _last_segment_duration = max_pts-min_pts;
         _last_segment_start_pts = min_pts;

         Log.debug("Loaded        " + _seqnum +  " of [" + (_levels[_level].start_seqnum) + "," + (_levels[_level].end_seqnum) + "],level "+ _level + " m/M PTS:" + min_pts +"/" + max_pts);
         var start_offset:Number = _levels[_level].updatePTS(_seqnum,min_pts,max_pts);
         _hls.dispatchEvent(new HLSEvent(HLSEvent.PLAYLIST_DURATION_UPDATED,_levels[_level].duration));
         _callback(tags,min_pts,max_pts,_hasDiscontinuity,start_offset);
         _pts_loading_in_progress = false;
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