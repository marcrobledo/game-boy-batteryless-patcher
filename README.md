Game Boy battery-less patching for bootleg cartridges
=====================================================


Some Game Boy bootleg cartridges made nowadays have no battery in their PCBs. Instead, they use a single Flash ROM that stores both the game and the savegame.<br/>
Pirate cartridge sellers patch the ROMs they are going to sell so the games redirect reads/writes calls from/to SRAM and use the Flash ROM instead.

This [RGBDS](https://github.com/gbdev/rgbds) skeleton project allows you to create your own battery-less patches for your Game Boy ROMs, so you can reflash a bootleg cartridge with your favorite game and keep its loading/saving features working.

It's based on [BennVennElectronic's tutorial](https://www.youtube.com/watch?v=l2bx-udTN84).<br/>
All this does is to automate and ease the process by making the most of RGBDS's [RGBLINK overlaying features](https://rgbds.gbdev.io/docs/v0.7.0/rgblink.1#O).<br/>Still, Game Boy hardware and debugging knowledge is needed because user will need to find some offsets, free RAM sections, etc, where our new code will be stored.

For now, it's only compatible with WR/AAA/A9 cart types and 64kb flashable sector size. But code should be easily scalable to other types if somebody does the reverse engineer needed for them.

Thanks to BennVennElectronic and Lesserkuma for their help!




How to
------
1. Get [RGBDS](https://rgbds.gbdev.io/install) and unzip it at `rgbds` folder.
2. Place the game you are going to patch as `roms/input.gbc` file.
3. Read `src/settings.asm` carefully and edit it, filling all needed offsets and constants for your game.
4. Compile with `assemble.bat` (Windows) or `assemble.sh` (Unix).
5. If there were no errors, a ROM `roms/output.gbc` will be created.
6. Flash your bootleg cartridge with the new generated ROM.

Note: when saving, the game might freeze a few frames. This is normal, it's just the cheap Flash ROM chip doing its magic!





Examples
--------
You can find some `settings.asm` template examples for some ROM hacks and translations in `examples/` folder.<br/>
Just replace the `src/settings.asm` files with any of them.
