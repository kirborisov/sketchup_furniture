# sketchup_furniture/tools/drawer_tool.rb
# Инструмент для открытия/закрытия ящиков двойным кликом

module SketchupFurniture
  module Tools
    class DrawerTool
      # Реестр: entityID группы -> объект Drawer
      @@registry = {}
      
      # === РЕЕСТР ===
      
      # Зарегистрировать ящик
      def self.register(group, drawer)
        @@registry[group.entityID] = drawer if group.respond_to?(:entityID)
      end
      
      # Очистить реестр
      def self.clear
        @@registry.clear
      end
      
      # Количество зарегистрированных ящиков
      def self.count
        @@registry.size
      end
      
      # Активировать инструмент
      def self.activate
        Sketchup.active_model.select_tool(new)
      end
      
      # === TOOL INTERFACE ===
      
      def activate
        @ip = Sketchup::InputPoint.new
        puts "Инструмент ящиков активирован (двойной клик — открыть/закрыть)"
        puts "Зарегистрировано ящиков: #{@@registry.size}"
      end
      
      def deactivate(view)
        view.invalidate
      end
      
      # Двойной клик — открыть/закрыть ящик
      def onLButtonDoubleClick(flags, x, y, view)
        ip = Sketchup::InputPoint.new
        ip.pick(view, x, y)
        
        drawer = find_drawer_from_inputpoint(ip)
        if drawer
          if drawer.open?
            drawer.close
            puts "Ящик закрыт: #{drawer.name}"
          else
            drawer.open
            puts "Ящик открыт: #{drawer.name}"
          end
          view.invalidate
        end
      end
      
      # Одиночный клик — выделение (как стандартный инструмент)
      def onLButtonDown(flags, x, y, view)
        ph = view.pick_helper
        ph.do_pick(x, y)
        
        best = ph.best_picked
        sel = Sketchup.active_model.selection
        
        if best
          # Shift — добавить к выделению
          if flags & 1 == 1  # CONSTRAIN_MODIFIER_KEY (Shift)
            sel.toggle(best)
          else
            sel.clear
            sel.add(best)
          end
        else
          sel.clear
        end
        
        view.invalidate
      end
      
      def onMouseMove(flags, x, y, view)
        @ip.pick(view, x, y)
        view.tooltip = @ip.tooltip
      end
      
      def getExtents
        Sketchup.active_model.bounds
      end
      
      private
      
      # Найти ящик через InputPoint#instance_path
      # (полный путь через все вложенные группы)
      def find_drawer_from_inputpoint(ip)
        begin
          path = ip.instance_path
          path.count.times do |i|
            entity = path[i]
            next unless entity.respond_to?(:entityID)
            drawer = @@registry[entity.entityID]
            return drawer if drawer
          end
        rescue => e
          # Fallback: поиск по parent chain от face
          face = ip.face
          return nil unless face
          find_drawer_by_parents(face)
        end
        nil
      end
      
      # Fallback: идём вверх по parent chain
      def find_drawer_by_parents(entity)
        current = entity.parent # Entities collection
        while current
          owner = current.respond_to?(:parent) ? current.parent : nil
          break unless owner
          break if owner.is_a?(Sketchup::Model)
          
          if owner.respond_to?(:entityID)
            drawer = @@registry[owner.entityID]
            return drawer if drawer
          end
          
          current = owner.respond_to?(:parent) ? owner.parent : nil
        end
        nil
      end
    end
  end
end
