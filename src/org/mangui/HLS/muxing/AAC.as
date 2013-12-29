package org.mangui.HLS.muxing {

    import flash.utils.ByteArray;
    import org.mangui.HLS.utils.Log;


    /** Constants and utilities for the AAC audio format. **/
    public class AAC {


        /** ADTS Syncword (111111111111), ID (MPEG4), layer (00) and protection_absent (1).**/
        private static const SYNCWORD:uint =  0xFFF1;
        /** ADTS Syncword with MPEG2 stream ID (used by e.g. Squeeze 7). **/
        private static const SYNCWORD_2:uint =  0xFFF9;
        /** ADTS Syncword with MPEG2 stream ID (used by e.g. Envivio 4Caster). **/
        private static const SYNCWORD_3:uint =  0xFFF8;
        /** ADTS/ADIF sample rates index. **/
        private static const RATES:Array = 
            [96000,88200,64000,48000,44100,32000,24000,22050,16000,12000,11025,8000,7350];
        /** ADIF profile index (ADTS doesn't have Null). **/
        //private static const PROFILES:Array = ['Null','Main','LC','SSR','LTP','SBR'];

        public function AAC(data:ByteArray,start_time:Number, callback:Function):void {
        var audioTags:Vector.<Tag> = new Vector.<Tag>();
        var adif:ByteArray = new ByteArray();
          /* parse AAC, convert Elementary Streams to TAG */
          var frames:Vector.<AudioFrame> = AAC.getFrames(data,0);
          adif = getADIF(data,0);
          var audioTag:Tag;
          var stamp:Number;
          var i:Number = 0;
          
          while(i < frames.length)
          {
             stamp = Math.round(1000*start_time+i*1024*1000 / frames[i].rate);
             audioTag = new Tag(Tag.AAC_RAW, stamp, stamp, false);
             if (i != frames.length-1) {
              audioTag.push(data,frames[i].start,frames[i].length);
            } else {
              audioTag.push(data,frames[i].start,data.length-frames[i].start);
            }
            audioTags.push(audioTag);
            i++;
          }
        callback(audioTags,new Vector.<Tag>(),adif, new ByteArray());

    };


    public static function probe(data:ByteArray):Boolean {
      var pos:Number = data.position;
      data.position+=ID3.length(data);
      var max_probe_pos:Number = Math.min(data.bytesAvailable,100);
         do { 
          // Check for ADTS header
          var short:uint = data.readUnsignedShort();
            if(short == SYNCWORD || short == SYNCWORD_2 || short == SYNCWORD_3) {
                return true;
              }
         } while(data.position < max_probe_pos);
      data.position = pos;
      return false;
    }


        /** Get ADIF header from ADTS stream. **/
        public static function getADIF(adts:ByteArray,position:Number=0):ByteArray {
            adts.position = position;
            var short:uint;
            // we need at least 6 bytes, 2 for sync word, 4 for frame length 
            while((adts.bytesAvailable > 5) && (short != SYNCWORD) && (short != SYNCWORD_2) && (short != SYNCWORD_3)) {
              short = adts.readUnsignedShort();
            } 
            
            if(short == SYNCWORD || short == SYNCWORD_2 || short == SYNCWORD_3) {
                var profile:uint = (adts.readByte() & 0xF0) >> 6;
                // Correcting zero-index of ADIF and Flash playing only LC/HE.
                if (profile > 3) { profile = 5; } else { profile = 2; }
                adts.position--;
                var srate:uint = (adts.readByte() & 0x3C) >> 2;
                adts.position--;
                var channels:uint = (adts.readShort() & 0x01C0) >> 6;
            } else {
                throw new Error("Stream did not start with ADTS header.");
                return null;
            }
            // 5 bits profile + 4 bits samplerate + 4 bits channels.
            var adif:ByteArray = new ByteArray();
            adif.writeByte((profile << 3) + (srate >> 1));
            adif.writeByte((srate << 7) + (channels << 3));
            // Log.txt('AAC: '+PROFILES[profile] + ', '+RATES[srate]+' Hz '+ channels +' channel(s)');
            // Reset position and return adif.
            adts.position -= 4;
            adif.position = 0;
            return adif;
        };


        /** Get a list with AAC frames from ADTS stream. **/
        public static function getFrames(adts:ByteArray,position:Number=0):Vector.<AudioFrame> {
            var frames:Vector.<AudioFrame> = new Vector.<AudioFrame>();
            var frame_start:uint;
            var frame_length:uint;
            position += ID3.length(adts);
            // Get raw AAC frames from audio stream.
            adts.position = position;
            var samplerate:uint;
            // we need at least 6 bytes, 2 for sync word, 4 for frame length
            while(adts.bytesAvailable > 5) {
                // Check for ADTS header
                var short:uint = adts.readUnsignedShort();
                if(short == SYNCWORD || short == SYNCWORD_2 || short == SYNCWORD_3) {
                    // Store samplerate for ofsetting timestamps.
                    if(!samplerate) {
                        samplerate = RATES[(adts.readByte() & 0x3C) >> 2];
                        adts.position--;
                    }
                    // Store raw AAC preceding this header.
                    if(frame_start) {
                        frames.push(new AudioFrame(frame_start, frame_length, samplerate));
                    }
                    if(short == SYNCWORD_3) {
                       // ADTS header is 9 bytes.
                       frame_length = ((adts.readUnsignedInt() & 0x0003FFE0) >> 5) - 9;
                       frame_start = adts.position + 3;
                       adts.position += frame_length + 3;
                  } else {
                       // ADTS header is 7 bytes.
                       frame_length = ((adts.readUnsignedInt() & 0x0003FFE0) >> 5) - 7;
                       frame_start = adts.position + 1;
                       adts.position += frame_length + 1;
                  }
                } else {
                    Log.txt("no ADTS header found, probing...");
                    adts.position--;
                }
            }
            // Write raw AAC after last header.
            if(frame_start) {
                frames.push(new AudioFrame(frame_start, frame_length, samplerate));
                // Log.txt("AAC: "+frames.length+" ADTS frames");
            } else {
              Log.txt("No ADTS headers found in this stream.");
            }
            adts.position = position;
            return frames;
        };


    }


}