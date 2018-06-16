"""
	SoundFont Reader by Yui Kinomoto @arlez80
"""

"""
	GenerateOperator
"""
const start_addrs_offset = 0
const end_addrs_offset = 1
const startloop_addrs_offset = 2
const endloop_addrs_offset = 3
const start_addrs_coarse_offset = 4
const mod_lfo_to_pitch = 5
const vib_lfo_to_pitch = 6
const mod_env_to_pitch = 7
const initial_filter_fc = 8
const initial_filter_q = 9
const mod_lfo_to_filter_fc = 10
const mod_env_to_filter_fc = 11
const end_addrs_coarse_offset = 12
const mod_lfo_to_volume = 13
const unused1 = 14
const chorus_effects_send = 15
const reverb_effects_send = 16
const pan = 17
const unused2 = 18
const unused3 = 19
const unused4 = 20
const delay_mod_lfo = 21
const freq_mod_lfo = 22
const delay_vib_lfo = 23
const freq_vib_lfo = 24
const delay_mod_env = 25
const attack_mod_env = 26
const hold_mod_env = 27
const decay_mod_env = 28
const sustain_mod_env = 29
const release_mod_env = 30
const keynum_to_mod_env_hold = 31
const keynum_to_mod_env_decay = 32
const delay_vol_env = 33
const attack_vol_env = 34
const hold_vol_env = 35
const decay_vol_env = 36
const sustain_vol_env = 37
const release_vol_env = 38
const keynum_to_vol_env_hold = 39
const keynum_to_vol_env_decay = 40
const instrument = 41
const reserved1 = 42
const key_range = 43
const vel_range = 44
const startloop_addrs_coarse_offset = 45
const keynum = 46
const velocity = 47
const initial_attenuation = 48
const reserved2 = 49
const endloop_addrs_coarse_offset = 50
const coarse_tune = 51
const fine_tune = 52
const sample_id = 53
const sample_modes = 54
const reserved3 = 55
const scale_tuning = 56
const exclusive_class = 57
const overriding_root_key = 58
const unused5 = 59
const end_oper = 60

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
	stream.big_endian = false
	f.close( )

	return self._read( stream )

"""
	配列から読み込み
	@param	data	PoolByteArray
	@return	smf
"""
func read_data( data ):
	var stream = StreamPeerBuffer.new( )
	stream.set_data_array( data )
	stream.big_endian = false
	return self._read( stream )

"""
	読み込み
	@param	input
	@return	SoundFont
"""
func _read( input ):
	self._check_chunk( input, "RIFF" )
	self._check_header( input, "sfbk" )

	var info = self._read_info( input )
	var sdta = self._read_sdta( input )
	var pdta = self._read_pdta( input )

	return {
		"info": info,
		"sdta": sdta,
		"pdta": pdta,
	}

"""
	チャンクチェック
	@param	input
	@param	hdr
"""
func _check_chunk( input, hdr ):
	self._check_header( input, hdr )
	input.get_32( )

"""
	ヘッダーチェック
	@param	input
	@param	hdr
"""
func _check_header( input, hdr ):
	var chk = input.get_string( 4 )
	if hdr != chk:
		print( "Doesn't exist " + hdr + " header" )
		breakpoint

"""
	チャンク読み込み
	@param	input
	@param	needs_header
	@param	chunk
"""
func _read_chunk( stream, needs_header = null ):
	var header = stream.get_string( 4 )
	if needs_header != null:
		if needs_header != header:
			print( "Doesn't exist " + needs_header + " header" )
			breakpoint
	var size = stream.get_u32( )
	var new_stream = StreamPeerBuffer.new( )
	new_stream.set_data_array( stream.get_partial_data( size )[1] )
	new_stream.big_endian = false

	return {
		"header": header,
		"size": size,
		"stream": new_stream,
	}

