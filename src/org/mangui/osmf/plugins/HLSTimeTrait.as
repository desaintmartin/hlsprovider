package org.mangui.osmf.plugins {
    import org.mangui.HLS.utils.Log;
    import org.osmf.traits.TimeTrait;
    import org.mangui.HLS.HLS;
    import org.mangui.HLS.HLSEvent;

    public class HLSTimeTrait extends TimeTrait {
        private var _hls : HLS;
        private var _duration : Number;
        private var _position : Number;

        public function HLSTimeTrait(hls : HLS, duration : Number = 0) {
            Log.debug("HLSTimeTrait()");
            super(duration);
            _position = 0;
            _duration = duration;
            _hls = hls;
            _hls.addEventListener(HLSEvent.MEDIA_TIME, _mediaTimeHandler);
            _hls.addEventListener(HLSEvent.PLAYBACK_COMPLETE, _playbackComplete);
        }

        override public function get duration() : Number {
            return _duration;
        }

        override public function get currentTime() : Number {
            return _position;
        }

        override public function dispose() : void {
            Log.debug("HLSTimeTrait:dispose");
            _hls.removeEventListener(HLSEvent.MEDIA_TIME, _mediaTimeHandler);
            _hls.removeEventListener(HLSEvent.PLAYBACK_COMPLETE, _playbackComplete);
            super.dispose();
        }

        /** Update playback position/duration **/
        private function _mediaTimeHandler(event : HLSEvent) : void {
            _position = Math.max(0, event.mediatime.position);
            _duration = event.mediatime.duration;
        };

        /** playback complete handler **/
        private function _playbackComplete(event : HLSEvent) : void {
            signalComplete();
        }
    }
}