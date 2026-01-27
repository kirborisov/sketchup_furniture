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
        x = (component.context&.x || 0).mm
        y = (component.context&.y || 0).mm
        z = (component.context&.z || 0).mm
        
        w = component.width.mm
        h = component.height.mm
        d = component.depth.mm
        
        offset = OFFSET.mm
        
        # Ширина (по X, снизу)
        add_dimension(entities,
          [x, y - offset, z],
          [x + w, y - offset, z],
          [0, -offset, 0]
        )
        
        # Высота (по Z, слева)
        add_dimension(entities,
          [x - offset, y, z],
          [x - offset, y, z + h],
          [-offset, 0, 0]
        )
        
        # Глубина (по Y, снизу слева)
        add_dimension(entities,
          [x - offset, y, z],
          [x - offset, y + d, z],
          [-offset, 0, 0]
        )
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
        begin
          # Точка для смещения размерной линии
          offset_pt = Geom::Point3d.new(
            (pt1[0] + pt2[0]) / 2.0 + offset_vector[0],
            (pt1[1] + pt2[1]) / 2.0 + offset_vector[1],
            (pt1[2] + pt2[2]) / 2.0 + offset_vector[2]
          )
          
          dim = entities.add_dimension_linear(
            Geom::Point3d.new(*pt1),
            Geom::Point3d.new(*pt2),
            offset_pt
          )
          
          @dimension_entities << dim if dim
        rescue => e
          # Игнорируем ошибки (могут быть если точки совпадают)
          puts "Dimension error: #{e.message}" if $DEBUG
        end
      end
    end
  end
end
