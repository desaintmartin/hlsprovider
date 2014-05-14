package org.mangui.osmf.plugins {
    import flash.display.Stage;

    import org.mangui.HLS.HLS;

    import flash.display.DisplayObject;
    import flash.events.Event;

    import org.mangui.HLS.utils.Log;
    import org.osmf.traits.DisplayObjectTrait;
    import org.osmf.media.videoClasses.VideoSurface;

    public class HLSDisplayObjectTrait extends DisplayObjectTrait {
        private var videoSurface : VideoSurface;
        private var _hls : HLS;

        public function HLSDisplayObjectTrait(hls : HLS, videoSurface : DisplayObject, mediaWidth : Number = 0, mediaHeight : Number = 0) {
            Log.debug("HLSDisplayObjectTrait()");
            _hls = hls;
            super(videoSurface, mediaWidth, mediaHeight);
            this.videoSurface = videoSurface as VideoSurface;

            if (this.videoSurface is VideoSurface)
                this.videoSurface.addEventListener(Event.ADDED_TO_STAGE, onStage);
        }

        override public function dispose() : void {
            Log.debug("HLSDisplayObjectTrait:dispose");
            videoSurface.removeEventListener(Event.ENTER_FRAME, onFrame);
            super.dispose();
        }

        private function onStage(event : Event) : void {
            _hls.stage = event.target.stage as Stage;
            videoSurface.removeEventListener(Event.ADDED_TO_STAGE, onStage);
            videoSurface.addEventListener(Event.ENTER_FRAME, onFrame);
        }

        private function onFrame(event : Event) : void {
            var newWidth : Number = videoSurface.videoWidth;
            var newHeight : Number = videoSurface.videoHeight;
            if (newWidth != 0 && newHeight != 0 && newWidth != mediaWidth && newHeight != mediaHeight) {
                // If there is no layout, set as no scale.
                if (videoSurface.width == 0 && videoSurface.height == 0) {
                    videoSurface.width = newWidth;
                    videoSurface.height = newHeight;
                }
                Log.info("HLSDisplayObjectTrait:setMediaSize(" + newWidth + "," + newHeight + ")");
                setMediaSize(newWidth, newHeight);
            }
            // videoSurface.removeEventListener(Event.ENTER_FRAME, onFrame);
        }
    }
}