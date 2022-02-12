const std = @import("std");

const glfw_path = "./vendor/glfw/";
const epoxy_path = "./vendor/libepoxy";
const ma_path = "./vendor/miniaudio";

pub fn build(b: *std.build.Builder) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const exe = b.addExecutable("junk", "src/main.zig");
    exe.setTarget(target);
    exe.setBuildMode(mode);

    exe.addIncludeDir("./vendor");
    exe.addIncludeDir(ma_path);
    exe.addIncludeDir(ma_path ++ "/research");
    exe.addCSourceFiles(&.{ "./include/miniaudio_impl.c", "./include/stb_image_impl.c" }, &[_][]const u8{"-Werror"});

    // Find GLFW
    exe.addIncludeDir(glfw_path ++ "include");
    exe.addLibPath(glfw_path ++ "build/src");

    // Find epoxy
    exe.addIncludeDir(epoxy_path ++ "include");
    exe.addLibPath(epoxy_path ++ "_build/src");

    exe.linkSystemLibrary("glfw");
    exe.linkSystemLibrary("epoxy");
    exe.linkSystemLibrary("pthread");
    exe.linkSystemLibrary("m");
    exe.linkSystemLibrary("dl");
    exe.linkLibC();

    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
