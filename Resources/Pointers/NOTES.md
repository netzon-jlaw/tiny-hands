# Pointer art notes

The pointers are original SVG drawings of the "Mr Tiny Hand" toy: a small plastic hand on
a telescoping metal pointer, with one raised finger, a stubby thumb, the other fingers
folded into the fist, and a fat cuff that pushes onto a silver rod. They are drawn the way a
1930s rubber-hose cartoon (the look the game Cuphead revives) would draw that toy. Nothing
is traced from photos or from any cartoon, and no characters or logos are used.

## Style: ink and paint

- **View.** Every hand is a right hand seen from above with the palm down, the way the
  toy looks when it taps a screen under an overhead camera. We see the back of the hand.
  No finger pads, fingertip curls or palm creases can show. The Cat Paw is the top of a
  paw for the same reason, so it has claws and no pads.
- **One outline.** Each hand is a single continuous contour: the fingers, the stubs of
  the folded fingers, a pinch at the wrist and the rolled cuff are all part of it.
- **Layered digits.** Each raised finger, folded-finger stub and cat toe is also painted
  as its own form over the hand, far to near, with an outline that fades out toward its
  root. Upright, that outline lies on the hand's own contour except for a short run into
  the hand: that run is the seam between two digits. Turned, the nearer digit overlaps
  the next with one clean line. Seams are never drawn separately, so they cannot leave
  the notch they belong to. Where a nearer digit's line would run alongside a farther
  one's, only the nearer is drawn, and a scrap of line stranded by an overlap is dropped.
- **Fingers.** A raised finger is a sausage of nearly even width with a round tip and a
  slight bow. It flows into a round hand through a wide fillet, and every inside corner of
  the outline (thumb web, finger gaps, the dips between cat toes, the wrist pinch) is
  opened up to a soft U.
- **Folded fingers.** Seen from the back, a folded finger shows only its first segment:
  a short stub that bumps the outline, with the rest tucked underneath. All fingers root on
  one knuckle row across the top of the hand, so the stubs always sit side by side in a
  row next to whatever is raised. This holds on Thumbs Up too.
- **Folded thumb.** On Peace Sign, Rock On and Middle Child the thumb is tucked under
  the fist. It is drawn beneath the hand, so from above only the part that sticks out past
  the left edge shows, as a lobe with the hand's outline running over it.
- **Marks on the back.** Taken from the 1928 to 1931 references listed at the end:
  three short dart lines in the middle of the back, clear of the outline, fanning a
  little; the short seams between digits described above; and nothing else. Cat Paw has
  the same darts.
- **Ink line.** One even warm-black line, `#1B1410`, the same ink as the app's tap
  effects. The outline is about 2 units wide, a touch heavier (up to 2.4) on the lower
  right. Seams are the same weight, run a little way under the outline where they meet it,
  and taper at their free end. Darts are a touch lighter and thin toward both ends.
- **Paint.** Each hand is one flat colour: the toy's own colour mixed 22 percent toward a
  warm cream, `#E9D7B2`, so the set looks like aged cel paint. There is no shading, no
  highlight and no gradient in any hand.
- **Cuff.** A narrow rolled band, slightly fuller on one side. The seam where the wrist
  goes into it is one arc from wrist pinch to wrist pinch; there is a short crease tick at
  each side of the roll.
- **Digits.** These are cartoon hands, so they have a thumb and three fingers. High Five
  shows three fat fingers and a thumb.
- **Film look.** The files hold no grain. The app adds sepia, grain and a few faint dust
  specks at runtime and cycles the three boil frames at 12 fps.

## Pointer sets

Every hand set uses viewBox `0 0 100 140`, is drawn upright, and has a transparent
background. Coordinates are in viewBox units with the origin at the top left.

- **Hotspot** is the topmost inked point, at y = 2.0. It is at the same x in every frame
  of a hand, including the roll frames.
