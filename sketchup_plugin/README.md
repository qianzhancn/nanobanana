# SketchUp 插件：CAD 墙门窗/地板一键建模

## 功能
- 根据 CAD 识别后的墙线数据自动拉出墙体。
- 按门窗参数（墙索引、偏移、宽高、窗台高）一次性开洞。
- 根据地面边界生成地板，并按瓷砖参数应用基础材质。

## 安装
1. 打开 SketchUp，进入 `Window > Extension Manager`（或直接使用 Ruby 控制台加载）。
2. 将 `cad_architect_builder.rb` 复制到 SketchUp 的 `Plugins` 目录。
3. 重启 SketchUp。
4. 菜单 `Plugins` 中会出现 **CAD 墙门窗/地板一键建模**。

## 使用
1. 点击插件菜单。
2. 粘贴 JSON（参考 `example_input.json`，单位为毫米）。
3. 插件会自动创建一个 `CAD_Build_Result` 组并完成建模。

## JSON 字段
- `walls[]`
  - `start`: `[x, y]`
  - `end`: `[x, y]`
  - `thickness`: 墙厚（mm）
  - `height`: 墙高（mm）
- `doors[] / windows[]`
  - `wall_index`: 所属墙体索引（从 0 开始）
  - `offset`: 沿墙线的中心偏移（mm）
  - `width`, `height`: 洞口尺寸（mm）
  - `sill`: 离地高度（mm，门通常为 0）
- `floor`
  - `boundary`: 地面轮廓点数组
  - `tile`: `w/h/gap/thickness`（目前 `gap` 预留，后续可扩展切缝贴图）

## 说明
- 这是可直接二次开发的基础版本，适合先打通“CAD 数据 -> SU 快速出模型”的流程。
- 后续可以加：
  - 自动识别 CAD 图层（墙/门/窗）
  - 门窗实体族库（不只是开洞）
  - 真正按瓷砖尺寸阵列分缝
