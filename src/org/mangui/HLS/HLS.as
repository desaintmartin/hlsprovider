package org.mangui.HLS {


import org.mangui.HLS.parsing.Level;
import org.mangui.HLS.streaming.*;
import org.mangui.HLS.utils.*;

import flash.events.*;
import flash.net.NetStream;
import flash.net.NetConnection;

    /** Class that manages the streaming process. **/
    public class HLS extends EventDispatcher {
        /** The quality monitor. **/
        private var _fragmentLoader:FragmentLoader;
        /** The manifest parser. **/
        private var _manifestLoader:ManifestLoader;
        /** HLS NetStream **/
        private var _hlsNetStream:HLSNetStream;

	private var _client:Object = {};

        /** Create and connect all components. **/
    public function HLS():void {
            var connection:NetConnection = new NetConnection();
            connection.connect(null);
            _manifestLoader = new ManifestLoader(this);
            _fragmentLoader = new FragmentLoader(this);
            _hlsNetStream = new HLSNetStream(connection,this, _fragmentLoader);
        };


        /** Forward internal errors. **/
        override public function dispatchEvent(event:Event):Boolean {
            if(event.type == HLSEvent.ERROR) {
                Log.error(HLSEvent(event).message);
                _hlsNetStream.close();
            }
            return super.dispatchEvent(event);
        };


        /** Return the current quality level. **/
        public function getLevel():Number {
            return _fragmentLoader.getLevel();
        };


        /** Return the list with bitrate levels. **/
        public function getLevels():Vector.<Level> {
            return _manifestLoader.getLevels();
        };


        /** Return the list with switching metrics. **/
        public function getMetrics():Object {
            return _fragmentLoader.getMetrics();
        };


        /** Return the current playback position. **/
        public function getPosition():Number {
            return _hlsNetStream.getPosition();
        };


        /** Return the current playback position. **/
        public function getState():String {
            return _hlsNetStream.getState();
        };


        /** Return the type of stream. **/
        public function getType():String {
            return _manifestLoader.getType();
        };


        /** Start playing an new HLS stream. **/
        public function load(url:String):void {
            _hlsNetStream.close();
            _manifestLoader.load(url);
        };  

        /** Update the screen width. **/
        public function setWidth(width:Number):void {
            _fragmentLoader.setWidth(width);
        };

        /* update playback quality level */
        public function setPlaybackQuality(level:Number):void {
            _fragmentLoader.setPlaybackQuality(level);
        };
    public function get stream():NetStream {
        return _hlsNetStream;
    }
    public function get client():Object {
        return _client;
    }
    public function set client(value:Object):void {
        _client = value;
    }

    /** get current Buffer Length  **/
    public function getBufferLength():Number {
      return _hlsNetStream.bufferLength;
    };

    /** set min Buffer Length  **/
    public function set minBufferLength(new_len:Number):void {
      _hlsNetStream.minBufferLength = new_len;
    }

    /** get min Buffer Length  **/
    public function get minBufferLength():Number {
      return _hlsNetStream.minBufferLength;
    };

    /** set max Buffer Length  **/
    public function set maxBufferLength(new_len:Number):void {
      _hlsNetStream.maxBufferLength = new_len;
    }
    
    /** get max Buffer Length  **/
    public function get maxBufferLength():Number {
      return _hlsNetStream.maxBufferLength;
    };
}
;
}