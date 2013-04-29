package com.longtailvideo.HLS.streaming {


    import com.longtailvideo.HLS.*;
    import com.longtailvideo.HLS.muxing.*;
    import com.longtailvideo.HLS.streaming.*;
    import com.longtailvideo.HLS.utils.*;
    
    import flash.media.*;
    import flash.net.*;
    import flash.utils.*;


    /** Class that keeps the buffer filled. **/
    public class Buffer {


        /** Default bufferlength in seconds. **/
        private static const LENGTH:Number = 30;

        /** Default bufferlength in seconds. **/
        private var restart_length:Number = 8;

        /** Reference to the framework controller. **/
        private var _adaptive:Adaptive;
        /** The buffer with video tags. **/
        private var _buffer:Vector.<Tag>;
        /** NetConnection legacy stuff. **/
        private var _connection:NetConnection;
        /** The current quality level. **/
        private var _level:Number = 0;
        /** Reference to the manifest levels. **/
        private var _levels:Array;
        /** The fragment loader. **/
        private var _loader:Loader;
        /** Store that a fragment load is in progress. **/
        private var _loading:Boolean;
        /** Interval for checking buffer and position. **/
        private var _interval:Number;
        /** Next loading fragment. **/
        private var _next:Number;
        /** Current position. **/
        private var _position:Number;
        /** Timestamp of the first tag in the buffer. **/
        private var _start:Number;
        /** Current playback state. **/
        private var _state:String;
        /** Netstream instance used for playing the stream. **/
        private var _stream:NetStream;
        /** The last tag that was appended to the buffer. **/
        private var _tag:Number;
        /** soundtransform object. **/
        private var _transform:SoundTransform;
        /** The start position of the stream. **/
        public var startPosition:Number = 0;
        /** Reference to the video object. **/
        private var _video:Object;
		/** Keeps track of the first tag added to the buffer **/
		private var _firstTag:Tag;


        /** Create the buffer. **/
        public function Buffer(adaptive:Adaptive, loader:Loader, video:Object):void {
            _adaptive = adaptive;
            _loader = loader;
            _video = video;
            _adaptive.addEventListener(AdaptiveEvent.MANIFEST,_manifestHandler);
            _connection = new NetConnection();
            _connection.connect(null);
            _transform = new SoundTransform();
            _transform.volume = 0.9;
            _setState(AdaptiveStates.IDLE);
			_firstTag = null;
        };


        /** Check the bufferlength. **/
        private function _checkBuffer():void {
            var buffer:Number = 0;         
            // Calculate the buffer and position.
            if(_buffer.length) {
                buffer = _buffer[_buffer.length-1].pts/1000 - _stream.time - _firstTag.pts/1000;
                _loader.setBuffer(buffer);
                _setPosition();
            }
            var maxIndex:Number = _levels[0].fragments.length-1;
            for (var i:Number = 1; i < _levels.length; i++) {
               maxIndex = Math.min(maxIndex,_levels[i].fragments.length-1);
            }
            // Load new tags from fragment.
            if(buffer < Buffer.LENGTH && _next <= maxIndex && !_loading) {
                _loader.load(_next,_loaderCallback,_buffer.length);
                _loading = true;
            }
            // Append tags to buffer.
            if((_state == AdaptiveStates.PLAYING && _stream.bufferLength < Buffer.LENGTH / 3) || 
               (_state == AdaptiveStates.BUFFERING && buffer > restart_length))
             {
                //Log.txt("appending data");
                while(_tag < _buffer.length && _stream.bufferLength < Buffer.LENGTH * 2 / 3) {
                    if(_buffer[_tag].type == Tag.AVC_HEADER && _buffer[_tag].level != _level) {
                        _level = _buffer[_tag].level;
                    }
                    try {
                        _stream.appendBytes(_buffer[_tag].data);
                    } catch (error:Error) {
                        _errorHandler(new Error(_buffer[_tag].type+": "+ error.message));
                    }
                    // Last tag done? Then append sequence end.
                    if (_adaptive.getType() == AdaptiveTypes.VOD && _next == length && _tag == _buffer.length - 1) {
                        _stream.appendBytesAction(NetStreamAppendBytesAction.END_SEQUENCE);
                        _stream.appendBytes(new ByteArray());
                    }
                    _tag++;
                }
            }
            // Set playback state and complete.
            if(_stream.bufferLength < Buffer.LENGTH / 10) {
                if(_next == length) {
                    if(_stream.bufferLength == 0) {
                        _complete();
                    }
                } else if(_state == AdaptiveStates.PLAYING) {
                    _setState(AdaptiveStates.BUFFERING);
                }
            } else if (_state == AdaptiveStates.BUFFERING) {
                _setState(AdaptiveStates.PLAYING);
            }
        };


        /** The video completed playback. **/
        private function _complete():void {
            _setState(AdaptiveStates.IDLE);
            clearInterval(_interval);
            // _stream.pause();
            _adaptive.dispatchEvent(new AdaptiveEvent(AdaptiveEvent.COMPLETE));
        };


        /** Dispatch an error to the controller. **/
        private function _errorHandler(error:Error):void { 
            _adaptive.dispatchEvent(new AdaptiveEvent(AdaptiveEvent.ERROR,error.toString()));
        };


        /** Return the current playback state. **/
        public function getPosition():Number {
            return _start;
        };


        /** Return the current playback state. **/
        public function getState():String {
            return _state;
        };


        /** Add a fragment to the buffer. **/
        private function _loaderCallback(tags:Vector.<Tag>):void {
			
			_buffer = _buffer.slice(_tag);
			_tag = 0;
			tags.sort(_sortTags);
			for each (var t:Tag in tags) {
				_buffer.push(t);
			}
			if(!_firstTag) {
				_firstTag = _buffer[0];
			}
            _next++;
            _loading = false;
        };

        /** Start streaming on manifest load. **/
        private function _manifestHandler(event:AdaptiveEvent):void {
            if(_state == AdaptiveStates.IDLE) {
                _levels = event.levels;
                _stream = new NetStream(_connection);
                _video.attachNetStream(_stream);
                _stream.play(null);
                _stream.soundTransform = _transform;
                _stream.appendBytesAction(NetStreamAppendBytesAction.RESET_BEGIN);
                _stream.appendBytes(FLV.getHeader());
                _level = 0;
                seek(startPosition);
            }
        };


        /** Toggle playback. **/
        public function pause():void {
            clearInterval(_interval);
            if(_state == AdaptiveStates.PAUSED) { 
                _setState(AdaptiveStates.BUFFERING);
                _stream.resume();
                _interval = setInterval(_checkBuffer,100);
            } else if(_state == AdaptiveStates.PLAYING) {
                _setState(AdaptiveStates.PAUSED);
                _stream.pause();
            }
        };


        /** Set current position. **/
        private function _setPosition():void {
            var position:Number = Math.round(_stream.time*100 + _start*100)/100;
            if(position != _position && _adaptive.getType() == AdaptiveTypes.VOD) {
                _position = position;
                _adaptive.dispatchEvent(new AdaptiveEvent(AdaptiveEvent.POSITION,_position));
            }
        };


        /** Change playback state. **/
        private function _setState(state:String):void {
            if(state != _state) {
                _state = state;
                _adaptive.dispatchEvent(new AdaptiveEvent(AdaptiveEvent.STATE,_state));
            }
        };


        /** Sort the buffer by tag. **/
        private function _sortTags(x:Tag,y:Tag):Number {
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


        /** Start playing data in the buffer. **/
        public function seek(position:Number):void {
            if(_levels.length) {
                _buffer = new Vector.<Tag>();
				_firstTag = null;
				_loader.clearLoader();
				_loading = false;
                _start = 0;
                _tag = 0;
                startPosition = 0;
                _stream.seek(0);
                _stream.appendBytesAction(NetStreamAppendBytesAction.RESET_SEEK);
				// For live streams, start at fragment N-2 instead of 0
				if( _adaptive.getType() == AdaptiveTypes.LIVE )
					_next = Math.max(0,_levels[_level].fragments.length - 3);
				else
                _next = _levels[_level].indexOf(position);
                _start = _levels[_level].fragments[_next].start;
				_setState(AdaptiveStates.BUFFERING);
                clearInterval(_interval);
                _interval = setInterval(_checkBuffer,100);
            }
        };


        /** Stop playback. **/
        public function stop():void {
            if(_stream) {
                _stream.pause();
            }
            _loading = false;
            clearInterval(_interval);
            _levels = [];
            _setState(AdaptiveStates.IDLE);
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