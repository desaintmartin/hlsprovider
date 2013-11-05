 package org.mangui.osmf.plugins
{
	import flash.net.NetConnection;
	import flash.net.NetStream;
	import org.osmf.media.MediaResourceBase;
	import org.osmf.media.URLResource;
	import org.osmf.net.NetStreamLoadTrait;
	import org.osmf.net.httpstreaming.HTTPStreamingNetLoader;
	import org.osmf.traits.LoadState;
		
	public class HLSNetLoader extends HTTPStreamingNetLoader
	{
		override public function canHandleResource(resource:MediaResourceBase):Boolean
		{
			return true;
		}
		
		override protected function createNetStream(connection:NetConnection, resource:URLResource):NetStream
		{
			return new HLSNetStream(connection);
		}
		
		override protected function processFinishLoading(loadTrait:NetStreamLoadTrait):void
		{
			var resource:URLResource = loadTrait.resource as URLResource;
		  updateLoadTrait(loadTrait, LoadState.READY);
		 return;
	  }
	}
}
