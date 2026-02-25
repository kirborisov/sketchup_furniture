# sketchup_furniture/components/fronts/door.rb
# Дверь шкафа (фасад с вращением по петельной стороне)

module SketchupFurniture
  module Components
    module Fronts
      class Door < Core::Component
        attr_reader :facade_thickness, :facade_gap, :hinge_side
        
        # facade_width: ширина фасада (мм)
        # facade_height: высота фасада (мм)
        # hinge_side: :left или :right (сторона петель)
        # facade_material: материал фасада
        def initialize(facade_width, facade_height, name: "Дверь",
                       facade_material: :ldsp_16, hinge_side: :left)
          
          facade_mat = Materials.get(facade_material) || { name: "ЛДСП", thickness: 16 }
          @facade_thickness = facade_mat[:thickness]
          @facade_material_name = facade_mat[:name]
          @hinge_side = hinge_side
          @facade_w = facade_width
          @facade_h = facade_height
          
          super(facade_width, facade_height, facade_mat[:thickness], name: name)
          
          @open_angle = 0
        end
        
        def build_geometry
          ox = (@context&.x || 0).mm
          oy = (@context&.y || 0).mm
          oz = (@context&.z || 0).mm
          
          entities = @group.entities
          
          facade_w = @facade_w.mm
          facade_h = @facade_h.mm
          facade_t = @facade_thickness.mm
          
          pts = [
            [ox, oy, oz],
            [ox + facade_w, oy, oz],
            [ox + facade_w, oy, oz + facade_h],
            [ox, oy, oz + facade_h]
          ]
          face = entities.add_face(pts)
          if face
            if face.normal.y > 0
              face.pushpull(-facade_t)
            else
              face.pushpull(facade_t)
            end
          end
          
          add_cut(
            name: "Фасад",
            length: @facade_w,
            width: @facade_h,
            thickness: @facade_thickness,
            material: @facade_material_name
          )
          
          # Запоминаем точку вращения (петельная сторона)
          @pivot_x = @hinge_side == :left ? ox : (ox + facade_w)
          @pivot_y = oy
          @pivot_z = oz
          
          # Регистрация для двойного клика
          Tools::DrawerTool.register(@group, self)
        end
        
        # === АНИМАЦИЯ ===
        
        # Открыть дверь (угол в градусах)
        def open(angle = nil)
          angle ||= 90
          rotate_door(angle)
        end
        
        # Закрыть дверь
        def close
          rotate_door(0)
        end
        
        # Открыта ли дверь
        def open?
          @open_angle != 0
        end
        
        private
        
        def rotate_door(target_angle)
          return unless @group
          
          delta = target_angle - @open_angle
          return if delta == 0
          
          angle_rad = delta * Math::PI / 180.0
          
          # Точка вращения: петельная сторона, передний край
          pivot = Geom::Point3d.new(@pivot_x, @pivot_y, @pivot_z)
          axis = Geom::Vector3d.new(0, 0, 1)
          
          # Левая петля: по часовой (сверху) → -angle, дверь уходит наружу (-Y)
          # Правая петля: против часовой → +angle, дверь уходит наружу (-Y)
          actual_angle = @hinge_side == :left ? -angle_rad : angle_rad
          
          transform = Geom::Transformation.rotation(pivot, axis, actual_angle)
          @group.transform!(transform)
          
          @open_angle = target_angle
        end
      end
    end
  end
end
