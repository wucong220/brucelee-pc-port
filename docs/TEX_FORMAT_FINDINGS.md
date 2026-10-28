# CTX3 `.tex` 格式取证与本地转换（2026-10-28）

本记录基于三个本机真实解码样本，且不包含原版像素或二进制。另一个 ChatGPT 会话已在完整原包中对 1942 条 CTX3 资源验证字符串表；纹理载荷结构目前只在这三个样本和本地实验中确认。

## 已确认的纹理路径

三个样本均含 17 条 CTX3 字符串，其中观察到的纹理属性包括：

`linear`、`minfilter`、`magfilter`、`clamp`、`wraps`、`wrapt`、`id`、`format`、`r8g8b8a8`、`sizex`、`sizey`、`sizez`、`hasalpha`、`type`、`texture2d`、`mips` 和 `datasourcepath/...`。

字符串表后存在 `DATA` 段。在三个样本中：

- `DATA+0x10` 是 payload 字节数；
- `DATA+0x90` 是宽度，分别得到 256、256、16；
- `DATA+0xA0` 是高度，分别得到 32、128、8；
- `DATA+0xEC`（即 `DATA+236`）是自上而下观察到的存储像素区；
- payload 长度均等于 `width × height × 4`；
- 像素字节为 `r8g8b8a8`；
- payload 后恰有 16 字节，等于此前全部文件数据的 MD5；
- 生成 PNG 时需上下翻转，才能恢复正向方向。

三个样本的人工查看结果分别与源路径相符：透明噪点菜单纹理、水乡背景和黄色 HUD 圆框。尺寸结论由 payload 长度、头部字段、像素连续性和可视结果共同支持。

当前转换器只接受单层、未压缩的 `r8g8b8a8` 纹理，并要求 payload 长度严格等于基础层像素数。带 mipmap 或其他编码的纹理必须明确报为不支持；不能把未知 mip 数据误当成基础层。

## 本地转换

```powershell
python -X utf8 tools/tex_convert.py "C:\path\to\decoded\texture.bin" --output "$env:LOCALAPPDATA\BruceLee-PC-Port\previews\texture.png"
```

输出必须是新文件，并位于仓库外和可识别的同步目录之外。工具不会修改输入的 CTX3 数据，只读取并在写 PNG 前验证字符串标识、DATA 边界、尺寸、payload 长度和 MD5 尾部。

2026-10-28，本机三个真实样本分别在 MXC 沙箱内完成解析和 PNG 编码，均返回成功；该过程未把原版像素提交到 Git。合成数据测试另行覆盖 CTX3 标识、MD5、尺寸、PNG 行翻转、覆盖保护、项目目录保护和 CLI 报告。

## 尚未解决

- 三个样本不能证明所有 `.tex` 都使用相同的 236 字节 DATA 描述。
- 尚未取得多 mip 纹理的样本来验证 mip 目录。
- `sizez`、`hasalpha`、`mips` 等属性的二进制字段映射尚未全部确定。
- 纹理转换成功不等于模型、骨骼或动画格式已解析。
