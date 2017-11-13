*(Note: This is still a work in progress.
This project is not associated with the
[Bitwarden](https://bitwarden.com/)
project nor 8bit Solutions LLC.)*

## bitwarden-ruby

A small, self-contained API server written in Ruby to provide a
private backend for the open-source
[Bitwarden apps](https://github.com/bitwarden).

Data is stored in a local SQLite database.
This means you can easily run it locally and have your data never leave
your device, or run it on your own web server via Rack and some front-end
HTTP server with TLS to support syncing across multiple devices.
Backing up your data is as easy as copying the `db/production.sqlite3` file
somewhere.

All user data in the SQLite database is stored in an encrypted format the same
way it is in the official Bitwarden backend:

- PBKDF2 with 5000 rounds stretches your master password with a salt of your
  e-mail address to become the secret key (unknown to the server).
- This key and a random 16-byte IV are used to encrypt 64 random bytes with
  AES-256-CBC.
  The output+IV become the "known" key attached to your user account, stored
  on the server and sent to the Bitwarden apps upon syncing.
- Private values for each item (called "Cipher" objects) can only be encrypted
  and decrypted on the client side by unencrypting the "known" key with the
  secret key derived from your master password and e-mail address.
  The first 32 bytes of the secret key are used as the encryption key, and the
  last 32 bytes are used as the HMAC key.

All items must be re-encrypted server-side if your master password or e-mail
address change (not yet supported).

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

	env RACK_ENV=production bundle exec rackup config.ru

You'll probably want to run it once with signups enabled, to allow yourself
to create an account:

	env RACK_ENV=production ALLOW_SIGNUPS=1 bundle exec rackup config.ru

Run test suite:

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
