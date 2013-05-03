package com.mangui.HLS.parsing {


    /** HLS streaming chunk. **/
    public class Fragment {


        /** Duration of this chunk. **/
        public var duration:Number;
        /** Starttime of this chunk. **/
        public var start:Number;
        /** sequence number of this chunk. **/
        public var seqnum:Number;
        /** URL to this chunk. **/
        public var url:String;


        /** Create the fragment. **/
        public function Fragment(url:String, duration:Number, seqnum:Number,start:Number=0):void {
            this.duration = duration;
            this.url = url;
            this.seqnum = seqnum;
            this.start = start;
        };
    }


}