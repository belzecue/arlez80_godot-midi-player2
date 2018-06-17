"""
	Sound Bank by Yui Kinomoto @arlez80
"""

const SoundFont = preload( "SoundFont.gd" )

# デフォルト
var default_mix_rate_table = [819,868,920,974,1032,1094,1159,1228,1301,1378,1460,1547,1639,1736,1840,1949,2065,2188,2318,2456,2602,2756,2920,3094,3278,3473,3679,3898,4130,4375,4635,4911,5203,5513,5840,6188,6556,6945,7358,7796,8259,8751,9271,9822,10406,11025,11681,12375,13111,13891,14717,15592,16519,17501,18542,19644,20812,22050,23361,24750,26222,27781,29433,31183,33038,35002,37084,39289,41625,44100,46722,49501,52444,55563,58866,62367,66075,70004,74167,78577,83250,88200,93445,99001,104888,111125,117733,124734,132151,140009,148334,157155,166499,176400,186889,198002,209776,222250,235466,249467,264301,280018,296668,314309,332999,352800,373779,396005,419552,444500,470932,498935,528603,560035,593337,628618,665998,705600,747557,792009,839105,889000,941863,997869,1057205,1120070,1186673,1257236]
var default_ads_state = [
	{ "time": 0, "volume": 1.0 },
	{ "time": 0.2, "volume": 0.8 },
]
var default_release_state = [
	{ "time": 0, "volume": 0.8 },
	{ "time": 0.01, "volume": 0.0 },
]


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
		"ads_state": default_ads_state,
		"release_state": default_release_state,
		# "assine_group": 0,	# reserved
	}

"""
	再生周波数計算
"""
func calc_mix_rate( rate, center_key, target_key ):
	return round( rate * pow( 2.0, ( target_key - center_key ) / 12.0 ) )

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
			var bag = {
				"program_number": program_number,
				"preset": preset,
				"coarse_tune": 0,
				"fine_tune": 0,
				"key_range": null,
				"instrument": null,
			}
			while gen_count < gen_next:
				var gen = sf.pdta.pgen[gen_count]
				match gen.gen_oper:
					SoundFont.coarse_tune:
						bag.coarse_tune = gen.amount
					SoundFont.fine_tune:
						bag.fine_tune = gen.amount
					SoundFont.key_range:
						bag.key_range = {
							"high": gen.uamount >> 8,
							"low": gen.uamount & 0xFF,
						}
					SoundFont.instrument:
						bag.instrument = sf_insts[gen.uamount]
					_:
						# print( gen.gen_oper )
						pass
				gen_count += 1
			if bag.instrument != null:
				self._read_soundfont_inst_to_preset( sf, preset.instruments, bag )
			gen_index = gen_next
			bag_count += 1
		bag_index = bag_next

		self.set_preset( program_number, preset )

