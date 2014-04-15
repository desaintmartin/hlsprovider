package org.mangui.HLS.muxing {
    import flash.utils.ByteArray;

    public interface Demuxer {
        function append(data : ByteArray) : void;
        function notifycomplete() : void;
        function cancel() : void;
    }
}
