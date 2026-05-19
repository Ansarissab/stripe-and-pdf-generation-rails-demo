# frozen_string_literal: true

ActiveAdmin.register Pay::Charge do
  actions :index, :show

  menu priority: 5, label: proc { I18n.t("active_admin.menus.pay_charges") }

  filter :currency
  filter :created_at

  index do
    id_column
    column :customer_id
    column :subscription_id
    column(I18n.t("active_admin.columns.amount")) { |ch| number_to_currency(ch.amount.to_i / 100.0, unit: ch.currency.to_s.upcase + " ") }
    column :currency
    column(I18n.t("active_admin.columns.refunded")) { |ch| number_to_currency(ch.amount_refunded.to_i / 100.0, unit: ch.currency.to_s.upcase + " ") }
    column :processor_id
    column :created_at
    actions
  end

  show do
    attributes_table do
      row :id
      row :type
      row :customer do |ch|
        link_to ch.customer_id, admin_pay_customer_path(ch.customer_id)
      end
      row :subscription do |ch|
        link_to ch.subscription_id, admin_pay_subscription_path(ch.subscription_id) if ch.subscription_id
      end
      row(I18n.t("active_admin.columns.amount")) { |ch| number_to_currency(ch.amount.to_i / 100.0, unit: ch.currency.to_s.upcase + " ") }
      row :currency
      row(I18n.t("active_admin.columns.refunded")) { |ch| number_to_currency(ch.amount_refunded.to_i / 100.0, unit: ch.currency.to_s.upcase + " ") }
      row :processor_id
      row :created_at
    end
  end
end
