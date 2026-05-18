class AddPlanToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :plan, :integer, null: false, default: 0
    add_index  :users, :plan
  end
end
