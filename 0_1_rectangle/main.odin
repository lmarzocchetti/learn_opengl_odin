package rectangle

import c "core:c"
import "core:fmt"
import "core:log"
import "core:os"
import "core:os/os2"
import "core:strconv"
import "core:strconv/decimal"
import "core:strings"

import gl "vendor:OpenGL"
import glfw "vendor:glfw"

WINDOW_WIDTH :: 800
WINDOW_HEIGHT :: 600

GL_MAJOR_VERSION :: 3
GL_MINOR_VERSION :: 3

framebuffer_size_callback :: proc "c" (window: glfw.WindowHandle, width: i32, height: i32) {
	gl.Viewport(0, 0, width, height)
}

process_input :: proc "c" (window: glfw.WindowHandle, key, scancode, action, mods: i32) {
	if key == glfw.KEY_ESCAPE {
		glfw.SetWindowShouldClose(window, true)
	}
}

load_shader_source :: proc(filepath: string, allocator := context.allocator) -> cstring {
	source, read_error := os2.read_entire_file(filepath, allocator)
	defer delete(source)
	if read_error != nil {
		log.errorf("Cannot Open file %s", filepath)
	}

	csource := strings.clone_to_cstring(string(source))

	return csource
}

main :: proc() {
	context.logger = log.create_console_logger()

	glfw.Init()
	defer glfw.Terminate()
	glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, 3)
	glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, 3)
	glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)
	when ODIN_OS == .Darwin {
		glfw.WindowHint(glfw.OPENGL_FORWARD_COMPAT, gl.TRUE)
	}

	window := glfw.CreateWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Hello from odin", nil, nil)
	defer glfw.DestroyWindow(window)
	if window == nil {
		glfw.Terminate()
		log.errorf("Failed to create GLFW window")
	}

	glfw.MakeContextCurrent(window)
	gl.load_up_to(GL_MAJOR_VERSION, GL_MINOR_VERSION, glfw.gl_set_proc_address)
	glfw.SwapInterval(1)
	glfw.SetKeyCallback(window, process_input)
	glfw.SetFramebufferSizeCallback(window, framebuffer_size_callback)
	// gl.Viewport(0, 0, WINDOW_WIDTH, WINDOW_HEIGHT)

	vertices := [?]f32{0.5, 0.5, 0.0, 0.5, -0.5, 0.0, -0.5, -0.5, 0.0, -0.5, 0.5, 0.0}
	indices := [?]u32{3, 0, 2, 0, 2, 1}

	success: i32
	info_log := new([512]u8)

	shader_source := load_shader_source("0_1_rectangle/shaders/shader.vert")
	vertex_shader: u32 = gl.CreateShader(gl.VERTEX_SHADER)
	defer gl.DeleteShader(vertex_shader)
	gl.ShaderSource(vertex_shader, 1, &shader_source, nil)
	gl.CompileShader(vertex_shader)
	gl.GetShaderiv(vertex_shader, gl.COMPILE_STATUS, &success)
	if !bool(success) {
		gl.GetShaderInfoLog(vertex_shader, 512, nil, cast([^]u8)&info_log)
		log.debugf("Error in compiling vertex shader %s", string(info_log[:]))
	}
	delete(shader_source)

	shader_source = load_shader_source("0_1_rectangle/shaders/shader.frag")
	frag_shader: u32 = gl.CreateShader(gl.FRAGMENT_SHADER)
	defer gl.DeleteShader(frag_shader)
	gl.ShaderSource(frag_shader, 1, &shader_source, nil)
	gl.CompileShader(frag_shader)
	gl.GetShaderiv(frag_shader, gl.COMPILE_STATUS, &success)
	if !bool(success) {
		gl.GetShaderInfoLog(frag_shader, 512, nil, cast([^]u8)&info_log)
		log.debugf("Error in compiling fragment shader %s", string(info_log[:]))
	}
	delete(shader_source)

	shader_program: u32 = gl.CreateProgram()
	defer gl.DeleteProgram(shader_program)
	gl.AttachShader(shader_program, vertex_shader)
	gl.AttachShader(shader_program, frag_shader)
	gl.LinkProgram(shader_program)
	gl.GetProgramiv(shader_program, gl.LINK_STATUS, &success)
	if !bool(success) {
		gl.GetProgramInfoLog(shader_program, 512, nil, cast([^]u8)&info_log)
		log.debugf("Error in linking shader program %s", string(info_log[:]))
	}

	VBO, VAO: u32
	gl.GenVertexArrays(1, &VAO)
	gl.GenBuffers(1, &VBO)
	defer gl.DeleteVertexArrays(1, &VAO)
	defer gl.DeleteBuffers(1, &VBO)
	gl.BindVertexArray(VAO)
	gl.BindBuffer(gl.ARRAY_BUFFER, VBO)

	gl.BufferData(gl.ARRAY_BUFFER, size_of(vertices), &vertices, gl.STATIC_DRAW)
	gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 3 * size_of(f32), cast(uintptr)0)
	gl.EnableVertexAttribArray(0)

	EBO: u32
	gl.GenBuffers(1, &EBO)
	defer gl.DeleteBuffers(1, &EBO)
	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, EBO)
	gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, size_of(indices), &indices, gl.STATIC_DRAW)

	gl.BindBuffer(gl.ARRAY_BUFFER, 0)
	gl.BindVertexArray(0)

	for !glfw.WindowShouldClose(window) {
		// input

		// render 
		gl.ClearColor(0.2, 0.3, 0.3, 1.0)
		gl.Clear(gl.COLOR_BUFFER_BIT)

		gl.UseProgram(shader_program)
		gl.BindVertexArray(VAO)
		gl.DrawElements(gl.TRIANGLES, 6, gl.UNSIGNED_INT, nil)
		// gl.DrawArrays(gl.TRIANGLES, 0, 3)
		// gl.BindVertexArray(0)

		glfw.SwapBuffers(window)
		glfw.PollEvents()
	}

}
