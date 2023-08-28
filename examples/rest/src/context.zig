const std = @import("std");
const mem = std.mem;
const Allocator = mem.Allocator;

const customer = @import("customer.zig");

pub const Context = struct {
    allocator: Allocator,
    customers: customer.Customers,
    last_key: u64 = 0,
};
