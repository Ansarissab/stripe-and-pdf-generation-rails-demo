require "test_helper"

class InvoicePdfTest < ActiveSupport::TestCase
  setup do
    @user     = users(:basic_user)
    @customer = setup_billing(@user)
    @charge   = make_charge(@customer, amount: 1234)
  end

  test "renders a valid PDF binary" do
    binary = InvoicePdf.new(@charge).render
    assert binary.start_with?("%PDF"), "expected PDF magic header"
    assert binary.bytesize.positive?
  end

  test "filename includes the charge id and issue date" do
    pdf = InvoicePdf.new(@charge)
    expected_date = @charge.created_at.to_date.strftime("%Y%m%d")
    assert_equal "invoice-#{expected_date}-##{@charge.id}.pdf", pdf.filename
  end
end
