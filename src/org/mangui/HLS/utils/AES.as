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
    /** chunk size to avoid blocking **/
    private static const CHUNK_SIZE:uint = 4096;

    
    public function AES(key:ByteArray,iv:ByteArray) {
      var pad:IPad = new PKCS5;
      _key = new AESKey(key);
      _mode = new CBCMode(_key, pad);
      pad.setBlockSize(_mode.getBlockSize());
      _iv = iv;
      if (_mode is IVMode) {
        var ivmode:IVMode = _mode as IVMode;
        ivmode.IV = iv;
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
        var newIv:ByteArray;
        var bytes_to_read:Number
        var pad:IPad;
        if(_data.bytesAvailable <= CHUNK_SIZE) {
          bytes_to_read = _data.bytesAvailable;
          pad = new PKCS5;
          _data.readBytes(dumpByteArray,0,bytes_to_read);
        } else {
          bytes_to_read= CHUNK_SIZE;
          pad = new NullPad;
          _data.readBytes(dumpByteArray,0,CHUNK_SIZE);
          newIv = new ByteArray;
          // Save new IV from ciphertext
          dumpByteArray.position += (dumpByteArray.length-16);
          dumpByteArray.readBytes(newIv, 0, 16);
        }
        dumpByteArray.position = 0;
        //Log.txt("before decrypt");
        _mode = new CBCMode(_key, pad);
        pad.setBlockSize(_mode.getBlockSize());
        if (_mode is IVMode) {
          var ivmode:IVMode = _mode as IVMode;
          ivmode.IV = _iv;
        }
        _mode.decrypt(dumpByteArray);
        //Log.txt("after decrypt");
        _decrypteddata.writeBytes(dumpByteArray);
        
        // switch IV to new one in case more bytes are available
        if(newIv) {
          _iv = newIv;
        }
      } else {
        _timer.stop();
        _timer = null;
        // callback
        _decrypteddata.position=0;
        _callback(_decrypteddata);
      }
    }
    
    public function destroy():void {
      _key = null;
      _mode = null;
    }
  }
}
