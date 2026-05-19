# frozen_string_literal: true

class AddTrackableAndLockableToAdminUsers < ActiveRecord::Migration[8.1]
  def change
    change_table :admin_users do |t|
      ## Trackable
      t.integer  :sign_in_count, default: 0, null: false
      t.datetime :current_sign_in_at
      t.datetime :last_sign_in_at
      t.string   :current_sign_in_ip
      t.string   :last_sign_in_ip

      ## Lockable (using :failed_attempts strategy + email unlock)
      t.integer  :failed_attempts, default: 0, null: false
      t.string   :unlock_token
      t.datetime :locked_at
    end

    add_index :admin_users, :unlock_token, unique: true
  end
end
