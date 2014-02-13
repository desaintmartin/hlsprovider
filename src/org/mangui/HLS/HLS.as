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
        public function get level():Number {
            return _fragmentLoader.level;
        };

        /* manually set playback level (-1 for automatic level selection) */
        public function set level(level:Number):void {
           _fragmentLoader.level = level;
        };

        /* check if we are in autolevel mode */
        public function get autolevel():Boolean {
            return _fragmentLoader.autolevel;
        };

        /** Return the list with bitrate levels. **/
        public function get levels():Vector.<Level> {
            return _manifestLoader.levels;
        };


        /** Return the list with switching metrics. **/
        public function get metrics():HLSMetrics {
            return _fragmentLoader.metrics;
        };

        /** Return the current playback position. **/
        public function get position():Number {
            return _hlsNetStream.position;
        };


        /** Return the current playback state. **/
        public function get state():String {
            return _hlsNetStream.state;
        };


        /** Return the type of stream. **/
        public function get type():String {
            return _manifestLoader.type;
        };


        /** Start playing an new HLS stream. **/
        public function load(url:String):void {
            _hlsNetStream.close();
            _manifestLoader.load(url);
        };  

        /** Update the screen width. **/
        public function set width(width:Number):void {
            _fragmentLoader.width = width;
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
    public function get bufferLength():Number {
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

    /** get the list of audio tracks **/
    public function get audioTracks():Vector.<HLSAudioTrack> {
        return _fragmentLoader.audioTracks;
    };

    /** get the id of the selected audio track **/
    public function get audioTrack():Number {
        return _fragmentLoader.audioTrack;
    };

    /** select an audio track **/
    public function set audioTrack(val:Number):void {
        _fragmentLoader.audioTrack = val;
    }

   /** if set to true, it will force to flush live URL cache, could be useful with live playlist 
    * as some combinations of Flash Player / Internet Explorer are not able to detect updated URL properly
    **/ 
   public function set flushLiveURLCache(val:Boolean):void {
      _manifestLoader.flushLiveURLCache=val;
   }

   public function get flushLiveURLCache():Boolean {
   return _manifestLoader.flushLiveURLCache;
   }

   public function set startFromLowestLevel(val:Boolean):void {
      _fragmentLoader.startFromLowestLevel=val;
   }

   public function get startFromLowestLevel():Boolean {
   return _fragmentLoader.startFromLowestLevel;
   }

}
;
}