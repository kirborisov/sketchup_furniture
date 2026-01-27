# furniture/core/context.rb
# Контекст построения — позиция, родитель, настройки

module SketchupFurniture
  module Core
    class Context
      attr_accessor :x, :y, :z           # позиция
      attr_accessor :rotation            # поворот (0, 90, 180, 270)
      attr_accessor :parent_group        # родительская группа SketchUp
      attr_accessor :config              # ссылка на конфигурацию
      
      def initialize(x: 0, y: 0, z: 0, rotation: 0, parent: nil, config: nil)
        @x = x
        @y = y
        @z = z
        @rotation = rotation
        @parent_group = parent
        @config = config || SketchupFurniture.config
      end
      
      # Создать дочерний контекст со смещением
      def offset(dx: 0, dy: 0, dz: 0)
        Context.new(
          x: @x + dx,
          y: @y + dy,
          z: @z + dz,
          rotation: @rotation,
          parent: @parent_group,
          config: @config
        )
      end
      
      # Позиция как массив
      def position
        [@x, @y, @z]
      end
      
      # Entities для построения
      def entities
        if @parent_group
          @parent_group.entities
        else
          Sketchup.active_model.active_entities
        end
      end
    end
  end
end
