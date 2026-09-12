# Original fictional sponsor artwork

Both atlases were generated with the **built-in image generation tool**, then copied into the project unchanged. No API key or image-generation CLI was used. Logos are fictional designs; they do not represent real racing teams or sponsors.

Runtime UV selection and panel construction live in `scripts/sponsor_identity.gd`. Tile interiors have padding and sampled gutters to reduce edge bleeding. Every car combines a circuit sponsor with a car-only identity. Walls, barriers, garages and gantry signs use the shared circuit set. The APEX tile is now unused: sponsor index 0 loads the supplied white/red logo adaptation from `assets/branding/apex-circuit-dark.png`.

## Circuit atlas

Output: `assets/sponsors/atlas.png`.

Generation brief, normalized for reproduction: create a square 2048-pixel sponsor texture atlas arranged as two columns by four rows, with no external margin or gutters. Each tile contains a distinct original motorsport identity with a logo symbol/diagram and strongly legible custom typography, entirely inside 15% padding. Flat artwork, clean edges, no real brands, no photographs or mockups. Reading order: APEX CIRCUIT in white/cyan on navy; VOLTARA in white/lime on black; NORDLINE in white on blue; HELIX in navy/orange on white; KORSA in white on burgundy; AERION in blue on white; STRATUM in gold on charcoal; PULSE in black on cyan.

Original local output filename: `exec-e5053338-3292-471a-a1ee-4df2aa910cc1.png` in generated-image session `01a0979b-02f3-7b52-b31b-a1190cedede5`.

## Car-only atlas

Output: `assets/sponsors/car-atlas.png`.

Generation brief, normalized for reproduction: create a square 2048-pixel texture atlas with two columns by two rows. Four original motorsport sponsor identities, distinct flat logo symbols and crisp typography, with 15% internal padding and no real brands. Top left: VECTOR, white italic lettering with turquoise vector symbol on dark navy. Top right: IONIX, navy futuristic lettering and a purple ion symbol on white. Bottom left: FORGE, white slab lettering and orange anvil symbol on black. Bottom right: ZENITH, navy lettering and a gold star on white. No photographic rendering, bevels or product mockups.

Original local output filename: `exec-c144b2b9-e016-4788-b0c2-499f24118ddc.png` in the same generated-image session. The IONIX tile did not meet contrast requirements and is intentionally unused; VECTOR, FORGE and ZENITH are used on cars.
