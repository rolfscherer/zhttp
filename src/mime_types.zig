const std = @import("std");

pub fn fromFileName(name: []const u8) []const u8 {
    return fromExtension(std.fs.path.extension(name));
}

pub fn fromExtension(ext: []const u8) []const u8 {
    const mime = map.get(ext);
    if (mime) |m| return m;

    return "text/plain;charset=UTF-8";
}

pub const map = std.ComptimeStringMap([]const u8, .{
    .{ ".au", "audio/basic" },
    .{ ".avi", "video/x-msvideo" },
    .{ ".bmp", "image/bmp" },
    .{ ".css", "text/css" },
    .{ ".csv", "text/csv" },
    .{ ".gif", "image/gif" },
    .{ ".htm", "text/html" },
    .{ ".html", "text/html" },
    .{ ".ico", "image/x-icon" },
    .{ ".ics", "text/calendar" },
    .{ ".ief", "image/ief" },
    .{ ".jpe", "image/jpeg" },
    .{ ".jpeg", "image/jpeg" },
    .{ ".jpg", "image/jpeg" },
    .{ ".jpgm", "video/jpm" },
    .{ ".jpgv", "video/jpeg" },
    .{ ".jpm", "video/jpm" },
    .{ ".js", "application/javascript" },
    .{ ".json", "application/json" },
    .{ ".mid", "audio/midi" },
    .{ ".midi", "audio/midi" },
    .{ ".mime", "message/rfc822" },
    .{ ".mov", "video/quicktime" },
    .{ ".movie", "video/x-sgi-movie" },
    .{ ".mp2", "audio/mpeg" },
    .{ ".mp2a", "audio/mpeg" },
    .{ ".mp3", "audio/mpeg" },
    .{ ".mp4", "video/mp4" },
    .{ ".mp4a", "audio/mp4" },
    .{ ".mp4s", "application/mp4" },
    .{ ".mp4v", "video/mp4" },
    .{ ".mpa", "video/mpeg" },
    .{ ".mpe", "video/mpeg" },
    .{ ".mpeg", "video/mpeg" },
    .{ ".mpg", "video/mpeg" },
    .{ ".mpg4", "video/mp4" },
    .{ ".mpga", "audio/mpeg" },
    .{ ".msi", "application/x-msdownload" },
    .{ ".oga", "audio/ogg" },
    .{ ".ogg", "audio/ogg" },
    .{ ".ogv", "video/ogg" },
    .{ ".pbm", "image/x-portable-bitmap" },
    .{ ".pcf", "application/x-font-pcf" },
    .{ ".pdf", "application/pdf" },
    .{ ".pic", "image/x-pict" },
    .{ ".png", "image/png" },
    .{ ".pnm", "image/x-portable-anymap" },
    .{ ".ppt", "application/vnd.ms-powerpoint" },
    .{ ".ra", "audio/x-pn-realaudio" },
    .{ ".ram", "audio/x-pn-realaudio" },
    .{ ".rgb", "image/x-rgb" },
    .{ ".rmi", "audio/midi" },
    .{ ".svg", "image/svg+xml" },
    .{ ".svgz", "image/svg+xml" },
    .{ ".tif", "image/tiff" },
    .{ ".tiff", "image/tiff" },
    .{ ".wav", "audio/x-wav" },
    .{ ".wm", "video/x-ms-wm" },
    .{ ".wma", "audio/x-ms-wma" },
    .{ ".wmv", "video/x-ms-wmv" },
    .{ ".wmx", "video/x-ms-wmx" },
    .{ ".xbm", "image/x-xbitmap" },
    .{ ".xif", "image/vnd.xiff" },
    .{ ".xml", "application/xml" },
    .{ ".xsl", "application/xml" },
    .{ ".xslt", "application/xslt+xml" },
    .{ ".xspf", "application/xspf+xml" },
    .{ ".zip", "application/zip" },
});

test {
    std.testing.refAllDecls(@This());
}
