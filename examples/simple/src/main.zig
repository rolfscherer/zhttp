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
    _ = ctx;
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

fn hello(ctx: *Context, response: *Server.Response, name: []const u8) !void {
    ctx.counter += 1;

    std.log.info("Hello {s}", .{name});
    var arrayList: std.ArrayList(u8) = std.ArrayList(u8).init(response.allocator);
    response.status = .ok;
    if (response.request.headers.contains("connection")) {
        try response.headers.append("connection", "keep-alive");
    }

    try arrayList.appendSlice("<head></head><body><h1>Hello ");
    try arrayList.appendSlice(name);

    try arrayList.appendSlice("</h1><p>Zig is great</p><body>");

    response.transfer_encoding = .{ .content_length = arrayList.items.len };
    try response.headers.append("content-type", "text/html");

    try response.do();
    try response.writeAll(arrayList.items);
    try response.finish();
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{ .stack_trace_frames = 12 }){};
    const allocator = gpa.allocator();

    fs = FileServer.init(allocator, "examples/static");
    if (fs) |*s| {
        defer s.deinit();
    }

    ts = TemplateServer.init(allocator, "examples/templates");
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
            builder.get("/hello/:name", hello),
            builder.get("/*", serveTemplates),
            builder.get("/static/*", serveFiles),
        }),
    );
}

test {
    std.testing.refAllDecls(@This());
}
