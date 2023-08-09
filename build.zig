const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Lib
    const lib = b.addStaticLibrary(.{
        .name = "zhttp",
        .root_source_file = .{ .path = "src/zhttp.zig" },
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(lib);

    const zhttp_module = b.addModule("zhttp", .{
        .source_file = .{ .path = "src/zhttp.zig" },
    });

    // Examples
    const simple_example = b.addExecutable(.{
        .name = "example",
        .root_source_file = .{ .path = "examples/simple/src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    simple_example.addModule("zhttp", zhttp_module);
    b.installArtifact(simple_example);
    const run_cmd = b.addRunArtifact(simple_example);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Tests
    const main_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    const run_main_tests = b.addRunArtifact(main_tests);
    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_main_tests.step);
}
