//! The `check add <provider> <ident>` subcommand

const std = @import("std");
const Provider = @import("provider.zig").Provider;

/// The function that is called when `check add` is called
pub fn add(provider: Provider, ident: []const u8) void {
    std.debug.print(
        "Add called with provider {} and ident {s}\n",
        .{ provider, ident },
    );
}
