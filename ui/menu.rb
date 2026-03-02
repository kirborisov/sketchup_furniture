# sketchup_furniture/ui/menu.rb
# Меню и кнопка «Обновить из YAML»
#
# Если краш при обновлении — установи SKIP_DIMENSIONS_ON_RELOAD = true
# (размеры можно добавить вручную: $kitchen.show_dimensions(:sections))

# true = не добавлять размеры при открытии/обновлении из YAML (меньше риск краша)
SKIP_DIMENSIONS_ON_RELOAD = true

require 'yaml'

module SketchupFurniture
  module UI
    class Menu
      class << self
        # Путь к YAML по умолчанию (относительно плагина)
        def default_yaml_path
          File.join(SKETCHUP_FURNITURE_PATH, 'examples', 'kitchen.yaml')
        end

        # Текущий путь к проекту (можно задать вручную)
        def project_path
          @project_path ||= default_yaml_path
        end

        def project_path=(path)
          @project_path = path
        end

        def setup
          return if @menu_loaded
          @menu_loaded = true

          # API принимает только английские имена; в русском интерфейсе отображается как «Расширения»
          menu = begin
            ::UI.menu('Extensions')
          rescue ArgumentError
            ::UI.menu('Plugins')
          end
          menu.add_item('Мебель: Обновить из YAML') { reload_from_yaml }
          menu.add_item('Мебель: Открыть YAML...') { open_and_reload }
        end

        def reload_from_yaml
          path = project_path
          unless File.exist?(path)
            ::UI.messagebox("Файл не найден:\n#{path}\n\nЗадай путь: SketchupFurniture::UI::Menu.project_path = 'путь/к/kitchen.yaml'")
            return
          end
          do_reload(path)
        end

        def open_and_reload
          path = ::UI.openpanel('Выбери YAML проекта', File.dirname(project_path), '*.yaml')
          return if path.nil? || path.empty?
          self.project_path = path
          do_reload(path)
        end

        def do_reload(path)
          model = Sketchup.active_model

          # Убрать старые размеры только если размеры при перезагрузке включены (иначе не трогаем)
          unless defined?(SKIP_DIMENSIONS_ON_RELOAD) && SKIP_DIMENSIONS_ON_RELOAD
            begin
              $kitchen.hide_dimensions if $kitchen.respond_to?(:hide_dimensions)
            rescue => _e
            end
          end

          begin
            names_to_erase = names_from_yaml(path)

            # Операция 1: удаление — отдельно, без disable_undo (меньше риск краша)
            model.start_operation('Удалить старую кухню', false)
            erase_groups_by_names(model.entities, names_to_erase)
            model.commit_operation

            # Операция 2: построение
            model.start_operation('Построить кухню из YAML', false)
            SketchupFurniture.reset_config
            kitchen = Loaders::KitchenYaml.load(path)
            kitchen.build

            $kitchen = kitchen
            kitchen.summary

            # Размеры — отдельная операция (можно отключить при крашах)
            model.commit_operation
            unless defined?(SKIP_DIMENSIONS_ON_RELOAD) && SKIP_DIMENSIONS_ON_RELOAD
              begin
                model.start_operation('Добавить размеры', false)
                kitchen.show_dimensions(:sections)
                model.commit_operation
              rescue => dim_err
                model.abort_operation
                puts "Размеры не добавлены: #{dim_err.message}"
              end
            end

            kitchen.activate_drawer_tool
            puts "Кухня обновлена из #{path}"
          rescue => e
            model.abort_operation
            ::UI.messagebox("Ошибка: #{e.message}\n\n#{e.backtrace.first(5).join("\n")}")
            puts e.backtrace.join("\n")
          end
        end

        def names_from_yaml(path)
          data = YAML.load_file(path)
          data = {} if data.nil?
          names = ['Кухня', 'Столешница']
          %w[lower upper].each do |row|
            row_data = data[row] || data[row.to_sym]
            next unless row_data
            cabs = row_data['cabinets'] || row_data[:cabinets] || []
            cabs.each do |c|
              n = c['name'] || c[:name]
              names << n if n
            end
          end
          names.uniq
        end

        # Удаляем только корневые группы по имени (вся кухня = одна группа «Кухня»).
        # Меньше операций — меньше риск нативного краша при массовом erase.
        def erase_groups_by_names(entities, names)
          to_erase = entities.select { |e| e.is_a?(Sketchup::Group) && names.include?(e.name) && e.valid? }
          return if to_erase.empty?
          to_erase.each { |g| safe_unregister(g) }
          entities.erase_entities(to_erase)
        end

        def safe_unregister(group)
          Tools::DrawerTool.unregister_group_and_children(group)
        rescue => _e
          # Игнорируем — unregister не должен ломать процесс
        end
      end
    end
  end
end
