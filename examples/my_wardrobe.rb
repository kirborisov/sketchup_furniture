# sketchup_furniture/examples/my_wardrobe.rb
# Пример: Шкаф в прихожей
#
# Загрузка:
#   load "путь/sketchup_furniture/sketchup_furniture.rb"
#   load "путь/sketchup_furniture/examples/my_wardrobe.rb"

wardrobe = Wardrobe.new "Прихожая", depth: 400 do
  
  # ═══════════ ЛЕВАЯ КОЛОННА ═══════════
  column 900 do
    
    # Низ — обувница (с цоколем 80мм)
    base 450, name: "Обувь" do
      plinth 80            # ниша 80мм снизу, боковины до пола
      sections "50%", "50%"
      shelf 150            # полка на высоте 150мм от дна
    end
    
    # Середина — одежда
    cabinet 1450, name: "Одежда" do
      sections "50%", "50%"
      shelf 900
    end
    
    # Антресоль
    top 800, name: "Антресоль-лев", shelf: 400
  end
  
  # ═══════════ ЦЕНТРАЛЬНАЯ КОЛОННА ═══════════
  column 700 do
    
    # Низ — ящики (пока как обычный шкаф)
    base 450, name: "Ящики" do
      sections "50%", "50%"
      shelves [150, 300]    # полки на высотах 150мм и 300мм (в каждой секции)
    end
    
    # Середина — полки
    cabinet 1450, name: "Полки" do
      sections "50%", "50%"
      shelves [300, 600, 900, 1200]
    end
    
    # Антресоль
    top 800, name: "Антресоль-центр", shelf: 400
  end
  
  # ═══════════ СКАМЕЙКА ═══════════
  column 1000 do
    
    # Скамейка (на ножках 100мм)
    base 450, name: "Скамейка" do
      legs 100             # ножки 100мм, боковины короче
      shelf 150
    end
    
    # Над скамейкой — открытое (крючки)
    cabinet 1450, name: "Крючки" do
      skip :back  # без задника — стена видна
    end
    
    # Антресоль
    top 800, name: "Антресоль-скам", shelf: 400
  end
  
end

# Строим
wardrobe.build

# Выводим результаты
wardrobe.summary
wardrobe.print_cut_list
wardrobe.print_hardware_list
