const std = @import("std");
const http = std.http;

const Server = http.Server;

const zhttp = @import("zhttp");
const router = zhttp.router;
const http_server = zhttp.http_server;
const FileServer = zhttp.file_server.FileServer;
const TemplateServer = zhttp.template_server.TemplateServer;
var fs: ?FileServer = null;
var ts: ?TemplateServer = null;

pub const Context = struct {
    counter: usize = 0,
};

var context: Context = .{ .counter = 0 };

fn serveFiles(ctx: *Context, response: *http.Server.Response) !void {
    _ = ctx;
    if (fs) |*s| {
        s.serve(response) catch |err| {
            std.log.err("Unexpected error {any}", .{err});
            response.status = .not_found;
            if (response.request.headers.contains("connection")) {
                try response.headers.append("connection", "keep-alive");
            }

            try response.do();
            try response.finish();
        };
    }
}

fn serveTemplates(ctx: *Context, response: *http.Server.Response) !void {
    if (!std.mem.endsWith(u8, response.request.target, "html") and !std.mem.endsWith(u8, response.request.target, "/")) {
        return try serveFiles(ctx, response);
    }

    if (ts) |*s| {
        s.serve(response) catch |err| {
            std.log.err("Unexpected error {any}", .{err});
            response.status = .not_found;
            if (response.request.headers.contains("connection")) {
                try response.headers.append("connection", "keep-alive");
            }

            try response.do();
            try response.finish();
        };
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{ .stack_trace_frames = 12 }){};
    const allocator = gpa.allocator();

    fs = FileServer.init(allocator, "examples/simple/static", null);
    if (fs) |*s| {
        defer s.deinit();
    }

    ts = TemplateServer.init(allocator, "examples/simple/templates");
    if (ts) |*s| {
        defer s.deinit();
    }

    var server = http_server.HttpServer.init(allocator);
    errdefer server.killServer();

    const builder = router.Builder(*Context);

    try server.startServer(
        "examples/simple/config.json",
        &context,
        comptime router.router(*Context, &.{
            builder.get("/assets/*", serveFiles),
            builder.get("/css/*", serveFiles),
            builder.get("/js/*", serveFiles),
            builder.get("/*", serveTemplates),
            builder.get("/", serveTemplates),
        }),
    );
}

test {
    std.testing.refAllDecls(@This());
}
