# VIDEO-FIX-002A 交付报告｜修复推购物车时人物动画错误切换

日期：2026-11-10　分支：`角色制作`　范围：仅修动画状态机，不碰素材 / 画质 / 参数 / 玩法

---

## 一、现象与定位

用户看 `godot_push_demo.mp4` 时发现约 4～5 s：`player anim=walk_right` 而 `cart=pushing`，
人物垂手像空手走路，购物车却仍在推行状态。

**根因（单帧内状态更新顺序）**：推车松手那一帧，`PushableCart._physics_process()` 先执行
（车在树里先于玩家），它 `set_push_moving(false)` → 起 `push_walk_to_idle` 并把
`_in_stop_transition` 置真；同一帧稍后 `PlayerController._physics_process()` 跑
`_update_state()`，此时人物 `velocity.x` 还有约 57 px/s（减速 1400 px/s² 需要 4 帧才归零），
`state` 仍是 `walk`，于是命中「状态没变 + 过渡中又起步 → 回 walk」这条分支：

```gdscript
# 修复前
if next == STATE_WALK and _in_stop_transition:
    _play(ANIM_WALK)      # ← 把 push_walk_to_idle 覆盖成 walk_right
    _in_stop_transition = false
```

因为覆盖发生在同一物理帧、且 `process` 在 `physics` 之后才轮询，`push_walk_to_idle`
**连一帧都没被渲染出来**；随后 `state` 变 `idle` 时又因 `push_pose` 提前 return，
`walk_right` 就一直挂着 —— 直接形成「车在推、人垂手」的稳定错误态，直到下次
`set_push_moving(true)` 才恢复。

**为什么上一轮测试没抓到**：只有 7/32（21.9%）的 walk 相位允许接过渡，其余相位直接
进 `push_idle`、不会进入这条分支。上一轮断言是检查点抽样，恰好没踩中；本次录屏踩中了。

---

## 二、修复（2 处，均在 `PlayerController`）

1. **守卫已知路径**：`_update_state()` 的「过渡中又起步」分支加 `not push_pose`。
   推车期间动画只由 `set_push_pose()` / `set_push_moving()` 驱动，普通移动逻辑不再插手。
2. **兜底未知路径**：新增 `_enforce_push_anim()`，在 `_physics_process()` 两个出口各调一次。
   只要 `push_pose` 为真而当前动画不属于推车三段，立刻按 `push_walk_active` 纠正回
   `push_walk_right` / `push_idle_right`（过渡进行中则保留）。

两处都用注释写清了真实事故与物理帧顺序，避免以后被"优化"回去。

**未改**：`PushableCart`（绑定 / 间距 / 速度 / 装载 / 图层）、碰撞盒、脚底锚点、
`move_speed` / `push_speed` / `pull_speed`、512×704 素材与 LINEAR 过滤、`project.godot`。

---

## 三、自动化断言（新增，逐帧而非抽样）

`--dev-scene=vid002` 增加一个**每帧运行**的一致性监视器：只要
`cart.state == PUSHING`，人物当前动画就不得是 `walk_right` / `walk_to_idle` / `idle_right`。
测试用例把 walk 相位**确定性**地停在 14 / 5 / 27 三个目标上再松手（14 属于允许接过渡的
集合，5、27 不属于），覆盖两条分支，并断言停止后人与车仍为 80 px。

| 版本 | 结果 |
|---|---|
| 修复前（同用例） | **134 帧违规**，5 项 FAIL，`anim=walk_right vx=56.7 cart=pushing pose=true` |
| 修复后 | **54/54 通过，0 违规**，过渡帧 43 帧（确认走到 `push_walk_to_idle`） |

录屏模式（`--vid002-movie`）同样开启监视器：本次成片 181 帧、`violations=0`。

---

## 四、实机验证

`compare_fix_4to5s.png`（同一时间点、同一机位）：

| 时刻 | 修复前 | 修复后 |
|---|---|---|
| 4.0 s | `push_walk_right` 手在把上 | `push_walk_right` 手在把上 |
| 4.5 s | `walk_right` **手离把** | `push_walk_to_idle` 手在把上 |
| 5.0 s | `walk_right` **手离把** | `push_idle_right` 手在把上 |

新演示片 `godot_push_demo.mp4`（9.05 s / 20 fps / 181 帧）完整覆盖：
普通行走 → 绑定 → 推车 → 停止（过渡）→ 再次推车（半载/满载）→ 停止。
原问题窗口的 1.6 s 片段保留为 `before_fix_stop_window.mp4` 作对照证据。

---

## 五、回归（全部重跑，未沿用旧结果）

| 项 | 结果 |
|---|---|
| `vid002` 推车真实测试 | **54/54**，0 违规 |
| `vid001` 普通行走 r10–r12 | **32/32** |
| smoke | **26/26** |
| art003 / art004 | 全部符合预期，0 脚本错误 |
| core001a / core001b | 0 脚本错误 / 失败 0 项 |
| Web（重新导出后实跑） | art003 **11/11**、core001b **19/19** |

---

## 六、仍未解决 / 未改变

- **停止过渡仍只覆盖 7/32 相位**：这是源视频只提供一次减速过程的素材限制，本轮不动素材，
  其余相位仍直接站稳（不会跳变，只是没有减速过程）。
- 脚底滑动、朝左仅 `flip_h` 镜像、单帧待机、赛璐璐与像素风差异：均未变。
- **候选状态不变**：台账 32 行、白名单 14 条、总览「推购物车」仍为「待重新制作」。
  待最终美术审核通过后再转正。

## 七、交付物

| 文件 | 说明 |
|---|---|
| `转存库/VIDEO-INTEGRATE-002/godot_push_demo.mp4` | **新演示片**（已替换旧片） |
| `转存库/VIDEO-INTEGRATE-002/godot_push_demo.gif` | 同内容 GIF |
| `转存库/VIDEO-INTEGRATE-002/before_fix_stop_window.mp4` | 修复前 3.8–5.4 s 问题片段 |
| `转存库/VIDEO-INTEGRATE-002/compare_fix_4to5s.png` | 修复前后 4.0/4.5/5.0 s 对照 |
| `tests/screenshots/vid002_test.png` | 54 项断言结果截图 |

复现：

```bash
G=.tools/godot/Godot_v4.7.2-stable_win64_console.exe
$G --path . -- --dev-scene=vid002 --vid002-test  --quit
$G --path . -- --dev-scene=vid002 --vid002-movie --quit
```
