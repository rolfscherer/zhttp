const std = @import("std");
const json = std.json;
const mem = std.mem;

const Allocator = mem.Allocator;
const ParseConfig = json.Parsed(Config);

pub const Config = struct {
    server: struct { name: []const u8, ipv4: struct {
        address: []const u8,
        port: u16,
    } },
    http: struct {
        max_header_size: u16,
    },
};

pub const ServerConfig = struct {
    allocator: Allocator,
    config: ParseConfig = undefined,

    const Self = @This();

    pub fn init(allocator: mem.Allocator) Self {
        return Self{
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.config.deinit();
    }

    pub fn loadConfigFromFile(self: *Self, sub_path: []const u8) !void {
        const data = try std.fs.cwd().readFileAlloc(self.allocator, sub_path, 2048);
        defer self.allocator.free(data);
        self.config = try std.json.parseFromSlice(Config, self.allocator, data, .{ .allocate = .alloc_always });
    }

    pub fn getServerName(self: *Self) []const u8 {
        return self.config.value.server.name;
    }

    pub fn getIpv4Address(self: *Self) []const u8 {
        return self.config.value.server.ipv4.address;
    }

    pub fn getIpv4Port(self: *Self) u16 {
        return self.config.value.server.ipv4.port;
    }

    pub fn getMaxHeaderSize(self: *Self) u16 {
        return self.config.value.http.max_header_size;
    }
};

test {
    std.testing.refAllDecls(@This());
}

test "read config ok" {
    var allocator = std.testing.allocator;

    var config = ServerConfig.init(allocator);
    defer config.deinit();

    try config.loadConfigFromFile("test/config1.json");

    try std.testing.expect(mem.eql(u8, "test", config.getServerName()));
    try std.testing.expect(mem.eql(u8, "127.0.0.1", config.getIpv4Address()));
    try std.testing.expectEqual(@as(u16, 8080), config.getIpv4Port());
    try std.testing.expectEqual(@as(u16, 32768), config.getMaxHeaderSize());
}
