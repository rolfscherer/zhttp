const std = @import("std");
const ascii = std.ascii;
const fs = std.fs;
const io = std.io;
const mem = std.mem;

const Allocator = mem.Allocator;

const tag_start = '{';
const tag_end = '}';
const tag_expression = '%';

pub fn TemplateReader(comptime buffer_size: usize, comptime ReaderType: type) type {
    return struct {
        allocator: Allocator,
        array: FileInfos,
        cfi: ?*FileInfo = null,
        buf: [buffer_size]u8 = undefined,
        start: usize = 0,
        end: usize = 0,

        var expression: [1024]u8 = undefined;
        var expression_len: usize = 0;

        pub const FillBufferError = error{ NoSpaceLeft, EndOfStream, UnexpectedEndOfStream, UnexpectedError, UnexpectedToken, OutOfMemory };
        pub const Error = ReaderType.Error || FillBufferError;
        pub const Reader = io.Reader(*Self, Error, read);

        pub const FileInfo = struct {
            unbuffered_reader: ReaderType,
            file: fs.File,
            eof: bool = false,
        };

        pub const FileInfos = std.ArrayList(FileInfo);

        const Self = @This();

        fn readByte(self: *Self) !u8 {
            if (self.cfi) |fileInfo| {
                var byte: u8 = fileInfo.unbuffered_reader.readByte() catch |err| switch (err) {
                    error.EndOfStream => {
                        fileInfo.file.close();

                        if (self.array.items.len > 1) {
                            _ = self.array.pop();
                            self.cfi = &self.array.items[self.array.items.len - 1];
                            return self.readByte();
                        } else {
                            fileInfo.eof = true;
                            return 0;
                        }
                    },
                    else => return err,
                };
                return byte;
            }

            return error.UnexpectedError;
        }

        fn parseExpression(self: *Self, exp: []const u8) !void {
            const INCLUDE = "include";

            if (mem.indexOfPos(u8, exp, 0, INCLUDE)) |pos| {
                var start = pos + INCLUDE.len + 1;
                var end: usize = 0;
                var idx = start;

                while (idx < exp.len) {
                    if (!ascii.isWhitespace(exp[idx])) {
                        break;
                    }

                    idx += 1;
                }

                if (exp[idx] != '"') {
                    return error.UnexpectedToken;
                }

                idx += 1;
                start = idx;

                while (idx < exp.len) {
                    if (exp[idx] == '"') {
                        end = idx;
                        std.log.info("File name: '{s}'", .{exp[start..end]});
                        break;
                    }

                    idx += 1;
                }

                const file = std.fs.cwd().openFile(exp[start..end], .{}) catch |err| {
                    std.log.info("Error: '{any}'", .{err});
                    return error.UnexpectedError;
                };
                var fr = file.reader();

                var fi: FileInfo = .{
                    .file = file,
                    .unbuffered_reader = fr,
                };
                try self.array.append(fi);

                self.cfi = &self.array.items[self.array.items.len - 1];
            }
        }

        fn readExpression(self: *Self) !void {
            var expressionStream = io.fixedBufferStream(&expression);
            var expressionWriter = expressionStream.writer();
            for (0..1024) |idx_tag| {
                var byte = try self.readByte();
                if (byte == 0) {
                    // Unexpected end of stream
                    return FillBufferError.UnexpectedEndOfStream;
                } else if (byte == tag_expression) {
                    const byteAhead = try self.readByte();
                    if (byteAhead == 0) {
                        // Unexpected end of stream
                        return FillBufferError.UnexpectedEndOfStream;
                    }
                    if (byteAhead == tag_end) {
                        expression_len = idx_tag;
                        break;
                    } else {
                        try expressionWriter.writeByte(byteAhead);
                    }
                } else {
                    try expressionWriter.writeByte(byte);
                }
            }
            std.log.info("Expression: '{s}'", .{expression[0..expression_len]});
            try self.parseExpression(expression[0..expression_len]);
        }

        fn fillBuffer(self: *Self) !usize {
            if (self.cfi) |fileInfo| {
                if (fileInfo.eof) {
                    return 0;
                }
            } else {
                return error.UnexpectedError;
            }
            var size: usize = 0;
            for (0..buffer_size) |_| {
                var byte: u8 = try self.readByte();
                if (byte == 0) {
                    return size;
                }

                // byte == {
                if (byte == tag_start) {
                    var byteAhead: u8 = try self.readByte();
                    if (byteAhead == 0) {
                        return size;
                    }

                    // byteAhead == '%'
                    if (byteAhead == tag_expression) {
                        // We have an expression
                        try self.readExpression();
                    } else {
                        // TODO support {{% expression %}}
                        // No expression, write bytes that have already been consumed to the buffer
                        self.buf[size] = byte;
                        size += 1;
                        self.buf[size] = byteAhead;
                        size += 1;
                    }
                } else {
                    self.buf[size] = byte;
                    size += 1;
                }
            }
            return size;
        }

        pub fn read(self: *Self, dest: []u8) Error!usize {
            if (self.cfi == null) {
                var last = self.array.getLast();
                self.cfi = &last;
            }

            var dest_index: usize = 0;

            while (dest_index < dest.len) {
                const written = @min(dest.len - dest_index, self.end - self.start);
                @memcpy(dest[dest_index..][0..written], self.buf[self.start..][0..written]);
                if (written == 0) {
                    const n = try self.fillBuffer();
                    if (n == 0) {
                        return dest_index;
                    }
                    self.start = 0;
                    self.end = n;
                }
                self.start += written;
                dest_index += written;
            }
            return dest.len;
        }

        pub fn init(allocator: Allocator, sub_path: []const u8) !Self {
            const file = try std.fs.cwd().openFile(sub_path, .{});
            var fr = file.reader();

            var fi: FileInfo = .{
                .file = file,
                .unbuffered_reader = fr,
            };

            var array = FileInfos.init(allocator);
            try array.append(fi);
            return .{ .allocator = allocator, .array = array };
        }

        pub fn deinit(self: *Self) void {
            self.array.deinit();
        }

        pub fn reader(self: *Self) Reader {
            return .{ .context = self };
        }
    };
}

pub fn templateReader(allocator: Allocator, sub_path: []const u8) !TemplateReader(8 * 1024, fs.File.Reader) {
    return bufferedReaderSize(allocator, sub_path, 8 * 1024);
}

pub fn bufferedReaderSize(allocator: Allocator, sub_path: []const u8, comptime size: usize) !TemplateReader(size, fs.File.Reader) {
    return TemplateReader(size, fs.File.Reader).init(allocator, sub_path);
}

test "refAllDecls" {
    std.testing.refAllDecls(@This());
}
