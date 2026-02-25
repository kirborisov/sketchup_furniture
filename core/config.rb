# furniture/core/config.rb
# Глобальная конфигурация по умолчанию

module SketchupFurniture
  module Core
    class Config
      attr_accessor :material_thickness, :back_thickness, :depth
      attr_accessor :legs_height, :plinth_height, :plinth_inset
      attr_accessor :soft_close, :edge_banding
      attr_accessor :cut_gap, :shelf_inset
      attr_accessor :facade_gap
      
      def initialize
        # Материалы
        @material_thickness = 18      # ЛДСП по умолчанию
        @back_thickness = 4           # ДВП задник
        
        # Габариты
        @depth = 400                  # глубина по умолчанию
        
        # Основание
        @legs_height = 100            # высота ножек
        @plinth_height = 100          # высота цоколя
        @plinth_inset = 50            # отступ цоколя от края
        
        # Фурнитура
        @soft_close = true            # доводчики по умолчанию
        
        # Кромка
        @edge_banding = {
          front: 2,                   # лицевая 2мм
          visible: 0.4,               # видимые 0.4мм
          hidden: 0                   # скрытые без кромки
        }
        
        # Фасады
        @facade_gap = 3               # зазор между фасадами (мм)
        
        # Раскрой
        @cut_gap = 4                  # зазор на пропил
        @shelf_inset = 2              # зазор полки от стенок
      end
      
      # Установить материал
      def material(type, thickness = nil)
        case type
        when :ldsp, :ldsp_16
          @material_thickness = thickness || 16
        when :ldsp_18
          @material_thickness = 18
        when :ldsp_22
          @material_thickness = 22
        end
      end
    end
  end
end
