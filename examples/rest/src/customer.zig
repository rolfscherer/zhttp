const std = @import("std");
const json = std.json;
const mem = std.mem;
const http = std.http;
const Server = http.Server;

const Context = @import("context.zig").Context;

const Allocator = mem.Allocator;

const Customer = struct {
    // zig fmt: off
    id: u64 = 0,
    last_name: ?[]const u8 = null,
    first_name: []const u8,
    address: ?[]const u8 = null,
    zip: u32 = 0,
    city: ?[]const u8 = null,
    phone: ?[]const u8 = null,
    // zig fmt: on
};

pub const Customers = std.AutoHashMap(u64, JsonType(Customer));

pub fn JsonType(comptime JsonStruct: type) type {
    return struct {
        allocator: Allocator,
        data: json.Parsed(JsonStruct) = undefined,
        const Self = @This();

        pub fn init(allocator: Allocator) Self {
            return .{ .allocator = allocator };
        }

        pub fn deinit(self: *Self) void {
            self.data.deinit();
        }

        pub fn parseFromSlice(self: *Self, slice: []const u8) !void {
            self.data = try std.json.parseFromSlice(JsonStruct, self.allocator, slice, .{ .allocate = .alloc_always });
        }
    };
}

pub fn createCustomer(ctx: *Context, response: *Server.Response) !void {
    var buffer: [8096]u8 = undefined;
    const size = try response.readAll(&buffer);

    std.log.info("{s}", .{buffer[0..size]});

    var json_data = JsonType(Customer).init(ctx.allocator);
    try json_data.parseFromSlice(buffer[0..size]);
    ctx.last_key += 1;
    json_data.data.value.id = ctx.last_key;
    try ctx.customers.put(json_data.data.value.id, json_data);

    response.status = .created;
    if (response.request.headers.contains("connection")) {
        try response.headers.append("connection", "keep-alive");
    }

    response.transfer_encoding = .chunked;
    try response.headers.append("content-type", "application/json");

    try response.do();
    try json.stringify(json_data.data.value, .{}, response.writer());
    try response.finish();
}

pub fn getCustomers(ctx: *Context, response: *Server.Response) !void {
    response.status = .ok;
    if (response.request.headers.contains("connection")) {
        try response.headers.append("connection", "keep-alive");
    }

    response.transfer_encoding = .chunked;
    try response.headers.append("content-type", "applicatiosn/json");

    try response.do();
    try response.writeAll("[");
    var it = ctx.customers.keyIterator();

    var num: usize = 0;
    while (it.next()) |key| {
        const entry = ctx.customers.get(key.*);

        if (num > 0) {
            try response.writeAll(",");
        }
        if (entry) |val| {
            try json.stringify(val.data.value, .{}, response.writer());
        }
        num += 1;
    }

    try response.writeAll("]");
    try response.finish();
}

pub fn getCustomer(ctx: *Context, response: *Server.Response, id: u64) !void {
    const entry = ctx.customers.get(id);

    if (response.request.headers.contains("connection")) {
        try response.headers.append("connection", "keep-alive");
    }

    if (entry) |val| {
        response.status = .ok;
        response.transfer_encoding = .chunked;
        try response.headers.append("content-type", "application/json");
        try response.do();
        try json.stringify(val.data.value, .{}, response.writer());
        try response.finish();
    } else {
        response.status = .not_found;
        try response.do();
        try response.finish();
    }
}

pub fn deleteCustomer(ctx: *Context, response: *Server.Response, id: u64) !void {
    var entry = ctx.customers.get(id);

    if (response.request.headers.contains("connection")) {
        try response.headers.append("connection", "keep-alive");
    }

    if (entry) |*val| {
        defer val.deinit();
        _ = ctx.customers.remove(id);

        response.status = .ok;
        try response.do();
        try response.finish();
    } else {
        response.status = .not_found;
        try response.do();
        try response.finish();
    }
}