- **Cuff bottom-centre** is where the app hangs the stick. The ink ends at y 138. Upright,
  the cuff is centred on x 50, except on High Five (50.2) and Thumbs Up (54.4), which are
  slid right to keep a 1.5-unit margin. The generator stops with an error if a hand is too
  wide to fit the viewBox at full height. The app finds the cuff in each frame by scanning
  the bottom rows.
- **Comment.** Each file starts with `<!-- tip-x N cuff-centre-x N -->`, which `icon.py`
  reads.

| Menu name | File prefix | Hotspot (tip) | Art x range | Paint as drawn | Toy colour before the cream mix |
| --- | --- | --- | --- | --- | --- |
| Tiny Hand | `tiny-hand` | (41.9, 2.0) | 2.8 to 85.6 | `#55C4A3` | teal `#2BBF9F` |
| Middle Child | `middle-child` | (50.0, 2.0) | 16.4 to 78.8 | `#68A0BE` | petrol blue `#4490C2` |
| Peace Sign | `peace` | (30.0, 2.0) | 15.4 to 84.4 | `#B39ACB` | lavender `#A489D2` |
| Thumbs Up | `thumbs-up` | (19.7, 2.0) | 1.4 to 93.2 | `#F0C556` | butter yellow `#F2C03C` |
| Rock On | `rock-on` | (30.6, 2.0) | 15.6 to 84.6 | `#80BA71` | green `#63B25F` |
| High Five | `high-five` | (52.7, 2.0) | 1.6 to 95.4 | `#ED99A2` | pink `#EE889E` |
| Cat Paw | `cat-paw` | (32.8, 2.0) | 7.6 to 92.2 | `#A7CADB`, claws `#F6ECD2` | sky blue `#95C6E6` |

These were measured from a 700-pixel-tall NSImage render (alpha > 0.5). Every file runs
from y 2.0 to y 138.0.

The poses:

- **Tiny Hand.** Index finger up, a stubby thumb out to the left with a wide web between
  them, and the stubs of two folded fingers side by side to the right of the index,
  stepping down.
- **Middle Child.** Middle finger up, one folded finger's stub on each side of it, thumb
  tucked under on the left.
- **Peace Sign.** Two bowed fingers in a V, one folded finger's stub on the right, thumb
  tucked under.
- **Thumbs Up.** A short thumb with a fat bulb tip, rooted low on the left side of the
  hand and leaning well out, with the three folded fingers as a row of stubs across the
  top to its right. The thumb must stay shorter and fatter than a finger and break away
  from the hand's edge, or the pose reads as a pointing finger.
- **Rock On.** Index and little finger up, the one folded finger's stub as a dome between
  them, thumb tucked under.
- **High Five.** An open hand: three splayed fingers and a thumb.
- **Cat Paw.** The top of a paw: a fat mitt with four overlapping toes, a fat hooked cream
  claw on each, and darts. The tallest claw's tip is the hotspot.

### Boil frames (`-b`, `-c`)

The `name-b.svg` and `name-c.svg` files are redrawn frames for the 12 fps line boil. In
each one the outline moves by up to about 0.3 units, the ink weight wobbles differently
and the inner lines shift a little. The noise fades to zero around the fingertip and the
cuff bottom, so all three frames keep the same tip, top and bottom.

### Roll frames (`-rm1` to `-rm4`, `-rp1` to `-rp4`)

Each hand also has eight drawings of itself turned about its long axis: 11, 22, 33 and 44
degrees to the left (`-rm1` to `-rm4`) and to the right (`-rp1` to `-rp4`). The app shows
them when the pointer is flicked sideways (see `Sources/TinyHands/PointerMotion.swift`).

- **How they are made.** The generator gives every part of the hand a depth: the palm is
  an ellipsoid about half as deep as it is wide, fingers and stubs are round, a thumb held
  out sits a little below the back of the hand, a tucked thumb sits under it, and the cuff
  is nearly as deep as it is wide. A roll turns all of it about a vertical axis through the
  fingertip and redraws the outline from the turned positions.
