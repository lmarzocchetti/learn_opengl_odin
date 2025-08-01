package texture_combined

import c "core:c"
import "core:fmt"
import "core:log"
import "core:math"
import "core:os"
import "core:os/os2"
import "core:strconv"
import "core:strconv/decimal"
import "core:strings"

import gl "vendor:OpenGL"
import glfw "vendor:glfw"
import stb "vendor:stb/image"

import lib "../lib/"

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

create_window :: proc() -> glfw.WindowHandle {
	glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, 3)
	glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, 3)
	glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)
	when ODIN_OS == .Darwin {
		glfw.WindowHint(glfw.OPENGL_FORWARD_COMPAT, gl.TRUE)
	}
	glfw.WindowHint(glfw.RESIZABLE, glfw.FALSE)

	window := glfw.CreateWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Hello from odin", nil, nil)
	if window == nil {
		glfw.Terminate()
		log.errorf("Failed to create GLFW window")
	}

	glfw.MakeContextCurrent(window)
	gl.load_up_to(GL_MAJOR_VERSION, GL_MINOR_VERSION, glfw.gl_set_proc_address)
	glfw.SwapInterval(1)
	glfw.SetKeyCallback(window, process_input)
	glfw.SetFramebufferSizeCallback(window, framebuffer_size_callback)

	return window
}

main :: proc() {
	context.logger = log.create_console_logger()

	glfw.Init()
	defer glfw.Terminate()

	window := create_window()
	defer glfw.DestroyWindow(window)

	shader_program: lib.Shader = lib.shader_create(
		"2_1_texture_combined/shaders/shader.vert",
		"2_1_texture_combined/shaders/shader.frag",
	)
	defer lib.shader_delete(shader_program)
	
    //odinfmt: disable
	vertices := [?]f32{
        // positions      // colors        // texture coord
         0.5, -0.5, 0.0,  1.0, 0.0, 0.0,   1.0, 0.0,    // top left
         0.5,  0.5, 0.0,  0.0, 1.0, 0.0,   1.0, 1.0,    // top right
        -0.5, -0.5, 0.0,  0.0, 0.0, 1.0,   0.0, 0.0,    // bottom left
        -0.5,  0.5, 0.0,  1.0, 1.0, 0.0,   0.0, 1.0,    // bottom right
    }

    indices := [?]u32 {
        2, 0, 1,
        2, 1, 3
    }
    //odinfmt: enable

	VBO, VAO, EBO: u32
	gl.GenVertexArrays(1, &VAO)
	gl.GenBuffers(1, &VBO)
	gl.GenBuffers(1, &EBO)
	defer gl.DeleteVertexArrays(1, &VAO)
	defer gl.DeleteBuffers(1, &VBO)
	defer gl.DeleteBuffers(1, &EBO)
	gl.BindVertexArray(VAO)

	gl.BindBuffer(gl.ARRAY_BUFFER, VBO)
	gl.BufferData(gl.ARRAY_BUFFER, size_of(vertices), &vertices, gl.STATIC_DRAW)

	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, EBO)
	gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, size_of(indices), &indices, gl.STATIC_DRAW)

	// Position Attribute
	gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 8 * size_of(f32), cast(uintptr)0)
	gl.EnableVertexAttribArray(0)
	// Color Attribute
	gl.VertexAttribPointer(
		1,
		3,
		gl.FLOAT,
		gl.FALSE,
		8 * size_of(f32),
		cast(uintptr)(3 * size_of(f32)),
	)
	gl.EnableVertexAttribArray(1)
	// Texture Attribute
	gl.VertexAttribPointer(
		2,
		2,
		gl.FLOAT,
		gl.FALSE,
		8 * size_of(f32),
		cast(uintptr)(6 * size_of(f32)),
	)
	gl.EnableVertexAttribArray(2)

	// TEXTURE
	container_texture, emoji_texture: u32
	gl.GenTextures(1, &container_texture)
	gl.BindTexture(gl.TEXTURE_2D, container_texture)
	texture_coords := [?]f32{0.0, 0.0, 1.0, 0.0, 0.5, 1.0}
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.MIRRORED_REPEAT)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.MIRRORED_REPEAT)
	// Border Color
	// border_color := [?]f32{1.0, 1.0, 0.0, 1.0}
	// gl.TexParameterfv(gl.TEXTURE_2D, gl.TEXTURE_BORDER_COLOR, raw_data(border_color[:]))
	// LINEAR_MIPMAP_LINEAR only in the minify because mipmaps are used only for downscaling 
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST)

	stb.set_flip_vertically_on_load(1)
	{
		width, height, nr_chan: i32
		data := stb.load(
			"2_1_texture_combined/resources/container.jpg",
			&width,
			&height,
			&nr_chan,
			0,
		)
		defer stb.image_free(data)
		if data == nil {
			log.fatalf("Error: could not read image")
			os.exit(1)
		}

		gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGB, width, height, 0, gl.RGB, gl.UNSIGNED_BYTE, data)
		gl.GenerateMipmap(gl.TEXTURE_2D)
	}

	gl.GenTextures(1, &emoji_texture)
	gl.BindTexture(gl.TEXTURE_2D, emoji_texture)
	{
		width, height, nr_chan: i32
		data := stb.load(
			"2_1_texture_combined/resources/awesomeface.png",
			&width,
			&height,
			&nr_chan,
			0,
		)
		defer stb.image_free(data)
		if data == nil {
			log.fatalf("Error: could not read image")
			os.exit(1)
		}

		gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGB, width, height, 0, gl.RGBA, gl.UNSIGNED_BYTE, data)
		gl.GenerateMipmap(gl.TEXTURE_2D)
	}

	lib.shader_use(shader_program)
	lib.shader_set_int(shader_program, "container_texture", 0)
	lib.shader_set_int(shader_program, "emoji_texture", 1)

	time_value: f64
	for !glfw.WindowShouldClose(window) {
		time_value = glfw.GetTime()
		// input

		// render 
		gl.ClearColor(0.2, 0.3, 0.3, 1.0)
		gl.Clear(gl.COLOR_BUFFER_BIT)

		gl.ActiveTexture(gl.TEXTURE0)
		gl.BindTexture(gl.TEXTURE_2D, container_texture)
		gl.ActiveTexture(gl.TEXTURE1)
		gl.BindTexture(gl.TEXTURE_2D, emoji_texture)

		lib.shader_use(shader_program)
		gl.BindVertexArray(VAO)
		gl.DrawElements(gl.TRIANGLES, 6, gl.UNSIGNED_INT, nil)
		// gl.BindVertexArray(0)

		// Update
		glfw.SwapBuffers(window)
		glfw.PollEvents()
	}

}
