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
      attr_reader :lower_cabinets, :upper_cabinets
      
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
      def cabinet(width, name: nil, **options, &block)
        case @_current_row
        when :lower
          cab = Assemblies::Cabinet.new(width, @lower_height, @lower_depth, name: name, **options)
          apply_default_support(cab)
          cab.instance_eval(&block) if block_given?
          @lower_cabinets << cab
        when :upper
          cab = Assemblies::Cabinet.new(width, @upper_height, @upper_depth, name: name, **options)
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
      
      private
      
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
