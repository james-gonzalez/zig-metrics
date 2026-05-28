const std = @import("std");
const procfs = @import("procfs.zig");

pub const DiskStats = struct {
    device: []const u8,
    reads_completed: u64,
    sectors_read: u64,
    writes_completed: u64,
    sectors_written: u64,

    pub fn readBytes(self: DiskStats) u64 {
        return self.sectors_read * 512;
    }

    pub fn writtenBytes(self: DiskStats) u64 {
        return self.sectors_written * 512;
    }
};

/// Reads per-device disk stats from /proc/diskstats.
/// Caller owns the returned slice; free with disk.free().
pub fn read(allocator: std.mem.Allocator, io: std.Io) ![]DiskStats {
    const content = try procfs.readFile(allocator, io, "/proc/diskstats");
    defer allocator.free(content);

    var disks: std.ArrayList(DiskStats) = .empty;
    errdefer {
        for (disks.items) |d| allocator.free(d.device);
        disks.deinit(allocator);
    }

    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) continue;

        var t = std.mem.tokenizeAny(u8, line, " \t");
        _ = t.next(); // major
        _ = t.next(); // minor
        const device = t.next() orelse continue;

        // Fields 1-4: reads_completed, reads_merged, sectors_read, time_reading_ms
        const reads_completed = std.fmt.parseInt(u64, t.next() orelse continue, 10) catch continue;
        _ = t.next(); // reads merged
        const sectors_read = std.fmt.parseInt(u64, t.next() orelse continue, 10) catch continue;
        _ = t.next(); // time reading
        // Fields 5-8: writes_completed, writes_merged, sectors_written, time_writing_ms
        const writes_completed = std.fmt.parseInt(u64, t.next() orelse continue, 10) catch continue;
        _ = t.next(); // writes merged
        const sectors_written = std.fmt.parseInt(u64, t.next() orelse continue, 10) catch continue;

        const device_copy = try allocator.dupe(u8, device);
        try disks.append(allocator, .{
            .device = device_copy,
            .reads_completed = reads_completed,
            .sectors_read = sectors_read,
            .writes_completed = writes_completed,
            .sectors_written = sectors_written,
        });
    }

    return disks.toOwnedSlice(allocator);
}

pub fn free(allocator: std.mem.Allocator, stats: []DiskStats) void {
    for (stats) |d| allocator.free(d.device);
    allocator.free(stats);
}
