# Pointer art notes

The pointers are original SVG drawings of a moulded-plastic toy hand on a telescoping
metal pointer. The reference is the "Mr Tiny Hand" style toy: a glossy, injection-moulded
hand with a single raised finger, a stubby thumb, the other fingers merged into a smooth
mitten-like palm, and a fat rolled cuff that pushes onto a silver rod. Nothing is traced
from photos and no logos are used.

## Style: moulded plastic, not a cartoon glove

- **Shapes.** Each hand is one smooth moulded volume. Fingers are chunky with a slightly
  fat, bulbous tip, and they flow into the palm through soft fillets. There are no stitch
  lines, knuckle creases or nail details. The thumb is short and stubby. The cuff is a
  fat cylinder with softly rounded rims.
- **Outline.** There is one thin outline, 1 viewBox unit outside the fill, in a dark shade
  of the toy's own colour (dark teal for the teal hand). It is never black.
- **Shading.** Each volume has a soft gradient: lighter top-left, base colour, and darker
  underside and right side. It is built from a base gradient, a few low-opacity
  light layers pushed toward the light, and low-opacity occlusion bands on the shadow
  side.
- **Gloss.** Crisp white specular streaks sit on the most curved lit edges, such as the
  fingertip and knuckle mound. There are also a few small white glints, a soft sheen on
  the palm, and a faint rim/bounce light along the underside. A soft occlusion line sits
  where the palm meets the cuff, and there is a dark hole at the cuff bottom for the rod.
- **Colour.** Each toy has its own colour. The colours are mixed about 6 percent toward a
  warm cream, so the set reads as one slightly faded vintage family. There is no grain
  or stipple in the files; the app adds film grain and sepia at runtime.

## Pointer sets

Every hand set uses viewBox `0 0 100 140`, is drawn upright, and has a transparent
background. Coordinates are in viewBox units with the origin at the top left.

- **Hotspot** is the single topmost opaque point. It is a path vertex at exactly y = 2.00,
  and nothing (including highlights) is above it.
- **Cuff bottom-centre** is where the app hangs the stick. The cuff fill ends at y 137 and
  its outline ends at y 138, centred on x 50.

| Menu name | File prefix | Hotspot (tip) | Cuff bottom-centre | Dominant colour |
| --- | --- | --- | --- | --- |
| Tiny Hand | `tiny-hand` | (40.0, 2.0) | (50, 138) | teal `#2EB795` (outline `#155445`) |
| Middle Child | `middle-child` | (50.0, 2.0) | (50, 138) | petrol blue `#4993BE` (outline `#204459`) |
| Peace Sign | `peace` | (36.0, 2.0) | (50, 138) | lavender purple `#A690CF` (outline `#473171`) |
| Thumbs Up | `thumbs-up` | (36.0, 2.0) | (50, 138) | butter yellow `#F2C751` (outline `#94701E`) |
| Rock On | `rock-on` | (34.0, 2.0) | (50, 138) | green `#6AB56F` (outline `#2C582F`) |
| High Five | `high-five` | (50.0, 2.0) | (50, 138) | pink `#F29DAD` (outline `#A21530`) |
| Cat Paw | `cat-paw` | (40.0, 2.0) | (50, 138) | pastel sky blue `#A2CEE5` with pink beans `#EE9AA6` (outline `#276A8D`) |

The table in words:

- **Tiny Hand.** The teal toy from the reference photo: index finger up on the left half of
  the palm, a stubby thumb out to the left, and the other fingers merged into a rounded
  knuckle mound at the top right.
- **Middle Child.** The middle finger is up, with rounded mounds on both sides for the
  folded fingers and the same stubby thumb.
- **Peace Sign.** Index and middle fingers form a V with a moulded web at the bottom. The
  index tip is 4.5 units higher than the middle tip, so the tip is unambiguous.
- **Thumbs Up.** A fat thumb rises from the top-left of the fist, and three fat curled-finger
  rolls scallop the right side. The thumb tip is the topmost point.
- **Rock On.** Index and pinky are up, with the folded middle fingers as a mound between
  them. The index tip is 9 units higher than the pinky tip.
- **High Five.** An open palm with four fanned fingers, webbed at the base, and a thumb out
  to the left. The middle fingertip is the topmost point.
- **Cat Paw.** A rounded paw toy with four toe bulbs, four pink toe beans and a pink
  three-lobed main pad, each with its own gloss. The left-middle toe is the topmost point.

