# 第三方声明

本项目保留原有 [LICENSE](../LICENSE) 与上游署名。

2026-10-23，设备标识的自动获取 `apps/flutter/lib/utils/szlm_duid_client.dart` 的报文构造、
编码与响应解密来自 [kongwufang/szlm_res](https://github.com/kongwufang/szlm_res) 发布包
[v1.0.0](https://github.com/kongwufang/szlm_res/releases/tag/v1.0.0) 中的 `getduid.py`，
该项目以 MIT 许可发布，版权声明见下。Flutter 侧为独立 Dart 实现（zlib 与 XOR 使用标准库），
并补上了单飞、冷却、次数上限、失败保留旧值与不落日志的策略；未移植其 Python 采集脚本、
Frida 钩子或抓包产物。79 字段报文模板取自该公开研究中的测试设备样本，不含账号或用户数据。
MIT 许可原文：

```text
MIT License

Copyright (c) 2026 kongwufang

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

数字联盟、酷安等名称与协议归各自权利人所有；该端点能否注册、注册频率与有效期由服务端决定，
本项目不绕过其判定（被判不自洽时直接视为失败）。

2026-10-23，基础 Markdown 显示新增直接依赖
[`markdown` 7.3.1](https://pub.dev/packages/markdown/versions/7.3.1)，
由 Dart project authors 以 BSD-3-Clause 许可发布，源码见
[Dart tools / markdown](https://github.com/dart-lang/tools/tree/main/pkgs/markdown)。
通过锁定的 pub 包解析常用 Markdown，再由现有 Flutter HTML 组件呈现；
未复制或修改解析器源码。许可证随 Flutter 依赖收录于应用“开源许可”。

2026-10-22，多列信息流新增直接依赖
[`flutter_staggered_grid_view` 0.7.0](https://pub.dev/packages/flutter_staggered_grid_view/versions/0.7.0)，
使用其 `SliverMasonryGrid` 实现按卡片实际高度接续的懒加载瀑布流。
该库由 Romain Rastel 以 MIT 许可发布，源码见
[上游仓库](https://github.com/letsar/flutter_staggered_grid_view)。
本项目通过锁定的 pub 包引用，未复制或修改该库源码；许可证随 Flutter
依赖许可证一并收录于应用“开源许可”页面。

同日新增 [`sliver_tools` 0.2.12](https://pub.dev/packages/sliver_tools/versions/0.2.12)，
使用其 `MultiSliver` 正确传递分段滚动修正，兼容当前 Flutter 工具链。
该库由 Pieter van Loon 以 MIT 许可发布，源码见
[上游仓库](https://github.com/Kavantix/sliver_tools)。同样通过 pub 包引用，
未复制或修改源码，其许可证随应用依赖许可证收录。

2026-10-16，新增的 `assets/emojis/niuniu_emotion_*.png` 为酷安官方
Android 16.6.4（2609291）安装包中的 32 张牛牛表情，用于兼容官方表情名称。
名称以官方 `niuniu_emotion_array` 核对；素材版权归酷安及相应权利人所有，
不因本项目的 AGPL-3.0 许可证而改变。未引入官方应用代码、账号或用户数据。

本轮会话置顶、取消置顶及删除的接口路径参考
[c001apk-compose](https://github.com/bggRGjQaUbCoE/c001apk-compose)
提交 `d44c471fb38fa600d28fa33b5dd7fcfd6abb7197` 的
`ui/notification/NoticeViewModel.kt`、`logic/network/ApiService.kt`，
该项目同样采用 AGPL-3.0（见本项目保留的根 LICENSE）。
Flutter 状态管理、失败重试及会话刷新协调在本项目实现。

`apps/flutter/lib/utils/token_util.dart` 中的 Token V3 兼容实现及
`apps/flutter/lib/utils/token_v3_data.dart` 中的协议查找表参考自
[daimiaopeng/coolapk-desktop](https://github.com/daimiaopeng/coolapk-desktop)，
来源提交 `3ef2ad4da6d171e118d2b29b0f18d7ffa6da9086`，文件
`src-tauri/src/coolapk/auth.rs` 与 `auth_blob.b64`，采用日期 2026-10-14。
原项目以 MIT 授权，其完整许可证及版权声明见
[coolapk-desktop MIT](licenses/coolapk-desktop-MIT.txt)。

以上许可适用于原项目原创代码；查找表用于非公开协议兼容，其第三方来源
与权利不由原项目 MIT 许可担保。酷安名称、商标及服务内容归相应权利人。
未引入参考项目的 Tauri/Vue 架构或在线测试集。

2026-10-14，游客动态详情的官方分享页 JSON 请求方式参考同一提交的
`src-tauri/src/coolapk/client.rs`（`fetch_external_page` 中的公开动态请求）。
本项目独立实现 Flutter 请求和回退逻辑，并实测补齐该页面需要的客户端
签名头；上述 MIT 许可证及版权声明同样适用于这一协议调研来源。

`apps/flutter/test/fixtures/token_v3.json` 为合成设备与固定时间的测试签名，使用独立
Node bcryptjs 实现生成，不含真实设备、账号凭据或用户 Token。

2026-10-14，`captcha_challenge.dart`、`captcha_page.dart` 的验证码配置解析、
`NEC` 验证凭证格式，以及点赞/回复的表单参数参考上述同一提交的
`src/utils/neteaseCaptcha.ts` 与 `src-tauri/src/coolapk/client.rs`，适用上述 MIT 声明。
Flutter 验证界面独立实现，运行时加载网易易盾官方 Web SDK，不把 SDK 打包到源码中。

2026-10-16，空 `captchaField` 对应 `validate` Cookie 的协议语义经官方
Android 16.6.4（2609291）客户端与游客只读响应对照核实。本项目独立实现
该分支及当前账号、设备范围内的内存复用，没有移植或分发官方客户端代码。
SDK 接入回调另核对 [网易易盾官方示例](https://github.com/yidun/captcha-php-demo/blob/master/index.php)。

2026-10-17，API 响应会话 Cookie 的保存与返回经同一官方客户端的协议行为及
游客响应核对。本项目独立实现域、路径、有效期、账号设备绑定及并发响应隔离，
并仅缓存服务端已接受的验证状态以供冷启动复用；未移植官方客户端代码或 SDK。

2026-10-14，Android 启动器图标的系统 Monet 亮暗配色参考
[bggRGjQaUbCoE/PiliPlus](https://github.com/bggRGjQaUbCoE/PiliPlus)，
来源提交 `bd5e04e5de5a523e85a8eeba30da748dcd68925a`，文件
`android/app/src/main/res/values-v31/colors.xml` 与
`android/app/src/main/res/values-night-v31/colors.xml`。
该项目采用 GPL-3.0，完整许可证见 [PiliPlus GPL-3.0](licenses/PiliPlus-GPL-3.0.txt)。
仅参考系统颜色资源搭配，保留 c001apk 原有无穷符号和单色层，未引入 PiliPlus 图形素材。

2026-10-15，账号切换入口、设置分类与文字层级参考同一项目
提交 `868580c3edbe13f874583a3139b1f4d116d4cc0f` 的
`lib/pages/setting/view.dart`、`lib/pages/setting/widgets/normal_item.dart`、
`lib/utils/theme_utils.dart` 与账号管理相关实现。
Flutter 页面和酷安多账号会话逻辑在本项目独立实现，沿用既有依赖及存储结构；
参考项目的 GPL-3.0 许可证见上述链接。

2026-10-22，Android WebView 的 AGP 9 兼容补丁保留完整
`flutter_inappwebview_android` 1.1.3 源码，位置为
`apps/flutter/third_party/flutter_inappwebview_android`，适用 Apache-2.0。
来源为上游 `v6.1.5`（提交 `f67ae1f34868c7660c16a2473f53a7a7bfb6f784`），
精确发布归档、SHA-256、修改说明和完整许可见
[补丁说明](../apps/flutter/third_party/flutter_inappwebview_android/C001APK_PATCH.md)及
[Apache-2.0 原文](../apps/flutter/third_party/flutter_inappwebview_android/LICENSE)。
补丁只替换两处默认 ProGuard 文件名并添加修改日期声明；不改全局 Pub 缓存。

2026-10-15，c001apk 自身更新弹窗的更新说明、关闭提醒与分平台下载入口
参考同一项目提交 `d529e0a2d90a2a3a04ef9847e6c14187852ea6ee` 的
`lib/utils/update.dart`。本项目独立实现语义版本比较、24 小时限频、跳过版本、
独立网络请求及设置持久化；没有采用参考实现按构建时间判断版本的方式。
参考项目的 GPL-3.0 许可证见上述链接。
