# Hogwarts touch preview (build 4)

Enable Settings > Touch Mode > Touchpad, then On-Screen Controls > Hogwarts.
Disable Swap A/B and X/Y for the documented default Xbox bindings.
The selection currently applies globally, including Desktop streams. It does not
automatically detect games running inside Desktop or read game state/cooldowns.

The unfolded Duo layout uses approximately 9–11 mm button diameters and distances
from the lower edges. Calibration assumes a full-screen inner panel about
157.7 x 110.9 mm; the cover display uses a compact fallback.

- Touch empty space in the left 45% to create a floating movement stick. Release
  to hide it and send neutral input. RUN toggles L3 and clears when movement ends.
- Drag empty space on the right to send relative mouse movement for the camera.
  Gain is 1.5 mouse counts per UIKit point on both axes, without acceleration.
  Adjust mouse sensitivity in the game to taste. Lifting and touching again
  repositions the finger without moving the camera; taps do not click.
  Movement/buttons remain gamepad input; simultaneous mouse/gamepad handling
  and changing button prompts depend on the game.
- CAST sends a single RT pulse; P holds Y (Protego/Stupefy), B holds dodge,
  and A holds jump/confirm.
- 1/2/3/4 send RT + Y/B/A/X respectively. They refer to slots, not named spells.
- + is D-pad down (heal); R is D-pad left (Revelio).
- The ellipsis opens extra controls: interact, Ancient Magic, throw, tool wheel,
  aim, target lock, four spell-set chords, D-pad navigation, map, pause, and EXIT.
  EXIT disconnects the stream without issuing a quit-game command.

RT chords are serialized with a short trigger lead-in. Defensive/other held
buttons cancel queued chords and release RT before sending their input.
All overlay input is reset on app suspension, touch cancellation, size changes,
or removal from the window. Fractional mouse movement resets between gestures.

This is an experimental input implementation. CI verifies device compilation and
IPA contents only. Touch feel, spell timing, folds, and controller mappings have
not been tested on an iPhone, Simulator, or in the game.

Build 4: gold translucent controls; four spell slots arc around a larger CAST.
Dodge/jump sit below, Protego to the left. Whole groups scale and anchor inside
the safe area without individual clamping or minimum sizes collapsing columns.
Extra controls replace the right combat cluster while open. Minimap/health are
part of the streamed game image and are not repositioned by this overlay.
