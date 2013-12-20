package org.mangui.HLS {


    /** Identifiers for the different stream types. **/
    public class HLSMediatime {
      
      private var _position:Number;
      private var _duration:Number;
      private var _buffer:Number;
      
		public function HLSMediatime(position:Number,duration:Number, buffer:Number) {
         _position= position;
         _duration = duration;
         _buffer = buffer;
      }
      
      public function get position():Number {
         return _position;
      }

      public function get duration():Number {
         return _duration;
      }
		public function get buffer():Number {
         return _buffer;
      }
    }
}