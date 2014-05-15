package org.mangui.HLS.streaming {
    import org.mangui.HLS.utils.Log;
    import org.mangui.HLS.*;

    /** Class that manages automatic min/low buffer len **/
    public class AutoBufferManager {
        /** Reference to the HLS controller. **/
        private var _hls : HLS;
        // max nb of samples used for bw checking. the bigger it is, the more conservative it is.
        private static const MAX_SAMPLES : Number = 30;
        private var _bw : Vector.<Number>;
        private var _nb_samples : uint;
        private var _targetduration : Number;
        private var _minBufferLength : Number;

        /** Create the loader. **/
        public function AutoBufferManager(hls : HLS) : void {
            _hls = hls;
            _hls.addEventListener(HLSEvent.MANIFEST_LOADED, _manifestLoadedHandler);
            _hls.addEventListener(HLSEvent.TAGS_LOADED, _fragmentLoadedHandler);
            _hls.addEventListener(HLSEvent.FRAGMENT_LOADED, _fragmentLoadedHandler);
        };

        public function get minBufferLength() : Number {
            return _minBufferLength;
        }

        private function _manifestLoadedHandler(event : HLSEvent) : void {
            _nb_samples = 0;
            _targetduration = event.levels[0].targetduration;
            _bw = new Vector.<Number>(MAX_SAMPLES);
            _minBufferLength = _targetduration;
        };

        private function _fragmentLoadedHandler(event : HLSEvent) : void {
            var cur_bw : Number = event.metrics.bandwidth;
            _bw[_nb_samples % MAX_SAMPLES] = cur_bw;
            _nb_samples++;

            // compute min bw on MAX_SAMPLES
            var min_bw : Number = Number.POSITIVE_INFINITY;
            var samples_max : Number = Math.min(_nb_samples, MAX_SAMPLES);
            for (var i : Number = 0; i < samples_max; i++) {
                min_bw = Math.min(min_bw, _bw[i]);
            }

            // give more weight to current bandwidth
            var bw_ratio : Number = 2 * cur_bw / (min_bw + cur_bw);

            /* predict time to dl next segment using a conservative approach.
             * 
             * heuristic is as follow :
             * 
             * time to dl next segment = time to dl current segment *  (playlist target duration / current segment duration) * bw_ratio
             *                           \---------------------------------------------------------------------------------/
             *                                  this part is a simple rule by 3, assuming we keep same dl bandwidth 
             *  bw ratio is the conservative factor, assuming that next segment will be downloaded with min bandwidth
             */
            _minBufferLength = event.metrics.frag_processing_time * (_targetduration / event.metrics.frag_duration) * bw_ratio;
            // avoid min > max
            if (HLSSettings.maxBufferLength) {
                _minBufferLength = Math.min(_hls.maxBufferLength, _minBufferLength);
            }
            Log.debug("AutoBufferManager:minBufferLength:" + _minBufferLength);
        };
    }
}