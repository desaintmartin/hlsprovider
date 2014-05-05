package org.mangui.HLS.utils {
    /**
     * @author Gpontavic
     */
    public class PTS {
        /* normalize a given PTS value, relative to a given reference PTS value */
        public static function normalize(reference : Number, value : Number) : Number {
            var offset : Number;
            if (reference < value) {
                // - 2^33/90
                offset = -95443717;
            } else {
                // + 2^33/90
                offset = 95443717;
            }
            // 2^32 / 90
            while (!isNaN(reference) && (Math.abs(value - reference) > 47721858)) {
                value += offset;
            }
            return value;
        }
    }
}
