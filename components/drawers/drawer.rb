# sketchup_furniture/components/drawers/drawer.rb
# Полный ящик: короб + направляющие + фасад

module SketchupFurniture
  module Components
    module Drawers
      class Drawer < Core::Component
        attr_reader :box, :slide, :facade_thickness, :facade_gap, :back_gap
        attr_reader :box_height, :slide_type
        
        # height: полная высота ящика (включая зазоры)
        # cabinet_width: внутренняя ширина шкафа (для расчёта ширины короба)
        # cabinet_depth: глубина шкафа (для выбора направляющих)
        def initialize(height, cabinet_width:, cabinet_depth:, name: "Ящик",
                       slide_type: :ball_bearing, soft_close: false,
                       facade_material: :ldsp_16, facade_gap: nil,
                       box_material: :plywood_10, bottom_material: :dvp_4,
                       draw_slides: false, back_gap: 20,
                       facade_width: nil, facade_height: nil,
                       facade_x_offset: 0, facade_z_offset: 0)
          
          @slide_type = slide_type
          @facade_gap = facade_gap || SketchupFurniture.config.facade_gap || 3
          @draw_slides = draw_slides
          @soft_close = soft_close
          @back_gap = back_gap
          @facade_width = facade_width
          @facade_height = facade_height
          @facade_x_offset = facade_x_offset
          @facade_z_offset = facade_z_offset
          
          # Создаём направляющую
          @slide = create_slide(cabinet_depth, slide_type, soft_close)
          
          # Материал фасада
          facade_mat = Materials.get(facade_material) || { name: "ЛДСП", thickness: 16 }
          @facade_thickness = facade_mat[:thickness]
          @facade_material_name = facade_mat[:name]
          
          # Расчёт размеров короба
          box_width = cabinet_width - @slide.width_reduction
          box_depth = @slide.length - @back_gap
          @box_height = height - @slide.height - @facade_gap
          
          # Полные размеры (с фасадом)
          super(cabinet_width, height, cabinet_depth, name: name)
          
          # Создаём короб
          @box = DrawerBox.new(
            box_width, @box_height, box_depth,
            name: "#{name} короб",
            box_material: box_material,
            bottom_material: bottom_material
          )
          
          # Позиция открытия (для анимации)
          @open_position = 0
        end
        
        # Создать направляющую по типу
        def create_slide(depth, type, soft_close)
          case type
          when :ball_bearing
            Slides::BallBearing.for_depth(depth, soft_close: soft_close)
          else
            Slides::BallBearing.for_depth(depth, soft_close: soft_close)
          end
        end
        
        def build_geometry
          ox = (@context&.x || 0).mm
          oy = (@context&.y || 0).mm
          oz = (@context&.z || 0).mm
          
          slide_offset = @slide.thickness.mm
          slide_height = @slide.height.mm
          
          # Сохраняем ссылку на entities ДО создания дочерних групп
          drawer_entities = @group.entities
          
          # Фасад (накладной, спереди) - строим ПЕРВЫМ
          build_facade(drawer_entities, ox, oy, oz)
          
          # Направляющие (если включено)
          build_slides(drawer_entities, ox, oy, oz) if @draw_slides
          
          # Короб выше направляющих
          # dx: отступ для направляющей слева
          # dz: короб стоит НА направляющих, поэтому выше на их высоту
          # ВАЖНО: передаём группу ящика как родителя, чтобы короб был внутри!
          box_context = Core::Context.new(
            x: @context.x + @slide.thickness,
            y: @context.y,
            z: @context.z + @slide.height,
            parent: @group  # <- короб создаётся ВНУТРИ группы ящика
          )
          @box.build(box_context)
          
          # Собираем детали раскроя от короба
          @cut_items.concat(@box.cut_items)
          
          # Фурнитура: направляющие
          add_hardware(**@slide.hardware_entry)
          
          # Регистрация для двойного клика
          Tools::DrawerTool.register(@group, self)
        end
        
        private
        
        def build_facade(entities, ox, oy, oz)
          fw_mm = @facade_width || @width
          fh_mm = @facade_height || (@height - @facade_gap)
          facade_w = fw_mm.mm
          facade_h = fh_mm.mm
          facade_t = @facade_thickness.mm
          
          # Смещение фасада (для покрытия перегородок/полок)
          fx = ox - @facade_x_offset.mm
          fz = oz - @facade_z_offset.mm
          
          pts = [
            [fx, oy, fz],
            [fx + facade_w, oy, fz],
            [fx + facade_w, oy, fz + facade_h],
            [fx, oy, fz + facade_h]
          ]
          face = entities.add_face(pts)
          return unless face
          
          if face.normal.y > 0
            face.pushpull(-facade_t)
          else
            face.pushpull(facade_t)
          end
          
          add_cut(
            name: "Фасад ящика",
            length: fw_mm,
            width: fh_mm,
            thickness: @facade_thickness,
            material: @facade_material_name
          )
        end
        
        def build_slides(entities, ox, oy, oz)
          # Упрощённое представление направляющих
          slide_w = 3.mm  # визуальная ширина
          slide_h = @slide.height.mm
          slide_l = @slide.length.mm
          t = @slide.thickness.mm
          
          # Левая направляющая
          build_slide_geometry(entities, ox, oy, oz, slide_w, slide_h, slide_l)
          
          # Правая направляющая
          build_slide_geometry(entities, ox + @width.mm - t, oy, oz, slide_w, slide_h, slide_l)
        end
        
        def build_slide_geometry(entities, x, y, z, w, h, l)
          pts = [
            [x, y, z],
            [x + w, y, z],
            [x + w, y + l, z],
            [x, y + l, z]
          ]
          face = entities.add_face(pts)
          return unless face
          
          # Горизонтальная грань — проверяем направление нормали
          if face.normal.z < 0
            face.pushpull(-h)
          else
            face.pushpull(h)
          end
        end
        
        public
        
        # === АНИМАЦИЯ ===
        
        # Открыть ящик
        def open(amount = nil)
          amount ||= @slide.length
          move_drawer(amount)
        end
        
        # Закрыть ящик
        def close
          move_drawer(0)
        end
        
        # Переместить ящик
        def move_drawer(y_offset)
          return unless @group
          
          delta = y_offset - @open_position
          return if delta == 0
          
          vector = Geom::Vector3d.new(0, -delta.mm, 0)
          transform = Geom::Transformation.translation(vector)
          @group.transform!(transform)
          
          @open_position = y_offset
        end
        
        def open?
          @open_position > 0
        end
      end
    end
  end
end
