package org.mangui.osmf.plugins
{
  import flash.events.NetStatusEvent;
  import org.osmf.traits.SeekTrait;
  import org.osmf.traits.TimeTrait;
  import org.osmf.net.NetStreamCodes;
  
  import org.mangui.HLS.HLS;
  import org.mangui.HLS.HLSStates;
  import org.mangui.HLS.HLSEvent;
  import org.mangui.HLS.utils.*;
	
	public class HLSSeekTrait extends SeekTrait
	{
	  private var _hls:HLS;
		public function HLSSeekTrait(hls:HLS,timeTrait:TimeTrait)
		{
			super(timeTrait);
			_hls = hls;
			_hls.addEventListener(HLSEvent.STATE,_stateChangedHandler);
		}


		/**
		 * @private
		 * Communicates a <code>seeking</code> change to the media through the NetStream. 
		 * @param newSeeking New <code>seeking</code> value.
		 * @param time Time to seek to, in seconds.
		 */						
		override protected function seekingChangeStart(newSeeking:Boolean, time:Number):void {
		  Log.txt("HLSSeekTrait:seekingChangeStart:newSeeking/time:"+newSeeking+"/"+time);
		  _hls.stream.seek(time);
		  super.seekingChangeStart(newSeeking,time);
		}
		
		override protected function seekingChangeEnd(time:Number):void
		{
		  Log.txt("HLSSeekTrait:seekingChangeEnd:"+time);
			super.seekingChangeEnd(time);
		}

    override public function canSeekTo(time:Number):Boolean {
      Log.txt("HLSSeekTrait:canSeekTo:"+time);
      return super.canSeekTo(time);
    }
    
   /** state changed handler **/
    private function _stateChangedHandler(event:HLSEvent):void {
      Log.txt("HLSSeekTrait:_stateChangedHandler:" + event.state);
      if (seeking && event.state == HLSStates.PLAYING) {
        Log.txt("HLSSeekTrait:setSeeking(false);");
        setSeeking(false,timeTrait.currentTime);
      }
    }
  }
}