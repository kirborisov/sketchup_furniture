# furniture/components/body/top_bottom.rb
# Верх и дно шкафа

module SketchupFurniture
  module Components
    class TopBottom < Core::Component
      attr_accessor :position  # :top или :bottom
      
      def initialize(width:, depth:, thickness: 18, position: :bottom, z_offset: 0, name: nil)
        super(width, thickness, depth, name: name || (position == :top ? "Верх" : "Дно"))
        @thickness = thickness
        @position = position
        @z_offset = z_offset
      end
      
      def build_geometry
        return unless @group && @context
        
        x = @context.x
        y = @context.y
        z = @context.z + @z_offset
        
        # Горизонтальная панель
        Primitives::Panel.horizontal(
          @group,
          x: x, y: y, z: z,
          width: @width,
          depth: @depth,
          thickness: @thickness
        )
        
        # Добавляем в раскрой
        add_cut(
          name: @name,
          length: @width,
          width: @depth,
          thickness: @thickness,
          material: "ЛДСП"
        ).edge(front: 2)
      end
    end
  end
end
