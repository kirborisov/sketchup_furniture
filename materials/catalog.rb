# furniture/materials/catalog.rb
# Каталог материалов

module SketchupFurniture
  module Materials
    CATALOG = {
      # ЛДСП
      ldsp_16: { name: "ЛДСП", thickness: 16, type: :panel },
      ldsp_18: { name: "ЛДСП", thickness: 18, type: :panel },
      ldsp_22: { name: "ЛДСП", thickness: 22, type: :panel },
      
      # ДВП
      dvp_3: { name: "ДВП", thickness: 3, type: :back },
      dvp_4: { name: "ДВП", thickness: 4, type: :back },
      dvp_6: { name: "ДВП", thickness: 6, type: :back },
      
      # МДФ
      mdf_16: { name: "МДФ", thickness: 16, type: :front },
      mdf_18: { name: "МДФ", thickness: 18, type: :front },
      mdf_19: { name: "МДФ", thickness: 19, type: :front },
      
      # Фанера
      plywood_10: { name: "Фанера", thickness: 10, type: :panel },
      plywood_15: { name: "Фанера", thickness: 15, type: :panel },
      plywood_18: { name: "Фанера", thickness: 18, type: :panel }
    }
    
    # Стандартные размеры листов
    SHEET_SIZES = {
      "ЛДСП" => { width: 2800, height: 2070 },
      "ДВП"  => { width: 2745, height: 1700 },
      "МДФ"  => { width: 2800, height: 2070 },
      "Фанера" => { width: 1525, height: 1525 }
    }
    
    def self.get(key)
      CATALOG[key.to_sym]
    end
    
    def self.sheet_size(material_name)
      SHEET_SIZES[material_name] || { width: 2500, height: 1250 }
    end
  end
end
