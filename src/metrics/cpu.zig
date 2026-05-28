const std = @import("std");
const procfs = @import("procfs.zig");

pub const CpuStats = struct {
    user: u64,
    nice: u64,
    system: u64,
    idle: u64,
    iowait: u64,
    irq: u64,
    softirq: u64,
    steal: u64,

    pub fn total(self: CpuStats) u64 {
        return self.user + self.nice + self.system + self.idle +
            self.iowait + self.irq + self.softirq + self.steal;
    }

    pub fn idleTotal(self: CpuStats) u64 {
        return self.idle + self.iowait;
    }
};

/// Reads aggregate CPU stats from /proc/stat.
pub fn read(allocator: std.mem.Allocator, io: std.Io) !CpuStats {
    const content = try procfs.readFile(allocator, io, "/proc/stat");
    defer allocator.free(content);

    var lines = std.mem.splitScalar(u8, content, '\n');
    const first_line = lines.first();

    // Format: "cpu  <user> <nice> <system> <idle> <iowait> <irq> <softirq> <steal> ..."
    var tokens = std.mem.tokenizeAny(u8, first_line, " \t");
    _ = tokens.next(); // skip "cpu"

    return .{
        .user = try parseNext(&tokens),
        .nice = try parseNext(&tokens),
        .system = try parseNext(&tokens),
        .idle = try parseNext(&tokens),
        .iowait = try parseNext(&tokens),
        .irq = try parseNext(&tokens),
        .softirq = try parseNext(&tokens),
        .steal = try parseNext(&tokens),
    };
}

fn parseNext(tokens: anytype) !u64 {
    const tok = tokens.next() orelse return error.UnexpectedEndOfData;
    return std.fmt.parseInt(u64, tok, 10);
}

test "cpu stats total" {
    const s = CpuStats{ .user = 100, .nice = 0, .system = 50, .idle = 800, .iowait = 10, .irq = 0, .softirq = 0, .steal = 0 };
    try std.testing.expectEqual(@as(u64, 960), s.total());
    try std.testing.expectEqual(@as(u64, 810), s.idleTotal());
}
