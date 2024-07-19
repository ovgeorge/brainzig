const std = @import("std");

pub const Interpreter = struct {
    code: []u8,
    pc: usize,
    head0: usize,
    head1: usize,
    output: std.ArrayList(u8),

    pub fn init(code: []u8, allocator: std.mem.Allocator) !Interpreter {
        return Interpreter{
            .code = code,
            .pc = 0,
            .head0 = 0,
            .head1 = 0,
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
                    if (self.head0 < self.code.len - 1) self.head0 += 1;
                    try stdout.print("  Moved head0 right to {d}\n", .{self.head0});
                },
                '<' => {
                    if (self.head0 > 0) self.head0 -= 1;
                    try stdout.print("  Moved head0 left to {d}\n", .{self.head0});
                },
                '}' => {
                    if (self.head1 < self.code.len - 1) self.head1 += 1;
                    try stdout.print("  Moved head1 right to {d}\n", .{self.head1});
                },
                '{' => {
                    if (self.head1 > 0) self.head1 -= 1;
                    try stdout.print("  Moved head1 left to {d}\n", .{self.head1});
                },
                '+' => {
                    self.code[self.head0] +%= 1;
                    try stdout.print("  Incremented value at head0 {d} to {d}\n", .{self.head0, self.code[self.head0]});
                },
                '-' => {
                    self.code[self.head0] -%= 1;
                    try stdout.print("  Decremented value at head0 {d} to {d}\n", .{self.head0, self.code[self.head0]});
                },
                '*' => {
                    self.code[self.head1] +%= 1;
                    try stdout.print("  Incremented value at head1 {d} to {d}\n", .{self.head1, self.code[self.head1]});
                },
                '_' => {
                    self.code[self.head1] -%= 1;
                    try stdout.print("  Decremented value at head1 {d} to {d}\n", .{self.head1, self.code[self.head1]});
                },
                '.' => {
                    self.code[self.head1] = self.code[self.head0];
                    try stdout.print("  Copied value from head0 to head1: {d}\n", .{self.code[self.head1]});
                },
                ',' => {
                    self.code[self.head0] = self.code[self.head1];
                    try stdout.print("  Copied value from head1 to head0: {d}\n", .{self.code[self.head0]});
                },
                '&' => {
                    self.code[self.head0] +%= self.code[self.head1];
                    try stdout.print("  Added head1 to head0, result: {d}\n", .{self.code[self.head0]});
                },
                '%' => {
                    self.code[self.head0] -%= self.code[self.head1];
                    try stdout.print("  Subtracted head1 from head0, result: {d}\n", .{self.code[self.head0]});
                },
                ':' => {
                    self.code[self.head1] +%= self.code[self.head0];
                    try stdout.print("  Added head0 to head1, result: {d}\n", .{self.code[self.head1]});
                },
                ';' => {
                    self.code[self.head1] -%= self.code[self.head0];
                    try stdout.print("  Subtracted head0 from head1, result: {d}\n", .{self.code[self.head1]});
                },
                '[' => {
                    if (self.code[self.head0] == 0) {
                        try self.findMatchingBracket('[', ']');
                        try stdout.print("  Jumped forward to matching ']' at position {d}\n", .{self.pc});
                    } else {
                        try stdout.print("  Entered loop\n", .{});
                    }
                },
                ']' => {
                    if (self.code[self.head0] != 0) {
                        try self.findMatchingBracket(']', '[');
                        self.pc -= 1; // Adjust to reprocess the opening bracket
                        try stdout.print("  Jumped back to matching '[' at position {d}\n", .{self.pc});
                    } else {
                        try stdout.print("  Exited loop\n", .{});
                    }
                },
                '(' => {
                    if (self.code[self.head1] == 0) {
                        try self.findMatchingBracket('(', ')');
                        try stdout.print("  Jumped forward to matching ')' at position {d}\n", .{self.pc});
                    } else {
                        try stdout.print("  Entered loop\n", .{});
                    }
                },
                ')' => {
                    if (self.code[self.head1] != 0) {
                        try self.findMatchingBracket(')', '(');
                        self.pc -= 1; // Adjust to reprocess the opening bracket
                        try stdout.print("  Jumped back to matching '(' at position {d}\n", .{self.pc});
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

        try stdout.print("\nFinal program tape state: {s}\n", .{self.code});

    }

    fn findMatchingBracket(self: *Interpreter, opening: u8, closing: u8) !void {
        const direction: isize = if (opening == '[' or opening == '(') 1 else -1;
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
        std.debug.print("Please provide a BrainZig program as an argument.\n", .{});
        std.debug.print("Usage: {s} '<brainflex program>'\n", .{args[0]});
        return;
    }

    const code = try allocator.dupe(u8, args[1]);
    defer allocator.free(code);

    var interpreter = try Interpreter.init(code, allocator);
    defer interpreter.deinit();

    interpreter.run() catch |err| {
        std.debug.print("Error occurred: {}\n", .{err});
        return;
    };
}