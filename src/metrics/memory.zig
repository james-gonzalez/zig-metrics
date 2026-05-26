const std = @import("std");

pub const MemStats = struct {
    total_bytes: u64,
    free_bytes: u64,
    available_bytes: u64,
    buffers_bytes: u64,
    cached_bytes: u64,
};

/// Reads memory stats from /proc/meminfo.
pub fn read(allocator: std.mem.Allocator) !MemStats {
    const file = try std.fs.openFileAbsolute("/proc/meminfo", .{});
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 64 * 1024);
    defer allocator.free(content);

    var stats = MemStats{
        .total_bytes = 0,
        .free_bytes = 0,
        .available_bytes = 0,
        .buffers_bytes = 0,
        .cached_bytes = 0,
    };

    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) continue;

        const colon = std.mem.indexOfScalar(u8, line, ':') orelse continue;
        const key = line[0..colon];
        const rest = std.mem.trim(u8, line[colon + 1 ..], " \t");

        // Values are "<number> kB"
        var tokens = std.mem.tokenizeAny(u8, rest, " \t");
        const num_str = tokens.next() orelse continue;
        const kb = std.fmt.parseInt(u64, num_str, 10) catch continue;
        const bytes = kb * 1024;

        if (std.mem.eql(u8, key, "MemTotal")) {
            stats.total_bytes = bytes;
        } else if (std.mem.eql(u8, key, "MemFree")) {
            stats.free_bytes = bytes;
        } else if (std.mem.eql(u8, key, "MemAvailable")) {
            stats.available_bytes = bytes;
        } else if (std.mem.eql(u8, key, "Buffers")) {
            stats.buffers_bytes = bytes;
        } else if (std.mem.eql(u8, key, "Cached")) {
            stats.cached_bytes = bytes;
        }
    }

    return stats;
}
