const std = @import("std");
const http = std.http;
const mime_types = @import("mime_types.zig");
const Allocator = std.mem.Allocator;
const fs = std.fs;
//const fmtDate = @import("date.zig").fmtDate;
const router = @import("router.zig");

pub const FileServer = @This();

dir: fs.Dir = undefined,
alloc: Allocator = undefined,
dir_sub_path: []const u8 = undefined,
initialized: bool = false,

pub const ServeError = error{
    NotAFile,
};

pub fn init(allocator: Allocator, dir_sub_path: []const u8) FileServer {
    return .{
        .alloc = allocator,
        .dir_sub_path = dir_sub_path,
    };
}

pub fn deinit(self: *FileServer) void {
    if (self.initialized) {
        self.dir.close();
    }
}

pub fn serve(self: *FileServer, response: *http.Server.Response) !void {
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

    const file = self.dir.openFile(path, .{}) catch |err| switch (err) {
        error.FileNotFound => return router.notFound(response),
        else => |e| {
            std.log.err("Unexpected error {any}", .{err});
            return e;
        },
    };
    defer file.close();

    serveFile(response, path, file) catch |err| switch (err) {
        error.NotAFile => return router.notFound(response),
        else => return err,
    };
}

pub fn serveFile(
    response: *http.Server.Response,
    file_name: []const u8,
    file: fs.File,
) !void {
    var stat = try file.stat();
    if (stat.kind != .file)
        return error.NotAFile;

    std.log.info("Sending file {s}", .{file_name});

    response.status = .ok;
    if (response.request.headers.contains("connection")) {
        try response.headers.append("connection", "keep-alive");
    }

    response.transfer_encoding = .chunked;

    try response.headers.append("content-type", mime_types.fromFileName(file_name));

    var buf: [1024 * 8]u8 = undefined;
    //try response.headers.append("last-modified", try std.fmt.bufPrint(&buf, "{}", fmtDate(stat.mtime)));

    try response.do();

    var buf_reader = std.io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();

    var bytes_read = try in_stream.read(&buf);
    while (bytes_read > 0) {
        try response.writeAll(buf[0..bytes_read]);
        bytes_read = try in_stream.read(&buf);
    }

    try response.finish();
}
