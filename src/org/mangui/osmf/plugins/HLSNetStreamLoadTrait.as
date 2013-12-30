package org.mangui.osmf.plugins
{
  import org.osmf.net.NetStreamLoadTrait;
  import org.osmf.traits.LoaderBase;
  import org.osmf.media.MediaResourceBase;

  import org.mangui.HLS.HLS;
  import org.mangui.HLS.HLSEvent;

  public class HLSNetStreamLoadTrait extends NetStreamLoadTrait
  {
    private var _hls:HLS;
    private var _time_loaded:Number;
    private var _time_total:Number;

    public function HLSNetStreamLoadTrait(hls:HLS,duration:Number,loader:LoaderBase,resource:MediaResourceBase)
    {
      super(loader,resource);
      _hls = hls;
      _time_loaded = 0;
      _time_total = duration;
      super.netStream = _hls.stream;
      _hls.addEventListener(HLSEvent.MEDIA_TIME,_mediaTimeHandler);
    }


    override public function get bytesLoaded():Number
    {
        return _time_loaded;
    }

    override public function get bytesTotal():Number
    {
      return _time_total;
    }

    /**  **/
    private function _mediaTimeHandler(event:HLSEvent):void {
      var time_total:Number = Math.round(10*event.mediatime.duration)/10;
      var time_loaded:Number = Math.round(10*(event.mediatime.position+event.mediatime.buffer))/10;

      if(_time_total != time_total) {
	if (time_total < _time_loaded || time_total < 0) {
	  time_total = NaN;
	}
        _time_total = time_total;
        setBytesTotal(time_total);
      } 
      
      if(_time_loaded != time_loaded && time_loaded <= time_total) {
        _time_loaded = time_loaded;
        setBytesLoaded(time_loaded);
      }
    };
  }
}