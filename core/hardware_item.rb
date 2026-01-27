# furniture/core/hardware_item.rb
# Элемент фурнитуры

module SketchupFurniture
  module Core
    class HardwareItem
      attr_accessor :name, :type, :quantity, :cabinet
      attr_accessor :specs, :article
      
      # Типы фурнитуры
      TYPES = {
        hinge: "Петля",
        handle: "Ручка",
        slides: "Направляющие",
        lift: "Подъёмник",
        leg: "Ножка",
        shelf_support: "Полкодержатель",
        rod: "Штанга",
        hook: "Крючок",
        connector: "Стяжка",
        screw: "Саморез",
        confirmat: "Конфирмат"
      }
      
      def initialize(type:, name: nil, quantity: 1, cabinet: nil, **specs)
        @type = type
        @name = name || TYPES[type] || type.to_s
        @quantity = quantity
        @cabinet = cabinet
        @specs = specs
        @article = specs[:article]
      end
      
      # Ключ для группировки
      def group_key
        [@type, @name, @specs]
      end
      
      # Описание
      def description
        desc = @name.dup
        desc += " #{@specs[:length]}мм" if @specs[:length]
        desc += " #{@specs[:size]}" if @specs[:size]
        desc += " soft-close" if @specs[:soft_close]
        desc
      end
      
      def to_s
        "#{description} — #{@quantity} шт"
      end
    end
  end
end
