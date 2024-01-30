@icon("musicbox.svg")
extends AudioStreamPlayer
class_name MusicBox

signal song_loaded
@export
var buffer : AudioStream
func LoadSong(song: String):
	if not ResourceLoader.exists(song):
		print ("Failed to load %s; does not exist" % song)
		emit_signal("song_loaded")
		return
	ResourceLoader.load_threaded_request(song, "AudioStreme")
	var tree = get_tree()
	while ResourceLoader.load_threaded_get_status(song) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await tree.process_frame
	var status = ResourceLoader.load_threaded_get_status(song)
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		buffer = ResourceLoader.load_threaded_get(song)
	else:
		buffer = null
		print ("Failed to load %s" % song)
	emit_signal("song_loaded")
	return
	
signal faded_out
var fade_volume_zero = false
func FadeMusicOut(time := 0.25):
	var tween = get_tree().create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_method(SetFadeVolume, 1.0, 0.0, time)\
			.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	await tween.finished
	stop()
	fade_volume_zero = true
	emit_signal("faded_out")

func SetFadeVolume(v:float):
		v = clampf(v, 0, 1)
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("music box"), linear_to_db(v))
		
func SwitchToSong(song, fade_time:float=0.0):
	if song is String:
		if stream and song == stream.resource_path: 
			if fade_volume_zero:
				SetFadeVolume(1)
				fade_volume_zero = false
			if not playing:
				play()
			return
		LoadSong(song)
		await song_loaded
		if not buffer: return
	elif song is AudioStream:
		if song == stream: 
			if fade_volume_zero:
				SetFadeVolume(1)
				fade_volume_zero = false
			if not playing:
				play()
			return
		buffer = song
	else:
		print("_MUSIC.SwitchToSong failed; song is not a path to a song or audiostream")
		return
	if not buffer:
		print("_MUSIC.SwitchToSong failed; song did not load.")
		return
	if fade_time > 0.01:
		FadeMusicOut(fade_time)
		await faded_out
	stop()
	SetFadeVolume(1)
	fade_volume_zero = false
	stream = buffer
	play()
