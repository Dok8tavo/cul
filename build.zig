const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const root = b.path("src/root.zig");

    const module = b.addModule("cul", .{
        .target = target,
        .optimize = optimize,
        .root_source_file = root,
    });

    const tests = b.addTest(.{ .root_module = module });
    const emit = b.addInstallArtifact(tests, .{});

    const documentation = b.addInstallDirectory(.{
        .source_dir = tests.getEmittedDocs(),
        .install_subdir = "doc",
        .install_dir = .prefix,
    });

    const run_tests = b.addRunArtifact(tests);
    if (b.args) |args| run_tests.addArgs(args);

    const doc_step = b.step("doc", "Build and install the documentation");
    const emit_step = b.step("emit", "Build and install the tests");
    const test_step = b.step("test", "Build and run the tests");
    const zls_step = b.step("zls", "A step for zls to use");

    doc_step.dependOn(&documentation.step);
    emit_step.dependOn(&emit.step);
    test_step.dependOn(&run_tests.step);
    zls_step.dependOn(&tests.step);

    // just in case someone doesn't use `zig build zls`
    b.getInstallStep().dependOn(&tests.step);
}
