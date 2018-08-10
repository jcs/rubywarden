## Rubywarden

### Migrating From `bitwarden-ruby` to Rubywarden and ActiveRecord

If you've used this application before it switched to using ActiveRecord
(when it was called `bitwarden-ruby`),
you need to do the following steps to migrate the data and generate the new
table structures.

Even though the migration script will import to a new database file at a
different path, it is probably best to create a backup yourself.
You can also copy the `db/production.sqlite3` to your local machine and do the
migration there.
After a successful migration you'd have to copy the updated database file back
to the production machine.

First make sure you have the latest code:

	git pull

Afterwards you need to run bundle to add some required libraries for the migration

	bundle --with migrate

Now you are ready to do the migration:

	bundle exec ruby tools/migrate_to_ar.rb -e production

The `-e` switch allows you to select the correct database environment from
`db/config.yml`.

The migration script will:

	- dump the contents of the old database (most likely at
      `db/production.sqlite`) to a temporary YAML file
	- create the new database at `db/production/production.sqlite3` using
      ActiveRecord migrations
	- import the contents from the dump file
	- remove the dump file

Now your data is completely migrated into a new database at the new recommended
path, and the library will now use ActiveRecord to handle anything database
related.

It is recommended to follow the
[initial installation instructions](https://github.com/jcs/rubywarden#usage)
to create a new, unprivileged user to own the new `db/production/` database
and run the server.
