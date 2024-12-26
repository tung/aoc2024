const std = @import("std");
const stdout = std.io.getStdOut().writer();
const Allocator = std.mem.Allocator;
const BitSet = std.DynamicBitSetUnmanaged;
const List = std.ArrayListUnmanaged;
const Map = std.AutoHashMapUnmanaged;
const StringMap = std.StringHashMapUnmanaged;

const Op = enum {
    AND,
    OR,
    XOR,

    const Self = @This();

    fn from_slice(s: []const u8) !Self {
        if (std.mem.eql(u8, s, "AND")) return Self.AND
        else if (std.mem.eql(u8, s, "OR")) return Self.OR
        else if (std.mem.eql(u8, s, "XOR")) return Self.XOR
        else return error.BadOp;
    }
};

const Rule = struct {
    op: Op,
    in: [2]usize,
    out: usize,
};

const Globals = struct {
    alloc: Allocator,
    names: StringMap(usize),
    rules: List(Rule),
    wires: BitSet,

    const Self = @This();

    fn init(alloc: Allocator, input: []const u8) !Self {
        var lines = std.mem.splitScalar(u8, input, '\n');

        // Map names to wires indices.
        var next_index: usize = 0;
        var names = StringMap(usize).empty;
        errdefer names.deinit(alloc);

        var init_set = StringMap(void).empty;
        defer init_set.deinit(alloc);

        // Read initially-set values for x and y wires.
        while (lines.next()) |line| {
            if (line.len == 0) break;
            if (!names.contains(line[0..3])) {
                try names.put(alloc, line[0..3], next_index);
                next_index += 1;
            }
            if (line[5] == '1') try init_set.put(alloc, line[0..3], {});
        }

        var unordered_rules = List(Rule).empty;
        defer unordered_rules.deinit(alloc);

        // Parse rule lines in input text order.
        while (lines.next()) |line| {
            if (line.len == 0) continue;
            var tokens = std.mem.tokenizeScalar(u8, line, ' ');
            const first_name = tokens.next() orelse return error.MissingFirst;
            const op_str = tokens.next() orelse return error.MissingOperator;
            const second_name = tokens.next() orelse return error.MissingSecond;
            const arrow = tokens.next() orelse return error.MissingArrow;
            const out_name = tokens.next() orelse return error.MissingOut;

            if (!std.mem.eql(u8, arrow, "->")) return error.BadArrow;

            const first = blk: {
                if (names.get(first_name)) |i| {
                    break :blk i;
                } else {
                    try names.put(alloc, first_name, next_index);
                    next_index += 1;
                    break :blk next_index - 1;
                }
            };
            const second = blk: {
                if (names.get(second_name)) |i| {
                    break :blk i;
                } else {
                    try names.put(alloc, second_name, next_index);
                    next_index += 1;
                    break :blk next_index - 1;
                }
            };
            const out = blk: {
                if (names.get(out_name)) |i| {
                    break :blk i;
                } else {
                    try names.put(alloc, out_name, next_index);
                    next_index += 1;
                    break :blk next_index - 1;
                }
            };

            try unordered_rules.append(alloc, .{
                .op = try Op.from_slice(op_str),
                .in = .{ first, second },
                .out = out,
            });
        }

        // Track wires that are 'ready' for rules to read them.
        var ready = Map(usize, void).empty;
        defer ready.deinit(alloc);

        var names_iter = names.iterator();
        while (names_iter.next()) |name| {
            if (name.key_ptr.*[0] == 'x' or name.key_ptr.*[0] == 'y') {
                try ready.put(alloc, name.value_ptr.*, {});
            }
        }

        var rules = List(Rule).empty;
        errdefer rules.deinit(alloc);

        // Add rules ordered so that both inputs are ready from previous rules.
        var ur_index: usize = 0;
        var ur_removed = false;
        while (unordered_rules.items.len > 0) {
            const rule = unordered_rules.items[ur_index];
            if (ready.contains(rule.in[0]) and ready.contains(rule.in[1])) {
                const rule2 = unordered_rules.swapRemove(ur_index);
                try rules.append(alloc, rule2);
                try ready.put(alloc, rule2.out, {});
                ur_removed = true;
            } else {
                ur_index += 1;
                if (ur_index >= unordered_rules.items.len and !ur_removed) {
                    return error.UnresolvedRules;
                }
            }
            if (ur_index >= unordered_rules.items.len) {
                ur_index = 0;
                ur_removed = false;
            }
        }

        var wires = try BitSet.initEmpty(alloc, names.count());
        errdefer wires.deinit(alloc);

        // Fill in initially-set wire bits.
        var init_set_key_iter = init_set.keyIterator();
        while (init_set_key_iter.next()) |isk| {
            wires.set(names.get(isk.*) orelse return error.MissingInitSetName);
        }

        return .{
            .alloc = alloc,
            .names = names,
            .rules = rules,
            .wires = wires,
        };
    }

    fn deinit(self: *Self) void {
        self.names.deinit(self.alloc);
        self.rules.deinit(self.alloc);
        self.wires.deinit(self.alloc);
    }
};

