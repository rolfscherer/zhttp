const std = @import("std");
const http = std.http;
const trie = @import("trie.zig");

pub const Entry = trie.Entry;

/// User API function signature of a request handler
pub fn RequestHandler(comptime Context: type) type {
    return fn (Context, *http.Server.Response) anyerror!void;
}

/// Route defines the path, method and how to parse such path
/// into a type that the handler can accept.
pub fn Route(comptime Context: type) type {
    return struct {
        /// Path by which the route is triggered
        path: []const u8,
        /// The handler function that will be called when triggered
        handler: *const Handler,
        /// http method
        method: http.Method,

        const Handler = fn (Context, *http.Server.Response, params: []const Entry) anyerror!void;
    };
}

pub fn notFound(response: *http.Server.Response) anyerror!void {
    var arrayList: std.ArrayList(u8) = std.ArrayList(u8).init(response.allocator);
    defer arrayList.deinit();

    std.log.info("Path not found, {s}", .{response.request.target});
    response.status = .not_found;
    if (response.request.headers.contains("connection")) {
        try response.headers.append("connection", "keep-alive");
    }

    try arrayList.appendSlice("<head></head><body><h1>404</h1><p>Page not found</p><body>");

    response.transfer_encoding = .{ .content_length = arrayList.items.len };
    try response.headers.append("content-type", "text/html");

    try response.do();
    if (response.request.method != .HEAD) {
        response.writeAll(arrayList.items) catch |err| {
            std.log.err("Ups {any}", .{err});
            return;
        };
        try response.finish();
    }
}

/// Generic function that inserts each route's path into a radix tree
/// to retrieve the right route when a request has been made
pub fn router(comptime Context: type, comptime routes: []const Route(Context)) RequestHandler(Context) {
    comptime var trees: [9]trie.Trie(u8) = undefined;
    inline for (&trees) |*t| t.* = trie.Trie(u8){};

    inline for (routes, 0..) |r, i| {
        trees[@intFromEnum(r.method)].insert(r.path, i);
    }

    return struct {
        const Self = @This();

        pub fn serve(context: Context, response: *http.Server.Response) anyerror!void {
            switch (trees[@intFromEnum(response.request.method)].get(response.request.target)) {
                .none => try notFound(response),
                .static => |index| {
                    inline for (routes, 0..) |route, i| {
                        if (index == i) return route.handler(context, response, &.{});
                    }
                },
                .with_params => |object| {
                    inline for (routes, 0..) |route, i| {
                        if (object.data == i)
                            return route.handler(context, response, object.params[0..object.param_count]);
                    }
                },
            }
        }
    }.serve;
}

pub fn wrap(comptime Context: type, comptime handler: anytype) Route(Context).Handler {
    const info = @typeInfo(@TypeOf(handler));
    if (info != .Fn)
        @compileError("router.wrap expects a function type");

    const function_info = info.Fn;
    if (function_info.is_generic)
        @compileError("Cannot create handler wrapper for generic function");
    if (function_info.is_var_args)
        @compileError("Cannot create handler wrapper for variadic function");

    if (function_info.params.len < 2)
        @compileError("Expected at least 2 args in Handler function; (" ++ @typeName(Context) ++ ", " ++ @typeName(*http.Server.Response) ++ ")]");

    assertIsType("Expected first argument of handler to be", Context, function_info.params[0].type.?);
    assertIsType("Expected second argument of handler to be", *http.Server.Response, function_info.params[1].type.?);

    if (function_info.params.len < 3) {
        // There is no 3th parameter, we can just ignore `params`
        const X = struct {
            fn wrapped(ctx: Context, res: *http.Server.Response, params: []const trie.Entry) anyerror!void {
                std.debug.assert(params.len == 0);
                return handler(ctx, res);
            }
        };
        return X.wrapped;
    }

    const ArgType = function_info.params[2].type.?;

    if (ArgType == []const u8) {
        // There 3th parameter is a string
        const X = struct {
            fn wrapped(ctx: Context, res: *http.Server.Response, params: []const trie.Entry) anyerror!void {
                std.debug.assert(params.len == 1);
                return handler(ctx, res, params[0].value);
            }
        };
        return X.wrapped;
    }

    if (@typeInfo(ArgType) == .Struct) {
        // There 3th parameter is a struct
        const X = struct {
            fn wrapped(ctx: Context, res: *http.Server.Response, params: []const trie.Entry) anyerror!void {
                const CaptureStruct = function_info.params[2].type.?;
                var captures: CaptureStruct = undefined;

                std.debug.assert(params.len == @typeInfo(CaptureStruct).Struct.fields.len);

                for (params) |param| {
                    // Using a variable here instead of something like `continue :params_loop` because that causes the compiler to crash with exit code 11.
                    var matched_a_field = false;
                    inline for (@typeInfo(CaptureStruct).Struct.fields) |field| {
                        assertIsType("Expected field " ++ field.name ++ " of " ++ @typeName(CaptureStruct) ++ " to be", []const u8, field.type);
                        if (std.mem.eql(u8, param.key, field.name)) {
                            @field(captures, field.name) = param.value;
                            matched_a_field = true;
                        }
                    }
                    if (!matched_a_field)
                        std.debug.panic("Unexpected capture \"{}\", no such field in {s}", .{ std.zig.fmtEscapes(param.key), @typeName(CaptureStruct) });
                }

                return handler(ctx, res, captures);
            }
        };
        return X.wrapped;
    }

    @compileError("Unsupported type `" ++ @typeName(ArgType) ++ "`. Must be `[]const u8` or a struct whose fields are `[]const u8`.");
}

