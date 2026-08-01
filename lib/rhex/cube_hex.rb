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
      @packed_key = CoordinatePacker.pack_unchecked(q, r) if q.is_a?(Integer) && r.is_a?(Integer)

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
      dq, dr, ds = Rhex::Constants::DIRECTION_VECTORS[direction_index] || raise(Rhex::DirectionIndexOutOfRange)

      derive(q + dq, r + dr, s + ds)
    end

    def neighbors
      Rhex::Constants::DIRECTION_VECTORS.map { |dq, dr, ds| derive(q + dq, r + dr, s + ds) }
    end

    # --- Алгоритмы ---

    def linedraw(target)
      dist = distance(target)
      return [self] if dist.zero?

      nudge_q, nudge_r, nudge_s = Rhex::Constants::LINE_OF_SIGHT_NUDGE

      # Смещение старта и конца, чтобы Lerp не попадал ровно на границу двух гексов.
      # Считаем по координатам, без промежуточных гексов: на каждый шаг раньше
      # создавалось два объекта (результат lerp и результат round) вместо одного.
      source_q = q + nudge_q
      source_r = r + nudge_r
      source_s = s + nudge_s
      target_q = target.q + nudge_q
      target_r = target.r + nudge_r
      target_s = target.s + nudge_s

      inverse_dist = 1.0 / dist

      (0..dist).map do |i|
        step = inverse_dist * i

        round_to_hex(
          self.class.lerp(source_q, target_q, step),
          self.class.lerp(source_r, target_r, step),
          self.class.lerp(source_s, target_s, step)
        )
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
      round_to_hex(q, r, s)
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

    # Кубическое округление: наибольшую ошибку восстанавливаем из двух других координат,
    # чтобы сумма осталась нулевой.
    def round_to_hex(float_q, float_r, float_s)
      rq = float_q.round
      rr = float_r.round
      rs = float_s.round

      q_diff = (rq - float_q).abs
      r_diff = (rr - float_r).abs
      s_diff = (rs - float_s).abs

      if q_diff > r_diff && q_diff > s_diff
        rq = -rr - rs
      elsif r_diff > s_diff
        rr = -rq - rs
      else
        rs = -rq - rr
      end

      derive(rq, rr, rs)
    end
  end
end
