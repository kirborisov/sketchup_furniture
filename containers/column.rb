# furniture/containers/column.rb
# Вертикальная колонна (стопка модулей)

module SketchupFurniture
  module Containers
    class Column < Core::Component
      attr_reader :modules
      
      def initialize(width, name: nil)
        super(width, 0, 0, name: name)  # высота и глубина определятся по модулям
        @modules = []
        @x_offset = 0
      end
      
      # Установить смещение X
      def at_x(x)
        @x_offset = x
        self
      end
      
      # Добавить модуль
      def add_module(mod)
        @modules << mod
        @height += mod.height
        @depth = [@depth, mod.depth].max
        self
      end
      
      # DSL: базовый шкаф (напольный)
      def base(height, name: nil, **options, &block)
        cab = Assemblies::Cabinet.new(@width, height, @depth, name: name, **options)
        cab.instance_eval(&block) if block_given?
        add_module(cab)
        cab
      end
      
      # DSL: обычный шкаф
      def cabinet(height, name: nil, **options, &block)
        cab = Assemblies::Cabinet.new(@width, height, @depth, name: name, **options)
        cab.instance_eval(&block) if block_given?
        add_module(cab)
        cab
      end
      
      # DSL: антресоль (верхний шкаф)
      def top(height, name: nil, shelf: nil, **options)
        cab = Assemblies::Cabinet.new(@width, height, @depth, name: name || "Антресоль", **options)
        cab.shelf(shelf) if shelf
        add_module(cab)
        cab
      end
      
      # Построение
      def build_geometry
        z_pos = 0
        
        @modules.each do |mod|
          mod_context = @context.offset(dx: @x_offset, dz: z_pos)
          mod.build(mod_context)
          z_pos += mod.height
        end
      end
      
      # Собрать раскрой со всех модулей
      def all_cut_items
        items = super
        @modules.each { |m| items.concat(m.all_cut_items) }
        items
      end
      
      # Собрать фурнитуру со всех модулей
      def all_hardware_items
        items = super
        @modules.each { |m| items.concat(m.all_hardware_items) }
        items
      end
    end
  end
end
