package org.mangui.HLS {
    /** Error Identifier **/
    public class HLSError {
        public static const OTHER_ERROR : Number = 0;
        public static const MANIFEST_LOADING_CROSSDOMAIN_ERROR : Number = 1;
        public static const MANIFEST_LOADING_IO_ERROR : Number = 2;
        public static const MANIFEST_PARSING_ERROR : Number = 3;
        public static const FRAGMENT_LOADING_ERROR : Number = 4;
        public static const FRAGMENT_PARSING_ERROR : Number = 5;
        public static const KEY_LOADING_ERROR : Number = 6;
        public static const KEY_PARSING_ERROR : Number = 7;
        public static const TAG_APPENDING_ERROR : Number = 8;
        private var _code : Number;
        private var _url : String;
        private var _msg : String;

        public function HLSError(code : Number, url : String, msg : String) {
            _code = code;
            _url = url;
            _msg = msg;
        }

        public function get code() : Number {
            return _code;
        }

        public function get msg() : String {
            return _msg;
        }

        public function get url() : String {
            return _url;
        }

        public function toString() : String {
            return "HLSError(code/url/msg)=" + _code + "/" + _url + "/" + _msg;
        }
    }
}