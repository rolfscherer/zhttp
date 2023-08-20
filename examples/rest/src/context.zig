const std = @import("std");
const mem = std.mem;
const Allocator = mem.Allocator;

pub const Context = struct {
    allocator: Allocator,
    counter: usize = 0,
};
