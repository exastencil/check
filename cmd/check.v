module main

import cli { Command }
import os
import check

fn main() {
	// Base `greet` command
	mut cmd := Command{
		name: 'check'
		description: 'Checks the internet so you can stay focused'
		version: '0.0.0'
		execute: exec
	}
	// Base `web` command
	mut web_cmd := Command{
		name: 'web'
		description: 'Follow websites or blogs with RSS or Atom feeds'
		execute: web
	}
	cmd.add_command(web_cmd)
	cmd.parse(os.args)
}

// init checks the environment and loads settings
fn init() check.Settings {
	// Check .checkrc
	println('TODO: Check the .checkrc file or use defaults')
	// Load settings
	return check.Settings{
		store_path: '~/.check/'
	}
}

// `check exec` brings all the databases up to date
fn exec(cmd Command) {
	println('check exec')
	settings := init()
	println('$settings')
	// Check providers
	// for each provider
	// ├─	check accounts
	// ├─ for each account
	// │   └─ if account stale
	// │      └─ check account
}

// `check web`
fn web(cmd Command) {
	settings := init()
	check.web(settings)
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
