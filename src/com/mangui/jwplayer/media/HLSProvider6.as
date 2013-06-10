package com.mangui.jwplayer.media {

    import com.longtailvideo.jwplayer.events.MediaEvent;
    import com.mangui.HLS.HLSEvent;
    import com.mangui.jwplayer.media.HLSProvider;
    import com.mangui.HLS.utils.Log;

    /** àdditional method needed for jwplayer6 **/
    public class HLSProvider6 extends HLSProvider {

      /** Array of quality levels **/
      private var _qualityLevels:Array;

      /** Forward QOS metrics on fragment load. **/
      override protected function _fragmentHandler(event:HLSEvent):void {
          _level = event.metrics.level;
          resize(_width,_height);

          // create quality level array and send event at first usage
          if (!_qualityLevels || _qualityLevels.length == 0) {
             if (_levels && _levels.length > 0) {
                _qualityLevels = [];
                
                for (var i:Number = 0; i < _levels.length; i++) {
                   _qualityLevels.push({label: _levels[i].width + 'p / ' + Math.round(_levels[i].bitrate/1024) + 'kb'});
                }
                if (_qualityLevels.length > 1) {
                   _qualityLevels.unshift({label: "auto"});
                }
                sendQualityEvent(MediaEvent.JWPLAYER_MEDIA_LEVELS, _qualityLevels, _currentQuality);
             }
          }
          // send meta data information
          sendMediaEvent(MediaEvent.JWPLAYER_MEDIA_META, { metadata: {
              bandwidth: Math.round(event.metrics.bandwidth/1024),
              droppedFrames: 0,
              currentLevel: (_level+1) +' of ' + _levels.length + ' (' + 
                  Math.round(_levels[_level].bitrate/1024) + 'kbps, ' + _levels[_level].width + 'px)',
              width: event.metrics.screenwidth,
              buffer: event.metrics.buffer
          }});
      };

      /** Change the current quality. **/
      override public function set currentQuality(quality:Number):void {
         _hls.setPlaybackQuality(quality-1);
         sendQualityEvent(MediaEvent.JWPLAYER_MEDIA_LEVEL_CHANGED, _qualityLevels, quality);
      }

      /** Return the list of quality levels. **/
      override public function get qualityLevels():Array {
         return _qualityLevels;
      }
    }
}
