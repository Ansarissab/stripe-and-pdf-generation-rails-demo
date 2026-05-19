# frozen_string_literal: true

ActiveAdmin.register Pay::Subscription do
  actions :index, :show

  menu priority: 4, label: proc { I18n.t("active_admin.menus.pay_subscriptions") }

  filter :status
  filter :processor_plan
  filter :created_at

  index do
    id_column
    column :customer_id
    column :name
    column :processor_plan
    column :status
    column :current_period_start
    column :current_period_end
    column :ends_at
    column :created_at
    actions
  end

  show do
    attributes_table do
      row :id
      row :type
      row :customer do |s|
        link_to s.customer_id, admin_pay_customer_path(s.customer_id)
      end
      row :name
      row :processor_id
      row :processor_plan
      row :status
      row :quantity
      row :current_period_start
      row :current_period_end
      row :trial_ends_at
      row :ends_at
      row :created_at
    end
  end
end
