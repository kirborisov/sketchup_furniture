# sketchup_furniture/sketchup_furniture.rb
# Мебельный конструктор для SketchUp
#
# Загрузка в SketchUp:
#   load "путь/sketchup_furniture/sketchup_furniture.rb"
#
# Использование:
#   Wardrobe.new "Прихожая", depth: 400 do
#     column 900 do
#       base 450
#       cabinet 1450
#       top 800
#     end
#   end.build

SKETCHUP_FURNITURE_PATH = File.dirname(__FILE__)

# === МОДУЛЬ ===

module SketchupFurniture
  VERSION = "1.0.0"
  
  # Глобальная конфигурация
  def self.config
    @config ||= Core::Config.new
  end
  
  # Сбросить конфигурацию
  def self.reset_config
    @config = Core::Config.new
  end
end

# === ЗАГРУЗКА ФАЙЛОВ ===

# 1. Ядро
load File.join(SKETCHUP_FURNITURE_PATH, 'core', 'config.rb')
load File.join(SKETCHUP_FURNITURE_PATH, 'core', 'context.rb')
load File.join(SKETCHUP_FURNITURE_PATH, 'core', 'cut_item.rb')
load File.join(SKETCHUP_FURNITURE_PATH, 'core', 'hardware_item.rb')
load File.join(SKETCHUP_FURNITURE_PATH, 'core', 'component.rb')

# 2. Примитивы
load File.join(SKETCHUP_FURNITURE_PATH, 'primitives', 'panel.rb')

# 3. Материалы
load File.join(SKETCHUP_FURNITURE_PATH, 'materials', 'catalog.rb')

# 4. Компоненты — опоры
load File.join(SKETCHUP_FURNITURE_PATH, 'components', 'support', 'base_support.rb')
load File.join(SKETCHUP_FURNITURE_PATH, 'components', 'support', 'sides_support.rb')
load File.join(SKETCHUP_FURNITURE_PATH, 'components', 'support', 'plinth_support.rb')
load File.join(SKETCHUP_FURNITURE_PATH, 'components', 'support', 'legs_support.rb')

# 5. Компоненты — корпус
load File.join(SKETCHUP_FURNITURE_PATH, 'components', 'body', 'side.rb')
load File.join(SKETCHUP_FURNITURE_PATH, 'components', 'body', 'top_bottom.rb')
load File.join(SKETCHUP_FURNITURE_PATH, 'components', 'body', 'back.rb')
load File.join(SKETCHUP_FURNITURE_PATH, 'components', 'body', 'shelf.rb')
load File.join(SKETCHUP_FURNITURE_PATH, 'components', 'body', 'countertop.rb')

# 6. Инструменты
load File.join(SKETCHUP_FURNITURE_PATH, 'tools', 'drawer_tool.rb')

# 7. Компоненты — фасады
load File.join(SKETCHUP_FURNITURE_PATH, 'components', 'fronts', 'door.rb')

# 8. Компоненты — ящики
load File.join(SKETCHUP_FURNITURE_PATH, 'components', 'drawers', 'slides', 'base_slide.rb')
load File.join(SKETCHUP_FURNITURE_PATH, 'components', 'drawers', 'slides', 'ball_bearing.rb')
load File.join(SKETCHUP_FURNITURE_PATH, 'components', 'drawers', 'drawer_box.rb')
load File.join(SKETCHUP_FURNITURE_PATH, 'components', 'drawers', 'drawer.rb')

# 9. Сборки
load File.join(SKETCHUP_FURNITURE_PATH, 'assemblies', 'cabinet.rb')

# 10. Контейнеры
load File.join(SKETCHUP_FURNITURE_PATH, 'containers', 'column.rb')

# 11. Вывод
load File.join(SKETCHUP_FURNITURE_PATH, 'output', 'cut_list.rb')
load File.join(SKETCHUP_FURNITURE_PATH, 'output', 'hardware_list.rb')

# 12. Утилиты
load File.join(SKETCHUP_FURNITURE_PATH, 'utils', 'dimensions.rb')

# 13. Пресеты
load File.join(SKETCHUP_FURNITURE_PATH, 'presets', 'wardrobe.rb')
load File.join(SKETCHUP_FURNITURE_PATH, 'presets', 'kitchen.rb')


# При повторной загрузке — пересоздать конфиг с новыми параметрами
SketchupFurniture.reset_config

# === ХЕЛПЕРЫ ===

# Расширение Numeric для миллиметров (если ещё нет)
unless Numeric.method_defined?(:mm)
  class Numeric
    def mm
      self
    end
  end
end


# === СПРАВКА ===

puts <<-HELP

╔════════════════════════════════════════════════════════════════╗
║           МЕБЕЛЬНЫЙ КОНСТРУКТОР v#{SketchupFurniture::VERSION.ljust(26)}║
╠════════════════════════════════════════════════════════════════╣
║  Wardrobe.new "Имя", depth: 400 do                            ║
║    column 900 do                                               ║
║      base 450                                                  ║
║      cabinet 1450 do shelves [300, 600, 900] end               ║
║      top 800, shelf: 400                                       ║
║    end                                                         ║
║  end.build                                                     ║
╠════════════════════════════════════════════════════════════════╣
║  Kitchen.new "Имя" do                                          ║
║    lower depth: 560, height: 820 do                            ║
║      plinth 100                                                ║
║      cabinet 600, name: "Мойка" do ... end                     ║
║    end                                                         ║
║    upper depth: 300, height: 600, at: 1400 do                  ║
║      cabinet 600, name: "Сушка" do ... end                     ║
║    end                                                         ║
║    countertop 38, overhang: 30                                 ║
║  end.build                                                     ║
╠════════════════════════════════════════════════════════════════╣
║  После .build:                                                 ║
║    .print_cut_list      - раскрой                              ║
║    .print_hardware_list - фурнитура                            ║
║    .summary             - сводка                               ║
║    .show_dimensions     - показать размеры                     ║
║    .hide_dimensions     - скрыть размеры                       ║
║    .activate_drawer_tool - двойной клик по ящику/двери         ║
╚════════════════════════════════════════════════════════════════╝

HELP
