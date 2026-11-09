//TO-DO: Refactor File color to a comptime aprouch and tranform the lis in to a list of textures

const std = @import("std");
const sdl = @import("SDL3");
const window = @import("struct/window.zig");

//Redeclarationg
const Rgb = @import("struct/rgb.zig").Rgb;
const log = std.log;
const Window = window.Window;

//This constant define the initialize flasg for the window
const MAIN_WINDOW_FLAGS: sdl.SDL_InitFlags = sdl.SDL_INIT_VIDEO; //you can add mor flags using the operator "|"

//Global Constants
const MAIN_WINDOW_TITLE = "DVD Screen save";

const MAIN_WIN_WIDTH = 800;
const MAIN_WIN_HEIGHT = 600;

const MIN_WINDOW_WIDTH = 600;
const MIN_WINDOW_HEIGHT = 500;

const TARGET_FPS = 60;
const TARGET_FRAME_TIME_NS = 1000000000 / TARGET_FPS;

const dvd_witdth: f32 = 256.0;
const dvd_height: f32 = 256.0;
const dvd_speed: f32 = 250.0;

const img_files = [_][]const u8{
    "./img/dvd_save/dvd_White.png",
    "./img/dvd_save/dvd_Yellow.png",
    "./img/dvd_save/dvd_Cyan.png",
    "./img/dvd_save/dvd_Green.png",
    "./img/dvd_save/dvd_Magenta.png",
    "./img/dvd_save/dvd_Blue.png",
    "./img/dvd_save/dvd_Red.png",
};
var dvd_textures: [img_files.len][*c]sdl.SDL_Texture = undefined;

const Direction = enum {
    northwest,
    northeast,
    southeast,
    southwest
};

//Global Vars
var current_main_win_width: c_int = MAIN_WIN_WIDTH;
var current_main_win_height: c_int = MAIN_WIN_HEIGHT;

var delta_time: f32 = undefined;

var target_width: i32 = MAIN_WIN_WIDTH;
var target_height: i32 = MAIN_WIN_HEIGHT;
var resize_pending: bool = false;
var last_resize_time: u64 = 0;

const DEBOUNCE_MS: u64 = 100;

var dvd_texture: [*c]sdl.SDL_Texture = undefined;
var dvd_color_index: usize = 0;
var dvd_current_direction: Direction = .northwest;
var dvd_pos_x: f32 = undefined;
var dvd_pos_y: f32 = undefined;

var exit = false;

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

fn next_color() void {
    dvd_color_index += 1;
    if (dvd_color_index >= dvd_textures.len-1)
        dvd_color_index = 0;

    dvd_texture = dvd_textures[dvd_color_index];

}

fn update_dvd_post() void {

    const f_main_height: f32 = @floatFromInt(current_main_win_height);
    const f_main_width: f32 = @floatFromInt(current_main_win_width);

    const delta_speed = dvd_speed * delta_time;

    switch (dvd_current_direction) {
        .northwest => {
            if (dvd_pos_x - delta_speed < 0) {
                dvd_pos_x = 0;
                dvd_pos_y -= delta_speed;
                dvd_current_direction = .northeast;
                next_color();
                return;
            }

            if (dvd_pos_y - delta_speed < 0) {
                dvd_pos_y = 0;
                dvd_pos_x -= delta_speed;
                dvd_current_direction = .southwest;
                next_color();
                return;
            }

            dvd_pos_x -= delta_speed;
            dvd_pos_y -= delta_speed;
        },
        .northeast => {

            if ((dvd_pos_x + dvd_witdth) + delta_speed > f_main_width) {
                dvd_pos_x = f_main_width - dvd_witdth;
                dvd_pos_y -= delta_speed;
                dvd_current_direction = .northwest;
                next_color();
                return;
            }

            if ((dvd_pos_y - delta_speed) < 0) {
                dvd_pos_y = 0;
                dvd_pos_x += delta_speed;
                dvd_current_direction = .southeast;
                next_color();
                return;
            }

            dvd_pos_x += delta_speed;
            dvd_pos_y -= delta_speed;
        },
        .southwest => {

            if (dvd_pos_x - delta_speed < 0) {
                dvd_pos_x = 0;
                dvd_pos_y += delta_speed;
                dvd_current_direction = .southeast;
                next_color();
                return;
            }

            if ((dvd_pos_y + dvd_height) + delta_speed > f_main_height) {
                dvd_pos_y = f_main_height - dvd_height;
                dvd_pos_x -= delta_speed;
                dvd_current_direction = .northwest;
                next_color();
                return;
            }

            dvd_pos_x -= delta_speed;
            dvd_pos_y += delta_speed;
        },
        .southeast => {

            if ((dvd_pos_x + dvd_witdth) + delta_speed > f_main_width) {
                dvd_pos_x = f_main_width - dvd_witdth;
                dvd_pos_y += delta_speed;
                dvd_current_direction = .southwest;
                next_color();
                return;
            }

            if ((dvd_pos_y + dvd_height) + delta_speed > f_main_height) {
                dvd_pos_y = f_main_height - dvd_height;
                dvd_pos_x += delta_speed;
                dvd_current_direction = .northeast;
                next_color();
                return;
            }

            dvd_pos_x += delta_speed;
            dvd_pos_y += delta_speed;
        }
    }
}

