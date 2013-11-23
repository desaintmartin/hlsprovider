package org.mangui.osmf.plugins
{
  import org.osmf.traits.PlayTrait;
  import org.osmf.traits.PlayState;
  import org.mangui.HLS.HLS;
  import org.mangui.HLS.utils.*;
	
	public class HLSPlayTrait extends PlayTrait
	{
	  private var _hls:HLS;
	  private var streamStarted:Boolean = false;
		public function HLSPlayTrait(hls:HLS)
		{
			super();
			_hls = hls;
		}

    override protected function playStateChangeStart(newPlayState:String):void {
      Log.txt("HLSPlayTrait:playStateChangeStart:"+newPlayState);
      switch(newPlayState) {
        case PlayState.PLAYING:
          if(streamStarted == false) {
            _hls.stream.seek(0);
            streamStarted = true;
          } else {
          _hls.stream.resume();
          }
          break;
        case PlayState.PAUSED:
        case PlayState.STOPPED:
          _hls.stream.pause();
          break;        
      }
    }
	}
}
