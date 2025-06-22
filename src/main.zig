const std = @import("std");
const c = @cImport({
    @cInclude("stdio.h");
});

fn sleepms(ms: u64) void {
    std.Thread.sleep(ms * 1000_000);
}

const Modules = enum {
    Cpu,
    Memory,
    Battery,
};

fn addModule(module: Modules, writer: anytype, allocator: std.mem.Allocator, options: ?std.StringHashMap([]const u8)) !void {
    switch (module) {
        Modules.Cpu => {
            try @import("./modules/cpu.zig").module_cpu(writer, allocator, options);
        },
        Modules.Memory => {
            try @import("./modules/memory.zig").module_memory(writer, allocator, options);
        },
        Modules.Battery => {
            try @import("./modules/battery.zig").module_battery(writer, allocator, options);
        },
    }
}

fn print_status_bar(buffWriter: anytype, allocator: std.mem.Allocator) !void {
    const output = buffWriter.writer();
    const Options = std.StringHashMap([]const u8);
    try output.writeAll("[");

    var hm = Options.init(allocator);
    defer hm.deinit();
    try hm.put("format", "BAT0 %state : %real_percent$2%");

    const ModulesAndOptions = struct {
        mod: Modules,
        opt: ?Options,
    };

    const used_modules = [_]ModulesAndOptions{
        .{ .mod = Modules.Battery, .opt = hm },
        .{ .mod = Modules.Cpu, .opt = null },
        .{ .mod = Modules.Memory, .opt = null },
    };

    var addComma: bool = false;
    for (used_modules) |module| {
        if (addComma) {
            try output.writeAll(",\n");
        }
        addComma = true;
        addModule(module.mod, output, allocator, module.opt) catch {
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
