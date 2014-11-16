# Post Hacker News Stories & Comments to NNTP Server

## Features

* 0 configuration
* CLI
* Compatible w/ crone jobs
* MIME `multipart/alternative` mails w/ html & txt portions


## Disadvantages

* Read-only
* No up-voting support or score updates


## Requirements

* nodejs 0.10.x
* `rnews` CL util from INN package
* w3m browser


## Installation & Setup

(in Fedora 21)

	# yum install w3m inn

Add this to sudoers (replacing `alex` w/ your user name):

	alex ALL = (news) NOPASSWD: /bin/rnews

Then

	# npm -g install hackernews2uucp


### Check your local inn

	# /usr/libexec/news/ctlinnd newgroup news.ycombinator

must not raise error.

Then

	$ hackernews2uucp-test

will just print a test message (in uncompressed UUCP batch format) to
stdout.

	$ hackernews2uucp-test | sudo rnews -N

will post a test message to `news.ycombinator` group. If the message
doesn't appear, run

	$ journalctl /bin/rnews
	$ journalctl -u innd


## Usage

Wait indefinitely for a data from Hacker News & post it to a local nntp
server:

	$ hackernews2uucp -v | sudo rnews -N

`-v` will print to stderr some info about arriving stories/comments/etc.
Press `<Ctrl-C>` to exit.

Get top 100 stories & all comments for them, then exit:

	$ hackernews2uucp -cv | sudo rnews -N


## FAQ

0. _I have a problem w/ rnews._

	Please, don't ask me any questions about INN. I have a very vague
	idea how it works.

1. _Can hackernews2uucp run as a daemon?_

	No.


## Bugs

* Tested only on Fedora 21.


## See Also

[rnews(1)](http://www.eyrie.org/~eagle/software/inn/docs/rnews.html)


## License

MIT.
