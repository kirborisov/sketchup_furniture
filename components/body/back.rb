# furniture/components/body/back.rb
# Задняя стенка

module SketchupFurniture
  module Components
    class Back < Core::Component
      def initialize(width:, height:, thickness: 4, name: nil)
        super(width, height, thickness, name: name || "Задняя стенка")
        @thickness = thickness
      end
      
      def build_geometry
        return unless @group && @context
        
        x = @context.x
        y = @context.y
        z = @context.z
        
        # Задник — вертикальная панель в плоскости XZ
        Primitives::Panel.back(
          @group,
          x: x, y: y, z: z,
          width: @width,
          height: @height,
          thickness: @thickness
        )
        
        # Добавляем в раскрой
        add_cut(
          name: @name,
          length: @height,
          width: @width,
          thickness: @thickness,
          material: "ДВП"
        )
      end
    end
  end
end
