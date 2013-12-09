package org.mangui.HLS.muxing {
   import flash.utils.ByteArray;

   public class ID3
   {
      public static const TAG:uint = 0x494433; /*0x49=I; 0x44=D; 0x33=3 */

      public static function length(data:ByteArray) : Number {
         var pos:Number = NaN;
         var tag:uint = 0;
         var i:Number = NaN;
         var tagSizeByte:uint = 0;
         var stream:ByteArray = data;
         var tagSize:uint = 0;
         try
         {
            pos = stream.position;
            tag = stream.readUnsignedInt() >> 8;
            if(tag == ID3.TAG)
            {
               stream.readUnsignedShort();
               i = 4;
               while(i > 0)
               {
                  tagSizeByte = stream.readUnsignedByte();
                  tagSizeByte = tagSizeByte & 127;
                  tagSize = tagSize + (tagSizeByte << (i-1) * 7);
                  i--;
               }
            }
            return tagSize > 0?tagSize + 10:-1;
         }
         catch(e:Error)
         {
         }
         return 0;
      }
   }
}