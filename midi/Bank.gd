"""
	Sound Bank by Yui Kinomoto @arlez80
"""

const SoundFont = preload( "SoundFont.gd" )

# デフォルト
var default_mix_rate_table = [819,868,920,974,1032,1094,1159,1228,1301,1378,1460,1547,1639,1736,1840,1949,2065,2188,2318,2456,2602,2756,2920,3094,3278,3473,3679,3898,4130,4375,4635,4911,5203,5513,5840,6188,6556,6945,7358,7796,8259,8751,9271,9822,10406,11025,11681,12375,13111,13891,14717,15592,16519,17501,18542,19644,20812,22050,23361,24750,26222,27781,29433,31183,33038,35002,37084,39289,41625,44100,46722,49501,52444,55563,58866,62367,66075,70004,74167,78577,83250,88200,93445,99001,104888,111125,117733,124734,132151,140009,148334,157155,166499,176400,186889,198002,209776,222250,235466,249467,264301,280018,296668,314309,332999,352800,373779,396005,419552,444500,470932,498935,528603,560035,593337,628618,665998,705600,747557,792009,839105,889000,941863,997869,1057205,1120070,1186673,1257236]

# 音色テーブル
var presets = {}

"""
	楽器
"""
func create_preset( ):
	var instruments = []
	for i in range( 0, 128 ):
		instruments.append( null )
	return {
		"name": "",
		"instruments": instruments,
	}

"""
	ノート
"""
func create_instrument( ):
	return {
		"mix_rate": 44100,
		"stream": null,
		# "assine_group": 0,	# reserved
	}

"""
	計算
"""
func calc_mix_rate( rate, center_key, target_key ):
	var key = center_key
	var half = pow( 2.0, 1.0 / 12.0 )
	var rev_half = 1 / half

	while key + 12 < target_key:
		rate *= 2
		key += 12
	while key < target_key:
		rate *= half
		key += 1
	while target_key < key - 12:
		rate *= 0.5
		key -= 12
	while target_key < key:
		rate *= rev_half
		key -= 1

	return round( rate )

"""
	追加
"""
func set_preset_sample( program_number, base_sample, base_mix_rate ):
	var mix_rate_table = default_mix_rate_table

	if base_mix_rate != 44100:
		print( "not implemented" )
		breakpoint

	var preset = self.create_preset( )
	preset.name = "#%03d" % program_number
	for i in range(0,128):
		var inst = self.create_instrument( )
		inst.mix_rate = mix_rate_table[i]
		inst.stream = base_sample
		preset.instruments[i] = inst

	self.set_preset( program_number, preset )

"""
	追加
"""
func set_preset( program_number, preset ):
	self.presets[program_number] = preset

"""
	指定した楽器を取得
"""
func get_preset( program_number ):
	if not self.presets.has( program_number ):
		program_number = 0

	return self.presets[program_number]

"""
	サウンドフォント読み込み
"""
func read_soundfont( sf ):
	var sf_insts = self._read_soundfont_pdta_inst( sf )

	var bag_index = 0
	var gen_index = 0
	for phdr_index in range( 0, len( sf.pdta.phdr )-1 ):
		var phdr = sf.pdta.phdr[phdr_index]

		var preset = self.create_preset( )
		var program_number = phdr.preset | ( phdr.bank << 7 )
		preset.name = phdr.name

		var bag_next = sf.pdta.phdr[phdr_index+1].preset_bag_index
		var bag_count = bag_index
		while bag_count < bag_next:
			var gen_next = sf.pdta.pbag[bag_count+1].gen_ndx
			var gen_count = gen_index
			while gen_count < gen_next:
				var gen = sf.pdta.pgen[gen_count]
				match gen.gen_oper:
					SoundFont.instrument:
						self._read_soundfont_inst_to_preset( sf, preset.instruments, sf_insts[gen.amount] )
				gen_count += 1
			gen_index = gen_next
			bag_count += 1
		bag_index = bag_next

		self.set_preset( program_number, preset )

	print( self.presets[72].instruments[84] )

func _read_soundfont_inst_to_preset( sf, instruments, sf_inst ):
	for bag in sf_inst.bags:
		var ass = AudioStreamSample.new( )
		ass.data = sf.sdta.smpl.subarray( bag.sample.start * 2, bag.sample.end * 2 )
		ass.format = AudioStreamSample.FORMAT_16_BITS
		ass.loop_mode = AudioStreamSample.LOOP_FORWARD
		ass.mix_rate = bag.sample.sample_rate
		ass.stereo = false
		ass.loop_begin = bag.sample.start_loop - bag.sample.start
		ass.loop_end = bag.sample.end_loop - bag.sample.start
		for key_number in range( bag.key_range.low, bag.key_range.high + 1 ):
			var instrument = self.create_instrument( )
			if bag.original_key == 255:
				instrument.mix_rate = bag.sample.sample_rate
			else:
				instrument.mix_rate = self.calc_mix_rate( bag.sample.sample_rate, bag.original_key, key_number )
			instrument.stream = ass
			instruments[key_number] = instrument

func _read_soundfont_pdta_inst( sf ):
	var sf_insts = []
	var bag_index = 0
	var gen_index = 0

	for inst_index in range(0, len( sf.pdta.inst ) - 1 ):
		var inst = sf.pdta.inst[inst_index]
		var sf_inst = {"name": inst.name, "bags": [] }

		var bag_next = sf.pdta.inst[inst_index+1].inst_bag_ndx
		var bag_count = bag_index
		while bag_count < bag_next:
			var bag_data = { "sample": null, "original_key":255, "key_range": { "high": 127, "low": 0 }, "vel_range": { "high": 127, "low": 0 } }
			var gen_next = sf.pdta.ibag[bag_count+1].gen_ndx
			var gen_count = gen_index
			while gen_count < gen_next:
				var gen = sf.pdta.igen[gen_count]
				match gen.gen_oper:
					SoundFont.key_range:
						bag_data.key_range.high = gen.amount >> 8
						bag_data.key_range.low = gen.amount & 0xFF
					SoundFont.vel_range:
						bag_data.vel_range.high = gen.amount >> 8
						bag_data.vel_range.low = gen.amount & 0xFF
					SoundFont.overriding_root_key:
						bag_data.original_key = gen.amount
					SoundFont.sample_id:
						bag_data.sample = sf.pdta.shdr[gen.amount]
						if bag_data.original_key == 255:
							bag_data.original_key = bag_data.sample.original_key
				gen_count += 1
			# global zone無視
			if bag_data.sample != null:
				sf_inst.bags.append( bag_data )
			gen_index = gen_next
			bag_count += 1
		sf_insts.append( sf_inst )
		bag_index = bag_next

	return sf_insts
