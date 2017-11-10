class DBModel
  class << self
    attr_accessor :table_name, :table_attrs

    def set_table_name(table)
      @table_name = table
    end

    def set_table_attrs(attrs)
      @table_attrs = attrs
      attr_accessor *attrs
    end
  end

  def self.method_missing(method, *args, &block)
    if m = method.to_s.match(/^find_by_(.+)/)
      return self.find_by_column(m[1], args[0])
    elsif m = method.to_s.match(/^find_all_by_(.+)/)
      return self.find_all_by_column(m[1], args[0])
    else
      super
    end
  end

  def self.find_by_column(column, value)
    self.find_all_by_column(column, value, "LIMIT 1").first
  end

  def self.find_all_by_column(column, value, limit = nil)
    Db.connection.execute("SELECT * FROM `#{self.table_name}` WHERE " <<
    "`#{column}` = ? #{limit}", [ value ]).map do |rec|
      obj = self.new

      rec.each do |k,v|
        next if !k.is_a?(String)
        obj.send("#{k}=", v)
      end

      obj
    end
  end

  def self.transaction(&block)
    Db.connection.transaction do
      yield block
    end
  end

  def before_save
    true
  end

  def destroy
    if self.id
      Db.connection.execute("DELETE FROM `#{self.class.table_name}` WHERE " <<
        "id = ?", [ self.id ])
    end
  end

  def save
    return false if !self.before_save

    if self.id
      Db.connection.execute("UPDATE `#{self.class.table_name}` SET " +
        self.class.table_attrs.reject{|a| a == :id }.
          map{|a| "#{a.to_s} = ?" }.join(", ") <<
        " WHERE `id` = ?",
        self.class.table_attrs.reject{|a| a == :id }.
          map{|a| self.send(a) } + [ self.id ])
    else
      Db.connection.execute("INSERT INTO `#{self.class.table_name}` (" <<
        self.class.table_attrs.reject{|a| a == :id }.
          map{|a| a.to_s }.join(", ") <<
        ") VALUES (" <<
        self.class.table_attrs.reject{|a| a == :id }.
          map{|a| "?" }.join(", ") <<
        ")",
        self.class.table_attrs.reject{|a| a == :id }.map{|a| self.send(a) })
    end
  end
end
