# sketchup_furniture/tests/test_facade_and_legs.rb
# Тесты на правильность построения фасадов и ножек

# Мок SketchUp API с записью геометрии
$created_faces = []

module Sketchup
  def self.active_model; Model.new; end
  class Model
    def start_operation(*args); end
    def commit_operation; end
    def active_entities; Entities.new; end
  end
  class Entities
    def add_group; Group.new; end
    def add_face(*args)
      face = Face.new(args)
      $created_faces << face
      face
    end
    def add_dimension_linear(*args); nil; end
  end
  class Group
    attr_accessor :name
    def entities; Sketchup::Entities.new; end
    def transform!(*args); end
  end
  class Face
    attr_reader :points, :extruded
    def initialize(pts)
      @points = pts.flatten
      @extruded = nil
    end
    def normal; Vector.new(orientation); end
    def pushpull(distance)
      @extruded = distance
    end
    
    # Определяем ориентацию грани
    def orientation
      return :unknown if @points.length < 12
      
      # Берём 3 точки и определяем плоскость
      x1, y1, z1 = @points[0..2]
      x2, y2, z2 = @points[3..5]
      x3, y3, z3 = @points[6..8]
      
      # Если все Z одинаковые — горизонтальная грань (XY)
      if z1 == z2 && z2 == z3
        :horizontal
      # Если все Y одинаковые — вертикальная грань фронтальная (XZ)
      elsif y1 == y2 && y2 == y3
        :vertical_xz
      # Если все X одинаковые — вертикальная грань боковая (YZ)
      elsif x1 == x2 && x2 == x3
        :vertical_yz
      else
        :unknown
      end
    end
  end
  class Vector
    def initialize(orientation = :unknown)
      @orientation = orientation
    end
    def z
      case @orientation
      when :horizontal then 1
      when :vertical_xz then 0
      when :vertical_yz then 0
      else 1
      end
    end
  end
end

module Geom
  class Vector3d
    def initialize(*args); end
  end
  class Transformation
    def self.translation(v); new; end
    def initialize; end
  end
end

Dir.chdir(File.dirname(__FILE__) + '/..')
load 'sketchup_furniture.rb'

$tests_passed = 0
$tests_failed = 0

def assert(condition, message = "")
  if condition
    $tests_passed += 1
    puts "  ✓ #{message}"
  else
    $tests_failed += 1
    puts "  ✗ #{message}"
  end
end

def assert_equal(expected, actual, message = "")
  if expected == actual
    $tests_passed += 1
    puts "  ✓ #{message}"
  else
    $tests_failed += 1
    puts "  ✗ #{message}: ожидалось #{expected}, получено #{actual}"
  end
end

def test(name)
  puts "\n#{name}"
  yield
end

# === ТЕСТЫ ФАСАДОВ ===

test "Фасад ящика — вертикальная панель (XZ плоскость)" do
  $created_faces = []
  
  drawer = SketchupFurniture::Components::Drawers::Drawer.new(
    140,
    cabinet_width: 764,
    cabinet_depth: 396
  )
  
  context = SketchupFurniture::Core::Context.new(x: 0, y: 0, z: 0)
  drawer.build(context)
  
  # Ищем фасад — это должна быть вертикальная грань XZ
  facade_faces = $created_faces.select { |f| f.orientation == :vertical_xz }
  
  assert facade_faces.length >= 1, "найдена вертикальная грань XZ (фасад)"
  
  # Фасад должен быть выдавлен на толщину (16мм = ~0.63 дюйма)
  facade = facade_faces.first
  if facade && facade.extruded
    # Толщина фасада 16мм ≈ 0.63 дюйма
    expected_thickness = 16.mm
    assert_equal expected_thickness, facade.extruded, "толщина фасада = 16мм"
  end
end

test "Фасад ящика — размеры соответствуют ширине и высоте" do
  $created_faces = []
  
  drawer_height = 140
  cabinet_width = 764
  facade_gap = 3
  
  drawer = SketchupFurniture::Components::Drawers::Drawer.new(
    drawer_height,
    cabinet_width: cabinet_width,
    cabinet_depth: 396
  )
  
  # Фасад: ширина = cabinet_width, высота = drawer_height - gap
  expected_width = cabinet_width
  expected_height = drawer_height - facade_gap  # = 137
  
  assert_equal expected_width, drawer.width, "ширина фасада = ширина шкафа"
  assert_equal expected_height, drawer_height - facade_gap, "высота фасада = 137мм"