"""
	INFOチャンクを読み込む
	@param	stream
	@param	chunk
"""
func _read_info( stream ):
	var chunk = self._read_chunk( stream, "LIST" )
	self._check_header( chunk.stream, "INFO" )

	var info = {
		"ifil":null,
		"isng":null,
		"inam":null,

		"irom":null,
		"iver":null,
		"icrd":null,
		"ieng":null,
		"iprd":null,
		"icop":null,
		"icmt":null,
		"isft":null,
	}

	while 0 < chunk.stream.get_available_bytes( ):
		var sub_chunk = self._read_chunk( chunk.stream )
		match sub_chunk.header.to_lower( ):
			"ifil":
				info.ifil = self._read_version_tag( sub_chunk.stream )
			"isng":
				info.isng = sub_chunk.stream.get_string( sub_chunk.size )
			"inam":
				info.inam = sub_chunk.stream.get_string( sub_chunk.size )
			"irom":
				info.irom = sub_chunk.stream.get_string( sub_chunk.size )
			"iver":
				info.iver = self._read_version_tag( sub_chunk.stream )
			"icrd":
				info.icrd = sub_chunk.stream.get_string( sub_chunk.size )
			"ieng":
				info.ieng = sub_chunk.stream.get_string( sub_chunk.size )
			"iprd":
				info.iprd = sub_chunk.stream.get_string( sub_chunk.size )
			"icop":
				info.icop = sub_chunk.stream.get_string( sub_chunk.size )
			"icmt":
				info.icmt = sub_chunk.stream.get_string( sub_chunk.size )
			"isft":
				info.isft = sub_chunk.stream.get_string( sub_chunk.size )
			_:
				print( "unknown header" )
				breakpoint

	return info

"""
	バージョンタグを読み込む
	@param	stream
	@param	chunk
"""
func _read_version_tag( stream ):
	var major = stream.get_u16( )
	var minor = stream.get_u16( )

	return {
		"major": major,
		"minor": minor,
	}

"""
	SDTAを読み込む
	@param	stream
	@param	chunk
"""
func _read_sdta( stream ):
	var chunk = self._read_chunk( stream, "LIST" )
	self._check_header( chunk.stream, "sdta" )

	var smpl = self._read_chunk( chunk.stream, "smpl" )
	var smpl_bytes = smpl.stream.get_partial_data( smpl.size )[1]

	var sm24_bytes = null
	if 0 < chunk.stream.get_available_bytes( ):
		var sm24_chunk = self._read_chunk( chunk.stream, "sm24" )
		sm24_bytes = sm24_chunk.stream.get_partial_data( sm24_chunk.size )[1]

	return {
		"smpl": smpl_bytes,
		"sm24": sm24_bytes,
	}

"""
	PDTAを読み込む
	@param	stream
	@param	chunk
"""
func _read_pdta( stream ):
	var chunk = self._read_chunk( stream, "LIST" )
	self._check_header( chunk.stream, "pdta" )

	var phdr = self._read_pdta_phdr( chunk.stream )
	var pbag = self._read_pdta_bag( chunk.stream )
	var pmod = self._read_pdta_mod( chunk.stream )
	var pgen = self._read_pdta_gen( chunk.stream )
	var inst = self._read_pdta_inst( chunk.stream )
	var ibag = self._read_pdta_bag( chunk.stream )
	var imod = self._read_pdta_mod( chunk.stream )
	var igen = self._read_pdta_gen( chunk.stream )
	var shdr = self._read_pdta_shdr( chunk.stream )

	return {
		"phdr": phdr,
		"pbag": pbag,
		"pmod": pmod,
		"pgen": pgen,
		"inst": inst,
		"ibag": ibag,
		"imod": imod,
		"igen": igen,
		"shdr": shdr,
	}

"""
	phdr 読み込み
	@param	stream
	@param	chunk
"""
func _read_pdta_phdr( stream ):
	var chunk = self._read_chunk( stream, "phdr" )
	var phdrs = []

	while 0 < chunk.stream.get_available_bytes( ):
		var phdr = {
			"name": "",
			"preset": 0,
			"bank": 0,
			"preset_bag_index": 0,
			"library": 0,
			"genre": 0,
			"morphology": 0,
		}

		phdr.name = chunk.stream.get_string( 20 )
		phdr.preset = chunk.stream.get_u16( )
		phdr.bank = chunk.stream.get_u16( )
		phdr.preset_bag_index = chunk.stream.get_u16( )
		phdr.library = chunk.stream.get_32( )
		phdr.genre = chunk.stream.get_32( )
		phdr.morphology = chunk.stream.get_32( )

		phdrs.append( phdr )

	return phdrs

