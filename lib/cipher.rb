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

class Cipher < DBModel
  set_table_name "ciphers"
  set_primary_key "uuid"

  attr_writer :user

  TYPE_LOGIN    = 1
  TYPE_NOTE     = 2
  TYPE_CARD     = 3
  TYPE_IDENTITY = 4

  def self.type_s(type)
    case type
    when TYPE_LOGIN
      "login"
    when TYPE_NOTE
      "note"
    when TYPE_CARD
      "card"
    when TYPE_IDENTITY
      "identity"
    else
      type.to_s
    end
  end

  # shortcut to turn any field containing json data into an object
  def method_missing(method, *args, &block)
    if m = method.to_s.match(/^(.+)_unjson$/)
      j = self.send(m[1])
      j ? JSON.parse(j) : nil
    else
      super
    end
  end

  # migrate from older style everything-in-data to separate fields
  def migrate_data!
    return if !self.data

    js = JSON.parse(self.data)
    return if !js

    self.name = js.delete("Name")
    self.notes = js.delete("Notes")
    self.fields = js.delete("Fields").try(:to_json)

    if self.type == TYPE_LOGIN
      js["Uris"] = [
        { "Uri" => js["Uri"], "Match" => nil },
      ]
      js.delete("Uri")
    end

    # move the remaining fields into the new dedicated field based on the type
    fmap = {
      TYPE_LOGIN => "login",
      TYPE_NOTE => "securenote",
      TYPE_CARD => "card",
      TYPE_IDENTITY => "identity",
    }
    self.send("#{fmap[self.type]}=", js.to_json)

    self.save || raise("failed migrating #{self.inspect}")
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
      "Object" => "cipher",
      "Name" => self.name,
      "Notes" => self.notes,
      "Fields" => self.fields_unjson,
      "Login" => self.login_unjson,
      "Card" => self.card_unjson,
      "Identity" => self.identity_unjson,
      "SecureNote" => self.securenote_unjson,
    }
  end

  def update_from_params(params)
    self.folder_uuid = params[:folderid]
    self.organization_uuid = params[:organizationid]
    self.favorite = params[:favorite]
    self.type = params[:type].to_i

    self.name = params[:name]
    self.notes = params[:notes]

    self.fields = nil
    if params[:fields] && params[:fields].is_a?(Array)
      self.fields = params[:fields].map{|h| h.ucfirst_hash }.to_json
    end

    case self.type
    when TYPE_LOGIN
      tlogin = params[:login].ucfirst_hash

      if tlogin["Uris"] && tlogin["Uris"].is_a?(Array)
        tlogin["Uris"].map!{|h| h.ucfirst_hash }
      end

      self.login = tlogin.to_json

    when TYPE_NOTE
      self.securenote = params[:securenote].ucfirst_hash.to_json

    when TYPE_CARD
      self.card = params[:card].ucfirst_hash.to_json

    when TYPE_IDENTITY
      self.identity = params[:identity].ucfirst_hash.to_json
    end
  end

  def user
    @user ||= User.find_by_uuid(self.user_uuid)
  end
end
