const std = @import("std");
const fs = std.fs;
const http = std.http;
const mem = std.mem;

const Allocator = mem.Allocator;
const tr = @import("reader.zig");

pub const TemplateServer = @This();
const mime_types = @import("mime_types.zig");
const router = @import("router.zig");

dir: fs.Dir = undefined,
allocator: Allocator = undefined,
dir_sub_path: []const u8 = undefined,
initialized: bool = false,

pub const Error = error{
    NotAFile,
};

pub fn init(allocator: Allocator, dir_sub_path: []const u8) TemplateServer {
    return .{
        .allocator = allocator,
        .dir_sub_path = dir_sub_path,
    };
}

pub fn deinit(self: *TemplateServer) void {
    if (self.initialized) {
        self.dir.close();
    }
}

pub fn serve(self: *TemplateServer, response: *http.Server.Response) !void {
    if (!self.initialized) {
        self.dir = try fs.cwd().openDir(self.dir_sub_path, .{});
        self.initialized = true;
    }

    var path = response.request.target;
    if (path[0] == '/') path = path[1..];

    // Only files in the dir path can be accessed
    if (std.mem.startsWith(u8, path, "..")) return router.notFound(response);

    if (path.len == 0) {
        path = "index.html";
    }

    std.log.info("Filename: {s} ", .{path});

    self.serveFile(response, path) catch |err| switch (err) {
        error.FileNotFound, error.BadPathName => return router.notFound(response),
        else => return err,
    };
}

pub fn serveFile(self: *TemplateServer, response: *http.Server.Response, file_name: []const u8) !void {
    var buf: [8 * 1024]u8 = undefined;
    var reader = try tr.templateReader(self.allocator, self.dir, file_name);

    response.status = .ok;
    if (response.request.headers.contains("connection")) {
        try response.headers.append("connection", "keep-alive");
    }

    response.transfer_encoding = .chunked;
    try response.headers.append("content-type", mime_types.fromFileName(file_name));
    try response.do();

    var size = try reader.read(&buf);
    while (size > 0) {
        try response.writeAll(buf[0..size]);
        size = try reader.read(&buf);
    }
    try response.finish();
}

test "refAllDecls" {
    std.testing.refAllDecls(@This());
}
