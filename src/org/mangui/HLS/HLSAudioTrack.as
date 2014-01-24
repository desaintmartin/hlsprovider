package org.mangui.HLS {


    /** Audio Track identifier **/
    public class HLSAudioTrack {
      
      public static const FROM_DEMUX:Number = 0;
      public static const FROM_PLAYLIST:Number = 1;
      
      private var _title:String;
      private var _id:Number;
      private var _source:Number;
      private var _isDefault:Boolean;

      public function HLSAudioTrack(title:String,source:Number,id:Number,isDefault:Boolean) {
         _title= title;
         _source = source;
         _id = id;
         _isDefault = isDefault;
      }
      
      public function get title():String {
         return _title;
      }

      public function get id():Number {
         return _id;
      }

      public function get source():Number {
         return _source;
      }

      public function get isDefault():Boolean{
         return _isDefault;
      }

    }
}