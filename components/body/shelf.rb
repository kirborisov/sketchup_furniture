# furniture/components/body/shelf.rb
# Полка

module SketchupFurniture
  module Components
    class Shelf < Core::Component
      attr_accessor :z_position, :adjustable
      
      def initialize(width:, depth:, thickness: 18, z_position: 0, adjustable: true, name: nil)
        super(width, thickness, depth, name: name || "Полка")
        @thickness = thickness
        @z_position = z_position
        @adjustable = adjustable
      end
      
      def build_geometry
        return unless @group && @context
        
        x = @context.x
        y = @context.y
        z = @context.z + @z_position
        
        # Полка — горизонтальная панель
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
        
        # Полкодержатели для съёмных полок
        if @adjustable
          add_hardware(type: :shelf_support, quantity: 4)
        end
      end
    end
  end
end
