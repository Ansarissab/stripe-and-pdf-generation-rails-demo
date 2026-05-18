require "hexapdf"
require "stringio"

# Base class for every HexaPDF document the app emits.
#
# Layering:
#   * Per-subject classes (e.g. InvoicePdf) subclass Pdf and implement #draw.
#   * #draw stays declarative -- it calls *layout primitives* defined here
#     rather than touching the HexaPDF Canvas directly.
#   * Low-level primitives (text, rule, money) wrap Canvas.
#   * High-level primitives (heading, meta_lines, two_columns, table_row,
#     total_row, footer_lines) compose the low-level ones into the patterns
#     every business document needs.
#
# Adding a new PDF type: subclass, implement #draw, override #filename.
class Pdf
  PAGE_MARGIN   = 50
  CONTENT_LEFT  = 50
  CONTENT_RIGHT = 545
  RIGHT_GUTTER  = 400
  LINE_COLOR    = "E5E7EB"

  def render
    io = StringIO.new
    document.write(io)
    io.string
  end

  def filename
    "#{self.class.name.underscore.sub(/_pdf\z/, '')}.pdf"
  end

  protected

  attr_reader :canvas

  def document
    HexaPDF::Document.new.tap do |doc|
      @canvas = doc.pages.add.canvas
      draw
    end
  end

  def draw
    raise NotImplementedError, "#{self.class} must implement #draw"
  end

  # ---- low-level primitives ------------------------------------------------

  def text(content, at:, size: 12, font: "Helvetica")
    canvas.font(font, size: size).text(content.to_s, at: at)
  end

  def rule(y, from: CONTENT_LEFT, to: CONTENT_RIGHT, color: LINE_COLOR, width: 0.5)
    canvas.stroke_color(color).line_width(width).line(from, y, to, y).stroke
  end

  def money(amount_cents, currency)
    "$#{format('%.2f', amount_cents.to_i / 100.0)} #{currency.to_s.upcase}"
  end

  # ---- high-level primitives (business-document patterns) ------------------

  # Big title at the top-left of the page.
  def heading(title, y: 780, size: 28)
    text(title, at: [ CONTENT_LEFT, y ], size: size)
  end

  # Stacks small lines top-down at a given x. Used for invoice number / date /
  # status blocks that sit in the top-right gutter.
  def meta_lines(lines, x: RIGHT_GUTTER, top_y: 790, size: 10, line_height: 15)
    lines.each_with_index do |line, i|
      text(line, at: [ x, top_y - (i * line_height) ], size: size)
    end
  end

  # Two stacked address-style columns (From / Bill to).
  def two_columns(left:, right:, top_y: 720, left_x: CONTENT_LEFT, right_x: 350, size: 11, line_height: 15)
    [ [ left, left_x ], [ right, right_x ] ].each do |(lines, x)|
      lines.each_with_index do |line, i|
        text(line, at: [ x, top_y - (i * line_height) ], size: size)
      end
    end
  end

  # A header-then-rows table with a single column rule above and below.
  # `columns` is a list of {label:, x:} hashes; `rows` is a list of arrays.
  def table(columns:, rows:, top_y:, header_size: 12, row_size: 12, row_height: 25)
    columns.each { |col| text(col[:label], at: [ col[:x], top_y ], size: header_size) }
    rule(top_y - 6)

    rows.each_with_index do |row, i|
      y = top_y - row_height * (i + 1)
      columns.each_with_index { |col, ci| text(row[ci], at: [ col[:x], y ], size: row_size) }
    end

    rule(top_y - row_height * (rows.size + 1) + 17)
  end

  # Bold-style total line under a table.
  def total_row(label:, value:, y:, label_x: CONTENT_LEFT, value_x: 450, size: 14)
    text(label, at: [ label_x, y ], size: size)
    text(value, at: [ value_x, y ], size: size)
  end

  # Multi-line small footer.
  def footer_lines(lines, top_y: 80, size: 8, line_height: 15)
    lines.each_with_index do |line, i|
      text(line, at: [ CONTENT_LEFT, top_y - (i * line_height) ], size: size)
    end
  end
end
