const std = @import("std");
const sdl = @import("SDL3");

const log = std.log;

pub const Win_Error = error {
    Initialize_SDL,
    Creation_Window,
    Creation_Renderer
};

///Estructure to create and destroy a full container that contain his window and renderer
pub const Window = struct {
    window: ?*sdl.SDL_Window,
    render: ?*sdl.SDL_Renderer,

    pub fn init(title: [*c]const u8, width: c_int, height: c_int, flags: sdl.SDL_InitFlags) !Window {
        var win: Window = undefined;
        if (!sdl.SDL_Init(flags)) {
            log.err("Initializing SDL3: {s}", .{sdl.SDL_GetError()});
            return Win_Error.Initialize_SDL;
        }

        win.window = sdl.SDL_CreateWindow(title, width, height, sdl.SDL_WINDOW_RESIZABLE);
        if (win.window == null) {
            log.err("Creating Window: {s}", .{sdl.SDL_GetError()});
            return Win_Error.Creation_Window;
        }

        win.render = sdl.SDL_CreateRenderer(win.window, null);
        if (win.render == null) {
            log.err("Creating Rendered: {s}", .{sdl.SDL_GetError()});
            return Win_Error.Creation_Renderer;
        }

        const renderer_name = sdl.SDL_GetRendererName(win.render);
        if (renderer_name != null) {
            log.info(">>> Render Engine in use: {s} <<<", .{renderer_name});
        }

        return win;
    }

    pub fn deinit(self: *Window) void {
        if (self.window != null) {
            sdl.SDL_DestroyRenderer(self.render);
            sdl.SDL_DestroyWindow(self.window);
            self.window = null;
        }
    }
};
