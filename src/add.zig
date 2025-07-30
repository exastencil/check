//! The `check add <provider> <ident>` subcommand

const std = @import("std");
const Provider = @import("provider.zig").Provider;
const web = @import("web.zig");

/// The function that is called when `check add` is called
pub fn add(allocator: std.mem.Allocator, provider: Provider, ident: []const u8) !void {
    switch (provider) {
        .web => {
            try web.add(allocator, ident);
        },
        else => {
            std.debug.print("Provider not implemented yet\\n", .{});
        },
    }
}
