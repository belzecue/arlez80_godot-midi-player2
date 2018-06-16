extends Node

const max_track = 16
const max_channel = 16
const max_note_number = 128
const max_program_number = 128
const drum_track_channel = 0x09

onready var SMF = preload( "SMF.gd" )
onready var SoundFont = preload( "SoundFont.gd" )
onready var Bank = preload( "Bank.gd" )

export var max_polyphony = 64
export var file = ""
export var playing = false
export var channel_mute = [false,false,false,false,false,false,false,false,false,false,false,false,false,false,false,false]
export var play_speed = 1.0
export var volume_db = -30
export var key_shift = 0
export var loop = false
export var loop_start = 0
export var soundfont = ""

var smf_data = null
var tempo = 120 setget set_tempo
var seconds_to_timebase = 2.3
var position = 0
var last_position = 0
var track_status = null
var channel_status = []
var channel_volume_db = 20

var bank = null
var audio_stream_players = []

signal changed_tempo( tempo )
signal appeared_lyric( lyric )
signal appeared_marker( marker )
signal appeared_cue_point( cue_point )
signal looped

func _ready( ):
	if self.playing:
		self.play( )

"""
	初期化
"""
func _prepare_to_play( ):
	# ファイル読み込み
	if self.smf_data == null:
		var smf_reader = SMF.new( )
		self.smf_data = smf_reader.read_file( self.file )

	self._init_track( )
	self._analyse_smf( )
	self._init_channel( )

	# 楽器
	self.bank = Bank.new( )
	if self.soundfont != "":
		var sf_reader = SoundFont.new( )
		var sf2 = sf_reader.read_file( self.soundfont )
		self.bank.read_soundfont( sf2 )

	"""
	var instruments = self.get_node( "Instruments" )
	if instruments == null:
		print( "Godot MIDI Player: MidiPlayer has not instruments. You must add 'Instruments' node or add soundfont path" )
		breakpoint
	for instrument_node in instruments.get_children( ):
		var program_number = int( instrument_node.get_name( ) )
		self.bank.set_preset_sample( program_number, instrument_node.stream, 44100 )
	"""
	# 発音機
	var ADSR = preload("ADSR.tscn")
	for i in range( self.max_polyphony ):
		var audio_stream_player = ADSR.instance( )
		#audio_stream_player.mix_target = instrument.mix_target
		#audio_stream_player.bus = instrument.bus
		self.add_child( audio_stream_player )
		self.audio_stream_players.append( audio_stream_player )



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

	for track in self.smf_data.tracks:
		self.track_status.events += track.events
	self.track_status.events.sort_custom( TrackSorter, "sort" )
	self.last_position = self.track_status.events[len(self.track_status.events)-1].time

"""
	SMF解析
"""
func _analyse_smf( ):
	var channels = []
	for i in range( max_channel ):
		channels.append({
			"program_number": 0,
			"note_on": {}
		})

	for event_chunk in self.track_status.events:
		var channel_number = event_chunk.channel_number
		var channel = channels[channel_number]
		var event = event_chunk.event

		match event.type:
			SMF.MIDIEventType.note_off:
				channel.note_on.erase( event.note )
			SMF.MIDIEventType.note_on:
				channel.note_on[event.note] = true
			SMF.MIDIEventType.program_change:
				channel.program_number = event.number
			SMF.MIDIEventType.control_change:
				if event.number == SMF.control_number_tkool_loop_point:
					self.loop_start = event_chunk.time

"""
	チャンネル初期化
"""
func _init_channel( ):
	self.channel_status = []
	for i in range( max_channel ):
		self.channel_status.append({
			"number": i,
			"note_on": {},
			"program": 0,
			"volume": 1.0,
			"expression": 1.0,
			"pitch_bend": 0.0,
			"pan": 0.5,
		})

"""
	再生
	@param	from_position
"""
func play( from_position = 0 ):
	self._prepare_to_play( )
	self.playing = true
	self.seek( from_position )

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
	テンポ設定
"""
func set_tempo( bpm ):
	tempo = bpm
	self.seconds_to_timebase = tempo / 60.0
	self.emit_signal( "changed_tempo", bpm )

"""
	全音を止める
"""
func _stop_all_notes( ):
	for audio_stream_player in self.audio_stream_players:
		audio_stream_player.stop( )

	for channel in self.channel_status:
		channel.note_on = {}

"""
	毎フレーム処理
"""
func _process( delta ):
	if self.smf_data == null:
		return
	if not self.playing:
		return

	self._process_track( )
	self.position += self.smf_data.timebase * delta * self.seconds_to_timebase * self.play_speed

"""
	トラック処理
