const std = @import("std");
const json = std.json;
const mem = std.mem;
const http = std.http;
const Server = http.Server;

const Context = @import("context.zig").Context;

const Allocator = mem.Allocator;

const Customer = struct {
    // zig fmt: off
    last_name: []const u8,
    first_name: []const u8,
    address: []const u8,
    zip: u32,
    city: []const u8,
    // zig fmt: on
};

pub fn JsonType(comptime JsonStruct: type) type {
    return struct {
        allocator: Allocator,
        data: json.Parsed(JsonStruct) = undefined,
        const Self = @This();

        pub fn init(allocator: Allocator) !Self {
            return .{ .allocator = allocator };
        }

        pub fn parseFromSlice(self: *Self, slice: []const u8) !void {
            self.config = try std.json.parseFromSlice(JsonStruct, self.allocator, slice, .{ .allocate = .alloc_always });
        }
    };
}

pub fn createCustomer(ctx: *Context, response: *Server.Response) !void {
    _ = ctx;

    var buffer: [1024]u8 = undefined;
    const read = response.readAll(buffer);
    _ = read;
}
