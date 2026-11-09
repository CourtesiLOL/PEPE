const std = @import("std");
const sdl = @import("SDL3");

const win = @import("struct/window.zig");


//Redeclarationg
const log = std.log;
const Rgb = @import("struct/rgb.zig").Rgb;

//This constant define the initialize flasg for the window
const MAIN_WINDOW_FLAGS: sdl.SDL_InitFlags = sdl.SDL_INIT_VIDEO; // | sdl.SDL_INIT_AUDIO; you can add mor flags using the operator "|"

//Global vars
const MAIN_WINDOW_TITLE = "Open Window";
const MAIN_WIN_WIDTH = 800;
const MAIN_WIN_HEIGHT = 600;

var current_main_win_width: c_int = MAIN_WIN_WIDTH;
var current_main_win_height: c_int = MAIN_WIN_HEIGHT;

var target_width: i32 = MAIN_WIN_WIDTH;
var target_height: i32 = MAIN_WIN_HEIGHT;
var resize_pending: bool = false;
var last_resize_time: u64 = 0;

const DEBOUNCE_MS: u64 = 100;

const TARGET_FPS = 60;
const TARGET_FRAME_TIME_NS = 1000000000 / TARGET_FPS;

var prng = std.Random.DefaultPrng.init(0);
const random = prng.random();

var back_ground: Rgb = .{.r = 0, .g = 0, .b = 0, .opacity = 0};
var quit = false;

fn delay_win_resize() void {
    const current_time = sdl.SDL_GetTicks();
    if (resize_pending and (current_time - last_resize_time >= DEBOUNCE_MS)) {
        current_main_win_width = target_width;
        current_main_win_height = target_height;
        resize_pending = false;
        log.info("Resize aplicado formalmente a: {d}x{d}", .{current_main_win_width, current_main_win_height});
    }
}

fn win_resize_handler(event: *sdl.SDL_Event) void {
    target_width = event.window.data1;
    target_height = event.window.data2;
    last_resize_time = sdl.SDL_GetTicks();
    resize_pending = true;
}

fn events(window: *const win.Window) void {

    _ = window;
    var event: sdl.SDL_Event = undefined;

    //Fix: change if for while to iterate every event
    while (sdl.SDL_PollEvent(&event)) {
        switch (event.type) {
            sdl.SDL_EVENT_WINDOW_CLOSE_REQUESTED => {
                log.debug("Requested close", .{});
                quit = true;
                log.debug("Close mode set \"true\"", .{});
            },
            sdl.SDL_EVENT_WINDOW_FOCUS_GAINED => {
                log.debug("Gain focus", .{});
                back_ground = .{ .r = 255, .g = 0, .b = 0, .opacity = 255 };
            },
            sdl.SDL_EVENT_WINDOW_FOCUS_LOST => {
                log.debug("Lost focus", .{});
                back_ground = .{ .r = 0, .g = 0, .b = 255, .opacity = 255 };

            },
            sdl.SDL_EVENT_MOUSE_BUTTON_DOWN => {

                const r: u8 = random.int(u8);
                const g: u8 = random.int(u8);
                const b: u8 = random.int(u8);

                back_ground = .{ .r = r, .g = g, .b = b, .opacity = 255 };
            },
            sdl.SDL_EVENT_WINDOW_RESIZED => {
                win_resize_handler(&event);
            },
            else => {}
        }
    }

    delay_win_resize();
}

fn draw(window: *win.Window) void {

    _ = sdl.SDL_SetRenderDrawColor(
        window.render,
        back_ground.r,
        back_ground.g,
        back_ground.b,
        back_ground.opacity
    );
    _ = sdl.SDL_RenderClear(window.render);
    _ = sdl.SDL_SetRenderDrawColor(window.render, 255, 255, 255, 255);

    const rect_width: f32 = 100.0;
    const rect_height: f32 = 50.0;


    const f_win_width: f32 = @floatFromInt(current_main_win_width);
    const f_win_height: f32 = @floatFromInt(current_main_win_height);
    const rectangle: sdl.SDL_FRect = .{
        .x = ((f_win_width / 2) - rect_width / 2),
        .y = ((f_win_height / 2) - rect_height / 2),
        .h = rect_height,
        .w = rect_width
    };


    if (!sdl.SDL_RenderFillRect(window.render, &rectangle))
        log.err("Can't draw the rectangle: {s}", .{sdl.SDL_GetError()});

    _ =sdl.SDL_RenderPresent(window.render);

}

pub fn run() void {
    var main_win = win.Window.init("Main window", MAIN_WIN_WIDTH, MAIN_WIN_HEIGHT, MAIN_WINDOW_FLAGS) catch {
        log.err("Can't create the main window and renderer: {s}", .{sdl.SDL_GetError()});
        return;
    };
    defer {
        main_win.deinit();
        sdl.SDL_Quit();
    }

    _ = sdl.SDL_SetWindowMinimumSize(main_win.window, 250, 150);

    while (!quit) {
        const frame_start = sdl.SDL_GetTicksNS();

        events(&main_win);
        if (!resize_pending)
            draw(&main_win);

        const frame_end = sdl.SDL_GetTicksNS();
        const frame_duration = frame_end - frame_start;

        if (frame_duration < TARGET_FRAME_TIME_NS)
            sdl.SDL_DelayNS(TARGET_FRAME_TIME_NS - frame_duration);
    }

    log.info("Game exited", .{});
}
