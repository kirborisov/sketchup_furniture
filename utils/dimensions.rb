# sketchup_furniture/utils/dimensions.rb
# Отображение размеров на модели

module SketchupFurniture
  module Utils
    class Dimensions
      # Смещение размерных линий от объекта
      OFFSET = 100  # мм
      
      attr_reader :mode, :dimension_entities
      
      def initialize
        @mode = :off
        @dimension_entities = []
      end
      
      # Показать размеры
      # mode: :off, :overview, :sections, :detailed
      def show(component, mode = :overview)
        @mode = mode
        hide  # Убрать старые
        
        return if mode == :off
        
        puts "\n=== РАЗМЕРЫ: #{mode} ==="
        
        entities = Sketchup.active_model.active_entities
        
        case mode
        when :overview
          add_overall_dimensions(entities, component)
        when :sections
          add_overall_dimensions(entities, component)
          add_section_dimensions(entities, component)
        when :detailed
          add_overall_dimensions(entities, component)
          add_section_dimensions(entities, component)
          add_shelf_dimensions(entities, component)
        end
        
        puts "=== Создано размеров: #{@dimension_entities.length} ===\n"
      end
      
      # Убрать размеры
      def hide
        @dimension_entities.each do |dim|
          dim.erase! if dim.valid?
        end
        @dimension_entities = []
      end
      
      private
      
      # Габаритные размеры
      def add_overall_dimensions(entities, component)
        # Получаем позицию и размеры в мм
        cx = component.context&.x || 0
        cy = component.context&.y || 0
        cz = component.context&.z || 0
        
        cw = component.width
        ch = component.height
        cd = component.depth
        
        puts "  Габариты: #{cw} × #{ch} × #{cd} мм"
        puts "  Позиция: [#{cx}, #{cy}, #{cz}] мм"
        
        # Смещение размерной линии от объекта
        off = OFFSET
        
        # ШИРИНА (по X) — линия спереди, ниже объекта
        # Точки: левый-передний-нижний угол → правый-передний-нижний угол
        add_dimension(entities,
          [(cx).mm, (cy - off).mm, cz.mm],
          [(cx + cw).mm, (cy - off).mm, cz.mm],
          [0, (-off * 0.3).mm, 0]
        )
        puts "  + Ширина: #{cw} мм"
        
        # ВЫСОТА (по Z) — линия слева, перед объектом
        # Точки: левый-передний-нижний → левый-передний-верхний
        add_dimension(entities,
          [(cx - off).mm, cy.mm, cz.mm],
          [(cx - off).mm, cy.mm, (cz + ch).mm],
          [(-off * 0.3).mm, 0, 0]
        )
        puts "  + Высота: #{ch} мм"
        
        # ГЛУБИНА (по Y) — линия слева снизу
        # Точки: левый-передний-нижний → левый-задний-нижний
        add_dimension(entities,
          [(cx - off).mm, cy.mm, (cz - off * 0.5).mm],
          [(cx - off).mm, (cy + cd).mm, (cz - off * 0.5).mm],
          [(-off * 0.3).mm, 0, 0]
        )
        puts "  + Глубина: #{cd} мм"
      end
      
      # Размеры секций/колонн
      def add_section_dimensions(entities, component)
        return unless component.respond_to?(:columns) && component.columns.any?
        
        x = (component.context&.x || 0).mm
        y = (component.context&.y || 0).mm
        z = (component.context&.z || 0).mm
        h = component.height.mm
        
        offset = OFFSET.mm * 0.5
        
        # Ширины колонн
        x_pos = x
        component.columns.each do |col|
          col_w = col.width.mm
          
          add_dimension(entities,
            [x_pos, y - offset, z + h + offset],
            [x_pos + col_w, y - offset, z + h + offset],
            [0, -offset * 0.5, offset * 0.5]
          )
          
          # Высоты модулей в колонне
          if col.respond_to?(:modules)
            z_pos = z
            col.modules.each do |mod|
              mod_h = mod.height.mm
              
              add_dimension(entities,
                [x_pos + col_w + offset, y, z_pos],
                [x_pos + col_w + offset, y, z_pos + mod_h],
                [offset * 0.5, 0, 0]
              )
              
              z_pos += mod_h
            end
          end
          
          x_pos += col_w
        end
      end
      
      # Размеры полок (детальный режим)
      def add_shelf_dimensions(entities, component)
        # Для каждого шкафа показываем высоты полок
        if component.respond_to?(:columns)
          component.columns.each do |col|
            add_column_shelf_dimensions(entities, col) if col.respond_to?(:modules)
          end
        elsif component.respond_to?(:shelves_config)
          add_cabinet_shelf_dimensions(entities, component)
        end
      end
      
      def add_column_shelf_dimensions(entities, col)
        col.modules.each do |mod|
          add_cabinet_shelf_dimensions(entities, mod) if mod.respond_to?(:shelves_config)
        end
      end
      
      def add_cabinet_shelf_dimensions(entities, cabinet)
        return if cabinet.shelves_config.empty?
        
        x = (cabinet.context&.x || 0).mm
        y = (cabinet.context&.y || 0).mm
        z = (cabinet.context&.z || 0).mm
        d = cabinet.depth.mm
        
        offset = OFFSET.mm * 0.3
        support_z = cabinet.respond_to?(:support) ? cabinet.support.bottom_z.mm : 0
        
        prev_z = z + support_z
        cabinet.shelves_config.each do |shelf_cfg|
          shelf_z = z + support_z + shelf_cfg[:z].mm
          
          # Высота от предыдущего уровня до полки
          add_dimension(entities,
            [x, y + d + offset, prev_z],
            [x, y + d + offset, shelf_z],
            [0, offset * 0.5, 0]
          )
          
          prev_z = shelf_z
        end
      end
      
      # Создать размерную линию
      def add_dimension(entities, pt1, pt2, offset_vector)
        # Проверяем что точки разные
        return if pt1[0] == pt2[0] && pt1[1] == pt2[1] && pt1[2] == pt2[2]
        
        begin
          p1 = pt1.is_a?(Array) ? pt1 : pt1.to_a
          p2 = pt2.is_a?(Array) ? pt2 : pt2.to_a
          
          # Вектор смещения для размерной линии
          offset_pt = [
            (p1[0] + p2[0]) / 2.0 + offset_vector[0],
            (p1[1] + p2[1]) / 2.0 + offset_vector[1],
            (p1[2] + p2[2]) / 2.0 + offset_vector[2]
          ]
          
          dim = entities.add_dimension_linear(p1, p2, offset_pt)
          @dimension_entities << dim if dim
          
        rescue => e
          puts "  Ошибка размера: #{e.message}"
        end
      end
    end
  end
end
