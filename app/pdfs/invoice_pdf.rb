class InvoicePdf < Pdf
  def initialize(charge)
    @charge = charge
  end

  def filename
    "invoice-#{charge.created_at.to_date.strftime('%Y%m%d')}-##{charge.id}.pdf"
  end

  protected

  def draw
    heading I18n.t("pdf.invoice.heading")
    meta_lines [
      I18n.t("pdf.invoice.number", id: charge.id),
      I18n.t("pdf.invoice.issued", date: charge.created_at.to_date),
      I18n.t("pdf.invoice.status", status: status_text)
    ]

    two_columns(
      left:  [ I18n.t("pdf.invoice.from"),    Pay.business_name, Pay.support_email ],
      right: [ I18n.t("pdf.invoice.bill_to"), charge.customer.owner.email ]
    )

    table(columns: table_columns, rows: [ [ line_description, formatted_amount ] ], top_y: 640)
    total_row(label: I18n.t("pdf.invoice.total"), value: formatted_amount, y: 565)

    footer_lines [
      I18n.t("pdf.invoice.stripe_charge", id: charge.processor_id),
      I18n.t("pdf.invoice.footer")
    ]
  end

  private

  attr_reader :charge

  def table_columns
    [
      { label: I18n.t("pdf.invoice.description"), x: CONTENT_LEFT },
      { label: I18n.t("pdf.invoice.amount"),      x: 450 }
    ]
  end

  def status_text
    charge.amount_refunded.to_i.positive? ? I18n.t("pdf.invoice.refunded") : I18n.t("pdf.invoice.paid")
  end

  def line_description
    sub = charge.subscription
    return I18n.t("pdf.invoice.charge_fallback") unless sub

    period = [ sub.current_period_start&.to_date, sub.current_period_end&.to_date ].compact.join(" – ")
    label  = sub.processor_plan.presence || I18n.t("pdf.invoice.subscription_fallback")
    period.present? ? "#{label} (#{period})" : label
  end

  def formatted_amount
    money(charge.amount, charge.currency)
  end
end
