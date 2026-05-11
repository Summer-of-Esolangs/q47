//! Operation types

const std = @import("std");

pub const ProcessError = error{
    InvalidChar,
    TODO,
};

pub const Condition = enum(u8) {
    gt = '>',
    lt = '<',
    eq = '=',
};

pub const Op = union(enum) {
    push: u8,
    add,
    mult,
    neg,
    reciprocal,
    print_num,
    print_char,
    input,
    conditional: struct { cond: Condition, comp: u8, action: std.ArrayList(Op) },
    repeat: struct { times: u8, action: std.ArrayList(Op) },
    jump_statement,
    grouping: std.ArrayList(Op),
    dup_top,
    dup_second_top,
    pop,
    swap,
    exp,
    eof,

    pub fn deinit(self: *Op, alloc: std.mem.Allocator) void {
        switch (self.*) {
            .grouping => |*g| {
                for (g.items) |*s| s.deinit(alloc);
                g.deinit(alloc);
            },
            .conditional => |*c| {
                for (c.action.items) |*s| s.deinit(alloc);
                c.action.deinit(alloc);
            },
            .repeat => |*r| {
                for (r.action.items) |*s| s.deinit(alloc);
                r.action.deinit(alloc);
            },
            else => {},
        }
    }
};

pub fn statement(alloc: std.mem.Allocator, data: []const u8) !struct { Op, []const u8 } {
    if (data.len == 0) return .{ .eof, data };

    switch (data[0]) {
        '0'...'9' => |n| return .{ .{ .push = n - '0' }, data[1..] },
        '+' => return .{ .add, data[1..] },
        '*' => return .{ .mult, data[1..] },
        '`' => return .{ .neg, data[1..] },
        '/' => return .{ .reciprocal, data[1..] },
        'p' => return .{ .print_num, data[1..] },
        '@' => return .{ .print_char, data[1..] },
        'i' => return .{ .input, data[1..] },
        ';' => return .{ .jump_statement, data[1..] },
        '.' => return .{ .dup_top, data[1..] },
        ',' => return .{ .dup_second_top, data[1..] },
        '?' => return .{ .pop, data[1..] },
        ':' => return .{ .swap, data[1..] },
        '^' => return .{ .exp, data[1..] },

        ' ', '\t', '\n' => return statement(alloc, data[1..]),

        '(' => return error.TODO, // TODO: Grouping
        '{' => return error.TODO, // TODO: conditional or repeat
        else => return error.InvalidChar,
    }
}
