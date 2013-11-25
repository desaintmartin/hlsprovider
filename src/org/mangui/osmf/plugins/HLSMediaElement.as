package org.mangui.osmf.plugins
{
  import flash.net.NetStream;
  import flash.net.NetConnection;
  import flash.media.Video;
  import flash.events.NetStatusEvent;
  

  import org.mangui.HLS.HLS;
  import org.mangui.HLS.utils.*;


  import org.osmf.events.MediaError;
  import org.osmf.events.MediaErrorEvent;
  import org.osmf.events.MediaErrorCodes;
  import org.osmf.media.LoadableElementBase;
  import org.osmf.traits.MediaTraitType;
  import org.osmf.media.videoClasses.VideoSurface;
  import org.osmf.media.MediaResourceBase;
  import org.osmf.traits.AudioTrait;
  import org.osmf.traits.BufferTrait;
  import org.osmf.traits.DynamicStreamTrait;
  import org.osmf.traits.LoadState;
  import org.osmf.traits.LoadTrait;
  import org.osmf.traits.LoaderBase;
  import org.osmf.traits.MediaTraitBase;
  import org.osmf.traits.MediaTraitType;
  import org.osmf.traits.PlayTrait;
  import org.osmf.traits.SeekTrait;
  import org.osmf.traits.TimeTrait;
  import org.osmf.utils.OSMFSettings;
  import org.osmf.net.NetLoader;
  import org.osmf.net.NetStreamAudioTrait;
  import org.osmf.net.NetStreamLoadTrait;

  public class HLSMediaElement extends LoadableElementBase
  {
    private var _hls:HLS;
    private var _stream:NetStream;
    private var _defaultduration:Number;
    private var videoSurface:VideoSurface;
    private var _smoothing:Boolean;
    private var _deblocking:int;
    private var _loader:LoaderBase;
    private var _loadTrait:NetStreamLoadTrait;

      public function HLSMediaElement(resource:MediaResourceBase, hls:HLS, duration:Number) {
        _hls = hls;
        _defaultduration = duration;
        super(resource, new HLSNetLoader(hls));
        initTraits();
      }

    protected function createVideo():Video
    {
      return new Video();
    }

    override protected function createLoadTrait(resource:MediaResourceBase, loader:LoaderBase):LoadTrait
    {
      if(_loadTrait == null) {
        _loadTrait = new NetStreamLoadTrait(loader, resource);
        _loadTrait.netStream = _hls.stream;
      }
       return _loadTrait;
    }

    /**
     * Specifies whether the video should be smoothed (interpolated) when it is scaled.
     * For smoothing to work, the runtime must be in high-quality mode (the default).
     * The default value is false (no smoothing).  Set this property to true to take
     * advantage of mipmapping image optimization.
     *
     * @see flash.media.Video
     *
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion OSMF 1.0
    **/
    public function get smoothing():Boolean
    {
      return _smoothing;
    }

    public function set smoothing(value:Boolean):void
    {
      _smoothing = value;
      if (videoSurface != null)
      {
        videoSurface.smoothing = value;
      }
    }

    private function initTraits():void
    {
      _stream = _hls.stream;

      // Set the video's dimensions so that it doesn't appear at the wrong size.
      // We'll set the correct dimensions once the metadata is loaded.  (FM-206)
      videoSurface = new VideoSurface(
                      OSMFSettings.enableStageVideo && OSMFSettings.supportsStageVideo,
                      createVideo);
      videoSurface.smoothing = true;
      videoSurface.deblocking = 1;
      videoSurface.width = videoSurface.height = 0;
      videoSurface.attachNetStream(_stream);
      
      //Log.txt("HLSMediaElement:audioTrait");
      var audioTrait:AudioTrait = new NetStreamAudioTrait(_stream);
      addTrait(MediaTraitType.AUDIO, audioTrait);

      //Log.txt("HLSMediaElement:BufferTrait");
      var bufferTrait:BufferTrait = new HLSBufferTrait(_hls);
      addTrait(MediaTraitType.BUFFER, bufferTrait);

      //Log.txt("HLSMediaElement:TimeTrait");
      var timeTrait:TimeTrait = new HLSTimeTrait(_hls,_defaultduration);
      addTrait(MediaTraitType.TIME, timeTrait);

      //Log.txt("HLSMediaElement:DisplayObjectTrait");
      var displayObjectTrait:HLSDisplayObjectTrait = new HLSDisplayObjectTrait(videoSurface, NaN, NaN);
      addTrait(MediaTraitType.DISPLAY_OBJECT, displayObjectTrait);

      //Log.txt("HLSMediaElement:PlayTrait");
      var playTrait:PlayTrait = new HLSPlayTrait(_hls);
      addTrait(MediaTraitType.PLAY, playTrait);

      // setup seek trait
      //Log.txt("HLSMediaElement:SeekTrait");
      var seekTrait:SeekTrait = new HLSSeekTrait(_hls, timeTrait);
      addTrait(MediaTraitType.SEEK, seekTrait);

      // setup dynamic resource trait
      //Log.txt("HLSMediaElement:DynamicStreamingResource");
      //var dsResource:DynamicStreamingResource = new NetStreamDynamicStreamTrait(_stream, loadTrait.switchManager, dsResource);
      //addTrait(MediaTraitType.DYNAMIC_STREAM, dsTrait);
      
      //setup drm trait
      //addTrait(MediaTraitType.DRM, drmTrait);

      //setup DVR trait
      //addTrait(MediaTraitType.DVR, dvrTrait);

      //setup alternative audio trait
      //addTrait(MediaTraitType.ALTERNATIVE_AUDIO, altAudioTrait);
    }
  }
}