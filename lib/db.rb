#
# Copyright (c) 2017 joshua stein <jcs@jcs.org>
#
# Permission to use, copy, modify, and distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
#

#
# To make a db change:
#  - modify the schema in #connect for a new install
#  - bump DB_VERSION
#  - add a case in #migrate_from to migrate up to that new version
#

require "sqlite3"

class Db
  class << self
    DB_VERSION = 3

    attr_reader :db, :db_file

    def connect(db_file)
      @db_file = db_file

      @db = SQLite3::Database.new(@db_file)

      @db.execute("
        CREATE TABLE IF NOT EXISTS
        users
        (uuid STRING PRIMARY KEY,
        created_at DATETIME,
        updated_at DATETIME,
        email TEXT UNIQUE,
        email_verified BOOLEAN,
        premium BOOLEAN,
        name TEXT,
        password_hash TEXT,
        password_hint TEXT,
        key TEXT,
        private_key BLOB,
        public_key BLOB,
        totp_secret STRING,
        security_stamp STRING,
        culture STRING)
      ")

      @db.execute("
        CREATE TABLE IF NOT EXISTS
        devices
        (uuid STRING PRIMARY KEY,
        created_at DATETIME,
        updated_at DATETIME,
        user_uuid STRING,
        name STRING,
        type INTEGER,
        push_token STRING UNIQUE,
        access_token STRING UNIQUE,
        refresh_token STRING UNIQUE,
        token_expires_at DATETIME)
      ")

      @db.execute("
        CREATE TABLE IF NOT EXISTS
        ciphers
        (uuid STRING PRIMARY KEY,
        created_at DATETIME,
        updated_at DATETIME,
        user_uuid STRING,
        folder_uuid STRING,
        organization_uuid STRING,
        type INTEGER,
        data BLOB,
        favorite BOOLEAN,
        attachments BLOB,
        name BLOB,
        notes BLOB,
        fields BLOB,
        login BLOB,
        card BLOB,
        identity BLOB,
        securenote BLOB)
      ")

      @db.execute("
        CREATE TABLE IF NOT EXISTS
        folders
        (uuid STRING PRIMARY KEY,
        created_at DATETIME,
        updated_at DATETIME,
        user_uuid STRING,
        name BLOB)
      ")

      @db.results_as_hash = true

      @db.execute("
        CREATE TABLE IF NOT EXISTS
        schema_version
        (version INTEGER)
      ")

      last_version = 0
      while true
        v = @db.execute("SELECT version FROM schema_version").first
        if v
          if v["version"] == last_version
            raise "looping in migrations, #{last_version} didn't increment"
          elsif v["version"] == DB_VERSION
            break
          end
        else
          v = { "version" => 0 }
        end

        last_version = v["version"]
        migrate_from(v["version"])
      end

      # eagerly cache column definitions
      ObjectSpace.each_object(Class).each do |klass|
        if klass < DBModel
          klass.fetch_columns
        end
      end

      @db
    end

    def connection
      @db
    end

    def execute(query, params = [])
      # debug point:
      # STDERR.puts(([ query ] + params).inspect)

      self.connection.execute(query, params)
    end

    def migrate_from(version)
      STDERR.puts "migrating db from version #{version}"

      case version
      when 0
        # we created a new db from scratch, no need to migrate to anything
        @db.execute("INSERT INTO schema_version (version) " <<
          "VALUES ('#{DB_VERSION}')")
        return

      when 1
        @db.execute("
          CREATE TABLE IF NOT EXISTS
          folders
          (uuid STRING PRIMARY KEY,
          created_at DATETIME,
          updated_at DATETIME,
          user_uuid STRING,
          name BLOB)
        ")
      when 2
        @db.execute("
          CREATE TABLE IF NOT EXISTS
          global_equivalent_domains
          (id INTEGER PRIMARY KEY NOT NULL,
          domains BLOB)
        ")

        @db.execute("
          CREATE TABLE IF NOT EXISTS
          excluded_global_equivalent_domains
          (id INTEGER PRIAMRY KEY NOT NULL,
          global_equivalent_domain_id INTEGER NOT NULL,
          user_uuid STRING NOT NULL)
        ")

        @db.execute("
          CREATE TABLE IF NOT EXISTS
          equivalent_domains
          (ID INTEGER PRIMARY KEY NOT NULL,
          domains TEXT NOT NULL,
          user_uuid STRING NOT NULL)
        ")
      when 3
        @db.execute("ALTER TABLE ciphers ADD name BLOB")
        @db.execute("ALTER TABLE ciphers ADD notes BLOB")
        @db.execute("ALTER TABLE ciphers ADD fields BLOB")
        @db.execute("ALTER TABLE ciphers ADD login BLOB")
        @db.execute("ALTER TABLE ciphers ADD card BLOB")
        @db.execute("ALTER TABLE ciphers ADD identity BLOB")
        @db.execute("ALTER TABLE ciphers ADD securenote BLOB")

        # migrate each existing field in the data column to its new dedicated
        # field
        Cipher.clear_column_cache!
        Cipher.all.each do |c|
          c.migrate_data!
        end

        STDERR.puts "migrated all ciphers to new dedicated fields"
      end

      @db.execute("UPDATE schema_version SET version = #{version + 1}")
    end
  end
end
