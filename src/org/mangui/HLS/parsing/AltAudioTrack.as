package org.mangui.HLS.parsing {

   public class AltAudioTrack {

      private var _group_id:String;
      private var _lang:String;
      private var _name:String;
      private var _autoselect:Boolean;
      private var _default:Boolean;
      private var _url:String;


      /** Create the quality level. **/
      public function AltAudioTrack(alt_group_id:String, alt_lang:String, alt_name:String, alt_autoselect:Boolean, alt_default:Boolean, alt_url:String):void {
         _group_id = alt_group_id;
         _lang = alt_lang;
         _name = alt_name;
         _autoselect = alt_autoselect;
         _default = alt_default;
         _url = alt_url;
      };
   }
}