fn events() void {
    var event: sdl.SDL_Event = undefined;
    while (sdl.SDL_PollEvent(&event)) {
        switch (event.type) {
            sdl.SDL_EVENT_WINDOW_CLOSE_REQUESTED => {
                exit = true;
            },
            sdl.SDL_EVENT_WINDOW_RESIZED => {
                win_resize_handler(&event);
            },
            else => {}
        }
    }

    delay_win_resize();
    if (!resize_pending) {
        update_dvd_post();
    }
}



fn draw_dvd(win: *Window) void {
    const rectangle: sdl.SDL_FRect = .{
        .x = dvd_pos_x,
        .y = dvd_pos_y,
        .h = dvd_height,
        .w = dvd_witdth
    };

    _ = sdl.SDL_RenderTexture(
        win.render,
        dvd_texture,
        null,
        &rectangle
    );
}

fn draw(win: *Window) void {
    _ = sdl.SDL_SetRenderDrawColor(win.render, 0, 0, 0, 255);
    _ = sdl.SDL_RenderClear(win.render);

    if (dvd_texture != null) {
        draw_dvd(win);
    } else log.err("DVD texture don't exist", .{});


    _ = sdl.SDL_RenderPresent(win.render);
}

fn deinit_load(win: *Window) void {
    win.deinit();
    sdl.SDL_Quit();

    //Destroy the textures in memory
    for (dvd_textures) |texture| {
        if (texture != null)
            sdl.SDL_DestroyTexture(texture);
    }
}

fn init_load(win: *Window) void {

    if (!sdl.SDL_SetWindowMinimumSize(win.window, MIN_WINDOW_WIDTH, MIN_WINDOW_HEIGHT))
        log.warn("Can't set the min size for the window", .{});

    for (img_files, 0..) |fl, i| {
        const surface = sdl.IMG_Load(@ptrCast(fl));
        if (surface != null) {
            dvd_textures[i] = sdl.SDL_CreateTextureFromSurface(
                win.render,
                surface
            );

            sdl.SDL_DestroySurface(surface);
        } else log.err("can't obtain the surface from the file: {s}", .{sdl.SDL_GetError()});
    }
    
    //Charge the texture for the dvd
    dvd_texture = dvd_textures[0];

    const f_main_height: f32 = @floatFromInt(current_main_win_height);
    const f_main_width: f32 = @floatFromInt(current_main_win_width);

    dvd_pos_x = ((f_main_width / 2) - dvd_witdth / 2);
    dvd_pos_y = ((f_main_height / 2) - dvd_height / 2);

}

pub fn run() void {
    var main_win = Window.init(MAIN_WINDOW_TITLE, MAIN_WIN_WIDTH, MAIN_WIN_HEIGHT, MAIN_WINDOW_FLAGS) catch {
        log.err("Can't create the main window and renderer: {s}", .{sdl.SDL_GetError()});
        return;
    };

    log.info("Window create succesfully", .{});

    init_load(&main_win);
    defer deinit_load(&main_win);

    var last_frame = sdl.SDL_GetTicksNS();
    while (!exit) {
        const frame_start = sdl.SDL_GetTicksNS();

        delta_time = @as(f32, @floatFromInt(frame_start - last_frame)) / 1_000_000_000.0;
        last_frame = frame_start;

        events();
        if (!resize_pending)
            draw(&main_win);

        const frame_end = sdl.SDL_GetTicksNS();
        const frame_duration = frame_end - frame_start;

        if (frame_duration < TARGET_FRAME_TIME_NS)
            sdl.SDL_DelayNS(TARGET_FRAME_TIME_NS - frame_duration);
    }

    log.info("Game exited", .{});
}
