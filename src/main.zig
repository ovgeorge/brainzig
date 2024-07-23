const std = @import("std");
const stdout = std.io.getStdOut().writer();

const TAPE_SIZE = 30000;
const MAX_STEPS = 1000000;

const Interpreter = struct {
    tape: [TAPE_SIZE]u8,
    heads: []usize,
    instruction_head: usize,
    active_head: usize,
    steps: usize,
    num_heads: usize,

    fn init(num_heads: usize, allocator: std.mem.Allocator) !Interpreter {
        const heads = try allocator.alloc(usize, num_heads);
        @memset(heads, 0);
        return Interpreter{
            .tape = std.mem.zeroes([TAPE_SIZE]u8),
            .heads = heads,
            .instruction_head = 0,
            .active_head = 0,
            .steps = 0,
            .num_heads = num_heads,
        };
    }

    fn deinit(self: *Interpreter, allocator: std.mem.Allocator) void {
        allocator.free(self.heads);
    }

    fn interpret(self: *Interpreter, program: []const u8) !void {
        while (self.steps < MAX_STEPS and self.instruction_head < program.len) {
            try self.executeInstruction(program);
            self.steps += 1;
        }

        if (self.steps >= MAX_STEPS) {
            try stdout.print("Program exceeded maximum number of steps.\n", .{});
        } else {
            try stdout.print("Program completed successfully.\n", .{});
        }
    }

    fn executeInstruction(self: *Interpreter, program: []const u8) !void {
        const instruction = program[self.instruction_head];
        try stdout.print("Heads: ", .{});
        for (self.heads, 0..) |head, i| {
            try stdout.print("{c}: {d}, ", .{ self.headIndexToChar(i), head });
        }

        switch (instruction) {
            '>' => {
                self.moveHead(self.active_head, true);
                self.instruction_head += 1;
                try stdout.print("Active head moved right.\n", .{});
            },
            '<' => {
                self.moveHead(self.active_head, false);
                self.instruction_head += 1;
                try stdout.print("Active head moved left.\n", .{});
            },
            '+' => {
                self.tape[self.heads[self.active_head]] +%= 1;
                self.instruction_head += 1;
                try stdout.print("Incremented byte at active head.\n", .{});
            },
            '-' => {
                self.tape[self.heads[self.active_head]] -%= 1;
                self.instruction_head += 1;
                try stdout.print("Decremented byte at active head.\n", .{});
            },
            '.' => {
                const next_head = (self.active_head + 1) % self.num_heads;
                const byte_to_copy = self.tape[self.heads[self.active_head]];
                self.tape[self.heads[next_head]] = byte_to_copy;
                self.instruction_head += 1;
                try stdout.print("Copied byte {d} from active head to next head.\n", .{byte_to_copy});
            },
            ',' => {
                const prev_head = (self.active_head + self.num_heads - 1) % self.num_heads;
                const byte_to_copy = self.tape[self.heads[prev_head]];
                self.tape[self.heads[self.active_head]] = byte_to_copy;
                self.instruction_head += 1;
                try stdout.print("Copied byte {d} from previous head to active head.\n", .{byte_to_copy});
            },
            '&' => {
                const next_head = (self.active_head + 1) % self.num_heads;
                self.tape[self.heads[self.active_head]] +%= self.tape[self.heads[next_head]];
                self.instruction_head += 1;
                try stdout.print("Added byte at next head to byte at active head. Result: {d}\n", .{self.tape[self.heads[self.active_head]]});
            },
            '%' => {
                const next_head = (self.active_head + 1) % self.num_heads;
                self.tape[self.heads[self.active_head]] -%= self.tape[self.heads[next_head]];
                self.instruction_head += 1;
                try stdout.print("Subtracted byte at next head from byte at active head. Result: {d}\n", .{self.tape[self.heads[self.active_head]]});
            },
            ':' => {
                const next_head = (self.active_head + 1) % self.num_heads;
                self.tape[self.heads[next_head]] +%= self.tape[self.heads[self.active_head]];
                self.instruction_head += 1;
                try stdout.print("Added byte at active head to byte at next head. Result: {d}\n", .{self.tape[self.heads[next_head]]});
            },
            ';' => {
                const next_head = (self.active_head + 1) % self.num_heads;
                self.tape[self.heads[next_head]] -%= self.tape[self.heads[self.active_head]];
                self.instruction_head += 1;
                try stdout.print("Subtracted byte at active head from byte at next head. Result: {d}\n", .{self.tape[self.heads[next_head]]});
            },
            '[' => try self.handleOpenBracket(program),
            ']' => try self.handleCloseBracket(program),
            '^' => try self.switchActiveHead(program),
            else => {
                self.instruction_head += 1;
                try stdout.print("Ignored non-command character.\n", .{});
            },
        }

        try stdout.print("Heads: ", .{});
        for (self.heads, 0..) |head, i| {
            try stdout.print("{c}: {d}, ", .{ self.headIndexToChar(i), head });
        }
        try stdout.print("Instruction Head: {d}, Active Head: {c}\n", .{ self.instruction_head, self.headIndexToChar(self.active_head) });
        try self.printTapeNearHeads();
    }

    fn moveHead(self: *Interpreter, head_index: usize, forward: bool) void {
        self.heads[head_index] = if (forward)
            (self.heads[head_index] + 1) % TAPE_SIZE
        else
            (self.heads[head_index] + TAPE_SIZE - 1) % TAPE_SIZE;
    }

    fn switchActiveHead(self: *Interpreter, program: []const u8) !void {
        self.instruction_head += 1;
        if (self.instruction_head >= program.len) {
            return error.UnexpectedEndOfProgram;
        }
        const head_index = try self.charToHeadIndex(program[self.instruction_head]);
        self.active_head = head_index;
        self.instruction_head += 1;
        try stdout.print("Switched active head to head{c}.\n", .{self.headIndexToChar(self.active_head)});
    }

    fn handleOpenBracket(self: *Interpreter, program: []const u8) !void {
        self.instruction_head += 1;
        if (self.instruction_head >= program.len) {
            return error.UnexpectedEndOfProgram;
        }
        const head_index = try self.charToHeadIndex(program[self.instruction_head]);
        
        if (self.tape[self.heads[head_index]] == 0) {
            var depth: usize = 1;
            while (depth > 0) {
                self.instruction_head += 1;
                if (self.instruction_head >= program.len) {
                    return error.UnmatchedBracket;
                }
                if (program[self.instruction_head] == '[') {
                    depth += 1;
                } else if (program[self.instruction_head] == ']') {
                    depth -= 1;
                }
            }
            self.instruction_head += 2;  // Skip the closing bracket and head index
        } else {
            self.instruction_head += 1;
        }
    }

    fn handleCloseBracket(self: *Interpreter, program: []const u8) !void {
        self.instruction_head += 1;
        if (self.instruction_head >= program.len) {
            return error.UnexpectedEndOfProgram;
        }
        const head_index = try self.charToHeadIndex(program[self.instruction_head]);
        
        if (self.tape[self.heads[head_index]] != 0) {
            var depth: usize = 1;
            while (depth > 0) {
                if (self.instruction_head < 2) {
                    return error.UnmatchedBracket;
                }
                self.instruction_head -= 1;
                if (program[self.instruction_head] == ']') {
                    depth += 1;
                } else if (program[self.instruction_head] == '[') {
                    depth -= 1;
                }
            }
            self.instruction_head -= 1;  // Move to the head index before the opening bracket
        } else {
            self.instruction_head += 1;
        }
    }

    fn printTapeNearHeads(self: Interpreter) !void {
        try stdout.print("Tape near heads: ", .{});
        for (self.heads, 0..) |head, i| {
            const start = if (head >= 5) head - 5 else 0;
            const end = @min(head + 6, TAPE_SIZE);
            try stdout.print("{c}: ", .{self.headIndexToChar(i)});
            for (self.tape[start..end], start..) |value, j| {
                if (j == head) {
                    try stdout.print("[{d}] ", .{value});
                } else {
                    try stdout.print("{d} ", .{value});
                }
            }
            try stdout.print("| ", .{});
        }
        try stdout.print("\n", .{});
    }

    fn charToHeadIndex(self: Interpreter, c: u8) !usize {
        _ = self;
        if (c >= '0' and c <= '9') {
            return c - '0';
        } else if (c >= 'A' and c <= 'Z') {
            return c - 'A' + 10;
        } else {
            return error.InvalidHeadIndex;
        }
    }

    fn headIndexToChar(self: Interpreter, index: usize) u8 {
        _ = self;
        if (index < 10) {
            return @as(u8, @intCast(index)) + '0';
        } else {
            return @as(u8, @intCast(index - 10)) + 'A';
        }
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const num_heads = 36;  // 0-9 and A-Z
    var interpreter = try Interpreter.init(num_heads, allocator);
    defer interpreter.deinit(allocator);

    const program = "++++++++[>++++[>++>+++>+++>+<<<<-]>+>+>->>+[<]<-]>>.>---.+++++++..+++.>>.<-.<.+++.------.--------.>>+.>++.";
    try interpreter.interpret(program);
}