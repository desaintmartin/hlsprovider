package org.mangui.osmf.plugins
{
  import flash.net.NetStream;
  import flash.net.NetConnection;
  import org.osmf.net.NetLoader;
  import org.osmf.media.URLResource;
  
  import org.mangui.HLS.HLS;
  import org.mangui.HLS.utils.*;
	
	public class HLSNetLoader extends NetLoader
	{
	  private var _hls:HLS;
		public function HLSNetLoader(hls:HLS)
		{
			_hls = hls;
			super();
		}

		override protected function createNetStream(connection:NetConnection, resource:URLResource):NetStream
		{
			return _hls.stream;
		}
  }
}