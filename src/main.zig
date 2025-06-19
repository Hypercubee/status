const std = @import("std");
const c = @cImport({
    @cInclude("stdio.h");
});

const module_cpu = @import("./modules/cpu.zig").module_cpu;
const module_memory = @import("./modules/memory.zig").module_memory;
const module_battery = @import("./modules/battery.zig").module_battery;

fn sleepms(ms: u64) void {
    std.Thread.sleep(ms * 1000_000);
}

fn print_status_bar(file: std.fs.File, allocator: std.mem.Allocator) !void {
    const output = file.writer();

    try output.writeAll("[\n");
    // pub fn module_cpu(file: std.fs.File, allocator: std.mem.Allocator, options: Options) !void {

    try module_cpu(file, allocator, .{});
    try output.writeAll(",\n");

    //     try module_cpu(file, allocator, .{});
    //     try output.writeAll(",\n");

    try module_memory(file, allocator, .{});
    try output.writeAll(",\n");

    try module_battery(file, allocator, .{});
    //     try output.writeAll(",\n");

    // external command
    //     const argv = .{ "cat", "/sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq" };
    //     const result = try std.process.Child.run(.{ .allocator = allocator, .argv = &argv });
    //     std.debug.print("stdout: {s}", .{result.stdout});

    //     try output.writeAll("{");
    //     try output.writeAll("\"full_text\": \"E: 127.0.0.1 (99999999 Mbit/s)\", ");
    //     try output.writeAll("\"color\": \"#00ff00\"");
    //     try output.writeAll("}\n");

    try output.writeAll("],\n");
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const stdout = std.io.getStdOut();
    const writer = stdout.writer();

    //std.Thread.sleep(1000 * 1000_000);
    try writer.writeAll("{ \"version\": 1 }\n");
    try writer.writeAll("[\n");

    //     for (0..10) |_| {
    //         try print_status_bar(stdout, allocator);
    //         sleepms(1000);
    //     }

    while (true) {
        try print_status_bar(stdout, allocator);
        sleepms(1000);
    }
}