Measured from a 1400-pixel-tall NSImage render (alpha > 0.5), every a, b and c frame has
its topmost opaque pixel at y 2.00 and its art bottom at about 138.5, which includes
antialiasing. The art spans these x ranges: tiny-hand 1.5 to 84.4, middle-child 3.1 to
84.4, peace 5.6 to 84.4, thumbs-up 15.6 to 88.9, rock-on 15.6 to 84.4, high-five 3.6 to
95.6, and cat-paw 11.6 to 89.4.

### Boil frames (`-b`, `-c`)

The `name-b.svg` and `name-c.svg` files are the 12 fps "boil" frames. In each one, a
smooth noise field moves the silhouette by up to about 0.7 units (0.5 on the cuff). Every
highlight, glint and sheen is also nudged by about 0.3 to 0.6 units and slightly resized.
The noise fades to zero within about 7 units of the tip, around the cuff bottom-centre,
and at the leftmost and rightmost points. As a result, all three frames keep:

- the same tip vertex, at the same x and y = 2.0
- the same art bounds
- the same viewBox

## stick.svg

The stick has viewBox `0 0 24 400`, is drawn vertically, and the cuff end is at the top.
It has three silver tube sections with stepped widths:

| Section | y range | x range | Width |
| --- | --- | --- | --- |
| Top | 0 to 140 | 0 to 24 | 24 (fills the full width) |
| Middle | 140 to 272 | 1.5 to 22.5 | 21 |
| Bottom | 272 to 400 | 3 to 21 | 18 |

- Each section has a horizontal metallic gradient, a bright white specular streak at about
  30 percent of its width, a faint secondary sheen and thin darker side edges.
- Each wider section ends in a rolled lip, and a short shadow sits where the narrower tube
  slides out of it.
- Two small holes near the top, at y 22 and 31, echo the real pointer.

## app-icon.svg

The icon is 1024 x 1024 with a 100 px transparent margin.

- **Background.** A superellipse squircle (n = 5) runs from 100 to 924 on both axes. It is
  filled with a warm orange gradient, `#F8B35A` to `#DB6A2C`.
- **Hand.** The teal Tiny Hand is drawn from `tiny-hand.svg`, scaled 4.1x and rotated 25
  degrees counter-clockwise, like the reference photo. Its fingertip taps at about
  (349, 234).
- **Tap effect.** Behind the fingertip are a soft cream glow and three cream impact rings.
  The hand casts a soft darker-orange drop shadow.
- **Rod.** The silver rod runs from the cuff to the bottom edge. It is cut by geometry
  just inside the squircle curve, not by a clip path.

Nothing is drawn outside the squircle; this was checked pixel by pixel through NSImage.
There is no text. If you change the hand, regenerate the icon or replace the hand group
in it.

## classic-arrow.svg

This file is unchanged: a black arrow with a white border. Its hotspot is (9, 2) for the
topmost-pixel scan, and the geometric vertex is (9, 9).

## SVG subset and rendering notes

- **Elements.** The files use only `path`, `ellipse`, `rect`, `g` (only to carry a
  `transform`), `linearGradient` and `radialGradient` with `stop`.
- **Attributes.** Only inline fill, stroke and opacity attributes are used.
- **Not used.** There are no filters, masks, clip paths, `<text>`, CSS, external
  references or embedded images. All files are pure ASCII.
- **Verified.** Every file renders through `NSImage(contentsOf:)` on macOS 26.
- **Source of the shapes.** The hands are generated from signed-distance-field shapes,
  smooth-unioned so the fingers, palm and thumb melt together like one moulding. They
  are extracted as fine polylines (0.25-unit grid) and written as plain paths.
- **Generator.** The generator (`gen.py`, `sdfart.py`, `stick.py`, `icon.py`) and the
  preview tooling live in the session scratchpad (`fresh-art/`), not in the repo.
- **Previews.** When drawing an `NSBitmapImageRep` into another context for previews, use
  `operation: .sourceOver`, or transparent areas come out white.

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

**Unconfirmed varieties.** Earlier research listed pointing, middle finger, peace sign,
thumbs up, rock-on and high five. This research confirmed pointing, peace (from the
TikTok posts) and middle finger (from a listing). No public page that could be reached
without logging in showed thumbs-up, rock-on, high-five or cat-paw versions of this toy.
They are kept as in-family designs for the app, with colours taken from the confirmed
product colours: green, yellow, purple, pink and blue.
