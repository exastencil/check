# Check Command Line Utility
_Internet checker so you can focus when you need to!_

`check` runs in the background, accessing online services and caching their
content snugly hidden in your home folder somewhere. When you are in-between
things you can check in on the rest of the world. Simple as that.

## Things to `check`

- Mail <planned>
- Twitter <planned>
- Reddit <planned>
- Slack <planned>
- Web (RSS / atom feeds) <planned>
- Discord <planned>
- Calendar <planned>

## How it works

Check creates a folder in `$HOME/.check` with all its data. It stores its
settings in `$HOME/.checkrc`. Each provider can have multiple accounts. Data
from each provider goes in its own SQLite database e.g. `~/.check/mail.sqlite`
so you can reset or syncrhonise individual providers.

## Getting Started

### 1. Install `check`

**You can't do this yet, because `check` isn't ready!**

### 2. Add a provider / account

This depends on the provider but would be something like: 
`check add twitter exastencil`.

This will start a process for authenticating against that provider if needed.
Repeat this for all the providers and acocunts you want.

### 3. Configure background `check`s

The default `check` command returns the status of unread items already stored.
It does not update the databases. For this there is `check exec`. You will
need to intermittently run `check exec` in the background to sync accounts.
You can safely run it frequently, since it checks provider settings for an
interval at which each account should be checked. 

A crontab such as the following usually does the trick:

```
* * * * * check exec
```

### 4. Review your settings

Edit `$HOME/.checkrc` to change the default intervals if you want.

### 5. Check the internet

Whenever you have a free moment: `check` to see what happened. If Twitter is
a-buzz, go ahead and `check twitter`. Is your boss sending you urgent email?
`check mail`.
