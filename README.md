# c001apk 公告数据

本分支 `announcements` 专门保存公告表与 Markdown 正文，应用代码继续在 `main`。本分支不包含 GitHub Actions workflow；现有应用构建只监听 main 的应用／workflow 文件变更。发布公告不需要构建或发布新 APK。

## 目录

- `announcements/index.json`：当前完整公告表，客户端只同步这张表。
- `announcements/<公告ID>-<内容修订号>.md`：按需下载的 UTF-8 Markdown 正文。
- 当前公告介绍 1.3.5 的 Markdown、内容保存与公告栏；原功能验收公告已撤回，不再向客户端展示。

## 公告表格式

顶层 `schemaVersion` 固定为 1，`revision` 每次修改表都递增，`announcements` 必须是完整数组。合法的新版本空数组表示撤回全部公告；不要用缺字段／404 表示删除。

每项：

| 字段 | 说明 |
| --- | --- |
| id | 永久唯一 ID，只用英文字母、数字、下划线或短横线；不要重复用于其他公告 |
| title / summary | 消息列表标题与摘要 |
| publishedAt | 带时区的 ISO8601 发布时间，推荐 UTC Z |
| contentRevision | 正文修订号，从 1 递增；修改正文时一起更换正文文件名和 SHA256 |
| reminderRevision | 提醒修订号，从 1 开始；仅明确需要重新通知时提高 |
| important | true 自动提醒最新一篇一次；false 只进入小助手 |
| path | 相对本目录的 Markdown 路径，不接受外部 URL 或上级目录 |
| sha256 | 正文文件原始 UTF-8 字节的 SHA256，小写64位十六进制 |
| withdrawn | 可选，true 撤回并隐藏，不计入未读 |
| expiresAt | 可选，带时区的到期时间，到期隐藏 |

## 发布／修订

1. 先准备 UTF-8 正文文件，推荐用内容修订号形成新文件名；不要先删除旧正文。
2. 用 `Get-FileHash -Algorithm SHA256 <文件路径>` 计算文件哈希，将小写值写入 sha256。
3. 更新索引条目，同时增加顶层 revision。普通纠错只提高 contentRevision，保持 reminderRevision。
4. 将正文和索引放在同一次提交，只 push 本 announcements 分支；不创建应用 Release、不手动触发 workflow。
5. 查看公开文件内容及 SHA256。GitHub 缓存传播可能有延迟；客户端正文校验失败会保留阅读状态并允许稍后重试。

## 撤回

优先把条目 withdrawn 改为 true 并提高顶层 revision；也允许从完整公告表移除。客户端下一次成功同步后隐藏并清理该篇正文缓存。单独删除正文会产生加载失败，不表示撤回。离线客户端在成功同步前仍可能看到缓存。

旧正文可在撤回／修订传播后再清理；保留公告 ID，不把它重新用于另一篇。已经略过的旧重要公告不会因撤回最新公告而依次补弹。

## 缓存与频率

启动检查一次；回前台超过6小时补查；进入小助手超过15分钟补查；手动刷新立即检查。正文只在阅读／准备重要弹窗时下载，最多缓存20篇／2MiB，单篇最多256KiB。清正文缓存保留已读／提醒记录。公告不需要酷安登录，不使用其账号 Cookie、Token 或设备头。