func _read_soundfont_inst_to_preset( sf, instruments, preset_bag ):
	var sf_inst = preset_bag.instrument
	for bag in sf_inst.bags:
		var mix_rate = bag.sample.sample_rate * pow( 2.0, ( preset_bag.coarse_tune + bag.coarse_tune ) / 12.0 ) * pow( 2.0, ( bag.sample.pitch_correction + preset_bag.fine_tune + bag.fine_tune ) / 1200.0 )

		var ass = AudioStreamSample.new( )
		ass.data = sf.sdta.smpl.subarray( bag.sample_start * 2, bag.sample_end * 2 )
		ass.format = AudioStreamSample.FORMAT_16_BITS
		ass.mix_rate = mix_rate
		ass.stereo = false #bag.sample.sample_type != SoundFont.mono_sample
		ass.loop_begin = bag.sample_start_loop - bag.sample_start
		ass.loop_end = bag.sample_end_loop - bag.sample_start
		ass.loop_mode = AudioStreamSample.LOOP_FORWARD
		#if ass.stereo:
		#	ass.loop_begin /= 2
		#	ass.loop_end /= 2
		if ass.loop_end - ass.loop_begin < 8:
			ass.loop_mode = AudioStreamSample.LOOP_DISABLED
		var key_range = bag.key_range
		if preset_bag.key_range != null:
			key_range = preset_bag.key_range
		for key_number in range( key_range.low, key_range.high + 1 ):
			var instrument = self.create_instrument( )
			if bag.original_key == 255:
				instrument.mix_rate = bag.sample.sample_rate
			else:
				instrument.mix_rate = self.calc_mix_rate( mix_rate, bag.original_key, key_number )
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
		var global_bag = {}
		while bag_count < bag_next:
			var bag = {
				"sample": null,
				"sample_id": -1,
				"sample_start": 0,
				"sample_end": 0,
				"sample_start_loop": 0,
				"sample_end_loop": 0,
				"coarse_tune": 0,
				"fine_tune": 0,
				"original_key": 255,
				"keynum": 0,
				"key_range": { "high": 127, "low": 0 },
				"vel_range": { "high": 127, "low": 0 },
			}
			var gen_next = sf.pdta.ibag[bag_count+1].gen_ndx
			var gen_count = gen_index
			while gen_count < gen_next:
				var gen = sf.pdta.igen[gen_count]
				match gen.gen_oper:
					SoundFont.key_range:
						bag.key_range.high = gen.uamount >> 8
						bag.key_range.low = gen.uamount & 0xFF
					SoundFont.vel_range:
						bag.vel_range.high = gen.uamount >> 8
						bag.vel_range.low = gen.uamount & 0xFF
					SoundFont.overriding_root_key:
						bag.original_key = gen.amount
					SoundFont.start_addrs_offset:
						bag.sample_start += gen.amount
					SoundFont.end_addrs_offset:
						bag.sample_end += gen.amount
					SoundFont.start_addrs_coarse_offset:
						bag.sample_start += gen.amount * 32768
					SoundFont.end_addrs_coarse_offset:
						bag.sample_end += gen.amount * 32768
					SoundFont.startloop_addrs_offset:
						bag.sample_start_loop = gen.amount
					SoundFont.endloop_addrs_offset:
						bag.sample_end_loop = gen.amount
					SoundFont.startloop_addrs_coarse_offset:
						bag.sample_start_loop += gen.amount * 32768
					SoundFont.endloop_addrs_coarse_offset:
						bag.sample_end_loop += gen.amount * 32768
					SoundFont.coarse_tune:
						bag.coarse_tune = gen.amount
					SoundFont.fine_tune:
						bag.fine_tune = gen.amount
					SoundFont.keynum:
						bag.keynum = gen.amount
					SoundFont.sample_id:
						bag.sample_id = gen.uamount
						bag.sample = sf.pdta.shdr[gen.amount]
						bag.sample_start += bag.sample.start
						bag.sample_end += bag.sample.end
						bag.sample_start_loop += bag.sample.start_loop
						bag.sample_end_loop += bag.sample.end_loop
						if bag.original_key == 255:
							bag.original_key = bag.sample.original_key
				gen_count += 1
			# global zoneでない場合
			if bag.sample != null:
				sf_inst.bags.append( bag )
			else:
				global_bag = bag
			gen_index = gen_next
			bag_count += 1
		sf_insts.append( sf_inst )
		bag_index = bag_next

	return sf_insts

func _read_soundfont_shdr( sf ):
	var samples = {}
	var zero_4bytes = PoolByteArray( [ 0, 0, 0, 0 ] )

	for sample_id in range( 0, len(sf.pdta.shdr) ):
		var shdr = sf.pdta.shdr[sample_id]
		var sample = null
		var base_sample = sf.sdta.smpl.subarray( shdr.start * 2, shdr.end * 2 )

		if samples.has( shdr.sample_link ):
			sample = samples[shdr.sample_link]
		else:
			sample = PoolByteArray( )

		match shdr.sample_type:
			SoundFont.left_sample:
				for i in range( 0, base_sample.size( ) - 2, 2 ):
					if sample.size( ) < i*2 + 3:
						sample.append_array( zero_4bytes )
					sample[i*2  ] = base_sample[i]
					sample[i*2+1] = base_sample[i+1]
			SoundFont.right_sample:
				for i in range( 0, base_sample.size( ) - 2, 2 ):
					if sample.size( ) < i*2 + 3:
						sample.append_array( zero_4bytes )
					sample[i*2+2] = base_sample[i]
					sample[i*2+3] = base_sample[i+1]
			_:
				sample = base_sample

		samples[sample_id] = sample

	return samples
