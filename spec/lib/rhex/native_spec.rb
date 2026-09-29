# frozen_string_literal: true

require "spec_helper"
require "open3"
require "timeout"

RSpec.describe("Native line of sight") do
  before do
    skip "Native extension is not built" unless defined?(Rhex::Native)
  end

  it "visits the same cells as Ruby near rounding boundaries and coordinate limits" do
    random = Random.new(12345)
    limit = (1 << 29) - 100
    [-limit, -1000, 0, 1000, limit].product([-limit, 0, limit]).each do |q, r|
      40.times do
        args = [q, r, q + random.rand(-50..50), r + random.rand(-50..50)]
        ruby_keys = []
        native_keys = []
        ruby_obstacles = Hash.new do |_hash, key|
          ruby_keys << key
          false
        end
        native_obstacles = Hash.new do |_hash, key|
          native_keys << key
          false
        end

        Rhex::GridAlgorithms::INSTANCE.send(:line_blocked_ruby?, *args, ruby_obstacles)
        expect(Rhex::Native.line_blocked?(*args, native_obstacles)).to(be(false))
        expect(native_keys).to(eq(ruby_keys), "Ray #{args.inspect} differs")
      end
    end
  end

  it "ignores the source but includes an obstructed target" do
    source = Rhex::CoordinatePacker.pack(-2, -1)
    target = Rhex::CoordinatePacker.pack(-1, -1)

    expect(Rhex::Native.line_blocked?(-2, -1, -2, -1, { source => true })).to(be(false))
    expect(Rhex::Native.line_blocked?(-2, -1, -1, -1, { source => true })).to(be(false))
    expect(Rhex::Native.line_blocked?(-2, -1, -1, -1, { target => true })).to(be(true))
  end

  it "declines unsupported coordinates and overridden lookups" do
    expect(Rhex::Native.line_blocked?(0.0, 0, 1, 0, {})).to(be_nil)
    [-(1 << 29), 1 << 29, 1 << 80].each do |q|
      expect(Rhex::Native.line_blocked?(q, 0, q + 1, 0, {})).to(be_nil)
    end
    obstacles = {}
    def obstacles.[](_key) = true
    expect(Rhex::Native.line_blocked?(0, 0, 1, 0, obstacles)).to(be_nil)
  end

  it "lets Ruby interrupt long native rays" do
    # Use a separate process so a regression cannot hang the test runner's GVL.
    script = <<~RUBY
      require "rhex"
      require "timeout"
      begin
        Timeout.timeout(0.05) do
          Rhex::Native.line_blocked?(0, 0, 500_000_000, 0, {})
        end
        abort "Ray finished without processing the timeout"
      rescue Timeout::Error
        puts "interrupted"
      end
    RUBY
    Open3.popen3(RbConfig.ruby, "-I#{Rhex.root.join("lib")}", "-e", script) do |stdin, stdout, stderr, waiter|
      stdin.close
      begin
        status = Timeout.timeout(10) { waiter.value }
        expect(status.success?).to(be(true), stderr.read)
        expect(stdout.read.strip).to(eq("interrupted"))
      ensure
        Process.kill("KILL", waiter.pid) if waiter.alive?
      end
    end
  end
end
