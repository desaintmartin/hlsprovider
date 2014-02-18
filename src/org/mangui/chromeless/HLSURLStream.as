package org.mangui.chromeless {
   import org.mangui.HLS.utils.Log;
   import flash.net.URLRequest;
   import flash.net.URLStream;

   /**
    * @author Gpontavic
    */
   public class HLSURLStream extends URLStream {
      public function HLSURLStream() {
         super();
      }
      
      override public function load(request : URLRequest) : void {
         Log.debug("HLSURLStream.load:"+request.url);
         super.load(request);
      }
   }
}
