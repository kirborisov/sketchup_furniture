# sketchup_furniture/assemblies/cabinet.rb
# Базовый шкаф — сборка из компонентов

module SketchupFurniture
  module Assemblies
    class Cabinet < Core::Component
      attr_accessor :thickness, :back_thickness
      attr_reader :shelves_config, :sections_config, :support, :drawer_objects
      
      # Доступные части для пропуска
      PARTS = [:bottom, :top, :back, :left_side, :right_side].freeze
      
      def initialize(width, height, depth, name: "Шкаф", thickness: 18, back_thickness: 4)
        super(width, height, depth, name: name)
        @thickness = thickness
        @back_thickness = back_thickness
        
        @shelves_config = []
        @sections_config = []
        @drawers_config = []  # Конфигурация ящиков
        @drawers_positions = nil  # Позиции ящиков (альтернативный режим)
        @drawers_options = {}
        @drawer_objects = []  # Созданные ящики (для анимации)
        @skip_parts = []  # Части которые не строим
        @stretchers_config = nil  # Царги (вместо верхней панели)
        @support = Components::Support::SidesSupport.new  # По умолчанию на боковинах
      end
      
      # === DSL МЕТОДЫ ===
      
      # Пропустить части шкафа
      # skip :bottom, :back, :left_side
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
      
      # Проверить нужно ли строить часть
      def build_part?(part)
        !@skip_parts.include?(part)
      end
      
      # Добавить полку
      def shelf(z_position, adjustable: true)
        @shelves_config << { z: z_position, adjustable: adjustable }
        self
      end
      
      # Добавить несколько полок
      def shelves(*positions)
        positions.flatten.each { |z| shelf(z) }
        self
      end
      
      # Задать секции (вертикальные перегородки)
      def sections(*widths)
        @sections_config = widths.flatten
        self
      end
      
      # === ЯЩИКИ ===
      
      # Добавить один ящик
      # height: высота ящика (мм)
      # slide: тип направляющих (:ball_bearing, :roller, :undermount)
      # soft_close: плавное закрывание
      # draw_slides: рисовать направляющие
      def drawer(height, slide: :ball_bearing, soft_close: false, draw_slides: false, back_gap: 20)
        @drawers_config << {
          height: height,
          slide: slide,
          soft_close: soft_close,
          draw_slides: draw_slides,
          back_gap: back_gap
        }
        self
      end
      
      # Добавить несколько ящиков
      # По количеству:  drawers 3, height: 150
      # По позициям Z:   drawers [0, 150, 350]  (высоты вычисляются автоматически)
      # back_gap: зазор между задней стенкой ящика и шкафа (мм, по умолчанию 20)
      def drawers(count_or_positions, height: nil, slide: :ball_bearing, soft_close: false, draw_slides: false, back_gap: 20)
        if count_or_positions.is_a?(Array)
          @drawers_positions = count_or_positions
          @drawers_options = { slide: slide, soft_close: soft_close, draw_slides: draw_slides, back_gap: back_gap }
        else
          count_or_positions.times { drawer(height, slide: slide, soft_close: soft_close, draw_slides: draw_slides, back_gap: back_gap) }
        end
        self
      end
      
      # Цоколь — боковины до пола, дно поднято
      def plinth(height, front_panel: false)
        @support = Components::Support::PlinthSupport.new(height, front_panel: front_panel)
        self
      end
      
      # Ножки — боковины короче
      def legs(height, count: nil, adjustable: true)
        leg_count = count || Components::Support::LegsSupport.calculate_count(@width)
        @support = Components::Support::LegsSupport.new(height, count: leg_count, adjustable: adjustable)
        self
      end
      
      # Царги вместо сплошного верха
      # mode: :standard — горизонтально (передняя + задняя)
      #        :sink    — на ребро (передняя + задняя)
      # width: ширина царги (мм)
      def stretchers(mode = :standard, width: 80)
        @stretchers_config = { mode: mode, width: width }
        skip(:top)
        self
      end
      
      # На боковинах (стандарт, по умолчанию)
      def on_sides
        @support = Components::Support::SidesSupport.new
        self
      end
      
      # === ПОСТРОЕНИЕ ===
      
      def build_geometry
        t = @thickness.mm
        bt = @back_thickness.mm
        
        # Смещения от опоры
        support_z = @support.side_start_z.mm      # откуда начинаются боковины
        bottom_offset = @support.bottom_z.mm      # где дно
        side_reduction = @support.side_height_reduction  # насколько короче боковины
        
        # Высота боковин (может быть уменьшена для ножек)
        side_height = @height - side_reduction
        
        # Внутренние размеры (в мм)
        inner_w_mm = @width - 2 * @thickness
        inner_d_mm = @depth - @back_thickness
        
        # Внутренняя высота: от верха дна до низа крышки
        # Учитывает цоколь/ножки правильно
        top_of_bottom = @support.bottom_z + @thickness
        bottom_of_top = @support.side_start_z + side_height - @thickness
        inner_h_mm = bottom_of_top - top_of_bottom
        
        # Внутренние размеры (конвертированы для SketchUp)
        inner_w = inner_w_mm.mm
        inner_d = inner_d_mm.mm
        inner_h = inner_h_mm.mm
        
        # Позиция
        ox = (@context&.x || 0).mm
        oy = (@context&.y || 0).mm
        oz = (@context&.z || 0).mm
        
        # Левая боковина
        if build_part?(:left_side)
          build_side(:left, ox, oy, oz + support_z, inner_d, side_height)
        end
        
        # Правая боковина
        if build_part?(:right_side)
          build_side(:right, ox + @width.mm - t, oy, oz + support_z, inner_d, side_height)
        end
        
        # Дно (с учётом смещения от опоры)
        if build_part?(:bottom)
          build_horizontal(:bottom, ox + t, oy, oz + bottom_offset, inner_w, inner_d)
        end
        
        # Верх
        if build_part?(:top)
          build_horizontal(:top, ox + t, oy, oz + support_z + side_height.mm - t, inner_w, inner_d)
        end
        
        # Царги (вместо верхней панели)
        build_stretchers(ox + t, oy, oz + support_z, inner_w, inner_d, side_height) if @stretchers_config
        
        # Задняя стенка
        if build_part?(:back)
          back_height = side_height
          build_back(ox, oy + inner_d, oz + support_z, back_height)
        end
        
        # Секции (перегородки)
        build_sections(ox, oy, oz + bottom_offset + t, inner_d, inner_h) if @sections_config.any?
        
        # Полки (относительно дна)
        build_shelves(ox, oy, oz + bottom_offset, inner_w, inner_d)
        
        # Ящики
        build_drawers(ox, oy, oz + bottom_offset + t, inner_w_mm, inner_d_mm) if @drawers_config.any? || @drawers_positions
        
        # Геометрия опоры (если есть)
        if @support.has_geometry?
          @support.build(@group, x: ox, y: oy, z: oz, width: @width.mm, depth: @depth.mm, thickness: t)
        end
        
        # Фурнитура от опоры
        @support.hardware.each do |hw|
          add_hardware(**hw)
        end
      end
      
      private
      
      def build_side(position, x, y, z, depth, height)
        Primitives::Panel.side(
          @group, x: x, y: y, z: z,
          height: height.mm,
          depth: depth,
          thickness: @thickness.mm
        )
        
        add_cut(
          name: position == :left ? "Боковина левая" : "Боковина правая",
          length: height,
          width: @depth - @back_thickness,
          thickness: @thickness,
          material: "ЛДСП"
        )
      end
      
      def build_horizontal(position, x, y, z, width, depth)
        Primitives::Panel.horizontal(
          @group, x: x, y: y, z: z,
          width: width,
          depth: depth,
          thickness: @thickness.mm
        )
        
        add_cut(
          name: position == :top ? "Верх" : "Дно",
          length: @width - 2 * @thickness,
          width: @depth - @back_thickness,
          thickness: @thickness,
          material: "ЛДСП"
        )
      end
      
      def build_back(x, y, z, height)
        Primitives::Panel.back(
          @group, x: x, y: y, z: z,
          width: @width.mm,
          height: height.mm,
          thickness: @back_thickness.mm
        )
        
        add_cut(
          name: "Задняя стенка",
          length: height,
          width: @width,
          thickness: @back_thickness,
          material: "ДВП"
        )
      end
      
      def build_sections(ox, oy, oz, inner_d, inner_h)
        t = @thickness.mm
        
        # Высота перегородки = внутренняя высота (от дна до верха)
        side_height = @height - @support.side_height_reduction
        top_of_bottom = @support.bottom_z + @thickness
        bottom_of_top = @support.side_start_z + side_height - @thickness
        panel_height = bottom_of_top - top_of_bottom
        panel_depth = @depth - @back_thickness
        
        # Вычисляем реальные ширины секций
        section_widths = resolve_sections
        
        x_pos = ox + t
        section_widths[0..-2].each_with_index do |sec_w, i|
          x_pos += sec_w.mm
          
          Primitives::Panel.side(
            @group, x: x_pos, y: oy, z: oz,
            height: inner_h,
            depth: inner_d,
            thickness: t
          )
          
          add_cut(
            name: "Перегородка #{i + 1}",
            length: panel_height,
            width: panel_depth,
            thickness: @thickness,
            material: "ЛДСП"
          )
          
          x_pos += t
        end
      end
      
      def build_shelves(ox, oy, oz, inner_w, inner_d)
        t = @thickness.mm
        section_widths = resolve_sections
        
        if section_widths.empty?
          # Одна секция на всю ширину
          @shelves_config.each_with_index do |shelf_cfg, i|
            build_shelf(ox + t, oy, oz + shelf_cfg[:z].mm, inner_w, inner_d, i + 1, 1)
          end
        else
          # Несколько секций
          x_pos = ox + t
          section_widths.each_with_index do |sec_w, sec_i|
            @shelves_config.each_with_index do |shelf_cfg, shi|
              build_shelf(x_pos, oy, oz + shelf_cfg[:z].mm, sec_w.mm, inner_d, shi + 1, sec_i + 1)
            end
            x_pos += sec_w.mm + t
          end
        end
      end
      
      def build_shelf(x, y, z, width, depth, shelf_num, section_num)
        Primitives::Panel.horizontal(
          @group, x: x, y: y, z: z,
          width: width,
          depth: depth,
          thickness: @thickness.mm
        )
        
        shelf_w = (width / 1.mm).round
        add_cut(
          name: "Полка #{section_num}-#{shelf_num}",
          length: shelf_w,
          width: @depth - @back_thickness,
          thickness: @thickness,
          material: "ЛДСП"
        )
        
        add_hardware(type: :shelf_support, quantity: 4)
      end
      
      # Построить царги
      def build_stretchers(x, y, z, inner_w, inner_d, side_height)
        t = @thickness.mm
        sw = @stretchers_config[:width]   # ширина царги (мм)
        inner_w_mm = @width - 2 * @thickness
        
        # Верх боковин
        top_z = z + side_height.mm
        
        case @stretchers_config[:mode]
        when :standard
          # Горизонтальные царги (лежат плашмя)
          # Передняя
          Primitives::Panel.horizontal(
            @group, x: x, y: y, z: top_z - t,
            width: inner_w, depth: sw.mm, thickness: t
          )
          # Задняя
          Primitives::Panel.horizontal(
            @group, x: x, y: y + inner_d - sw.mm, z: top_z - t,
            width: inner_w, depth: sw.mm, thickness: t
          )
          
        when :sink
          # Царги на ребро (стоят вертикально)
          # depth=t (тонкая 18мм по Y), thickness=sw (высота 80мм по Z)
          # Передняя
          Primitives::Panel.horizontal(
            @group, x: x, y: y, z: top_z - sw.mm,
            width: inner_w, depth: t, thickness: sw.mm
          )
          # Задняя
          Primitives::Panel.horizontal(
            @group, x: x, y: y + inner_d - t, z: top_z - sw.mm,
            width: inner_w, depth: t, thickness: sw.mm
          )
        end
        
        # Раскрой
        add_cut(
          name: "Царга передняя",
          length: inner_w_mm,
          width: sw,
          thickness: @thickness,
          material: "ЛДСП"
        )
        add_cut(
          name: "Царга задняя",
          length: inner_w_mm,
          width: sw,
          thickness: @thickness,
          material: "ЛДСП"
        )
      end
      
      # Построить ящики
      def build_drawers(ox, oy, oz, inner_w_mm, inner_d_mm)
        # Преобразовать позиции в конфиг (если заданы по позициям)
        resolve_drawer_positions if @drawers_positions
        return if @drawers_config.empty?
        
        # Если есть дно, ящики начинаются выше него
        # Если дна нет (skip :bottom), ящики начинаются от support.bottom_z
        start_z = if build_part?(:bottom)
          @support.bottom_z + @thickness
        else
          @support.bottom_z
        end
        
        @drawers_config.each_with_index do |cfg, i|
          drawer = Components::Drawers::Drawer.new(
            cfg[:height],
            cabinet_width: inner_w_mm,
            cabinet_depth: @depth - @back_thickness,
            name: "#{@name} ящик #{i + 1}",
            slide_type: cfg[:slide],
            soft_close: cfg[:soft_close],
            draw_slides: cfg[:draw_slides],
            back_gap: cfg[:back_gap] || 20
          )
          
          drawer_context = @context.offset(
            dx: @thickness,
            dy: 0,
            dz: start_z + drawer_z_offset(i)
          )
          
          drawer.build(drawer_context)
          
          # Собираем детали и фурнитуру
          @cut_items.concat(drawer.all_cut_items)
          @hardware_items.concat(drawer.all_hardware_items)
          
          # Сохраняем для анимации
          @drawer_objects << drawer
        end
      end
      
      # Смещение ящика по Z (от дна шкафа)
      def drawer_z_offset(index)
        if @drawers_config[index] && @drawers_config[index][:z_offset]
          @drawers_config[index][:z_offset]
        else
          offset = 0
          @drawers_config[0...index].each do |cfg|
            offset += cfg[:height]
          end
          offset
        end
      end
      
      # Преобразовать позиции ящиков в конфиг с высотами
      def resolve_drawer_positions
        positions = @drawers_positions
        opts = @drawers_options
        
        # Внутренняя высота для расчёта последнего ящика
        side_height = @height - @support.side_height_reduction
        top_of_bottom = @support.bottom_z + @thickness
        bottom_of_top = @support.side_start_z + side_height - @thickness
        inner_h = bottom_of_top - top_of_bottom
        
        positions.each_with_index do |pos, i|
          h = if i < positions.length - 1
            positions[i + 1] - pos
          else
            inner_h - pos
          end
          
          @drawers_config << {
            height: h,
            z_offset: pos,
            slide: opts[:slide],
            soft_close: opts[:soft_close],
            draw_slides: opts[:draw_slides],
            back_gap: opts[:back_gap] || 20
          }
        end
        
        @drawers_positions = nil
      end
      
      # Преобразовать проценты в реальные ширины
      def resolve_sections
        return [] if @sections_config.empty?
        
        inner_w = @width - 2 * @thickness
        num_partitions = @sections_config.length - 1
        partitions_w = num_partitions * @thickness
        available_w = inner_w - partitions_w
        
        @sections_config.map do |sec|
          if sec.is_a?(String) && sec.end_with?("%")
            percent = sec.to_f
            (available_w * percent / 100.0).round
          else
            sec.to_i
          end
        end
      end
    end
  end
end
