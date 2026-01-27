# sketchup_furniture/components/support/plinth_support.rb
# Цоколь — боковины до пола, дно поднято

module SketchupFurniture
  module Components
    module Support
      class PlinthSupport < BaseSupport
        attr_reader :has_front_panel  # цокольная планка спереди
        
        def initialize(height = 100, front_panel: false)
          super(height)
          @has_front_panel = front_panel
        end
        
        # Боковины начинаются с пола
        def side_start_z
          0
        end
        
        # Дно поднято на высоту цоколя
        def bottom_z
          @height
        end
        
        # Боковины полной высоты
        def side_height_reduction
          0
        end
        
        # Можно добавить цокольную планку
        def has_geometry?
          @has_front_panel
        end
        
        def build(group, x:, y:, z:, width:, depth:, thickness:)
          return unless @has_front_panel
          
          # Цокольная планка спереди
          Primitives::Panel.vertical_x(
            group, x: x, y: y, z: z,
            width: width,
            height: @height.mm,
            thickness: thickness
          )
        end
        
        def cut_items
          return [] unless @has_front_panel
          
          [{
            name: "Цоколь",
            length: @width,
            width: @height,
            thickness: 18,
            material: "ЛДСП"
          }]
        end
        
        def type
          :plinth
        end
      end
    end
  end
end
