extends Node

const max_track = 16
const max_channel = 16
const max_note_number = 128
const max_program_number = 128

onready var SMF = preload( "SMF.gd" )

export var max_polyphony = 8
export var file = ""
export var playing = false
export var channel_mute = [ false,false,false,false,false,false,false,false,false,false,false,false,false,false,false,false, ]
var smf = null

var seconds_to_timebase = 2.3
var position = 0
var track_status = []
var channel_status = []
var instruments_status = {}
var volume_db = -20
var channel_volume_db = 20

# 69 = A4
var play_rate_table = [819,868,920,974,1032,1094,1159,1228,1301,1378,1460,1547,1639,1736,1840,1949,2065,2188,2318,2456,2602,2756,2920,3094,3278,3473,3679,3898,4130,4375,4635,4911,5203,5513,5840,6188,6556,6945,7358,7796,8259,8751,9271,9822,10406,11025,11681,12375,13111,13891,14717,15592,16519,17501,18542,19644,20812,22050,23361,24750,26222,27781,29433,31183,33038,35002,37084,39289,41625,44100,46722,49501,52444,55563,58866,62367,66075,70004,74167,78577,83250,88200,93445,99001,104888,111125,117733,124734,132151,140009,148334,157155,166499,176400,186889,198002,209776,222250,235466,249467,264301,280018,296668,314309,332999,352800,373779,396005,419552,444500,470932,498935,528603,560035,593337,628618,665998,705600,747557,792009,839105,889000,941863,997869,1057205,1120070,1186673,1257236]

"""
	初期化
"""
func _ready( ):
	# ファイル読み込み
	if self.smf == null:
		var smf_reader = SMF.new( )
		self.smf = smf_reader.read_file( self.file )

	self._init_track( )
	self._init_channel( )

	# 楽器
	var instruments = self.get_node( "Instruments" )
	if instruments == null:
		print( "Godot MIDI Player: MidiPlayer has not 'Instruments' node!" )
		breakpoint

	for instrument in instruments.get_children( ):
		var program_number = int( instrument.name )
		self.instruments_status[program_number] = []

		for i in range( self.max_polyphony ):
			var audio_stream_player = AudioStreamPlayer.new( )
			audio_stream_player.stream = instrument.stream.duplicate( )
			self.add_child( audio_stream_player )
			self.instruments_status[program_number].append( audio_stream_player )

"""
	トラック初期化
"""
func _init_track( ):
	for i in range( max_track ):
		self.track_status.append({
			"events": null,
			"event_pointer": 0,
		})
	for track in self.smf.tracks:
		if 16 <= track.track_number:
			continue
		self.track_status[track.track_number].events = track.events

"""
	チャンネル初期化
"""
func _init_channel( ):
	var note_on = []
	for i in range( max_note_number ):
		note_on.append( null )

	for i in range( max_channel ):
		self.channel_status.append({
			"note_on": note_on,
			"program": 0,
			"volume": 1.0,
			"expression": 1.0,
			"pan": 0,
		})

"""
	再生
	@param	from_position
"""
func play( from_position = 0 ):
	self._stop_all_notes( )
	self.playing = true
	self.position = from_position
	self._init_track( )
	self._init_channel( )

"""
	シーク
"""
func seek( to_position ):
	print( "not implemented" )
	breakpoint
	# TODO: ノートの状態を変更するように
	# self.position = to_position

"""
	停止
"""
func stop( ):
	self._stop_all_notes( )
	self.playing = false

"""
	全音を止める
"""
func _stop_all_notes( ):
	for instrument in self.instruments_status:
		for asp in instrument:
			asp.stop( )

"""
	毎フレーム処理
"""
func _process( delta ):
	if not self.playing:
		return

	for track in self.track_status:
		self._process_track( track )

	self.position += self.smf.timebase * delta * self.seconds_to_timebase

"""
	トラック処理
"""
func _process_track( track ):
	if track.events == null:
		return

	while track.event_pointer < len(track.events):
		var event_chunk = track.events[track.event_pointer]
		if self.position < event_chunk.time:
			break

		var channel = self.channel_status[event_chunk.channel_number]
		var event = event_chunk.event

		if event.type == SMF.MIDIEventType.note_off:
			var note = channel.note_on[event.note]
			if note != null:
				channel.note_on[event.note] = null
				note.stop( )
		elif event.type == SMF.MIDIEventType.note_on:
			if not self.channel_mute[event_chunk.channel_number]:
				var old_note = channel.note_on[event.note]
				if old_note != null:
					channel.note_on[event.note] = null
					old_note.stop( )
				var note = self._get_instruments( channel.program )
				if note != null:
					note.stream.mix_rate = play_rate_table[event.note]
					note.volume_db = ( ( channel.volume * channel.expression * ( event.velocity / 127 ) ) * self.channel_volume_db ) - self.channel_volume_db + self.volume_db
					note.play( )
					channel.note_on[event.note] = note
		elif event.type == SMF.MIDIEventType.program_change:
			channel.program = event.number
		elif event.type == SMF.MIDIEventType.control_change:
			if event.number == SMF.control_number_volume:
				channel.volume = event.value / 127
			elif event.number == SMF.control_number_expression:
				channel.expression = event.value / 127
			elif event.number == SMF.control_number_pan:
				channel.pan = event.value / 64 - 1.0
			else:
				# 無視
				pass
		elif event.type == SMF.MIDIEventType.system_event:
			if event.args.type == SMF.MIDISystemEventType.set_tempo:
				var bpm = 60000000.0 / event.args.bpm
				self.seconds_to_timebase = bpm / 60.0
			else:
				# 無視
				pass
		else:
			# 無視
			pass

		track.event_pointer += 1

func _get_instruments( program ):
	if not self.instruments_status.has( program ):
		program = 0
		if not self.instruments_status.has( 0 ):
			return null

	for instrument in self.instruments_status[program]:
		if not instrument.playing:
			return instrument

	return null
