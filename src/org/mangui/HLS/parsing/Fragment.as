package org.mangui.HLS.parsing {

//import org.mangui.HLS.utils.Log;

    /** HLS streaming chunk. **/
    public class Fragment {


        /** Duration of this chunk. **/
        public var duration:Number;
        /** Start time of this chunk. **/
        public var start_time:Number;
        /** Start PTS of this chunk. **/
        public var start_pts:Number;
        /** computed Start PTS of this chunk. **/
        public var start_pts_computed:Number;
        /** sequence number of this chunk. **/
        public var seqnum:Number;
        /** URL to this chunk. **/
        public var url:String;
        /** continuity index of this chunk. **/
        public var continuity:Number;
        /** program date of this chunk. **/
        public var program_date:Number;


        /** Create the fragment. **/
        public function Fragment(url:String, duration:Number, seqnum:Number,start_time:Number,continuity:Number,program_date:Number):void {
            this.duration = duration;
            this.url = url;
            this.seqnum = seqnum;
            this.start_time = start_time;
            this.continuity = continuity;
            this.program_date = program_date;
            this.start_pts = Number.NEGATIVE_INFINITY;
            this.start_pts_computed = Number.NEGATIVE_INFINITY;
            //Log.txt("Frag["+seqnum+"]:duration/start_time,cc="+duration+","+start_time+","+continuity);
        };
    }


}