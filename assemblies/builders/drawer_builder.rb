# sketchup_furniture/assemblies/builders/drawer_builder.rb
# Построение обычных ящиков (одна колонка)

module SketchupFurniture
  module Assemblies
    module Builders
      class DrawerBuilder
        def initialize(drawers_config:, drawers_positions:, drawers_options:,
                       width:, height:, depth:, thickness:, back_thickness:,
                       support:, skip_parts:, cabinet_name:)
          @drawers_config = drawers_config
          @drawers_positions = drawers_positions
          @drawers_options = drawers_options
          @width = width
          @height = height
          @depth = depth
          @thickness = thickness
          @back_thickness = back_thickness
          @support = support
          @skip_parts = skip_parts
          @cabinet_name = cabinet_name
        end

        def build(context, inner_w_mm, inner_d_mm)
          resolve_drawer_positions if @drawers_positions
          return { cut_items: [], hardware_items: [], objects: [] } if @drawers_config.empty?

          cut_items = []
          hardware_items = []
          objects = []

          facade_gap = SketchupFurniture.config.facade_gap || 3
          facade_w = @width - facade_gap
          facade_x_off = @thickness - facade_gap / 2.0

          start_z = if !@skip_parts.include?(:bottom)
            @support.bottom_z + @thickness
          else
            @support.bottom_z
          end

          @drawers_config.each_with_index do |cfg, i|
            drawer = Components::Drawers::Drawer.new(
              cfg[:height],
              cabinet_width: inner_w_mm,
              cabinet_depth: @depth - @back_thickness,
              name: "#{@cabinet_name} ящик #{i + 1}",
              slide_type: cfg[:slide],
              soft_close: cfg[:soft_close],
              draw_slides: cfg[:draw_slides],
              back_gap: cfg[:back_gap] || 20,
              facade_gap: facade_gap,
              facade_width: facade_w,
              facade_x_offset: facade_x_off,
              box_top_inset: cfg[:box_top_inset] || 20,
              box_bottom_inset: cfg[:box_bottom_inset] || 20
            )

            drawer_context = context.offset(
              dx: @thickness,
              dy: 0,
              dz: start_z + drawer_z_offset(i)
            )

            drawer.build(drawer_context)

            cut_items.concat(drawer.all_cut_items)
            hardware_items.concat(drawer.all_hardware_items)
            objects << drawer
          end

          { cut_items: cut_items, hardware_items: hardware_items, objects: objects }
        end

        private

        def drawer_z_offset(index)
          if @drawers_config[index] && @drawers_config[index][:z_offset]
            @drawers_config[index][:z_offset]
          else
            @drawers_config[0...index].sum { |cfg| cfg[:height] }
          end
        end

        def resolve_drawer_positions
          positions = @drawers_positions
          opts = @drawers_options

          side_height = @height - @support.side_height_reduction
          top_of_bottom = @support.bottom_z + @thickness
          bottom_of_top = @support.side_start_z + side_height - @thickness
          inner_h = bottom_of_top - top_of_bottom

          positions.each_with_index do |pos, i|
            h = if i < positions.length - 1
              positions[i + 1] - pos
            else
              inner_h - pos
            end

            @drawers_config << {
              height: h, z_offset: pos,
              slide: opts[:slide], soft_close: opts[:soft_close],
              draw_slides: opts[:draw_slides],
              back_gap: opts[:back_gap] || 20,
              box_top_inset: opts[:box_top_inset] || 20,
              box_bottom_inset: opts[:box_bottom_inset] || 20
            }
          end

          @drawers_positions = nil
        end
      end
    end
  end
end
