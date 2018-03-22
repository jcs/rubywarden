#
# Copyright (c) 2017-2018 joshua stein <jcs@jcs.org>
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

class DBModel
  class << self
    attr_reader :table_name, :columns

    def method_missing(method, *args, &block)
      if m = method.to_s.match(/^find_by_(.+)/)
        return find_by_column(m[1].split("_and_"), args)
      elsif m = method.to_s.match(/^find_all_by_(.+)/)
        return find_all_by_column(m[1].split("_and_"), args)
      else
        super
      end
    end

    def all
      fetch_columns

      Db.execute("SELECT * FROM `#{table_name}` ORDER BY `#{primary_key}`").
      map do |rec|
        build_obj_from_rec(rec)
      end
    end

    # transform ruby data into sql
    def cast_data_for_column(data, col)
      if !@columns.try(:any?)
        raise "need to fetch columns but in a query"
      end

      case @columns[col][:type]
      when /boolean/i
        return data == true ? 1 : 0
      when /datetime/i
        return (data == nil ? nil : data.to_i)
      when /integer/i
        return (data == nil ? nil : data.to_i)
      when /blob/i
        return (data == nil ? nil : data.to_s)
      else
        return data
      end
    end

    def clear_column_cache!
      @columns = {}
    end

    def fetch_columns
      return if @columns.try(:any?)

      @columns = {}

      Db.execute("SELECT sql FROM sqlite_master WHERE tbl_name = ?",
      [ self.table_name ]).first["sql"].
      gsub("\n", " ").
      gsub(/^\s*CREATE\s+TABLE\s+#{self.table_name}\s*\(/i, "").
      split(",").
      each do |f|
        if !(m = f.match(/^\s*([A-Za-z0-9_-]+)\s+([A-Za-z ]+)/))
          raise "can't parse column definition #{f.inspect}"
        end

        @columns[m[1]] = {
          :type => m[2].strip.upcase,
        }
      end

      attr_accessor(*(columns.keys))
    end

    def find_all_by_column(columns, values, limit = nil)
      fetch_columns

      if columns.count != values.count
        raise "arg mismatch: #{columns.inspect} vs #{values.inspect}"
      end

      where = columns.map{|c| "`#{c}` = ?" }.join(" AND ")
      values = values.map{|v| v.is_a?(String) ? v.encode("utf-8") : v }

      Db.execute("SELECT * FROM `#{table_name}` WHERE #{where} #{limit}",
      values).map do |rec|
        build_obj_from_rec(rec)
      end
    end

    def find_by_column(columns, values)
      find_all_by_column(columns, values, "LIMIT 1").first
    end

    def first
      fetch_columns

      rec = Db.execute("SELECT * FROM `#{table_name}` ORDER BY " <<
        "`#{primary_key}` LIMIT 1").first

      rec ? build_obj_from_rec(rec) : nil
    end

    def last
      fetch_columns

      rec = Db.execute("SELECT * FROM `#{table_name}` ORDER BY " <<
        "`#{primary_key}` DESC LIMIT 1").first

      rec ? build_obj_from_rec(rec) : nil
    end

    def primary_key
      @primary_key || "id"
    end

    def primary_key_uuid?
      !!primary_key.match(/uuid$/)
    end

    def set_primary_key(col)
      @primary_key = col
    end

    def set_table_attrs(attrs)
      @table_attrs = attrs
      attr_accessor(*attrs)
    end

    def set_table_name(table)
      @table_name = table
    end

    # transform database data into ruby
    def uncast_data_from_column(data, col)
      if !@columns.try(:any?)
        raise "need to fetch columns but in a query"
      end

      case @columns[col][:type]
      when /boolean/i
        return (data >= 1)
      when /datetime/i
        return (data == nil ? nil : Time.at(data.to_i))
      when /integer/i
        return (data == nil ? nil : data.to_i)
      else
        return data
      end
    end

    def writable_columns_for(what)
      k = columns.keys

      # normally we don't want to include `id` in the insert/update because
      # the db handles that for us, but when we have uuid primary keys, we
      # need to generate them ourselves, so include the column
      unless what == :insert && primary_key_uuid?
        k.reject!{|a| a == primary_key }
      end

      k
    end

  private
    def build_obj_from_rec(rec)
      obj = self.new
      obj.new_record = false

      rec.each do |k,v|
        next if !k.is_a?(String)
        obj.send("#{k}=", uncast_data_from_column(v, k))
      end

      obj
    end
  end

  attr_accessor :new_record

  def self.transaction(&block)
    ret = true

    Db.connection.transaction do
      ret = yield block
    end

    ret
  end

  def initialize
    @new_record = true
  end

  def method_missing(method, *args, &block)
    self.class.fetch_columns
    super
  end

  def actual_before_create
    if self.class.primary_key_uuid? && self.send(self.class.primary_key).blank?
      self.send("#{self.class.primary_key}=", SecureRandom.uuid)
    end

    if self.class.columns["created_at"]
      self.created_at = Time.now
    end

    before_create
  end

  def actual_before_save
    if self.class.columns["updated_at"]
      self.updated_at = Time.now
    end

    before_save
  end

  def before_create
    true
  end

  def before_save
    true
  end

  def destroy
    if !self.new_record && self.send(self.class.primary_key)
      Db.execute("DELETE FROM `#{self.class.table_name}` WHERE " <<
        "`#{self.class.primary_key}` = ?",
        [ self.send(self.class.primary_key) ])
    end
  end

  def save
    self.class.fetch_columns

    return false if !self.actual_before_save

    if self.new_record
      return false if !self.actual_before_create

      Db.execute("INSERT INTO `#{self.class.table_name}` (" <<
        self.class.writable_columns_for(:insert).map{|a| "`#{a.to_s}`" }.
          join(", ") <<
        ") VALUES (" <<
        self.class.writable_columns_for(:insert).map{|a| "?" }.join(", ") <<
        ")",
        self.class.writable_columns_for(:insert).map{|a|
          self.class.cast_data_for_column(self.send(a), a)
        })

      self.new_record = false
    else
      Db.execute("UPDATE `#{self.class.table_name}` SET " +
        self.class.writable_columns_for(:update).map{|a| "`#{a.to_s}` = ?" }.
        join(", ") <<
        " WHERE `#{self.class.primary_key}` = ?",
        self.class.writable_columns_for(:update).map{|a|
          self.class.cast_data_for_column(self.send(a), a)
        } + [ self.send(self.class.primary_key) ])
    end

    true
  end
end
