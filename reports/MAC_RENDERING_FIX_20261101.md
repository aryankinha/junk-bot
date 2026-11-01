# Mac clarity fix

The portrait ratio determines composition, not inherently pixelation. Inspection found a 432×768 desktop window, disabled MSAA, no MSAA in preview SubViewports, and a 600×600 result portrait that could be enlarged on Retina displays. HiDPI was not explicitly disabled; Godot enables it by default.

Changed:
- Explicit HiDPI support and a larger desktop default, fitted to the usable Mac display area.
- Desktop 4× MSAA on the main viewport and both robot preview viewports.
- Desktop result portraits at 1200×1200.
- Existing Android MSAA setting and portrait-image budget preserved via mobile overrides.
- Existing canvas-items scaling retained; no low-resolution viewport stretching introduced.

References: [Godot multiple resolutions and HiDPI](https://docs.godotengine.org/en/stable/tutorials/rendering/multiple_resolutions.html), [Godot 3D antialiasing](https://docs.godotengine.org/en/stable/tutorials/3d/3d_antialiasing.html). MSAA addresses geometry edges; deliberately low-poly shapes and toon shading remain stylistic.

Validation: `results/mac_quality_checks.txt`, `results/mac_quality_checks.json`, `results/mac_quality_home.png`, `results/mac_quality_portrait.png`; full regression: `results/mac_quality_regression.txt` (25,155 checks, zero failures). Actual surface sizes can change when macOS constrains a window to the usable display area. The capture test reports image dimensions and the surface after OS resize separately.

Desktop GPU work increases with 4× MSAA and larger images; phone settings are unchanged. This short rendering check is not a sustained Mac/phone performance certification. Restart the running game from Godot to load the new project settings.
