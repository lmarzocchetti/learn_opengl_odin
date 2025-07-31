package lib

import "core:log"
import "core:os/os2"
import "core:strings"

import gl "vendor:OpenGL"

Shader :: u32

@(private)
load_shader_source :: proc(filepath: string, allocator := context.allocator) -> cstring {
	source, read_error := os2.read_entire_file(filepath, allocator)
	defer delete(source)
	if read_error != nil {
		log.errorf("Cannot Open file %s", filepath)
	}

	csource := strings.clone_to_cstring(string(source))

	return csource
}

shader_create :: proc(
	vertex_path: string,
	fragment_path: string,
	allocator := context.allocator,
) -> Shader {
	vertex_code := load_shader_source(vertex_path, allocator)
	defer delete(vertex_code)
	fragment_code := load_shader_source(fragment_path, allocator)
	defer delete(fragment_code)

	success: i32
	info_log := new([512]u8)

	vertex_shader: u32 = gl.CreateShader(gl.VERTEX_SHADER)
	defer gl.DeleteShader(vertex_shader)
	gl.ShaderSource(vertex_shader, 1, &vertex_code, nil)
	gl.CompileShader(vertex_shader)
	gl.GetShaderiv(vertex_shader, gl.COMPILE_STATUS, &success)
	if !bool(success) {
		gl.GetShaderInfoLog(vertex_shader, 512, nil, cast([^]u8)&info_log)
		log.debugf("Error in compiling vertex shader %s", string(info_log[:]))
	}

	frag_shader: u32 = gl.CreateShader(gl.FRAGMENT_SHADER)
	defer gl.DeleteShader(frag_shader)
	gl.ShaderSource(frag_shader, 1, &fragment_code, nil)
	gl.CompileShader(frag_shader)
	gl.GetShaderiv(frag_shader, gl.COMPILE_STATUS, &success)
	if !bool(success) {
		gl.GetShaderInfoLog(frag_shader, 512, nil, cast([^]u8)&info_log)
		log.debugf("Error in compiling fragment shader %s", string(info_log[:]))
	}

	shader_program: u32 = gl.CreateProgram()
	gl.AttachShader(shader_program, vertex_shader)
	gl.AttachShader(shader_program, frag_shader)
	gl.LinkProgram(shader_program)
	gl.GetProgramiv(shader_program, gl.LINK_STATUS, &success)
	if !bool(success) {
		gl.GetProgramInfoLog(shader_program, 512, nil, cast([^]u8)&info_log)
		log.debugf("Error in linking shader program %s", string(info_log[:]))
	}

	return shader_program
}

shader_delete :: proc(shader: Shader) {
	gl.DeleteShader(shader)
}

shader_use :: proc(shader: Shader) {
	gl.UseProgram(shader)
}

shader_set_bool :: proc(shader: Shader, name: string, value: bool) {
	gl.Uniform1i(
		gl.GetUniformLocation(shader, strings.clone_to_cstring(name, context.temp_allocator)),
		i32(value),
	)
}

shader_set_int :: proc(shader: Shader, name: string, value: i32) {
	gl.Uniform1i(
		gl.GetUniformLocation(shader, strings.clone_to_cstring(name, context.temp_allocator)),
		value,
	)
}

shader_set_float :: proc(shader: Shader, name: string, value: f32) {
	gl.Uniform1f(
		gl.GetUniformLocation(shader, strings.clone_to_cstring(name, context.temp_allocator)),
		value,
	)
}
