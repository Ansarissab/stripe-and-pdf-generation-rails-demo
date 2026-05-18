class Account::InvoicesController < ApplicationController
  before_action :set_charge, only: :show

  def index
    @charges = current_user_charges.order(created_at: :desc)
    authorize Pay::Charge, policy_class: Pay::ChargePolicy
  end

  def show
    authorize @charge, policy_class: Pay::ChargePolicy
    pdf = InvoicePdf.new(@charge)
    send_data pdf.render,
              filename: pdf.filename,
              type: "application/pdf",
              disposition: "attachment"
  end

  private

  def current_user_charges
    Pay::Charge.joins(:customer)
               .where(pay_customers: { owner_id: current_user.id, owner_type: "User" })
  end

  def set_charge
    @charge = current_user_charges.find_by(id: params[:id])
    redirect_to(account_invoices_path, alert: "Invoice not found.") unless @charge
  end
end
