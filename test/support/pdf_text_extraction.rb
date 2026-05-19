require "hexapdf"
require "stringio"

# Parses a rendered PDF byte string and returns the concatenated text of every
# show-text operation across all pages. Used by the Pdf and InvoicePdf tests
# to assert that specific strings and formats were drawn.
module PdfTextExtraction
  def extract_pdf_text(bytes)
    doc   = HexaPDF::Document.new(io: StringIO.new(bytes))
    texts = []
    processor = Class.new(HexaPDF::Content::Processor) do
      def initialize(out)
        super()
        @out = out
      end

      def show_text(string)
        @out << decode_text(string)
      end

      def show_text_with_positioning(array)
        array.each { |element| @out << decode_text(element) if element.is_a?(String) }
      end
    end.new(texts)
    doc.pages.each { |page| page.process_contents(processor) }
    texts.join(" | ")
  end
end

ActiveSupport::TestCase.include(PdfTextExtraction)
