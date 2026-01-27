# sketchup_furniture/components/drawers/drawer_box.rb
# Короб ящика (без фасада и направляющих)

module SketchupFurniture
  module Components
    module Drawers
      class DrawerBox < Core::Component
        attr_reader :box_material, :bottom_material, :box_thickness, :bottom_thickness
        
        # width: внешняя ширина короба
        # height: высота короба (без фасада)
        # depth: глубина короба
        def initialize(width, height, depth, name: "Короб",
                       box_material: :plywood_10, bottom_material: :dvp_4)
          super(width, height, depth, name: name)
          
          @box_material = Materials.get(box_material) || { name: "Фанера", thickness: 10 }
          @bottom_material = Materials.get(bottom_material) || { name: "ДВП", thickness: 4 }
          @box_thickness = @box_material[:thickness]
          @bottom_thickness = @bottom_material[:thickness]
        end
        
        # Внутренние размеры короба
        def inner_width
          @width - 2 * @box_thickness
        end
        
        def inner_depth
          @depth - 2 * @box_thickness
        end
        
        def inner_height
          @height - @bottom_thickness
        end
        
        def build_geometry
          t = @box_thickness.mm
          bt = @bottom_thickness.mm
          
          ox = (@context&.x || 0).mm
          oy = (@context&.y || 0).mm
          oz = (@context&.z || 0).mm
          
          # Левая боковина
          build_side(:left, ox, oy, oz)
          
          # Правая боковина
          build_side(:right, ox + @width.mm - t, oy, oz)
          
          # Передняя стенка (между боковинами)
          build_front_back(:front, ox + t, oy, oz)
          
          # Задняя стенка (между боковинами)
          build_front_back(:back, ox + t, oy + @depth.mm - t, oz)
          
          # Дно (внутри короба, на нижнем краю)
          build_bottom(ox + t, oy + t, oz)
        end
        
        private
        
        def build_side(position, x, y, z)
          t = @box_thickness.mm
          
          # Боковина: глубина × высота × толщина
          pts = [
            [x, y, z],
            [x + t, y, z],
            [x + t, y + @depth.mm, z],
            [x, y + @depth.mm, z]
          ]
          face = @group.entities.add_face(pts)
          return unless face
          
          # Горизонтальная грань — проверяем направление нормали
          if face.normal.z < 0
            face.pushpull(-@height.mm)
          else
            face.pushpull(@height.mm)
          end
          
          add_cut(
            name: position == :left ? "Ящик боковина лев" : "Ящик боковина прав",
            length: @depth,
            width: @height,
            thickness: @box_thickness,
            material: @box_material[:name]
          )
        end
        
        def build_front_back(position, x, y, z)
          t = @box_thickness.mm
          inner_w = (@width - 2 * @box_thickness).mm
          
          # Передняя/задняя: ширина × высота × толщина
          pts = [
            [x, y, z],
            [x + inner_w, y, z],
            [x + inner_w, y + t, z],
            [x, y + t, z]
          ]
          face = @group.entities.add_face(pts)
          return unless face
          
          # Горизонтальная грань — проверяем направление нормали
          if face.normal.z < 0
            face.pushpull(-@height.mm)
          else
            face.pushpull(@height.mm)
          end
          
          add_cut(
            name: position == :front ? "Ящик передняя" : "Ящик задняя",
            length: @width - 2 * @box_thickness,
            width: @height,
            thickness: @box_thickness,
            material: @box_material[:name]
          )
        end
        
        def build_bottom(x, y, z)
          bt = @bottom_thickness.mm
          inner_w = (@width - 2 * @box_thickness).mm
          inner_d = (@depth - 2 * @box_thickness).mm
          
          # Дно: внутренняя ширина × внутренняя глубина
          pts = [
            [x, y, z],
            [x + inner_w, y, z],
            [x + inner_w, y + inner_d, z],
            [x, y + inner_d, z]
          ]
          face = @group.entities.add_face(pts)
          return unless face
          
          # Горизонтальная грань — проверяем направление нормали
          if face.normal.z < 0
            face.pushpull(-bt)
          else
            face.pushpull(bt)
          end
          
          add_cut(
            name: "Ящик дно",
            length: @width - 2 * @box_thickness,
            width: @depth - 2 * @box_thickness,
            thickness: @bottom_thickness,
            material: @bottom_material[:name]
          )
        end
      end
    end
  end
end
