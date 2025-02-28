// MIT License
//
// Copyright (c) 2025 Dok8tavo
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//

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
