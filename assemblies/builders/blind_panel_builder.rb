# sketchup_furniture/assemblies/builders/blind_panel_builder.rb
# Глухая панель — ЛДСП фасад без петель (не открывается)

module SketchupFurniture
  module Assemblies
    module Builders
      class BlindPanelBuilder
        def initialize(blind_panel_config:, cabinet_width:, support:, cabinet_name:)
          @config = blind_panel_config
          @cabinet_width = cabinet_width
          @support = support
          @cabinet_name = cabinet_name
        end

        def panel_width
          @config[:width] || (@cabinet_width / 2.0).floor
        end

        def build(context, ox, oy, oz, side_height)
          return { cut_items: [], blind_width: 0 } unless @config

          facade_gap = SketchupFurniture.config.facade_gap || 3
          facade_mat = Materials.get(@config[:facade_material] || :ldsp_16) || { name: "ЛДСП", thickness: 16 }
          facade_t = facade_mat[:thickness]

          pw = panel_width
          ph = side_height - facade_gap

          support_z = @support.side_start_z

          panel_x = if @config[:side] == :right
                      @cabinet_width - pw - facade_gap / 2.0
                    else
                      facade_gap / 2.0
                    end

          panel_z = support_z + facade_gap / 2.0

          entities = context.entities
          group = entities.add_group
          group.name = "#{@cabinet_name} глухая панель"

          fw = pw.mm
          fh = ph.mm
          ft = facade_t.mm

          px = ox + panel_x.mm
          py = oy
          pz = oz + panel_z.mm

          pts = [
            [px, py, pz],
            [px + fw, py, pz],
            [px + fw, py, pz + fh],
            [px, py, pz + fh]
          ]
          face = group.entities.add_face(pts)
          if face
            if face.normal.y > 0
              face.pushpull(-ft)
            else
              face.pushpull(ft)
            end
          end

          cut_item = Core::CutItem.new(
            name: "Глухая панель",
            length: pw,
            width: ph,
            thickness: facade_t,
            material: facade_mat[:name],
            cabinet: @cabinet_name
          )

          { cut_items: [cut_item], blind_width: pw }
        end
      end
    end
  end
end
