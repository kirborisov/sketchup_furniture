# sketchup_furniture/examples/my_wardrobe.rb
# Пример: Шкаф в прихожей
#
# Загрузка:
#   load "путь/sketchup_furniture/sketchup_furniture.rb"
#   load "путь/sketchup_furniture/examples/my_wardrobe.rb"

wardrobe = Wardrobe.new "Прихожая", depth: 400 do
  
  # ═══════════ ЛЕВАЯ КОЛОННА ═══════════
  column 900 do
    
    # Низ — обувница
    base 450, name: "Обувь" do
      sections "50%", "50%"
      shelves [200, 200]
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
      shelves [150, 300]
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
    
    # Скамейка
    base 450, name: "Скамейка" do
      shelf 150
    end
    
    # Над скамейкой — открытое (крючки)
    cabinet 1450, name: "Крючки" do
      no_back  # без задника — стена видна
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
