# furniture/primitives/panel.rb
# Создание панелей (прямоугольников с толщиной)

module SketchupFurniture
  module Primitives
    class Panel
      # Ориентации панели
      ORIENTATIONS = {
        horizontal: :xy,  # лежит горизонтально (дно, полка)
        vertical_x: :xz,  # стоит вдоль X (задник)
        vertical_y: :yz   # стоит вдоль Y (боковина)
      }
      
      # Создать панель
      # group: группа SketchUp куда добавлять
      # origin: [x, y, z] начальная точка
      # size: [width, depth, thickness] размеры
      # orientation: :horizontal, :vertical_x, :vertical_y
      def self.create(group, origin:, size:, orientation: :horizontal)
        x, y, z = origin
        w, d, t = size
        
        entities = group.respond_to?(:entities) ? group.entities : group
        
        case orientation
        when :horizontal, :xy
          # Панель лежит в плоскости XY (полка, дно)
          pts = [
            [x, y, z],
            [x + w, y, z],
            [x + w, y + d, z],
            [x, y + d, z]
          ]
          face = entities.add_face(pts)
          extrude(face, t)
          
        when :vertical_x, :xz
          # Панель стоит в плоскости XZ (задник)
          pts = [
            [x, y, z],
            [x + w, y, z],
            [x + w, y, z + t],
            [x, y, z + t]
          ]
          # Это нужно переделать для правильного выдавливания
          pts = [
            [x, y, z],
            [x + w, y, z],
            [x + w, y, z + d],
            [x, y, z + d]
          ]
          face = entities.add_face(pts)
          extrude(face, t)
          
        when :vertical_y, :yz
          # Панель стоит в плоскости YZ (боковина)
          pts = [
            [x, y, z],
            [x, y + d, z],
            [x, y + d, z + w],
            [x, y, z + w]
          ]
          face = entities.add_face(pts)
          extrude(face, t)
        end
      end
      
      # Создать панель по типу
      def self.side(group, x:, y:, z:, height:, depth:, thickness:)
        # Боковина: высота × глубина × толщина
        pts = [
          [x, y, z],
          [x + thickness, y, z],
          [x + thickness, y + depth, z],
          [x, y + depth, z]
        ]
        face = group.entities.add_face(pts)
        extrude(face, height)
      end
      
      def self.horizontal(group, x:, y:, z:, width:, depth:, thickness:)
        # Горизонтальная панель: ширина × глубина × толщина
        pts = [
          [x, y, z],
          [x + width, y, z],
          [x + width, y + depth, z],
          [x, y + depth, z]
        ]
        face = group.entities.add_face(pts)
        extrude(face, thickness)
      end
      
      def self.back(group, x:, y:, z:, width:, height:, thickness:)
        # Задняя стенка: ширина × высота × толщина
        pts = [
          [x, y, z],
          [x + width, y, z],
          [x + width, y, z + height],
          [x, y, z + height]
        ]
        face = group.entities.add_face(pts)
        extrude(face, thickness)
      end
      
      private
      
      def self.extrude(face, distance)
        return unless face
        if face.normal.z < 0
          face.pushpull(-distance)
        else
          face.pushpull(distance)
        end
      end
    end
  end
end
