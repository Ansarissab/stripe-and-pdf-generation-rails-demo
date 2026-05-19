# frozen_string_literal: true

ActiveAdmin.register User do
  actions :index, :show

  menu priority: 2

  filter :email
  filter :plan, as: :select, collection: -> { User.plans.keys }
  filter :created_at

  index do
    id_column
    column :email
    column :plan
    column :confirmed_at
    column :current_sign_in_at
    column :sign_in_count
    column :created_at
    actions
  end

  show do
    attributes_table do
      row :id
      row :email
      row :plan
      row :confirmed_at
      row :current_sign_in_at
      row :sign_in_count
      row :created_at
    end

    panel I18n.t("active_admin.users_show.pay_customers") do
      table_for user.pay_customers do
        column :id do |c|
          link_to c.id, admin_pay_customer_path(c)
        end
        column :processor
        column :processor_id
        column :default
        column :created_at
      end
    end

    panel I18n.t("active_admin.users_show.current_subscription") do
      sub = user.payment_processor&.current_subscription
      if sub
        attributes_table_for sub do
          row :id do
            link_to sub.id, admin_pay_subscription_path(sub)
          end
          row :name
          row :processor_plan
          row :status
          row :current_period_start
          row :current_period_end
          row :ends_at
        end
      else
        para I18n.t("active_admin.users_show.no_subscription")
      end
    end

    panel I18n.t("active_admin.users_show.charges") do
      count = Pay::Charge.where(customer_id: user.pay_customers.select(:id)).count
      para I18n.t("active_admin.users_show.charge_count", count: count)
    end
  end
end
