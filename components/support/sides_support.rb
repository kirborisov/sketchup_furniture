# sketchup_furniture/components/support/sides_support.rb
# Стандартная опора — шкаф стоит на боковинах

module SketchupFurniture
  module Components
    module Support
      class SidesSupport < BaseSupport
        def initialize
          super(0)
        end
        
        # Боковины начинаются с пола
        def side_start_z
          0
        end
        
        # Дно на уровне пола (+ толщина дна)
        def bottom_z
          0
        end
        
        # Боковины полной высоты
        def side_height_reduction
          0
        end
        
        def type
          :standard
        end
      end
    end
  end
end
