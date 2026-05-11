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

        '(' => {
            var ops: std.ArrayList(Op) = .empty;
            errdefer {
                for (ops.items) |*s| s.deinit(alloc);
                ops.deinit(alloc);
            }
            var rest = data[1..];
            while (true) {
                if (rest.len == 0) return error.InvalidChar;
                if (rest[0] == ')') break;
                const op, const next = try statement(alloc, rest);
                try ops.append(alloc, op);
                rest = next;
            }
            return .{ .{ .grouping = ops }, rest[1..] };
        },

        '{' => {
            if (data.len < 2) return error.InvalidChar;
            var rest = data[1..];

            switch (rest[0]) {
                '0'...'9' => |n| {
                    rest = rest[1..];
                    if (rest.len == 0 or rest[0] != '~') return error.InvalidChar;
                    rest = rest[1..];

                    var ops: std.ArrayList(Op) = .empty;
                    errdefer {
                        for (ops.items) |*s| s.deinit(alloc);
                        ops.deinit(alloc);
                    }
                    while (true) {
                        if (rest.len == 0) return error.InvalidChar;
                        if (rest[0] == '}') break;
                        const op, const next = try statement(alloc, rest);
                        try ops.append(alloc, op);
                        rest = next;
                    }
                    return .{ .{ .repeat = .{ .times = n - '0', .action = ops } }, rest[1..] };
                },
                '>', '<', '=' => |c| {
                    rest = rest[1..];
                    if (rest.len == 0) return error.InvalidChar;
                    const comp = rest[0];
                    rest = rest[1..];
                    if (rest.len == 0 or rest[0] != '|') return error.InvalidChar;
                    rest = rest[1..];

                    var ops: std.ArrayList(Op) = .empty;
                    errdefer {
                        for (ops.items) |*s| s.deinit(alloc);
                        ops.deinit(alloc);
                    }

                    while (true) {
                        if (rest.len == 0) return error.InvalidChar;
                        if (rest[0] == '}') break;
                        const op, const next = try statement(alloc, rest);
                        try ops.append(alloc, op);
                        rest = next;
                    }

                    const cond: Condition = @enumFromInt(c);
                    return .{ .{ .conditional = .{ .cond = cond, .comp = comp - '0', .action = ops } }, rest[1..] };
                },
                else => return error.InvalidChar,
            }
        },

        else => return error.InvalidChar,
    }
}
