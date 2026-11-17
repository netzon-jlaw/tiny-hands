# Archived pointers

Middle Child, Peace Sign, Thumbs Up and Rock On are parked here to cut testing effort.
The build script only bundles `Resources/Pointers/*.svg`, so these files are not in the app.

To restore one, move all its files (`name.svg`, `name-b.svg`, `name-c.svg` and the roll frames `name-rm1..4`, `name-rp1..4`) back to
`Resources/Pointers/`, add the case to `PointerStyle` in `Settings.swift`, and add it to the
switch in `PointerArt.make` with `height = base * 1.1; tilt = 0`.
