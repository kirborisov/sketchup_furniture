# furniture/presets/wardrobe.rb
# Встроенный шкаф / гардероб

module SketchupFurniture
  module Presets
    class Wardrobe < Core::Component
      attr_reader :columns
      
      def initialize(name = "Шкаф", depth: 400, thickness: 18, &block)
        super(0, 0, depth, name: name)
        @thickness = thickness
        @columns = []
        @cut_list = Output::CutList.new
        @hardware_list = Output::HardwareList.new
        @dimensions = Utils::Dimensions.new
        
        instance_eval(&block) if block_given?
      end
      
      # DSL: добавить колонну
      def column(width, name: nil, &block)
        col = Containers::Column.new(width, name: name)
        col.instance_variable_set(:@depth, @depth)
        col.at_x(@width)  # смещение = текущая ширина
        
        col.instance_eval(&block) if block_given?
        
        @columns << col
        @width += width
        @height = [@height, col.height].max
        
        col
      end
      
      # Построение
      def build(context = nil)
        Tools::DrawerTool.clear
        @context = context || Core::Context.new
        @group = create_group(@name)
        
        @columns.each do |col|
          col.build(@context)
        end
        
        # Собираем раскрой и фурнитуру
        collect_outputs
        
        @group
      end
      
      # Печать раскроя
      def print_cut_list
        @cut_list.print
      end
      
      # Печать фурнитуры
      def print_hardware_list
        @hardware_list.print
      end
      
      # Сводка
      def summary
        puts "\n" + "=" * 60
        puts "ШКАФ: #{@name}"
        puts "=" * 60
        puts "Габариты: #{@width} × #{@height} × #{@depth} мм"
        puts "Колонн: #{@columns.length}"
        
        @cut_list.summary
        @hardware_list.summary
      end
      
      # === РАЗМЕРЫ ===
      
      # Показать размеры
      # mode: :off, :overview, :sections, :detailed
      def show_dimensions(mode = :overview)
        @dimensions.show(self, mode)
        nil  # Не выводить объект в консоль
      end
      
      # Убрать размеры
      def hide_dimensions
        @dimensions.hide
        puts "Размеры скрыты"
        nil  # Не выводить объект в консоль
      end
      
      # Текущий режим размеров
      def dimensions_mode
        @dimensions.mode
      end
      
      # === ЯЩИКИ ===
      
      # Активировать инструмент ящиков (двойной клик)
      def activate_drawer_tool
        Tools::DrawerTool.activate
      end
      
      # Получить все ящики
      def all_drawers
        drawers = []
        @columns.each do |col|
          col.modules.each do |mod|
            if mod.respond_to?(:drawer_objects)
              drawers.concat(mod.drawer_objects)
            end
          end
        end
        drawers
      end
      
      # Открыть конкретный ящик
      # wardrobe.open_drawer(1, 0, 0)  # колонна 1, модуль 0, ящик 0
      def open_drawer(column_idx, module_idx = 0, drawer_idx = 0, amount: nil)
        drawer = get_drawer(column_idx, module_idx, drawer_idx)
        drawer&.open(amount)
      end
      
      # Закрыть конкретный ящик
      def close_drawer(column_idx, module_idx = 0, drawer_idx = 0)
        drawer = get_drawer(column_idx, module_idx, drawer_idx)
        drawer&.close
      end
      
      # Открыть все ящики
      def open_all_drawers(amount: nil)
        all_drawers.each { |d| d.open(amount) }
        puts "Открыто ящиков: #{all_drawers.length}"
      end
      
      # Закрыть все ящики
      def close_all_drawers
        all_drawers.each(&:close)
        puts "Закрыто ящиков: #{all_drawers.length}"
      end
      
      # Получить ящик по индексам
      def get_drawer(column_idx, module_idx, drawer_idx)
        col = @columns[column_idx]
        return nil unless col
        
        mod = col.modules[module_idx]
        return nil unless mod&.respond_to?(:drawer_objects)
        
        mod.drawer_objects[drawer_idx]
      end
      
      private
      
      def collect_outputs
        @cut_list.clear
        @hardware_list.clear
        
        @columns.each do |col|
          @cut_list.add(col.all_cut_items)
          @hardware_list.add(col.all_hardware_items)
        end
      end
    end
  end
end

# Алиас для удобства
Wardrobe = SketchupFurniture::Presets::Wardrobe
