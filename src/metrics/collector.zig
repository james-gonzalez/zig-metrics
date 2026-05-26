const std = @import("std");
const cpu = @import("cpu.zig");
const memory = @import("memory.zig");
const network = @import("network.zig");
const disk = @import("disk.zig");

pub const Collector = struct {
    allocator: std.mem.Allocator,
    prev_cpu: ?cpu.CpuStats,

    pub fn init(allocator: std.mem.Allocator) Collector {
        return .{ .allocator = allocator, .prev_cpu = null };
    }

    pub fn deinit(_: *Collector) void {}

    /// Returns an allocated Prometheus text-format response body.
    /// Caller owns the memory.
    pub fn collect(self: *Collector, io: std.Io) ![]const u8 {
        const heap_buf = try self.allocator.alloc(u8, 256 * 1024);
        defer self.allocator.free(heap_buf);

        var w = std.Io.Writer.fixed(heap_buf);

        try self.writeCpu(io, &w);
        try self.writeMemory(io, &w);
        try self.writeNetwork(io, &w);
        try self.writeDisk(io, &w);

        return self.allocator.dupe(u8, heap_buf[0..w.end]);
    }

    fn writeCpu(self: *Collector, io: std.Io, w: *std.Io.Writer) !void {
        const current = cpu.read(self.allocator, io) catch |err| {
            std.log.warn("cpu read failed: {}", .{err});
            return;
        };

        const prev = self.prev_cpu;
        self.prev_cpu = current;

        const usage_percent: f64 = if (prev) |p| blk: {
            const total_diff = current.total() -| p.total();
            const idle_diff = current.idleTotal() -| p.idleTotal();
            if (total_diff == 0) break :blk 0.0;
            const active: f64 = @floatFromInt(total_diff - idle_diff);
            const total: f64 = @floatFromInt(total_diff);
            break :blk active / total * 100.0;
        } else 0.0;

        try w.writeAll("# HELP system_cpu_usage_percent Current CPU usage percentage\n");
        try w.writeAll("# TYPE system_cpu_usage_percent gauge\n");
        try w.print("system_cpu_usage_percent {d:.2}\n\n", .{usage_percent});
    }

    fn writeMemory(self: *Collector, io: std.Io, w: *std.Io.Writer) !void {
        const stats = memory.read(self.allocator, io) catch |err| {
            std.log.warn("memory read failed: {}", .{err});
            return;
        };

        try w.writeAll("# HELP system_memory_total_bytes Total installed memory\n");
        try w.writeAll("# TYPE system_memory_total_bytes gauge\n");
        try w.print("system_memory_total_bytes {d}\n", .{stats.total_bytes});

        try w.writeAll("# HELP system_memory_free_bytes Unallocated memory\n");
        try w.writeAll("# TYPE system_memory_free_bytes gauge\n");
        try w.print("system_memory_free_bytes {d}\n", .{stats.free_bytes});

        try w.writeAll("# HELP system_memory_available_bytes Memory available for new allocations\n");
        try w.writeAll("# TYPE system_memory_available_bytes gauge\n");
        try w.print("system_memory_available_bytes {d}\n", .{stats.available_bytes});

        try w.writeAll("# HELP system_memory_used_bytes Memory in use (total - free)\n");
        try w.writeAll("# TYPE system_memory_used_bytes gauge\n");
        try w.print("system_memory_used_bytes {d}\n\n", .{stats.total_bytes -| stats.free_bytes});
    }

    fn writeNetwork(self: *Collector, io: std.Io, w: *std.Io.Writer) !void {
        const stats = network.read(self.allocator, io) catch |err| {
            std.log.warn("network read failed: {}", .{err});
            return;
        };
        defer network.free(self.allocator, stats);

        try w.writeAll("# HELP system_network_receive_bytes_total Bytes received per interface\n");
        try w.writeAll("# TYPE system_network_receive_bytes_total counter\n");
        for (stats) |s| try w.print("system_network_receive_bytes_total{{interface=\"{s}\"}} {d}\n", .{ s.interface, s.rx_bytes });

        try w.writeAll("# HELP system_network_transmit_bytes_total Bytes transmitted per interface\n");
        try w.writeAll("# TYPE system_network_transmit_bytes_total counter\n");
        for (stats) |s| try w.print("system_network_transmit_bytes_total{{interface=\"{s}\"}} {d}\n", .{ s.interface, s.tx_bytes });

        try w.writeAll("# HELP system_network_receive_packets_total Packets received per interface\n");
        try w.writeAll("# TYPE system_network_receive_packets_total counter\n");
        for (stats) |s| try w.print("system_network_receive_packets_total{{interface=\"{s}\"}} {d}\n", .{ s.interface, s.rx_packets });

        try w.writeAll("# HELP system_network_transmit_packets_total Packets transmitted per interface\n");
        try w.writeAll("# TYPE system_network_transmit_packets_total counter\n");
        for (stats) |s| try w.print("system_network_transmit_packets_total{{interface=\"{s}\"}} {d}\n\n", .{ s.interface, s.tx_packets });
    }

    fn writeDisk(self: *Collector, io: std.Io, w: *std.Io.Writer) !void {
        const stats = disk.read(self.allocator, io) catch |err| {
            std.log.warn("disk read failed: {}", .{err});
            return;
        };
        defer disk.free(self.allocator, stats);

        try w.writeAll("# HELP system_disk_reads_completed_total Disk read operations completed\n");
        try w.writeAll("# TYPE system_disk_reads_completed_total counter\n");
        for (stats) |s| try w.print("system_disk_reads_completed_total{{device=\"{s}\"}} {d}\n", .{ s.device, s.reads_completed });

        try w.writeAll("# HELP system_disk_writes_completed_total Disk write operations completed\n");
        try w.writeAll("# TYPE system_disk_writes_completed_total counter\n");
        for (stats) |s| try w.print("system_disk_writes_completed_total{{device=\"{s}\"}} {d}\n", .{ s.device, s.writes_completed });

        try w.writeAll("# HELP system_disk_read_bytes_total Bytes read from disk\n");
        try w.writeAll("# TYPE system_disk_read_bytes_total counter\n");
        for (stats) |s| try w.print("system_disk_read_bytes_total{{device=\"{s}\"}} {d}\n", .{ s.device, s.readBytes() });

        try w.writeAll("# HELP system_disk_written_bytes_total Bytes written to disk\n");
        try w.writeAll("# TYPE system_disk_written_bytes_total counter\n");
        for (stats) |s| try w.print("system_disk_written_bytes_total{{device=\"{s}\"}} {d}\n\n", .{ s.device, s.writtenBytes() });
    }
};
