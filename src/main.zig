const std = @import("std");
const server = @import("server.zig");

pub fn main(init: std.process.Init) !void {
    _ = init;

    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const port: u16 = 9090;
    std.log.info("Starting zig-metrics on :{d}", .{port});
    try server.run(allocator, port);
}

test "server runs" {
    // Integration tests live in server.zig and metrics/ — nothing to test here.
}
