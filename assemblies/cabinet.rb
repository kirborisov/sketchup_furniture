# furniture/assemblies/cabinet.rb
# Базовый шкаф — сборка из компонентов

module SketchupFurniture
  module Assemblies
    class Cabinet < Core::Component
      attr_accessor :thickness, :back_thickness
      attr_reader :shelves_config, :sections_config
      
      def initialize(width, height, depth, name: "Шкаф", thickness: 18, back_thickness: 4)
        super(width, height, depth, name: name)
        @thickness = thickness
        @back_thickness = back_thickness
        
        @shelves_config = []
        @sections_config = []
        @has_back = true
      end
      
      # === DSL МЕТОДЫ ===
      
      # Добавить полку
      def shelf(z_position, adjustable: true)
        @shelves_config << { z: z_position, adjustable: adjustable }
        self
      end
      
      # Добавить несколько полок
      def shelves(*positions)
        positions.flatten.each { |z| shelf(z) }
        self
      end
      
      # Задать секции (вертикальные перегородки)
      def sections(*widths)
        @sections_config = widths.flatten
        self
      end
      
      # Без задней стенки
      def no_back
        @has_back = false
        self
      end
      
      # === ПОСТРОЕНИЕ ===
      
      def build_geometry
        t = @thickness.mm
        bt = @back_thickness.mm
        
        # Внутренние размеры (в мм)
        inner_w_mm = @width - 2 * @thickness
        inner_d_mm = @depth - @back_thickness
        inner_h_mm = @height - 2 * @thickness
        
        # Внутренние размеры (конвертированы для SketchUp)
        inner_w = inner_w_mm.mm
        inner_d = inner_d_mm.mm
        inner_h = inner_h_mm.mm
        
        # Позиция
        ox = (@context&.x || 0).mm
        oy = (@context&.y || 0).mm
        oz = (@context&.z || 0).mm
        
        # Левая боковина
        build_side(:left, ox, oy, oz, inner_d)
        
        # Правая боковина
        build_side(:right, ox + @width.mm - t, oy, oz, inner_d)
        
        # Дно
        build_horizontal(:bottom, ox + t, oy, oz, inner_w, inner_d)
        
        # Верх
        build_horizontal(:top, ox + t, oy, oz + @height.mm - t, inner_w, inner_d)
        
        # Задняя стенка
        build_back(ox, oy + inner_d, oz) if @has_back
        
        # Секции (перегородки)
        build_sections(ox, oy, oz, inner_d, inner_h) if @sections_config.any?
        
        # Полки
        build_shelves(ox, oy, oz, inner_w, inner_d)
      end
      
      private
      
      def build_side(position, x, y, z, depth)
        Primitives::Panel.side(
          @group, x: x, y: y, z: z,
          height: @height.mm,
          depth: depth,
          thickness: @thickness.mm
        )
        
        add_cut(
          name: position == :left ? "Боковина левая" : "Боковина правая",
          length: @height,
          width: @depth - @back_thickness,
          thickness: @thickness,
          material: "ЛДСП"
        )
      end
      
      def build_horizontal(position, x, y, z, width, depth)
        Primitives::Panel.horizontal(
          @group, x: x, y: y, z: z,
          width: width,
          depth: depth,
          thickness: @thickness.mm
        )
        
        add_cut(
          name: position == :top ? "Верх" : "Дно",
          length: @width - 2 * @thickness,
          width: @depth - @back_thickness,
          thickness: @thickness,
          material: "ЛДСП"
        )
      end
      
      def build_back(x, y, z)
        Primitives::Panel.back(
          @group, x: x, y: y, z: z,
          width: @width.mm,
          height: @height.mm,
          thickness: @back_thickness.mm
        )
        
        add_cut(
          name: "Задняя стенка",
          length: @height,
          width: @width,
          thickness: @back_thickness,
          material: "ДВП"
        )
      end
      
      def build_sections(ox, oy, oz, inner_d, inner_h)
        t = @thickness.mm
        panel_depth = @depth - @back_thickness
        panel_height = @height - 2 * @thickness
        
        # Вычисляем реальные ширины секций
        section_widths = resolve_sections
        
        x_pos = ox + t
        section_widths[0..-2].each_with_index do |sec_w, i|
          x_pos += sec_w.mm
          
          Primitives::Panel.side(
            @group, x: x_pos, y: oy, z: oz + t,
            height: inner_h,
            depth: inner_d,
            thickness: t
          )
          
          add_cut(
            name: "Перегородка #{i + 1}",
            length: panel_height,
            width: panel_depth,
            thickness: @thickness,
            material: "ЛДСП"
          )
          
          x_pos += t
        end
      end
      
      def build_shelves(ox, oy, oz, inner_w, inner_d)
        t = @thickness.mm
        section_widths = resolve_sections
        
        if section_widths.empty?
          # Одна секция на всю ширину
          @shelves_config.each_with_index do |shelf_cfg, i|
            build_shelf(ox + t, oy, oz + shelf_cfg[:z].mm, inner_w, inner_d, i + 1, 1)
          end
        else
          # Несколько секций
          x_pos = ox + t
          section_widths.each_with_index do |sec_w, sec_i|
            @shelves_config.each_with_index do |shelf_cfg, shi|
              build_shelf(x_pos, oy, oz + shelf_cfg[:z].mm, sec_w.mm, inner_d, shi + 1, sec_i + 1)
            end
            x_pos += sec_w.mm + t
          end
        end
      end
      
      def build_shelf(x, y, z, width, depth, shelf_num, section_num)
        Primitives::Panel.horizontal(
          @group, x: x, y: y, z: z,
          width: width,
          depth: depth,
          thickness: @thickness.mm
        )
        
        shelf_w = (width / 1.mm).round
        add_cut(
          name: "Полка #{section_num}-#{shelf_num}",
          length: shelf_w,
          width: @depth - @back_thickness,
          thickness: @thickness,
          material: "ЛДСП"
        )
        
        add_hardware(type: :shelf_support, quantity: 4)
      end
      
      # Преобразовать проценты в реальные ширины
      def resolve_sections
        return [] if @sections_config.empty?
        
        inner_w = @width - 2 * @thickness
        num_partitions = @sections_config.length - 1
        partitions_w = num_partitions * @thickness
        available_w = inner_w - partitions_w
        
        @sections_config.map do |sec|
          if sec.is_a?(String) && sec.end_with?("%")
            percent = sec.to_f
            (available_w * percent / 100.0).round
          else
            sec.to_i
          end
        end
      end
    end
  end
end
