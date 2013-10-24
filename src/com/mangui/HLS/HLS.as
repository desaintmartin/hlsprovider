package com.mangui.HLS {


import com.mangui.HLS.streaming.*;
import com.mangui.HLS.utils.*;

import flash.events.*;
import flash.net.NetStream;

    /** Class that manages the streaming process. **/
    public class HLS extends EventDispatcher {


        /** The playback buffer. **/
        private var _buffer:Buffer;
        /** The quality monitor. **/
        private var _loader:FragmentLoader;
        /** The manifest parser. **/
        private var _manifestLoader:ManifestLoader;
	/** HLS NetStream **/
	private var _stream:NetStream;

	private var _client:Object = {};

        /** Create and connect all components. **/
    public function HLS(stream:NetStream):void {
            _stream = stream;
            _manifestLoader = new ManifestLoader(this);
            _loader = new FragmentLoader(this);
            _buffer = new Buffer(this, _loader, stream);
        };


        /** Forward internal errors. **/
        override public function dispatchEvent(event:Event):Boolean {
            if(event.type == HLSEvent.ERROR) {
                Log.txt(HLSEvent(event).message);
                stop();
            }
            return super.dispatchEvent(event);
        };


        /** Return the current quality level. **/
        public function getLevel():Number {
            return _loader.getLevel();
        };


        /** Return the list with bitrate levels. **/
        public function getLevels():Array {
            return _manifestLoader.getLevels();
        };


        /** Return the list with switching metrics. **/
        public function getMetrics():Object {
            return _loader.getMetrics();
        };


        /** Return the current playback position. **/
        public function getPosition():Number {
            return _buffer.getPosition();
        };


        /** Return the current playback position. **/
        public function getState():String {
            return _buffer.getState();
        };


        /** Return the type of stream. **/
        public function getType():String {
            return _manifestLoader.getType();
        };


        /** Start playing an new HLS stream. **/
        public function play(url:String,start:Number=0):void {
            _buffer.stop();
            _buffer.PlaybackStartPosition = start;
            _manifestLoader.load(url);
        };


    /** Pause playback **/
        public function pause():void {
            _buffer.pause();
    };
    /** Resume playback **/
    public function resume():void {
        _buffer.resume();
        };


        /** Seek to another position in the stream. **/
        public function seek(position:Number):void {
            _buffer.seek(position);
        };


        /** Stop streaming altogether. **/
        public function stop():void {
            _buffer.stop();
        };


        /** Change the audio volume of the stream. **/
        public function volume(percent:Number):void {
            _buffer.volume(percent);
        };


        /** Update the screen width. **/
        public function setWidth(width:Number):void {
            _loader.setWidth(width);
        };

        /* update playback quality level */
        public function setPlaybackQuality(level:Number):void {
            _loader.setPlaybackQuality(level);
            _buffer.seek(_buffer.getPosition());
        };
    public function get stream():NetStream {
        return _stream;
    }
    public function get client():Object {
        return _client;
    }
    public function set client(value:Object):void {
        _client = value;
    }
}
;
}