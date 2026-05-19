class DropActiveAdminComments < ActiveRecord::Migration[8.1]
  def up
    drop_table :active_admin_comments if table_exists?(:active_admin_comments)
  end

  def down
    create_table :active_admin_comments do |t|
      t.string :namespace
      t.text :body
      t.references :resource, polymorphic: true
      t.references :author, polymorphic: true
      t.timestamps
    end
    add_index :active_admin_comments, [ :namespace ]
  end
end