"""
func _process_track( ):
	var track = self.track_status
	if track.events == null:
		return

	var length = len(track.events)

	if length <= track.event_pointer:
		if self.loop:
			self.seek( self.loop_start )
			self.emit_signal( "looped" )
		else:
			self.playing = false
		return

	while track.event_pointer < length:
		var event_chunk = track.events[track.event_pointer]
		if self.position < event_chunk.time:
			break
		track.event_pointer += 1

		var channel = self.channel_status[event_chunk.channel_number]
		var event = event_chunk.event

		match event.type:
			SMF.MIDIEventType.note_off:
				self._process_track_event_note_off( channel, event )
			SMF.MIDIEventType.note_on:
				self._process_track_event_note_on( channel, event )
			SMF.MIDIEventType.program_change:
				channel.program = event.number
			SMF.MIDIEventType.control_change:
				self._process_track_event_control_change( channel, event )
			SMF.MIDIEventType.pitch_bend:
				channel.pitch_bend = event.value / 8192.0 - 1.0
				self._update_pitch_bend_note( channel )
			SMF.MIDIEventType.system_event:
				self._process_track_system_event( channel, event )
			_:
				# 無視
				pass

func _process_track_event_note_off( channel, event ):
	var key_number = event.note + self.key_shift
	if channel.note_on.has( key_number ):
		var note_player = channel.note_on[key_number]
		if note_player != null:
			note_player.start_release( )
			channel.note_on.erase( key_number )

func _process_track_event_note_on( channel, event ):
	if not self.channel_mute[channel.number]:
		var program_number = channel.program
		if channel.number == drum_track_channel:
			program_number |= 128 << 7

		var key_number = event.note + self.key_shift
		var note_volume = channel.volume * channel.expression * ( event.velocity / 127.0 )
		var volume_db = note_volume * self.channel_volume_db - self.channel_volume_db + self.volume_db
		var preset = self.bank.get_preset( program_number )
		var instrument = preset.instruments[key_number]

		if instrument != null:
			if channel.note_on.has( key_number ):
				var note_player = channel.note_on[key_number]
				note_player.velocity = event.velocity
				note_player.maximum_volume_db = volume_db
				note_player.pitch_bend = channel.pitch_bend
				note_player.mix_rate = instrument.mix_rate
				note_player.stream = instrument.stream.duplicate( )
				note_player.play( )
			else:
				var note_player = self._get_idle_player( channel.program )
				if note_player != null:
					note_player.maximum_volume_db = volume_db
					note_player.velocity = event.velocity
					note_player.pitch_bend = channel.pitch_bend
					note_player.mix_rate = instrument.mix_rate
					note_player.stream = instrument.stream.duplicate( )
					note_player.play( )
					channel.note_on[key_number] = note_player

func _process_track_event_control_change( channel, event ):
	match event.number:
		SMF.control_number_volume:
			channel.volume = event.value / 127.0
			self._update_volume_note( channel )
		SMF.control_number_expression:
			channel.expression = event.value / 127.0
			self._update_volume_note( channel )
		SMF.control_number_pan:
			channel.pan = event.value / 127.0
		_:
			# 無視
			pass

func _process_track_system_event( channel, event ):
	match event.args.type:
		SMF.MIDISystemEventType.set_tempo:
			self.tempo = 60000000.0 / event.args.bpm
		SMF.MIDISystemEventType.lyric:
			self.emit_signal( "appeared_lyric", event.args.text )
		SMF.MIDISystemEventType.marker:
			self.emit_signal( "appeared_marker", event.args.text )
		SMF.MIDISystemEventType.cue_point:
			self.emit_signal( "appeared_cue_point", event.args.text )
		_:
			# 無視
			pass

func _get_idle_player( program ):
	var oldest_audio_stream_player = null
	var longest = 0.0

	for audio_stream_player in self.audio_stream_players:
		if not audio_stream_player.playing:
			return audio_stream_player
		if longest < audio_stream_player.using_timer:
			oldest_audio_stream_player = audio_stream_player
			longest = audio_stream_player.using_timer

	return oldest_audio_stream_player

func _update_volume_note( channel ):
	for note in channel.note_on.values( ):
		var note_volume = channel.volume * channel.expression * ( note.velocity / 127.0 )
		var volume_db = note_volume * self.channel_volume_db - self.channel_volume_db + self.volume_db
		note.maximum_volume_db = volume_db

func _update_pitch_bend_note( channel ):
	for note in channel.note_on.values( ):
		note.set_pitch_bend( channel.pitch_bend )
