const std = @import("std");
const mem = std.mem;

const Allocator = mem.Allocator;
const tr = @import("reader.zig");

pub fn readFileTillDelimiter(allocator: Allocator, template_path: []const u8, file_name: []const u8) !void {
    var reader = try tr.templateReader(allocator, template_path, file_name);
    var buf: [8 * 1024]u8 = undefined;
    const stdout_file = std.io.getStdOut().writer();
    try stdout_file.writeByte('\n');
    var size = try reader.read(&buf);
    while (size > 0) {
        try stdout_file.writeAll(buf[0..size]);
        size = try reader.read(&buf);
    }
    try stdout_file.writeByte('\n');
}

pub fn readFileTillDelimiter2(sub_path: []const u8) !void {
    const buffer_size: usize = 1024 * 8;

    var buffer: [buffer_size]u8 = undefined;
    var file_name: [1024]u8 = undefined;
    var file_name_len: usize = 0;
    var fbs = std.io.fixedBufferStream(&buffer);
    var writer = fbs.writer();
    const file = try std.fs.cwd().openFile(sub_path, .{});
    var reader = file.reader();

    for (0..buffer_size) |_| {
        var byte: u8 = reader.readByte() catch |err| switch (err) {
            error.EndOfStream => {
                file.close();
                return;
            },
            else => return err,
        };

        if (byte == '{') {
            var byteAhead: u8 = reader.readByte() catch |err| switch (err) {
                error.EndOfStream => {
                    file.close();
                    return;
                },
                else => return err,
            };

            if (byteAhead == '!') {
                var fbsfn = std.io.fixedBufferStream(&file_name);
                var wfn = fbsfn.writer();
                for (0..1024) |idx| {
                    byte = try reader.readByte();
                    if (byte == '!') {
                        byteAhead = try reader.readByte();
                        if (byteAhead == '}') {
                            file_name_len = idx - 1;
                            break;
                        }
                    } else if (byte != ' ') {}
                    try wfn.writeByte(byte);
                }
                std.log.info("Filename: '{s}'", .{file_name[0..file_name_len]});
            } else {
                try writer.writeByte('{');
                try writer.writeByte(byteAhead);
            }
        } else {
            try writer.writeByte(byte);
        }
    }
}

test "refAllDecls" {
    std.testing.refAllDecls(@This());
}
