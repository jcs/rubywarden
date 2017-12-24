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

require "sqlite3"

class Db
  class << self
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
        attachments BLOB)
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

      loop do
        v = @db.execute("SELECT version FROM schema_version").first
        if !v
          v = { "version" => 0 }
        end

        case v["version"]
        when 0
          @db.execute("INSERT INTO schema_version (version) VALUES (1)")

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

          @db.execute("UPDATE schema_version SET version = 2")

        when 2
          @db.execute("
            CREATE TABLE IF NOT EXISTS
            equiv_domains
            (uuid STRING PRIMARY KEY,
            user_uuid STRING)
          ")

          @db.execute("
            CREATE TABLE IF NOT EXISTS
            equiv_domain_names
            (uuid STRING PRIMARY KEY,
            domain STRING,
            domain_uuid STRING)
          ")

          @db.execute("UPDATE schema_version SET version = 3")

        when 3
          break
        end
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
  end
end
