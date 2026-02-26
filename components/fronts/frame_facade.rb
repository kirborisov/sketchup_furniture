# sketchup_furniture/components/fronts/frame_facade.rb
# Общая логика рамочного фасада (рамка + филёнка) для переиспользования
# в дверях (FrameDoor) и фасадах ящиков (Drawer type: :frame).
#
# cut_collector — объект с методом add_cut(name:, length:, width:, thickness:, material:)

module SketchupFurniture
  module Components
    module Fronts
      module FrameFacade
        DEFAULT_OPTS = {
          frame_width: 50,
          frame_thickness: 20,
          tenon: 10,
          panel_gap: 2,
          panel_thickness: 6,
          groove_depth: nil
        }.freeze

        # Строит геометрию рамочного фасада в group.entities и добавляет раскрой в cut_collector.
        # group — группа SketchUp (door или drawer)
        # ox, oy, oz — начало фасада в мм (для двери вызывающий передаёт oy - thickness, чтобы рамка выступала вперёд)
        # width_mm, height_mm — размеры фасада (мм)
        # cut_collector — объект с add_cut(...)
        def self.build(group, ox, oy, oz, width_mm, height_mm, cut_collector, **opts)
          opts = DEFAULT_OPTS.merge(opts)
          # Переданные nil не должны перезаписывать дефолты (merge даёт приоритет переданному)
          fw = opts[:frame_width] || DEFAULT_OPTS[:frame_width]
          ft = opts[:frame_thickness] || DEFAULT_OPTS[:frame_thickness]
          tenon = opts[:tenon] || DEFAULT_OPTS[:tenon]
          pg = opts[:panel_gap] || DEFAULT_OPTS[:panel_gap]
          pt = opts[:panel_thickness] || DEFAULT_OPTS[:panel_thickness]
          gd = (opts[:groove_depth] || tenon)
          gw = pt
          dw = width_mm
          dh = height_mm

          go = (ft - gw) / 2.0
          pi = gd - pg

          fw_su = fw.mm
          ft_su = ft.mm
          gd_su = gd.mm
          gw_su = gw.mm
          go_su = go.mm
          dw_su = dw.mm
          dh_su = dh.mm
          inner_w = dw - 2 * fw
          inner_w_su = inner_w.mm

          # ЛЕВАЯ СТОЙКА
          Primitives::Panel.side(
            group, x: ox, y: oy, z: oz,
            height: dh_su, depth: ft_su, thickness: (fw - gd).mm
          )
          Primitives::Panel.side(
            group, x: ox + (fw - gd).mm, y: oy, z: oz,
            height: dh_su, depth: go_su, thickness: gd_su
          )
          Primitives::Panel.side(
            group, x: ox + (fw - gd).mm, y: oy + go_su + gw_su, z: oz,
            height: dh_su, depth: go_su, thickness: gd_su
          )

          # ПРАВАЯ СТОЙКА
          sx = ox + dw_su - fw_su
          Primitives::Panel.side(
            group, x: sx + gd_su, y: oy, z: oz,
            height: dh_su, depth: ft_su, thickness: (fw - gd).mm
          )
          Primitives::Panel.side(
            group, x: sx, y: oy, z: oz,
            height: dh_su, depth: go_su, thickness: gd_su
          )
          Primitives::Panel.side(
            group, x: sx, y: oy + go_su + gw_su, z: oz,
            height: dh_su, depth: go_su, thickness: gd_su
          )

          # НИЖНЯЯ ПОПЕРЕЧИНА
          rail_x = ox + fw_su
          Primitives::Panel.horizontal(
            group, x: rail_x, y: oy, z: oz,
            width: inner_w_su, depth: ft_su, thickness: (fw - gd).mm
          )
          Primitives::Panel.horizontal(
            group, x: rail_x, y: oy, z: oz + (fw - gd).mm,
            width: inner_w_su, depth: go_su, thickness: gd_su
          )
          Primitives::Panel.horizontal(
            group, x: rail_x, y: oy + go_su + gw_su, z: oz + (fw - gd).mm,
            width: inner_w_su, depth: go_su, thickness: gd_su
          )

          # ВЕРХНЯЯ ПОПЕРЕЧИНА
          top_z = oz + dh_su - fw_su
          Primitives::Panel.horizontal(
            group, x: rail_x, y: oy, z: top_z + gd_su,
            width: inner_w_su, depth: ft_su, thickness: (fw - gd).mm
          )
          Primitives::Panel.horizontal(
            group, x: rail_x, y: oy, z: top_z,
            width: inner_w_su, depth: go_su, thickness: gd_su
          )
          Primitives::Panel.horizontal(
            group, x: rail_x, y: oy + go_su + gw_su, z: top_z,
            width: inner_w_su, depth: go_su, thickness: gd_su
          )

          # ФИЛЁНКА
          pw = inner_w + 2 * pi
          ph = (dh - 2 * fw) + 2 * pi
          panel_x = ox + fw_su - pi.mm
          panel_y = oy + go_su
          panel_z = oz + fw_su - pi.mm
          Primitives::Panel.back(
            group, x: panel_x, y: panel_y, z: panel_z,
            width: pw.mm, height: ph.mm, thickness: gw_su
          )

          # РАСКРОЙ
          cut_collector.add_cut(name: "Стойка рамки", length: dh, width: fw, thickness: ft, material: "Массив")
          cut_collector.add_cut(name: "Стойка рамки", length: dh, width: fw, thickness: ft, material: "Массив")
          rl = inner_w + 2 * tenon
          cut_collector.add_cut(name: "Поперечина рамки", length: rl, width: fw, thickness: ft, material: "Массив")
          cut_collector.add_cut(name: "Поперечина рамки", length: rl, width: fw, thickness: ft, material: "Массив")
          cut_collector.add_cut(name: "Филёнка", length: pw, width: ph, thickness: pt, material: "Фанера")
        end
      end
    end
  end
end
