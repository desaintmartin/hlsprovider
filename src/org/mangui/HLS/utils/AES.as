package org.mangui.HLS.utils {
  import com.hurlant.crypto.symmetric.AESKey;
  import com.hurlant.crypto.symmetric.CBCMode;
  import com.hurlant.crypto.symmetric.ICipher;
  import com.hurlant.crypto.symmetric.IPad;
  import com.hurlant.crypto.symmetric.IVMode;
  import com.hurlant.crypto.symmetric.NullPad;
  import com.hurlant.crypto.symmetric.PKCS5;
  
  import flash.utils.ByteArray;
  import flash.utils.Timer;
  import flash.events.Event;
  import flash.events.TimerEvent;
  
  /**
   * Contains Utility functions for Decryption
   */
  public class AES
  {
    private var _key:AESKey;
    private var _mode:ICipher;
    private var _iv:ByteArray;
    /* callback function upon read complete */
    private var _callback:Function;
    /** Timer for decrypting packets **/ 
    private var _timer:Timer;
    /** Byte data to be decrypt **/
    private var _data:ByteArray;
    /** Byte data to be decrypt **/
    private var _decrypteddata:ByteArray;
    /** loop counter to avoid blocking **/
    private static const COUNT:uint = 16*128;

    
    public function AES(key:ByteArray) {
      _key = new AESKey(key);
    }
    
    public function set pad(type:String):void {
      var pad:IPad;
      if (type == "pkcs7") {
        pad = new PKCS5;
      } else {
        pad = new NullPad;
      }
      _mode = new CBCMode(_key, pad);
      pad.setBlockSize(_mode.getBlockSize());
      // Reset IV if it was already set
      if (_iv) {
        this.iv = _iv;
      }
    }
    
    public function set iv(iv:ByteArray):void {
      _iv = iv;
      if (_mode) {
        if (_mode is IVMode) {
          var ivmode:IVMode = _mode as IVMode;
          ivmode.IV = iv;
        }
      }
    }
    
    public function decrypt(data:ByteArray):ByteArray {
      _mode.decrypt(data);
      return data;
    }

    public function decryptasync(data:ByteArray,callback:Function):void {
      _data = data;
      _callback = callback;
      _decrypteddata = new ByteArray();
      _timer = new Timer(0,0);
      _timer.addEventListener(TimerEvent.TIMER, _decryptData);
      _timer.start();
    }
    
    public function cancel():void {
      if(_timer) {
        _timer.stop();
        _timer = null;
      }
    }

    /** decrypt a small chunk of packets each time to avoid blocking **/
    private function _decryptData(e:Event):void {
      if(_data.bytesAvailable) {
        var dumpByteArray:ByteArray = new ByteArray();
        var bytes_to_read:Number
        if(_data.bytesAvailable <= 4096) {
          bytes_to_read = _data.bytesAvailable;
          this.pad = "pkcs7";
        } else {
          bytes_to_read= 4096;
        }
        _data.readBytes(dumpByteArray,0,bytes_to_read);
        // Save new IV from ciphertext
        var newIv:ByteArray = new ByteArray;
        dumpByteArray.position += (dumpByteArray.length-16);
        dumpByteArray.readBytes(newIv, 0, 16);
        dumpByteArray.position = 0;
        //Log.txt("before");
        _mode.decrypt(dumpByteArray);
        //Log.txt("after");
        _decrypteddata.writeBytes(dumpByteArray);
      }
      if (!_data.bytesAvailable) {
        _timer.stop();
        _timer = null;
        // callback
        _decrypteddata.position=0;
        _callback(_decrypteddata);
      } else {
        this.iv = newIv;
      }
    }
    
    public function destroy():void {
      _key = null;
      _mode = null;
    }
  }
}
