# sketchup_furniture/components/support/base_support.rb
# Базовый класс для опор шкафа

module SketchupFurniture
  module Components
    module Support
      class BaseSupport
        attr_reader :height
        
        def initialize(height = 0)
          @height = height
        end
        
        # Откуда начинаются боковины (Z координата)
        def side_start_z
          0
        end
        
        # На какой высоте дно (Z координата)
        def bottom_z
          0
        end
        
        # Высота боковин (уменьшается если ножки)
        def side_height_reduction
          0
        end
        
        # Нужно ли рисовать геометрию опоры?
        def has_geometry?
          false
        end
        
        # Построить геометрию опоры
        def build(group, x:, y:, z:, width:, depth:, thickness:)
          # Реализуется в наследниках
        end
        
        # Фурнитура для опоры
        def hardware
          []
        end
        
        # Детали раскроя для опоры
        def cut_items
          []
        end
        
        # Тип опоры
        def type
          :standard
        end
        
        # Фабричный метод
        def self.create(type, height = 0)
          case type
          when :standard, :sides, nil
            SidesSupport.new
          when :plinth
            PlinthSupport.new(height)
          when :legs
            LegsSupport.new(height)
          else
            SidesSupport.new
          end
        end
      end
    end
  end
end
