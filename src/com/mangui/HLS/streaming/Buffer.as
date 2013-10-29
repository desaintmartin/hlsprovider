package com.mangui.HLS.streaming {


    import com.mangui.HLS.*;
    import com.mangui.HLS.muxing.*;
    import com.mangui.HLS.streaming.*;
    import com.mangui.HLS.parsing.*;
    import com.mangui.HLS.utils.*;

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
        private var _loading:Boolean;
        /** means that last fragment of a VOD playlist has been loaded */
        private var _reached_vod_end:Boolean;
        /** Interval for checking buffer and position. **/
        private var _interval:Number;
        /** Next loading fragment sequence number. **/
        /** The start position of the stream. **/
        public var PlaybackStartPosition:Number = 0;
         /** start playback position in second, retrieved from first fragment **/
        private var _playback_start_position:Number;
        /** playback start PTS. **/
        private var _playback_start_pts:Number;
        /** playlist start PTS when playback started. **/
        private var _playlist_start_pts:Number;
        /** Current play position (relative position from beginning of sliding window) **/
        private var _playback_current_position:Number;
        /** buffer last PTS. **/
        private var _buffer_last_pts:Number;
         /** next buffer time. **/
        private var _buffer_next_time:Number;
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
        public function Buffer(hls:HLS, loader:FragmentLoader, stream:NetStream):void {
            _hls = hls;
            _loader = loader;
            _stream = stream;
            _stream.inBufferSeek = true;
            _hls.addEventListener(HLSEvent.MANIFEST,_manifestHandler);
            _transform = new SoundTransform();
            _transform.volume = 0.9;
            _setState(HLSStates.IDLE);
        };


        /** Check the bufferlength. **/
        private function _checkBuffer():void {
          //Log.txt("checkBuffer");
            var buffer:Number = 0;
            // Calculate the buffer and position.
            if(_buffer.length) {
               buffer = (_buffer_last_pts - _playback_start_pts)/1000 - _stream.time;
               /** Current play time (time since beginning of playback) **/
               var playback_current_time:Number = (Math.round(_stream.time*100 + _playback_start_position*100)/100);
               var current_playlist_start_pts:Number = _loader.getPlayListStartPTS();
               var play_position:Number;
               if(current_playlist_start_pts ==Number.NEGATIVE_INFINITY) {
                  play_position = 0;
               } else {
                  play_position = playback_current_time -(current_playlist_start_pts-_playlist_start_pts)/1000;
                }
               if(play_position != _playback_current_position || buffer !=_last_buffer) {
                  if (play_position <0) {
                     play_position = 0;
                  }
                  _playback_current_position = play_position;
                  _last_buffer = buffer;
                  _hls.dispatchEvent(new HLSEvent(HLSEvent.MEDIA_TIME,{ position:_playback_current_position, buffer:buffer, duration:_loader.getPlayListDuration()}));
               }
            }

            // Load new tags from fragment.
            if(_reached_vod_end == false && buffer < _loader.getBufferLength() && ((!_loading) || _loader.needReload() == true)) {
               var loadstatus:Number = _loader.loadfragment(_buffer_next_time,_buffer_last_pts,buffer,_loaderCallback,(_buffer.length == 0));
               if (loadstatus == 0) {
                  // good, new fragment being loaded
                  _loading = true;
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
                  _loading = false;
                  //seqnum not available in playlist
                  if (_hls.getType() == HLSTypes.VOD) {
                     // if VOD playlist, it means we reached the end, on live playlist do nothing and wait ...
                     _reached_vod_end = true;
                  }
               }
            }
            if((_state == HLSStates.PLAYING) ||
               (_state == HLSStates.BUFFERING && (buffer > _loader.getSegmentAverageDuration() || _reached_vod_end)))
             {
                //Log.txt("appending data into NetStream");
                while(_buffer_current_index < _buffer.length && _stream.bufferLength < 2*_loader.getSegmentAverageDuration()) {
                    try {
                        _stream.appendBytes(_buffer[_buffer_current_index].data);
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
                    _hls.dispatchEvent(new HLSEvent(HLSEvent.COMPLETE));
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
            if (_playback_start_pts == Number.NEGATIVE_INFINITY) {
               _playback_start_pts = seek_pts < min_pts ? min_pts : seek_pts;
               _playlist_start_pts = _loader.getPlayListStartPTS();
               _playback_start_position = (_playback_start_pts-_playlist_start_pts)/1000;
            }
            _buffer_last_pts = max_pts;
            tags.sort(_sortTagsbyDTS);
            for each (var t:Tag in tags) {
                _filterTag(t,seek_pts) && _buffer.push(t);
            }
            _buffer_next_time=_playback_start_position+(_buffer_last_pts-_playback_start_pts)/1000;
            Log.txt("_loaderCallback:start_offset/_buffer_next_time:"+start_offset + "/" + _buffer_next_time);
            _loading = false;
        };

        /** Start streaming on manifest load. **/
        private function _manifestHandler(event:HLSEvent):void {
            if(_state == HLSStates.IDLE) {
                _stream.close();
                _stream.play(null);
                _stream.soundTransform = _transform;
                _stream.appendBytesAction(NetStreamAppendBytesAction.RESET_BEGIN);
                _stream.appendBytes(FLV.getHeader());
                seek(PlaybackStartPosition);
            }
        };


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
               _buffer = new Vector.<Tag>();
               _loader.clearLoader();
               _loading = false;
               _buffer_current_index = 0;
                PlaybackStartPosition = position;
               _stream.seek(0);
               _stream.appendBytesAction(NetStreamAppendBytesAction.RESET_SEEK);
               _reached_vod_end = false;
               _playback_start_pts = Number.NEGATIVE_INFINITY;
               _buffer_next_time = position;
               _buffer_last_pts = 0;
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
            _loading = false;
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


    }


}