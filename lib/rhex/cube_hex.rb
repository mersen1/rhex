# frozen_string_literal: true

module Rhex
  class CubeHex
    RadiusCannotBeZero = Class.new(StandardError)

    # Вынес lerp в helper класса, так быстрее и чище
    def self.lerp(start, stop, t)
      (stop * t) + (start * (1.0 - t))
    end

    attr_reader :q, :r, :s, :data, :packed_key, :image_config

    def initialize(q, r, s, data: nil, image_config: nil)
      @q = q
      @r = r
      @s = s
      @data = data
      # Intermediate hexes (lerp results, medians) may carry Floats — those have no packed key.
      @packed_key = CoordinatePacker.pack(q, r) if q.is_a?(Integer) && r.is_a?(Integer)

      self.image_config = image_config
    end

    def image_config=(value)
      return @image_config = nil unless value

      validation = Rhex::Contracts::ImageConfigContract.new.call(value)
      validation.failure? && raise(ArgumentError, "Invalid image_config: #{validation.errors.to_h}")

      @image_config = validation.to_h
    end

    def hash
      [q, r, s].hash
    end

    def ==(other)
      q == other.q && r == other.r && s == other.s
    end
    alias_method :eql?, :==

    def !=(other)
      !self.==(other)
    end

    # --- Арифметика (вместо add/subtract/scale) ---

    # Арифметика сохраняет полезную нагрузку левого операнда: производные гексы
    # (соседи, кольца, линии) остаются с теми же data/image_config, что и исходный.
    def +(other)
      derive(q + other.q, r + other.r, s + other.s)
    end

    def -(other)
      derive(q - other.q, r - other.r, s - other.s)
    end

    def *(other)
      derive(q * other, r * other, s * other)
    end

    # --- Геометрия ---

    def distance(hex)
      ((q - hex.q).abs + (r - hex.r).abs + (s - hex.s).abs) / 2
    end

    def neighbor(direction_index)
      coords = Rhex::Constants::DIRECTION_VECTORS[direction_index] || raise(Rhex::DirectionIndexOutOfRange)

      self + Rhex::CubeHex.new(*coords)
    end

    def neighbors
      Rhex::Constants::DIRECTION_VECTORS.map.with_index { |_, direction_index| neighbor(direction_index) }
    end

    # --- Алгоритмы ---

    def linedraw(target)
      dist = distance(target)
      return [self] if dist.zero?

      # Сразу создаем смещение как объект один раз
      offset = Rhex::CubeHex.new(*Rhex::Constants::LINE_OF_SIGHT_NUDGE)

      # Добавляем смещение к старту и концу для корректного Lerp
      source_nudged = self + offset
      target_nudged = target + offset

      (0..dist).map do |i|
        step = 1.0 / dist * i
        source_nudged.lerp(target_nudged, step).round
      end
    end

    def ring(radius = 1)
      return [self] if radius.zero?

      start_vector = Rhex::CubeHex.new(*Rhex::Constants::INITIAL_RING_VECTOR)
      current_hex = self + (start_vector * radius)

      results = []
      Rhex::Constants::DIRECTION_VECTORS.each do |coords|
        vector = Rhex::CubeHex.new(*coords)
        radius.times do
          results << current_hex
          current_hex += vector
        end
      end
      results
    end

    def spiral_ring(radius = 1)
      raise(RadiusCannotBeZero) unless radius.positive?

      # Используем flat_map для сбора единого массива
      (0..radius).flat_map { |r| ring(r) }
    end

    # --- Отражения ---

    def reflection_q(ref = Rhex::CubeHex.new(0, 0, 0)) = with_reflection(ref) { [_1.q, _1.s, _1.r] }
    def reflection_r(ref = Rhex::CubeHex.new(0, 0, 0)) = with_reflection(ref) { [_1.s, _1.r, _1.q] }
    def reflection_s(ref = Rhex::CubeHex.new(0, 0, 0)) = with_reflection(ref) { [_1.r, _1.q, _1.s] }

    def to_axial
      Rhex::AxialHex.new(q, r, data: data, image_config: image_config)
    end

    # --- Protected / Private Helpers ---

    def round
      rq = q.round
      rr = r.round
      rs = s.round

      q_diff = (rq - q).abs
      r_diff = (rr - r).abs
      s_diff = (rs - s).abs

      if q_diff > r_diff && q_diff > s_diff
        rq = -rr - rs
      elsif r_diff > s_diff
        rr = -rq - rs
      else
        rs = -rq - rr
      end

      derive(rq, rr, rs)
    end

    def lerp(target, step)
      derive(
        self.class.lerp(q, target.q, step),
        self.class.lerp(r, target.r, step),
        self.class.lerp(s, target.s, step)
      )
    end

    protected

    def with_reflection(reference_point)
      subtracted = self - reference_point
      new_q, new_r, new_s = yield(subtracted)
      derive(new_q, new_r, new_s) + reference_point
    end

    private

    def derive(new_q, new_r, new_s)
      Rhex::CubeHex.new(new_q, new_r, new_s, data: data, image_config: image_config)
    end
  end
end
