# 《寒潮清单》美术设定｜许知夏 v02

## 身份与状态

- 素材 ID：`ART_CHAR_001`
- 版本：`v02`
- 角色：许知夏（第一季主角）
- 资产类型：2D 精细像素画人物设定稿，非可运行精灵图、非动画帧
- 设定决定：采用 v02 作为主角外观基准；正式运行素材尚待生产及测试
- 来源：原创 AI 生成设定，用户提交的侧面像素人物图仅作为画风与像素质量参考，不得描摹原人物造型作为商业素材

## 固定人物设定

- 年龄观感：24–26 岁的普通中国都市女性，冷静、警觉、擅长提前规划生活物资
- 发型：深栗棕色低马尾，略蓬松，轻微偏分刘海，右侧小号琥珀色发夹
- 五官：自然肤色、棕色眼睛，面部表情沉静，不偏幼态或夸张动漫脸
- 服装：蓝灰色短款连帽工装外套，帽里低饱和锈橙色；内搭深橄榄绿色上衣
- 下装：深褐灰色直筒工装裤，膝部局部磨损补强；旧棕色低帮鞋
- 配件：小型苔绿色帆布斜挎工具包、细红绳手环
- 禁止：大面积军装装备、科幻盔甲、明显制服胸牌、鲜艳高饱和配色、夸张武器

## 视觉语言

- 2D 侧视横版游戏、细腻手工像素画风；轮廓清晰、像素块边界清楚、低饱和灰棕主调
- 人体比例接近真实成年人，约七头身；以 960×540 游戏视口中的清晰轮廓为目标
- 以蓝灰、土褐、橄榄绿和少量锈橙为主色，不能在不同角度中随意改变服装版型
- 背景与 UI 的暖冷色变化由天气和剧情决定，角色基础服装颜色保持固定

## 交付画面

- 一张近景正面面容图
- 全身正面、左侧面、右侧面、背面四视图
- 所有全身视角须从头到脚完整入画；相同身高、服装轮廓和配饰位置

## 使用限制及后续工序

1. `v02` 是**设定基准**，不是 Godot 可直接使用的透明 PNG sprite。
2. 开发 Agent 只能将其登记至 `素材库/美术设定集/01-角色/`，并更新素材台账与离线画廊。
3. 不能覆盖原有 `v01`，应并存保留以便追溯。
4. 不得把图中的五个展示区域直接裁切后宣布行走动画完成；精灵图需要统一像素画布、透明背景、轮廓修正、碰撞盒与动画帧一致性测试。
5. 后续角色扩展先制作站立正侧面、走路循环和背包持物动作，再生成剧情表情及冬季服装版本。

## 生成提示词摘要

Original female apocalypse survival protagonist; fine handcrafted 2D pixel art, muted slate blue, olive and charcoal palette, low messy ponytail, tiny amber clip, hooded work jacket with rust-orange hood lining, canvas crossbody utility pouch, straight cargo trousers, worn boots; coherent front, left profile, right profile and back full-body orthographic turnaround plus face portrait; clean neutral background, crisp deliberately placed pixels, believable human proportions, no lettering or logos, no copying reference character's exact silhouette. The prior user image is style-only reference.