"""
	*bag読み込み
	@param	stream
	@param	chunk
"""
func _read_pdta_bag( stream ):
	var chunk = self._read_chunk( stream )
	var bags = []

	if chunk.header.substr( 1, 3 ) != "bag":
		print( "Doesn't exist *bag header." )
		breakpoint

	while 0 < chunk.stream.get_available_bytes( ):
		var bag = {
			"gen_ndx": 0,
			"mod_ndx": 0,
		}
	
		bag.gen_ndx = chunk.stream.get_u16( )
		bag.mod_ndx = chunk.stream.get_u16( )
		bags.append( bag )

	return bags

"""
	*mod読み込み
	@param	stream
	@param	chunk
"""
func _read_pdta_mod( stream ):
	var chunk = self._read_chunk( stream )
	var mods = []

	if chunk.header.substr( 1, 3 ) != "mod":
		print( "Doesn't exist *mod header." )
		breakpoint

	while 0 < chunk.stream.get_available_bytes( ):
		var mod = {
			"src_oper": null,
			"dest_oper": 0,
			"amount": 0,
			"amt_src_oper": null,
			"trans_oper": 0,
		}
	
		mod.src_oper = self._read_pdta_modulator( chunk.stream.get_u16( ) )
		mod.dest_oper = chunk.stream.get_u16( )
		mod.amount = chunk.stream.get_u16( )
		mod.amt_src_oper = self._read_pdta_modulator( chunk.stream.get_u16( ) )
		mod.trans_oper = chunk.stream.get_u16( )
		mods.append( mod )

	return mods

"""
	PDTA-Modulator 読み込み
	@param	stream
	@param	chunk
"""
func _read_pdta_modulator( u ):
	return {
		"type": ( u >> 10 ) & 0x3f,
		"direction": ( u >> 8 ) & 0x01,
		"polarity": ( u >> 9 ) & 0x01,
		"controller": u & 0x7f,
		"controllerPallete": ( u >> 7 ) & 0x01,
	}

"""
	gen 読み込み
	@param	stream
	@param	chunk
"""
func _read_pdta_gen( stream ):
	var chunk = self._read_chunk( stream )
	var gens = []

	if chunk.header.substr( 1, 3 ) != "gen":
		print( "Doesn't exist *gen header." )
		breakpoint

	while 0 < chunk.stream.get_available_bytes( ):
		var gen = {
			"gen_oper": 0,
			"amount": 0,
		}
	
		gen.gen_oper = chunk.stream.get_u16( )
		gen.amount = chunk.stream.get_u16( )
		gens.append( gen )

	return gens

"""
	inst読み込み
	@param	stream
	@param	chunk
"""
func _read_pdta_inst( stream ):
	var chunk = self._read_chunk( stream, "inst" )
	var insts = []

	while 0 < chunk.stream.get_available_bytes( ):
		var inst = {
			"name": "",
			"inst_bag_ndx": 0,
		}
	
		inst.name = chunk.stream.get_string( 20 )
		inst.inst_bag_ndx = chunk.stream.get_u16( )
		insts.append( inst )

	return insts

"""
	shdr 読み込み
	@param	stream
	@param	chunk
"""
func _read_pdta_shdr( stream ):
	var chunk = self._read_chunk( stream, "shdr" )
	var shdrs = []

	while 0 < chunk.stream.get_available_bytes( ):
		var shdr = {
			"name": "",
			"start": 0,
			"end": 0,
			"start_loop": 0,
			"end_loop": 0,
			"sample_rate": 0,
			"original_key": 0,
			"pitch_correction": 0,
			"sample_link": 0,
			"sample_type": 0,
		}
	
		shdr.name = chunk.stream.get_string( 20 )
		shdr.start = chunk.stream.get_u32( )
		shdr.end = chunk.stream.get_u32( )
		shdr.start_loop = chunk.stream.get_u32( )
		shdr.end_loop = chunk.stream.get_u32( )
		shdr.sample_rate = chunk.stream.get_u32( )
		shdr.original_key = chunk.stream.get_u8( )
		shdr.pitch_correction = chunk.stream.get_8( )
		shdr.sample_link = chunk.stream.get_u16( )
		shdr.sample_type = chunk.stream.get_u16( )
		shdrs.append( shdr )

	return shdrs
