const std = @import("std");

const TAPE_SIZE = 512;
const MAX_STEPS = 512;

const Interpreter = struct {
    tape: [TAPE_SIZE]u8,
    head0: usize,
    head1: usize,
    instruction_head: usize,
    data_head: usize,
    steps: usize,
    output: std.ArrayList(u8),

    pub fn init(allocator: std.mem.Allocator) !Interpreter {
        return Interpreter{
            .tape = [_]u8{0} ** TAPE_SIZE,
            .head0 = 0,
            .head1 = 0,
            .instruction_head = 0,
            .data_head = 1,
            .steps = 0,
            .output = try std.ArrayList(u8).initCapacity(allocator, 1000),
        };
    }

    pub fn deinit(self: *Interpreter) void {
        self.output.deinit();
    }

    pub fn loadProgram(self: *Interpreter, program: []const u8) void {
        for (program, 0..) |byte, i| {
            if (i >= TAPE_SIZE) break;
            self.tape[i] = byte;
        }
    }

pub fn run(self: *Interpreter) !void {
    const stdout = std.io.getStdOut().writer();

    while (self.steps < MAX_STEPS) {
        const instruction = self.tape[self.getInstructionHead()];
        if (instruction == 0) break; // End of program

        try stdout.print("Step {d}: Executing '{c}' at position {d}\n", .{
            self.steps + 1, instruction, self.getInstructionHead()
        });

        switch (instruction) {
            '>' => {
                self.moveHead(self.data_head, true);
                try stdout.print("Moved data head right. Instruction head moved right.\n", .{});
            },
            '<' => {
                self.moveHead(self.data_head, false);
                try stdout.print("Moved data head left. Instruction head moved right.\n", .{});
            },
            '+' => {
                self.tape[self.getDataHead()] +%= 1;
                try stdout.print("Incremented value at data head. Instruction head moved right.\n", .{});
            },
            '-' => {
                self.tape[self.getDataHead()] -%= 1;
                try stdout.print("Decremented value at data head. Instruction head moved right.\n", .{});
            },
            '.' => {
                try self.output.append(self.tape[self.getDataHead()]);
                try stdout.print("Output: '{c}'. Instruction head moved right.\n", .{self.tape[self.getDataHead()]});
            },
            ',' => {
                // Input not implemented in this version
                try stdout.print("Input not implemented. Instruction head moved right.\n", .{});
            },
            '[' => try self.handleOpenBracket(),
            ']' => try self.handleCloseBracket(),
            '~' => {
                self.switchHeads();
                try stdout.print("Switched instruction and data heads. Instruction head moved right.\n", .{});
            },
            else => {
                try stdout.print("Ignored non-command character. Instruction head moved right.\n", .{});
            },
        }

        self.moveHead(self.instruction_head, true);
        self.steps += 1;
        try self.printState(stdout);
    }

    if (self.steps >= MAX_STEPS) {
        try stdout.print("\nExecution halted: Maximum steps ({d}) reached.\n", .{MAX_STEPS});
    }

    try self.printFinalState();
}

fn findMatchingBracket(self: *Interpreter, start: u8, end: u8, forward: bool) !usize {
    var depth: isize = 0;
    var current_pos = self.getInstructionHead();

    while (self.steps < MAX_STEPS) {
        if (forward) {
            current_pos = (current_pos + 1) % TAPE_SIZE;
        } else {
            current_pos = (current_pos + TAPE_SIZE - 1) % TAPE_SIZE;
        }

        const current_char = self.tape[current_pos];
        if (current_char == start) {
            depth += if (forward) 1 else -1;
        } else if (current_char == end) {
            depth += if (forward) -1 else 1;
        }

        if (depth == 0) return current_pos;
        self.steps += 1;
    }

    return error.UnmatchedBracket;
}


fn handleOpenBracket(self: *Interpreter) !void {
    const current_value = self.tape[self.getDataHead()];
    if (current_value == 0) {
        // If the current cell is zero, jump past the matching ]
        const matching_close = try self.findMatchingBracket('[', ']', true);
        self.setInstructionHead(matching_close);
    } else {
        // If non-zero, just move to the next instruction
        self.moveHead(self.instruction_head, true);
    }
}

fn handleCloseBracket(self: *Interpreter) !void {
    const current_value = self.tape[self.getDataHead()];
    if (current_value != 0) {
        // If the current cell is non-zero, jump back to the matching [
        const matching_open = try self.findMatchingBracket(']', '[', false);
        self.setInstructionHead(matching_open);
        self.moveHead(self.instruction_head, true); // Move past the [
    } else {
        // If zero, just move to the next instruction
        self.moveHead(self.instruction_head, true);
    }
}

    fn getInstructionHead(self: Interpreter) usize {
        return if (self.instruction_head == 0) self.head0 else self.head1;
    }

    fn getDataHead(self: Interpreter) usize {
        return if (self.data_head == 0) self.head0 else self.head1;
    }

    fn setInstructionHead(self: *Interpreter, pos: usize) void {
        if (self.instruction_head == 0) {
            self.head0 = pos;
        } else {
            self.head1 = pos;
        }
    }

    fn moveHead(self: *Interpreter, head: usize, forward: bool) void {
        if (head == 0) {
            self.head0 = if (forward)
                (self.head0 + 1) % TAPE_SIZE
            else
                (self.head0 + TAPE_SIZE - 1) % TAPE_SIZE;
        } else {
            self.head1 = if (forward)
                (self.head1 + 1) % TAPE_SIZE
            else
                (self.head1 + TAPE_SIZE - 1) % TAPE_SIZE;
        }
    }

    fn switchHeads(self: *Interpreter) void {
        self.instruction_head = 1 - self.instruction_head;
        self.data_head = 1 - self.data_head;
    }

fn printState(self: Interpreter, writer: anytype) !void {
    try writer.print("Head0: {d}, Head1: {d}, Instruction Head: {d}, Data Head: {d}\n", .{
        self.head0, self.head1, self.getInstructionHead(), self.getDataHead()
    });

    const min_head = @min(self.head0, self.head1);
    const max_head = @max(self.head0, self.head1);
    const start = if (min_head >= 5) min_head - 5 else 0;
    const end = @min(TAPE_SIZE - 1, max_head + 5);

    try writer.print("Tape near heads (offset {d}): ", .{start});
    var i: usize = start;
    while (i <= end) : (i += 1) {
        if (i == self.head0) {
            try writer.print("[{d}]", .{self.tape[i]});
        } else if (i == self.head1) {
            try writer.print("({d})", .{self.tape[i]});
        } else {
            try writer.print(" {d} ", .{self.tape[i]});
        }
    }
    try writer.print("\n\n", .{});
}

    fn printFinalState(self: Interpreter) !void {
        const stdout = std.io.getStdOut().writer();
        try stdout.print("\nExecution completed in {d} steps.\n", .{self.steps});
        try stdout.print("Final output: ", .{});
        for (self.output.items) |byte| {
            try stdout.print("{c}", .{byte});
        }
        try stdout.print("\n", .{});
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var interpreter = try Interpreter.init(allocator);
    defer interpreter.deinit();

    const stdin = std.io.getStdIn().reader();
    var program = std.ArrayList(u8).init(allocator);
    defer program.deinit();

    // Read the program from stdin
    while (true) {
        const byte = stdin.readByte() catch |err| switch (err) {
            error.EndOfStream => break,
            else => return err,
        };
        try program.append(byte);
    }

    interpreter.loadProgram(program.items);
    try interpreter.run();
}