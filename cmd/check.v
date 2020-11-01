module main

import term
import os
import check

const (
	providers = ['web']
)

fn main() {
	settings := init()

	if os.args.len < 2 {
		// No options or params: `check`
		println('Default usage')
	} else if os.args.len < 3 {
		// Subcommand is passed
		match os.args[1] {
			'exec' { exec(settings) }
			'add'  { println('Usage: check add <extension> <identifier>') }
			else   { usage() }
		}
	} else if os.args.len < 4 {
		match os.args[1] {
		'add' {
			provider := os.args[2]
			if provider in providers {
				println('Usage: check add $provider <identifier>')
			} else {
				println('Invalid provider: $provider')
				println('Supported providers: $providers')
			}
		}
		else  { usage() }
		}
	} else if os.args.len < 5 {
		match os.args[1] {
			'add' {
				if os.args.len < 3 { panic('No provider for adding account') }
				if os.args.len < 4 { panic('No identifier for adding account') }
				provider := os.args[2]
				ident := os.args[3]
				add(settings, provider, ident)
			}
			else { usage() }
		}
	} else {
		// Unknown command usage
		println('These aren\'t the droids you\'re looking for')
	}
}

// Usage instructions
fn usage() {
	println('✔️ check - checks the Internet for you so you can stay productive\n')
	println('Usage:\n')
	println(' check             - Shows counts of unread items per extension')
	println(' check <extension> - Shows unreads for <extension>')
	println(' check add <extension> <ident>')
	println('   - Starts the process of adding <extension> with <ident>')
	println('     e.g. `check add mail user@domain.com`')
	println('')
	println('Extensions:\n')
	println(' 🌐 web - URL to Atom feed')
	println('          check add https://xkcd.com/atom.xml')
	println('')
}

// init checks the environment and loads settings
fn init() check.Settings {
	// Check .checkrc
	// TODO: Check the .checkrc file or use defaults
	// Load settings
	return check.Settings{
		store_path: '~/.check/'
	}
}

// `check exec` brings all the databases up to date
fn exec(settings check.Settings) {
	println('check exec')
	println('$settings')
	// Check providers
	// for each provider
	// ├─	check accounts
	// ├─ for each account
	// │   └─ if account stale
	// │      └─ check account
}

// `check add` adds an account to a provider
fn add(s check.Settings, provider string, ident string) {
	match provider {
		'web' { check.add_web(s, ident) }
		else  {
			print(term.red('\nUnsupported provider: '))
			print(term.bold('$provider\n\n'))
			usage()
		}
	}
}

// `check $provider` shows unprocessed entries for that provider
fn provider(provider string) {
	println('check $provider')
}
