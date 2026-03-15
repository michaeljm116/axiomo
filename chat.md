Now I understand the full picture. Here's the analysis:
Current System
The shader at rt/ray_gen/main-rg.glsl:24-40 does:
uv within GUI rect → sample texture at (alignMin + guv * alignExt)
So for each character, you create a GUI with:
- min/extents = character position on screen (normalized)
- alignMin/alignExt = which glyph in the font atlas to sample
Your Questions
1. Can you combine text into a single GUI?
Yes! You want a text texture cache:
┌─────────────────────────┐
│  Dynamic Text Texture   │
│  ┌─────┐ ┌─────┐ ┌───┐ │
│  │ H   │ │ e   │ │l │ │
│  └─────┘ └─────┘ └───┘ │
└─────────────────────────┘
         │
         ▼
    ONE GUI component pointing to this texture
This is much cleaner than per-character GUIs.
2. Do normalized coordinates work for text?
Yes! The math is straightforward:
extents_uv.x = pixel_width / screen_width
extents_uv.y = pixel_height / screen_height
The normalized system actually makes this easier - no conversion needed when screen resizes.
---
Proposed Plan
Option A: Dynamic Text Texture (Recommended)
1. Create a TextRenderer system with a dynamic texture (e.g., 512x128)
2. When update_text() is called:
   - Render all glyphs to a pixel buffer using STB_truetype
   - Upload to GPU texture
   - Create ONE GUI with alignMin={0,0}, alignExt={1,1}
3. Track "dirty" state - only re-render when text changes
Option B: Vertex-based (More complex)
- Pass all character positions to shader
- Shader loops through them internally
- Requires shader changes
---
Question for you: Do you want to support multiple fonts, or just one for now? This affects whether we need per-font textures or can share a cache.