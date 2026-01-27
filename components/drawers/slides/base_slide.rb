# sketchup_furniture/components/drawers/slides/base_slide.rb
# Базовый класс для направляющих ящика

module SketchupFurniture
  module Components
    module Drawers
      module Slides
        class BaseSlide
          attr_reader :length, :height, :thickness, :extension, :load_capacity
          
          # length: длина направляющей (мм)
          # height: высота профиля (мм)  
          # thickness: толщина на одну сторону (мм)
          # extension: :full или :partial
          # load_capacity: нагрузка (кг)
          def initialize(length:, height:, thickness:, extension: :full, load_capacity: 25)
            @length = length
            @height = height
            @thickness = thickness
            @extension = extension
            @load_capacity = load_capacity
          end
          
          # Насколько уменьшается ширина ящика (обе стороны)
          def width_reduction
            @thickness * 2
          end
          
          # Стандартные длины направляющих
          def self.standard_lengths
            [250, 300, 350, 400, 450, 500, 550]
          end
          
          # Подобрать длину под глубину шкафа
          def self.length_for_depth(depth, clearance: 50)
            target = depth - clearance
            standard_lengths.select { |l| l <= target }.max || standard_lengths.min
          end
          
          # Тип для фурнитуры
          def type
            :drawer_slide
          end
          
          # Название для списка фурнитуры
          def hardware_name
            "Направляющая #{@length}мм"
          end
          
          # Запись в список фурнитуры (1 комплект = 2 направляющих)
          def hardware_entry
            {
              type: type,
              name: hardware_name,
              quantity: 1,  # 1 комплект на ящик
              specs: {
                length: @length,
                height: @height,
                extension: @extension,
                load_capacity: @load_capacity
              }
            }
          end
        end
      end
    end
  end
end
