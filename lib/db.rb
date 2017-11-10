require "sqlite3"

class Db
  @@db = nil

  def self.db_file
    "#{APP_ROOT}/db.sqlite3"
  end

  def self.connection
    if @@db
      return @@db
    end

    @@db = SQLite3::Database.new(self.db_file)

    @@db.execute("
      CREATE TABLE IF NOT EXISTS
      users
      (id INTEGER PRIMARY KEY ASC,
      email TEXT UNIQUE,
      name TEXT,
      password_hash TEXT,
      key TEXT,
      totp_secret STRING,
      security_stamp STRING,
      culture STRING)
    ")

    @@db.execute("
      CREATE TABLE IF NOT EXISTS
      devices
      (id INTEGER PRIMARY KEY ASC,
      device_uuid STRING UNIQUE,
      user_id INTEGER,
      name STRING,
      device_type INTEGER,
      device_push_token STRING,
      access_token STRING UNIQUE,
      refresh_token STRING UNIQUE,
      token_expiry INTEGER)
    ")

    @@db.execute("
      CREATE TABLE IF NOT EXISTS
      ciphers
      (id INTEGER PRIMARY KEY ASC,
      cipher_uuid STRING UNIQUE,
      updated_at INTEGER,
      user_id INTEGER,
      data STRING,
      cipher_type INTEGER,
      cipher_attachments STRING)
    ")

    @@db.results_as_hash = true

    @@db
  end
end
