const std = @import("std");
const Io = std.Io;

const preprocess = @import("preprocess.zig");
const Op = preprocess.Op;

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const alloc = init.gpa;

    var args = init.minimal.args.iterate();
    _ = args.next();

    var source: []u8 = undefined;

    if (args.next()) |file_path| {
        source = try std.Io.Dir.cwd().readFileAlloc(
            io,
            file_path,
            alloc,
            .unlimited,
        );
    } else {
        std.debug.print("Missing Q47 file!!!\n", .{});
        std.process.exit(1);
    }

    defer alloc.free(source);

    var top_level: Op = .{ .grouping = .empty };
    defer top_level.deinit(alloc);

    var data: []const u8 = source;

    while (data.len > 0) {
        const op, data = try preprocess.statement(alloc, data);
        try top_level.grouping.append(alloc, op);
    }
}
