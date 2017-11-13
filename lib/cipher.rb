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

class Cipher < DBModel
  set_table_name "ciphers"
  set_primary_key "uuid"

  attr_writer :user

  TYPE_LOGIN = 1
  TYPE_NOTE  = 2
  TYPE_CARD  = 3

  def self.type_s(type)
    case type
    when TYPE_LOGIN
      "login"
    when TYPE_NOTE
      "note"
    when TYPE_CARD
      "card"
    else
      type.to_s
    end
  end

  def to_hash
    {
      "Id" => self.uuid,
      "Type" => self.type,
      "RevisionDate" => self.updated_at.strftime("%Y-%m-%dT%H:%M:%S.000000Z"),
      "FolderId" => self.folder_uuid,
      "Favorite" => self.favorite,
      "OrganizationId" => nil,
      "Attachments" => self.attachments,
      "OrganizationUseTotp" => false,
      "Data" => JSON.parse(self.data.to_s),
      "Object" => "cipher",
    }
  end

  def update_from_params(params)
    self.folder_uuid = params[:folderid]
    self.organization_uuid = params[:organizationid]
    self.favorite = params[:favorite]
    self.type = params[:type].to_i

    cdata = {
      "Name" => params[:name]
    }

    case self.type
    when TYPE_LOGIN
      params[:login].each do |k,v|
        cdata[k.to_s.ucfirst] = v
      end

    when TYPE_CARD
      params[:card].each do |k,v|
        cdata[k.to_s.ucfirst] = v
      end
    end

    cdata["Notes"] = params[:notes]

    if params[:fields] && params[:fields].is_a?(Array)
      cdata["Fields"] = params[:fields].map{|f|
        fh = {}
        f.each do |k,v|
          fh[k.ucfirst] = v
        end
        fh
      }
    else
      cdata["Fields"] = nil
    end

    self.data = cdata.to_json
  end

  def user
    @user ||= User.find_by_uuid(self.user_uuid)
  end
end
