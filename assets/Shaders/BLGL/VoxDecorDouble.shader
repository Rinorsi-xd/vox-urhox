// Source spinSteel uses DoubleSide; keep culling in the shader for hot reload.
shader_type spatial;
render_mode shading_model_pbr, cull_disabled;
#include "lib/VoxDecorSurface.shaderinc"
