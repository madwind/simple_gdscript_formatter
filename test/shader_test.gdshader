// [01] Global directives and render modes
// Expected formatted output (4-space indentation):
// #define TAU 6.283185
// shader_type spatial;
// render_mode unshaded, cull_back, depth_draw_opaque;
#define TAU 6.283185
shader_type    spatial;
render_mode unshaded ,cull_back , depth_draw_opaque;

// [02] Uniforms, hints, varyings and constants
// Expected formatted output (4-space indentation):
// uniform vec4 base_color : source_color = vec4(0.8, 0.35, 0.1, 1.0);
// uniform sampler2D albedo_texture : source_color;
// uniform float pulse_speed : hint_range(0.0, 8.0) = 2.0;
// uniform float pulse_amount : hint_range(0.0, 1.0) = 0.25;
// uniform bool use_rim = false;
// varying vec3 world_position;
// varying float height_offset;
// const float MIN_BRIGHTNESS = 0.15;
uniform vec4 base_color :source_color=vec4( 0.8,0.35,0.1,1.0 );
uniform sampler2D albedo_texture:source_color;
uniform float pulse_speed :hint_range(0.0,8.0)=2.0;
uniform float pulse_amount :hint_range( 0.0,1.0 ) =0.25;
uniform bool use_rim=false;
varying vec3 world_position;
varying float height_offset;
const float MIN_BRIGHTNESS=0.15;

// [03] Function declaration, parameters, return value and arithmetic
// Expected formatted output (4-space indentation):
// float pulse(float value) {
//     return sin(TIME * pulse_speed + value) * pulse_amount;
// }
float  pulse( float value ){
return sin( TIME*pulse_speed+value )*pulse_amount;
}

// [04] Vertex function, matrix multiplication and conditional branches
// Expected formatted output (4-space indentation):
// void vertex() {
//     world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
//     height_offset = pulse(VERTEX.x);
//     if (use_rim) {
//         VERTEX.y += height_offset;
//     } else {
//         VERTEX.y -= pulse(VERTEX.z) * 0.5;
//     }
// }
void  vertex( ){
world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
height_offset=pulse( VERTEX.x );
if( use_rim ){
VERTEX.y +=height_offset;
}else{
VERTEX.y -=pulse( VERTEX.z )*0.5;
}
}

// [05] Helper function, vector operations, ternary expression and loop
// Expected formatted output (4-space indentation):
// vec3 calculate_lighting(vec3 texture_color, vec3 normal_color) {
//     float light_factor = clamp(dot(NORMAL, vec3(0.0, 1.0, 0.0)), 0.0, 1.0);
//     float blend = light_factor > 0.5 ? 1.0 : 0.25;
//     vec3 animated_color = mix(texture_color, base_color.rgb, 0.75);
//     animated_color *= (MIN_BRIGHTNESS + light_factor) * blend;
//     for (int i = 0; i < 2; i++) {
//         animated_color = mix(animated_color, base_color.rgb, 0.1);
//     }
//     return animated_color;
// }
vec3 calculate_lighting( vec3 texture_color,vec3 normal_color ){
float light_factor=clamp(dot( NORMAL,vec3(0.0,1.0,0.0) ),0.0,1.0);
float blend=light_factor>0.5?1.0:0.25;
vec3 animated_color=mix(texture_color,base_color.rgb,0.75);
animated_color*=(MIN_BRIGHTNESS+light_factor)*blend;
for( int i=0;i<2;i++ ){
animated_color=mix( animated_color,base_color.rgb,0.1 );
}
return animated_color;
}

// [06] Fragment output, texture sampling, material assignments and branches
// Expected formatted output (4-space indentation):
// void fragment() {
//     vec3 normal_color = normalize(NORMAL) * 0.5 + 0.5;
//     vec3 texture_color = texture(albedo_texture, UV).rgb;
//     ALBEDO = calculate_lighting(texture_color, normal_color);
//     ROUGHNESS = 0.35;
//     ALPHA = base_color.a;
//     if (ALPHA < 0.05) {
//         discard;
//     } else if (ALPHA < 1.0) {
//         EMISSION = base_color.rgb * 0.1;
//     }
// }
void fragment( ) {
vec3 normal_color=normalize( NORMAL )*0.5+0.5;
vec3 texture_color=texture( albedo_texture,UV ).rgb;
ALBEDO=calculate_lighting( texture_color,normal_color );
ROUGHNESS =0.35;
ALPHA=base_color.a;
if( ALPHA<0.05 ){
discard;
}else if( ALPHA<1.0 ){
EMISSION=base_color.rgb*0.1;
}
}
