require 'gosu'
require 'pry'
require 'rmagick'

class Window < Gosu::Window
  def initialize
    @needs_redraw = true
    @target_image = Magick::Image::read('alan2.jpg').first
    @accum = Magick::Image.new(@target_image.columns, @target_image.rows) { self.background_color = 'none'}
    @output = Gosu::Image.new(@accum)
    @running = false
    @max_draw = @target_image.columns * 0.2
    @colors = []
    @coord_queue = []
    @target_image.quantize(20).unique_colors.each_pixel { |p| @colors << p }
    puts "Using #{@colors.size} colors"

    @last_comp_update = 0
    @comps = 0
    @comps_per_sec = 0
    @font = Gosu::Font.new(18)

    super(@target_image.columns, @target_image.rows, false)
  end

  def update
    close if button_down?(Gosu::KbEscape)
    draw_one if @running

    now = Gosu.milliseconds
    if now - @last_comp_update >= 1000
      @last_comp_update = now
      @comps_per_sec = @comps
      @comps = 0
      @needs_redraw = true
    end
  end

  def button_down(button)
    case button
    when Gosu::KbSpace then @running = !@running
    when Gosu::KbEscape, Gosu::KbQ then close
    end
  end

  def draw
    @output.insert(@accum, 0, 0)
    @output.draw(0, 0, 0)
    @font.draw("Comps per sec: #{@comps_per_sec}", 0, 0, 0, 1, 1, Gosu::Color::RED)
    @font.draw("Max size: #{@max_draw}", 0, 20, 0, 1, 1)
    @needs_redraw = false
  end

  def needs_redraw?
    @needs_redraw
  end

  def draw_one
    attempt = @accum.copy
    rect = draw_random(attempt)
    if closer(attempt, *rect)
      @comps += 1
      @accum.destroy!
      @accum = attempt
      @needs_redraw = true
    else
      attempt.destroy!
    end
  end

  def closer(img, x, y, w, h)
    current_diff = 0.0
    attempt_diff = 0.0
    target_image = @target_image
    accum = @accum

    (x..(x+w)).each do |px|
      (y..(y+h)).each do |py|
        target = target_image.pixel_color(px, py)
        current_diff += color_diff(target, accum.pixel_color(px, py))
        attempt_diff += color_diff(target, img.pixel_color(px, py))
      end
    end

    attempt_diff < current_diff
  end

  def draw_random(img)
    if @coord_queue.empty?
      enqueue_coords!
      puts "Requeued #{@coord_queue.size}"
    end

    x, y, color = @coord_queue.shift
    w = rand(1.0...@max_draw) || 1
    h = rand(1.0...@max_draw) || 1

    circle = Magick::Draw.new
    circle.fill(color)
    circle.ellipse(x, y, w, h, 0, 360)
    circle.draw(img)

    rx = Float(w) / 2.0
    ry = Float(h) / 2.0
    [(x - rx).floor, (y - ry).floor, 2*rx.ceil, 2*ry.ceil]
  end

  def enqueue_coords!
    @max_draw = (@max_draw <= 3 ? 3 : @max_draw * 0.90)

    step = Float(@max_draw) * 0.75

    0.step(by: step, to: width).flat_map do |x|
      0.step(by: step, to: height).map do |y|
        target = @target_image.pixel_color(x, y)
        current = @accum.pixel_color(x, y)
        diff = color_diff(target, current)
        color = closest_color(target)
        @coord_queue << [x, y, color, diff]
      end
    end

    @coord_queue.sort_by!(&:last)
    @coord_queue.reverse!
    @coord_queue.pop((@coord_queue.size * 0.7).floor)
  end

  def closest_color(target)
    @colors
      .min_by{ |c| color_diff(c, target) }
      .to_color
  end

  def color_diff(c1, c2)
    dmax = 65535.0
    dr = (c1.red - c2.red).abs
    dg = (c1.green - c2.green).abs
    db = (c1.blue - c2.blue).abs

    dr/dmax + dg/dmax + db/dmax
  end
end

Window.new.show
