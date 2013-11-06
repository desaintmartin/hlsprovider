package org.mangui.HLS.streaming {


    import org.mangui.HLS.*;
    import org.mangui.HLS.muxing.*;
    import org.mangui.HLS.streaming.*;
    import org.mangui.HLS.parsing.*;
    import org.mangui.HLS.utils.*;

    import flash.media.*;
    import flash.net.*;
    import flash.utils.*;


    /** Class that keeps the buffer filled. **/
    public class Buffer {
        /** Reference to the framework controller. **/
        private var _hls:HLS;
        /** The buffer with video tags. **/
        private var _buffer:Vector.<Tag>;
        /** The fragment loader. **/
        private var _loader:FragmentLoader;
        /** Store that a fragment load is in progress. **/
        private var _fragment_loading:Boolean;
        /** means that last fragment of a VOD playlist has been loaded */
        private var _reached_vod_end:Boolean;
        /** Interval for checking buffer and position. **/
        private var _interval:Number;
        /** requested start position **/
        public var PlaybackStartPosition:Number = 0;
         /** real start position , retrieved from first fragment **/
        private var _playback_start_position_real:Number;
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
        /** Netstream instance used for playing the stream. **/
        private var _stream:NetStream;
        /** The last tag that was appended to the buffer. **/
        private var _buffer_current_index:Number;
        /** soundtransform object. **/
        private var _transform:SoundTransform;

        private var _was_playing:Boolean = false;
        /** Create the buffer. **/
        public function Buffer(hls:HLS, loader:FragmentLoader):void {
            _hls = hls;
            _loader = loader;
            _hls.addEventListener(HLSEvent.LAST_VOD_FRAGMENT_LOADED,_lastVODFragmentLoadedHandler);
            _setState(HLSStates.IDLE);
        };


        /** Check the bufferlength. **/
        private function _checkBuffer():void {
          //Log.txt("checkBuffer");
            var buffer:Number = 0;
            // Calculate the buffer and position.
            if(_buffer.length) {
              /* remaining buffer is total duration buffered since beginning minus playback time */
               buffer = getTotalBufferedDuration()-_stream.time;
               /** Absolute playback position (start position + play time) **/
               var playback_absolute_position:Number = (Math.round(_stream.time*100 + _playback_start_position_real*100)/100);
               /** Relative playback position (Absolute Position - playlist sliding, non null for Live Playlist) **/
               var playback_relative_position:Number = playback_absolute_position-_playlist_sliding_duration;
               
               // only send media time event if data has changed
               if(playback_relative_position != _playback_current_position || buffer !=_last_buffer) {
                  if (playback_relative_position <0) {
                     playback_relative_position = 0;
                  }
                  _playback_current_position = playback_relative_position;
                  _last_buffer = buffer;
                  _hls.dispatchEvent(new HLSEvent(HLSEvent.MEDIA_TIME,{ position:_playback_current_position, buffer:buffer, duration:_loader.getPlayListDuration()}));
               }
            }
            //Log.txt("checkBuffer,loading,needReload,_reached_vod_end,buffer,loader.getBufferLength():"+ _fragment_loading + "/" + _loader.needReload() + "/" + _reached_vod_end + "/" + buffer + "/" + _loader.getBufferLength());
            // Load new tags from fragment.
            if(_reached_vod_end == false && buffer < _loader.getBufferLength() && ((!_fragment_loading) || _loader.needReload() == true)) {
                var loadstatus:Number;
                if(_stream.time == 0 && _buffer.length == 0) {
                // just after seek, load first fragment
                  loadstatus = _loader.loadfirstfragment(PlaybackStartPosition,_loaderCallback);
                } else {
                  loadstatus = _loader.loadnextfragment(buffer,_loaderCallback);
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
                  Log.txt("long pause on live stream or bad network quality");
                  seek(0);
                  return;
               } else if(loadstatus > 0) {
                  //seqnum not available in playlist
                  _fragment_loading = false;
               }
            }
            if((_state == HLSStates.PLAYING) ||
               (_state == HLSStates.BUFFERING && (buffer > _loader.getSegmentAverageDuration() || _reached_vod_end)))
             {
                //Log.txt("appending data into NetStream");
                while(_buffer_current_index < _buffer.length && _stream.bufferLength < 2*_loader.getSegmentAverageDuration()) {
                    try {
                        if(_buffer[_buffer_current_index].type == Tag.DISCONTINUITY) {
                          _stream.appendBytesAction(NetStreamAppendBytesAction.RESET_BEGIN);
                          _stream.appendBytes(FLV.getHeader());
                      } else {
                          _stream.appendBytes(_buffer[_buffer_current_index].data);
                      }
                    } catch (error:Error) {
                        _errorHandler(new Error(_buffer[_buffer_current_index].type+": "+ error.message));
                    }
                    // Last tag done? Then append sequence end.
                    if (_reached_vod_end ==true && _buffer_current_index == _buffer.length - 1) {
                        _stream.appendBytesAction(NetStreamAppendBytesAction.END_SEQUENCE);
                        _stream.appendBytes(new ByteArray());
                    }
                    _buffer_current_index++;
                }
            }
            // Set playback state and complete.
            if(_stream.bufferLength < 3) {
                if(_stream.bufferLength == 0 && _reached_vod_end ==true) {
                    clearInterval(_interval);
                    _hls.dispatchEvent(new HLSEvent(HLSEvent.PLAYBACK_COMPLETE));
                    _setState(HLSStates.IDLE);
                } else if(_state == HLSStates.PLAYING) {
                    !_reached_vod_end && _setState(HLSStates.BUFFERING);
                }
            } else if (_state == HLSStates.BUFFERING) {

                if(_was_playing)
                _setState(HLSStates.PLAYING);
                else
                    pause();
            }
        };

        /** Dispatch an error to the controller. **/
        private function _errorHandler(error:Error):void {
            _hls.dispatchEvent(new HLSEvent(HLSEvent.ERROR,error.toString()));
        };


        /** Return the current playback state. **/
        public function getPosition():Number {
            return _playback_current_position;
        };


        /** Return the current playback state. **/
        public function getState():String {
            return _state;
        };


        /** Add a fragment to the buffer. **/
        private function _loaderCallback(tags:Vector.<Tag>,min_pts:Number,max_pts:Number, hasDiscontinuity:Boolean, start_offset:Number):void {
            // flush already injected Tags and restart index from 0
            _buffer = _buffer.slice(_buffer_current_index);
            _buffer_current_index = 0;
            
            var seek_pts:Number = min_pts + (PlaybackStartPosition-start_offset)*1000;            
            if (_playback_start_position_real == Number.NEGATIVE_INFINITY) {
               _playback_start_position_real = PlaybackStartPosition < start_offset ? start_offset : PlaybackStartPosition;
            }
            /* check live playlist sliding here :
              _playback_start_position_real + getTotalBufferedDuration()  should be the start_position of the new fragment if the
              playlist is not sliding
              => live playlist sliding is the difference between these values */
            _playlist_sliding_duration = (_playback_start_position_real + getTotalBufferedDuration()) - start_offset;

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
            for each (var t:Tag in tags) {
                _filterTag(t,seek_pts) && _buffer.push(t);
            }
            Log.txt("_loaderCallback:start_offset/hasDiscontinuity/_playlist_sliding_duration:"+start_offset + "/" + hasDiscontinuity + "/" + _playlist_sliding_duration);
            _fragment_loading = false;
        };


        /** return total buffered duration since seek() call 
         needed to compute remaining buffer duration
        */
        private function getTotalBufferedDuration():Number {
          var bufSize:Number = 0;
          /* duration of all the data already pushed into Buffer = sum of duration per continuity index */
          for(var i:Number=0; i < _buffer_start_pts.length ; i++) {
            bufSize+=_buffer_last_pts[i]-_buffer_start_pts[i];
          }
          bufSize/=1000;
          return bufSize;
        }
      
        private function _lastVODFragmentLoadedHandler(event:HLSEvent):void {
          _reached_vod_end = true;
        }

        /** Pause playback. **/
        public function pause():void {
            if(_state == HLSStates.PLAYING || _state == HLSStates.BUFFERING) {
                clearInterval(_interval);
                _stream.pause();
                _setState(HLSStates.PAUSED);
            }
        };

        /** Resume playback. **/
        public function resume():void {
            if(_state == HLSStates.PAUSED) {
                clearInterval(_interval);
                _stream.resume();
                _interval = setInterval(_checkBuffer,100);
                _setState(HLSStates.PLAYING);
            }
        };

        /** Change playback state. **/
        private function _setState(state:String):void {
            if(state != _state) {
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

        /**
         *
         * Filter tag by type and pts for accurate seeking.
         *
         * @param tag
         * @param pts Destination pts
         * @return
         */
        private function _filterTag(tag:Tag,pts:Number = 0):Boolean{
            if(tag.type == Tag.AAC_HEADER || tag.type == Tag.AVC_HEADER || tag.type == Tag.AVC_NALU){
              if(tag.pts < pts)
               tag.pts = tag.dts = pts;
              return true;
            }
            return tag.pts >= pts;
        }

        /** Start playing data in the buffer. **/
        public function seek(position:Number):void {
               Log.txt("seek("+position+")");
               _buffer = new Vector.<Tag>();
               _loader.clearLoader();
               _fragment_loading = false;
               _buffer_current_index = 0;
               _buffer_start_pts = new Array();
               _buffer_last_pts = new Array();
                PlaybackStartPosition = position;
                _stream.close();
                _stream.play(null);
               _stream.appendBytesAction(NetStreamAppendBytesAction.RESET_SEEK);
               _reached_vod_end = false;
               _playback_start_position_real = Number.NEGATIVE_INFINITY;
               _last_buffer = 0;
               _was_playing = (_state == HLSStates.PLAYING) || (_state == HLSStates.IDLE);
               _setState(HLSStates.BUFFERING);
               clearInterval(_interval);
               _interval = setInterval(_checkBuffer,100);
        };


        /** Stop playback. **/
        public function stop():void {
            if(_stream) {
                _stream.pause();
            }
            _fragment_loading = false;
            clearInterval(_interval);
            _setState(HLSStates.IDLE);
        };


        /** Change the volume (set in the NetStream). **/
        public function volume(percent:Number):void {
            _transform.volume = percent/100;
            if(_stream) {
                _stream.soundTransform = _transform;
            }
        };
        
        public function set NetStream(netstream:NetStream):void {
          _stream = netstream; 
          _stream.inBufferSeek = true;
          _transform = new SoundTransform();
          _transform.volume = 0.9;
          _stream.soundTransform = _transform;
        }
    }
}