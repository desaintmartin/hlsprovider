package com.mangui.HLS {


    import flash.events.Event;


    /** Event fired when an error prevents playback. **/
    public class HLSEvent extends Event {


        /** Identifier for a playback complete event. **/
        public static const COMPLETE:String = "hlsEventComplete";
        /** Identifier for a playback error event. **/
        public static const ERROR:String = "hlsEventError";
        /** Identifier for a fragment load event. **/
        public static const FRAGMENT:String = "hlsEventFragment";
        /** Identifier for a manifest (re)load event. **/
        public static const MANIFEST:String = "hlsEventManifest";
        /** Identifier for a playback media time change event. **/
        public static const MEDIA_TIME:String = "hlsEventMediaTime";
        /** Identifier for a playback state switch event. **/
        public static const STATE:String = "hlsEventState";
        /** Identifier for a quality level switch event. **/
        public static const SWITCH:String = "hlsEventLevel";
        /** Identifier for a audio only fragment **/
        public static const AUDIO:String = "audioOnly";

        /** The current quality level. **/
        public var level:Number;
        /** The list with quality levels. **/
        public var levels:Array;
        /** The error message. **/
        public var message:String;
        /** The current QOS metrics. **/
        public var metrics:Object;
        /** The time position. **/
        public var mediatime:Object;
        /** The new playback state. **/
        public var state:String;


        /** Assign event parameter and dispatch. **/
        public function HLSEvent(type:String, parameter:*=null) {
            switch(type) {
                case HLSEvent.ERROR:
                    message = parameter as String;
                    break;
                case HLSEvent.FRAGMENT:
                    metrics = parameter as Object;
                    break;
                case HLSEvent.MANIFEST:
                    levels = parameter as Array;
                    break;
                case HLSEvent.MEDIA_TIME:
                    mediatime = parameter as Object;
                    break;
                case HLSEvent.STATE:
                    state = parameter as String;
                    break;
                case HLSEvent.SWITCH:
                    level = parameter as Number;
                    break;
            }
            super(type, false, false);
        };


    }


}