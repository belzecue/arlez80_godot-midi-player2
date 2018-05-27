extends AudioStreamPlayer

"""
	AudioStreamPlayer with ADSR
"""

enum ADSRPlayingMode {
	ads,
	release,
}

var mode = ADSRPlayingMode.ads
var velocity = 0
var pitch_bend = 0
var mix_rate = 0
var using_timer = 0.0
var timer = 0.0
var current_volume = 0
var maximum_volume_db = -8
var minimum_volume_db = -1000
var pan = 0.5
var ads_state = [
	{ "time": 0, "volume": 1.0 },
	{ "time": 0.2, "volume": 0.8 },
	# { "time": 0.2, "jump_to": 0.0 },	# not implemented
]
var release_state = [
	{ "time": 0, "volume": 0.8 },
	{ "time": 0.03, "volume": 0.0 },
	# { "time": 0.2, "jump_to": 0.0 },	# not implemented
]

func _ready( ):
	self.stop( )

func play( ):
	self.mode = ADSRPlayingMode.ads
	self.timer = 0.0
	self.using_timer = 0.0
	# self.stream.loop_mode = AudioStreamSample.LOOP_FORWARD
	self.current_volume = self.ads_state[0].volume
	self.stream.mix_rate = round( self.mix_rate * ( 1 + self.pitch_bend * 0.5 ) )
	.play( 0.0 )
	self._update_volume( )

func start_release( ):
	self.mode = ADSRPlayingMode.release
	self.current_volume = self.release_state[0].volume
	self.timer = 0.0
	self._update_volume( )

func set_pitch_bend( pb ):
	self.pitch_bend = pb
	var pos = self.get_playback_position( )
	self.stream.mix_rate = round( self.mix_rate * ( 1 + self.pitch_bend * 0.5 ) )
	.play( pos )

func _process( delta ):
	if not self.playing:
		return

	self.timer += delta
	self.using_timer += delta
	# self.transform.origin.x = self.pan * self.get_viewport( ).size.x

	# ADSR
	var use_state = null
	if self.mode == ADSRPlayingMode.ads:
		use_state = self.ads_state
	elif self.mode == ADSRPlayingMode.release:
		use_state = self.release_state

	var last_time = 0
	var all_states = len( use_state )
	var last_state = all_states - 1
	for state_number in range( all_states ):
		var state = use_state[state_number]
		if state.time <= self.timer:
			if 0 < last_time:
				var s = ( state.time - self.timer ) / last_time
				var t = 1.0 - s
				self.current_volume = self.current_volume * s + state.volume * t
				if self.mode == ADSRPlayingMode.release:
					if state_number == last_state:
						self.stop( )
			else:
				self.current_volume = state.volume
			break
		else:
			self.current_volume = state.volume
			last_time = state.time

	self._update_volume( )

func _update_volume( ):
	var s = self.current_volume
	var t = 1.0 - s
	self.volume_db = s * self.maximum_volume_db + t * self.minimum_volume_db
