package { 


    import org.mangui.HLS.*;
    import flash.display.*;
    import flash.events.*;
    import flash.net.*;
    import flash.external.ExternalInterface;
    import flash.geom.Rectangle;
    import flash.media.Video;
    import flash.media.StageVideo;
    import flash.media.StageVideoAvailability;
    import flash.utils.setTimeout;


    public class ChromelessPlayer extends Sprite {


        /** reference to the framework. **/
        private var _hls:HLS;
        /** Sheet to place on top of the video. **/
        private var _sheet:Sprite;
        /** Reference to the video element. **/
        private var _video:StageVideo;
        /** Javascript callbacks. **/
        private var _callbacks:Object = {};

        /** Initialization. **/
        public function ChromelessPlayer():void {
            // Set stage properties
            stage.scaleMode = StageScaleMode.NO_SCALE;
            stage.align = StageAlign.TOP_LEFT;
            stage.fullScreenSourceRect = new Rectangle(0,0,stage.stageWidth,stage.stageHeight);
            stage.addEventListener(StageVideoAvailabilityEvent.STAGE_VIDEO_AVAILABILITY, _onStageVideoState);
            // Draw sheet for catching clicks
            _sheet = new Sprite();
            _sheet.graphics.beginFill(0x000000,0);
            _sheet.graphics.drawRect(0,0,stage.stageWidth,stage.stageHeight);
            _sheet.addEventListener(MouseEvent.CLICK,_clickHandler);
            _sheet.buttonMode = true;
            addChild(_sheet);
            // Connect getters to JS.
            ExternalInterface.addCallback("getLevel",_getLevel);
            ExternalInterface.addCallback("getLevels",_getLevels);
            ExternalInterface.addCallback("getMetrics",_getMetrics);
            ExternalInterface.addCallback("getPosition",_getPosition);
            ExternalInterface.addCallback("getState",_getState);
            ExternalInterface.addCallback("getType",_getType);
            // Connect calls to JS.
            ExternalInterface.addCallback("play",_play);
            ExternalInterface.addCallback("pause",_pause);
            ExternalInterface.addCallback("seek",_seek);
            ExternalInterface.addCallback("stop",_stop);
            ExternalInterface.addCallback("volume",_volume);
            // Connect callbacks to JS.
            ExternalInterface.addCallback("onComplete",_onComplete);
            ExternalInterface.addCallback("onError",_onError);
            ExternalInterface.addCallback("onFragment",_onFragment);
            ExternalInterface.addCallback("onManifest",_onManifest);
            ExternalInterface.addCallback("onPosition",_onPosition);
            ExternalInterface.addCallback("onState",_onState);
            ExternalInterface.addCallback("onSwitch",_onSwitch);
            setTimeout(_pingJavascript,50);
        };


        /** Notify javascript the framework is ready. **/
        private function _pingJavascript():void {
            ExternalInterface.call("onHLSReady",ExternalInterface.objectID);
        };


        /** Forward events from the framework. **/
        private function _completeHandler(event:HLSEvent):void {
            if(_callbacks.oncomplete) {
                ExternalInterface.call(_callbacks.oncomplete);
            }
        };
        private function _errorHandler(event:HLSEvent):void {
            if(_callbacks.onerror) {
                ExternalInterface.call(_callbacks.onerror,event.message);
            }
        };
        private function _fragmentHandler(event:HLSEvent):void {
            if(_callbacks.onfragment) {
                ExternalInterface.call(_callbacks.onfragment,event.metrics);
            }
        };
        private function _manifestHandler(event:HLSEvent):void {
            if(_callbacks.onmanifest) {
                ExternalInterface.call(_callbacks.onmanifest,event.levels);
            }
        };
        private function _mediaTimeHandler(event:HLSEvent):void {
            if(_callbacks.onposition) {
                ExternalInterface.call(_callbacks.onposition,event.mediatime);
            }
        };
        private function _stateHandler(event:HLSEvent):void {
            if(_callbacks.onstate) {
                ExternalInterface.call(_callbacks.onstate,event.state);
            }
        };
        private function _switchHandler(event:HLSEvent):void {
            if(_callbacks.onswitch) {
                ExternalInterface.call(_callbacks.onswitch,event.level);
            }
        };


        /** Javascript getters. **/
        private function _getLevel():Number { return _hls.getLevel(); };
        private function _getLevels():Array { return _hls.getLevels(); };
        private function _getMetrics():Object { return _hls.getMetrics(); };
        private function _getPosition():Number { return _hls.getPosition(); };
        private function _getState():String { return _hls.getState(); };
        private function _getType():String { return _hls.getType(); };


        /** Javascript calls. **/
        private function _play(url:String,start:Number=0):void { _hls.play(url,start); };
        private function _pause():void { _hls.pause(); };
        private function _seek(position:Number):void { _hls.seek(position); };
        private function _stop():void { _hls.stop(); };
        private function _volume(percent:Number):void { _hls.volume(percent); };


        /** Javascript event subscriptions. **/
        private function _onComplete(name:String):void { _callbacks.oncomplete = name; };
        private function _onError(name:String):void { _callbacks.onerror = name; };
        private function _onFragment(name:String):void { _callbacks.onfragment = name; };
        private function _onManifest(name:String):void { _callbacks.onmanifest = name; };
        private function _onPosition(name:String):void { _callbacks.onposition = name; };
        private function _onState(name:String):void { _callbacks.onstate = name; };
        private function _onSwitch(name:String):void { _callbacks.onswitch = name; };


        /** Mouse click handler. **/
        private function _clickHandler(event:MouseEvent):void {
            if(stage.displayState == StageDisplayState.FULL_SCREEN) {
                stage.displayState = StageDisplayState.NORMAL;
            } else {
                stage.displayState = StageDisplayState.FULL_SCREEN;
            }
            _hls.setWidth(stage.stageWidth);
        };


        /** StageVideo detector. **/
        private function _onStageVideoState(event:StageVideoAvailabilityEvent):void {
            var available:Boolean = (event.availability == StageVideoAvailability.AVAILABLE);
            if (available && stage.stageVideos.length > 0) {
              _video = stage.stageVideos[0];
              _video.viewPort = new Rectangle(0, 0, stage.stageWidth, stage.stageHeight);
              _hls = new HLS();
            } else {
              var video:Video = new Video(stage.stageWidth, stage.stageHeight);
              addChild(video);
              _hls = new HLS();
            }
            _video.attachNetStream(_hls.stream);
            _hls.setWidth(stage.stageWidth);
            _hls.addEventListener(HLSEvent.PLAYBACK_COMPLETE,_completeHandler);
            _hls.addEventListener(HLSEvent.ERROR,_errorHandler);
            _hls.addEventListener(HLSEvent.FRAGMENT_LOADED,_fragmentHandler);
            _hls.addEventListener(HLSEvent.MANIFEST_LOADED,_manifestHandler);
            _hls.addEventListener(HLSEvent.MEDIA_TIME,_mediaTimeHandler);
            _hls.addEventListener(HLSEvent.STATE,_stateHandler);
            _hls.addEventListener(HLSEvent.QUALITY_SWITCH,_switchHandler);
        };


    }


}