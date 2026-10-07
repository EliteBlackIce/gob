extends Node
## Every sound is synthesised at startup, so the repo ships zero audio files.

const RATE := 22050

var _bank: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var _music_stream: AudioStreamWAV
var _amb: AudioStreamPlayer
var _amb_tw: Tween
var _track := "tavern"
var _tracks := {}


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
	_bank["step"] = _tone(150.0, 0.07, 0, -70.0, 0.4, 20.0, 0.75)
	_bank["clip"] = _cat([_tone(1200.0, 0.04, 1, 0.0, 0.4, 30.0), _tone(1600.0, 0.08, 1, 0.0, 0.4, 20.0)])
	_bank["swing"] = _tone(380.0, 0.16, 0, 700.0, 0.25, 6.0, 0.9)
	_bank["hit"] = _cat([_tone(190.0, 0.05, 0, -90.0, 0.8, 22.0, 0.6), _tone(120.0, 0.12, 0, -60.0, 0.7, 14.0, 0.3)])
	_bank["crit"] = _cat([_tone(1400.0, 0.05, 1, -600.0, 0.5, 20.0), _tone(160.0, 0.14, 0, -100.0, 0.9, 12.0, 0.5)])
	_bank["block"] = _cat([_tone(900.0, 0.04, 1, -200.0, 0.5, 30.0, 0.3), _tone(240.0, 0.16, 1, -120.0, 0.5, 14.0)])
	_bank["parry"] = _cat([_tone(1500.0, 0.05, 1, 0.0, 0.5, 20.0), _tone(2000.0, 0.25, 0, 0.0, 0.45, 6.0)])
	_bank["roll"] = _tone(220.0, 0.3, 0, 260.0, 0.22, 4.0, 1.0)
	_bank["loot"] = _cat([_tone(1046.0, 0.06, 1, 0.0, 0.4, 10.0), _tone(1568.0, 0.1, 1, 0.0, 0.4, 8.0)])
	_bank["loot_rare"] = _cat([_tone(784.0, 0.08, 1, 0.0, 0.45, 8.0), _tone(1046.0, 0.08, 1, 0.0, 0.45, 8.0), _tone(1318.0, 0.08, 1, 0.0, 0.45, 8.0), _tone(1568.0, 0.35, 1, 0.0, 0.5, 4.0)])
	_bank["loot_epic"] = _cat([_tone(523.0, 0.1, 1, 0.0, 0.5, 6.0), _tone(784.0, 0.1, 1, 0.0, 0.5, 6.0), _tone(1046.0, 0.1, 1, 0.0, 0.5, 6.0), _tone(1318.0, 0.1, 1, 0.0, 0.5, 6.0), _tone(1568.0, 0.2, 1, 0.0, 0.5, 5.0), _tone(2093.0, 0.7, 0, 0.0, 0.55, 3.0)])
	_bank["levelup"] = _cat([_tone(523.0, 0.09, 1, 0.0, 0.45, 8.0), _tone(659.0, 0.09, 1, 0.0, 0.45, 8.0), _tone(784.0, 0.09, 1, 0.0, 0.45, 8.0), _tone(1046.0, 0.5, 0, 0.0, 0.55, 3.0)])
	_bank["chest"] = _cat([_tone(120.0, 0.12, 0, -40.0, 0.7, 10.0, 0.5), _tone(700.0, 0.3, 1, 300.0, 0.3, 6.0)])
	_bank["door"] = _tone(70.0, 0.55, 0, -25.0, 0.9, 4.0, 0.6)
	_bank["arrow"] = _tone(900.0, 0.12, 1, -500.0, 0.3, 10.0, 0.3)
	_bank["fire"] = _tone(260.0, 0.35, 2, -100.0, 0.35, 4.0, 0.8)
	_bank["spore"] = _tone(150.0, 0.3, 0, 120.0, 0.5, 6.0, 0.4, 20.0)
	_bank["bone"] = _cat([_tone(700.0, 0.03, 1, 0.0, 0.5, 40.0, 0.6), _tone(520.0, 0.05, 1, 0.0, 0.4, 30.0, 0.5), _tone(860.0, 0.04, 1, 0.0, 0.4, 30.0, 0.6)])
	_bank["squish"] = _tone(180.0, 0.22, 0, 220.0, 0.6, 8.0, 0.2, 14.0)
	_bank["beep"] = _tone(1100.0, 0.06, 1, 0.0, 0.4, 14.0)
	_bank["potion"] = _cat([_tone(300.0, 0.08, 0, 200.0, 0.5, 8.0), _tone(400.0, 0.08, 0, 200.0, 0.5, 8.0), _tone(560.0, 0.2, 0, 200.0, 0.5, 6.0)])
	_bank["boss"] = _cat([_tone(70.0, 0.9, 2, -20.0, 0.9, 1.5, 0.3, 10.0), _tone(52.0, 0.9, 2, -10.0, 0.9, 1.5, 0.3, 12.0)])
	_bank["shrine"] = _cat([_tone(440.0, 0.2, 0, 220.0, 0.4, 3.0), _tone(660.0, 0.5, 0, 220.0, 0.4, 3.0)])
	_music = AudioStreamPlayer.new()
	_music.volume_db = -14.0
	add_child(_music)
	_music_stream = _make_shanty()
	_music.stream = _music_stream
	_music.play()
	_amb = AudioStreamPlayer.new()
	_amb.stream = _make_ocean()
	_amb.volume_db = -60.0
	add_child(_amb)


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


