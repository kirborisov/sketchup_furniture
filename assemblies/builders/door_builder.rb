# sketchup_furniture/assemblies/builders/door_builder.rb
# Построение дверей (сплошных и рамочных)

module SketchupFurniture
  module Assemblies
    module Builders
      class DoorBuilder
        def initialize(doors_config:, width:, support:, cabinet_name:)
          @doors_config = doors_config
          @width = width
          @support = support
          @cabinet_name = cabinet_name
        end

        def build(context, ox, oy, oz, side_height)
          return { cut_items: [], objects: [] } unless @doors_config

          facade_gap = SketchupFurniture.config.facade_gap || 3
          count = @doors_config[:count]
          opts = @doors_config[:options] || {}

          facade_h = side_height - facade_gap
          total_facade_w = @width - count * facade_gap

          door_widths = if count == 1
            [total_facade_w]
          else
            w = (total_facade_w.to_f / count).floor
            widths = Array.new(count, w)
            widths[-1] = total_facade_w - widths[0..-2].sum
            widths
          end

          cut_items = []
          objects = []

          current_x = facade_gap / 2.0
          support_z = @support.side_start_z

          door_widths.each_with_index do |dw, i|
            hinge = if count == 1
              :left
            elsif count == 2
              i == 0 ? :left : :right
            else
              i.even? ? :left : :right
            end

            door_opts = opts.dup
            door_type = door_opts.delete(:type)
            door_class = case door_type
                         when :frame then Components::Fronts::FrameDoor
                         else Components::Fronts::Door
                         end

            d = door_class.new(
              dw, facade_h,
              name: "#{@cabinet_name} дверь #{i + 1}",
              hinge_side: hinge,
              **door_opts
            )

            door_context = context.offset(
              dx: current_x,
              dy: 0,
              dz: support_z + facade_gap / 2.0
            )

            d.build(door_context)
            cut_items.concat(d.all_cut_items)
            objects << d

            current_x += dw + facade_gap
          end

          { cut_items: cut_items, objects: objects }
        end
      end
    end
  end
end
