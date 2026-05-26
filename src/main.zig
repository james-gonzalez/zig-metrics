const std = @import("std");
const server = @import("server.zig");

pub fn main(init: std.process.Init) !void {
    var gpa: std.heap.DebugAllocator(.{}) = .init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const port: u16 = 9090;
    std.log.info("Starting zig-metrics on :{d}", .{port});
    try server.run(allocator, init.io, port);
}
