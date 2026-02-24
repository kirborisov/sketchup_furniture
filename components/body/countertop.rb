# sketchup_furniture/components/body/countertop.rb
# Столешница — горизонтальная панель поверх нижних шкафов

module SketchupFurniture
  module Components
    module Body
      class Countertop
        attr_reader :width, :depth, :thickness, :overhang
        
        # width: общая ширина (по всем нижним шкафам)
        # depth: полная глубина столешницы (включая свес)
        # thickness: толщина (28, 38мм)
        # overhang: свес спереди (мм)
        def initialize(width:, depth:, thickness: 38, overhang: 30)
          @width = width
          @depth = depth
          @thickness = thickness
          @overhang = overhang
        end
        
        # Построить геометрию
        # group: группа SketchUp
        # x, y, z: координаты (уже в единицах SketchUp)
        def build(group, x:, y:, z:)
          Primitives::Panel.horizontal(
            group,
            x: x,
            y: y - @overhang.mm,
            z: z,
            width: @width.mm,
            depth: @depth.mm,
            thickness: @thickness.mm
          )
        end
        
        # Деталь для таблицы раскроя
        def cut_item(cabinet_name = nil)
          Core::CutItem.new(
            name: "Столешница",
            length: @width,
            width: @depth,
            thickness: @thickness,
            material: "Столешница",
            cabinet: cabinet_name
          )
        end
      end
    end
  end
end
