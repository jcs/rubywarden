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

class Sinatra::IndifferentHash
  def ucfirst_hash
    out = {}
    self.each do |k,v|
      out[k.to_s.ucfirst] = v
    end
    out
  end
end

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

  def ucfirst
    if self.length == 0
      ""
    else
      self[0].upcase << self[1 .. -1].to_s
    end
  end
end
