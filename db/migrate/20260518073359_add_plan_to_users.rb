class AddPlanToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :plan, :integer
    add_index  :users, :plan
  end
end
