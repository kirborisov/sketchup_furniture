# furniture/core/cut_item.rb
# Элемент для таблицы раскроя

module SketchupFurniture
  module Core
    class CutItem
      attr_accessor :name, :length, :width, :thickness
      attr_accessor :material, :quantity, :cabinet
      attr_accessor :edge_front, :edge_back, :edge_left, :edge_right
      
      def initialize(name:, length:, width:, thickness:, material: "ЛДСП", cabinet: nil)
        # Длина всегда >= ширина
        @length = [length, width].max
        @width = [length, width].min
        @thickness = thickness
        @name = name
        @material = material
        @cabinet = cabinet
        @quantity = 1
        
        # Кромка по умолчанию — без
        @edge_front = 0
        @edge_back = 0
        @edge_left = 0
        @edge_right = 0
      end
      
      # Установить кромку
      def edge(front: 0, back: 0, left: 0, right: 0, all: nil)
        if all
          @edge_front = @edge_back = @edge_left = @edge_right = all
        else
          @edge_front = front
          @edge_back = back
          @edge_left = left
          @edge_right = right
        end
        self
      end
      
      # Площадь в м²
      def area
        @length * @width / 1_000_000.0
      end
      
      # Периметр кромки в м
      def edge_length
        total = 0
        total += @length if @edge_front > 0
        total += @length if @edge_back > 0
        total += @width if @edge_left > 0
        total += @width if @edge_right > 0
        total / 1000.0
      end
      
      # Ключ для группировки одинаковых деталей
      def group_key
        [@cabinet, @name, @length, @width, @thickness, @material]
      end
      
      # Строковое представление
      def to_s
        "#{@name}: #{@length}×#{@width}×#{@thickness} (#{@material})"
      end
    end
  end
end
