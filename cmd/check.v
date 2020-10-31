module main

import os

fn main() {
	command := os.args[0]
	if os.args.len > 1 {
		// Options have been passed
		mode := os.args[1]
		println('You ran `$command $mode`! Check is a WIP!')
		println('TODO: Determine which subcommand to run')
	} else {
		println('You ran $command')
		println('TODO: Check unread counts')
	}
}

// init checks the environment and loads settings
fn init() {
	// Check .checkrc
	println('TODO: Check the .checkrc file or use defaults')
	// Load settings
	println('TODO: Populate settings with defaults if empty')
}

// `check exec` brings all the databases up to date
fn exec() {
	println('check exec')
	// Check providers
	// for each provider
	// ├─	check accounts
	// ├─ for each account
	// │   └─ if account stale
	// │      └─ check account
}

// `check add` adds an account to a provider
fn add(provider string, ident string) {
	println('check add $provider $ident')
	// Determine module to use
	// Initiate the procedure for the provider
}

// `check $provider` shows unprocessed entries for that provider
fn provider(provider string) {
	println('check $provider')
}
