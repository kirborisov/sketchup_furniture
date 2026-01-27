# furniture/output/hardware_list.rb
# Вывод списка фурнитуры

module SketchupFurniture
  module Output
    class HardwareList
      def initialize(items = [])
        @items = items
      end
      
      def add(items)
        @items.concat(Array(items))
      end
      
      def clear
        @items = []
      end
      
      def print
        return puts "Список фурнитуры пуст!" if @items.empty?
        
        puts "\n" + "=" * 60
        puts "СПЕЦИФИКАЦИЯ ФУРНИТУРЫ"
        puts "=" * 60
        
        # Группируем по типу и описанию
        grouped = @items.group_by(&:group_key)
        
        grouped.each do |key, items|
          item = items.first
          total_qty = items.sum(&:quantity)
          puts sprintf("%-45s %8d шт", item.description, total_qty)
        end
        
        puts "=" * 60
      end
      
      def summary
        by_type = @items.group_by { |i| i.type }
        
        puts "\n=== ФУРНИТУРА ==="
        by_type.each do |type, items|
          total = items.sum(&:quantity)
          name = Core::HardwareItem::TYPES[type] || type.to_s
          puts "#{name}: #{total} шт"
        end
      end
    end
  end
end
