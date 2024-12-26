const std = @import("std");
const print = std.debug.print;
const input = @embedFile("input17.txt");

const Registers = struct { a: u32, b: u32, c: u32 };

fn combo(v: u8, regs: Registers) !u32 {
    if (v <= 3) return v
    else if (v == 4) return regs.a
    else if (v == 5) return regs.b
    else if (v == 6) return regs.c;
    return error.ComboOperand7;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    defer if (gpa.deinit() != .ok) @panic("GPA LEAK");
    const alloc = gpa.allocator();

    var num_strs = std.mem.tokenizeAny(u8, input, "RegisterABCProgram:, \n");

    const a_str = num_strs.next() orelse return error.MissingRegisterA;
    const b_str = num_strs.next() orelse return error.MissingRegisterB;
    const c_str = num_strs.next() orelse return error.MissingRegisterC;

    var regs: Registers = .{
        .a = try std.fmt.parseInt(u32, a_str, 10),
        .b = try std.fmt.parseInt(u32, b_str, 10),
        .c = try std.fmt.parseInt(u32, c_str, 10),
    };

    var program = std.ArrayListUnmanaged(u8).empty;
    defer program.deinit(alloc);

    while (num_strs.next()) |num_str| {
        const num = try std.fmt.parseInt(u8, num_str, 10);
        try program.append(alloc, num);
    }

    var output = std.ArrayListUnmanaged(u8).empty;
    defer output.deinit(alloc);

    var ip: usize = 0;
    while (ip < program.items.len) {
        switch (program.items[ip]) {
            0 => { // adv
                const operand = try combo(program.items[ip + 1], regs);
                const divisor = std.math.pow(u32, 2, operand);
                regs.a = @divFloor(regs.a, divisor);
            },
            1 => { //bxl
                regs.b = regs.b ^ program.items[ip + 1];
            },
            2 => { // bst
                regs.b = (try combo(program.items[ip + 1], regs)) % 8;
            },
            3 => { // jnz
                if (regs.a != 0) {
                    ip = program.items[ip + 1];
                    continue;
                }
            },
            4 => { // bxc
                regs.b = regs.b ^ regs.c;
            },
            5 => { // out
                const value = try combo(program.items[ip + 1], regs);
                try output.append(alloc, @intCast(value % 8));
            },
            6 => { // bdv
                const operand = try combo(program.items[ip + 1], regs);
                const divisor = std.math.pow(u32, 2, operand);
                regs.b = @divFloor(regs.a, divisor);
            },
            7 => { // cdv
                const operand = try combo(program.items[ip + 1], regs);
                const divisor = std.math.pow(u32, 2, operand);
                regs.c = @divFloor(regs.a, divisor);
            },
            else => unreachable,
        }
        ip += 2;
    }

    if (output.items.len > 0) {
        print("{d}", .{output.items[0]});
        for (output.items[1..]) |o| print(",{d}", .{o});
        print("\n", .{});
    }

    //print("{s}", .{input});
    //while (num_strs.next()) |ns| print("{s}\n", .{ns});
    //print("{d} {d} {d}\n", .{ regs.a, regs.b, regs.c });
    //print("{d}\n", .{program.items.len});
    //_ = &regs;
}

test "decls" { std.testing.refAllDecls(@This()); }
