const std = @import("std");
const net = std.Io.net;
const Collector = @import("metrics/collector.zig").Collector;

pub fn run(allocator: std.mem.Allocator, io: std.Io, port: u16) !void {
    var addr_buf: [22]u8 = undefined;
    const addr_str = try std.fmt.bufPrint(&addr_buf, "0.0.0.0:{d}", .{port});
    const address = try net.IpAddress.parseLiteral(addr_str);

    var tcp_server = try address.listen(io, .{ .reuse_address = true });
    defer tcp_server.deinit(io);

    std.log.info("Listening on 0.0.0.0:{d} — /metrics /health", .{port});

    var collector = Collector.init(allocator);
    defer collector.deinit();

    while (true) {
        const stream = tcp_server.accept(io) catch |err| {
            std.log.err("accept failed: {}", .{err});
            continue;
        };
        handleConnection(allocator, io, stream, &collector) catch |err| {
            std.log.err("connection error: {}", .{err});
        };
    }
}

fn handleConnection(
    allocator: std.mem.Allocator,
    io: std.Io,
    stream: net.Stream,
    collector: *Collector,
) !void {
    defer stream.close(io);

    var recv_buf: [4096]u8 = undefined;
    var send_buf: [4096]u8 = undefined;
    var conn_reader = stream.reader(io, &recv_buf);
    var conn_writer = stream.writer(io, &send_buf);

    var http_server: std.http.Server = .init(&conn_reader.interface, &conn_writer.interface);
    var request = http_server.receiveHead() catch |err| {
        std.log.warn("receiveHead failed: {}", .{err});
        return;
    };

    if (std.mem.eql(u8, request.head.target, "/metrics")) {
        const body = try collector.collect(io);
        defer allocator.free(body);
        try request.respond(body, .{
            .extra_headers = &.{
                .{ .name = "content-type", .value = "text/plain; version=0.0.4; charset=utf-8" },
            },
        });
    } else if (std.mem.startsWith(u8, request.head.target, "/health")) {
        try request.respond("OK\n", .{});
    } else {
        try request.respond("Not Found", .{ .status = .not_found });
    }
}
