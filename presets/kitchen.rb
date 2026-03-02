# sketchup_furniture/presets/kitchen.rb
# Кухня — пресет с нижним и верхним рядом шкафов
#
# Использование:
#   Kitchen.new "Кухня" do
#     lower depth: 560, height: 820 do
#       plinth 100
#       cabinet 600, name: "Мойка" do ... end
#     end
#     upper depth: 300, height: 600, at: 1400 do
#       cabinet 600, name: "Сушка" do ... end
#     end
#     countertop 38, overhang: 30
#   end.build

module SketchupFurniture
  module Presets
    class Kitchen < Core::Component
      attr_reader :lower_cabinets, :upper_cabinets, :lower_depth, :upper_depth
      
      def initialize(name = "Кухня", &block)
        super(0, 0, 0, name: name)
        
        @lower_cabinets = []
        @upper_cabinets = []
        
        # Параметры рядов
        @lower_depth = 560
        @lower_height = 720
        @upper_depth = 300
        @upper_height = 600
        @upper_z = 1400
        
        # Опора по умолчанию для нижнего ряда
        @lower_support_type = nil
        @lower_support_height = 0
        @lower_legs_options = {}
        
        # Столешница
        @countertop_config = nil
        @countertop_obj = nil
        
        # Текущий ряд (для DSL)
        @_current_row = nil
        
        # Вывод
        @cut_list = Output::CutList.new
        @hardware_list = Output::HardwareList.new
        @dimensions = Utils::Dimensions.new
        
        instance_eval(&block) if block_given?
      end
      
      # === DSL: РЯДЫ ===
      
      # Нижний ряд
      # depth: глубина шкафов (мм)
      # height: высота шкафов включая опору (мм)
      def lower(depth: 560, height: 720, &block)
        @lower_depth = depth
        @lower_height = height
        @_current_row = :lower
        instance_eval(&block) if block_given?
        @_current_row = nil
      end
      
      # Верхний ряд
      # depth: глубина шкафов (мм)
      # height: высота шкафов (мм)
      # at: высота от пола (мм)
      def upper(depth: 300, height: 600, at: 1400, &block)
        @upper_depth = depth
        @upper_height = height
        @upper_z = at
        @_current_row = :upper
        instance_eval(&block) if block_given?
        @_current_row = nil
      end
      
      # Шкаф (внутри lower/upper блока)
      # width:   ширина шкафа (мм)
      # height:  опциональная высота именно этого шкафа (по умолчанию = высота ряда)
      # depth:   опциональная глубина этого шкафа (по умолчанию = глубина ряда)
      def cabinet(width, name: nil, height: nil, depth: nil, **options, &block)
        case @_current_row
        when :lower
          effective_height = height || @lower_height
          effective_depth = depth || @lower_depth
          cab = Assemblies::Cabinet.new(width, effective_height, effective_depth, name: name, **options)
          apply_default_support(cab)
          cab.instance_eval(&block) if block_given?
          @lower_cabinets << cab
        when :upper
          effective_height = height || @upper_height
          effective_depth = depth || @upper_depth
          cab = Assemblies::Cabinet.new(width, effective_height, effective_depth, name: name, **options)
          cab.instance_eval(&block) if block_given?
          @upper_cabinets << cab
        else
          puts "Предупреждение: cabinet вызван вне lower/upper блока"
          return nil
        end
        cab
      end
      
      # === DSL: ОПОРА (для нижнего ряда) ===
      
      # Цоколь по умолчанию для всех нижних шкафов
      def plinth(height, **options)
        @lower_support_type = :plinth
        @lower_support_height = height
      end
      
      # Ножки по умолчанию для всех нижних шкафов
      def legs(height, **options)
        @lower_support_type = :legs
        @lower_support_height = height
        @lower_legs_options = options
      end
      
      # === DSL: СТОЛЕШНИЦА ===
      
      # thickness: толщина (мм)
      # overhang: свес спереди (мм)
      # depth: полная глубина (если не указана = lower_depth + overhang)
      def countertop(thickness = 38, overhang: 30, depth: nil)
        @countertop_config = {
          thickness: thickness,
          overhang: overhang,
          depth: depth
        }
      end
      
      # === ПОСТРОЕНИЕ ===
      
      def build(context = nil)
        Tools::DrawerTool.clear
        @context = context || Core::Context.new
        @group = create_group(@name)
        
        build_lower_row
        build_countertop
        build_upper_row
        
        update_overall_dimensions
        collect_outputs
        
        @group
      end
      
      # === ВЫВОД ===
      
      def print_cut_list
        @cut_list.print
      end
      
      def print_hardware_list
        @hardware_list.print
      end
      
      def summary
        puts "\n" + "=" * 60
        puts "КУХНЯ: #{@name}"
        puts "=" * 60
        puts "Габариты: #{@width} × #{@height} × #{@depth} мм"
        puts "Нижних шкафов: #{@lower_cabinets.length}"
        puts "Верхних шкафов: #{@upper_cabinets.length}"
        
        if @countertop_config
          puts "Столешница: #{@countertop_config[:thickness]}мм"
        end
        
        if @lower_cabinets.any? && @upper_cabinets.any? && @countertop_config
          lower_top = @lower_cabinets.map(&:height).max
          backsplash = @upper_z - lower_top - @countertop_config[:thickness]
          puts "Фартук (зазор): #{backsplash} мм"
        end
        
        @cut_list.summary
        @hardware_list.summary
      end
      
      # === РАЗМЕРЫ ===
      
      def show_dimensions(mode = :overview)
        @dimensions.show(self, mode)
        nil
      end
      
      def hide_dimensions
        @dimensions.hide
        puts "Размеры скрыты"
        nil
      end
      
      def dimensions_mode
        @dimensions.mode
      end
      
      # === ЯЩИКИ ===
      
      # Активировать инструмент ящиков (двойной клик)
      def activate_drawer_tool
        Tools::DrawerTool.activate
      end
      
      def all_drawers
        drawers = []
        (@lower_cabinets + @upper_cabinets).each do |cab|
          drawers.concat(cab.drawer_objects) if cab.respond_to?(:drawer_objects)
        end
        drawers
      end
      
      def open_all_drawers(amount: nil)
        all_drawers.each { |d| d.open(amount) }
        puts "Открыто ящиков: #{all_drawers.length}"
      end
      
      def close_all_drawers
        all_drawers.each(&:close)
        puts "Закрыто ящиков: #{all_drawers.length}"
      end

      # Пересобрать один шкаф по имени (без пересборки всей кухни)
      # name — имя шкафа (например "Шкаф 5, ящики")
      # Возвращает новую группу шкафа или nil, если не найден
      def rebuild_cabinet(name)
        cab = find_cabinet_by_name(name)
        unless cab
          puts "Шкаф '#{name}' не найден в описании кухни"
          return nil
        end

        groups = find_all_groups_by_name(Sketchup.active_model.entities, name)
        if groups.empty?
          puts "Группа шкафа '#{name}' не найдена в модели"
          return nil
        end

        # Позиция и родитель — по первой найденной
        group = groups.first
        bounds = group.bounds
        pt = bounds.min
        inch_to_mm = 25.4
        x_mm = pt.x * inch_to_mm
        y_mm = pt.y * inch_to_mm
        z_mm = pt.z * inch_to_mm

        parent_group = group.parent.respond_to?(:parent) && group.parent.parent.is_a?(Sketchup::Group) ? group.parent.parent : nil

        # Собрать все группы для удаления: по имени + все, чьи bounds внутри шкафа (ящики/двери — соседи корпуса)
        to_erase = groups.dup
        groups.each do |cab_group|
          next unless cab_group.valid?
          to_erase.concat(groups_inside_bounds(cab_group.parent.entities, cab_group.bounds, exclude: groups))
        end
        to_erase.uniq!

        # Удалить размеры, попадающие в bounds этого шкафа
        @dimensions.remove_dimensions_in_bounds(group.bounds) if group.valid?

        to_erase.each do |g|
          Tools::DrawerTool.unregister_group_and_children(g)
          g.erase! if g.valid?
        end

        cab.clear_build_artifacts
        cab_context = Core::Context.new(
          x: x_mm, y: y_mm, z: z_mm,
          parent: parent_group,
          config: SketchupFurniture.config
        )
        new_group = cab.build(cab_context)
        # Очистить невалидные записи и переактивировать инструмент — двойной клик снова работает
        Tools::DrawerTool.unregister_invalid
        activate_drawer_tool
        new_group
      end

      private
      
      # Найти шкаф по имени в lower/upper
      def find_cabinet_by_name(name)
        (@lower_cabinets + @upper_cabinets).find { |c| c.name == name }
      end

      # Рекурсивный поиск первой группы по имени
      def find_group_by_name(entities, name)
        entities.each do |e|
          return e if e.is_a?(Sketchup::Group) && e.name == name
        end
        entities.each do |e|
          next unless e.is_a?(Sketchup::Group)
          found = find_group_by_name(e.entities, name)
          return found if found
        end
        nil
      end

      # Рекурсивный поиск всех групп с данным именем
      def find_all_groups_by_name(entities, name)
        out = []
        entities.each do |e|
          out << e if e.is_a?(Sketchup::Group) && e.name == name
        end
        entities.each do |e|
          next unless e.is_a?(Sketchup::Group)
          out.concat(find_all_groups_by_name(e.entities, name))
        end
        out
      end

      # Группы из entities, чьи bounds полностью внутри заданного bbox (ящики/двери шкафа)
      # exclude — группы не учитывать (сам шкаф и т.п.)
      def groups_inside_bounds(entities, bounds, exclude: [])
        tol = 1.0  # дюймы, запас для фасадов
        bmin = bounds.min
        bmax = bounds.max
        out = []
        entities.each do |e|
          next unless e.is_a?(Sketchup::Group) && e.valid?
          next if exclude.include?(e)
          gmin = e.bounds.min
          gmax = e.bounds.max
          next unless gmin.x >= bmin.x - tol && gmax.x <= bmax.x + tol &&
                      gmin.y >= bmin.y - tol && gmax.y <= bmax.y + tol &&
                      gmin.z >= bmin.z - tol && gmax.z <= bmax.z + tol
          out << e
        end
        out
      end

      # Применить опору по умолчанию к шкафу
      def apply_default_support(cab)
        case @lower_support_type
        when :plinth
          cab.plinth(@lower_support_height)
        when :legs
          cab.legs(@lower_support_height, **@lower_legs_options)
        end
      end
      
      # Построить нижний ряд
      def build_lower_row
        x_pos = 0
        @lower_cabinets.each do |cab|
          cab_context = @context.offset(dx: x_pos)
          cab.build(cab_context)
          x_pos += cab.width
        end
      end
      
      # Построить верхний ряд
      # Задние стенки верхних шкафов выравниваются с нижними
      def build_upper_row
        x_pos = 0
        y_offset = @lower_depth - @upper_depth
        @upper_cabinets.each do |cab|
          cab_context = @context.offset(dx: x_pos, dy: y_offset, dz: @upper_z)
          cab.build(cab_context)
          x_pos += cab.width
        end
      end
      
      # Построить столешницу
      def build_countertop
        return unless @countertop_config
        return if @lower_cabinets.empty?
        
        lower_width = @lower_cabinets.sum(&:width)
        lower_top_z = @lower_cabinets.map(&:height).max
        
        ct_overhang = @countertop_config[:overhang]
        ct_total_depth = @countertop_config[:depth] || (@lower_depth + ct_overhang)
        
        @countertop_obj = Components::Body::Countertop.new(
          width: lower_width,
          depth: ct_total_depth,
          thickness: @countertop_config[:thickness],
          overhang: ct_overhang
        )
        
        # Создаём группу для столешницы
        entities = @context.entities
        ct_group = entities.add_group
        ct_group.name = "Столешница"
        
        ox = (@context&.x || 0).mm
        oy = (@context&.y || 0).mm
        oz = (@context&.z || 0).mm
        
        @countertop_obj.build(ct_group, x: ox, y: oy, z: oz + lower_top_z.mm)
      end
      
      # Обновить общие габариты
      def update_overall_dimensions
        lower_w = @lower_cabinets.sum(&:width)
        upper_w = @upper_cabinets.sum(&:width)
        @width = [lower_w, upper_w, 0].max
        
        lower_h = @lower_cabinets.any? ? @lower_cabinets.map(&:height).max : 0
        ct_h = @countertop_config ? @countertop_config[:thickness] : 0
        upper_top = @upper_cabinets.any? ? @upper_z + @upper_height : 0
        @height = [lower_h + ct_h, upper_top].max
        
        @depth = [@lower_depth, @upper_depth].max
      end
      
      # Собрать раскрой и фурнитуру
      def collect_outputs
        @cut_list.clear
        @hardware_list.clear
        
        (@lower_cabinets + @upper_cabinets).each do |cab|
          @cut_list.add(cab.all_cut_items)
          @hardware_list.add(cab.all_hardware_items)
        end
        
        # Столешница
        if @countertop_obj
          @cut_list.add([@countertop_obj.cut_item(@name)])
        end
      end
    end
  end
end

# Алиас для удобства
Kitchen = SketchupFurniture::Presets::Kitchen
