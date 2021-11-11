const std = @import("std");

const glfw_path = "./vendor/glfw/";
const epoxy_path = "./vendor/libepoxy";

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

    // The ./include/ dir contains any C files we have to write to integrate with
    // vendored libs
    exe.addIncludeDir("./include");

    // Single-file header libraries (like stb_image.h) live in the root of the vendor
    // directory, so we need those too
    exe.addIncludeDir("./vendor");

    // Find GLFW
    exe.addIncludeDir(glfw_path ++ "include");
    exe.addLibPath(glfw_path ++ "build/src");

    // Find epoxy
    exe.addIncludeDir(epoxy_path ++ "include");
    exe.addLibPath(epoxy_path ++ "_build/src");

    exe.linkSystemLibrary("glfw");
    exe.linkSystemLibrary("epoxy");
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
