package org.mangui.HLS {
    /** Identifiers for the different stream types. **/
    public class HLSMetrics {
        private var _level : Number;
        private var _bandwidth : Number;
        private var _frag_duration : Number;
        private var _frag_processing_time : Number;

        public function HLSMetrics(level : Number, bandwidth : Number, frag_duration : Number, frag_processing_time : Number) {
            _level = level;
            _bandwidth = bandwidth;
            _frag_duration = frag_duration;
            _frag_processing_time = frag_processing_time;
        }

        public function get level() : Number {
            return _level;
        }

        public function get bandwidth() : Number {
            return _bandwidth;
        }

        public function get frag_duration() : Number {
            return _frag_duration;
        }

        public function get frag_processing_time() : Number {
            return _frag_processing_time;
        }
    }
}