extends Node
## Every sound is synthesised at startup, so the repo ships zero audio files.

const RATE := 22050

var _bank: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var _music_stream: AudioStreamWAV


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 14:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	_bank["blip"] = _tone(880.0, 0.07, 0, 0.0, 0.5, 18.0)
	_bank["click"] = _tone(520.0, 0.05, 1, 0.0, 0.4, 30.0)
	_bank["coin"] = _cat([_tone(988.0, 0.07, 1, 0.0, 0.5, 10.0), _tone(1319.0, 0.22, 1, 0.0, 0.5, 8.0)])
	_bank["deliver"] = _cat([_tone(523.0, 0.1, 1, 0.0, 0.5, 6.0), _tone(659.0, 0.1, 1, 0.0, 0.5, 6.0), _tone(784.0, 0.1, 1, 0.0, 0.5, 6.0), _tone(1047.0, 0.4, 1, 0.0, 0.5, 5.0)])
	_bank["thud"] = _tone(110.0, 0.28, 0, -70.0, 0.9, 9.0, 0.35)
	_bank["stamp"] = _cat([_tone(160.0, 0.12, 0, -90.0, 0.9, 14.0, 0.5), _tone(90.0, 0.2, 0, -30.0, 0.9, 12.0, 0.3)])
	_bank["scream"] = _tone(520.0, 0.9, 2, 520.0, 0.5, 2.5, 0.0, 14.0)
	_bank["caw"] = _cat([_tone(700.0, 0.12, 1, -250.0, 0.5, 6.0, 0.15), _tone(620.0, 0.16, 1, -250.0, 0.5, 6.0, 0.15)])
	_bank["squelch"] = _tone(260.0, 0.35, 0, -180.0, 0.7, 5.0, 0.3, 24.0)
	_bank["whoosh"] = _tone(300.0, 0.4, 0, 500.0, 0.2, 3.5, 1.0)
	_bank["roar"] = _tone(95.0, 1.0, 2, -35.0, 0.9, 1.8, 0.4, 18.0)
	_bank["bell"] = _cat([_tone(1180.0, 0.9, 0, 0.0, 0.5, 3.0), _tone(1770.0, 0.7, 0, 0.0, 0.25, 3.5)])
	_bank["hurt"] = _tone(420.0, 0.28, 2, -300.0, 0.6, 5.0)
	_bank["boom"] = _tone(80.0, 0.8, 0, -60.0, 0.9, 3.0, 0.8)
	_bank["splash"] = _tone(500.0, 0.5, 0, -300.0, 0.3, 4.0, 1.0)
	_bank["yeet"] = _tone(250.0, 0.7, 2, 900.0, 0.5, 2.0, 0.0, 6.0)
	_bank["error"] = _cat([_tone(220.0, 0.12, 2, 0.0, 0.5, 6.0), _tone(160.0, 0.2, 2, 0.0, 0.5, 6.0)])
	_bank["pop"] = _tone(600.0, 0.1, 0, 400.0, 0.6, 20.0)
	_bank["clip"] = _cat([_tone(1200.0, 0.04, 1, 0.0, 0.4, 30.0), _tone(1600.0, 0.08, 1, 0.0, 0.4, 20.0)])
	_music = AudioStreamPlayer.new()
	_music.volume_db = -14.0
	add_child(_music)
	_music_stream = _make_shanty()
	_music.stream = _music_stream
	_music.play()


func play(sound: String, vol_db := 0.0, pitch := 1.0) -> void:
	if not _bank.has(sound):
		return
	for p in _pool:
		if not p.playing:
			p.stream = _bank[sound]
			p.volume_db = vol_db - 4.0
			p.pitch_scale = pitch * randf_range(0.97, 1.03)
			p.play()
			return


func music_volume(db: float) -> void:
	_music.volume_db = db


# wave: 0 sine, 1 square-ish, 2 saw. sweep adds Hz over the duration.
func _tone(freq: float, dur: float, wave: int, sweep := 0.0, vol := 0.5, decay := 5.0, noise := 0.0, vibrato := 0.0) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	var seed_v := 1234567
	for i in n:
		var t := float(i) / RATE
		var u := t / dur
		var f := freq + sweep * u + (sin(t * 38.0) * vibrato * 10.0 if vibrato > 0.0 else 0.0)
		phase += TAU * f / RATE
		var s := 0.0
		match wave:
			0:
				s = sin(phase)
			1:
				s = 1.0 if sin(phase) > 0.0 else -1.0
				s *= 0.5
			2:
				s = fmod(phase / TAU, 1.0) * 2.0 - 1.0
				s *= 0.7
		if noise > 0.0:
			seed_v = (seed_v * 1103515245 + 12345) & 0x7fffffff
			s = lerpf(s, (float(seed_v) / 1073741823.5) - 1.0, noise)
		var env := exp(-decay * u) * minf(1.0, t * 220.0)
		var v := clampi(int(s * env * vol * 32000.0), -32768, 32767)
		data.encode_s16(i * 2, v)
	return _wav(data)


func _wav(data: PackedByteArray, loop := false) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = data.size() / 2
	return w


func _cat(streams: Array) -> AudioStreamWAV:
	var all := PackedByteArray()
	for s in streams:
		all.append_array((s as AudioStreamWAV).data)
	return _wav(all)


# A drunken little D-dorian shanty. Plucked melody over a boom-chick bass.
func _make_shanty() -> AudioStreamWAV:
	var bpm := 112.0
	var step := 60.0 / bpm / 2.0
	var mel := [62, 0, 65, 67, 69, 0, 67, 65, 62, 0, 65, 69, 72, 0, 69, 0,
		67, 0, 69, 72, 74, 0, 72, 69, 67, 0, 65, 62, 64, 0, 62, 0]
	var bass := [50, 0, 57, 0, 50, 0, 57, 0, 55, 0, 62, 0, 55, 0, 62, 0,
		53, 0, 60, 0, 53, 0, 60, 0, 52, 0, 59, 0, 50, 0, 57, 0]
	var total := int(step * mel.size() * RATE)
	var buf := PackedFloat32Array()
	buf.resize(total)
	for i in mel.size():
		var start := int(i * step * RATE)
		if mel[i] > 0:
			_pluck(buf, start, 440.0 * pow(2.0, (mel[i] - 69) / 12.0), 0.32, 7.0, 0.5)
		if bass[i] > 0:
			_pluck(buf, start, 440.0 * pow(2.0, (bass[i] - 69) / 12.0), 0.5, 5.0, 0.45)
	var data := PackedByteArray()
	data.resize(total * 2)
	for i in total:
		data.encode_s16(i * 2, clampi(int(buf[i] * 30000.0), -32768, 32767))
	return _wav(data, true)


func _pluck(buf: PackedFloat32Array, start: int, freq: float, dur: float, decay: float, vol: float) -> void:
	var n := int(dur * RATE)
	for i in n:
		var idx := start + i
		if idx >= buf.size():
			break
		var t := float(i) / RATE
		var s := sin(TAU * freq * t) + 0.35 * sin(TAU * freq * 2.0 * t) * exp(-8.0 * t) + 0.2 * sin(TAU * freq * 3.0 * t) * exp(-12.0 * t)
		buf[idx] += s * exp(-decay * t / dur) * minf(1.0, t * 300.0) * vol * 0.4
