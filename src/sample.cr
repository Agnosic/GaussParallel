# TODO: Write documentation for `Sample`
module Sample
  VERSION = "0.1.0"

  class Parser
    property path : String
    getter size : Int32
    getter matrix : Array(Array(Float64))
    getter vec : Array(Float64)

    def initialize(path : String)
      @path = path
      @size = 0
      @matrix = Array.new(@size) { |i| Array.new(@size) { |j| 0.0 } }
      @vec = Array.new(@size) { |i| 0.0 }
    end

    def decode
      file = File.read_lines(@path)
      @size = file[0].to_i
      @matrix = Array.new(@size) { |i| Array.new(@size) { |j| 0.0 } }
      @vec = Array.new(@size) { |i| 0.0 }
      @size.times do |i|
        vec = file[i + 1].split(" ").map { |n| n.to_f }
        @size.times do |j|
          @matrix[i][j] = vec[j]
        end
      end

      vec = file[@size + 1].split(" ").map { |n| n.to_f }
      @size.times do |j|
        @vec[j] = vec[j]
      end
    end
  end

  class Matryx
    property matrix : Array(Array(Float64))
    property vec : Array(Float64)
    property aS : Array(Float64)

    def initialize(matrix : Array(Array(Float64)), vec : Array(Float64), size : Int32)
      @matrix = matrix
      @vec = vec
      @aS = Array.new(size) { |i| 0.0 }
      @size = size
    end

    def to_s
      text = @size.to_s + " \n"
      0..@size.times do |i|
        text += @matrix[i].map { |n| n.to_s }.reduce { |acc, j| acc + " " + j }
        text += "\n"
      end
      text += @vec.map { |n| n.to_s }.reduce { |acc, j| acc + " " + j }
    end
  end

  class A
    def initialize(i : Int32, k : Int32, matryx : Matryx)
      @k = k
      @i = i
      @matryx = matryx
    end

    def calculate
      @matryx.aS[@k] = @matryx.matrix[@k][@i] / @matryx.matrix[@i][@i]
      :ok
    end
  end

  class BC
    def initialize(i : Int32, k : Int32, j : Int32, matryx : Matryx)
      @i = i
      @k = k
      @j = j
      @matryx = matryx
    end

    def calculateMatrix
      @matryx.matrix[@k][@j] -= @matryx.aS[@k] * @matryx.matrix[@i][@j]
      :ok
    end

    def calculateVec
      @matryx.vec[@k] -= @matryx.aS[@k] * @matryx.vec[@i]
      :ok
    end
  end

  class Normalizer
    def initialize(matryx : Matryx, size : Int32)
      @matryx = matryx
      @size = size
    end

    def normalize
      i = @size - 1
      while i >= 0
        j = i + 1
        while j < @size
          @matryx.vec[i] -= @matryx.matrix[i][j] * @matryx.vec[j]
          @matryx.matrix[i][j] = 0.0
          j += 1
        end
        @matryx.vec[i] = @matryx.vec[i] / @matryx.matrix[i][i]
        @matryx.matrix[i][i] = 1.0
        i -= 1
      end
      # @matryx.vec[@row] /= @matryx.matrix[@row][@row]
      # @matryx.matrix[@row][@row] = 1.0
      :ok
    end
  end

  channel = Channel(Symbol).new

  # person = channel.receive

  parser = Parser.new "input/in.txt"
  parser.decode
  size = parser.size
  matrix = parser.matrix
  vec = parser.vec
  matryx = Matryx.new(matrix, vec, size)

  (0..(size - 1)).each do |i|
    matryx.aS = Array.new(size) { |i| 0.0 }

    ((i + 1)..(size - 1)).each do |k|
      spawn do
        channel.send(A.new(i, k, matryx).calculate)
      end
    end

    ((i + 1)..(size - 1)).each do |k|
      channel.receive
    end

    ((i + 1)..(size - 1)).each do |k|
      (i..(size - 1)).each do |j|
        spawn do
          channel.send(BC.new(i, k, j, matryx).calculateMatrix)
        end
      end
      spawn do
        channel.send(BC.new(i, k, 0, matryx).calculateVec)
      end
    end

    ((i + 1)..(size - 1)).each do |k|
      (i..(size - 1)).each do |j|
        channel.receive
      end
      channel.receive
    end
  end

  Normalizer.new(matryx, size).normalize

  puts matryx.to_s

  File.write("input/out.txt", matryx.to_s)
end
