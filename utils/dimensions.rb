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

      # Удалить размеры, попадающие в bbox (для пересборки одного шкафа)
      # bounds — Geom::BoundingBox в координатах модели (дюймы)
      def remove_dimensions_in_bounds(bounds)
        return if bounds.nil?
        margin = 12.0  # дюймов, запас (размерные линии смещены от объекта)
        bmin = bounds.min
        bmax = bounds.max
        tol = margin
        to_remove = []
        @dimension_entities.each do |dim|
          next unless dim.valid?
          next unless dim.respond_to?(:bounds)
          dmin = dim.bounds.min
          dmax = dim.bounds.max
          next unless dmin.x >= bmin.x - tol && dmax.x <= bmax.x + tol &&
                      dmin.y >= bmin.y - tol && dmax.y <= bmax.y + tol &&
                      dmin.z >= bmin.z - tol && dmax.z <= bmax.z + tol
          to_remove << dim
        end
        to_remove.each do |dim|
          dim.erase! if dim.valid?
          @dimension_entities.delete(dim)
        end
      end

      private
      
      # Габаритные размеры
      def add_overall_dimensions(entities, component)
        # Мировая позиция для размерных линий
        cx = component.respond_to?(:world_x) ? (component.world_x || 0) : (component.context&.x || 0)
        cy = component.respond_to?(:world_y) ? (component.world_y || 0) : (component.context&.y || 0)
        cz = component.respond_to?(:world_z) ? (component.world_z || 0) : (component.context&.z || 0)
        
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
      
      # Размеры секций/колонн (гардероб) или по корпусам (кухня)
      def add_section_dimensions(entities, component)
        if component.respond_to?(:lower_cabinets) && (component.lower_cabinets.any? || component.upper_cabinets.any?)
          add_kitchen_cabinet_dimensions(entities, component)
          return
        end
        return unless component.respond_to?(:columns) && component.columns.any?
        
        x = (component.respond_to?(:world_x) ? (component.world_x || 0) : (component.context&.x || 0)).mm
        y = (component.respond_to?(:world_y) ? (component.world_y || 0) : (component.context&.y || 0)).mm
        z = (component.respond_to?(:world_z) ? (component.world_z || 0) : (component.context&.z || 0)).mm
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
      
      # Размеры по корпусам кухни (нижний и верхний ряд)
      def add_kitchen_cabinet_dimensions(entities, kitchen)
        ox = (kitchen.respond_to?(:world_x) ? (kitchen.world_x || 0) : (kitchen.context&.x || 0)).mm
        oy = (kitchen.respond_to?(:world_y) ? (kitchen.world_y || 0) : (kitchen.context&.y || 0)).mm
        oz = (kitchen.respond_to?(:world_z) ? (kitchen.world_z || 0) : (kitchen.context&.z || 0)).mm
        offset = OFFSET.mm * 0.5
        
        # Нижний ряд — ширины корпусов (спереди снизу)
        x_pos = ox
        kitchen.lower_cabinets.each do |cab|
          cw = cab.width.mm
          z_low = oz
          add_dimension(entities,
            [x_pos, oy - offset, z_low],
            [x_pos + cw, oy - offset, z_low],
            [0, -offset * 0.5, -offset * 0.5]
          )
          x_pos += cw
        end
        
        # Верхний ряд — ширины корпусов (если есть)
        return unless kitchen.upper_cabinets.any?
        
        upper_z = kitchen.instance_variable_get(:@upper_z) || 1400
        y_upper = oy + (kitchen.lower_depth - kitchen.upper_depth).mm
        x_pos = ox
        kitchen.upper_cabinets.each do |cab|
          cw = cab.width.mm
          add_dimension(entities,
            [x_pos, y_upper - offset, (oz + upper_z).mm],
            [x_pos + cw, y_upper - offset, (oz + upper_z).mm],
            [0, -offset * 0.5, offset * 0.5]
          )
          x_pos += cw
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
        
        x = (cabinet.respond_to?(:world_x) ? (cabinet.world_x || 0) : (cabinet.context&.x || 0)).mm
        y = (cabinet.respond_to?(:world_y) ? (cabinet.world_y || 0) : (cabinet.context&.y || 0)).mm
        z = (cabinet.respond_to?(:world_z) ? (cabinet.world_z || 0) : (cabinet.context&.z || 0)).mm
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
