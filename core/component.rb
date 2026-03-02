# furniture/core/component.rb
# Базовый класс для всех компонентов

module SketchupFurniture
  module Core
    class Component
      attr_reader :width, :height, :depth, :name
      attr_reader :cut_items, :hardware_items
      attr_reader :group
      attr_reader :world_x, :world_y, :world_z
      attr_accessor :context
      
      def initialize(width, height, depth, name: nil)
        @width = width
        @height = height
        @depth = depth
        @name = name
        @context = nil
        
        @cut_items = []
        @hardware_items = []
        @children = []
        @group = nil
        @world_x = 0
        @world_y = 0
        @world_z = 0
      end
      
      # === ПОСТРОЕНИЕ ===
      
      # Построить компонент (переопределяется в наследниках)
      def build(context = nil)
        @context = context || Context.new
        @group = create_group(@name || self.class.name.split('::').last)
        
        # Локальная позиция (для трансформации группы)
        cx = @context.x || 0
        cy = @context.y || 0
        cz = @context.z || 0
        
        # Мировая позиция (для размерных линий)
        @world_x = @context.world_x || cx
        @world_y = @context.world_y || cy
        @world_z = @context.world_z || cz
        
        # Позиционируем группу трансформацией
        if cx != 0 || cy != 0 || cz != 0
          tr = Geom::Transformation.new([cx.mm, cy.mm, cz.mm])
          @group.transformation = tr
        end
        
        # Переключаемся на локальные координаты (0,0,0) — геометрия внутри группы
        @context = Context.new(
          x: 0, y: 0, z: 0,
          parent: @group,
          config: @context.config,
          world_x: @world_x, world_y: @world_y, world_z: @world_z
        )
        
        build_geometry
        build_children
        
        @group
      end
      
      # Создать группу в SketchUp
      def create_group(name)
        entities = @context.entities
        group = entities.add_group
        group.name = name
        group
      end
      
      # Построить геометрию (переопределяется)
      def build_geometry
        # Реализуется в наследниках
      end
      
      # Построить дочерние компоненты
      def build_children
        @children.each do |child|
          child.build(@context)
        end
      end
      
      # === ДОЧЕРНИЕ КОМПОНЕНТЫ ===
      
      # Добавить дочерний компонент
      def add_child(component)
        @children << component
        component
      end
      
      # === РАСКРОЙ И ФУРНИТУРА ===
      
      # Добавить деталь в раскрой
      def add_cut(name:, length:, width:, thickness:, material: "ЛДСП")
        item = CutItem.new(
          name: name,
          length: length,
          width: width,
          thickness: thickness,
          material: material,
          cabinet: @name
        )
        @cut_items << item
        item
      end
      
      # Добавить фурнитуру
      def add_hardware(type:, name: nil, quantity: 1, **specs)
        item = HardwareItem.new(
          type: type,
          name: name,
          quantity: quantity,
          cabinet: @name,
          **specs
        )
        @hardware_items << item
        item
      end
      
      # Собрать все детали раскроя (включая детей)
      def all_cut_items
        items = @cut_items.dup
        @children.each do |child|
          items.concat(child.all_cut_items)
        end
        items
      end
      
      # Собрать всю фурнитуру (включая детей)
      def all_hardware_items
        items = @hardware_items.dup
        @children.each do |child|
          items.concat(child.all_hardware_items)
        end
        items
      end
      
      # === ГАБАРИТЫ ===
      
      def bounding_box
        { width: @width, height: @height, depth: @depth }
      end
      
      # === ВАЛИДАЦИЯ ===
      
      def validate
        errors = []
        errors << "Ширина должна быть > 0" if @width <= 0
        errors << "Высота должна быть > 0" if @height <= 0
        errors << "Глубина должна быть > 0" if @depth <= 0
        errors
      end
      
      def valid?
        validate.empty?
      end
    end
  end
end
