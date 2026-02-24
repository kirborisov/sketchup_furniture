# sketchup_furniture/utils/dimensions.rb
# Отображение размеров на модели

module SketchupFurniture
  module Utils
    class Dimensions
      # Смещение размерных линий от объекта
      OFFSET = 200  # мм
      
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
        
        # Смещение размерной линии от объекта (в дюймах для SketchUp)
        off = OFFSET.mm
        
        # ШИРИНА (по X) — спереди снизу
        # Измеряем от левого-переднего-нижнего до правого-переднего-нижнего
        add_dimension(entities,
          [cx.mm, cy.mm, cz.mm],                    # левый-передний-нижний
          [(cx + cw).mm, cy.mm, cz.mm],             # правый-передний-нижний
          [0, -off, 0]                              # смещение вперёд (по -Y)
        )
        puts "  + Ширина: #{cw} мм"
        
        # ВЫСОТА (по Z) — слева спереди
        # Измеряем от левого-переднего-нижнего до левого-переднего-верхнего
        add_dimension(entities,
          [cx.mm, cy.mm, cz.mm],                    # левый-передний-нижний
          [cx.mm, cy.mm, (cz + ch).mm],             # левый-передний-верхний
          [-off, 0, 0]                              # смещение влево (по -X)
        )
        puts "  + Высота: #{ch} мм"
        
        # ГЛУБИНА (по Y) — слева снизу
        # Измеряем от левого-переднего-нижнего до левого-заднего-нижнего
        add_dimension(entities,
          [cx.mm, cy.mm, cz.mm],                    # левый-передний-нижний
          [cx.mm, (cy + cd).mm, cz.mm],             # левый-задний-нижний
          [-off, 0, -off]                           # смещение влево-вниз
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
          # add_dimension_linear принимает:
          # - start_pt: начальная точка измерения
          # - end_pt: конечная точка измерения  
          # - offset: вектор смещения размерной линии от объекта
          
          dim = entities.add_dimension_linear(pt1, pt2, offset_vector)
          @dimension_entities << dim if dim
          
        rescue => e
          puts "  Ошибка размера: #{e.message}"
        end
      end
    end
  end
end
