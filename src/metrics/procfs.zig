const std = @import("std");

/// Reads the entire contents of a file into an allocated buffer.
///
/// procfs files (e.g. /proc/stat, /proc/meminfo) must be read with sequential
/// `read()` syscalls: they report a stat size of 0 and do not support
/// positional (`preadv`) reads, which return EOF immediately. A default
/// `File.reader` reads positionally and therefore yields no data. Using a
/// streaming reader forces sequential reads, so the file is read correctly.
///
/// Caller owns the returned slice and must free it.
pub fn readFile(allocator: std.mem.Allocator, io: std.Io, path: []const u8) ![]u8 {
    const file = try std.Io.Dir.openFileAbsolute(io, path, .{});
    defer file.close(io);

    var file_buf: [64 * 1024]u8 = undefined;
    var file_reader = file.readerStreaming(io, &file_buf);

    var out: std.Io.Writer.Allocating = .init(allocator);
    defer out.deinit();

    _ = try file_reader.interface.streamRemaining(&out.writer);
    return out.toOwnedSlice();
}
