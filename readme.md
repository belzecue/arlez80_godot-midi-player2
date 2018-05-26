# Godot MIDI Player

Software MIDI player library for Godot Engine 3.

* Can changes play speed.
* Can control as AudioSamplePlayer.

## Try it

+ Copy test.mid to "res://"

### Add instruments

+ Add AudioStreamPlayer node renamed program number (0 based) to TestScene/MidiPlayer/Instruments of TestScene.tscn.

## How to use

### SMF.gd

```
var smf_reader = preload( "path/to/SMF.gd" ).new( )
var smf = smf_reader.read_file( "path/to/smf.mid" )
print( smf )
```

### MidiPlayer.tscn

TODO

## TODO

* See [issues]( https://bitbucket.org/arlez80/godot-midi-player/issues )

## not TODO

* Supports format 2
* Implements some effects (Use godot's mixer!)

## Known Probrem

* Player's timebase is 1/60.
** It probably need 1/240 at least.

## License

MIT License
