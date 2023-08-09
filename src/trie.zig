const std = @import("std");
const mem = std.mem;

pub const Entry = struct {
    key: []const u8,
    value: []const u8,
};

pub fn Trie(comptime T: type) type {
    return struct {
        const Self = @This();
        const max_params: usize = 10;

        const Node = struct {
            childs: []*Node,
            label: enum { none, all, param },
            path: []const u8,
            data: ?T,
        };

        size: usize = 0,
        root: Node = Node{ .childs = &.{}, .label = .none, .path = "/", .data = null },

        /// Result is an union which is returned when trying to find
        /// from a path
        const Result = union(ResultTag) {
            none: void,
            static: T,
            with_params: struct {
                data: T,
                params: [max_params]Entry,
                param_count: usize,
            },

            const ResultTag = enum { none, static, with_params };
        };

        /// Inserts new nodes based on the given path
        /// `path`[0] must be '/'
        pub fn insert(comptime self: *Self, comptime path: []const u8, comptime data: T) void {
            if (path.len == 1 and path[0] == '/') {
                self.root.data = data;
                return;
            }

            if (path[0] != '/') @compileError("Path must start with /");
            if (comptime mem.count(u8, path, ":") > max_params) @compileError("This path contains too many Entrys");

            comptime var it = mem.splitSequence(u8, path[1..], "/");
            comptime var current = &self.root;

            comptime {
                loop: while (it.next()) |subPath| {
                    var new_node = Node{
                        .path = subPath,
                        .childs = &[_]*Node{},
                        .label = .none,
                        .data = null,
                    };

                    for (current.childs) |child| {
                        if (mem.eql(u8, child.path, subPath)) {
                            current = child;
                            continue :loop;
                        }
                    }

                    self.size += 1;

                    if (subPath.len > 0) {
                        new_node.label = switch (subPath[0]) {
                            ':' => .param,
                            '*' => .all,
                            else => .none,
                        };
                    }

                    var childs: [current.childs.len + 1]*Node = undefined;
                    mem.copy(*Node, &childs, current.childs ++ [_]*Node{&new_node});
                    current.childs = &childs;
                    current = &new_node;

                    if (current.label == .all) break;
                }
            }
            current.data = data;
        }
        /// Retrieves T based on the given path
        /// when a wildcard such as * is found, it will return T
        /// If a colon is found, it will add the path piece onto the param list
        pub fn get(self: *Self, path: []const u8) Result {
            if (path.len == 1) {
                if (self.root.data) |data| {
                    return .{ .static = data };
                } else {
                    return .none;
                }
            }

            var new_path = path;
            var pos = mem.indexOfPos(u8, path, 0, "?");
            if (pos != null) {
                var it = mem.splitSequence(u8, new_path[0..], "?");
                if (it.next()) |p| {
                    new_path = p;
                }
            }

            var params: [max_params]Entry = undefined;
            var param_count: usize = 0;
            var current = &self.root;
            var it = mem.splitSequence(u8, new_path[1..], "/");
            var index: usize = 0;

            loop: while (it.next()) |component| {
                index += component.len + 1;
                for (current.childs) |child| {
                    if (mem.eql(u8, component, child.path) or child.label == .param or child.label == .all) {
                        if (child.label == .all) {
                            if (child.data == null) return .none;

                            var result = Result{
                                .with_params = .{
                                    .data = child.data.?,
                                    .params = undefined,
                                    .param_count = param_count,
                                },
                            };

                            // Add the wildcard as param as well
                            // returns full result from wildcard onwards
                            params[param_count] = .{ .key = child.path, .value = new_path[index - component.len ..] };
                            mem.copy(Entry, &result.with_params.params, &params);
                            return result;
                        }
                        if (child.label == .param) {
                            params[param_count] = .{ .key = child.path[1..], .value = component };
                            param_count += @intFromBool(param_count < max_params);
                        }
                        current = child;
                        continue :loop;
                    }
                }
                return .none;
            }

            if (current.data == null) return .none;
            if (param_count == 0) return .{ .static = current.data.? };

            var result = Result{
                .with_params = .{
                    .data = current.data.?,
                    .params = undefined,
                    .param_count = param_count,
                },
            };

            mem.copyForwards(Entry, &result.with_params.params, &params);
            return result;
        }
    };
}

test {
    std.testing.refAllDecls(@This());
}
