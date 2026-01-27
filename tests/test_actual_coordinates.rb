# sketchup_furniture/tests/test_actual_coordinates.rb
# Тест выводит РЕАЛЬНЫЕ координаты элементов для отладки

# Мок SketchUp API с трекингом координат
$drawn_elements = []

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
      $drawn_elements << { type: :face, points: args }
      Face.new
    end
    def add_dimension_linear(*args); nil; end
  end
  class Group
    attr_accessor :name
    def entities; Sketchup::Entities.new; end
    def transform!(*args); end
  end
  class Face
    def normal; Vector.new; end
    def pushpull(distance)
      $drawn_elements.last[:extrude] = distance
    end
  end
  class Vector; def z; 1; end; end
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

# === ТЕСТ 1: Шкаф на ножках ===
puts "\n" + "=" * 70
puts "ТЕСТ: Шкаф на ножках 100мм (высота 450мм)"
puts "=" * 70

$drawn_elements = []

cab = SketchupFurniture::Assemblies::Cabinet.new(800, 450, 400, thickness: 18, name: "Скамейка")
cab.legs(100)
cab.shelf(150)

context = SketchupFurniture::Core::Context.new(x: 0, y: 0, z: 0)
cab.build(context)

puts "\nПараметры опоры:"
puts "  side_start_z = #{cab.support.side_start_z} мм (откуда начинаются боковины)"
puts "  side_height_reduction = #{cab.support.side_height_reduction} мм"
puts "  bottom_z = #{cab.support.bottom_z} мм (где дно)"
puts "  has_geometry? = #{cab.support.has_geometry?}"

side_height = cab.height - cab.support.side_height_reduction
puts "\nРасчётная высота боковины: #{cab.height} - #{cab.support.side_height_reduction} = #{side_height} мм"

# Конвертируем для проверки
side_start_z_mm = cab.support.side_start_z
expected_side_end_z = side_start_z_mm + side_height
puts "Боковина должна быть: от z=#{side_start_z_mm}мм до z=#{expected_side_end_z}мм"

puts "\nОЖИДАНИЕ:"
puts "  ✓ Боковины начинаются на высоте 100мм (не от пола!)"
puts "  ✓ Боковины высотой 350мм (450-100)"
puts "  ✓ Между полом и боковиной зазор 100мм для ножек"

# === ТЕСТ 2: Ящики в колонне ===
puts "\n" + "=" * 70
puts "ТЕСТ: Ящики в центральной колонне (base 450, skip :bottom, 3×140)"
puts "=" * 70

$drawn_elements = []

cab2 = SketchupFurniture::Assemblies::Cabinet.new(700, 450, 400, thickness: 18, name: "Ящики")
cab2.skip(:bottom)
cab2.drawers(3, height: 140, slide: :ball_bearing)

context2 = SketchupFurniture::Core::Context.new(x: 900, y: 0, z: 0)  # смещён как центральная колонна
cab2.build(context2)

puts "\nПараметры:"
puts "  skip :bottom = да"
puts "  support.bottom_z = #{cab2.support.bottom_z} мм"
puts "  context.z = 0 мм (первый модуль в колонне)"

puts "\nРасчёт позиций ящиков:"
start_z = cab2.build_part?(:bottom) ? cab2.support.bottom_z + 18 : cab2.support.bottom_z
puts "  start_z (без дна) = #{start_z} мм"

configs = cab2.instance_variable_get(:@drawers_config)
configs.each_with_index do |cfg, i|
  offset = cab2.send(:drawer_z_offset, i)
  z_start = start_z + offset
  z_end = z_start + cfg[:height]
  puts "  Ящик #{i+1}: z = #{z_start}..#{z_end} мм (высота #{cfg[:height]})"
end

inner_top = 450 - 18
puts "\nВнутренняя высота до крышки: #{inner_top} мм"
puts "Все ящики до: #{start_z + 3*140} мм"

if start_z + 3*140 <= inner_top
  puts "✓ Ящики помещаются"
else
  puts "✗ ОШИБКА: ящики выпирают!"
end

# === ТЕСТ 3: Полная структура колонны ===
puts "\n" + "=" * 70
puts "ТЕСТ: Правая колонна (Скамейка) — 3 модуля"
puts "=" * 70

puts "\nСтруктура колонны:"
puts "  column 1000 do"
puts "    base 450, legs: 100   <- боковины z=100..450"
puts "    cabinet 1450          <- боковины z=450..1900"
puts "    top 800               <- боковины z=1900..2700"
puts "  end"

modules = [
  { name: "base", height: 450, legs: 100 },
  { name: "cabinet", height: 1450, legs: nil },
  { name: "top", height: 800, legs: nil }
]

z_pos = 0
modules.each do |mod|
  legs = mod[:legs] || 0
  side_start = z_pos + legs
  side_height = mod[:height] - legs
  side_end = side_start + side_height
  
  puts "\n  #{mod[:name]} (#{mod[:height]}мм):"
  puts "    Модуль: z = #{z_pos}..#{z_pos + mod[:height]}"
  if legs > 0
    puts "    Ножки: #{legs}мм"
    puts "    Боковины: z = #{side_start}..#{side_end} (высота #{side_height}мм)"
  else
    puts "    Боковины: z = #{side_start}..#{side_end}"
  end
  
  z_pos += mod[:height]
end

puts "\n" + "=" * 70
puts "ВЫВОД:"
puts "=" * 70
puts "1. Ножки НЕ РИСУЮТСЯ (только в списке фурнитуры)"
puts "   -> Это выглядит как 'пропавшая ножка'"
puts "   -> Нужно добавить визуализацию ножек?"
puts ""
puts "2. Боковины на ножках УКОРОЧЕНЫ и ПОДНЯТЫ"
puts "   -> z начинается не от 0, а от 100"
puts "   -> Это создаёт зазор для ножек"
puts ""
puts "3. Ящики позиционируются правильно"
puts "   -> При skip :bottom начинаются от z=0"
puts "   -> При наличии дна — от z=18 (толщина дна)"
puts "=" * 70
