# sketchup_furniture/components/fronts/frame_door.rb
# Рамочная дверь — рамка из массива с филёнкой из фанеры
#
#   ┌────────────────────────┐
#   │  ┌──────────────────┐  │
#   │  │                  │  │ ← стойки (стоевые)
#   │  │     филёнка      │  │
#   │  │     (фанера)     │  │
#   │  │                  │  │
#   │  └──────────────────┘  │
#   └────────────────────────┘
#       ↑ поперечины (rails)
#
#   Паз: канал в каждом бруске рамки для филёнки
#   Шип: выступ поперечины, входящий в паз стойки
#
# Каждый брусок моделируется как 3 бокса:
#   1. Основное тело (без паза)
#   2. Передняя губа (перед пазом)
#   3. Задняя губа (за пазом)
# Это создаёт видимый паз на внутренней грани.

module SketchupFurniture
  module Components
    module Fronts
      class FrameDoor < Door
        attr_reader :frame_width, :frame_thickness, :tenon
        attr_reader :panel_gap, :panel_thickness, :groove_depth
        
        # facade_width:     ширина фасада (мм)
        # facade_height:    высота фасада (мм)
        # hinge_side:       :left или :right (сторона петель)
        # frame_width:      ширина бруска рамки (мм, по умолчанию 50)
        # frame_thickness:  толщина рамки (мм, по умолчанию из конфига или 20)
        # tenon:            длина шипа (мм, по умолчанию 10)
        # panel_gap:        зазор филёнки от паза (мм, по умолчанию 2)
        # panel_thickness:  толщина филёнки (мм, по умолчанию 6)
        # groove_depth:     глубина паза (мм, по умолчанию = tenon)
        def initialize(facade_width, facade_height, name: "Дверь рамочная",
                       hinge_side: :left,
                       frame_width: 50, frame_thickness: nil,
                       tenon: 10, panel_gap: 2, panel_thickness: 6,
                       groove_depth: nil)
          
          @frame_width = frame_width
          @frame_thickness = frame_thickness || SketchupFurniture.config.frame_thickness || 20
          @tenon = tenon
          @panel_gap = panel_gap
          @panel_thickness = panel_thickness
          @groove_depth = groove_depth || tenon
          
          # Инициализируем базовый Door
          # facade_material не нужен для рамочной, но передадим :ldsp_16 для super
          super(facade_width, facade_height,
                name: name, hinge_side: hinge_side)
          
          # Переопределяем толщину и материал — для рамочной двери это массив
          @facade_thickness = @frame_thickness
          @facade_material_name = "Массив"
          @depth = @frame_thickness  # Обновляем depth компонента
        end
        
        # === Расчётные размеры ===
        
        # Внутренний проём рамки (ширина)
        def inner_opening_width
          @facade_w - 2 * @frame_width
        end
        
        # Внутренний проём рамки (высота)
        def inner_opening_height
          @facade_h - 2 * @frame_width
        end
        
        # Ширина филёнки
        def panel_width
          inner_opening_width + 2 * (@groove_depth - @panel_gap)
        end
        
        # Высота филёнки
        def panel_height
          inner_opening_height + 2 * (@groove_depth - @panel_gap)
        end
        
        # Длина поперечины (с шипами)
        def rail_length
          inner_opening_width + 2 * @tenon
        end
        
        # Ширина паза (= толщина филёнки)
        def groove_width
          @panel_thickness
        end
        
        # Смещение паза от передней грани (центрирован)
        def groove_offset
          (@frame_thickness - @panel_thickness) / 2.0
        end
        
        protected
        
        # Переопределяем построение геометрии — переиспользуем общий модуль FrameFacade
        def build_door_panels(ox, oy, oz)
          # Дверь выступает вперёд: задняя грань рамки на oy, передняя — на oy - ft
          oy_back = oy - @frame_thickness.mm
          Fronts::FrameFacade.build(
            @group, ox, oy_back, oz, @facade_w, @facade_h, self,
            frame_width: @frame_width,
            frame_thickness: @frame_thickness,
            tenon: @tenon,
            panel_gap: @panel_gap,
            panel_thickness: @panel_thickness,
            groove_depth: @groove_depth
          )
        end
      end
    end
  end
end