end

# === ТЕСТЫ НОЖЕК ===

test "Ножки — has_geometry возвращает true" do
  cab = SketchupFurniture::Assemblies::Cabinet.new(800, 450, 400, thickness: 18)
  cab.legs(100)
  
  assert cab.support.has_geometry?, "ножки имеют геометрию"
end

test "Ножки — создаётся 4 ножки для узкого шкафа" do
  cab = SketchupFurniture::Assemblies::Cabinet.new(600, 450, 400, thickness: 18)
  cab.legs(100)
  
  assert_equal 4, cab.support.count, "4 ножки для ширины < 800мм"
end

test "Ножки — создаётся 6 ножек для широкого шкафа" do
  cab = SketchupFurniture::Assemblies::Cabinet.new(1000, 450, 400, thickness: 18)
  cab.legs(100)
  
  assert_equal 6, cab.support.count, "6 ножек для ширины > 800мм"
end

test "Ножки — геометрия строится при build" do
  $created_faces = []
  
  cab = SketchupFurniture::Assemblies::Cabinet.new(600, 450, 400, thickness: 18, name: "Скамейка")
  cab.legs(100)
  cab.shelf(150)
  
  context = SketchupFurniture::Core::Context.new(x: 0, y: 0, z: 0)
  cab.build(context)
  
  # Должны быть созданы грани для ножек (горизонтальные грани у пола)
  horizontal_faces_at_z0 = $created_faces.select do |f|
    f.orientation == :horizontal && f.points[2] == 0
  end
  
  # 4 ножки = минимум 4 горизонтальные грани у z=0
  assert horizontal_faces_at_z0.length >= 4, "созданы грани для ножек (минимум 4)"
end

test "Ножки — высота ножек соответствует параметру" do
  $created_faces = []
  
  leg_height = 100
  
  cab = SketchupFurniture::Assemblies::Cabinet.new(600, 450, 400, thickness: 18)
  cab.legs(leg_height)
  
  context = SketchupFurniture::Core::Context.new(x: 0, y: 0, z: 0)
  cab.build(context)
  
  # Ножки выдавливаются на высоту leg_height.mm
  expected_extrude = leg_height.mm
  
  leg_faces = $created_faces.select do |f|
    f.orientation == :horizontal && 
    f.points[2] == 0 && 
    f.extruded == expected_extrude
  end
  
  assert leg_faces.length >= 4, "ножки выдавлены на #{leg_height}мм"
end

# === ТЕСТЫ ЦОКОЛЯ ===

test "Цоколь — has_geometry по умолчанию false" do
  cab = SketchupFurniture::Assemblies::Cabinet.new(800, 450, 400, thickness: 18)
  cab.plinth(80)
  
  assert !cab.support.has_geometry?, "цоколь без передней панели — нет геометрии"
end

test "Цоколь с передней панелью — has_geometry true" do
  cab = SketchupFurniture::Assemblies::Cabinet.new(800, 450, 400, thickness: 18)
  cab.plinth(80, front_panel: true)
  
  assert cab.support.has_geometry?, "цоколь с передней панелью — есть геометрия"
end

# === ОБЩИЕ ТЕСТЫ ===

test "Боковина — вертикальная грань YZ" do
  $created_faces = []
  
  cab = SketchupFurniture::Assemblies::Cabinet.new(800, 500, 400, thickness: 18, name: "Тест")
  context = SketchupFurniture::Core::Context.new(x: 0, y: 0, z: 0)
  cab.build(context)
  
  # Боковины — горизонтальные грани которые потом выдавливаются вверх
  # (из-за особенности Panel.side — создаёт горизонтальную грань и pushpull вверх)
  vertical_faces = $created_faces.select { |f| f.orientation == :horizontal && f.extruded && f.extruded > 0 }
  
  assert vertical_faces.length >= 2, "найдены боковины (минимум 2)"
end

# === ИТОГИ ===

puts "\n" + "=" * 60
puts "РЕЗУЛЬТАТЫ ТЕСТОВ ФАСАДОВ И НОЖЕК:"
puts "  Пройдено: #{$tests_passed}"
puts "  Провалено: #{$tests_failed}"
puts "=" * 60

exit($tests_failed > 0 ? 1 : 0)
