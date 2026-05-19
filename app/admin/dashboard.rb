# frozen_string_literal: true

ActiveAdmin.register_page "Dashboard" do
  menu priority: 1, label: proc { I18n.t("active_admin.dashboard") }

  content title: proc { I18n.t("active_admin.dashboard") } do
    columns do
      column do
        panel I18n.t("active_admin.dashboard_panels.users.title") do
          para I18n.t("active_admin.dashboard_panels.users.total", count: User.count)
          para link_to(I18n.t("active_admin.dashboard_panels.users.link"), admin_users_path)
        end
      end

      column do
        panel I18n.t("active_admin.dashboard_panels.active_subscriptions.title") do
          active = Pay::Subscription.where(status: %w[active trialing]).count
          para I18n.t("active_admin.dashboard_panels.active_subscriptions.total", count: active)
          para link_to(I18n.t("active_admin.dashboard_panels.active_subscriptions.link"), admin_pay_subscriptions_path)
        end
      end

      column do
        panel I18n.t("active_admin.dashboard_panels.charges_this_month.title") do
          scope = Pay::Charge.where(created_at: Time.current.all_month)
          total_cents = scope.sum(:amount)
          para I18n.t("active_admin.dashboard_panels.charges_this_month.total", count: scope.count)
          para number_to_currency(total_cents / 100.0)
          para link_to(I18n.t("active_admin.dashboard_panels.charges_this_month.link"), admin_pay_charges_path)
        end
      end
    end
  end
end
