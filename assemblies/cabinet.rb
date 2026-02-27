# sketchup_furniture/assemblies/cabinet.rb
# Базовый шкаф — сборка из компонентов
# Построение делегируется билдерам (assemblies/builders/)

module SketchupFurniture
  module Assemblies
    class Cabinet < Core::Component
      attr_accessor :thickness, :back_thickness
      attr_reader :shelves_config, :sections_config, :support, :drawer_objects, :door_objects, :blind_panel_config
      
      PARTS = [:bottom, :top, :back, :left_side, :right_side].freeze
      
      def initialize(width, height, depth, name: "Шкаф", thickness: 18, back_thickness: 4)
        super(width, height, depth, name: name)
        @thickness = thickness
        @back_thickness = back_thickness
        
        @shelves_config = []
        @sections_config = []
        @drawers_config = []
        @drawers_positions = nil
        @drawers_options = {}
        @drawer_rows_config = []
        @drawer_objects = []
        @doors_config = nil
        @door_objects = []
        @blind_panel_config = nil
        @skip_parts = []
        @stretchers_config = nil
        @separator_shelf = false
        @support = Components::Support::SidesSupport.new
        @_building_row = nil
      end
      
      # === DSL МЕТОДЫ ===
      
      def skip(*parts)
        parts.flatten.each do |part|
          unless PARTS.include?(part)
            puts "Предупреждение: неизвестная часть '#{part}'. Доступные: #{PARTS.join(', ')}"
            next
          end
          @skip_parts << part unless @skip_parts.include?(part)
        end
        self
      end
      
      def build_part?(part)
        !@skip_parts.include?(part)
      end
      
      def shelf(z_position, adjustable: true)
        @shelves_config << { z: z_position, adjustable: adjustable }
        self
      end
      
      def shelves(*positions)
        positions.flatten.each { |z| shelf(z) }
        self
      end
      
      def sections(*widths)
        @sections_config = widths.flatten
        self
      end

      # Горизонтальная разделительная полка между ящиками и дверями
      def separator_shelf
        @separator_shelf = true
        self
      end
      
      # === ЯЩИКИ ===
      
      def drawer(value, **opts)
        if @_building_row
          merged = @_building_row[:defaults].merge(opts)
          @_building_row[:drawers] << merged.merge(width: value)
        else
          defaults = { slide: :ball_bearing, soft_close: false, draw_slides: false,
                       back_gap: 20, box_top_inset: 20, box_bottom_inset: 20 }
          @drawers_config << defaults.merge(opts).merge(height: value)
        end
        self
      end
      
      def drawers(count_or_positions, height: nil, slide: :ball_bearing, soft_close: false, draw_slides: false,
                 back_gap: 20, box_top_inset: 20, box_bottom_inset: 20,
                 type: nil, frame_width: nil, frame_thickness: nil, tenon: nil,
                 panel_gap: nil, panel_thickness: nil, groove_depth: nil)
        if count_or_positions.is_a?(Array)
          @drawers_positions = count_or_positions
          @drawers_options = {
            slide: slide, soft_close: soft_close, draw_slides: draw_slides, back_gap: back_gap,
            box_top_inset: box_top_inset, box_bottom_inset: box_bottom_inset,
            type: type, frame_width: frame_width, frame_thickness: frame_thickness,
            tenon: tenon, panel_gap: panel_gap, panel_thickness: panel_thickness, groove_depth: groove_depth
          }
        else
          count_or_positions.times do
            drawer(height, slide: slide, soft_close: soft_close, draw_slides: draw_slides,
                   back_gap: back_gap, box_top_inset: box_top_inset, box_bottom_inset: box_bottom_inset,
                   type: type, frame_width: frame_width, frame_thickness: frame_thickness,
                   tenon: tenon, panel_gap: panel_gap, panel_thickness: panel_thickness, groove_depth: groove_depth)
          end
        end
        self
      end
      
      def drawer_row(height: nil, count: nil, slide: :ball_bearing, soft_close: false, draw_slides: false,
                     back_gap: 20, box_top_inset: 20, box_bottom_inset: 20,
                     type: nil, frame_width: nil, frame_thickness: nil, tenon: nil,
                     panel_gap: nil, panel_thickness: nil, groove_depth: nil, &block)
        @_building_row = {
          height: height,
          count: count,
          defaults: {
            slide: slide, soft_close: soft_close, draw_slides: draw_slides, back_gap: back_gap,
            box_top_inset: box_top_inset, box_bottom_inset: box_bottom_inset,
            type: type, frame_width: frame_width, frame_thickness: frame_thickness,
            tenon: tenon, panel_gap: panel_gap, panel_thickness: panel_thickness, groove_depth: groove_depth
          },
          drawers: []
        }
        instance_eval(&block) if block
        @drawer_rows_config << @_building_row
        @_building_row = nil
        self
      end
      
      # === ДВЕРИ ===
      
      def doors(count, **opts)
        @doors_config = { count: count, options: opts }
        self
      end
      
      # Глухая панель (не открывается, без петель)
      def blind_panel(side:, width: nil, facade_material: :ldsp_16)
        @blind_panel_config = { side: side, width: width, facade_material: facade_material }
        self
      end
      
      # === ОПОРЫ ===
      
      def plinth(height, front_panel: false)
        @support = Components::Support::PlinthSupport.new(height, front_panel: front_panel)
        self
      end
      
      def legs(height, count: nil, adjustable: true)
        leg_count = count || Components::Support::LegsSupport.calculate_count(@width)
        @support = Components::Support::LegsSupport.new(height, count: leg_count, adjustable: adjustable)
        self
      end
      
      def stretchers(mode = :standard, width: 80)
        @stretchers_config = { mode: mode, width: width }
        skip(:top)
        self
      end
      
      def on_sides
        @support = Components::Support::SidesSupport.new
        self
      end
      
      # === ПОСТРОЕНИЕ ===
      
      def build_geometry
        t = @thickness.mm
        
        side_height = @height - @support.side_height_reduction
        bottom_offset = @support.bottom_z.mm
        inner_w_mm = @width - 2 * @thickness
        inner_d_mm = @depth - @back_thickness
        
        top_of_bottom = @support.bottom_z + @thickness
        bottom_of_top = @support.side_start_z + side_height - @thickness
        inner_h_mm = bottom_of_top - top_of_bottom
        inner_h = inner_h_mm.mm
        inner_d = inner_d_mm.mm
        
        ox = (@context&.x || 0).mm
        oy = (@context&.y || 0).mm
        oz = (@context&.z || 0).mm
        
        # Корпус (боковины, верх/дно, задник, царги)
        body = Builders::BodyBuilder.new(
          width: @width, height: @height, depth: @depth,
          thickness: @thickness, back_thickness: @back_thickness,
          support: @support, skip_parts: @skip_parts,
          cabinet_name: @name, stretchers_config: @stretchers_config
        )
        merge_result(body.build(@group, ox, oy, oz))
        
        # Секции (вертикальные перегородки)
        section_builder = Builders::SectionBuilder.new(
          sections_config: @sections_config,
          width: @width, height: @height, depth: @depth,
          thickness: @thickness, back_thickness: @back_thickness,
          support: @support, cabinet_name: @name
        )
        section_widths = section_builder.resolve_sections
        
        if @sections_config.any?
          merge_result(section_builder.build(@group, ox, oy, oz + bottom_offset + t, inner_d, inner_h))
        end
        
        # Полки
        if @shelves_config.any?
          shelf_builder = Builders::ShelfBuilder.new(
            shelves_config: @shelves_config, section_widths: section_widths,
            width: @width, depth: @depth,
            thickness: @thickness, back_thickness: @back_thickness,
            cabinet_name: @name
          )
          merge_result(shelf_builder.build(@group, ox, oy, oz + bottom_offset))
        end
        
        # Ящики
        if @drawers_config.any? || @drawers_positions
          drawer_builder = Builders::DrawerBuilder.new(
            drawers_config: @drawers_config, drawers_positions: @drawers_positions,
            drawers_options: @drawers_options,
            width: @width, height: @height, depth: @depth,
            thickness: @thickness, back_thickness: @back_thickness,
            support: @support, skip_parts: @skip_parts, cabinet_name: @name
          )
          result = drawer_builder.build(@context, inner_w_mm, inner_d_mm)
          merge_result(result)
          @drawer_objects.concat(result[:objects] || [])
        end
        
        # Ряды ящиков
        if @drawer_rows_config.any?
          auto_fill_drawer_row_heights(inner_h_mm)
          row_builder = Builders::DrawerRowBuilder.new(
            drawer_rows_config: @drawer_rows_config,
            width: @width, depth: @depth,
            thickness: @thickness, back_thickness: @back_thickness,
            support: @support, skip_parts: @skip_parts, cabinet_name: @name
          )
          result = row_builder.build(@group, @context, ox, oy, oz + bottom_offset + t, inner_w_mm, inner_d_mm)
          merge_result(result)
          @drawer_objects.concat(result[:objects] || [])
        end

        # Разделительная полка над ящиками (если включена)
        if @separator_shelf
          shelf_z = separator_shelf_z(top_of_bottom, inner_h_mm)
          if shelf_z
            Primitives::Panel.horizontal(
              @group,
              x: ox + t, y: oy, z: oz + shelf_z.mm,
              width: inner_w_mm.mm, depth: inner_d, thickness: t
            )

            @cut_items << Core::CutItem.new(
              name: "Разделительная полка",
              length: inner_w_mm, width: @depth - @back_thickness,
              thickness: @thickness, material: "ЛДСП", cabinet: @name
            )
          end
        end
        
        # Глухая панель (до дверей, чтобы DoorBuilder знал зону дверей)
        if @blind_panel_config
          blind_builder = Builders::BlindPanelBuilder.new(
            blind_panel_config: @blind_panel_config,
            cabinet_width: @width,
            support: @support,
            cabinet_name: @name
          )
          merge_result(blind_builder.build(@context, ox, oy, oz, side_height))
        end
        
        # Двери (учитывают глухую панель при наличии)
        if @doors_config
          zone_start = nil
          zone_height = nil
          opts = @doors_config[:options] || {}

          # Специальный режим: двери над выдвижными ящиками
          if opts[:over_drawers] && (!@drawers_config.empty? || @drawers_positions)
            zone_info = doors_over_drawers_zone(
              side_height: side_height,
              top_of_bottom: top_of_bottom,
              inner_h_mm: inner_h_mm
            )
            zone_start = zone_info[:zone_start]
            zone_height = zone_info[:zone_height]
          end

          # Служебные ключи дверей не передаём в класс Door
          cleaned_opts = opts.dup
          cleaned_opts.delete(:over_drawers)
          @doors_config = @doors_config.merge(options: cleaned_opts)

          door_builder = Builders::DoorBuilder.new(
            doors_config: @doors_config, width: @width,
            support: @support, cabinet_name: @name,
            blind_panel_config: @blind_panel_config,
            zone_start: zone_start,
            zone_height: zone_height
          )
          result = door_builder.build(@context, ox, oy, oz, side_height)
          merge_result(result)
          @door_objects.concat(result[:objects] || [])
        end
        
        # Геометрия опоры
        if @support.has_geometry?
          @support.build(@group, x: ox, y: oy, z: oz, width: @width.mm, depth: @depth.mm, thickness: t)
        end
        
        # Фурнитура от опоры
        @support.hardware.each do |hw|
          add_hardware(**hw)
        end
      end
      
      private
      
      def merge_result(result)
        @cut_items.concat(result[:cut_items] || [])
        @hardware_items.concat(result[:hardware_items] || [])
      end

      # Если в drawer_row не указана высота, можно заполнить её автоматически.
      # Простое правило:
      # - если ровно один ряд и height не задан — он занимает всю внутреннюю высоту;
      # - если рядов несколько, а часть без height — оставшуюся высоту делим между ними поровну.
      def auto_fill_drawer_row_heights(inner_h_mm)
        return if @drawer_rows_config.empty?

        rows_without_height = @drawer_rows_config.select { |r| r[:height].nil? }
        return if rows_without_height.empty?

        if @drawer_rows_config.length == 1
          @drawer_rows_config[0][:height] = inner_h_mm
          return
        end

        explicit_sum = @drawer_rows_config.sum { |r| r[:height] || 0 }
        remaining = inner_h_mm - explicit_sum
        return if remaining <= 0

        auto_rows = rows_without_height
        share = (remaining.to_f / auto_rows.length).floor
        auto_rows.each { |r| r[:height] = share }

        used = explicit_sum + share * auto_rows.length
        delta = inner_h_mm - used
        auto_rows.last[:height] += delta if delta > 0
      end

      # Расчёт вертикальной зоны фасадов дверей в режиме over_drawers
      def doors_over_drawers_zone(side_height:, top_of_bottom:, inner_h_mm:)
        configs =
          if @drawers_positions
            resolve_drawer_configs_for_positions(inner_h_mm)
          else
            @drawers_config
          end

        return { zone_start: nil, zone_height: nil } if configs.empty?

        total_drawers_h = configs.sum { |c| c[:height] }
        facade_gap = SketchupFurniture.config.facade_gap || 3

        # Базовый отступ от низа боковин до верха ящиков
        base_offset = (top_of_bottom - @support.side_start_z) + total_drawers_h

        # При separator_shelf фасад двери должен закрывать кромку полки:
        # нижняя кромка фасада совпадает с верхом полки.
        relative_start =
          if @separator_shelf
            base_offset - facade_gap / 2.0
          else
            base_offset + facade_gap
          end

        zone_height = side_height - relative_start

        if zone_height <= facade_gap
          { zone_start: nil, zone_height: nil }
        else
          { zone_start: relative_start, zone_height: zone_height }
        end
      end

      # Локальное разрешение конфигов ящиков по positions (аналог DrawerBuilder#resolve_drawer_positions),
      # только для вычисления высот, без модификации @drawers_config.
      def resolve_drawer_configs_for_positions(inner_h_mm)
        return [] unless @drawers_positions

        positions = @drawers_positions
        opts = @drawers_options

        configs = []

        positions.each_with_index do |pos, i|
          h = if i < positions.length - 1
            positions[i + 1] - pos
          else
            inner_h_mm - pos
          end

          configs << {
            height: h,
            slide: opts[:slide], soft_close: opts[:soft_close],
            draw_slides: opts[:draw_slides],
            back_gap: opts[:back_gap] || 20,
            box_top_inset: opts[:box_top_inset] || 20,
            box_bottom_inset: opts[:box_bottom_inset] || 20,
            type: opts[:type], frame_width: opts[:frame_width], frame_thickness: opts[:frame_thickness],
            tenon: opts[:tenon], panel_gap: opts[:panel_gap], panel_thickness: opts[:panel_thickness],
            groove_depth: opts[:groove_depth]
          }
        end

        configs
      end

      # Высота разделительной полки над ящиками (в мм от низа боковин)
      def separator_shelf_z(top_of_bottom, inner_h_mm)
        configs =
          if @drawers_positions
            resolve_drawer_configs_for_positions(inner_h_mm)
          else
            @drawers_config
          end

        return nil if configs.empty?

        total_drawers_h = configs.sum { |c| c[:height] }
        top_of_bottom + total_drawers_h
      end
    end
  end
end
