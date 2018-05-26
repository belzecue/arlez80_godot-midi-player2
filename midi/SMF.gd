"""
	SMF reader by Yui Kinomoto @arlez80
"""

var last_event_type

const control_number_modulation = 0x01
const control_number_volume = 0x07
const control_number_pan = 0x0A
const control_number_expression = 0x0B

enum MIDIEventType {
	note_off,					# 8*
	note_on,					# 9*
	polyphonic_key_pressure,	# A*
	control_change,				# B*
	program_change,				# C*
	channel_pressure,			# D*
	pitch_bend,					# E*
	system_event,				# F*
}

enum MIDISystemEventType {
	sys_ex,					
	divided_sys_ex,			
	text_event,				# 01
	copyright,				# 02
	track_name,				# 03
	instrument_name,		# 04
	lyric,					# 05
	marker,					# 06
	cue_point,				# 07
	midi_channel_prefix,	# 20
	end_of_track,			# 2F

	set_tempo,				# 51

	smpte_offset,			# 54
	beat,					# 58
	key,					# 59

	unknown,				
}

"""
	ファイルから読み込み
	@param	path	File path
	@return	smf
"""
func read_file( path ):
	var f = File.new( )

	if not f.file_exists( path ):
		print( "file %s is not found" % path )
		breakpoint

	f.open( path, f.READ )
	var stream = StreamPeerBuffer.new( )
	stream.set_data_array( f.get_buffer( f.get_len( ) ) )
	stream.big_endian = true
	f.close( )

	return self.read( stream )

"""
	配列から読み込み
	@param	data	PoolByteArray
	@return	smf
"""
func read_data( data ):
	var stream = StreamPeerBuffer.new( )
	stream.set_data_array( data )
	stream.big_endian = true
	return self.read( stream )

"""
	読み込み
	@param	input
	@return	smf
"""
func read( input ):
	var header = self.read_chunk_data( input )
	if header.id != "MThd" and header.size != 6:
		print( "MThd header expected" )
		breakpoint

	var format_type = header.stream.get_u16( )
	var track_count = header.stream.get_u16( )
	var timebase = header.stream.get_u16( )

	var tracks = []
	for i in range( 0, track_count ):
		tracks.append( self.read_track( input, i ) )

	return {
		"format_type": format_type,
		"track_count": track_count,
		"timebase": timebase,
		"tracks": tracks,
	}

"""
	トラックの読み込み
	@param	input
	@param	track_number	トラックナンバー
	@return	track data
"""
func read_track( input, track_number ):
	var track_chunk = self.read_chunk_data( input )
	if track_chunk.id != "MTrk":
		print( "Unknown chunk: " + track_chunk.id )
		breakpoint

	var stream = track_chunk.stream
	var time = 0
	var events = []

	while 0 < stream.get_available_bytes( ):
		var delta_time = self.read_variable_int( stream )
		time += delta_time
		var event_type_byte = stream.get_u8( )

		var event
		if self.is_system_event( event_type_byte ):
			event = {
				"type": MIDIEventType.system_event,
				"args": self.read_system_event( stream, event_type_byte )
			}
		else:
			event = self.read_event( stream, event_type_byte )

			if ( event_type_byte & 0x80 ) == 0:
				event_type_byte = self.last_event_type

		events.append({
			"time": time,
			"channel_number": event_type_byte & 0x0f,
			"event": event,
		})

	return {
		"track_number": track_number,
		"events": events,
	}

"""
	システムイベントか否かを返す
	@param	b	event type
	@return	システムイベントならtrueを返す
"""
func is_system_event( b ):
	return ( b & 0xf0 ) == 0xf0

