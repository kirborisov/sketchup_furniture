# sketchup_furniture/components/support/legs_support.rb
# Ножки — боковины короче, шкаф на ножках

module SketchupFurniture
  module Components
    module Support
      class LegsSupport < BaseSupport
        attr_reader :count, :adjustable
        
        def initialize(height = 100, count: 4, adjustable: true)
          super(height)
          @count = count
          @adjustable = adjustable
        end
        
        # Боковины начинаются выше пола
        def side_start_z
          @height
        end
        
        # Дно тоже поднято
        def bottom_z
          @height
        end
        
        # Боковины короче на высоту ножек
        def side_height_reduction
          @height
        end
        
        # Ножки не рисуем (только фурнитура)
        def has_geometry?
          false
        end
        
        def hardware
          leg_name = @adjustable ? "Ножка регулируемая" : "Ножка"
          [{
            type: :leg,
            name: "#{leg_name} #{@height}мм",
            quantity: @count
          }]
        end
        
        def type
          :legs
        end
        
        # Рассчитать количество ножек для ширины шкафа
        def self.calculate_count(width)
          if width > 800
            6  # 3 спереди, 3 сзади
          else
            4  # 2 спереди, 2 сзади
          end
        end
      end
    end
  end
end
