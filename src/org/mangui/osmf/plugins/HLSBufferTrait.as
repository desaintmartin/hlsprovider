package org.mangui.osmf.plugins
{
  import org.osmf.traits.BufferTrait;
  
  import org.mangui.HLS.HLS;
  import org.mangui.HLS.HLSEvent;
  import org.mangui.HLS.HLSStates;
  import org.mangui.HLS.utils.*;
	
	public class HLSBufferTrait extends BufferTrait
	{
	  private var _hls:HLS;
		public function HLSBufferTrait(hls:HLS)
		{
			super();
			_hls = hls;
			_hls.addEventListener(HLSEvent.STATE,_stateChangedHandler);
			
		}

    override public function get bufferLength():Number {
      return _hls.stream.bufferLength;
    }

		override protected function bufferingChangeStart(newBuffering:Boolean):void
		{
		  Log.txt("HLSBufferTrait:bufferingChangeStart:"+ newBuffering);
		}


   /** state changed handler **/
    private function _stateChangedHandler(event:HLSEvent):void {
      Log.txt("HLSBufferTrait:_stateChangedHandler:" + event.state);
      switch(event.state) {
         case HLSStates.BUFFERING:
            Log.txt("HLSBufferTrait:_stateChangedHandler:setBuffering(true)");
            setBuffering(true);
            break;
         default:
          Log.txt("HLSBufferTrait:_stateChangedHandler:setBuffering(false)");
          setBuffering(false);
          break;
        }
		}
	}
}
