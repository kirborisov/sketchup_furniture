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
