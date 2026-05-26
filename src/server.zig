const std = @import("std");
const Collector = @import("metrics/collector.zig").Collector;

pub fn run(allocator: std.mem.Allocator, port: u16) !void {
    const address = try std.net.Address.parseIp("0.0.0.0", port);
    var net_server = try address.listen(.{ .reuse_address = true });
    defer net_server.deinit();

    std.log.info("Listening on 0.0.0.0:{d} — /metrics /health", .{port});

    var collector = Collector.init(allocator);
    defer collector.deinit();

    while (true) {
        const connection = net_server.accept() catch |err| {
            std.log.err("accept failed: {}", .{err});
            continue;
        };
        handleConnection(allocator, connection, &collector) catch |err| {
            std.log.err("connection error: {}", .{err});
        };
    }
}

fn handleConnection(
    allocator: std.mem.Allocator,
    connection: std.net.Server.Connection,
    collector: *Collector,
) !void {
    defer connection.stream.close();

    var req_buf: [4096]u8 = undefined;
    const n = try connection.stream.read(&req_buf);
    if (n == 0) return;

    const request = req_buf[0..n];
    const line_end = std.mem.indexOfScalar(u8, request, '\n') orelse request.len;
    const first_line = request[0..line_end];

    if (std.mem.indexOf(u8, first_line, "GET /metrics") != null) {
        const body = try collector.collect();
        defer allocator.free(body);

        const header = try std.fmt.allocPrint(
            allocator,
            "HTTP/1.1 200 OK\r\n" ++
                "Content-Type: text/plain; version=0.0.4; charset=utf-8\r\n" ++
                "Content-Length: {d}\r\n" ++
                "\r\n",
            .{body.len},
        );
        defer allocator.free(header);

        try connection.stream.writeAll(header);
        try connection.stream.writeAll(body);
    } else if (std.mem.indexOf(u8, first_line, "GET /health") != null) {
        try connection.stream.writeAll(
            "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 3\r\n\r\nOK\n",
        );
    } else {
        try connection.stream.writeAll(
            "HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\n\r\n",
        );
    }
}
