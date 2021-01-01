const std = @import("std");
const mem = std.mem;

const open_flags = .{
    .access_sub_paths = true,
    .iterate = true,
};

pub const Iterator = struct {
    allocator: *mem.Allocator,
    pattern: std.ArrayList([]const u8),
    segments: std.ArrayList([]const u8),

    pub fn init(allocator: *mem.Allocator, root: std.fs.Dir, pattern: []const u8) !Iterator {
        return error.Todo;
    }

    pub fn deinit(self: *Iterator) void {}

    pub fn next() !?[]const u8 {
        return error.Todo;
    }
};

pub fn copy(
    allocator: *mem.Allocator,
    pattern: []const u8,
    from: std.fs.Dir,
    to: std.fs.Dir,
) !void {
    var it = try Iterator.init(allocator, from, pattern);
    defer it.deinit();

    while (try it.next()) |subpath| try from.copyFile(subpath, to, subpath);
}

test "no files" {
    try copy_test("", &[_][]const u8{}, &[_][]const u8{});
}

test "single file" {
    try copy_test("build.zig", &[_][]const u8{"build.zig"}, &[_][]const u8{"build.zig"});
}

test "single file in dir" {
    try copy_test("src/main.zig", &[_][]const u8{"src/main.zig"}, &[_][]const u8{"src/main.zig"});
}

test "glob all in root" {
    try copy_test(
        "*",
        &[_][]const u8{
            "something.zig",
            "file",
            "src/main.zig",
        },
        &[_][]const u8{
            "something.zig",
            "file",
        },
    );
}

test "glob single file with extension" {
    try copy_test(
        "*.zig",
        &[_][]const u8{ "build.zig", "README.md", "src/main.zig" },
        &[_][]const u8{"build.zig"},
    );
}

test "glob multiple files with extension" {
    try copy_test(
        "*.txt",
        &[_][]const u8{ "build.txt", "file.txt", "src/main.zig" },
        &[_][]const u8{ "build.txt", "file.txt" },
    );
}

test "glob single file with prefix" {
    try copy_test(
        "build*",
        &[_][]const u8{ "build.zig", "file.zig", "src/main.zig" },
        &[_][]const u8{"build.zig"},
    );
}

test "glob multiple files with prefix" {
    try copy_test(
        "ha*",
        &[_][]const u8{ "haha", "hahahaha.zig", "file", "src/hain.zig" },
        &[_][]const u8{ "haha", "hahahaha.zig" },
    );
}

test "glob all files in dir" {
    try copy_test(
        "src/*",
        &[_][]const u8{ "src/main.zig", "src/file.txt", "README.md", "build.zig" },
        &[_][]const u8{ "src/main.zig", "src/file.txt" },
    );
}

test "glob files with extension in dir" {
    try copy_test(
        "src/*.zig",
        &[_][]const u8{ "src/main.zig", "src/lib.zig", "src/file.txt", "README.md", "build.zig" },
        &[_][]const u8{ "src/main.zig", "src/lib.zig" },
    );
}

test "glob single file in multiple dirs" {
    try copy_test(
        "*/main.zig",
        &[_][]const u8{ "src/main.zig", "something/main.zig", "README.md", "src/a_file" },
        &[_][]const u8{ "src/main.zig", "something/main.zig" },
    );
}

test "glob beginning and end of a file" {
    try copy_test(
        "*hello*",
        &[_][]const u8{ "this_is_hello_file", "hello_world", "hello", "greeting_hello", "file" },
        &[_][]const u8{ "this_is_hello_file", "hello_world", "hello", "greeting_hello" },
    );
}

test "glob beginning and end of a file" {
    try copy_test(
        "*hello*file",
        &[_][]const u8{ "hellofile", "hello_world_file", "ahelloafile", "greeting_hellofile", "file" },
        &[_][]const u8{ "hellofile", "hello_world_file", "ahelloafile", "greeting_hellofile" },
    );
}

test "glob extension in multiple dirs" {
    try copy_test(
        "*/*.zig",
        &[_][]const u8{ "src/main.zig", "something/lib.zig", "README.md", "src/a_file" },
        &[_][]const u8{ "src/main.zig", "something/lib.zig" },
    );
}

fn copy_test(pattern: []const u8, fs: []const []const u8, expected: []const []const u8) !void {
    var dir = try setup_fs(fs);
    defer dir.cleanup();

    var dst = std.testing.tmpDir(open_flags);
    defer dst.cleanup();

    try copy(pattern, dir.dir, dst.dir);
    try expect_fs(dst.dir, expected);
}

fn setup_fs(files: []const []const u8) !std.testing.TmpDir {
    var root = std.testing.tmpDir(open_flags);
    errdefer root.cleanup();

    for (files) |subpath| {
        if (subpath.len == 0) continue;

        var buf: [std.mem.page_size]u8 = undefined;
        const path = blk: {
            for (subpath) |c, i| buf[i] = if (c == '/') std.fs.path.sep else c;
            break :blk buf[0..subpath.len];
        };

        const kind: std.fs.File.Kind = if (path[path.len - 1] == std.fs.path.sep)
            .Directory
        else
            .File;

        try touch(root.dir, path, kind);
    }

    return root;
}

fn expect_fs(root: std.fs.Dir, expected: []const []const u8) !void {
    for (expected) |subpath| try root.access(subpath, .{ .read = true });
}

fn touch(root: std.fs.Dir, subpath: []const u8, kind: std.fs.File.Kind) !void {
    switch (kind) {
        .Directory => try root.makeDir(subpath),
        .File => {
            const file = try root.createFile(subpath, .{});
            file.close();
        },
        else => return error.OnlyDirOrFile,
    }
}