## Seamless ocean wash for the island. Fades in/out so scene swaps don't pop.
func ambience(on: bool, db := -17.0) -> void:
	if _amb_tw != null and _amb_tw.is_valid():
		_amb_tw.kill()
	if on and not _amb.playing:
		_amb.play()
	_amb_tw = create_tween()
	_amb_tw.tween_property(_amb, "volume_db", db if on else -60.0, 1.2)
	if not on:
		_amb_tw.tween_callback(_amb.stop)


func _make_ocean() -> AudioStreamWAV:
	var secs := 6.0
	var n := int(secs * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var lp := 0.0
	var seed_v := 987654
	for i in n:
		var t := float(i) / RATE
		seed_v = (seed_v * 1103515245 + 12345) & 0x7fffffff
		var white := (float(seed_v) / 1073741823.5) - 1.0
		lp += (white - lp) * 0.08
		var swell := 0.5 + 0.5 * sin(TAU * t / secs * 1.0 - 1.2)
		var swell2 := 0.5 + 0.5 * sin(TAU * t / secs * 2.0)
		var amp := 0.25 + 0.55 * swell * swell + 0.2 * swell2
		data.encode_s16(i * 2, clampi(int(lp * amp * 9000.0), -32768, 32767))
	return _wav(data, true)


func music_volume(db: float) -> void:
	_music.volume_db = db


## Swap the background track: "tavern" (shanty), "dungeon" (brooding) or "boss" (driving).
func set_track(track: String) -> void:
	if track == _track:
		return
	_track = track
	if not _tracks.has(track):
		match track:
			"dungeon":
				_tracks[track] = _make_dungeon()
			"boss":
				_tracks[track] = _make_boss()
			_:
				_tracks[track] = _music_stream
	_music.stream = _tracks[track]
	_music.play()


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


func _render_track(mel: Array, bass: Array, bpm: float, mel_dur: float, bass_dur: float, mel_decay: float, mel_vol: float, bass_vol: float) -> AudioStreamWAV:
	var step := 60.0 / bpm / 2.0
	var total := int(step * mel.size() * RATE)
	var buf := PackedFloat32Array()
	buf.resize(total)
	for i in mel.size():
		var start := int(i * step * RATE)
		if mel[i] > 0:
			_pluck(buf, start, 440.0 * pow(2.0, (mel[i] - 69) / 12.0), mel_dur, mel_decay, mel_vol)
		if bass[i] > 0:
			_pluck(buf, start, 440.0 * pow(2.0, (bass[i] - 69) / 12.0), bass_dur, 3.0, bass_vol)
	var data := PackedByteArray()
	data.resize(total * 2)
	for i in total:
		data.encode_s16(i * 2, clampi(int(buf[i] * 30000.0), -32768, 32767))
	return _wav(data, true)


func _make_dungeon() -> AudioStreamWAV:
	var mel := [0, 0, 69, 0, 0, 72, 0, 0, 76, 0, 0, 72, 0, 71, 0, 0,
		0, 0, 67, 0, 0, 71, 0, 0, 74, 0, 0, 71, 0, 69, 0, 0,
		0, 0, 65, 0, 0, 69, 0, 0, 72, 0, 0, 69, 0, 68, 0, 0,
		0, 0, 64, 0, 0, 68, 0, 0, 71, 0, 76, 0, 71, 0, 68, 0]
	var bass := [45, 0, 0, 0, 0, 0, 0, 0, 45, 0, 0, 0, 0, 0, 0, 0,
		43, 0, 0, 0, 0, 0, 0, 0, 43, 0, 0, 0, 0, 0, 0, 0,
		41, 0, 0, 0, 0, 0, 0, 0, 41, 0, 0, 0, 0, 0, 0, 0,
		40, 0, 0, 0, 0, 0, 0, 0, 40, 0, 0, 0, 0, 0, 0, 0]
	return _render_track(mel, bass, 76.0, 0.9, 1.6, 3.5, 0.34, 0.5)


func _make_boss() -> AudioStreamWAV:
	var mel := [0, 0, 69, 0, 0, 0, 72, 0, 0, 0, 70, 0, 0, 0, 69, 0,
		0, 0, 67, 0, 0, 0, 70, 0, 0, 0, 68, 0, 0, 0, 67, 0]
	var bass := [38, 38, 0, 38, 38, 0, 38, 41, 38, 38, 0, 38, 36, 0, 38, 0,
		36, 36, 0, 36, 36, 0, 36, 39, 36, 36, 0, 36, 34, 0, 36, 0]
	return _render_track(mel, bass, 150.0, 0.25, 0.3, 8.0, 0.45, 0.55)


func _pluck(buf: PackedFloat32Array, start: int, freq: float, dur: float, decay: float, vol: float) -> void:
	var n := int(dur * RATE)
	for i in n:
		var idx := start + i
		if idx >= buf.size():
			break
		var t := float(i) / RATE
		var s := sin(TAU * freq * t) + 0.35 * sin(TAU * freq * 2.0 * t) * exp(-8.0 * t) + 0.2 * sin(TAU * freq * 3.0 * t) * exp(-12.0 * t)
		buf[idx] += s * exp(-decay * t / dur) * minf(1.0, t * 300.0) * vol * 0.4