"""
	システムイベントの読み込み
"""
func read_system_event( stream, event_type_byte ):
	if event_type_byte == 0xff:
		var meta_type = stream.get_u8( )
		var size = self.read_variable_int( stream )

		if meta_type == 0x01:
			return { "type": MIDISystemEventType.text_event, "text": self.read_string( stream, size ) }
		elif meta_type == 0x02:
			return { "type": MIDISystemEventType.copyright, "text": self.read_string( stream, size ) }
		elif meta_type == 0x03:
			return { "type": MIDISystemEventType.track_name, "text": self.read_string( stream, size ) }
		elif meta_type == 0x04:
			return { "type": MIDISystemEventType.instrument_name, "text": self.read_string( stream, size ) }
		elif meta_type == 0x05:
			return { "type": MIDISystemEventType.lyric, "text": self.read_string( stream, size ) }
		elif meta_type == 0x06:
			return { "type": MIDISystemEventType.marker, "text": self.read_string( stream, size ) }
		elif meta_type == 0x07:
			return { "type": MIDISystemEventType.cue_point, "text": self.read_string( stream, size ) }
		elif meta_type == 0x20:
			if size != 1:
				print( "MIDI Channel Prefix length is not 1" )
				breakpoint
			return { "type": MIDISystemEventType.midi_channel_prefix, "prefix": stream.get_u8( ) }
		elif meta_type == 0x2F:
			if size != 0:
				print( "End of track with unknown data" )
				breakpoint
			return { "type": MIDISystemEventType.end_of_track }
		elif meta_type == 0x51:
			if size != 3:
				print( "Tempo length is not 3" )
				breakpoint
			# beat per microseconds
			var bpm = stream.get_u8( ) << 16
			bpm |= stream.get_u8( ) << 8
			bpm |= stream.get_u8( )
			return { "type": MIDISystemEventType.set_tempo, "bpm": bpm }
		elif meta_type == 0x54:
			if size != 5:
				print( "SMPTE length is not 5" )
				breakpoint
			var hr = stream.get_u8( )
			var mm = stream.get_u8( )
			var se = stream.get_u8( )
			var fr = stream.get_u8( )
			var ff = stream.get_u8( )
			return {
				"type": MIDISystemEventType.smpte_offset,
				"hr": hr,
				"mm": mm,
				"se": se,
				"fr": fr,
				"ff": ff,
			}
		elif meta_type == 0x58:
			if size != 4:
				print( "Beat length is not 4" )
				breakpoint
			var numerator = stream.get_u8( )
			var denominator = stream.get_u8( )
			var clock = stream.get_u8( )
			var beat32 = stream.get_u8( )
			return {
				"type": MIDISystemEventType.beat,
				"numerator": numerator,
				"denominator": denominator,
				"clock": clock,
				"beat32": beat32,
			}
		elif meta_type == 0x59:
			if size != 2:
				print( "Key length is not 2" )
				breakpoint
			var sf = stream.get_u8( )
			var minor = stream.get_u8( ) == 1
			return {
				"type": MIDISystemEventType.key,
				"sf": sf,
				"minor": minor,
			}
		else:
			return {
				"type": MIDISystemEventType.unknown,
				"meta_type": meta_type,
				"data": stream.get_partial_data( size )[1],
			}
	elif event_type_byte == 0xf0:
		var size = self.read_variable_int( stream )
		return {
			"type": MIDISystemEventType.sys_ex,
			"data": stream.get_partial_data( size )[1],
		}
	elif event_type_byte == 0xf7:
		var size = self.read_variable_int( stream )
		return {
			"type": MIDISystemEventType.divided_sys_ex,
			"data": stream.get_partial_data( size )[1],
		}

	print( "Unknown system event type: %x" % event_type_byte )
	breakpoint

"""
	通常のイベント読み込み
"""
func read_event( stream, event_type_byte ):
	var param = 0

	if ( event_type_byte & 0x80 ) == 0:
		# running status
		param = event_type_byte
		event_type_byte = self.last_event_type
	else:
		param = stream.get_u8( )
		self.last_event_type = event_type_byte

	var event_type = event_type_byte & 0xf0

	if event_type == 0x80:
		return {
			"type": MIDIEventType.note_off,
			"note": param,
			"velocity": stream.get_u8( ),
		}
	elif event_type == 0x90:
		var velocity = stream.get_u8( )
		if velocity == 0:
			# velocity0のnote_onはnote_off扱いにする
			return {
				"type": MIDIEventType.note_off,
				"note": param,
				"velocity": velocity,
			}
		else:
			return {
				"type": MIDIEventType.note_on,
				"note": param,
				"velocity": velocity,
			}
	elif event_type == 0xA0:
		return {
			"type": MIDIEventType.polyphonic_key_pressure,
			"note": param,
			"value": stream.get_u8( ),
		}
	elif event_type == 0xB0:
		return {
			"type": MIDIEventType.control_change,
			"number": param,
			"value": stream.get_u8( ),
		}
	elif event_type == 0xC0:
		return {
			"type": MIDIEventType.program_change,
			"number": param,
		}
	elif event_type == 0xD0:
		return {
			"type": MIDIEventType.channel_pressure,
			"value": param,
		}
	elif event_type == 0xE0:
		return {
			"type": MIDIEventType.pitch_bend,
			"value": param | ( stream.get_u8( ) << 7 ),
		}

	print( "unknown event type: %d" % event_type_byte )
	breakpoint

"""
	可変長数値の読み込み
	@param	stream
	@return	数値
"""
func read_variable_int( stream ):
	var result = 0

	while true:
		var c = stream.get_u8( )
		if ( c & 0x80 ) != 0:
			result |= c & 0x7f
			result <<= 7
		else:
			result |= c
			break

	return result

"""
	チャンクデータの読み込み
	@param	stream	Stream
	@return	chunk data
"""
func read_chunk_data( stream ):
	var id = self.read_string( stream, 4 )
	var size = stream.get_32( )
	var new_stream = StreamPeerBuffer.new( )
	new_stream.set_data_array( stream.get_partial_data( size )[1] )
	new_stream.big_endian = true

	return {
		"id": id,
		"size": size,
		"stream": new_stream
	}

"""
	文字列で返す
"""
func read_string( stream, size ):
	return stream.get_partial_data( size )[1].get_string_from_utf8( )
