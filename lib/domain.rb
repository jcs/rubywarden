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

class EquivalentDomainName < DBModel
  set_table_name "equiv_domain_names"
  set_primary_key "uuid"

  attr_writer :equiv_domain

  def equiv_domain
    @equiv_domain ||= EquivalentDomain.find_by_uuid(domain_uuid)
  end
end

class EquivalentDomain < DBModel
  set_table_name "equiv_domains"
  set_primary_key "uuid"

  attr_writer :user

  def to_ary
    EquivalentDomainName.find_all_by_domain_uuid(uuid).map(&:domain)
  end

  def user
    @user ||= User.find_by_uuid(user_uuid)
  end
end

def equivalent_domains(user)
  {
    "EquivalentDomains" => user.domains.map(&:to_ary),
    "GlobalEquivalentDomains" => [],
    "Object" => "domains"
  }
end
