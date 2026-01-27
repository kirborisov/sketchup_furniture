# sketchup_furniture/components/drawers/slides/ball_bearing.rb
# Шариковые направляющие полного выдвижения

module SketchupFurniture
  module Components
    module Drawers
      module Slides
        class BallBearing < BaseSlide
          # Стандартные параметры шариковых направляющих
          DEFAULTS = {
            height: 35,           # высота профиля (мм)
            thickness: 13,        # толщина на сторону (мм)
            extension: :full,     # полное выдвижение
            load_capacity: 25     # нагрузка (кг)
          }.freeze
          
          def initialize(length:, soft_close: false)
            super(
              length: length,
              height: DEFAULTS[:height],
              thickness: DEFAULTS[:thickness],
              extension: DEFAULTS[:extension],
              load_capacity: DEFAULTS[:load_capacity]
            )
            @soft_close = soft_close
          end
          
          # Мягкое закрывание?
          def soft_close?
            @soft_close
          end
          
          def hardware_name
            name = "Направляющая шариковая #{@length}мм"
            name += " (плавное закрывание)" if @soft_close
            name
          end
          
          # Создать для глубины шкафа
          def self.for_depth(depth, soft_close: false)
            length = length_for_depth(depth)
            new(length: length, soft_close: soft_close)
          end
        end
      end
    end
  end
end
