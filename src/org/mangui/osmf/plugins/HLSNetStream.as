package org.mangui.osmf.plugins
{
	import flash.events.Event;
	import flash.events.NetStatusEvent;
	import flash.events.TimerEvent;
	import flash.net.NetConnection;
	import flash.net.NetStream;
	import flash.net.NetStreamPlayOptions;
	import flash.net.NetStreamPlayTransitions;
	import flash.utils.ByteArray;
	import flash.utils.Timer;

  import org.mangui.HLS.utils.*;
  import org.mangui.HLS.HLS;
	

	import org.osmf.media.MediaResourceBase;
	import org.osmf.media.URLResource;
	import org.osmf.net.NetClient;
	import org.osmf.net.NetStreamCodes;
	import org.osmf.net.NetStreamPlaybackDetailsRecorder;
	import org.osmf.net.StreamingURLResource;
	import org.osmf.utils.OSMFSettings;
	
	CONFIG::LOGGING 
	{	
		import org.osmf.logging.Log;
		import org.osmf.logging.Logger;
	}
	
	
	/**
	 * 
	 * @private
	 * 
	 * HTTPNetStream is a NetStream subclass which can accept input via the
	 * appendBytes method.  In general, the assumption is that a large media
	 * file is broken up into a number of smaller fragments.
	 * 
	 * There are two important aspects of working with an HTTPNetStream:
	 * 1) How to map a specific playback time to the media file fragment
	 * which holds the media for that time.
	 * 2) How to unmarshal the data from a media file fragment so that it can
	 * be fed to the NetStream as TCMessages. 
	 * 
	 * The former is the responsibility of HTTPStreamingIndexHandlerBase,
	 * the latter the responsibility of HTTPStreamingFileHandlerBase.
	 */	
	public class HLSNetStream extends NetStream
	{
	  private var _resource:URLResource;
		private var _playStreamName:String = null;
		private var _playStart:Number = -1;
		private var _playForDuration:Number = -1;
		private var _hls:HLS;
		private var _netstream:NetStream;
		/**
		 * Constructor.
		 * 
		 * @param connection The NetConnection to use.
		 * @param indexHandler Object which exposes the index, which maps
		 * playback times to media file fragments.
		 * @param fileHandler Object which canunmarshal the data from a
		 * media file fragment so that it can be fed to the NetStream as
		 * TCMessages.
		 *  
		 *  @langversion 3.0
		 *  @playerversion Flash 10
		 *  @playerversion AIR 1.5
		 *  @productversion OSMF 1.0
		 */
		public function HLSNetStream(connection:NetConnection, resource:URLResource = null)
		{
			_resource = resource;
			super(connection);
		}
		
		///////////////////////////////////////////////////////////////////////
		/// Public API overrides
		///////////////////////////////////////////////////////////////////////
		
		override public function set client(object:Object):void
		{
		  //Log.txt("HLSNetStream:set Client:" + object);
			super.client = object;
		}
		
		/**
		 * Plays the specified stream with respect to provided arguments.
		 */
		override public function play(...args):void 
		{
			if(args.length == 1) {
			  super.play(args[0]);
			  return;
			}
			//processPlayParameters(args);
			Log.txt("HLSNetStream:play initiated for [" + _playStreamName +"] with parameters ( start = " + _playStart.toString() + ", duration = " + _playForDuration.toString() +" ).");
			_hls = HLSLoaderBase.hls;
			_hls.NetStream = this;
			_hls.seek(0);
		}
		
		/**
		 * Pauses playback.
		 */
		override public function pause():void 
		{
		  Log.txt("HLSNetStream:pause");
			super.pause();
		}
		
		/**
		 * Resumes playback.
		 */
		override public function resume():void 
		{
		  Log.txt("HLSNetStream:resume");
			super.resume();
		}

		/**
		 * Plays the specified stream and supports dynamic switching and alternate audio streams. 
		 */
		override public function play2(param:NetStreamPlayOptions):void
		{
		  Log.txt("HLSNetStream:play2");
      super.play2(param);
		} 
		
		/**
		 * Seeks into the media stream for the specified offset in seconds.
		 */
		override public function seek(offset:Number):void
		{
		  Log.txt("HLSNetStream:seek");
			if(offset < 0)
			{
				offset = 0;		// FMS rule. Seek to <0 is same as seeking to zero.
			}
						
			dispatchEvent(
				new NetStatusEvent(
					NetStatusEvent.NET_STATUS, 
					false, 
					false, 
					{
						code:NetStreamCodes.NETSTREAM_SEEK_START, 
						level:"status"
					}
				)
			);
		}
		

		/**
		 * Closes the NetStream object.
		 */
		override public function close():void
		{
		  Log.txt("HLSNetStream:close");	  
			super.close();
		}
		
		/**
		 * @inheritDoc
		 */
		override public function set bufferTime(value:Number):void
		{
		  Log.txt("HLSNetStream:set Buffer Time:" + value);
			super.bufferTime = value;
		}
		
		/**
		 * @inheritDoc
		 */
		override public function get time():Number
		{
		  Log.txt("HLSNetStream:get time()");
		    return 0;
		}
		
		/**
		 * @private
		 * 
		 * Processes provided arguments to obtain the actual
		 * play parameters.
		 */
		private function processPlayParameters(args:Array):void
		{
			if (args.length < 1)
			{
				throw new Error("HTTPNetStream.play() requires at least one argument");
			}

			_playStreamName = args[0];
			_playStart = 0;
			if (args.length >= 2)
			{
				_playStart = Number(args[1]);
			}
			
			_playForDuration = -1;
			if (args.length >= 3)
			{
				_playForDuration = Number(args[2]);
			}
		}
			
		private static const HIGH_PRIORITY:int = int.MAX_VALUE;
		
		CONFIG::LOGGING
		{
			private static const logger:Logger = Log.getLogger("org.denivip.osmf.net.httpstreaming.hls.HTTPHLSNetStream") as Logger;
			private var previouslyLoggedState:String = null;
		}
	}
}
