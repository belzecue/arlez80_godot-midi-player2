# Godot MIDI Player

Software MIDI player library for Godot Engine 3.

* Changes play speed.
* Set tempo.
* Emit on some events (tempo change, appears lyric ...)
* Can control as AudioStreamPlayer.

I develop it for use embedding in game.

## Try it

1. Copy *.mid to "res://"
2. Copy *.sf2 to "res://"
3. Set MIDI path to MidiPlayer "file" parameter.
4. Set SoundFont path to MidiPlayer "soundfont" parameter.
5. Play

## How to use

* See [wiki](https://bitbucket.org/arlez80/godot-midi-player/wiki/)

### Demo / Screenshot

![screenshot](https://bitbucket.org/arlez80/godot-midi-player/raw/1e78bb018835c38ece7e7d1ff2c825e98d4b0a44/godot-midi-player.png "screenshot")

* [download](https://bitbucket.org/arlez80/godot-midi-player/downloads/demo.zip)

## TODO

* See [issues]( https://bitbucket.org/arlez80/godot-midi-player/issues )

## Not TODO

* Supports play format 2
* Implements some effects (Use godot's mixer!)

## Known Problem

* Player's timebase is 1/60. - It probably need 1/240 at least.
* Pitch bend is buggy...
* Sometimes appear petit noises.

## License

MIT License

## Author

* @arlez80 あるる / きのもと 結衣
