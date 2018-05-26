extends Node

const max_track = 16
const max_channel = 16
const max_note_number = 128
const max_program_number = 128

onready var SMF = preload( "SMF.gd" )

export var max_polyphony = 8
export var file = ""
export var playing = false
export var channel_mute = [false,false,false,false,false,false,false,false,false,false,false,false,false,false,false,false]
export var play_speed = 1.0
export var volume_db = -8
var smf = null

var seconds_to_timebase = 2.3
var position = 0
var last_position = 0
var track_status = null
var channel_status = []
var instruments_status = {}
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

	var ADSR = preload("ADSR.tscn")
	for instrument in instruments.get_children( ):
		var program_number = int( instrument.name )
		self.instruments_status[program_number] = []

		for i in range( self.max_polyphony ):
			var audio_stream_player = ADSR.instance( )
			audio_stream_player.stream = instrument.stream.duplicate( )
			self.add_child( audio_stream_player )
			self.instruments_status[program_number].append( audio_stream_player )

"""
	トラック初期化
"""
class TrackSorter:
	static func sort(a, b):
		if a.time < b.time:
			return true

func _init_track( ):
	self.track_status = {
		"events": [],
		"event_pointer": 0,
	}

	# 1トラックに集約
	for track in self.smf.tracks:
		self.track_status.events += track.events

	# ソート
	self.track_status.events.sort_custom( TrackSorter, "sort" )

	self.last_position = self.track_status.events[len(self.track_status.events)-1].time

"""
	チャンネル初期化
"""
func _init_channel( ):
	for i in range( max_channel ):
		self.channel_status.append({
			"note_on": {},
			"program": 0,
			"volume": 1.0,
			"expression": 1.0,
			"pan": 0.5,
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
	self._stop_all_notes( )
	self.position = to_position

	var pointer = 0
	var length = len(self.track_status.events)
	while pointer < length:
		var event_chunk = self.track_status.events[pointer]
		if self.position < event_chunk.time:
			break
		pointer += 1
	self.track_status.event_pointer = pointer

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
	for program in self.instruments_status.keys( ):
		for instrument in self.instruments_status[program]:
			instrument.stop( )

	for channel in self.channel_status:
		channel.note_on = {}

"""
	毎フレーム処理
"""
func _process( delta ):
	if not self.playing:
		return

	self._process_track( )
	self.position += self.smf.timebase * delta * self.seconds_to_timebase * self.play_speed

"""
	トラック処理
"""
func _process_track( ):
	var track = self.track_status
	if track.events == null:
		return

	var length = len(track.events)

	if length <= track.event_pointer:
		self.playing = false
		return

	while track.event_pointer < length:
		var event_chunk = track.events[track.event_pointer]
		if self.position < event_chunk.time:
			break
		track.event_pointer += 1

		if event_chunk.channel_number == 9:
			# ドラムトラックは"今"未対応なので無視する
			continue

		var channel = self.channel_status[event_chunk.channel_number]
		var event = event_chunk.event

		if event.type == SMF.MIDIEventType.note_off:
			if channel.note_on.has( event.note ):
				var note = channel.note_on[event.note]
				if note != null:
					note.start_release( )
					channel.note_on.erase( event.note )
		elif event.type == SMF.MIDIEventType.note_on:
			if not self.channel_mute[event_chunk.channel_number]:
				var note_volume = channel.volume * channel.expression * ( event.velocity / 127.0 )
				var volume_db = note_volume * self.channel_volume_db - self.channel_volume_db + self.volume_db

				if channel.note_on.has( event.note ):
					var note = channel.note_on[event.note]
					note.play( )
					note.maximum_volume_db = volume_db
				else:
					var note = self._get_instruments( channel.program )
					if note != null:
						note.stream.mix_rate = play_rate_table[event.note]
						note.maximum_volume_db = volume_db
						note.play( )
						channel.note_on[event.note] = note
		elif event.type == SMF.MIDIEventType.program_change:
			channel.program = event.number
		elif event.type == SMF.MIDIEventType.control_change:
			if event.number == SMF.control_number_volume:
				channel.volume = event.value / 127.0
			elif event.number == SMF.control_number_expression:
				channel.expression = event.value / 127.0
			elif event.number == SMF.control_number_pan:
				channel.pan = event.value / 127.0
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

func _get_instruments( program ):
	if not self.instruments_status.has( program ):
		program = 0
		if not self.instruments_status.has( 0 ):
			return null

	for instrument in self.instruments_status[program]:
		if not instrument.playing:
			return instrument

	return null
