## Rubywarden

### Migrating From `bitwarden-ruby` to Rubywarden and ActiveRecord

If you've used this application before it switched to using ActiveRecord
(when it was called `bitwarden-ruby`),
you need to do the following steps to migrate the data and generate the new
table structures.

Even though the migration script will create a backup of your database, it is
probably best to create a backup yourself.
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

The -e switch allows you to select the correct database environment from
`db/config.yml`.
The migration script will:

	- dump the contents of the database to a YAML file
	- rename the original database file to `production.sqlite3.#{Time.now.to_i}`
	- create the database using ActiveRecord migrations
	- load the contents from the dump file
	- remove the dump file

Now your data is completely migrated and the library will now use ActiveRecord
to handle anything database related.

Note: The ActiveRecord migration also defaults to putting the production
database files in `db/production/` instead of just `db/`, which allows for
a separate user to be able to write to the SQLite file without writing to
`db/config.yml` and `db/migrate/` files.
