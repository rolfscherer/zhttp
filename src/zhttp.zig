const std = @import("std");

pub const router = @import("router.zig");
pub const http_server = @import("http_server.zig");

test {
    _ = @import("config.zig");
    _ = @import("http_server.zig");
    _ = @import("trie.zig");
}
