const std = @import("std");
const print = std.debug.print;
const input = @embedFile("input17.txt");

const Registers = struct { a: u64, b: u64, c: u64 };

fn read_input(alloc: std.mem.Allocator, in: []const u8) !std.ArrayListUnmanaged(u8) {
    var num_strs = std.mem.tokenizeAny(u8, in, "RegisterABCProgram:, \n");

    _ = num_strs.next() orelse return error.MissingRegisterA;
    _ = num_strs.next() orelse return error.MissingRegisterB;
    _ = num_strs.next() orelse return error.MissingRegisterC;

    var program = std.ArrayListUnmanaged(u8).empty;
    errdefer program.deinit(alloc);

    while (num_strs.next()) |num_str| {
        const num = try std.fmt.parseInt(u8, num_str, 10);
        try program.append(alloc, num);
    }

    return program;
}

fn combo(v: u8, regs: Registers) !u64 {
    if (v <= 3) return v
    else if (v == 4) return regs.a
    else if (v == 5) return regs.b
    else if (v == 6) return regs.c;
    return error.ComboOperand7;
}

fn simulate(alloc: std.mem.Allocator, program: []const u8, a: u64) !std.ArrayListUnmanaged(u8) {
    var regs: Registers = .{ .a = a, .b = 0, .c = 0 };
    var ip: usize = 0;
    var output = std.ArrayListUnmanaged(u8).empty;
    errdefer output.deinit(alloc);

    while (ip < program.len) {
        switch (program[ip]) {
            0 => { // adv
                const operand = try combo(program[ip + 1], regs);
                const divisor = std.math.pow(u64, 2, operand);
                regs.a = @divFloor(regs.a, divisor);
            },
            1 => { //bxl
                regs.b = regs.b ^ program[ip + 1];
            },
            2 => { // bst
                regs.b = (try combo(program[ip + 1], regs)) % 8;
            },
            3 => { // jnz
                if (regs.a != 0) {
                    ip = program[ip + 1];
                    continue;
                }
            },
            4 => { // bxc
                regs.b = regs.b ^ regs.c;
            },
            5 => { // out
                const value = try combo(program[ip + 1], regs);
                try output.append(alloc, @intCast(value % 8));
            },
            6 => { // bdv
                const operand = try combo(program[ip + 1], regs);
                const divisor = std.math.pow(u64, 2, operand);
                regs.b = @divFloor(regs.a, divisor);
            },
            7 => { // cdv
                const operand = try combo(program[ip + 1], regs);
                const divisor = std.math.pow(u64, 2, operand);
                regs.c = @divFloor(regs.a, divisor);
            },
            else => unreachable,
        }
        ip += 2;
    }

    return output;
}

fn print_u8s(u8s: []u8) void {
    if (u8s.len > 0) print("{d}", .{u8s[0]});
    for (u8s[1..]) |u| print(",{d}", .{u});
    print("\n", .{});
}

fn search(alloc: std.mem.Allocator, program: []const u8, pos: usize, a: u64) !?u64 {
    const aa = a << 3;
    for (0..8) |i| {
        const aaa = aa + i;
        const o = blk: {
            var output = try simulate(alloc, program, aaa);
            defer output.deinit(alloc);
            break :blk output.items[0];
        };
        if (o == program[pos]) {
            if (pos == 0) return aaa;
            if (try search(alloc, program, pos - 1, aaa)) |res| return res;
        }
    }
    return null;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    defer if (gpa.deinit() != .ok) @panic("GPA LEAK");
    const alloc = gpa.allocator();

    var program = try read_input(alloc, input);
    defer program.deinit(alloc);

    var args = std.process.args();
    _ = args.next();
    if (args.next()) |arg| {
        var output = try simulate(alloc, program.items, try std.fmt.parseInt(u64, arg, 10));
        defer output.deinit(alloc);

        print_u8s(output.items);
    } else {
        print_u8s(program.items);
        if (try search(alloc, program.items, program.items.len - 1, 0)) |a| {
            var output = try simulate(alloc, program.items, a);
            defer output.deinit(alloc);

            print_u8s(output.items);
            print("{d}\n", .{a});
        } else {
            print("???\n", .{});
        }
    }
}

test "decls" { std.testing.refAllDecls(@This()); }
