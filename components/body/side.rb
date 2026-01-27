# furniture/components/body/side.rb
# Боковина шкафа

module SketchupFurniture
  module Components
    class Side < Core::Component
      attr_accessor :position  # :left или :right
      
      def initialize(height:, depth:, thickness: 18, position: :left, name: nil)
        super(thickness, height, depth, name: name || "Боковина #{position == :left ? 'левая' : 'правая'}")
        @thickness = thickness
        @position = position
      end
      
      def build_geometry
        return unless @group && @context
        
        x = @context.x
        y = @context.y
        z = @context.z
        
        # Боковина — вертикальная панель
        Primitives::Panel.side(
          @group,
          x: x, y: y, z: z,
          height: @height,
          depth: @depth,
          thickness: @thickness
        )
        
        # Добавляем в раскрой
        add_cut(
          name: @name,
          length: @height,
          width: @depth,
          thickness: @thickness,
          material: "ЛДСП"
        ).edge(front: 2, back: 0, left: 0.4, right: 0.4)
      end
      
      private
      
      def thickness
        @thickness
      end
    end
  end
end
