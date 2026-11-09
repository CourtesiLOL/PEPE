const std = @import("std");
const buildin = @import("builtin");

const log = std.log;
const os = buildin.target.os;

//zig build -Dstatic -Dtarget=aarch64-windows

const win_sys_libs = [_][]const u8{
    "winmm", "ole32", "oleaut32",
    "setupapi", "gdi32", "shell32",
    "user32", "advapi32", "imm32",
    "version", "uuid"
};

const linux_sys_libs = [_][]const u8{
};

fn enum_to_str_alloc(alloc: std.mem.Allocator, arg: anytype) ?[]u8 {
    return std.fmt.allocPrint(alloc, "{}", .{arg}) catch null;
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    var optimize = b.standardOptimizeOption(.{});

    //If the target is windows this code make a
    //cross-compilation for x86_64-windows and aarch64-windows
    const final_target = if (os.tag == .windows)
            b.resolveTargetQuery(.{
                .os_tag = .windows,
                .cpu_arch = .x86_64,
            })
        else
            target;

    const op_mode = b.option(bool, "release", "Build the project using the SmallRelease mode");
    const static_link_mode = b.option(bool, "static", "compilation link static");
    const debug_msg_opt = b.option(bool, "vervose", "enable build message info");
    const debug_msg: bool = if (debug_msg_opt != null and debug_msg_opt.? == true) true else false;

    if (debug_msg)
        log.info("Library link mode: {s}", .{
            if (static_link_mode != null and static_link_mode.? == true)
                "static"
            else
                "dynamic"
        });


    const cpu_architecture_str = enum_to_str_alloc(b.allocator, target.result.cpu.arch);
    defer if (cpu_architecture_str) |str| b.allocator.free(str);

    if (debug_msg) {
        log.info("Target os: {}", .{target.result.os.tag});
        log.info("Target architecture: {s}", .{if (cpu_architecture_str) |name| name else "unk"});   
    }

    const exe_name: ?[]u8 = std.fmt.allocPrint(b.allocator, "pepe-{s}", .{
        if (cpu_architecture_str) |str| str[1..] else "unk"
    }) catch null;
    
    defer if (exe_name) |name| b.allocator.free(name);

    if(op_mode) |op| {
        if(op) {
            optimize = .ReleaseFast;
        } else optimize = .Debug;
    }

    //The main executable
    const exe = b.addExecutable(.{
        .name = exe_name.?,
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = final_target,
            .optimize = optimize,
        }),
    });

    const root_md = exe.root_module;
    root_md.link_libc = true;

    if (op_mode) |op| {
        if (op) {
            root_md.strip = true;
            if (os.tag == .windows)
                exe.subsystem = .Windows;
            if (debug_msg)
                log.info("Build mode: release", .{});
        } else {
            if (debug_msg)
                log.info("Build mode: debug", .{});
        }

    }

    if (debug_msg)
        log.info("Opt mode on exe: {}", .{root_md.optimize.?});
    //Create the translate for the SDL3 library
    const sdl_translate = b.addTranslateC(.{
        .root_source_file = b.path("include/SDL_zig.h"),
        .target = final_target,
        .optimize = optimize,
    });

    //Set the path for the header for SDL3
    sdl_translate.addIncludePath(b.path("include/"));
    const sdl_mod = sdl_translate.createModule();

    //Add sdl3 import
    root_md.addImport("SDL3", sdl_mod);

    //Link the libraries
    if (static_link_mode != null and static_link_mode.? == true) {

        if (os.tag == .windows) {
            root_md.addLibraryPath(b.path("lib/win/static/"));

            for (win_sys_libs) |sys_lib| {
                root_md.linkSystemLibrary(sys_lib, .{
                    .needed = true,
                    .preferred_link_mode = .dynamic
                });
            }

            root_md.linkSystemLibrary("SDL3", .{.preferred_link_mode = .static});
            root_md.linkSystemLibrary("SDL3_image", .{.preferred_link_mode = .static});

        }else if (os.tag == .linux) {
            root_md.addLibraryPath(b.path("lib/linux/static/"));
            for (linux_sys_libs) |sys_lib|
                root_md.linkSystemLibrary(sys_lib, .{
                    .needed = true,
                    .preferred_link_mode = .dynamic
                });

            //I can't compile SDL3_Image for a static link in linux
            b.installBinFile("lib/linux/dynamic/libSDL3_image.so.0.4.4", "lib/SDL3_image.so");

            root_md.linkSystemLibrary("SDL3", .{.preferred_link_mode = .static});
            root_md.linkSystemLibrary("SDL3_image", .{.preferred_link_mode = .dynamic});
        } else {
            log.err("Link libraries not implemeted for: {}", .{os.tag});
            return;
        }



    } else {

        if (os.tag == .windows) {
            root_md.addLibraryPath(b.path("lib/win/dynamic/"));
        } else if (os.tag == .linux) {
            root_md.addLibraryPath(b.path("lib/linux/dynamic/"));
        }


        root_md.linkSystemLibrary("SDL3", .{.preferred_link_mode = .dynamic});
        root_md.linkSystemLibrary("SDL3_image", .{.preferred_link_mode = .dynamic});

    }

    if (os.tag == .windows) {
        if (static_link_mode == null or static_link_mode.? == false) {
            b.installBinFile("lib/win/dynamic/SDL3.dll", "SDL3.dll");
            b.installBinFile("lib/win/dynamic/SDL3_image.dll", "SDL3_image.dll");
        }
    } else if (os.tag == .linux) {
        if (static_link_mode == null or static_link_mode.? == false) {
            b.installBinFile("lib/linux/dynamic/libSDL3_image.so.0.4.4", "lib/SDL3.so");
            b.installBinFile("lib/linux/dynamic/libSDL3_image.so.0.4.4", "lib/SDL3_image.so");
        }
    }

    b.installDirectory(.{
        .source_dir = b.path("img/"),
        .install_dir = .prefix,
        .install_subdir = "bin/img"
    });

    b.installArtifact(exe);



    const run_step = b.step("run", "Run the app");

    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const exe_tests = b.addTest(.{
        .root_module = root_md,
    });

    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_exe_tests.step);
}