fn assertIsType(comptime text: []const u8, comptime expected: type, comptime actual: type) void {
    if (actual != expected)
        @compileError(text ++ " " ++ @typeName(expected) ++ ", but found type " ++ @typeName(actual) ++ " instead");
}

/// Creates a builder namespace, generic over the given `Context`
/// This makes it easy to create the routers without having to passing
/// a lot of the types.
pub fn Builder(comptime Context: type) type {
    return struct {
        /// Creates a new `Route` for the given HTTP Method that will be
        /// triggered based on its path conditions
        ///
        /// When the path contains parameters such as ':<name>' it will be captured
        /// and passed into the handlerFn as the 4th parameter. See the `wrap` function
        /// for more information on how captures are passed down.
        pub fn basicRoute(
            comptime method: http.Method,
            comptime path: []const u8,
            comptime handlerFn: anytype,
        ) Route(Context) {
            return Route(Context){
                .method = method,
                .path = path,
                .handler = wrap(Context, handlerFn),
            };
        }

        /// Shorthand function to create a `Route` where method is 'GET'
        pub fn get(path: []const u8, comptime handlerFn: anytype) Route(Context) {
            return basicRoute(.GET, path, handlerFn);
        }
        /// Shorthand function to create a `Route` where method is 'POST'
        pub fn post(path: []const u8, comptime handlerFn: anytype) Route(Context) {
            return basicRoute(.POST, path, handlerFn);
        }
        /// Shorthand function to create a `Route` where method is 'PATCH'
        pub fn patch(path: []const u8, comptime handlerFn: anytype) Route(Context) {
            return basicRoute(.PATCH, path, handlerFn);
        }
        /// Shorthand function to create a `Route` where method is 'PUT'
        pub fn put(path: []const u8, comptime handlerFn: anytype) Route(Context) {
            return basicRoute(.PUT, path, handlerFn);
        }
        /// Shorthand function to create a `Route` where method is 'HEAD'
        pub fn head(path: []const u8, comptime handlerFn: anytype) Route(Context) {
            return basicRoute(.HEAD, path, handlerFn);
        }
        /// Shorthand function to create a `Route` where method is 'DELETE'
        pub fn delete(path: []const u8, comptime handlerFn: anytype) Route(Context) {
            return basicRoute(.DELETE, path, handlerFn);
        }
        /// Shorthand function to create a `Route` where method is 'CONNECT'
        pub fn connect(path: []const u8, comptime handlerFn: anytype) Route(Context) {
            return basicRoute(.CONNECT, path, handlerFn);
        }
        /// Shorthand function to create a `Route` where method is 'OPTIONS'
        pub fn options(path: []const u8, comptime handlerFn: anytype) Route(Context) {
            return basicRoute(.OPTIONS, path, handlerFn);
        }
        /// Shorthand function to create a `Route` where method is 'TRACE'
        pub fn trace(path: []const u8, comptime handlerFn: anytype) Route(Context) {
            return basicRoute(.TRACE, path, handlerFn);
        }
    };
}

test "refAllDecls" {
    std.testing.refAllDecls(@This());
}
