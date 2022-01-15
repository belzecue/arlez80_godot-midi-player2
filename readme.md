# Godot MIDI Player

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/E1E44AWTA)

Software MIDI player library for Godot Engine 3.4 later

* Changes play speed.
* Set tempo.
* Emit on some events (tempo change, appears lyric ...)
* You can control like AudioStreamPlayer.

## Try it

1. Copy *.mid under "res://"
2. Copy *.sf2 under "res://"
3. Set MIDI path to MidiPlayer "file" parameter.
4. Set SoundFont path to MidiPlayer "soundfont" parameter.
5. call play() method

## How to use

* See [wiki](https://bitbucket.org/arlez80/godot-midi-player/wiki/)

### Demo

* [download](https://bitbucket.org/arlez80/godot-midi-player/downloads/demo.zip)
    * This demo can get MIDIInput events. You can play using MIDI keyboards!
* BGM "failyland_gm.mid" from [IvyMaze]( http://ivymaze.sakura.ne.jp/ )
* Youtube: [Demo #1](https://www.youtube.com/watch?v=SdrU4uRepVs)
* Youtube: [Demo #2](https://www.youtube.com/watch?v=nn21P3eI4hs)
* Youtube: [Demo #3](https://www.youtube.com/watch?v=dAYfFH-Fq2o)

## Hint

* Set false to `GodotMIDIPlayer.load_all_voices_from_soundfont` to load voices for program change message in MIDI sequence.
    * of course, `GodotMIDIPlayer.load_all_voices_from_soundfont = true` will be very slow.
* SMF format 0 loading faster than SMF format 1.
    * because format 1 data will be convert to format 0 in the player.

## TODO

* See [issues]( https://bitbucket.org/arlez80/godot-midi-player/issues )

## Not TODO

* Supports play format 2
    * SMF.gd can read it. but I will not implement it to MIDI Player.

## License

MIT License

## Author

* @arlez80 あるる / きのもと 結衣 ( Yui Kinomoto )
