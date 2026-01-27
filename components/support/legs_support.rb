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
        
        # Рисуем упрощённые ножки
        def has_geometry?
          true
        end
        
        # Построить визуализацию ножек
        def build(group, x:, y:, z:, width:, depth:, thickness:)
          entities = group.respond_to?(:entities) ? group.entities : group
          
          leg_size = 30.mm  # размер ножки 30×30мм
          h = @height.mm
          inset = 50.mm     # отступ от края
          
          # Позиции 4 ножек
          positions = [
            [x + inset, y + inset],                         # передняя левая
            [x + width - inset - leg_size, y + inset],      # передняя правая
            [x + inset, y + depth - inset - leg_size],      # задняя левая
            [x + width - inset - leg_size, y + depth - inset - leg_size]  # задняя правая
          ]
          
          # Для широких шкафов — добавляем средние ножки
          if @count >= 6
            mid_x = x + width / 2 - leg_size / 2
            positions << [mid_x, y + inset]
            positions << [mid_x, y + depth - inset - leg_size]
          end
          
          positions.each do |lx, ly|
            build_leg(entities, lx, ly, z, leg_size, h)
          end
        end
        
        private
        
        def build_leg(entities, x, y, z, size, height)
          pts = [
            [x, y, z],
            [x + size, y, z],
            [x + size, y + size, z],
            [x, y + size, z]
          ]
          face = entities.add_face(pts)
          return unless face && face.respond_to?(:pushpull)
          
          # Горизонтальная грань — проверяем направление нормали
          # Если нормаль вниз (-Z), инвертируем направление pushpull
          if face.normal.z < 0
            face.pushpull(-height)
          else
            face.pushpull(height)
          end
        end
        
        public
        
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
