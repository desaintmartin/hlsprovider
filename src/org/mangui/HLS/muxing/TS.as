package org.mangui.HLS.muxing {
    import com.hurlant.util.Hex;

    import org.mangui.HLS.muxing.*;
    import org.mangui.HLS.utils.Log;
    import org.mangui.HLS.HLSAudioTrack;

    import flash.events.Event;
    import flash.events.EventDispatcher;
    import flash.events.TimerEvent;
    import flash.utils.ByteArray;
    import flash.utils.Timer;

    /** Representation of an MPEG transport stream. **/
    public class TS extends EventDispatcher implements Demuxer {
        /** read position **/
        private var _read_position : uint;
        /** is bytearray full ? **/
        private var _data_complete : Boolean;
        /** TS Sync byte. **/
        private static const SYNCBYTE : uint = 0x47;
        /** TS Packet size in byte. **/
        private static const PACKETSIZE : uint = 188;
        /** loop counter to avoid blocking **/
        private static const COUNT : uint = 5000;
        /** Packet ID of the PAT (is always 0). **/
        private static const _patId : Number = 0;
        /** Packet ID of the SDT (is always 17). **/
        private static const _sdtId : Number = 17;
        /** has PAT been parsed ? **/
        private var _patParsed : Boolean = false;
        /** has PMT been parsed ? **/
        private var _pmtParsed : Boolean = false;
        /** any TS packets before PMT ? **/
        private var _packetsBeforePMT : Boolean = false;
        /** Packet ID of the Program Map Table. **/
        private var _pmtId : Number = -1;
        /** Packet ID of the video stream. **/
        private var _avcId : Number = -1;
        /** Packet ID of selected audio stream. **/
        private static var _audioId : Number = -1;
        private var _audioIsAAC : Boolean = false;
        /** List with audio frames. **/
        private var _audioTags : Vector.<Tag> = new Vector.<Tag>();
        /** List with video frames. **/
        private var _videoTags : Vector.<Tag> = new Vector.<Tag>();
        /** Timer for reading packets **/
        private var _timer : Timer;
        /** Byte data to be read **/
        private var _data : ByteArray;
        /* callback functions for audio selection, and parsing progress/complete */
        private var _callback_audioselect : Function;
        private var _callback_progress : Function;
        private var _callback_complete : Function;
        /* current audio binary data */
        private static var _curAudioData : ByteArray = null;
        /* current video binary data */
        private static var _curVideoData : ByteArray = null;
        /* ADTS overflowing data */
        private static var _adtsOverflowData : ByteArray = null;
        /* current AVC Tag */
        private var _curVideoTag : Tag;

        public static function probe(data : ByteArray) : Boolean {
            var pos : Number = data.position;
            var len : Number = Math.min(data.bytesAvailable, 188 * 2);
            for (var i : Number = 0; i < len; i++) {
                if (data.readByte() == SYNCBYTE) {
                    // ensure that at least two consecutive TS start offset are found
                    if (data.bytesAvailable > 188) {
                        data.position = pos + i + 188;
                        if (data.readByte() == SYNCBYTE) {
                            data.position = pos + i;
                            return true;
                        } else {
                            data.position = pos + i + 1;
                        }
                    }
                }
            }
            data.position = pos;
            return false;
        }

        /** Transmux the M2TS file into an FLV file. **/
        public function TS(callback_audioselect : Function, callback_progress : Function, callback_complete : Function, discontinuity : Boolean) {
            // in case of discontinuity, flush any partially parsed audio/video PES packet
            if (discontinuity) {
                _curAudioData = null;
                _curVideoData = null;
                _adtsOverflowData = null;
            }
            _data = new ByteArray();
            _data_complete = false;
            _callback_audioselect = callback_audioselect;
            _callback_progress = callback_progress;
            _callback_complete = callback_complete;
            _read_position = 0;
            _timer = new Timer(0, 0);
            _timer.addEventListener(TimerEvent.TIMER, _readData);
        };

        /** append new TS data */
        public function append(data : ByteArray) : void {
            _data.position = _data.length;
            _data.writeBytes(data, data.position);
            _timer.start();
        }

        /** cancel demux operation */
        public function cancel() : void {
            _data = null;
            _timer.stop();
        }

        public function notifycomplete() : void {
            _data_complete = true;
        }

        /** Read a small chunk of packets each time to avoid blocking **/
        private function _readData(e : Event) : void {
            var i : uint = 0;
            _data.position = _read_position;
            while ((_data.bytesAvailable >= 188) && i < COUNT) {
                _readPacket();
                i++;
            }
            _read_position = _data.position;
            // finish reading TS fragment
            if (_data_complete && _data.bytesAvailable < 188) {
                // first check if TS parsing was successful
                if (_pmtParsed == false) {
                    Log.error("TS: no PMT found, report parsing complete");
                    _callback_complete();
                } else {
                    _timer.stop();
                    _parsingEnd();
                }
            }
        }

        /** notify end of parsing **/
        private function _parsingEnd() : void {
            // check whether last parsed audio PES is complete
            if (_curAudioData && _curAudioData.length > 14) {
                var pes : PES = new PES(TS._curAudioData, true);
                if (pes.len && (pes.data.length - pes.payload - pes.payload_len) >= 0) {
                    Log.debug2("TS: complete Audio PES found at end of segment, parse it");
                    // complete PES, parse and push into the queue
                    if (_audioIsAAC) {
                        _parseADTSPES(pes);
                    } else {
                        _parseMPEGPES(pes);
                    }
                    _curAudioData = null;
                } else {
                    Log.debug("TS: partial AAC PES at end of segment");
                    _curAudioData.position = _curAudioData.length;
                }
            }
            // check whether last parsed video PES is complete
            if (_curVideoData && _curVideoData.length > 14) {
                pes = new PES(TS._curVideoData, false);
                if (pes.len && (pes.data.length - pes.payload - pes.payload_len) >= 0) {
                    Log.debug2("TS: complete AVC PES found at end of segment, parse it");
                    // complete PES, parse and push into the queue
                    _parseAVCPES(pes);
                    _curVideoData = null;
                } else {
                    Log.debug("TS: partial AVC PES at end of segment");
                    _curVideoData.position = _curVideoData.length;
                }
            }
            Log.debug("TS: successfully parsed");
            Log.debug("TS: " + _videoTags.length + " video tags extracted");
            Log.debug("TS: " + _audioTags.length + " audio tags extracted");
            _callback_progress(_audioTags, _videoTags);
            _callback_complete();
        }

        /** parse ADTS audio PES packet **/
        private function _parseADTSPES(pes : PES) : void {
            var stamp : Number;
            // check if previous ADTS frame was overflowing.
            if (_adtsOverflowData && _adtsOverflowData.length) {
                // if overflowing, append remaining data from previous frame at the beginning of PES packet
                Log.debug("TS/AAC: append overflowing " + _adtsOverflowData.length + " bytes to beginning of new PES packet");
                var ba : ByteArray = new ByteArray();
                ba.writeBytes(_adtsOverflowData);
                ba.writeBytes(pes.data, pes.payload);
                pes.data = ba;
                pes.payload = 0;
                _adtsOverflowData = null;
            }
            if (isNaN(pes.pts)) {
                Log.warn("TS/AAC: no PTS info in this PES packet,discarding it");
                return;
            }
            // insert ADIF TAG at the beginning
            if (_audioTags.length == 0) {
                var adifTag : Tag = new Tag(Tag.AAC_HEADER, pes.pts, pes.dts, true);
                var adif : ByteArray = AAC.getADIF(pes.data, pes.payload);
                Log.debug("TS/AAC: insert ADIF TAG");
                adifTag.push(adif, 0, adif.length);
                _audioTags.push(adifTag);
            }
            // Store ADTS frames in array.
            var frames : Vector.<AudioFrame> = AAC.getFrames(pes.data, pes.payload);
            var frame : AudioFrame;
            for (var j : Number = 0; j < frames.length; j++) {
                frame = frames[j];
                // Increment the timestamp of subsequent frames.
                stamp = Math.round(pes.pts + j * 1024 * 1000 / frame.rate);
                var curAudioTag : Tag = new Tag(Tag.AAC_RAW, stamp, stamp, false);
                curAudioTag.push(pes.data, frame.start, frame.length);
                _audioTags.push(curAudioTag);
            }
            if (frame) {
                // check if last ADTS frame is overflowing on next PES packet
                var adts_overflow : Number = pes.data.length - (frame.start + frame.length);
                if (adts_overflow) {
                    _adtsOverflowData = new ByteArray();
                    _adtsOverflowData.writeBytes(pes.data, frame.start + frame.length);
                    Log.debug("TS/AAC:ADTS frame overflow:" + adts_overflow);
                }
            }
        };

        /** parse MPEG audio PES packet **/
        private function _parseMPEGPES(pes : PES) : void {
            if (isNaN(pes.pts)) {
                Log.warn("TS/MP3: no PTS info in this MP3 PES packet,discarding it");
                return;
            }
            var tag : Tag = new Tag(Tag.MP3_RAW, pes.pts, pes.dts, false);
            tag.push(pes.data, pes.payload, pes.data.length - pes.payload);
            _audioTags.push(tag);
        };

        /** parse AVC PES packet **/
        private function _parseAVCPES(pes : PES) : void {
            var sps : ByteArray;
            var pps : ByteArray;
            var sps_found : Boolean = false;
            var pps_found : Boolean = false;
            var frames : Vector.<VideoFrame> = AVC.getNALU(pes.data, pes.payload);
            // If there's no NAL unit, push all data in the previous tag, if any exists
            if (!frames.length) {
                if (_curVideoTag) {
                    _curVideoTag.push(pes.data, pes.payload, pes.data.length - pes.payload);
                } else {
                    Log.warn("TS: no NAL unit found in first (?) video PES packet, discarding data. possible segmentation issue ?");
                }
                return;
            }
            // If NAL units are not starting right at the beginning of the PES packet, push preceding data into the previous tag.
            var overflow : Number = frames[0].start - frames[0].header - pes.payload;
            if (overflow && _curVideoTag) {
                _curVideoTag.push(pes.data, pes.payload, overflow);
            }
            if (isNaN(pes.pts)) {
                Log.warn("TS: no PTS info in this AVC PES packet,discarding it");
                return;
            }
            _curVideoTag = new Tag(Tag.AVC_NALU, pes.pts, pes.dts, false);
            // Only push NAL units 1 to 5 into tag.
            for each (var frame : VideoFrame in frames) {
                if (frame.type < 6 ) {
                    _curVideoTag.push(pes.data, frame.start, frame.length);
                    // Unit type 5 indicates a keyframe.
                    if (frame.type == 5) {
                        _curVideoTag.keyframe = true;
                    }
                } else if (frame.type == 7) {
                    sps_found = true;
                    sps = new ByteArray();
                    pes.data.position = frame.start;
                    pes.data.readBytes(sps, 0, frame.length);
                } else if (frame.type == 8) {
                    pps_found = true;
                    pps = new ByteArray();
                    pes.data.position = frame.start;
                    pes.data.readBytes(pps, 0, frame.length);
                }
            }
            if (sps_found && pps_found) {
                var avcc : ByteArray = AVC.getAVCC(sps, pps);
                var avccTag : Tag = new Tag(Tag.AVC_HEADER, pes.pts, pes.dts, true);
                avccTag.push(avcc, 0, avcc.length);
                _videoTags.push(avccTag);
            }
            _videoTags.push(_curVideoTag);
        }

        /** Read TS packet. **/
        private function _readPacket() : void {
            // Each packet is 188 bytes.
            var todo : uint = TS.PACKETSIZE;
            // Sync byte.
            if (_data.readByte() != TS.SYNCBYTE) {
                var pos_start : Number = _data.position - 1;
                if (probe(_data) == true) {
                    var pos_end : Number = _data.position;
                    Log.warn("TS: lost sync between offsets:" + pos_start + "/" + pos_end);
                    if (Log.LOG_DEBUG2_ENABLED) {
                        var ba : ByteArray = new ByteArray();
                        _data.position = pos_start;
                        _data.readBytes(ba, 0, pos_end - pos_start);
                        Log.debug2("TS: lost sync dump:" + Hex.fromArray(ba));
                    }
                    _data.position = pos_end + 1;
                } else {
                    throw new Error("TS: Could not parse file: sync byte not found @ offset/len " + _data.position + "/" + _data.length);
                }
            }
            todo--;
            // Payload unit start indicator.
            var stt : uint = (_data.readUnsignedByte() & 64) >> 6;
            _data.position--;

            // Packet ID (last 13 bits of UI16).
            var pid : uint = _data.readUnsignedShort() & 8191;
            // Check for adaptation field.
            todo -= 2;
            var atf : uint = (_data.readByte() & 48) >> 4;
            todo--;
            // Read adaptation field if available.
            if (atf > 1) {
                // Length of adaptation field.
                var len : uint = _data.readUnsignedByte();
                todo--;
                // Random access indicator (keyframe).
                // var rai:uint = data.readUnsignedByte() & 64;
                _data.position += len;
                todo -= len;
                // Return if there's only adaptation field.
                if (atf == 2 || len == 183) {
                    _data.position += todo;
                    return;
                }
            }

            // Parse the PES, split by Packet ID.
            switch (pid) {
                case _patId:
                    todo -= _readPAT(stt);
                    if (_patParsed == false) {
                        _patParsed = true;
                        Log.debug("TS: PAT found.PMT PID:" + _pmtId);
                    }
                    break;
                case _pmtId:
                    if (_pmtParsed == false) {
                        Log.debug("TS: PMT found");
                        todo -= _readPMT(stt);
                        _pmtParsed = true;
                        // if PMT was not parsed before, and some unknown packets have been skipped in between,
                        // rewind to beginning of the stream, it helps recovering bad segmented content
                        // in theory there should be no A/V packets before PAT/PMT)
                        if (_packetsBeforePMT) {
                            Log.warn("TS: late PMT found, rewinding at beginning of TS");
                            _data.position = 0;
                            return;
                        }
                    }
                    break;
                case _audioId:
                    if (_pmtParsed == false) {
                        break;
                    }
                    if (stt) {
                        if (_curAudioData) {
                            if (_audioIsAAC) {
                                _parseADTSPES(new PES(_curAudioData, true));
                            } else {
                                _parseMPEGPES(new PES(_curAudioData, true));
                            }
                        }
                        _curAudioData = new ByteArray();
                    }
                    if (_curAudioData) {
                        _curAudioData.writeBytes(_data, _data.position, todo);
                    } else {
                        Log.warn("TS: Discarding audio packet with id " + pid);
                    }
                    break;
                case _avcId:
                    if (_pmtParsed == false) {
                        break;
                    }
                    if (stt) {
                        if (_curVideoData) {
                            _parseAVCPES(new PES(_curVideoData, false));
                        }
                        _curVideoData = new ByteArray();
                    }
                    if (_curVideoData) {
                        _curVideoData.writeBytes(_data, _data.position, todo);
                    } else {
                        Log.warn("TS: Discarding video packet with id " + pid + " bad TS segmentation ?");
                    }
                    break;
                case _sdtId:
                    break;
                default:
                    _packetsBeforePMT = true;
                    break;
            }
            // Jump to the next packet.
            _data.position += todo;
        };

        /** Read the Program Association Table. **/
        private function _readPAT(stt : uint) : Number {
            var pointerField : uint = 0;
            if (stt) {
                pointerField = _data.readUnsignedByte();
                // skip alignment padding
                _data.position += pointerField;
            }
            // skip table id
            _data.position += 1;
            // get section length
            var sectionLen : uint = _data.readUnsignedShort() & 0x3FF;
            // Check the section length for a single PMT.
            if (sectionLen > 13) {
                throw new Error("TS: Multiple PMT entries are not supported.");
            }
            // Grab the PMT ID.
            _data.position += 7;
            _pmtId = _data.readUnsignedShort() & 8191;
            return 13 + pointerField;
        };

        /** Read the Program Map Table. **/
        private function _readPMT(stt : uint) : Number {
            var pointerField : uint = 0;

            /** audio Track List */
            var audioList : Vector.<HLSAudioTrack> = new Vector.<HLSAudioTrack>();

            if (stt) {
                pointerField = _data.readUnsignedByte();
                // skip alignment padding
                _data.position += pointerField;
            }
            // skip table id
            _data.position += 1;
            // Check the section length for a single PMT.
            var len : uint = _data.readUnsignedShort() & 0x3FF;
            var read : uint = 13;
            _data.position += 7;
            // skip program info
            var pil : uint = _data.readUnsignedShort() & 0x3FF;
            _data.position += pil;
            read += pil;
            // Loop through the streams in the PMT.
            while (read < len) {
                // stream type
                var typ : uint = _data.readByte();
                // stream pid
                var sid : uint = _data.readUnsignedShort() & 0x1fff;
                if (typ == 0x0F) {
                    // ISO/IEC 13818-7 ADTS AAC (MPEG-2 lower bit-rate audio)
                    audioList.push(new HLSAudioTrack('TS/AAC ' + audioList.length, HLSAudioTrack.FROM_DEMUX, sid, (audioList.length==0)));
                } else if (typ == 0x1B) {
                    // ITU-T Rec. H.264 and ISO/IEC 14496-10 (lower bit-rate video)
                    _avcId = sid;
                    Log.debug("TS: Selected video PID: " + _avcId);
                } else if (typ == 0x03 || typ == 0x04) {
                    // ISO/IEC 11172-3 (MPEG-1 audio)
                    // or ISO/IEC 13818-3 (MPEG-2 halved sample rate audio)
                    audioList.push(new HLSAudioTrack('TS/MP3' + audioList.length, HLSAudioTrack.FROM_DEMUX, sid, (audioList.length==0)));
                }
                // es_info_length
                var sel : uint = _data.readUnsignedShort() & 0xFFF;
                _data.position += sel;
                // loop to next stream
                read += sel + 5;
            }
            
            if(audioList.length) {
                Log.debug("TS: Found " + audioList.length + " audio tracks");
            }
            // provide audio track List to audio select callback. this callback will return the selected audio track
            var audioPID : Number;
            var audioTrack : HLSAudioTrack = _callback_audioselect(audioList);
            if (audioTrack) {
                audioPID = audioTrack.id;
                _audioIsAAC = (audioTrack.title.indexOf("AAC") > -1);
                Log.debug("TS: selected audio PID: " + audioPID + " isAAC:" + _audioIsAAC);
            } else {
                audioPID = -1;
                Log.debug("TS: no audio selected");
            }
            // in case audio PID change, flush any partially parsed audio PES packet
            if (audioPID != _audioId) {
                _curAudioData = null;
                _adtsOverflowData = null;
                _audioId = audioPID;
            }
            return len + pointerField;
        };
    }
}