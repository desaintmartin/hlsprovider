package org.mangui.HLS {
    public final class HLSSettings extends Object {
        // // // // /////////////////////////////////////
        //
        // org.mangui.HLS.streaming.HLSNetStream
        //
        // // // // /////////////////////////////////////
        /**
         * Defines minimum buffer length in seconds before playback can start, after seeking or buffer stalling.
         * 
         * Default is -1 = auto
         */
        public static var minBufferLength : Number = -1;
        /**
         * Defines maximum buffer length in seconds. 
         * (0 means infinite buffering)
         * 
         * Default is 60.
         */
        public static var maxBufferLength : Number = 60;
        /**
         * Defines low buffer length in seconds. 
         * When crossing down this threshold, HLS will switch to buffering state.
         * 
         * Default is 3.
         */
        public static var lowBufferLength : Number = 3;
        /**
         * Defines seek mode to one form available in HLSSeekmode class:
         *      HLSSeekmode.ACCURATE_SEEK - accurate seeking to exact requested position
         *      HLSSeekmode.KEYFRAME_SEEK - key-frame based seeking (seek to nearest key frame before requested seek position)
         *      HLSSeekmode.SEGMENT_SEEK - segment based seeking (seek to beginning of segment containing requested seek position)
         * 
         * Default is HLSSeekmode.ACCURATE_SEEK.
         */
        public static var seekMode : String = HLSSeekmode.ACCURATE_SEEK;
        // // // // /////////////////////////////////////
        //
        // org.mangui.HLS.streaming.FragmentLoader
        //
        // // // // /////////////////////////////////////
        /**
         * If set to true, playback will start from lowest non-audio level after manifest download. 
         * If set to false, playback will start from level matching download bandwidth.
         * 
         * Default is false
         */
        public static var startFromLowestLevel : Boolean = false;
        /**
         * If set to true, playback will start from lowest non-audio level after any seek operation.
         * If set to false, playback will start from level used before seeking.
         * 
         * Default is false
         */
        public static var seekFromLowestLevel : Boolean = false;
        
        /** max nb of retries for Fragment Loading in case I/O errors are met,
         *      0, means no retry, error will be triggered automatically
         *     -1 means infinite retry 
         */        
        public static var fragmentLoadMaxRetry : Number = -1;
        // // // // /////////////////////////////////////
        //
        // org.mangui.HLS.streaming.ManifestLoader
        //
        // // // // /////////////////////////////////////
        /**
         * If set to true, live playlist will be flushed from URL cache before reloading 
         * (this is to workaround some cache issues with some combination of Flash Player / IE version)
         * 
         * Default is false
         */
        public static var flushLiveURLCache : Boolean = false;
        
        /** max nb of retries for Manifest Loading in case I/O errors are met,
         *      0, means no retry, error will be triggered automatically
         *     -1 means infinite retry 
         */
        public static var manifestLoadMaxRetry : Number = -1;
        // // // // /////////////////////////////////////
        //
        // org.mangui.HLS.utils.Log
        //
        // // // // /////////////////////////////////////
        /**
         * Defines whether INFO level log messages will will appear in the console
         * Default is true.
         */
        public static var logInfo : Boolean = true;
        /**
         * Defines whether DEBUG level log messages will will appear in the console
         * Default is false.
         */
        public static var logDebug : Boolean = false;
        /**
         * Defines whether DEBUG2 level log messages will will appear in the console
         * Default is false.
         */
        public static var logDebug2 : Boolean = false;
        /**
         * Defines whether WARN level log messages will will appear in the console
         * Default is true.
         */
        public static var logWarn : Boolean = true;
        /**
         * Defines whether ERROR level log messages will will appear in the console
         * Default is true.
         */
        public static var logError : Boolean = true;
    }
}