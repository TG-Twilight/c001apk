<div align="center">

<img src="docs/media/banner.svg" alt="c001apk — 让酷安，轻一点。" width="100%">

# c001apk

**轻量、简体中文的非官方酷安客户端**

[![License: AGPL v3](https://img.shields.io/badge/License-AGPL_v3-607D8B?style=flat-square)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.47.7-02569B?style=flat-square&logo=flutter&logoColor=white)](docs/DEVELOPMENT.md)
[![Build](https://github.com/TG-Twilight/c001apk/actions/workflows/build.yml/badge.svg?branch=main)](https://github.com/TG-Twilight/c001apk/actions/workflows/build.yml)
![Platforms](https://img.shields.io/badge/平台-Android%20%7C%20Windows-486B78?style=flat-square)
![Status](https://img.shields.io/badge/状态-持续维护中-6E8B74?style=flat-square)

[下载最新版](https://github.com/TG-Twilight/c001apk/releases/latest) · [反馈问题](https://github.com/TG-Twilight/c001apk/issues) · [参与开发](docs/DEVELOPMENT.md)

</div>

## 关于

基于 [c001apk-flutter](https://github.com/bggRGjQaUbCoE/c001apk-flutter) 持续维护的非官方酷安客户端，重点支持 Android 与 Windows。在轻量、简体中文的浏览体验上，加入 HDR／Live 实况、液态玻璃、大屏阅读和本地内容过滤。

## 特色功能

在轻量浏览之外，我们也在持续打磨看图、阅读和内容筛选的体验。

| 功能 | 你可以用它做什么 |
| --- | --- |
| **HDR 图片** | 在支持的设备与显示条件下查看 HDR 高光；不支持 HDR 时加载高清 SDR。支持保存原件，也可开启“我不想看HDR”，让静态大图始终使用高清 SDR。 |
| **Live 实况图片** | 在大图中播放实况，支持自动播放一次、手动循环播放，以及实况原件保存。 |
| **液态玻璃** | 顶部分类、悬浮导航、搜索和菜单随背后内容呈现折射与色散，提供低／中／高／完全四档，也可关闭。 |
| **悄悄关注** | 将感兴趣的用户加入本机名单、集中浏览动态，无需向账号发起关注操作；游客也可使用本地关注。 |
| **帖子／文章保存** | 将正文、作者、来源及部分评论导出为 Markdown 或离线 HTML；HTML 可将图片内嵌到同一个文件，方便离线阅读与归档。 |
| **屏蔽傻逼内容** | 按自己的浏览偏好减少低俗内容打扰。提供标准／严格两档、话题与作者名单、文本规则、个人规则及订阅更新；列表静默过滤，支持例外与临时查看。默认关闭，仅影响本机展示。 |
| **桌面与大屏阅读** | 信息流随窗口宽度切换一至四列，阅读时正文居中，右侧可继续浏览；支持实时缩窗、独立滚动、键盘操作与鼠标前进／后退侧键。 |

同时保留动态／文章／评论浏览、内容搜索、多账号、游客模式、本地收藏与浏览历史，以及明暗主题、阅读字号和主页分类自定义。

## 界面预览

Android · M3E 标准界面（1.5.2，2026-11-08）

<p align="center">
  <img src="docs/media/screenshots/android-home-1.5.2.avif" width="31%" alt="Android M3E 首页：标准顶部分类、动态列表与底部导航，关闭悬浮控件">
  <img src="docs/media/screenshots/android-article-1.5.2.avif" width="31%" alt="Android M3E 图文详情：封面、正文与图片">
  <img src="docs/media/screenshots/android-settings-1.5.2.avif" width="31%" alt="Android M3E 分类设置：外观、关注、隐私、存储与账号管理">
</p>
<p align="center"><sub>Android · 首页 / 图文详情 / 分类设置</sub></p>

<details>
<summary>Android · 开启液态玻璃（1.5.2，点击展开）</summary>

<p align="center">
  <img src="docs/media/screenshots/android-liquid-glass-1.5.2.avif" width="45%" alt="Android 深色主题下开启液态玻璃：顶部分类栏与底部悬浮导航折射背后的图片内容">
  <img src="docs/media/screenshots/android-liquid-glass-follow-1.5.2.avif" width="45%" alt="Android 关注页液态玻璃：用户关注分类、搜索按钮与底部悬浮导航折射背后的内容">
</p>
<p align="center"><sub>Android · 液态玻璃：首页 / 关注 · 2026-11-08</sub></p>

</details>

Windows · 1.5.2（2026-11-08）

<p align="center">
  <img src="docs/media/screenshots/windows-home-1.5.2.avif" width="96%" alt="Windows 桌面端首页：液态玻璃悬浮侧栏、顶部分类与三列信息流">
</p>
<p align="center"><sub>Windows · 悬浮导航与三列信息流</sub></p>

<p align="center">
  <img src="docs/media/screenshots/windows-reading-1.5.2.avif" width="96%" alt="Windows 大屏阅读：居中正文、右侧作者卡与继续浏览信息流">
</p>
<p align="center"><sub>Windows · 居中阅读与右侧继续浏览</sub></p>

<p align="center">
  <img src="docs/media/screenshots/windows-settings-1.5.2.avif" width="96%" alt="Windows 分类设置：左侧分类与右侧外观、悬浮控件及液态玻璃选项">
</p>
<p align="center"><sub>Windows · 分类设置与宽窗口布局</sub></p>

## 下载安装

从本仓库 [Releases](https://github.com/TG-Twilight/c001apk/releases/latest) 下载官方完整版。本次 README 对应 **1.5.2**，更新内容见 [发行说明](https://github.com/TG-Twilight/c001apk/releases/tag/1.5.2-release)。

| 平台 | 安装包与支持情况 |
| --- | --- |
| **Android** | 提供 arm64-v8a、armeabi-v7a、x86_64，最低 Android 7.0；多数近年的手机选择 arm64-v8a。 |
| **Windows** | 提供 x86_64 压缩包，解压完整目录后运行 `c001apk.exe`，请保留同目录的 DLL 与 data 文件夹。 |
| **Linux** | 提供 x86_64 构建产物，运行体验仍待验收。 |
| **iOS** | 提供 arm64 未签名 IPA，需自行签名后安装，运行体验仍待验收。 |

自行构建请参照 [开发指南](docs/DEVELOPMENT.md)。

云端构建包可从 [Actions](https://github.com/TG-Twilight/c001apk/actions/workflows/build.yml) 的 Artifacts 下载，平台、签名与手动构建方式见 [云端构建指南](docs/CI.md)。

反复遇到人机验证时，可在引导或设备设置中主动获取数盟 ID，也可参照 [从官方酷安导入设备标识](docs/DEVICE_ID_IMPORT.md) 手动导入。不会在启动或回到前台时自动取号；获取或导入设备标识不保证永久免验证。

## 使用说明

- **悄悄关注**：在设置中开启后，长按用户主页的关注按钮即可添加。名单仅保存在本机，不会自动同步到账号。
- **保存帖子／文章**：在详情页点击“保存内容”，选择 Markdown 或离线 HTML。保存包含最多三条一级评论，不包含全量评论、楼中楼或视频；图片下载失败时会提示确认。
- **内容过滤**：在“设置 → 浏览与隐私 → 屏蔽傻逼内容”中开启。标准档较温和，严格档包含标准规则、过滤更强，误杀可能更多；可调整分类、添加个人规则或临时查看。不会调用账号拉黑或举报接口。
- **液态玻璃**：在“设置 → 外观与字号”中开启悬浮控件与液态玻璃，并选择档位。
- **HDR 与实况**：“我不想看HDR”只改变静态大图的显示策略，保留实况播放、缩略图素材标识和原件保存。

Android 包名为 `app.awavenue.c001apk`。与其他包名的客户端独立安装，账号及本地数据不会自动迁移。

> [!NOTE]
> 部分内容仍受登录、验证码和服务端接口限制，验证码放行与部分账号操作仍需继续完善。

## 参与与致谢

欢迎提交 [Issue](https://github.com/TG-Twilight/c001apk/issues) 或 Pull Request。反馈请附平台、版本、复现步骤与脱敏错误信息；开发环境、工程目录及检查命令见 [开发指南](docs/DEVELOPMENT.md)。

感谢 [bggRGjQaUbCoE/c001apk-flutter](https://github.com/bggRGjQaUbCoE/c001apk-flutter) 的开源，以及 [daimiaopeng/coolapk-desktop](https://github.com/daimiaopeng/coolapk-desktop) 的协议调研参考。

感谢 [kongwufang](https://github.com/kongwufang) 通过 [PR #11](https://github.com/TG-Twilight/c001apk/pull/11) 贡献数字联盟设备标识自动获取功能，以及配套的离线测试、实测记录与许可说明。

本项目沿用 [GNU AGPL v3](LICENSE)，第三方来源与 MIT 许可见 [第三方声明](docs/THIRD_PARTY_NOTICES.md)。本项目与酷安官方无隶属关系，酷安名称、商标及服务内容归相应权利人所有。
