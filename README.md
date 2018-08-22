# norns
Sketches for the monome norns audio device

## Tests

This is a folder that contains various tests I'm doing to try out functions
of the norns. Sometimes you might find interesting stuff for edge-case
or hardware handling.

## Walkabout

This is a little 8x8 sequencer (8 sequences, 8 steps each) that allows quick
switching among sequences, auto-saves changes when sleeping or switching
sketches (to data/ddg/walkabout.data) and uses a cool little alt-driven
menu for selecting and setting things like run status, tempo and direction.

It's easiest to check out the video for this:

<a href="http://www.youtube.com/watch?feature=player_embedded&v=af6aXKQBDak
" target="_blank"><img src="http://img.youtube.com/vi/af6aXKQBDak/0.jpg"
alt="IMAGE ALT TEXT HERE" width="240" height="180" border="10" /></a>

v 1.1: Notes are output on MIDI, the first device encountered, channel 1, with
a gate time of 10 ms.
