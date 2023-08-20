const std = @import("std");
const Context = @import("context.zig").Context;

const http = std.http;
const Server = http.Server;

const Message = struct { subject: []const u8, text: []const u8 };

pub fn messages(ctx: *Context, response: *Server.Response, message: Message) !void {
    var text = try std.Uri.unescapeString(ctx.allocator, message.text);
    defer ctx.allocator.free(text);
    std.log.info("{s}, {s}", .{ message.subject, text });
    ctx.counter += 1;

    var arrayList: std.ArrayList(u8) = std.ArrayList(u8).init(response.allocator);
    response.status = .ok;
    if (response.request.headers.contains("connection")) {
        try response.headers.append("connection", "keep-alive");
    }

    try arrayList.appendSlice(message.subject);
    try arrayList.append('\n');
    try arrayList.appendSlice(text);
    try arrayList.append('\n');

    response.transfer_encoding = .chunked;
    try response.headers.append("content-type", "text/plain");

    try response.do();
    try response.writeAll(arrayList.items);
    try response.finish();
}
