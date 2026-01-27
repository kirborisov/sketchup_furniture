# furniture/output/cut_list.rb
# Вывод таблицы раскроя

module SketchupFurniture
  module Output
    class CutList
      def initialize(items = [])
        @items = items
      end
      
      # Добавить элементы
      def add(items)
        @items.concat(Array(items))
      end
      
      # Очистить
      def clear
        @items = []
      end
      
      # Печать таблицы
      def print
        return puts "Список раскроя пуст!" if @items.empty?
        
        puts "\n" + "=" * 75
        puts "ТАБЛИЦА РАСКРОЯ"
        puts "=" * 75
        
        by_material = @items.group_by { |p| "#{p.material} #{p.thickness}мм" }
        
        by_material.each do |mat_name, parts|
          puts "\n#{mat_name}:"
          puts "-" * 75
          puts sprintf("%-15s | %-20s | %10s | %10s | %5s", 
                       "Шкаф", "Деталь", "Длина", "Ширина", "Кол-во")
          puts "-" * 75
          
          grouped = parts.group_by(&:group_key)
          
          grouped.each do |key, items|
            item = items.first
            puts sprintf("%-15s | %-20s | %8d мм | %8d мм | %5d",
                        item.cabinet || "-", item.name, item.length, item.width, items.length)
          end
          
          area = parts.sum(&:area)
          puts "-" * 75
          puts sprintf("%50s Площадь: %.2f м²", "", area)
        end
        
        puts "\n" + "=" * 75
      end
      
      # Экспорт в CSV
      def export_csv(path)
        File.open(path, "w:UTF-8") do |f|
          f.puts "Шкаф;Деталь;Длина мм;Ширина мм;Толщина мм;Материал;Кол-во"
          
          grouped = @items.group_by(&:group_key)
          grouped.each do |key, items|
            item = items.first
            f.puts "#{item.cabinet};#{item.name};#{item.length};#{item.width};#{item.thickness};#{item.material};#{items.length}"
          end
        end
        puts "Сохранено: #{path}"
      end
      
      # Общая площадь по материалам
      def summary
        by_material = @items.group_by { |p| "#{p.material} #{p.thickness}мм" }
        
        puts "\n=== СВОДКА ==="
        by_material.each do |mat_name, parts|
          area = parts.sum(&:area)
          count = parts.length
          puts "#{mat_name}: #{count} деталей, %.2f м²" % area
        end
      end
    end
  end
end
