# Gradient Info

A [Transport Fever 3](https://transportfever3.com) mod that shows the gradient (grade, slope) of built tracks and the steepest climb of each rail line, so you can find sections that are too steep for your trains.

**Status:** prototype.

- **Terrain data layer:** also colors track segments, or tracks and roads, chosen in a dropdown, by their average gradient (green → yellow → red → black; tracks up to 9%, roads up to 20%; hold Shift for every 4 m), and shows gradients in a tooltip.
- **Line window:** a Line info card for rail lines, in the style of the game's own figures: round trip length, number of stops (average distance between them on hover), average speed including stops, and the steepest climb over the shortest platform's length (the vehicle store Performance rating needed on hover).
- **Train window:** the same card for the train's line, with the steepest climb over the train's length and, on hover, the Performance rating it requires next to the train's own.
- **Line manager:** for rail lines, a row below the line's statistics with the round trip length, the steepest climb and the Performance rating it needs.

## Repository layout

```
nulldozzer_gradients/       The mod itself (this folder is what the game loads)
  mod.json                   Technical definition: mod id, revision, scripts
  _metadata/modinfo.json     Name, description, tags shown in the Mod Hub
  content/gui/nulldozzer_gradients/
    terrain_layer_replacement.res.lua  Swaps the game's Terrain data layer for ours
    gradient_layer.script.tl Terrain layer wrapper, legend and coloring
    gradient_layer.css.lua   Legend layout
    gradient_tooltip.tl      Hover tooltip
    network_scan.tl          Finds track and road segments, kept between openings
    edge_profile.tl          Measures gradients along a segment
    gradient_scale.tl        Gradient to color
    line_gradient.*          Gradient card in the line window
    vehicle_gradient.*       Gradient card in the train window
    line_manager_climb.*     Climb row in the line manager's statistics
    line_climb.tl            A line's length and steepest climb
    store_performance.tl     The vehicle store's Performance ratings and train figures
    line_info_card.tl        Shared Line info card for the line and train windows
    line_route.tl            A line's route between stops, as height profiles
    climb_window.tl          Steepest climb over a given length
    *.d.tl                   Teal type definitions for the modules
tlconfig.lua, all_def.tl     Teal type-checking config for the editor
```

Everything outside `nulldozzer_gradients/` is development tooling and is not part of the mod.

## Local development

Link the mod folder into the game's staging area, so the game loads it straight from this repository. In PowerShell:

```powershell
New-Item -ItemType Junction `
  -Path "C:\Program Files (x86)\Steam\userdata\<steam-id>\3493540\local\staging_area\nulldozzer_gradients" `
  -Target "<path-to-this-repo>\nulldozzer_gradients"
```

Then start the game and enable **Gradient Info** in the mod selection when starting or loading a game. Open **Data Layers → Terrain** to see the gradients.

After editing scripts, exit to the main menu and load the save again. Edits to already loaded GUI scripts also apply with <kbd>AltGr</kbd>+<kbd>Shift</kbd>+<kbd>R</kbd> (debug mode); new files need the reload. The game log is `userdata/<steam-id>/3493540/local/crash_dump/stdout.txt`.

Turning on debug mode in the game's advanced settings enables extra tools for testing, such as the debug window (<kbd>AltGr</kbd>+<kbd>D</kbd>).

## Editor setup (optional)

For autocompletion and type checking in VS Code:

1. Install [Teal](https://github.com/teal-language/tl) (the `tl` compiler).
2. Install the recommended [Teal extension](https://marketplace.visualstudio.com/items?itemName=pdesaulniers.vscode-teal) and set the path to the `tl` executable in its settings.
3. If the game is not in the default Steam library, adjust the path in `tlconfig.lua`.

## References

- [TF3 Modding Manual](https://wiki.transportfever3.com/doku.php?id=modding:start)
- [Mod Definition](https://wiki.transportfever3.com/doku.php?id=modding:general:moddefinition) (`mod.json`, `modinfo.json`, `strings.json`)
- [Mod Parameters & Scripts](https://wiki.transportfever3.com/doku.php?id=modding:general:modscripts)
- [Guidelines & Requirements](https://wiki.transportfever3.com/doku.php?id=modding:general:guidelines)
- [Scripting API Reference](https://wiki.transportfever3.com/script-doc/)
