class DropAttachmentsUrl < ActiveRecord::Migration[5.1]
  def change
    remove_column "attachments", "url"
  end
end