fn run_rules(g: *Globals) void {
    for (g.rules.items) |rule| {
        const in0 = g.wires.isSet(rule.in[0]);
        const in1 = g.wires.isSet(rule.in[1]);
        switch (rule.op) {
            .AND => if (in0 and in1) g.wires.set(rule.out) else g.wires.unset(rule.out),
            .OR => if (in0 or in1) g.wires.set(rule.out) else g.wires.unset(rule.out),
            .XOR => if (in0 != in1) g.wires.set(rule.out) else g.wires.unset(rule.out),
        }
    }
}

fn read_z_bits(g: Globals) !u64 {
    var result: u64 = 0;
    var it = g.names.iterator();
    while (it.next()) |n| {
        if (n.key_ptr.*[0] != 'z') continue;
        if (!g.wires.isSet(n.value_ptr.*)) continue;
        const offset: u6 = try std.fmt.parseInt(u6, n.key_ptr.*[1..], 10);
        result |= @as(u64, 1) << offset;
    }
    return result;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    defer if (gpa.deinit() != .ok) @panic("GPA LEAK");
    const alloc = gpa.allocator();

    var g = try Globals.init(alloc, @embedFile("input24.txt"));
    defer g.deinit();

    run_rules(&g);

    try stdout.print("{d}\n", .{try read_z_bits(g)});
}

test "decls" {
    std.testing.refAllDecls(@This());
}

test "example1" {
    const alloc = std.testing.allocator;
    const input =
        \\x00: 1
        \\x01: 1
        \\x02: 1
        \\y00: 0
        \\y01: 1
        \\y02: 0
        \\
        \\x00 AND y00 -> z00
        \\x01 XOR y01 -> z01
        \\x02 OR y02 -> z02
        \\
        ;
    var g = try Globals.init(alloc, input);
    defer g.deinit();
    run_rules(&g);
    try std.testing.expectEqual(4, read_z_bits(g));
}

test "example2" {
    const alloc = std.testing.allocator;
    const input =
        \\x00: 1
        \\x01: 0
        \\x02: 1
        \\x03: 1
        \\x04: 0
        \\y00: 1
        \\y01: 1
        \\y02: 1
        \\y03: 1
        \\y04: 1
        \\
        \\ntg XOR fgs -> mjb
        \\y02 OR x01 -> tnw
        \\kwq OR kpj -> z05
        \\x00 OR x03 -> fst
        \\tgd XOR rvg -> z01
        \\vdt OR tnw -> bfw
        \\bfw AND frj -> z10
        \\ffh OR nrd -> bqk
        \\y00 AND y03 -> djm
        \\y03 OR y00 -> psh
        \\bqk OR frj -> z08
        \\tnw OR fst -> frj
        \\gnj AND tgd -> z11
        \\bfw XOR mjb -> z00
        \\x03 OR x00 -> vdt
        \\gnj AND wpb -> z02
        \\x04 AND y00 -> kjc
        \\djm OR pbm -> qhw
        \\nrd AND vdt -> hwm
        \\kjc AND fst -> rvg
        \\y04 OR y02 -> fgs
        \\y01 AND x02 -> pbm
        \\ntg OR kjc -> kwq
        \\psh XOR fgs -> tgd
        \\qhw XOR tgd -> z09
        \\pbm OR djm -> kpj
        \\x03 XOR y03 -> ffh
        \\x00 XOR y04 -> ntg
        \\bfw OR bqk -> z06
        \\nrd XOR fgs -> wpb
        \\frj XOR qhw -> z04
        \\bqk OR frj -> z07
        \\y03 OR x01 -> nrd
        \\hwm AND bqk -> z03
        \\tgd XOR rvg -> z12
        \\tnw OR pbm -> gnj
        \\
        ;
    var g = try Globals.init(alloc, input);
    defer g.deinit();
    run_rules(&g);
    try std.testing.expectEqual(2024, read_z_bits(g));
}
