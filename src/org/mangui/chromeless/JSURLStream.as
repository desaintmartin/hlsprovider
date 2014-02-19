package org.mangui.chromeless {
   import com.hurlant.util.Base64;
   import flash.external.ExternalInterface;
   import flash.events.Event;
   import flash.events.ProgressEvent;
   import flash.utils.ByteArray;
   import flash.net.URLStream;
   import org.mangui.HLS.utils.Log;
   import flash.net.URLRequest;

   public class JSURLStream extends URLStream {
      
      private var _connected:Boolean;
      private var _resource:ByteArray = new ByteArray();
      
      public function JSURLStream() {
         addEventListener(Event.OPEN, onOpen);
         super();
         // Connect calls to JS.
         if (ExternalInterface.available) {
            Log.info("add callback resourceLoaded");
            ExternalInterface.addCallback("resourceLoaded",_resourceLoaded);
         }
      }

    override public function get connected ():Boolean {
      return _connected;
    }

    override public function get bytesAvailable ():uint {
      return _resource.bytesAvailable;
    }

    override public function readByte():int {
      return _resource.readByte();
    }

    override public function readUnsignedShort():uint {
      return _resource.readUnsignedShort();
    }

    override public function readBytes(bytes:ByteArray, offset:uint = 0, length:uint = 0):void {
        _resource.readBytes(bytes, offset, length);
    }
    

    override public function close ():void {
    }
      
      override public function load(request : URLRequest) : void {
         Log.info("JSURLStream.load:"+request.url);
         if (ExternalInterface.available) {
            ExternalInterface.call("onRequestResource", request.url);
            dispatchEvent(new Event(Event.OPEN));
         } else {
            super.load(request);
         }
      }

      private function onOpen(event:Event):void {
         _connected = true;
      }

      private function _resourceLoaded(base64Resource:String):void {
         Log.info("resourceLoaded");
         _resource = Base64.decodeToByteArray(base64Resource);
         Log.info("resourceLoaded and decoded");
         this.dispatchEvent(new ProgressEvent(ProgressEvent.PROGRESS, false, false, _resource.bytesAvailable, _resource.bytesAvailable));
         this.dispatchEvent(new Event(Event.COMPLETE));
      }
   }
}
