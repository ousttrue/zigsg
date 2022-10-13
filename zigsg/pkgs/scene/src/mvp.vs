#version 330
in vec3 aPos;
in vec3 aNom;
in vec3 aCol;
out vec3 vCol;
uniform mediump mat4 uMVP;
uniform mediump mat4 uView;

uniform vec4 uLight = vec4(1, 2, -3, 0);

void main() {
  gl_Position = uMVP * vec4(aPos, 1);

  vec4 N = uView * vec4(aNom, 0);
  float shade = dot(normalize(uLight).xyz, N.xyz);
  vCol = aCol * shade;
}
