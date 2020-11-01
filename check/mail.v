module check

import time

// Mailbox is the *subscription* for the _mail_ provider
struct Mailbox {
	address  string
	password string
	imap     string
	checked  time.Time
}

// Mail is the *item* for the _mail_ provider
struct Mail {
	subject   string
	to        []string
	from      string
	text_body string
	html_body string
	sent      time.Time
	read      bool
}
