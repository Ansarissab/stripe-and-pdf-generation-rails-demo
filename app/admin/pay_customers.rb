# frozen_string_literal: true

ActiveAdmin.register Pay::Customer do
  actions :index, :show

  menu priority: 3, label: proc { I18n.t("active_admin.menus.pay_customers") }

  filter :processor, as: :select, collection: -> { Pay::Customer.distinct.pluck(:processor).compact }
  filter :owner_type
  filter :default
  filter :created_at

  index do
    id_column
    column :owner_type
    column :owner_id
    column :processor
    column :processor_id
    column :default
    column :created_at
    actions
  end

  show do
    attributes_table do
      row :id
      row :type
      row :owner_type
      row :owner_id
      row :owner do |c|
        owner = c.owner
        if owner.is_a?(User)
          link_to owner.email, admin_user_path(owner)
        else
          owner.to_s
        end
      end
      row :processor
      row :processor_id
      row :default
      row :created_at
      row :updated_at
    end
  end
end
