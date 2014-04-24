package org.mangui.HLS.utils {
    import flash.external.ExternalInterface;
    
    import org.mangui.HLS.HLSSettings;

    /** Class that sends log messages to browser console. **/
    public class Log {
        private static const LEVEL_INFO : String = "INFO:";
        private static const LEVEL_DEBUG : String = "DEBUG:";
        private static const LEVEL_WARN : String = "WARN:";
        private static const LEVEL_ERROR : String = "ERROR:";
        public static var LOG_INFO_ENABLED : Boolean = HLSSettings.logInfo;
        public static var LOG_DEBUG_ENABLED : Boolean = HLSSettings.logDebug;
        public static var LOG_DEBUG2_ENABLED : Boolean = HLSSettings.logDebug2;
        public static var LOG_WARN_ENABLED : Boolean = HLSSettings.logWarn;
        public static var LOG_ERROR_ENABLED : Boolean = HLSSettings.logError;

        public static function info(message : *) : void {
            if (LOG_INFO_ENABLED)
                outputlog(LEVEL_INFO, String(message));
        };

        public static function debug(message : *) : void {
            if (LOG_DEBUG_ENABLED)
                outputlog(LEVEL_DEBUG, String(message));
        };

        public static function debug2(message : *) : void {
            if (LOG_DEBUG2_ENABLED)
                outputlog(LEVEL_DEBUG, String(message));
        };

        public static function warn(message : *) : void {
            if (LOG_WARN_ENABLED)
                outputlog(LEVEL_WARN, String(message));
        };

        public static function error(message : *) : void {
            if (LOG_ERROR_ENABLED)
                outputlog(LEVEL_ERROR, String(message));
        };

        /** Log a message to the console. **/
        private static function outputlog(level : String, message : String) : void {
            if (ExternalInterface.available)
                ExternalInterface.call('console.log', level + message);
            else trace(level + message);
        }
    };
}