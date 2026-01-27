# furniture/core/component.rb
# Базовый класс для всех компонентов

module SketchupFurniture
  module Core
    class Component
      attr_reader :width, :height, :depth, :name
      attr_reader :cut_items, :hardware_items
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
      end
      
      # === ПОСТРОЕНИЕ ===
      
      # Построить компонент (переопределяется в наследниках)
      def build(context = nil)
        @context = context || Context.new
        @group = create_group(@name || self.class.name.split('::').last)
        
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
