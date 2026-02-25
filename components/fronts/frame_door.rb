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
        
        # Переопределяем построение геометрии
        def build_door_panels(ox, oy, oz)
          fw = @frame_width         # ширина бруска (мм)
          ft = @frame_thickness     # толщина рамки (мм)
          gd = @groove_depth        # глубина паза (мм)
          gw = @panel_thickness     # ширина паза = толщина филёнки (мм)
          pg = @panel_gap           # зазор филёнки (мм)
          dw = @facade_w            # ширина двери (мм)
          dh = @facade_h            # высота двери (мм)
          
          go = (ft - gw) / 2.0     # смещение паза от передней грани
          pi = gd - pg             # на сколько филёнка входит в паз
          
          # Конвертация в единицы SketchUp
          fw_su = fw.mm
          ft_su = ft.mm
          gd_su = gd.mm
          gw_su = gw.mm
          go_su = go.mm
          dw_su = dw.mm
          dh_su = dh.mm
          
          inner_w = dw - 2 * fw     # проём ширина (мм)
          inner_w_su = inner_w.mm
          
          # ─── ЛЕВАЯ СТОЙКА (паз на правой/внутренней грани) ───
          # Тело (от внешнего края до начала паза)
          Primitives::Panel.side(
            @group, x: ox, y: oy, z: oz,
            height: dh_su, depth: ft_su, thickness: (fw - gd).mm
          )
          # Передняя губа паза
          Primitives::Panel.side(
            @group, x: ox + (fw - gd).mm, y: oy, z: oz,
            height: dh_su, depth: go_su, thickness: gd_su
          )
          # Задняя губа паза
          Primitives::Panel.side(
            @group, x: ox + (fw - gd).mm, y: oy + go_su + gw_su, z: oz,
            height: dh_su, depth: go_su, thickness: gd_su
          )
          
          # ─── ПРАВАЯ СТОЙКА (паз на левой/внутренней грани) ───
          sx = ox + dw_su - fw_su
          # Тело (от конца паза до внешнего края)
          Primitives::Panel.side(
            @group, x: sx + gd_su, y: oy, z: oz,
            height: dh_su, depth: ft_su, thickness: (fw - gd).mm
          )
          # Передняя губа паза
          Primitives::Panel.side(
            @group, x: sx, y: oy, z: oz,
            height: dh_su, depth: go_su, thickness: gd_su
          )
          # Задняя губа паза
          Primitives::Panel.side(
            @group, x: sx, y: oy + go_su + gw_su, z: oz,
            height: dh_su, depth: go_su, thickness: gd_su
          )
          
          # ─── НИЖНЯЯ ПОПЕРЕЧИНА (паз сверху/на внутренней грани) ───
          rail_x = ox + fw_su
          # Тело (от низа до начала паза)
          Primitives::Panel.horizontal(
            @group, x: rail_x, y: oy, z: oz,
            width: inner_w_su, depth: ft_su, thickness: (fw - gd).mm
          )
          # Передняя губа паза
          Primitives::Panel.horizontal(
            @group, x: rail_x, y: oy, z: oz + (fw - gd).mm,
            width: inner_w_su, depth: go_su, thickness: gd_su
          )
          # Задняя губа паза
          Primitives::Panel.horizontal(
            @group, x: rail_x, y: oy + go_su + gw_su, z: oz + (fw - gd).mm,
            width: inner_w_su, depth: go_su, thickness: gd_su
          )
          
          # ─── ВЕРХНЯЯ ПОПЕРЕЧИНА (паз снизу/на внутренней грани) ───
          top_z = oz + dh_su - fw_su
          # Тело (от конца паза до верха)
          Primitives::Panel.horizontal(
            @group, x: rail_x, y: oy, z: top_z + gd_su,
            width: inner_w_su, depth: ft_su, thickness: (fw - gd).mm
          )
          # Передняя губа паза
          Primitives::Panel.horizontal(
            @group, x: rail_x, y: oy, z: top_z,
            width: inner_w_su, depth: go_su, thickness: gd_su
          )
          # Задняя губа паза
          Primitives::Panel.horizontal(
            @group, x: rail_x, y: oy + go_su + gw_su, z: top_z,
            width: inner_w_su, depth: go_su, thickness: gd_su
          )
          
          # ─── ФИЛЁНКА (фанера, в пазах) ───
          pw = inner_w + 2 * pi     # ширина филёнки (мм)
          ph = (dh - 2 * fw) + 2 * pi  # высота филёнки (мм)
          
          panel_x = ox + fw_su - pi.mm
          panel_y = oy + go_su
          panel_z = oz + fw_su - pi.mm
          
          Primitives::Panel.back(
            @group, x: panel_x, y: panel_y, z: panel_z,
            width: pw.mm, height: ph.mm, thickness: gw_su
          )
          
          # ─── РАСКРОЙ ───
          # 2 стойки (массив)
          add_cut(
            name: "Стойка рамки",
            length: dh, width: fw, thickness: ft,
            material: "Массив"
          )
          add_cut(
            name: "Стойка рамки",
            length: dh, width: fw, thickness: ft,
            material: "Массив"
          )
          
          # 2 поперечины (массив, длина включает шипы)
          rl = inner_w + 2 * @tenon
          add_cut(
            name: "Поперечина рамки",
            length: rl, width: fw, thickness: ft,
            material: "Массив"
          )
          add_cut(
            name: "Поперечина рамки",
            length: rl, width: fw, thickness: ft,
            material: "Массив"
          )
          
          # 1 филёнка (фанера)
          add_cut(
            name: "Филёнка",
            length: pw, width: ph, thickness: @panel_thickness,
            material: "Фанера"
          )
        end
      end
    end
  end
end
