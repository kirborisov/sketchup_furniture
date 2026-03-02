# sketchup_furniture/loaders/kitchen_yaml.rb
# Загрузка кухни из YAML-файла
#
# Использование:
#   kitchen = SketchupFurniture::Loaders::KitchenYaml.load("путь/kitchen.yaml")
#   kitchen.build

require 'yaml'

module SketchupFurniture
  module Loaders
    class KitchenYaml
      class << self
        def load(path)
          path = File.expand_path(path)
          raise "Файл не найден: #{path}" unless File.exist?(path)

          data = YAML.load_file(path)
          data = {} if data.nil?
          data = data.to_h if data.respond_to?(:to_h)

          name = data['name'] || data[:name] || 'Кухня'

          # Конфиг
          config = data['config'] || data[:config] || {}
          config = config.to_h if config.respond_to?(:to_h)
          if config['drawer_row_overlay'] || config[:drawer_row_overlay]
            SketchupFurniture.config.drawer_row_overlay = true
          end

          kitchen = Presets::Kitchen.new(name) do
            # Нижний ряд
            lower_data = data['lower'] || data[:lower] || {}
            lower_data = lower_data.to_h if lower_data.respond_to?(:to_h)
            lower_depth = lower_data['depth'] || lower_data[:depth] || 560
            lower_height = lower_data['height'] || lower_data[:height] || 720

            lower depth: lower_depth, height: lower_height do
              support_type = lower_data['support'] || lower_data[:support]
              support_height = lower_data['support_height'] || lower_data[:support_height] || 100
              case support_type.to_s
              when 'plinth'
                plinth support_height
              when 'legs'
                legs support_height
              end

              (lower_data['cabinets'] || lower_data[:cabinets] || []).each do |cab_data|
                cab_data = cab_data.to_h if cab_data.respond_to?(:to_h)
                Loaders::KitchenYaml.apply_cabinet(self, cab_data, lower_depth, lower_height)
              end
            end

            # Верхний ряд
            upper_data = data['upper'] || data[:upper] || {}
            upper_data = upper_data.to_h if upper_data.respond_to?(:to_h)
            upper_depth = upper_data['depth'] || upper_data[:depth] || 300
            upper_height = upper_data['height'] || upper_data[:height] || 600
            upper_at = upper_data['at'] || upper_data[:at] || 1400

            upper depth: upper_depth, height: upper_height, at: upper_at do
              (upper_data['cabinets'] || upper_data[:cabinets] || []).each do |cab_data|
                cab_data = cab_data.to_h if cab_data.respond_to?(:to_h)
                Loaders::KitchenYaml.apply_cabinet(self, cab_data, upper_depth, upper_height)
              end
            end

            # Столешница
            ct = data['countertop'] || data[:countertop]
            if ct
              ct = ct.to_h if ct.respond_to?(:to_h)
              thickness = ct['thickness'] || ct[:thickness] || 38
              overhang = ct['overhang'] || ct[:overhang] || 30
              depth = ct['depth'] || ct[:depth]
              countertop thickness, overhang: overhang, depth: depth
            end
          end

          kitchen
        end

        def apply_cabinet(kitchen, d, row_depth, _row_height)
          width = d['width'] || d[:width] || 600
          name = d['name'] || d[:name]
          height = d['height'] || d[:height]
          depth = d['depth'] || d[:depth] || row_depth

          kitchen.cabinet(width, name: name, height: height, depth: depth) do
            stretchers if d['stretchers'] || d[:stretchers]

            if (shelves = d['shelves'] || d[:shelves])
              shelves = [shelves] unless shelves.is_a?(Array)
              self.shelves(*shelves)
            end

            if (dr = d['drawers'] || d[:drawers])
              dr_type = (d['drawers_type'] || d[:drawers_type] || :frame).to_s.to_sym
              if dr.is_a?(Array)
                drawers dr, type: dr_type
              else
                drawers dr, height: (d['drawers_height'] || d[:drawers_height]), type: dr_type
              end
            end

            if (drr = d['drawer_row'] || d[:drawer_row])
              drr = drr.to_h if drr.respond_to?(:to_h)
              count = drr['count'] || drr[:count]
              h = drr['height'] || drr[:height]
              drr_type = (drr['type'] || drr[:type] || :frame).to_s.to_sym
              if count
                drawer_row count: count, type: drr_type
              else
                drawer_row height: h, type: drr_type
              end
            end

            separator_shelf if d['separator_shelf'] || d[:separator_shelf]

            if (doors_count = d['doors'] || d[:doors])
              doors_type = (d['doors_type'] || d[:doors_type] || :frame).to_s.to_sym
              over_drawers = d['doors_over_drawers'] || d[:doors_over_drawers]
              doors doors_count, type: doors_type, over_drawers: over_drawers
            end

            if (bp = d['blind_panel'] || d[:blind_panel])
              bp = bp.to_h if bp.respond_to?(:to_h)
              side = (bp['side'] || bp[:side] || :left).to_s.to_sym
              w = bp['width'] || bp[:width]
              blind_panel side: side, width: w
            end
          end
        end
      end
    end
  end
end
