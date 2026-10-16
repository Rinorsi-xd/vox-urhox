# Linear Sampling

User direction on 2026-10-16 explicitly replaces anisotropic filtering with
ordinary linear filtering. This is an intentional rendering exception to H5
visual parity, not a missing migration feature.

- Crater albedo/nra texture arrays: anisotropic -> trilinear.
- Hangar sign/decal samplers: filter_linear_mipmap_anisotropic -> filter_linear_mipmap.
- Runtime renderer default: FILTER_TRILINEAR, textureAnisotropy=1.
- Stop restores previous renderer defaults, including editor preview ownership.
- compile-crater.py emits the same texture-array setting on future exports.

The documented filter_linear_mipmap uses linear filtering within and between
mipmap levels. Mipmap chains and repeat/clamp addressing remain intact. This
avoids the distant aliasing and bandwidth cost of forcing every lookup to mip 0.
Render-target/UI textures already using bilinear retain their existing settings.

Minimap pixels are recaptured with matching renderer defaults because texture
filtering is a genuine pixel input. Old capture reports remain historical;
changing a checksum alone cannot approve the new output. Actual capture and Web
results are recorded separately. This change does not by itself establish frame
rate, sustained mobile temperature or total loading performance.
