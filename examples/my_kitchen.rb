# sketchup_furniture/examples/my_kitchen.rb
# Пример: Линейная кухня
#
# Загрузка:
#   load "путь/sketchup_furniture/sketchup_furniture.rb"
#   load "путь/sketchup_furniture/examples/my_kitchen.rb"

# Фасады рядов ящиков прикрывают дно и верх корпуса с зазором facade_gap/2
SketchupFurniture.config.drawer_row_overlay = true

# При повторном load удаляем только старые группы кухни (корневые группы с именем "Кухня")
model = Sketchup.active_model
to_erase = model.entities.to_a.select { |e| e.is_a?(Sketchup::Group) && e.name == "Кухня" }
to_erase.each { |g| g.erase! if g.valid? }

$kitchen = Kitchen.new "Кухня" do
  
  # ═══════════ НИЖНИЙ РЯД ═══════════
  lower depth: 560, height: 850 do
    legs 0
    

    # Нижний ящик большой, два верхних одинаковые; глубина 400 мм
    cabinet 700, name: "Шкаф 5, ящики", depth: 400 do
      stretchers
      drawers [0, 400, 567], type: :frame
    end

    # Ящики
    cabinet 800, name: "Шкаф 4" do
      stretchers
      shelves [250]
      blind_panel side: :left, width: 400   # глухая панель 200 мм слева
      doors 1, type: :frame                              # одна дверь на оставшуюся ширину
    end
    
    # Посуда
    cabinet 1100, name: "Шкаф 3 (под окном)", height: 480 do
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

# Строим кухню
$kitchen.build

# Выводим результаты
$kitchen.summary
$kitchen.print_cut_list
$kitchen.print_hardware_list

# Размеры: общие габариты + по каждому корпусу (ширины нижнего и верхнего ряда)
# Режимы: :overview — только общие, :sections — общие + по корпусам, :detailed — ещё полки
$kitchen.show_dimensions(:sections)

# Активируем инструмент ящиков (двойной клик)
$kitchen.activate_drawer_tool