- **Digits overlap.** The webbing between fingers and the rounding of inside corners are
  let go as the hand turns, so fingers that close up overlap instead of fusing. Digits are
  painted far to near: turning right brings the left side nearer.
- **The tucked thumb** lies under the hand, so it widens on a right turn and slides out
  of sight on a left turn. Once the strip still showing is thinner than the ink line it is
  left out altogether.
- **Marks travel with the surface.** Darts are lifted onto the rounded back of the hand
  and turned with it, so they drift toward the leading edge and bow with the turn; a dart
  nearing the outline shortens and is then left out. The cuff seam keeps the same arc in every
  frame. The cuff's crease ticks travel round the roll, and the one on the far side goes
  out of sight.
- **What stays fixed.** The fingertip does not move, because the axis passes through it.
  The viewBox, top and bottom are the same as the upright frame. The cuff shifts sideways
  by up to about 10 units (Thumbs Up, whose tip is furthest from the cuff's centre line),
  and the rod follows it.
- **Positive roll** (`-rp`) carries the top of the hand to the right.

## stick.svg

The stick has viewBox `0 0 24 400`, is drawn vertically, and the cuff end is at the top.
It has three tube sections, each with ink edges matched to the hands' line weight, flat
warm-silver paint `#CFC8B6`, one shadow tone `#A39B88` down the right third and one long
cream shine on the left.

| Section | y range | x range | Width |
| --- | --- | --- | --- |
| Top | 0 to 140 | 5.2 to 18.8 | 13.6 |
| Middle | 140 to 272 | 6.3 to 17.7 | 11.4 |
| Bottom | 272 to 400 | 7.4 to 16.6 | 9.2 |

- Each wider section ends in a puffy inked ring that stands 1.8 units proud of its tube.
- The tubes are much narrower than the viewBox, which keeps the rod about half as wide as
  the cuff, as on the real toy.
- The app scales the stick by its aspect ratio, so changing the viewBox width changes how
  fat the rod is next to the hand.

## app-icon.svg

The icon is 1024 x 1024 with a 100 px transparent margin.

- **Background.** A superellipse squircle (n = 5) from 100 to 924 on both axes, painted
  gold `#E8A33C`, with a 14-ray sunburst in `#F2C261` fanning out from the fingertip.
- **Tap.** A flat cream disc sits behind the fingertip at about (374, 273), with five ink
  "plink" strokes around it.
- **Hand.** The Tiny Hand from `tiny-hand.svg`, scaled 4.1x and rotated 25 degrees
  counter-clockwise, with a solid darker-orange cel shadow offset behind it and the rod.
- **Rod.** Inked and flat-painted like `stick.svg`, running from under the cuff to the
  edge of the tile.

The rays, disc, plinks and rod are cut by the squircle's own geometry, not by a clip
path, so nothing is drawn outside it. There is no text. The icon embeds the hand, so
regenerate it whenever `tiny-hand.svg` changes.

## classic-arrow.svg

This file is unchanged: a black arrow with a white border. Its hotspot is (9, 2) for the
topmost-pixel scan, and the geometric vertex is (9, 9).

## SVG subset and rendering notes

- **Elements.** The hands use only `path`. The stick uses only `rect`. The icon
  uses `path` and `g` (only to carry a `transform`).
- **Attributes.** Only inline `fill` is used.
- **Not used.** There are no gradients, strokes, filters, masks, clip paths, `<text>`,
  CSS, external references or embedded images. All files are pure ASCII.
- **Verified.** Every file renders through `NSImage(contentsOf:)`.
- **Source of the shapes.** Every shape is a signed-distance field on a 0.25-unit grid.
  Fingers are circles swept along a curve and blended into the palm, knuckles and cuff.
  The blended field is then re-solved into a true distance field, which is what lets the
  generator round the inside corners and grow an ink line of the same width everywhere.
  Inner lines are circles swept along a spline, clipped to the paint. Each region is
  traced to a polyline and written as a plain path. A view object turns every position
  about the roll axis before any of this happens, which is how the roll frames are made.
- **Previews.** When drawing an `NSBitmapImageRep` into another context for previews, use
  `operation: .sourceOver`, or transparent areas come out white.

## Regenerating

The generators are in `scripts/art/` and need numpy, which the system Python has.

```bash
/usr/bin/python3 scripts/art/gen.py Resources/Pointers
```

```bash
/usr/bin/python3 scripts/art/stick.py Resources/Pointers/stick.svg
```

```bash
/usr/bin/python3 scripts/art/icon.py Resources/Pointers/tiny-hand.svg Resources/Pointers/app-icon.svg
```

`scripts/art/render.swift` composites SVGs into a PNG sheet and reports each file's tip
and bounds.

## Research sources

The toy's shape and colours are from the user's reference photo: a teal toy hand on a
silver telescoping pointer, tapping a wall calendar.

**TikTok account "Mr Tiny Hand"**, @mr.tiny.hand
(https://www.tiktok.com/@mr.tiny.hand). Still frames were studied from 12 of its public
posts; the profile page itself would not load without a browser. The posts show the same
toy tapping monitors, laptops, keyboards and calendars. They confirmed:

- **Pointing hand.** Index finger up, stubby thumb out, the other fingers merged into a
  rounded mitten palm, a fat rolled cuff, and a multi-section silver telescoping rod with
  small holes.
- **Pointing-hand colours.** Aqua/mint teal, light sky aqua, a darker petrol blue-teal and
  a green.
- **Peace sign.** A V-sign version in aqua.

**Retail listings for mini telescoping hand pointers** (classroom and novelty "finger
pointer" sticks). These confirmed the rod build: 14 to 22 inch telescoping, metal, with
a plastic hand tip. They also confirmed the macaron colour sets: white, pink, green,
yellow, blue and purple.

- Stemfinity, "Telescoping Hand Pointers, Set of 10"
  (https://stemfinity.com/collections/science/products/telescoping-hand-pointer-set-of-10)
- Staples, Learning Resources Telescoping Hand Pointer, set of 10
  (https://www.staples.com/product_1235180)
- AliExpress Wiki, "pointer with tiny hand"
  (https://www.aliexpress.com/s/wiki-ssr/article/pointer-with-tiny-hand)
- AliExpress Wiki, "extendable middle finger pointer"
  (https://www.aliexpress.com/s/wiki-ssr/article/extendable-middle-finger-pointer).
  This confirms that a middle-finger version is sold.
- Walmart, "telescopic hand gesture pointer" listings
  (https://www.walmart.com/ip/16733255316)

**Style reference.** The ink-and-paint look was studied from the Cuphead launch trailer
(https://www.youtube.com/watch?v=NN-9SQXoi50) and the Mr Tiny Hand YouTube channel
(https://www.youtube.com/@Mr-Tiny-Hand): bold black line, flat aged colour, no gradients.

**Rubber-hose references.** The back-of-hand conventions (three darts, even sausage
fingers, plain fists with scalloped knuckles, a narrow cuff band, thin even line) were
taken from public-domain material: frames from *The Karnival Kid* (1929, Internet Archive,
Public Domain Mark), and Wikimedia Commons scans of a 1928 poster, a 1929 Film Daily
advertisement and a 1930 book cover. They were used for style study only; nothing is
copied from them.

**Unconfirmed varieties.** Earlier research listed pointing, middle finger, peace sign,
thumbs up, rock-on and high five. This research confirmed pointing, peace (from the
TikTok posts) and middle finger (from a listing). No public page that could be reached
without logging in showed thumbs-up, rock-on, high-five or cat-paw versions of this toy.
They are kept as in-family designs for the app, with colours taken from the confirmed
product colours: green, yellow, purple, pink and blue.
