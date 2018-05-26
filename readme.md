# Godot MIDI Player

Software MIDI player library for Godot Engine 3.

* Can changes play speed.
* Can control as AudioSamplePlayer.

I develop it for use embedding in game.

## Try it

+ Copy test.mid to "res://"

### Add instruments

+ Add AudioStreamPlayer node renamed program number (0 based) to TestScene/MidiPlayer/Instruments of TestScene.tscn.

(It will be change this method.)

### Demo / Screenshot

![screenshot](https://bitbucket.org/arlez80/godot-midi-player/raw/1e78bb018835c38ece7e7d1ff2c825e98d4b0a44/godot-midi-player.png "screenshot")

* [download](https://bitbucket.org/arlez80/godot-midi-player/downloads/demo.zip)

## How to use

### SMF.gd

Standard MIDI File reader

```
var smf_reader = preload( "path/to/SMF.gd" ).new( )
var smf = smf_reader.read_file( "path/to/smf.mid" )
print( smf )
```

### MidiPlayer.tscn

Software MIDI Player

* TODO / かきかけとちゅう

## TODO

* See [issues]( https://bitbucket.org/arlez80/godot-midi-player/issues )

## Not TODO

* Supports format 2
* Implements some effects (Use godot's mixer!)

## Known Problem

* Player's timebase is 1/60.
 * It probably need 1/240 at least.
* Pitch bend is buggy...

## License

MIT License

## Author

* @arlez80 あるる / きのもと 結衣
