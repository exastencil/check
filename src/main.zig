//! A program to check the internet for you

// Dependencies
const std = @import("std");
const curl = @import("curl");
const zqlite = @import("zqlite");

// Commands
const check = @import("check.zig");
const add = @import("add.zig");
const list = @import("list.zig");

// Types
const Provider = @import("provider.zig").Provider;

/// Program entry. Processes args and calls the appropriate function for subcommand
pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Command configuration
    const Command = enum {
        check,
        exec,
        init,
        help,
        version,
        add,
        list,
    };
    var command = Command.check;

    // Options configuration
    const Options = struct {
        verbose: bool = false,
        provider: Provider = .none,
    };
    var options: Options = .{};
    var ident: [:0]u8 = undefined;

    const args = try std.process.argsAlloc(allocator);
    defer allocator.free(args);

    for (args[1..]) |arg| args: {
        // If command hasn't been overridden, check that we aren't trying to do that
        if (command == .check) {
            command = std.meta.stringToEnum(Command, arg) orelse command;
        }

        // Verbose option
        if (std.mem.eql(u8, arg, "-v") or std.mem.eql(u8, arg, "--verbose")) {
            options.verbose = true;
        }

        // Set the provider if it hasn't been set
        if (options.provider == .none) {
            if (std.meta.stringToEnum(Provider, arg)) |provider| {
                options.provider = provider;
                break :args;
            }
        }

        // First value after the provider should be the identifier
        if (command == .add and options.provider != .none) {
            ident = arg;
        }
    }

    const stdout = std.io.getStdOut();

    switch (command) {
        .init => {
            const flags = zqlite.OpenFlags.Create | zqlite.OpenFlags.EXResCode;

            // Get the home directory and construct the database path
            const home_dir = std.posix.getenv("HOME") orelse return error.HomeNotFound;
            const db_path = try std.fmt.allocPrintZ(allocator, "{s}/.check.db", .{home_dir});
            defer allocator.free(db_path);

            var conn = try zqlite.open(db_path, flags);
            defer conn.close();

            // NOTE: Consider adding a settings table once we have some
        },
        .check => {
            check.check();
        },
        .exec => {
            try check.exec(allocator);
        },
        .add => {
            try add.add(allocator, options.provider, ident);
        },
        .list => {
            try list.list(allocator, options.provider);
        },
        .version => {
            try stdout.writeAll("check 0.0.0\n");
        },
        else => {
            try stdout.writeAll(
                \\✔️ check - checks the Internet for you so you can stay productive
                \\
                \\Usage:
                \\
                \\ check            - Shows counts of unread items per extension
                \\ check <provider> - Shows unreads for <provider>
                \\ check exec       - Checks all feeds in all providers for new content
                \\ check add <provider> <ident>
                \\   - Starts the process of adding <provider> with <ident>
                \\     e.g. `check add web https://example.com/feed.xml`
                \\ check list <provider>
                \\   - Lists all items for <provider>
                \\     e.g. `check list web`
                \\
                \\Providers:
                \\
                \\ 🌐 web - URL to Atom feed
                \\          check add web https://xkcd.com/atom.xml
                \\
            );
        },
    }
}
