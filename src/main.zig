const std = @import("std");
const c = @cImport({
    @cInclude("stdio.h");
});

fn sleepms(ms: u64) void {
    std.Thread.sleep(ms * 1000_000);
}

fn print_status_bar(buffWriter: anytype, allocator: std.mem.Allocator) !void {
    const output = buffWriter.writer();

    try output.writeAll("[");

    const moduleFuncSig = fn (anytype, std.mem.Allocator, anytype) anyerror!void;

    const modules = [_]*const moduleFuncSig{
        @import("./modules/battery.zig").module_battery,
        @import("./modules/cpu.zig").module_cpu,
        @import("./modules/memory.zig").module_memory,
    };

    var addComma: bool = false;
    inline for (modules) |module| {
        if (addComma) {
            try output.writeAll(",\n");
        }
        addComma = true;
        module(output, allocator, .{}) catch {
            addComma = false;
        };
    }

    // external command
    //     const argv = .{ "cat", "/sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq" };
    //     const result = try std.process.Child.run(.{ .allocator = allocator, .argv = &argv });
    //     std.debug.print("stdout: {s}", .{result.stdout});

    try output.writeAll("],\n");
    try buffWriter.flush();
}

pub fn main() !void {
    const stdout = std.io.getStdOut();

    var bw = std.io.bufferedWriter(stdout.writer());

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const writer = bw.writer();

    try writer.writeAll("{ \"version\": 1 }\n");
    try writer.writeAll("[\n");
    try bw.flush();

    //     for (0..10) |_| {
    //         try print_status_bar(&bw, allocator);
    //         sleepms(500);
    //     }

    while (true) {
        try print_status_bar(&bw, allocator);
        sleepms(1000);
    }
}
