package org.mangui.osmf.plugins {
    import flash.utils.Dictionary;

    /**
     * HLSPlugin is an enumeration which holds every legal external params names 
     * which can be used to customize HLSSettings and maps them to the relevant HLSSettings values
     * 
     */
    public class HLSPluginParams {
        public static const MIN_BUFFER_LENGTH : String = "minbufferlength";
        public static const MAX_BUFFER_LENGTH : String = "maxbufferlength";
        public static const LOW_BUFFER_LENGTH : String = "lowbufferlength";
        public static const SEEK_MODE : String = "seekmode";
        public static const START_FROM_LOWEST_LEVEL : String = "startfromlowestlevel";
        public static const SEEK_FROM_LOWEST_LEVEL : String = "seekfromlowestlevel";
        public static const FLUSH_LIVE_URL_CACHE : String = "live_flushurlcache";
        public static const MANIFEST_LOAD_MAX_RETRY : String = "manifestloadmaxretry";
        public static const FRAGMENT_LOAD_MAX_RETRY : String = "segmentloadmaxretry";
        public static const LOG_INFO : String = "info";
        public static const LOG_DEBUG : String = "debug";
        public static const LOG_DEBUG2 : String = "debug2";
        public static const LOG_WARN : String = "warn";
        public static const LOG_ERROR : String = "error";

        public static function get paramMap() : Dictionary {
            return _paramMap;
        }

        /**
         * HLSSettings <-> params maping
         */
        private static var _paramMap : Dictionary = new Dictionary();
        paramMap[HLSPluginParams.MIN_BUFFER_LENGTH] = "minBufferLength";
        paramMap[HLSPluginParams.MAX_BUFFER_LENGTH] = "maxBufferLength";
        paramMap[HLSPluginParams.LOW_BUFFER_LENGTH] = "lowBufferLength";
        paramMap[HLSPluginParams.SEEK_MODE] = "seekMode";
        paramMap[HLSPluginParams.START_FROM_LOWEST_LEVEL] = "startFromLowestLevel";
        paramMap[HLSPluginParams.SEEK_FROM_LOWEST_LEVEL] = "seekFromLowestLevel";
        paramMap[HLSPluginParams.FLUSH_LIVE_URL_CACHE] = "flushLiveURLCache";
        paramMap[HLSPluginParams.MANIFEST_LOAD_MAX_RETRY] = "manifestLoadMaxRetry";
        paramMap[HLSPluginParams.FRAGMENT_LOAD_MAX_RETRY] = "segmentLoadMaxRetry";
        paramMap[HLSPluginParams.LOG_INFO] = "logInfo";
        paramMap[HLSPluginParams.LOG_DEBUG] = "logDebug";
        paramMap[HLSPluginParams.LOG_DEBUG2] = "logDebug2";
        paramMap[HLSPluginParams.LOG_WARN] = "logWarn";
        paramMap[HLSPluginParams.LOG_ERROR] = "logError";
    }
}