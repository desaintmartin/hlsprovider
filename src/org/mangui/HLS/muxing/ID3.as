package org.mangui.HLS.muxing {
   import flash.utils.ByteArray;

   public class ID3
   {
      public static const TAG:uint = 0x494433; /*0x49=I; 0x44=D; 0x33=3 */
      
      // header :
      // 0x49 0x44 0x33 0x.. | 0x.. 0x.. | 0x.. 0x.. 0x.. 0x.. |
      //  I    D    3        |           |  tag length         | tag 

      public static function length(data:ByteArray) : Number {
         var tag:uint = 0;
         var tagSize:uint = 0;
         try {
            var pos:Number = data.position;
            do {
              tag = data.readUnsignedInt() >> 8;
              if(tag == ID3.TAG) {
                // skip 16 bit
                data.readUnsignedShort();
                // retrieve tag length
                var byte1:uint = data.readUnsignedByte() & 0x7f;
                var byte2:uint = data.readUnsignedByte() & 0x7f;
                var byte3:uint = data.readUnsignedByte() & 0x7f;
                var byte4:uint = data.readUnsignedByte() & 0x7f;
                tagSize = (byte1 << 21) + (byte2 << 14) + (byte3 << 7) + byte4;

                data.position += tagSize;
              } else {
                data.position-=4;
                //Log.txt("ID3 len:"+ (data.position-pos));
                return (data.position-pos);
              }
            } while (true);
         } catch(e:Error)
         {
         }
         return 0;
      }
   }
}