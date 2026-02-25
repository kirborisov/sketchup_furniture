# sketchup_furniture/examples/my_kitchen.rb
# Пример: Линейная кухня
#
# Загрузка:
#   load "путь/sketchup_furniture/sketchup_furniture.rb"
#   load "путь/sketchup_furniture/examples/my_kitchen.rb"

$kitchen = Kitchen.new "Кухня" do
  
  # ═══════════ НИЖНИЙ РЯД ═══════════
  lower depth: 560, height: 820 do
    plinth 100
    
    # Мойка
    cabinet 600, name: "Мойка" do
      stretchers :sink      # царги на ребро
      skip :bottom          # под мойкой нет дна
    end
    
    # Ящики
    cabinet 400, name: "Ящики" do
      stretchers            # стандартные царги
      drawers 3, height: 150, slide: :ball_bearing
    end
    
    # Посуда
    cabinet 600, name: "Посуда" do
      stretchers            # стандартные царги
      shelves [250, 500]
      doors 2               # две створки
    end
    
    # Столовые приборы (ряды ящиков)
    cabinet 600, name: "Приборы" do
      stretchers
      drawer_row height: 100, count: 2   # два равных ящика + перегородка
      drawer_row height: 200, count: 1   # сплошной
      drawer_row height: 200, count: 1   # сплошной
    end
    
    # Духовка
    cabinet 600, name: "Духовка" do
      stretchers            # стандартные царги
      skip :back, :bottom   # ниша под встройку
    end
  end
  
  # ═══════════ ВЕРХНИЙ РЯД ═══════════
  upper depth: 300, height: 600, at: 1400 do
    
    # Сушка над мойкой
    cabinet 600, name: "Сушка" do
      shelf 300
      doors 2               # две створки
    end
    
    # Специи
    cabinet 400, name: "Специи" do
      shelves [150, 300, 450]
      door                  # одна дверь
    end
    
    # Посуда
    cabinet 600, name: "Посуда верх" do
      shelf 300
      doors 2               # две створки
    end
  end
  
  # ═══════════ СТОЛЕШНИЦА ═══════════
  countertop 38, overhang: 30
  
end

# Строим
$kitchen.build

# Выводим результаты
$kitchen.summary
$kitchen.print_cut_list
$kitchen.print_hardware_list

# Активируем инструмент ящиков
$kitchen.activate_drawer_tool
