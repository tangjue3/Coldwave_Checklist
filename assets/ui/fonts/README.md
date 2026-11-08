# 字体与授权

本工程所有 UI 文字使用**随工程分发**的 Noto Sans SC，不依赖系统安装的微软雅黑等字体。

| 文件 | 说明 |
|---|---|
| `NotoSansSC-Variable.ttf` | 可变字重 TTF（17,772,300 字节），简体中文 + 拉丁 + 常用符号 |
| `OFL.txt` | SIL Open Font License 1.1 许可证全文 |
| `upstream_info.md` | Google Fonts 仓库的上游信息 |

## 来源

- 官方仓库：https://github.com/google/fonts/tree/main/ofl/notosanssc
- 字体文件：https://raw.githubusercontent.com/google/fonts/main/ofl/notosanssc/NotoSansSC%5Bwght%5D.ttf
- 许可证：https://raw.githubusercontent.com/google/fonts/main/ofl/notosanssc/OFL.txt
- 下载日期：2026-11-08

## 校验

```
SHA256(NotoSansSC-Variable.ttf) = a3041811a78c361b1de50f953c805e0244951c21c5bd412f7232ef0d899af0da
SHA256(OFL.txt)                = 1c05c68c34f9708415aada51f17e1b0092d2cea709bf4a94cd38114f9e73d7d9
```

## 授权要点

SIL OFL 1.1：允许使用、研究、修改、再分发（含随游戏打包与商业发行），需随字体附带许可证与版权声明；
不得单独售卖字体本身；衍生字体不得使用保留字体名（本许可证声明的保留名为 `Source`）。
本工程**未修改**字体文件，按原名分发，因此只需保留 `OFL.txt` 即可。

> 注意：如果以后对字体做子集化（减小 Web 包体积），属于「修改字体」，需确认保留字体名规则并相应重命名。
> 当前为保证任意中文文本都能显示，使用未裁剪的完整字库。
