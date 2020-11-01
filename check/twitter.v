module check

import time

// Twitter is the *subscription* for the _twitter_ provider
struct Twitter {
	handle       string
	password     string
	display_name string
	checked      time.Time
}

// Tweet is the *item* for the _twitter_ provider
struct Tweet {
	handle       string
	display_name string
	content      string
	time         time.Time
	read         bool
}
