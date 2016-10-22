require 'gosu'
require 'pry'
require 'rmagick'

class Window < Gosu::Window
  def initialize
    @needs_redraw = true
    @target_image = Magick::Image::read('alan4.png').first
    @accum = Magick::Image.new(@target_image.columns, @target_image.rows) { self.background_color = 'none'}
    @output = Gosu::Image.new(@accum)
    @running = false
    @debug = false
    @max_draw = @target_image.columns * 0.2
    @coord_queue = []

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
    when Gosu::KbD then @debug = !@debug
    when Gosu::KbEscape, Gosu::KbQ then close
    end
  end

  def draw
    @output.insert(@accum, 0, 0)
    @output.draw(0, 0, 0)

    if @debug
      @font.draw("Comps per sec: #{@comps_per_sec}", 0, 0, 0, 1, 1, Gosu::Color::RED)
      @font.draw("Max size: #{@max_draw}", 0, 20, 0, 1, 1)
    end

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

    draw = Magick::Draw.new
    draw.translate(x, y)
    draw.rotate(rand(0..360))
    draw_random_bezier(draw, w, h, color)
    draw.draw(img)

    rx = Float(w) / 2.0
    ry = Float(h) / 2.0
    [(x - rx).floor, (y - ry).floor, 2*rx.ceil, 2*ry.ceil]
  end

  def draw_random_elipse(draw, w, h, color)
    draw.fill(color)
    draw.ellipse(0, 0, w, h, 0, 360)
  end

  def draw_random_line(draw, w, h, color)
    thickness = [1.0, (w + h) / 20.0].max
    draw.stroke(color)
    draw.stroke_width(thickness)
    draw.line(-w, -h, w, h)
  end

  def draw_random_bezier(draw, w, h, color)
    thickness = [1.0, (w + h) / 5.0].max
    minx = -w
    maxx = w
    miny = -h
    maxy = h

    draw.stroke(color)
    draw.fill('none')
    draw.stroke_width(thickness)
    draw.bezier(
      -w, -h,
      rand(minx..maxx), rand(miny..maxy),
      rand(minx..maxx), rand(miny..maxy),
      w, h
    )
  end

  def enqueue_coords!
    @max_draw = (@max_draw <= 3 ? 3 : @max_draw * 0.90)

    step = Float(@max_draw) / 2.0

    0.step(by: step, to: width).flat_map do |x|
      0.step(by: step, to: height).map do |y|
        target = @target_image.pixel_color(x, y)
        current = @accum.pixel_color(x, y)
        diff = color_diff(target, current)
        color = target.to_color
        @coord_queue << [x, y, color, diff]
      end
    end

    @coord_queue.sort_by!(&:last)
    @coord_queue.reverse!
    @coord_queue.pop((@coord_queue.size * 0.85).floor)
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
