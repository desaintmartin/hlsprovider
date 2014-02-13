package org.mangui.HLS.streaming {


    import org.mangui.HLS.*;
    import org.mangui.HLS.muxing.*;
    import org.mangui.HLS.streaming.*;
    import org.mangui.HLS.utils.*;
    import flash.net.*;
    import flash.utils.*;


    /** Class that keeps the buffer filled. **/
    public class HLSNetStream extends NetStream {
        /** Reference to the framework controller. **/
        private var _hls:HLS;
        /** The buffer with video tags. **/
        private var _buffer:Vector.<Tag>;
        /** The fragment loader. **/
        private var _fragmentLoader:FragmentLoader;
        /** Store that a fragment load is in progress. **/
        private var _fragment_loading:Boolean;
        /** means that last fragment of a VOD playlist has been loaded */
        private var _reached_vod_end:Boolean;
        /** Interval for checking buffer and position. **/
        private var _interval:Number;
        /** requested start position **/
        private var _seek_position_requested:Number = 0;
         /** real start position , retrieved from first fragment **/
        private var _seek_position_real:Number;
        /** initial seek offset, difference between real seek position and first fragment start time **/
        private var _seek_offset:Number;
        /** Current play position (relative position from beginning of sliding window) **/
        private var _playback_current_position:Number;
        /** playlist sliding (non null for live playlist) **/
        private var _playlist_sliding_duration:Number;
        /** array of buffer start PTS (indexed by continuity) */
        private var _buffer_start_pts:Array;
        /** array of buffer last PTS (indexed by continuity) **/
        private var _buffer_last_pts:Array;
         /** previous buffer time. **/
        private var _last_buffer:Number;
        /** Current playback state. **/
        private var _state:String;
        /** The last tag that was appended to the buffer. **/
        private var _buffer_current_index:Number;
        /** max buffer length (default 60s)**/
        private var _buffer_max_len:Number=60;
        /** min buffer length (default 3s)**/
        private var _buffer_min_len:Number=3;
        /** playlist duration **/
        private var _playlist_duration:Number=0;
        /** Create the buffer. **/

        public function HLSNetStream(connection:NetConnection, hls:HLS, fragmentLoader:FragmentLoader):void {
            super(connection);
            super.inBufferSeek = true;
            _hls = hls;
            _fragmentLoader = fragmentLoader;
            _hls.addEventListener(HLSEvent.LAST_VOD_FRAGMENT_LOADED,_lastVODFragmentLoadedHandler);
            _hls.addEventListener(HLSEvent.PLAYLIST_DURATION_UPDATED,_playlistDurationUpdated);
            _setState(HLSStates.IDLE);
        };


        /** Check the bufferlength. **/
        private function _checkBuffer():void {
            var buffer:Number = 0;
            // Calculate the buffer and position.
            if(_buffer.length) {
               buffer = this.bufferLength;
               /** Absolute playback position (start position + play time) **/
               var playback_absolute_position:Number = (Math.round(super.time*100 + _seek_position_real*100)/100);
               /** Relative playback position (Absolute Position - playlist sliding, non null for Live Playlist) **/
               var playback_relative_position:Number = playback_absolute_position-_playlist_sliding_duration;

               // only send media time event if data has changed
               if(playback_relative_position != _playback_current_position || buffer !=_last_buffer) {
                  if (playback_relative_position <0) {
                     playback_relative_position = 0;
                  }
                  _playback_current_position = playback_relative_position;
                  _last_buffer = buffer;
                  _hls.dispatchEvent(new HLSEvent(HLSEvent.MEDIA_TIME,new HLSMediatime(_playback_current_position, _playlist_duration, buffer)));
               }
            }
            //Log.info("checkBuffer,loading,needReload,_reached_vod_end,buffer,maxBufferLength:"+ _fragment_loading + "/" + _fragmentLoader.needReload() + "/" + _reached_vod_end + "/" + buffer + "/" + _buffer_max_len);
            // Load new tags from fragment,
            if(_reached_vod_end == false &&                                         // if we have not reached the end of a VoD playlist AND
               ((_buffer_max_len == 0) || (buffer < _buffer_max_len)) &&            // if the buffer is not full AND
               ((!_fragment_loading) || _fragmentLoader.needReload() == true)) {    // ( if no fragment is being loaded currently OR if a fragment need to be reloaded
                var loadstatus:Number;
                if(super.time == 0 && _buffer.length == 0) {
                // just after seek, load first fragment
                  loadstatus = _fragmentLoader.loadfirstfragment(_seek_position_requested,_loaderCallback);
                } else {
                  loadstatus = _fragmentLoader.loadnextfragment(buffer,_loaderCallback);
                }
                if (loadstatus == 0) {
                  // good, new fragment being loaded
                  _fragment_loading = true;
                } else  if (loadstatus < 0) {
                  /* it means PTS requested is smaller than playlist start PTS.
                     it could happen on live playlist :
                     - if bandwidth available is lower than lowest quality needed bandwidth
                     - after long pause
                     seek to offset 0 to force a restart of the playback session  */
                  Log.warn("long pause on live stream or bad network quality");
                  seek(0);
                  return;
               } else if(loadstatus > 0) {
                  //seqnum not available in playlist
                  _fragment_loading = false;
               }
            }
            
            // Set playback state
            // check low buffer condition
            if (super.bufferLength < _buffer_min_len) {
              if(_reached_vod_end) {
                if(super.bufferLength ==0) {
                  // reach end of playlist + playback complete (as buffer is empty).
                  // stop timer, report event and switch to IDLE mode.
                  clearInterval(_interval);
                  _hls.dispatchEvent(new HLSEvent(HLSEvent.PLAYBACK_COMPLETE));
                  _setState(HLSStates.IDLE);
                }
              } else if(_state == HLSStates.PLAYING) {
                // low buffer condition and play state. switch to play buffering state
                _setState(HLSStates.PLAYING_BUFFERING);
              } else if(_state == HLSStates.PAUSED) {
                // low buffer condition and pause state. switch to paused buffering state
                _setState(HLSStates.PAUSED_BUFFERING);
              }
            } else { // no more in low buffer state
               if (_state == HLSStates.PLAYING_BUFFERING) {
                _setState(HLSStates.PLAYING);
               } else
                if (_state == HLSStates.PAUSED_BUFFERING) {
                _setState(HLSStates.PAUSED);
               }
            }
            
            // try to append data into NetStream
            //if we are already in PLAYING state, OR
            if((_state == HLSStates.PLAYING) ||
            //if we are in Buffering State, with enough buffer data (at least _buffer_min_len seconds) OR at the end of a VOD playlist
               ((_state == HLSStates.PLAYING_BUFFERING || _state == HLSStates.PAUSED_BUFFERING) && (buffer > _buffer_min_len || _reached_vod_end)))
             {
                //Log.debug("appending data into NetStream");
                while(_buffer_current_index < _buffer.length && // append data until we drain our _buffer[] array AND
                      super.bufferLength < 10) { // that NetStream Buffer contains at least 10 seconds
                    try {
                        if(_buffer[_buffer_current_index].type == Tag.DISCONTINUITY) {
                          super.appendBytesAction(NetStreamAppendBytesAction.RESET_BEGIN);
                          super.appendBytes(FLV.getHeader());
                      } else {
                          super.appendBytes(_buffer[_buffer_current_index].data);
                      }
                    } catch (error:Error) {
                        _errorHandler(new Error(_buffer[_buffer_current_index].type+": "+ error.message));
                    }
                    // Last tag done? Then append sequence end.
                    if (_reached_vod_end && _buffer_current_index == _buffer.length - 1) {
                        super.appendBytesAction(NetStreamAppendBytesAction.END_SEQUENCE);
                        super.appendBytes(new ByteArray());
                    }
                    _buffer_current_index++;
                }
            }
        };

        /** Dispatch an error to the controller. **/
        private function _errorHandler(error:Error):void {
            _hls.dispatchEvent(new HLSEvent(HLSEvent.ERROR,error.toString()));
        };


        /** Return the current playback state. **/
        public function get position():Number {
            return _playback_current_position;
        };


        /** Return the current playback state. **/
        public function get state():String {
            return _state;
        };


        /** Add a fragment to the buffer. **/
        private function _loaderCallback(tags:Vector.<Tag>,min_pts:Number,max_pts:Number, hasDiscontinuity:Boolean, start_offset:Number):void {
            // flush already injected Tags and restart index from 0
            _buffer = _buffer.slice(_buffer_current_index);
            _buffer_current_index = 0;

            var seek_pts:Number = min_pts + (_seek_position_requested-start_offset)*1000;
            if (_seek_position_real == Number.NEGATIVE_INFINITY) {
               _seek_position_real = _seek_position_requested < start_offset ? start_offset : _seek_position_requested;
               _seek_offset = _seek_position_real - start_offset;
            }
            /* check live playlist sliding here :
              _seek_position_real + getTotalBufferedDuration()  should be the start_position of the new fragment if the
              playlist is not sliding
              => live playlist sliding is the difference between these values */
              _playlist_sliding_duration = (_seek_position_real + getTotalBufferedDuration()) - start_offset - _seek_offset;

            /* if first fragment loaded, or if discontinuity, record discontinuity start PTS, and insert discontinuity TAG */
            if(hasDiscontinuity) {
              _buffer_start_pts.push(min_pts);
              _buffer_last_pts.push(max_pts);
              _buffer.push(new Tag(Tag.DISCONTINUITY,min_pts,min_pts,false));
            } else {
              // same continuity than previously, update its max PTS
              _buffer_last_pts[_buffer_last_pts.length-1] = max_pts;
            }

            tags.sort(_sortTagsbyDTS);
            
            /* accurate seeking : 
             * analyze fragment tags and look for last keyframe before seek position.
             * in schema below, we seek at t=17s, in a fragment starting at t=10s, ending at t=20s
             * this fragment contains 4 keyframes.
             *  timestamp of the last keyframe before seek position is @ t=16s
             * 
             *                             seek_pts
             *  K----------K------------K------*-----K---------|
             *  10s       13s          16s    17s    18s      20s
             *  
             *  
             */
            var i:Number = 0;
            var keyframe_pts:Number;            
            for(i = 0; i < tags.length ; i++) {
               // look for last keyframe with pts <= seek_pts
               if(tags[i].keyframe == true && tags[i].pts <= seek_pts)
                  keyframe_pts = tags[i].pts;
            }
            
            for(i = 0; i < tags.length ; i++) {
              if(tags[i].pts >= seek_pts) {
                _buffer.push(tags[i]);  
              } else {
                switch(tags[i].type) {
                  case Tag.AAC_HEADER:
                  case Tag.AVC_HEADER:
                    tags[i].pts = tags[i].dts = seek_pts;
                    _buffer.push(tags[i]);
                    break;
                  case Tag.AVC_NALU:
                /* only append video tags starting from last keyframe before seek position to avoid playback artifacts
                 *  rationale of this is that there can be multiple keyframes per segment. if we append all keyframes
                 *  in NetStream, all of them will be displayed in a row and this will introduce some playback artifacts
                 *  */                  
                    if(tags[i].pts >= keyframe_pts) {
                      tags[i].pts = tags[i].dts = seek_pts;
                      _buffer.push(tags[i]);
                    }
                    break;
                  default:
                    break;                        
                }
              }
            }
            Log.debug("Loaded offset/duration/sliding/discontinuity:"+start_offset.toFixed(2) + "/" +((max_pts-min_pts)/1000).toFixed(2) + "/" + _playlist_sliding_duration.toFixed(2)+ "/" + hasDiscontinuity );
            _fragment_loading = false;
        };


        /** return total buffered duration since seek() call
         needed to compute remaining buffer duration
        */
        private function getTotalBufferedDuration():Number {
          var bufSize:Number = 0;
          if(_buffer_start_pts != null) {
            /* duration of all the data already pushed into Buffer = sum of duration per continuity index */
            for(var i:Number=0; i < _buffer_start_pts.length ; i++) {
              bufSize+=_buffer_last_pts[i]-_buffer_start_pts[i];
            }
          }
          bufSize/=1000;
          return bufSize;
        }

        private function _lastVODFragmentLoadedHandler(event:HLSEvent):void {
          _reached_vod_end = true;
        }

        private function _playlistDurationUpdated(event:HLSEvent):void {
          _playlist_duration = event.duration;
        }

        /** Change playback state. **/
        private function _setState(state:String):void {
            if(state != _state) {
                Log.debug('[STATE] from ' + _state + ' to ' + state);
                _state = state;
                _hls.dispatchEvent(new HLSEvent(HLSEvent.STATE,_state));
            }
        };


        /** Sort the buffer by tag. **/
        private function _sortTagsbyDTS(x:Tag,y:Tag):Number {
            if(x.dts < y.dts) {
                return -1;
            } else if (x.dts > y.dts) {
                return 1;
            } else {
                if(x.type == Tag.AVC_HEADER || x.type == Tag.AAC_HEADER) {
                    return -1;
                } else if (y.type == Tag.AVC_HEADER || y.type == Tag.AAC_HEADER) {
                    return 1;
                } else {
                    if(x.type == Tag.AVC_NALU) {
                        return -1;
                    } else if (y.type == Tag.AVC_NALU) {
                        return 1;
                    } else {
                        return 0;
                    }
                }
            }
        };

    override public function play(...args):void 
    {
      var _playStart:Number;
      if (args.length >= 2)
      {
        _playStart = Number(args[1]);
      } else {
            _playStart = 0;
         }
      Log.info("HLSNetStream:play("+_playStart+")");
      seek(_playStart);
    }

    override public function play2(param : NetStreamPlayOptions):void 
    {
      Log.info("HLSNetStream:play2("+param.start+")");
      seek(param.start);
    }

    /** Pause playback. **/
    override public function pause():void {
        Log.info("HLSNetStream:pause");
        if(_state == HLSStates.PLAYING) {
            clearInterval(_interval);
            super.pause();
            _setState(HLSStates.PAUSED);
        } else if(_state == HLSStates.PLAYING_BUFFERING) {
            clearInterval(_interval);
            super.pause();
            _setState(HLSStates.PAUSED_BUFFERING);
        }
    };
    
    /** Resume playback. **/
    override public function resume():void {
         Log.info("HLSNetStream:resume");
        if(_state == HLSStates.PAUSED || _state == HLSStates.PAUSED_BUFFERING) {
            clearInterval(_interval);
            super.resume();
            _interval = setInterval(_checkBuffer,100);
            _setState(HLSStates.PLAYING);
        }
    };

    /** get Buffer Length  **/
    override public function get bufferLength():Number {
      /* remaining buffer is total duration buffered since beginning minus playback time */
      return getTotalBufferedDuration() - super.time;
    };

    /** get min Buffer Length  **/
    public function get minBufferLength():Number {
      return _buffer_min_len;
    };

    /** set min Buffer Length  **/
    public function set minBufferLength(new_len:Number):void {
      if (new_len < 0) {
        new_len = 0;
      }
      _buffer_min_len = new_len;
    };

    /** get max Buffer Length  **/
    public function get maxBufferLength():Number {
      return _buffer_max_len;
    };

    /** set max Buffer Length  **/
    public function set maxBufferLength(new_len:Number):void {
      _buffer_max_len = new_len;
    };


        /** Start playing data in the buffer. **/
        override public function seek(position:Number):void {
               Log.info("HLSNetStream:seek("+position+")");
               _buffer = new Vector.<Tag>();
               _fragmentLoader.clearLoader();
               _fragment_loading = false;
               _buffer_current_index = 0;
               _buffer_start_pts = new Array();
               _buffer_last_pts = new Array();
                _seek_position_requested = position;
                super.close();
                super.play(null);
                super.appendBytesAction(NetStreamAppendBytesAction.RESET_SEEK);
               _reached_vod_end = false;
               _seek_position_real = Number.NEGATIVE_INFINITY;
               _last_buffer = 0;
               
               if(_state == HLSStates.PAUSED || _state == HLSStates.PAUSED_BUFFERING) {
                 super.pause();
                 _setState(HLSStates.PAUSED_BUFFERING);
               } else {
                  _setState(HLSStates.PLAYING_BUFFERING);  
               }
               clearInterval(_interval);
               _interval = setInterval(_checkBuffer,100);
        };


        /** Stop playback. **/
        override public function close():void {
            Log.info("HLSNetStream:close");
            super.close();
            _fragment_loading = false;
            clearInterval(_interval);
            _setState(HLSStates.IDLE);
        };
    }
}