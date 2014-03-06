package org.mangui.osmf.plugins {
    import org.osmf.traits.TimeTrait;
    import org.mangui.HLS.HLS;
    import org.mangui.HLS.HLSEvent;

    public class HLSTimeTrait extends TimeTrait {
        private var _hls : HLS;
        private var _duration : Number = 0;
        private var _position : Number = 0;

        public function HLSTimeTrait(hls : HLS, duration : Number = 0) {
            super(duration);
            _duration = duration;
            _hls = hls;
            _hls.addEventListener(HLSEvent.MEDIA_TIME, _mediaTimeHandler);
            _hls.addEventListener(HLSEvent.PLAYBACK_COMPLETE, _playbackComplete);
        }

        override public function get duration() : Number {
            return _duration;
        }

        override public function get currentTime() : Number {
            // Log.info("HLSTimeTrait:get currentTime:" + _position);
            return _position;
        }

        /** Update playback position/duration **/
        private function _mediaTimeHandler(event : HLSEvent) : void {
            _position = Math.max(0,event.mediatime.position);
            _duration = event.mediatime.duration;
        };

        /** playback complete handler **/
        private function _playbackComplete(event : HLSEvent) : void {
            signalComplete();
        }
    }
}