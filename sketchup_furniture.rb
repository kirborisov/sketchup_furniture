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

# 4. Компоненты
load File.join(SKETCHUP_FURNITURE_PATH, 'components', 'body', 'side.rb')
load File.join(SKETCHUP_FURNITURE_PATH, 'components', 'body', 'top_bottom.rb')
load File.join(SKETCHUP_FURNITURE_PATH, 'components', 'body', 'back.rb')
load File.join(SKETCHUP_FURNITURE_PATH, 'components', 'body', 'shelf.rb')

# 5. Сборки
load File.join(SKETCHUP_FURNITURE_PATH, 'assemblies', 'cabinet.rb')

# 6. Контейнеры
load File.join(SKETCHUP_FURNITURE_PATH, 'containers', 'column.rb')

# 7. Вывод
load File.join(SKETCHUP_FURNITURE_PATH, 'output', 'cut_list.rb')
load File.join(SKETCHUP_FURNITURE_PATH, 'output', 'hardware_list.rb')

# 8. Пресеты
load File.join(SKETCHUP_FURNITURE_PATH, 'presets', 'wardrobe.rb')


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
║  Wardrobe.new "Имя", depth: 400 do                             ║
║    column 900 do                                               ║
║      base 450, sections: 2                                     ║
║      cabinet 1450 do                                           ║
║        shelves [300, 600, 900]                                 ║
║      end                                                       ║
║      top 800, shelf: 400                                       ║
║    end                                                         ║
║  end.build                                                     ║
╠════════════════════════════════════════════════════════════════╣
║  После .build:                                                 ║
║    wardrobe.print_cut_list      - раскрой                      ║
║    wardrobe.print_hardware_list - фурнитура                    ║
║    wardrobe.summary             - сводка                       ║
╚════════════════════════════════════════════════════════════════╝

HELP
