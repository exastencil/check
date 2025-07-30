//! The `check remove <provider> <ident>` subcommand

const std = @import("std");
const Provider = @import("provider.zig").Provider;
const web = @import("web.zig");

/// The function that is called when `check remove` is called
pub fn remove(allocator: std.mem.Allocator, provider: Provider, ident: []const u8) !void {
    switch (provider) {
        .web => {
            try web.remove(allocator, ident);
        },
        else => {
            std.debug.print("Remove not implemented for provider {s}\n", .{@tagName(provider)});
        },
    }
}
