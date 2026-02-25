# sketchup_furniture/assemblies/builders/drawer_row_builder.rb
# Построение рядов ящиков (несколько ящиков по горизонтали)
# Автоматически строит перегородки и полки между рядами

module SketchupFurniture
  module Assemblies
    module Builders
      class DrawerRowBuilder
        def initialize(drawer_rows_config:, width:, depth:, thickness:, back_thickness:,
                       support:, skip_parts:, cabinet_name:)
          @drawer_rows_config = drawer_rows_config
          @width = width
          @depth = depth
          @thickness = thickness
          @back_thickness = back_thickness
          @support = support
          @skip_parts = skip_parts
          @cabinet_name = cabinet_name
        end

        def build(group, context, ox, oy, oz, inner_w_mm, inner_d_mm)
          t = @thickness
          t_su = t.mm
          inner_d_su = inner_d_mm.mm
          facade_gap = SketchupFurniture.config.facade_gap || 3
          num_rows = @drawer_rows_config.length

          cut_items = []
          hardware_items = []
          objects = []

          @drawer_rows_config.each { |row| resolve_row_drawers(row, inner_w_mm) }

          row_partitions = @drawer_rows_config.map { |row| [row[:drawers].length - 1, 0].max }

          panels_between = (0...num_rows - 1).map { |i| row_partitions[i] > 0 || row_partitions[i + 1] > 0 }
          need_top_shelf = !build_part?(:top) && row_partitions[-1] > 0

          # Facade heights (proportional distribution)
          total_h = @drawer_rows_config.sum { |r| r[:height] }
          panels_between.each { |p| total_h += t if p }
          sum_row_h = @drawer_rows_config.sum { |r| r[:height] }.to_f
          total_facade_h = total_h - num_rows * facade_gap

          facade_heights = @drawer_rows_config.map { |r| (r[:height] / sum_row_h * total_facade_h).round }
          facade_heights[-1] = total_facade_h - facade_heights[0..-2].sum

          # Facade Z offsets
          facade_z_offsets = []
          acc_facade_z = 0
          acc_box_z = 0
          @drawer_rows_config.each_with_index do |row, i|
            facade_z_offsets[i] = acc_box_z - acc_facade_z
            acc_facade_z += facade_heights[i] + facade_gap
            acc_box_z += row[:height]
            acc_box_z += t if i < num_rows - 1 && panels_between[i]
          end

          current_z = 0

          @drawer_rows_config.each_with_index do |row, row_i|
            row_height = row[:height]
            row_drawers = row[:drawers]
            num_drawers = row_drawers.length

            total_facade_w = @width - num_drawers * facade_gap
            column_widths = row_drawers.map { |d| d[:width] }
            sum_col_w = column_widths.sum.to_f

            facade_widths = column_widths.map { |cw| (cw / sum_col_w * total_facade_w).round }
            facade_widths[-1] = total_facade_w - facade_widths[0..-2].sum

            facade_x_offsets = []
            box_x_abs = t.to_f
            facade_x_abs = facade_gap / 2.0
            row_drawers.each_with_index do |dcfg, di|
              facade_x_offsets << (box_x_abs - facade_x_abs)
              box_x_abs += dcfg[:width]
              facade_x_abs += facade_widths[di]
              if di < num_drawers - 1
                box_x_abs += t
                facade_x_abs += facade_gap
              end
            end

            current_x = 0
            row_drawers.each_with_index do |dcfg, di|
              d = Components::Drawers::Drawer.new(
                row_height,
                cabinet_width: dcfg[:width],
                cabinet_depth: @depth - @back_thickness,
                name: "#{@cabinet_name} ящик #{row_i + 1}-#{di + 1}",
                slide_type: dcfg[:slide],
                soft_close: dcfg[:soft_close],
                draw_slides: dcfg[:draw_slides],
                back_gap: dcfg[:back_gap] || 20,
                facade_gap: facade_gap,
                facade_width: facade_widths[di],
                facade_height: facade_heights[row_i],
                facade_x_offset: facade_x_offsets[di],
                facade_z_offset: facade_z_offsets[row_i],
                box_top_inset: dcfg[:box_top_inset] || 20,
                box_bottom_inset: dcfg[:box_bottom_inset] || 20
              )

              drawer_context = context.offset(
                dx: t + current_x,
                dy: 0,
                dz: (@support.bottom_z + t) + current_z
              )

              d.build(drawer_context)

              cut_items.concat(d.all_cut_items)
              hardware_items.concat(d.all_hardware_items)
              objects << d

              current_x += dcfg[:width]

              if di < num_drawers - 1
                Primitives::Panel.side(
                  group,
                  x: ox + t_su + current_x.mm, y: oy, z: oz + current_z.mm,
                  height: row_height.mm, depth: inner_d_su, thickness: t_su
                )

                cut_items << Core::CutItem.new(
                  name: "Перегородка ящиков #{row_i + 1}-#{di + 1}",
                  length: row_height, width: @depth - @back_thickness,
                  thickness: t, material: "ЛДСП", cabinet: @cabinet_name
                )

                current_x += t
              end
            end

            current_z += row_height

            need_shelf = if row_i < num_rows - 1
              panels_between[row_i]
            else
              need_top_shelf
            end

            if need_shelf
              Primitives::Panel.horizontal(
                group,
                x: ox + t_su, y: oy, z: oz + current_z.mm,
                width: inner_w_mm.mm, depth: inner_d_su, thickness: t_su
              )

              cut_items << Core::CutItem.new(
                name: "Полка ящиков #{row_i + 1}",
                length: inner_w_mm, width: @depth - @back_thickness,
                thickness: t, material: "ЛДСП", cabinet: @cabinet_name
              )

              current_z += t
            end
          end

          { cut_items: cut_items, hardware_items: hardware_items, objects: objects }
        end

        private

        def build_part?(part)
          !@skip_parts.include?(part)
        end

        def resolve_row_drawers(row, inner_w_mm)
          if row[:count] && row[:drawers].empty?
            num = row[:count]
            num_partitions = num - 1
            available = inner_w_mm - num_partitions * @thickness
            w = (available.to_f / num).floor
            num.times do
              row[:drawers] << row[:defaults].merge(width: w)
            end
          end
        end
      end
    end
  end
end
