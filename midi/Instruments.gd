"""
	Instruments Bank
"""

const max_notes = 128

var bank = {}

# 69 = A4
var default_play_rate_table = [819,868,920,974,1032,1094,1159,1228,1301,1378,1460,1547,1639,1736,1840,1949,2065,2188,2318,2456,2602,2756,2920,3094,3278,3473,3679,3898,4130,4375,4635,4911,5203,5513,5840,6188,6556,6945,7358,7796,8259,8751,9271,9822,10406,11025,11681,12375,13111,13891,14717,15592,16519,17501,18542,19644,20812,22050,23361,24750,26222,27781,29433,31183,33038,35002,37084,39289,41625,44100,46722,49501,52444,55563,58866,62367,66075,70004,74167,78577,83250,88200,93445,99001,104888,111125,117733,124734,132151,140009,148334,157155,166499,176400,186889,198002,209776,222250,235466,249467,264301,280018,296668,314309,332999,352800,373779,396005,419552,444500,470932,498935,528603,560035,593337,628618,665998,705600,747557,792009,839105,889000,941863,997869,1057205,1120070,1186673,1257236]
# ADSR
var default_ads_state = [
	{ "time": 0, "volume": 1.0 },
	{ "time": 0.2, "volume": 0.8 },
];
var default_release_state = [
	{ "time": 0, "volume": 0.8 },
	{ "time": 0.03, "volume": 0.0 },
];

func create_instrument( ):
	return {
		"name": "",
		"notes": [],
		"audio_streams": [],	# auto update
	}

func add_instrument( bank_number, program_number, instrument ):
	self._update_instrument_information( instrument )

	if self.bank.has( bank_number ):
		self.bank[bank_number] = {}
	self.bank[bank_number][program_number] = instrument

func add_simple_instrument( bank_number, program_number, audio_stream ):
	var instrument = self.create_instrument( )

	for i in range( max_notes ):
		instrument.notes.append({
			"assign_group": 0,
			"audio_stream": audio_stream,
			"volume_db": 0.0,
			"ads_state": default_ads_state,
			"release_state": default_release_state,
			"play_rate_table": default_play_rate_table,
		})

	self.add_instrument( bank_number, program_number, instrument )

	return instrument

func create_play_rate_table( center, rate ):
	var table = []
	self._create_play_rate_table_down( table, center, rate )
	self._create_play_rate_table_up( table, center, rate )
	return table

func _create_play_rate_table_down( table, from, rate ):
	var to = from - 12
	var half_rate = rate / 2.0

	for i in range( 0, 12 ):
		var note = to + i
		if 0 < note:
			table[note] = round( hald_rate * pow( 2, i / 12.0 ) )

	if 0 < to:
		self._create_play_rate_table_down( table, to, half_rate )

func _create_play_rate_table_up( table, from, rate ):
	var to = from + 12

	for i in range( 1, 13 ):
		var note = i + from
		if note <= 127:
			table[note] = round( rate * pow( 2, i / 12.0 ) )

	if to < 127:
		self._create_play_rate_table_up( table, to, rate * 2 )

func _update_instrument_information( instrument ):
	var audio_streams = []
	for note in instrument.notes:
		var audio_stream = note.audio_stream
		if audio_streams.find( audio_stream ) == -1:
			audio_streams.append( audio_stream )
	instrument.audio_streams = audio_streams
