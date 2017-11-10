class NilClass
  def blank?
    true
  end

  def present?
    false
  end
end

class String
  def blank?
    self.strip == ""
  end

  def present?
    !blank?
  end

  def timingsafe_equal_to(other)
    if self.bytesize != other.bytesize
      return false
    end

    bytes = self.unpack("C#{self.bytesize}")

    res = 0
    other.each_byte do |byte|
      res |= byte ^ bytes.shift
    end

    res == 0
  end
end

def need_params(*ps)
  ps.each do |p|
    if params[p].blank?
      yield(p)
    end
  end
end

def tee(d)
  STDERR.puts d
  d
end

def validation_error(msg)
  [ 400, {
    "ValidationErrors" => { "" => [
      msg,
    ]},
    "Object" => "error",
  }.to_json ]
end
