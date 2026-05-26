const std = @import("std");

pub const NetStats = struct {
    interface: []const u8,
    rx_bytes: u64,
    rx_packets: u64,
    rx_errors: u64,
    rx_drop: u64,
    tx_bytes: u64,
    tx_packets: u64,
    tx_errors: u64,
    tx_drop: u64,
};

/// Reads per-interface network stats from /proc/net/dev.
/// Caller owns the returned slice; free with network.free().
pub fn read(allocator: std.mem.Allocator) ![]NetStats {
    const file = try std.fs.openFileAbsolute("/proc/net/dev", .{});
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 64 * 1024);
    defer allocator.free(content);

    var interfaces: std.ArrayList(NetStats) = .empty;
    errdefer {
        for (interfaces.items) |s| allocator.free(s.interface);
        interfaces.deinit(allocator);
    }

    var lines = std.mem.splitScalar(u8, content, '\n');
    var line_num: usize = 0;
    while (lines.next()) |line| {
        line_num += 1;
        if (line_num <= 2) continue; // skip the two header lines
        if (line.len == 0) continue;

        const trimmed = std.mem.trim(u8, line, " \t");
        const colon = std.mem.indexOfScalar(u8, trimmed, ':') orelse continue;
        const iface = std.mem.trim(u8, trimmed[0..colon], " \t");
        const values = std.mem.trim(u8, trimmed[colon + 1 ..], " \t");

        var t = std.mem.tokenizeAny(u8, values, " \t");
        // Receive: bytes packets errs drop fifo frame compressed multicast
        const rx_bytes = std.fmt.parseInt(u64, t.next() orelse continue, 10) catch continue;
        const rx_packets = std.fmt.parseInt(u64, t.next() orelse continue, 10) catch continue;
        const rx_errors = std.fmt.parseInt(u64, t.next() orelse continue, 10) catch continue;
        const rx_drop = std.fmt.parseInt(u64, t.next() orelse continue, 10) catch continue;
        _ = t.next(); // fifo
        _ = t.next(); // frame
        _ = t.next(); // compressed
        _ = t.next(); // multicast
        // Transmit: bytes packets errs drop fifo colls carrier compressed
        const tx_bytes = std.fmt.parseInt(u64, t.next() orelse continue, 10) catch continue;
        const tx_packets = std.fmt.parseInt(u64, t.next() orelse continue, 10) catch continue;
        const tx_errors = std.fmt.parseInt(u64, t.next() orelse continue, 10) catch continue;
        const tx_drop = std.fmt.parseInt(u64, t.next() orelse continue, 10) catch continue;

        const iface_copy = try allocator.dupe(u8, iface);
        try interfaces.append(allocator, .{
            .interface = iface_copy,
            .rx_bytes = rx_bytes,
            .rx_packets = rx_packets,
            .rx_errors = rx_errors,
            .rx_drop = rx_drop,
            .tx_bytes = tx_bytes,
            .tx_packets = tx_packets,
            .tx_errors = tx_errors,
            .tx_drop = tx_drop,
        });
    }

    return interfaces.toOwnedSlice(allocator);
}

pub fn free(allocator: std.mem.Allocator, stats: []NetStats) void {
    for (stats) |s| allocator.free(s.interface);
    allocator.free(stats);
}
