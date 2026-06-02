extends Node

const TRACK_MAP := {
	"menu": "res://assets/music/bgm_menu.ogg",
	"vn": "res://assets/music/bgm_vn.mp3",
	"investigation": "res://assets/music/bgm_investigation.ogg",
	"deduction": "res://assets/music/bgm_deduction.ogg",
}

const FADE_DURATION := 2.0
const DEFAULT_VOLUME_DB := -10.0
const SILENT_DB := -80.0

var _track_a: AudioStreamPlayer
var _track_b: AudioStreamPlayer
var _current_track: AudioStreamPlayer
var _current_path: String = ""
var _fade_tween: Tween
var _stream_cache: Dictionary = {}
var _voice_player: AudioStreamPlayer
var _voice_cache: Dictionary = {}

func _ready() -> void:
	_track_a = AudioStreamPlayer.new()
	_track_b = AudioStreamPlayer.new()
	_track_a.volume_db = SILENT_DB
	_track_b.volume_db = SILENT_DB
	add_child(_track_a)
	add_child(_track_b)
	_current_track = _track_a

	_voice_player = AudioStreamPlayer.new()
	_voice_player.volume_db = -2.0
	_voice_player.bus = "Master"
	add_child(_voice_player)

func play_bgm(track_name: String) -> void:
	var path: String = TRACK_MAP.get(track_name, "")
	if path.is_empty() or path == _current_path:
		return
	_current_path = path
	var stream: AudioStream = _load_audio(path)
	if stream == null:
		push_warning("[AudioManager] Failed to load BGM: " + path)
		_current_path = ""
		return
	_crossfade_to(stream)

func fade_out() -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(_current_track, "volume_db", SILENT_DB, FADE_DURATION)
	_fade_tween.tween_callback(_current_track.stop)
	_current_path = ""

func stop_bgm() -> void:
	_track_a.stop()
	_track_b.stop()
	_current_path = ""

func _load_audio(res_path: String) -> AudioStream:
	if res_path in _stream_cache:
		return _stream_cache[res_path]

	var abs_path := ProjectSettings.globalize_path(res_path)
	var stream: AudioStream = null

	if res_path.ends_with(".ogg"):
		stream = AudioStreamOggVorbis.load_from_file(abs_path)
		if stream:
			(stream as AudioStreamOggVorbis).loop = true
	elif res_path.ends_with(".mp3"):
		var file := FileAccess.open(res_path, FileAccess.READ)
		if file:
			var mp3 := AudioStreamMP3.new()
			mp3.data = file.get_buffer(file.get_length())
			mp3.loop = true
			file.close()
			stream = mp3

	if stream:
		_stream_cache[res_path] = stream
	return stream

func play_voice(res_path: String) -> void:
	stop_voice()
	var stream := _load_voice(res_path)
	if stream == null:
		return
	_voice_player.stream = stream
	_voice_player.play()

func stop_voice() -> void:
	if _voice_player.playing:
		_voice_player.stop()

func is_voice_playing() -> bool:
	return _voice_player.playing

func _load_voice(res_path: String) -> AudioStream:
	if res_path in _voice_cache:
		return _voice_cache[res_path]

	var abs_path := ProjectSettings.globalize_path(res_path)
	if not FileAccess.file_exists(abs_path):
		return null

	var file := FileAccess.open(abs_path, FileAccess.READ)
	if file == null:
		return null
	var mp3 := AudioStreamMP3.new()
	mp3.data = file.get_buffer(file.get_length())
	mp3.loop = false
	file.close()
	_voice_cache[res_path] = mp3
	return mp3

func _crossfade_to(stream: AudioStream) -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()

	var next_track := _track_b if _current_track == _track_a else _track_a
	next_track.stream = stream
	next_track.volume_db = SILENT_DB
	next_track.play()

	_fade_tween = create_tween().set_parallel(true)
	_fade_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)

	if _current_track.playing:
		_fade_tween.tween_property(_current_track, "volume_db", SILENT_DB, FADE_DURATION)
	_fade_tween.tween_property(next_track, "volume_db", DEFAULT_VOLUME_DB, FADE_DURATION)

	var old_track := _current_track
	_current_track = next_track
	_fade_tween.chain().tween_callback(old_track.stop)
