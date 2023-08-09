const std = @import("std");
const http = std.http;
const log = std.log;
const mem = std.mem;
const net = std.net;

const Address = net.Address;
const Allocator = mem.Allocator;
const Server = http.Server;

const config = @import("config.zig");
const router = @import("router.zig");

const ServerConfig = config.ServerConfig;

pub const HttpServer = struct {
    allocator: Allocator,
    handle_new_requests: bool = false,
    running: bool = false,
    address: Address = undefined,
    server: Server = undefined,
    pool: *std.Thread.Pool = undefined,
    config: ServerConfig = undefined,

    const Self = @This();

    pub const Error = error{
        OutOfMemory,
    };

    pub fn init(allocator: mem.Allocator) Self {
        return Self{
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) !void {
        self.pool.deinit();
        self.allocator.destroy(self.pool);
        self.config.deinit();
    }

    pub fn startServer(
        self: *Self,
        config_file_name: []const u8,
        context: anytype,
        comptime handler: router.RequestHandler(@TypeOf(context)),
    ) !void {
        self.config = config.ServerConfig.init(self.allocator);
        try self.config.loadConfigFromFile(config_file_name);

        log.info("Starting Server with IP-address {s} and port {d}", .{ self.config.getIpv4Address(), self.config.getIpv4Port() });
        self.server = http.Server.init(self.allocator, .{ .reuse_address = true });
        self.address = net.Address.parseIp(self.config.getIpv4Address(), self.config.getIpv4Port()) catch unreachable;
        try self.server.listen(self.address);

        self.running = true;
        self.handle_new_requests = true;
        self.pool = try self.allocator.create(std.Thread.Pool);
        try self.pool.init(.{ .allocator = self.allocator });

        while (self.handle_new_requests) {
            var res = try self.allocator.create(Server.Response);
            res.* = try self.server.accept(.{
                .allocator = self.allocator,
                .header_strategy = .{ .dynamic = self.config.getMaxHeaderSize() },
            });
            try self.pool.spawn(responseThread, .{ res, context, handler });
        }
    }

    fn responseThread(res: *Server.Response, context: anytype, comptime handler: router.RequestHandler(@TypeOf(context))) void {
        defer res.allocator.destroy(res);
        defer res.deinit();

        while (res.reset() != .closing) {
            res.wait() catch |err| switch (err) {
                error.HttpHeadersInvalid => return,
                error.EndOfStream => continue,
                else => return,
            };

            log.info("{s} {s} {s}", .{ @tagName(res.request.method), @tagName(res.request.version), res.request.target });
            handler(context, res) catch |err| switch (err) {
                else => |e| {
                    std.log.warn("Unexpected Error {any}", .{e});
                    return;
                },
            };
        }
    }

    pub fn killServer(self: *Self) void {
        log.info("Killing server", .{});
        self.handle_new_requests = false;

        std.time.sleep(std.time.ns_per_s * 2);

        const conn = std.net.tcpConnectToAddress(self.address) catch return;
        conn.close();

        try self.deinit();
    }
};

test {
    std.testing.refAllDecls(@This());
}
