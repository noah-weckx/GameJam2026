# Godot 4 Asset Guide

Use Godot-friendly source assets and keep layers or animation frames separate when they need independent movement or timing.

- `assets/sprites/characters/` and `assets/sprites/objects/`: Use `.png` for sprites and sprite sheets, especially when transparency is needed. Import sheets as textures and define animation frames with `SpriteFrames` or `AnimationPlayer`.
- `assets/backgrounds/static/`: Use `.jpg` for opaque, photographic backgrounds when smaller files are useful; use `.png` when transparency or lossless edges matter.
- `assets/backgrounds/parallax/`: Use separate `.png` images for each layer. Transparent areas let distant and foreground layers move independently with `Parallax2D`.
- `assets/backgrounds/dynamic/`: Use `.png` frame sequences or sprite sheets for animated backgrounds. Drive them with `AnimatedSprite2D` or `AnimationPlayer`; avoid GIF as a runtime animation format.
- `assets/audio/music/`: Use `.ogg` for compressed music and enable looping in the relevant Godot import or playback settings.
- `assets/audio/sfx/`: Use `.wav` for short effects where low-latency playback matters; use `.ogg` for longer effects where smaller files are preferable.
- `scenes/levels/` and `scenes/entities/`: Save reusable Godot scenes as `.tscn` files.
- `scripts/environment/` and `scripts/audio/`: Save Godot scripts as `.gd` files.

Godot imports common image and audio formats into its own runtime resources. Keep original source assets in the project and tune filtering, compression, looping, and animation in the Import dock as appropriate.
