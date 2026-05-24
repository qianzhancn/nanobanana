# frozen_string_literal: true

require 'json'
require 'sketchup.rb'

module NanoBanana
  module CadArchitectBuilder
    PLUGIN_NAME = 'CAD 墙门窗/地板一键建模'.freeze

    # 数据格式示例：
    # {
    #   "walls": [{"start":[0,0], "end":[5000,0], "thickness":240, "height":2800}],
    #   "doors": [{"wall_index":0, "offset":900, "width":900, "height":2100, "sill":0}],
    #   "windows": [{"wall_index":0, "offset":2500, "width":1500, "height":1500, "sill":900}],
    #   "floor": {"boundary": [[0,0],[5000,0],[5000,4000],[0,4000]], "tile":{"w":600, "h":600, "gap":2, "thickness":12}}
    # }

    def self.mm_to_inch(v)
      v.to_f.mm
    end

    def self.parse_model_data(json_str)
      JSON.parse(json_str)
    rescue JSON::ParserError => e
      UI.messagebox("JSON 解析失败: #{e.message}")
      nil
    end

    def self.ask_json_input
      prompts = ['请粘贴 CAD 识别后的 JSON 数据（毫米单位）:']
      defaults = ['{"walls":[],"doors":[],"windows":[],"floor":{}}']
      input = UI.inputbox(prompts, defaults, '导入墙体/门窗/地板数据')
      return nil unless input

      input[0]
    end

    def self.unit_perp(v)
      perp = Geom::Vector3d.new(-v.y, v.x, 0)
      perp.normalize!
      perp
    end

    def self.build_walls(group, walls)
      walls.each_with_index.map do |w, idx|
        sp = Geom::Point3d.new(mm_to_inch(w['start'][0]), mm_to_inch(w['start'][1]), 0)
        ep = Geom::Point3d.new(mm_to_inch(w['end'][0]), mm_to_inch(w['end'][1]), 0)
        dir = ep - sp
        next if dir.length < 0.001

        wall_thickness = mm_to_inch(w.fetch('thickness', 240))
        wall_height = mm_to_inch(w.fetch('height', 2800))
        perp = unit_perp(dir)
        half = wall_thickness / 2.0

        p1 = sp.offset(perp, half)
        p2 = ep.offset(perp, half)
        p3 = ep.offset(perp.reverse, half)
        p4 = sp.offset(perp.reverse, half)

        face = group.entities.add_face(p1, p2, p3, p4)
        face.pushpull(wall_height) if face

        {
          index: idx,
          start: sp,
          end: ep,
          dir: dir,
          perp: perp,
          thickness: wall_thickness,
          height: wall_height
        }
      end.compact
    end

    def self.cut_opening(group_entities, wall, opening)
      offset = mm_to_inch(opening.fetch('offset', 0))
      width = mm_to_inch(opening.fetch('width', 900))
      height = mm_to_inch(opening.fetch('height', 2100))
      sill = mm_to_inch(opening.fetch('sill', 0))

      dir = wall[:dir]
      dir.normalize!
      perp = wall[:perp]
      half = wall[:thickness] / 2.0

      center = wall[:start].offset(dir, offset)
      left = center.offset(dir.reverse, width / 2.0)
      right = center.offset(dir, width / 2.0)

      z0 = sill
      z1 = sill + height

      p1 = Geom::Point3d.new(left.x + perp.x * half, left.y + perp.y * half, z0)
      p2 = Geom::Point3d.new(right.x + perp.x * half, right.y + perp.y * half, z0)
      p3 = Geom::Point3d.new(right.x + perp.x * half, right.y + perp.y * half, z1)
      p4 = Geom::Point3d.new(left.x + perp.x * half, left.y + perp.y * half, z1)

      face = group_entities.add_face(p1, p2, p3, p4)
      return unless face

      # 负向拉伸穿透墙体
      face.pushpull(-wall[:thickness] - 1.mm)
    end

    def self.build_openings(group, walls_meta, doors, windows)
      doors.each do |door|
        wi = door.fetch('wall_index', -1)
        wall = walls_meta[wi]
        next unless wall

        cut_opening(group.entities, wall, door)
      end

      windows.each do |win|
        wi = win.fetch('wall_index', -1)
        wall = walls_meta[wi]
        next unless wall

        cut_opening(group.entities, wall, win)
      end
    end

    def self.build_floor(group, floor)
      return unless floor.is_a?(Hash)

      boundary = floor['boundary'] || []
      return if boundary.length < 3

      pts = boundary.map { |xy| Geom::Point3d.new(mm_to_inch(xy[0]), mm_to_inch(xy[1]), 0) }
      face = group.entities.add_face(pts)
      return unless face

      tile = floor['tile'] || {}
      t = mm_to_inch(tile.fetch('thickness', 10))
      face.pushpull(-t)

      mat_name = "Tile_#{tile.fetch('w', 600)}x#{tile.fetch('h', 600)}"
      mat = Sketchup.active_model.materials[mat_name] || Sketchup.active_model.materials.add(mat_name)
      mat.color = Sketchup::Color.new(220, 220, 220)
      face.material = mat
      face.back_material = mat
    end

    def self.build_from_json(json_str)
      data = parse_model_data(json_str)
      return unless data

      model = Sketchup.active_model
      model.start_operation('一键生成墙门窗地板', true)
      group = model.active_entities.add_group
      group.name = 'CAD_Build_Result'

      walls = data['walls'] || []
      doors = data['doors'] || []
      windows = data['windows'] || []
      floor = data['floor'] || {}

      walls_meta = build_walls(group, walls)
      build_openings(group, walls_meta, doors, windows)
      build_floor(group, floor)

      model.commit_operation
      UI.messagebox("建模完成！墙体: #{walls_meta.size}，门: #{doors.size}，窗: #{windows.size}")
    rescue StandardError => e
      model.abort_operation
      UI.messagebox("建模失败: #{e.message}\n#{e.backtrace.first}")
    end

    def self.run
      json_str = ask_json_input
      return unless json_str && !json_str.strip.empty?

      build_from_json(json_str)
    end

    unless file_loaded?(__FILE__)
      UI.menu('Plugins').add_item(PLUGIN_NAME) { run }
      file_loaded(__FILE__)
    end
  end
end
