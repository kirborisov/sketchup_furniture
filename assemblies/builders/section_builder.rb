# sketchup_furniture/assemblies/builders/section_builder.rb
# Построение вертикальных перегородок (секций)

module SketchupFurniture
  module Assemblies
    module Builders
      class SectionBuilder
        def initialize(sections_config:, width:, height:, depth:, thickness:, back_thickness:,
                       support:, cabinet_name:)
          @sections_config = sections_config
          @width = width
          @height = height
          @depth = depth
          @thickness = thickness
          @back_thickness = back_thickness
          @support = support
          @cabinet_name = cabinet_name
        end

        def resolve_sections
          return [] if @sections_config.empty?

          inner_w = @width - 2 * @thickness
          num_partitions = @sections_config.length - 1
          partitions_w = num_partitions * @thickness
          available_w = inner_w - partitions_w

          @sections_config.map do |sec|
            if sec.is_a?(String) && sec.end_with?("%")
              (available_w * sec.to_f / 100.0).round
            else
              sec.to_i
            end
          end
        end

        def build(group, ox, oy, oz, inner_d, inner_h)
          @cut_items = []
          section_widths = resolve_sections
          return { cut_items: @cut_items } if section_widths.empty?

          t = @thickness.mm
          side_height = @height - @support.side_height_reduction
          top_of_bottom = @support.bottom_z + @thickness
          bottom_of_top = @support.side_start_z + side_height - @thickness
          panel_height = bottom_of_top - top_of_bottom
          panel_depth = @depth - @back_thickness

          x_pos = ox + t
          section_widths[0..-2].each_with_index do |sec_w, i|
            x_pos += sec_w.mm

            Primitives::Panel.side(
              group, x: x_pos, y: oy, z: oz,
              height: inner_h, depth: inner_d, thickness: t
            )

            @cut_items << Core::CutItem.new(
              name: "Перегородка #{i + 1}",
              length: panel_height, width: panel_depth,
              thickness: @thickness, material: "ЛДСП", cabinet: @cabinet_name
            )

            x_pos += t
          end

          { cut_items: @cut_items }
        end
      end
    end
  end
end
