const std = @import("std");
const http = std.http;

const Server = http.Server;

const zhttp = @import("zhttp");
const router = zhttp.router;
const http_server = zhttp.http_server;
const Context = @import("context.zig").Context;
const rc = @import("rest_struct.zig");

fn hello(ctx: *Context, response: *Server.Response, name: []const u8) !void {
    ctx.counter += 1;

    var arrayList: std.ArrayList(u8) = std.ArrayList(u8).init(response.allocator);
    response.status = .ok;
    if (response.request.headers.contains("connection")) {
        try response.headers.append("connection", "keep-alive");
    }

    try arrayList.appendSlice("Hello ");
    try arrayList.appendSlice(name);
    try arrayList.append('\n');

    response.transfer_encoding = .{ .content_length = arrayList.items.len };
    try response.headers.append("content-type", "text/plain");

    try response.do();
    try response.writeAll(arrayList.items);
    try response.finish();
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{ .stack_trace_frames = 12 }){};
    const allocator = gpa.allocator();

    var context: Context = .{ .allocator = allocator, .counter = 0 };

    var server = http_server.HttpServer.init(allocator);
    errdefer server.killServer();

    const builder = router.Builder(*Context);

    try server.startServer(
        "examples/rest/config.json",
        &context,
        comptime router.router(*Context, &.{
            builder.get("/hello/:name", hello),
            builder.get("/api/posts/:subject/messages/:text", rc.messages),
        }),
    );
}

test {
    std.testing.refAllDecls(@This());
}
