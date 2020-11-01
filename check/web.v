module check

import time

// Feed is the *subscription* for the _web_ provider
struct Feed {
	url	    string
	title   string
	checked time.Time
}

// Post is the *item* for the _web_ provider
struct Post {
	title     string
	url       string
	ident     string
	published time.Time
	summary   string
	read      bool
}

// `check web`
pub fn web(settings Settings) {
	path := settings.store_path
	println('Checking items in $path')
}

// `check add web _ident_`
pub fn add_web(settings Settings, ident string) {
	println('check.add_web($ident)')
}
