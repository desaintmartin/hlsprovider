package org.mangui.osmf.plugins {
    import org.mangui.HLS.utils.Log;
    import org.osmf.traits.TimeTrait;
    import org.mangui.HLS.HLS;
    import org.mangui.HLS.HLSEvent;

    public class HLSTimeTrait extends TimeTrait {
        private var _hls : HLS;

        public function HLSTimeTrait(hls : HLS, duration : Number = 0) {
            Log.debug("HLSTimeTrait()");
            super(duration);
            setCurrentTime(0);
            _hls = hls;
            _hls.addEventListener(HLSEvent.MEDIA_TIME, _mediaTimeHandler);
            _hls.addEventListener(HLSEvent.PLAYBACK_COMPLETE, _playbackComplete);
        }

        override public function dispose() : void {
            Log.debug("HLSTimeTrait:dispose");
            _hls.removeEventListener(HLSEvent.MEDIA_TIME, _mediaTimeHandler);
            _hls.removeEventListener(HLSEvent.PLAYBACK_COMPLETE, _playbackComplete);
            super.dispose();
        }

        /** Update playback position/duration **/
        private function _mediaTimeHandler(event : HLSEvent) : void {
            var new_duration : Number = event.mediatime.duration;
            var new_position : Number = Math.max(0, event.mediatime.position);
            setDuration(new_duration);
            setCurrentTime(new_position);
        };

        /** playback complete handler **/
        private function _playbackComplete(event : HLSEvent) : void {
            signalComplete();
        }
    }
}