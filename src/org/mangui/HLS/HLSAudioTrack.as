package org.mangui.HLS {


    /** Audio Track identifier **/
    public class HLSAudioTrack {
      
      private var _title:String;
      private var _id:Number;

      public function HLSAudioTrack(title:String,id:Number) {
         _title= title;
         _id = id;
      }
      
      public function get title():String {
         return _title;
      }

      public function get id():Number {
         return _id;
      }
    }
}