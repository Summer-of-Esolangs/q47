//! Interpreter!

const std = @import("std");
const preprocess = @import("preprocess.zig");
const Op = preprocess.Op;
const Condition = preprocess.Condition;

pub const RuntimeError = error{
    StackUnderflow,
    InvalidInput,
    OutOfMemory,
};

const Signal = enum { none, jump };

stack: std.ArrayList(f32),

const Interpreter = @This();

pub fn init() Interpreter {
    return .{
        .stack = .empty,
    };
}

pub fn deinit(self: *Interpreter, alloc: std.mem.Allocator) void {
    self.stack.deinit(alloc);
}

fn push(self: *Interpreter, alloc: std.mem.Allocator, val: f32) RuntimeError!void {
    try self.stack.append(alloc, val);
}

fn pop(self: *Interpreter) RuntimeError!f32 {
    if (self.stack.items.len == 0) return error.StackUnderflow;
    return self.stack.pop().?;
}

fn peek(self: *Interpreter) RuntimeError!f32 {
    if (self.stack.items.len == 0) return error.StackUnderflow;
    return self.stack.items[self.stack.items.len - 1];
}

fn peekSecond(self: *Interpreter) RuntimeError!f32 {
    if (self.stack.items.len < 2) return error.StackUnderflow;
    return self.stack.items[self.stack.items.len - 2];
}

pub fn runSlice(self: *Interpreter, alloc: std.mem.Allocator, io: std.Io, slice: []const Op) RuntimeError!Signal {
    for (slice) |*op| {
        const sig = try self.runOp(alloc, io, op);
        if (sig == .jump) return .jump;
    }
    return .none;
}

pub fn runOp(self: *Interpreter, alloc: std.mem.Allocator, io: std.Io, op: *const Op) RuntimeError!Signal {
    switch (op.*) {
        .push => |n| try self.push(alloc, @floatFromInt(n)),

        .add => {
            const b = try self.pop();
            const a = try self.pop();
            try self.push(alloc, a + b);
        },
        .mult => {
            const b = try self.pop();
            const a = try self.pop();
            try self.push(alloc, a * b);
        },
        .neg => {
            const a = try self.pop();
            try self.push(alloc, -a);
        },
        .reciprocal => {
            const a = try self.pop();
            try self.push(alloc, 1.0 / a);
        },
        .exp => {
            const b = try self.pop();
            const a = try self.pop();
            try self.push(alloc, std.math.pow(f32, a, b));
        },

        .print_num => {
            const a = try self.peek();

            if (a == @floor(a)) {
                std.debug.print("{d}", .{@as(i64, @intFromFloat(a))});
            } else {
                std.debug.print("{d}", .{a});
            }
        },
        .print_char => {
            const a = try self.peek();
            std.debug.print("{c}", .{@as(u8, @intFromFloat(a))});
        },

        .input => {
            const stdin = std.Io.File.stdin();

            var buffer: [1]u8 = undefined;
            var reader = stdin.reader(io, &buffer);

            const byte = reader.interface.takeByte() catch @panic("Read error :O\n");
            const int = byte - '0';
            const float: f32 = @floatFromInt(int);
            try self.stack.append(alloc, float);
        },

        .dup_top => {
            const a = try self.peek();
            try self.push(alloc, a);
        },
        .dup_second_top => {
            const a = try self.peekSecond();
            try self.push(alloc, a);
        },
        .pop => _ = try self.pop(),
        .swap => {
            const b = try self.pop();
            const a = try self.pop();
            try self.push(alloc, b);
            try self.push(alloc, a);
        },

        .jump_statement => return .jump,

        .grouping => |*g| {
            while (true) {
                const sig = try self.runSlice(alloc, io, g.items);
                if (sig == .none) break;
            }
        },

        .conditional => |*c| {
            const top = try self.peek();
            const comp: f32 = @floatFromInt(c.comp);
            const taken = switch (c.cond) {
                .eq => top == comp,
                .lt => top < comp,
                .gt => top > comp,
            };
            if (taken) {
                const sig = try self.runSlice(alloc, io, c.action.items);
                if (sig == .jump) return .jump;
            }
        },

        .repeat => |*r| {
            var i: u8 = 0;
            while (i < r.times) : (i += 1) {
                const sig = try self.runSlice(alloc, io, r.action.items);
                if (sig == .jump) return .jump;
            }
        },

        .eof => {},
    }
    return .none;
}
