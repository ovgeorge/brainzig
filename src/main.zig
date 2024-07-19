const std = @import("std");

const MEMORY_SIZE: usize = 30000;

pub const Interpreter = struct {
    code: []const u8,
    pc: usize,
    pointer: usize,
    memory: [MEMORY_SIZE]u8,
    output: std.ArrayList(u8),

    pub fn init(code: []const u8, allocator: std.mem.Allocator) !Interpreter {
        return Interpreter{
            .code = code,
            .pc = 0,
            .pointer = 0,
            .memory = [_]u8{0} ** MEMORY_SIZE,
            .output = std.ArrayList(u8).init(allocator),
        };
    }

    pub fn deinit(self: *Interpreter) void {
        self.output.deinit();
    }

    pub fn run(self: *Interpreter) !void {
        const stdout = std.io.getStdOut().writer();
        
        while (self.pc < self.code.len) {
            const command = self.code[self.pc];
            try stdout.print("Executing command: '{c}' at position {d}\n", .{command, self.pc});
            
            switch (command) {
                '>' => {
                    if (self.pointer < MEMORY_SIZE - 1) self.pointer += 1;
                    try stdout.print("  Moved pointer right to {d}\n", .{self.pointer});
                },
                '<' => {
                    if (self.pointer > 0) self.pointer -= 1;
                    try stdout.print("  Moved pointer left to {d}\n", .{self.pointer});
                },
                '+' => {
                    self.memory[self.pointer] +%= 1;
                    try stdout.print("  Incremented value at pointer {d} to {d}\n", .{self.pointer, self.memory[self.pointer]});
                },
                '-' => {
                    self.memory[self.pointer] -%= 1;
                    try stdout.print("  Decremented value at pointer {d} to {d}\n", .{self.pointer, self.memory[self.pointer]});
                },
                '.' => {
                    try self.output.append(self.memory[self.pointer]);
                    try stdout.print("  Output: '{c}' (ASCII: {d})\n", .{self.memory[self.pointer], self.memory[self.pointer]});
                },
                ',' => {
                    try stdout.print("  Input command not implemented\n", .{});
                },
                '[' => {
                    if (self.memory[self.pointer] == 0) {
                        try self.findMatchingBracket('[');
                        try stdout.print("  Jumped forward to matching ']' at position {d}\n", .{self.pc});
                    } else {
                        try stdout.print("  Entered loop\n", .{});
                    }
                },
                ']' => {
                    if (self.memory[self.pointer] != 0) {
                        try self.findMatchingBracket(']');
                        self.pc -= 1; // Adjust to reprocess the opening bracket
                        try stdout.print("  Jumped back to matching '[' at position {d}\n", .{self.pc});
                    } else {
                        try stdout.print("  Exited loop\n", .{});
                    }
                },
                else => {
                    try stdout.print("  Ignored non-command character\n", .{});
                },
            }
            self.pc += 1;
        }

        try stdout.print("\nFinal output: ", .{});
        for (self.output.items) |char| {
            try stdout.print("{c}", .{char});
        }
        try stdout.print("\n", .{});
    }

    pub fn findMatchingBracket(self: *Interpreter, bracket: u8) !void {
        const direction: isize = if (bracket == '[') 1 else -1;
        const opening = '[';
        const closing = ']';
        var depth: isize = 0;

        while (true) {
            if (direction > 0) {
                self.pc += 1;
                if (self.pc >= self.code.len) {
                    return error.UnmatchedBracket;
                }
            } else {
                if (self.pc == 0) {
                    return error.UnmatchedBracket;
                }
                self.pc -= 1;
            }

            if (self.code[self.pc] == opening) {
                depth += 1;
            } else if (self.code[self.pc] == closing) {
                depth -= 1;
            }

            if (depth == 0) {
                break;
            }
        }

        if (direction < 0) {
            self.pc -= 1; // Adjust for the increment in the main loop
        }
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        std.debug.print("Please provide a Brainfuck program as an argument.\n", .{});
        std.debug.print("Usage: {s} '<brainfuck program>'\n", .{args[0]});
        return;
    }

    var interpreter = try Interpreter.init(args[1], allocator);
    defer interpreter.deinit();

    try interpreter.run();
}