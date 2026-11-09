const std = @import("std");
const sdl = @import("SDL3");

const eql = std.mem.eql;
const log = std.log;

const example_window = @import("examples/example_window.zig");
const dvd_screen = @import("examples/dvd_screensaver.zig");

const MENU_EXAMPLES = @embedFile("./menu.txt");

pub fn main(init: std.process.Init.Minimal) !void {
    var alloc = std.heap.DebugAllocator(.{}).init;
    defer _ = alloc.deinit();
    
    const gpa = alloc.allocator();

    var args = init.args.iterateAllocator(gpa) catch {
        log.err("Can't obtain the argumens", .{});
        return;
    };
    defer args.deinit();

    _ = args.skip();
    const name = args.next();

    if (name) |nm| {
        const normal_nm = nm[0..nm.len];
        if (eql(u8, normal_nm, "dvd")) {
            dvd_screen.run();
        } else if (eql(u8, normal_nm, "window")) {
            example_window.run();
        } else {
            log.err("Example programn name unknow\n{s}", .{MENU_EXAMPLES});
        }
    } else {
        log.warn("Can't obtain the name", .{});
        log.info("Executiong default example", .{});
        example_window.run();
        return;
    }
}
