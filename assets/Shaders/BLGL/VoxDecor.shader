// Source rotating and emissive decor; shared GPU animation with source culling.
shader_type spatial;
render_mode shading_model_pbr, cull_back;
#include "lib/VoxDecorSurface.shaderinc"