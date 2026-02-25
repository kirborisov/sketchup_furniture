# sketchup_furniture/assemblies/cabinet.rb
# Базовый шкаф — сборка из компонентов
# Построение делегируется билдерам (assemblies/builders/)

module SketchupFurniture
  module Assemblies
    class Cabinet < Core::Component
      attr_accessor :thickness, :back_thickness
      attr_reader :shelves_config, :sections_config, :support, :drawer_objects, :door_objects
      
      PARTS = [:bottom, :top, :back, :left_side, :right_side].freeze
      
      def initialize(width, height, depth, name: "Шкаф", thickness: 18, back_thickness: 4)
        super(width, height, depth, name: name)
        @thickness = thickness
        @back_thickness = back_thickness
        
        @shelves_config = []
        @sections_config = []
        @drawers_config = []
        @drawers_positions = nil
        @drawers_options = {}
        @drawer_rows_config = []
        @drawer_objects = []
        @doors_config = nil
        @door_objects = []
        @skip_parts = []
        @stretchers_config = nil
        @support = Components::Support::SidesSupport.new
        @_building_row = nil
      end
      
      # === DSL МЕТОДЫ ===
      
      def skip(*parts)
        parts.flatten.each do |part|
          unless PARTS.include?(part)
            puts "Предупреждение: неизвестная часть '#{part}'. Доступные: #{PARTS.join(', ')}"
            next
          end
          @skip_parts << part unless @skip_parts.include?(part)
        end
        self
      end
      
      def build_part?(part)
        !@skip_parts.include?(part)
      end
      
      def shelf(z_position, adjustable: true)
        @shelves_config << { z: z_position, adjustable: adjustable }
        self
      end
      
      def shelves(*positions)
        positions.flatten.each { |z| shelf(z) }
        self
      end
      
      def sections(*widths)
        @sections_config = widths.flatten
        self
      end
      
      # === ЯЩИКИ ===
      
      def drawer(value, **opts)
        if @_building_row
          merged = @_building_row[:defaults].merge(opts)
          @_building_row[:drawers] << merged.merge(width: value)
        else
          defaults = { slide: :ball_bearing, soft_close: false, draw_slides: false,
                       back_gap: 20, box_top_inset: 20, box_bottom_inset: 20 }
          @drawers_config << defaults.merge(opts).merge(height: value)
        end
        self
      end
      
      def drawers(count_or_positions, height: nil, slide: :ball_bearing, soft_close: false, draw_slides: false, back_gap: 20, box_top_inset: 20, box_bottom_inset: 20)
        if count_or_positions.is_a?(Array)
          @drawers_positions = count_or_positions
          @drawers_options = { slide: slide, soft_close: soft_close, draw_slides: draw_slides, back_gap: back_gap,
                               box_top_inset: box_top_inset, box_bottom_inset: box_bottom_inset }
        else
          count_or_positions.times { drawer(height, slide: slide, soft_close: soft_close, draw_slides: draw_slides,
                                            back_gap: back_gap, box_top_inset: box_top_inset, box_bottom_inset: box_bottom_inset) }
        end
        self
      end
      
      def drawer_row(height:, count: nil, slide: :ball_bearing, soft_close: false, draw_slides: false,
                     back_gap: 20, box_top_inset: 20, box_bottom_inset: 20, &block)
        @_building_row = {
          height: height,
          count: count,
          defaults: { slide: slide, soft_close: soft_close, draw_slides: draw_slides, back_gap: back_gap,
                      box_top_inset: box_top_inset, box_bottom_inset: box_bottom_inset },
          drawers: []
        }
        instance_eval(&block) if block
        @drawer_rows_config << @_building_row
        @_building_row = nil
        self
      end
      
      # === ДВЕРИ ===
      
      def door(**opts)
        @doors_config = { count: 1, options: opts }
        self
      end
      
      def doors(count, **opts)
        @doors_config = { count: count, options: opts }
        self
      end
      
      # === ОПОРЫ ===
      
      def plinth(height, front_panel: false)
        @support = Components::Support::PlinthSupport.new(height, front_panel: front_panel)
        self
      end
      
      def legs(height, count: nil, adjustable: true)
        leg_count = count || Components::Support::LegsSupport.calculate_count(@width)
        @support = Components::Support::LegsSupport.new(height, count: leg_count, adjustable: adjustable)
        self
      end
      
      def stretchers(mode = :standard, width: 80)
        @stretchers_config = { mode: mode, width: width }
        skip(:top)
        self
      end
      
      def on_sides
        @support = Components::Support::SidesSupport.new
        self
      end
      
      # === ПОСТРОЕНИЕ ===
      
      def build_geometry
        t = @thickness.mm
        
        side_height = @height - @support.side_height_reduction
        bottom_offset = @support.bottom_z.mm
        inner_w_mm = @width - 2 * @thickness
        inner_d_mm = @depth - @back_thickness
        
        top_of_bottom = @support.bottom_z + @thickness
        bottom_of_top = @support.side_start_z + side_height - @thickness
        inner_h_mm = bottom_of_top - top_of_bottom
        inner_h = inner_h_mm.mm
        inner_d = inner_d_mm.mm
        
        ox = (@context&.x || 0).mm
        oy = (@context&.y || 0).mm
        oz = (@context&.z || 0).mm
        
        # Корпус (боковины, верх/дно, задник, царги)
        body = Builders::BodyBuilder.new(
          width: @width, height: @height, depth: @depth,
          thickness: @thickness, back_thickness: @back_thickness,
          support: @support, skip_parts: @skip_parts,
          cabinet_name: @name, stretchers_config: @stretchers_config
        )
        merge_result(body.build(@group, ox, oy, oz))
        
        # Секции (вертикальные перегородки)
        section_builder = Builders::SectionBuilder.new(
          sections_config: @sections_config,
          width: @width, height: @height, depth: @depth,
          thickness: @thickness, back_thickness: @back_thickness,
          support: @support, cabinet_name: @name
        )
        section_widths = section_builder.resolve_sections
        
        if @sections_config.any?
          merge_result(section_builder.build(@group, ox, oy, oz + bottom_offset + t, inner_d, inner_h))
        end
        
        # Полки
        if @shelves_config.any?
          shelf_builder = Builders::ShelfBuilder.new(
            shelves_config: @shelves_config, section_widths: section_widths,
            width: @width, depth: @depth,
            thickness: @thickness, back_thickness: @back_thickness,
            cabinet_name: @name
          )
          merge_result(shelf_builder.build(@group, ox, oy, oz + bottom_offset))
        end
        
        # Ящики
        if @drawers_config.any? || @drawers_positions
          drawer_builder = Builders::DrawerBuilder.new(
            drawers_config: @drawers_config, drawers_positions: @drawers_positions,
            drawers_options: @drawers_options,
            width: @width, height: @height, depth: @depth,
            thickness: @thickness, back_thickness: @back_thickness,
            support: @support, skip_parts: @skip_parts, cabinet_name: @name
          )
          result = drawer_builder.build(@context, inner_w_mm, inner_d_mm)
          merge_result(result)
          @drawer_objects.concat(result[:objects] || [])
        end
        
        # Ряды ящиков
        if @drawer_rows_config.any?
          row_builder = Builders::DrawerRowBuilder.new(
            drawer_rows_config: @drawer_rows_config,
            width: @width, depth: @depth,
            thickness: @thickness, back_thickness: @back_thickness,
            support: @support, skip_parts: @skip_parts, cabinet_name: @name
          )
          result = row_builder.build(@group, @context, ox, oy, oz + bottom_offset + t, inner_w_mm, inner_d_mm)
          merge_result(result)
          @drawer_objects.concat(result[:objects] || [])
        end
        
        # Двери
        if @doors_config
          door_builder = Builders::DoorBuilder.new(
            doors_config: @doors_config, width: @width,
            support: @support, cabinet_name: @name
          )
          result = door_builder.build(@context, ox, oy, oz, side_height)
          merge_result(result)
          @door_objects.concat(result[:objects] || [])
        end
        
        # Геометрия опоры
        if @support.has_geometry?
          @support.build(@group, x: ox, y: oy, z: oz, width: @width.mm, depth: @depth.mm, thickness: t)
        end
        
        # Фурнитура от опоры
        @support.hardware.each do |hw|
          add_hardware(**hw)
        end
      end
      
      private
      
      def merge_result(result)
        @cut_items.concat(result[:cut_items] || [])
        @hardware_items.concat(result[:hardware_items] || [])
      end
    end
  end
end
