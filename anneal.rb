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
    @max_draw = 20
    @colors = []
    @target_image.quantize(20).unique_colors.each_pixel { |p| @colors << p.to_color }
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
      print 'Y'
      @comps += 1
      @accum.destroy!
      @accum = attempt
      @needs_redraw = true
    else
      print '.'
      attempt.destroy!
    end
  end

  def closer(img, x, y, w, h)
    diff = 0
    largest_wrongness = 0
    most_wrong = nil

    (x...(x+w)).each do |px|
      (y...(y+h)).each do |py|
        target_pix = @target_image.pixel_color(px, py)
        current_pix = @accum.pixel_color(px, py)
        attempt_pix = img.pixel_color(px, py)
        #wrongness = 0

        [:red, :green, :blue].each do |channel|
          target = target_pix.send(channel)
          current_diff = (target - current_pix.send(channel)).abs
          attempt_diff = (target - attempt_pix.send(channel)).abs
          diff += (attempt_diff <= current_diff ? 1 : -1)
          #wrongness += current_diff
        end

        #if wrongness > largest_wrongness
          #largest_wrongness = wrongness
          #most_wrong = [px, py]
        #end
      end
    end

    #@most_wrong = most_wrong

    diff >= 0
  end

  def draw_random(img)
    if @most_wrong && rand < 0.5
      x, y = @most_wrong
    else
      x = rand(0...width)
      y = rand(0...height)
    end

    w = rand(1.0...@max_draw) || 1
    h = rand(1.0...@max_draw) || 1

    color = @colors.sample

    circle = Magick::Draw.new
    circle.fill(color)
    circle.ellipse(x, y, w, h, 0, 360)
    circle.draw(img)

    rx = (Float(width) / 2.0).ceil
    ry = (Float(height) / 2.0).ceil
    [x - rx, y - ry, 2*rx, 2*ry]
  end
end

Window.new.show
