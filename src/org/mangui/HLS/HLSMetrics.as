package org.mangui.HLS {


    /** Identifiers for the different stream types. **/
    public class HLSMetrics {
      
      private var _level:Number;
      private var _bandwidth:Number;
      private var _width:Number;
      
		public function HLSMetrics(level:Number,bandwidth:Number, width:Number) {
         _level= level;
         _bandwidth = bandwidth;
         _width = width;
      }
      
      public function get level():Number {
         return _level;
      }

      public function get bandwidth():Number {
         return _bandwidth;
      }
		public function get screenwidth():Number {
         return _width;
      }
    }
}