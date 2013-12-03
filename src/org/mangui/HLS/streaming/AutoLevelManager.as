package org.mangui.HLS.streaming {


    import org.mangui.HLS.*;
    import org.mangui.HLS.utils.Log;

    /** Class that manages auto level selection **/
    public class AutoLevelManager {

        /** Reference to the HLS controller. **/
        private var _hls:HLS;
        /** Reference to the manifest levels. **/
        private var _levels:Array;
        /** switch up threshold **/
        private var _switchup:Array = null;
        /** switch down threshold **/
        private var _switchdown:Array = null;

        /** Create the loader. **/
        public function AutoLevelManager(hls:HLS):void {
            _hls = hls;
            _hls.addEventListener(HLSEvent.MANIFEST_LOADED, _manifestLoadedHandler);
        };

        /** Store the manifest data. **/
        private function _manifestLoadedHandler(event:HLSEvent):void {
            _levels = event.levels;
            _initlevelswitch();
        };

        /* initialize level switching heuristic tables */
        private function _initlevelswitch():void {
          var i:Number;
          var maxswitchup:Number=0;
          var minswitchdwown:Number=Number.MAX_VALUE;
          _switchup = new Array(_levels.length);
          _switchdown = new Array(_levels.length);

          for(i=0 ; i < _levels.length-1; i++) {
             _switchup[i] = (_levels[i+1].bitrate - _levels[i].bitrate) / _levels[i].bitrate;
             maxswitchup = Math.max(maxswitchup,_switchup[i]);
          }
          for(i=0 ; i < _levels.length-1; i++) {
             _switchup[i] = Math.min(maxswitchup,2*_switchup[i]);
             //Log.txt("_switchup["+i+"]="+_switchup[i]);
          }


          for(i = 1; i < _levels.length; i++) {
             _switchdown[i] = (_levels[i].bitrate - _levels[i-1].bitrate) / _levels[i].bitrate;
             minswitchdwown  =Math.min(minswitchdwown,_switchdown[i]);
          }
          for(i = 1; i < _levels.length; i++) {
             _switchdown[i] = Math.max(2*minswitchdwown,_switchdown[i]);
             //Log.txt("_switchdown["+i+"]="+_switchdown[i]);
          }
        }

        /** Update the quality level for the next fragment load. **/
        public function getnextlevel(current_level:Number, buffer:Number, last_segment_duration:Number, last_fetch_duration:Number, last_bandwidth:Number):Number {
         var i:Number;

            var level:Number = -1;
            // Select the lowest non-audio level.
            for(i = 0; i < _levels.length; i++) {
                if(!_levels[i].audio) {
                    level = i;
                    break;
                }
            }
            if(level == -1) {
                Log.txt("No other quality levels are available");
                return -1;
            }
            if(last_fetch_duration == 0 || last_segment_duration == 0) {
               return 0;
            }
            var fetchratio:Number = last_segment_duration/last_fetch_duration;
            var bufferratio:Number = 1000*buffer/last_segment_duration;
            //Log.txt("fetchratio:" + fetchratio);
            //Log.txt("bufferratio:" + bufferratio);

            /* to switch level up :
              fetchratio should be greater than switch up condition,
               but also, when switching levels, we might have to load two fragments :
                - first one for PTS analysis,
                - second one for NetStream injection
               the condition (bufferratio > 2*_levels[_level+1].bitrate/_last_bandwidth)
               ensures that buffer time is bigger than than the time to download 2 fragments from current_level+1, if we keep same bandwidth
            */
            if((current_level < _levels.length-1) && (fetchratio > (1+_switchup[current_level])) && (bufferratio > 2*_levels[current_level+1].bitrate/last_bandwidth)) {
               //Log.txt("fetchratio:> 1+_switchup[_level]="+(1+_switchup[current_level]));
               //Log.txt("switch to level " + (current_level+1));
                  //level up
                  return (current_level+1);
            }
            /* to switch level down :
              fetchratio should be smaller than switch down condition,
               or buffer time is too small to retrieve one fragment with current level
            */

            else if(current_level > 0 &&((fetchratio < (1-_switchdown[current_level])) || (bufferratio < 1)) ) {
                  //Log.txt("bufferratio < 2 || fetchratio: < 1-_switchdown[_level]="+(1-_switchdown[_level]));
                  /* find suitable level matching current bandwidth, starting from current level
                     when switching level down, we also need to consider that we might need to load two fragments.
                     the condition (bufferratio > 2*_levels[j].bitrate/_last_bandwidth)
                    ensures that buffer time is bigger than than the time to download 2 fragments from level j, if we keep same bandwidth
                  */
                  for(var j:Number = current_level-1; j > 0; j--) {
                     if( _levels[j].bitrate <= last_bandwidth && (bufferratio > 2*_levels[j].bitrate/last_bandwidth)) {
                          Log.txt("switch to level " + j);
                          return j;
                      }
                  }
                  Log.txt("switch to level 0");
                  return 0;
               }
            return current_level;
        }
    }
}