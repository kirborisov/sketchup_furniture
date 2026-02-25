# sketchup_furniture/assemblies/builders/body_builder.rb
# Построение корпуса: боковины, верх/дно, задник, царги

module SketchupFurniture
  module Assemblies
    module Builders
      class BodyBuilder
        def initialize(width:, height:, depth:, thickness:, back_thickness:,
                       support:, skip_parts:, cabinet_name:, stretchers_config: nil)
          @width = width
          @height = height
          @depth = depth
          @thickness = thickness
          @back_thickness = back_thickness
          @support = support
          @skip_parts = skip_parts
          @cabinet_name = cabinet_name
          @stretchers_config = stretchers_config
        end

        def build(group, ox, oy, oz)
          @group = group
          @cut_items = []

          t = @thickness.mm
          support_z = @support.side_start_z.mm
          bottom_offset = @support.bottom_z.mm
          side_height = @height - @support.side_height_reduction
          inner_w = (@width - 2 * @thickness).mm
          inner_d = (@depth - @back_thickness).mm

          if part?(:left_side)
            build_side(:left, ox, oy, oz + support_z, inner_d, side_height)
          end

          if part?(:right_side)
            build_side(:right, ox + @width.mm - t, oy, oz + support_z, inner_d, side_height)
          end

          if part?(:bottom)
            build_horizontal(:bottom, ox + t, oy, oz + bottom_offset, inner_w, inner_d)
          end

          if part?(:top)
            build_horizontal(:top, ox + t, oy, oz + support_z + side_height.mm - t, inner_w, inner_d)
          end

          if @stretchers_config
            build_stretchers(ox + t, oy, oz + support_z, inner_w, inner_d, side_height)
          end

          if part?(:back)
            build_back(ox, oy + inner_d, oz + support_z, side_height)
          end

          { cut_items: @cut_items }
        end

        private

        def part?(name)
          !@skip_parts.include?(name)
        end

        def build_side(position, x, y, z, depth, height)
          Primitives::Panel.side(
            @group, x: x, y: y, z: z,
            height: height.mm, depth: depth, thickness: @thickness.mm
          )
          @cut_items << Core::CutItem.new(
            name: position == :left ? "Боковина левая" : "Боковина правая",
            length: height, width: @depth - @back_thickness,
            thickness: @thickness, material: "ЛДСП", cabinet: @cabinet_name
          )
        end

        def build_horizontal(position, x, y, z, width, depth)
          Primitives::Panel.horizontal(
            @group, x: x, y: y, z: z,
            width: width, depth: depth, thickness: @thickness.mm
          )
          @cut_items << Core::CutItem.new(
            name: position == :top ? "Верх" : "Дно",
            length: @width - 2 * @thickness, width: @depth - @back_thickness,
            thickness: @thickness, material: "ЛДСП", cabinet: @cabinet_name
          )
        end

        def build_back(x, y, z, height)
          Primitives::Panel.back(
            @group, x: x, y: y, z: z,
            width: @width.mm, height: height.mm, thickness: @back_thickness.mm
          )
          @cut_items << Core::CutItem.new(
            name: "Задняя стенка",
            length: height, width: @width,
            thickness: @back_thickness, material: "ДВП", cabinet: @cabinet_name
          )
        end

        def build_stretchers(x, y, z, inner_w, inner_d, side_height)
          t = @thickness.mm
          sw = @stretchers_config[:width]
          inner_w_mm = @width - 2 * @thickness
          top_z = z + side_height.mm

          case @stretchers_config[:mode]
          when :standard
            Primitives::Panel.horizontal(@group, x: x, y: y, z: top_z - t, width: inner_w, depth: sw.mm, thickness: t)
            Primitives::Panel.horizontal(@group, x: x, y: y + inner_d - sw.mm, z: top_z - t, width: inner_w, depth: sw.mm, thickness: t)
          when :sink
            Primitives::Panel.horizontal(@group, x: x, y: y, z: top_z - sw.mm, width: inner_w, depth: t, thickness: sw.mm)
            Primitives::Panel.horizontal(@group, x: x, y: y + inner_d - t, z: top_z - sw.mm, width: inner_w, depth: t, thickness: sw.mm)
          end

          @cut_items << Core::CutItem.new(name: "Царга передняя", length: inner_w_mm, width: sw, thickness: @thickness, material: "ЛДСП", cabinet: @cabinet_name)
          @cut_items << Core::CutItem.new(name: "Царга задняя", length: inner_w_mm, width: sw, thickness: @thickness, material: "ЛДСП", cabinet: @cabinet_name)
        end
      end
    end
  end
end
