# sketchup_furniture/assemblies/builders/shelf_builder.rb
# Построение полок (с учётом секций)

module SketchupFurniture
  module Assemblies
    module Builders
      class ShelfBuilder
        def initialize(shelves_config:, section_widths:, width:, depth:, thickness:,
                       back_thickness:, cabinet_name:)
          @shelves_config = shelves_config
          @section_widths = section_widths
          @width = width
          @depth = depth
          @thickness = thickness
          @back_thickness = back_thickness
          @cabinet_name = cabinet_name
        end

        def build(group, ox, oy, oz)
          @group = group
          @cut_items = []
          @hardware_items = []

          t = @thickness.mm
          inner_w = (@width - 2 * @thickness).mm
          inner_d = (@depth - @back_thickness).mm

          if @section_widths.empty?
            @shelves_config.each_with_index do |shelf_cfg, i|
              build_shelf(ox + t, oy, oz + shelf_cfg[:z].mm, inner_w, inner_d, i + 1, 1)
            end
          else
            x_pos = ox + t
            @section_widths.each_with_index do |sec_w, sec_i|
              @shelves_config.each_with_index do |shelf_cfg, shi|
                build_shelf(x_pos, oy, oz + shelf_cfg[:z].mm, sec_w.mm, inner_d, shi + 1, sec_i + 1)
              end
              x_pos += sec_w.mm + t
            end
          end

          { cut_items: @cut_items, hardware_items: @hardware_items }
        end

        private

        def build_shelf(x, y, z, width, depth, shelf_num, section_num)
          Primitives::Panel.horizontal(
            @group, x: x, y: y, z: z,
            width: width, depth: depth, thickness: @thickness.mm
          )

          shelf_w = (width / 1.mm).round
          @cut_items << Core::CutItem.new(
            name: "Полка #{section_num}-#{shelf_num}",
            length: shelf_w, width: @depth - @back_thickness,
            thickness: @thickness, material: "ЛДСП", cabinet: @cabinet_name
          )

          @hardware_items << Core::HardwareItem.new(
            type: :shelf_support, quantity: 4, cabinet: @cabinet_name
          )
        end
      end
    end
  end
end
