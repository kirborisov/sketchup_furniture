# sketchup_furniture/examples/my_kitchen.rb
# Пример: Линейная кухня
#
# Загрузка:
#   load "путь/sketchup_furniture/sketchup_furniture.rb"
#   load "путь/sketchup_furniture/examples/my_kitchen.rb"

$kitchen = Kitchen.new "Кухня" do
  
  # ═══════════ НИЖНИЙ РЯД ═══════════
  lower depth: 560, height: 820 do
    legs 50
    

    
    # Ящики
    cabinet 400, name: "Ящики" do
      stretchers            # стандартные царги
      drawers [0, 150, 350], type: :frame
    end
    
    # Посуда
    cabinet 1100, name: "Посуда", height: 480 do
      stretchers            # стандартные царги
      drawer_row count: 2, type: :frame
    end
    
    # Столовые приборы (ящик + дверца)
    cabinet 500, name: "Шкаф №2 Комбинированный" do
      stretchers
      # Нижняя часть — вертикальная колонка выдвижных ящиков
      drawers 1, height: 250, type: :frame

      # Разделительная полка над ящиком
      separator_shelf

      # Верхняя часть — дверца над ящиками
      doors 1, over_drawers: true, type: :frame
    end

    # Шкаф с глухой панелью (торцевой — панель слева, дверь справа)
    cabinet 1400, name: "Шкаф 1 с мойкой" do
      stretchers
      shelves [250, 500]
      blind_panel side: :left, width: 550   # глухая панель 200 мм слева
      doors 2, type: :frame                              # одна дверь на оставшуюся ширину
    end

  end


  # ═══════════ ВЕРХНИЙ РЯД ═══════════
  upper depth: 300, height: 600, at: 1400 do
    
    # Сушка над мойкой
    cabinet 500, name: "Сушка" do
      shelves [150, 300]
      doors 1, type: :frame               # две створки
    end
    
    # Специи (рамочная дверь)
    cabinet 500, name: "Специи" do
      shelves [150, 300]
      doors 1, type: :frame # рамка из массива + филёнка
    end
    
  end
  
  # ═══════════ СТОЛЕШНИЦА ═══════════
  #countertop 38, overhang: 30
  
end

# Строим
$kitchen.build

# Выводим результаты
$kitchen.summary
$kitchen.print_cut_list
$kitchen.print_hardware_list

# Активируем инструмент ящиков
$kitchen.activate_drawer_tool
