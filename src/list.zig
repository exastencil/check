//! List subcommand functionality

const std = @import("std");
const Provider = @import("provider.zig").Provider;
const web = @import("web.zig");

/// Lists items based on the provider
pub fn list(allocator: std.mem.Allocator, provider: Provider) !void {
    switch (provider) {
        .web => {
            try web.list(allocator);
        },
        .none => {
            std.debug.print("Error: Please specify a provider to list.\n", .{});
            std.debug.print("Usage: check list <provider>\n", .{});
            std.debug.print("Example: check list web\n", .{});
        },
        else => {
            std.debug.print("Error: Provider '{s}' is not yet supported for listing.\n", .{@tagName(provider)});
        },
    }
}
