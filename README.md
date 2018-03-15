*(Note: This is still a work in progress.
This project is not associated with the
[Bitwarden](https://bitwarden.com/)
project nor 8bit Solutions LLC.)*

## bitwarden-ruby

A small, self-contained API server written in Ruby and Sinatra to provide a
private backend for the open-source
[Bitwarden apps](https://github.com/bitwarden).

### Data

All data is stored in a local SQLite database.
This means you can easily run the server locally and have your data never
leave your device, or run it on your own web server via Rack and some front-end
HTTP server with TLS to support syncing across multiple devices.
Backing up your data is as easy as copying the `db/production.sqlite3` file
somewhere.

All user data in the SQLite database is stored in an encrypted format the
[same way](https://help.bitwarden.com/crypto.html)
it is in the official Bitwarden backend, where the master password is never
known by the server.
For details on the format, consult the
[documentation](https://github.com/jcs/bitwarden-ruby/blob/master/API.md).

### API Documentation

This project also contains independent
[documentation for Bitwarden's API](https://github.com/jcs/bitwarden-ruby/blob/master/API.md)
written as I work on this server, since there doesn't seem to be any
documentation available other than the
[.NET Bitwarden code](https://github.com/bitwarden/core)
itself.

### Usage

Run `bundle install` at least once.

To run via Rack on port 4567:

	env RACK_ENV=production bundle exec rackup -p 4567 config.ru

You'll probably want to run it once with signups enabled, to allow yourself
to create an account:

	env RACK_ENV=production ALLOW_SIGNUPS=1 bundle exec rackup -p 4567 config.ru

Once the server is running, the Bitwarden apps (such as the Firefox extension)
can be configured to use your own Bitwarden server before login.
For a local Rack instance, you can point it at `http://127.0.0.1:4567/`.

To run the test suite:

	bundle exec rake test

### 1Password Conversion

Export everything from 1Password in its "1Password Interchange Format".
It should create a directory with a `data.1pif` file (which is unencrypted, so
be careful with it).
Once you have created your initial user account through `bitwarden-ruby`, run
the conversion tool with your account e-mail address:

	env RACK_ENV=production bundle exec ruby tools/1password_import.rb -f /path/to/data.1pif -u you@example.com

It will prompt you for the master password you already created, and then
convert and import as many items as it can.

This tool operates on the SQLite database directly (not through its REST API)
so you can run it offline.

### Lastpass Conversion

Export everything from LastPass by going to your vault, "More Options",
"Advanced" and then "Export". It will then export your details in a new browser
window in CSV format, copy and paste this data into a file accessible from your
bitwarden-ruby installation. Unfortunately due to limitations in LastPass
export the "extra fields" and "attachments" data in the LastPass vault will not
be converted.

Once you have created your initial user account through `bitwarden-ruby`, run
the conversion tool with your account e-mail address:

```
env RACK_ENV=production bundle exec ruby tools/lastpass_import.rb -f /path/to/data.csv -u you@example.com
```

It will prompt you for the master password you already created, and then
convert and import as many items as it can.

This tool operates on the SQLite database directly (not through its REST API)
so you can run it offline.

### bitwarden Conversion

Export your bitwarden vault via the web interface or the browser plugin, which
should prompt you to save a `bitwarden_export_<datestamp>.csv` file. Due to
limitations of the exporter, neither cards nor identities will be exported,
and any custom fields will lose their type (text, hidden, or boolean) and be
simply exported as text.

Once you have created your initial user account through `bitwarden-ruby`, run
the conversion tool with your account e-mail address:

```
env RACK_ENV=production bundle exec ruby tools/bitwarden_import.rb -f /path/to/data.csv -u you@example.com
```

It will prompt you for the master password you already created, and then
convert and import as many items as it can.

This tool operates on the SQLite database directly (not through its REST API)
so you can run it offline.

### Keepass Conversion

In order to use the Keepass converter, you will need to install the necessary 
dependency, using `bundle install --with keepass`.

There is no need to export your Keepass-database - you can use it as is.

Once you have created your initial user account through `bitwarden-ruby`, run
the conversion tool with your account e-mail address:

```
env RACK_ENV=production bundle exec ruby tools/keepass_import.rb -f /path/to/data.kdbx -u you@example.com
```

If your Keepass-database is secured using a keyfile, you can pass it using the `-k` parameter:

```
env RACK_ENV=production bundle exec ruby tools/keepass_import.rb -f /path/to/data.kdbx -k /path/to/keyfile.key -u you@example.com
```

It will prompt you for the master password you already created, and then
convert and import as many items as it can.

This tool operates on the SQLite database directly (not through its REST API)
so you can run it offline.


### 2-Factor Authentication

The Bitwarden browser extensions and mobile apps support accounts that require
2FA, by prompting you for the current code after successfully logging in.
To activate Time-based One-Time Passwords (TOTP) on your account after you've
signed up in the previous steps, run the `tools/activate_totp.rb` program on
the server:

	env RACK_ENV=production bundle exec ruby tools/activate_totp.rb -u you@example.com

You'll be shown a `data:` URL that has a PNG-encoded QR code, which you must
copy and paste into a browser, then scan with your mobile TOTP authenticator
apps (assuming it supports scanning from the camera).
Once scanned, the activation program will ask you to enter the current TOTP
being shown in the app for verification, and then save the TOTP secret to your
account in the SQLite database.
Your `security_stamp` will be reset, forcing a new login on any devices that
are logged into your account.
Those devices will now prompt for a TOTP code upon future logins.

### License

Copyright (c) 2017 joshua stein `<jcs@jcs.org>`

Permission to use, copy, modify, and distribute this software for any
purpose with or without fee is hereby granted, provided that the above
copyright notice and this permission notice appear in all copies.

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
