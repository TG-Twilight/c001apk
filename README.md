# c001apk 内容过滤规则

此分支发布 c001apk 的内容过滤订阅，帮助减少低俗内容打扰，让浏览更清爽。规则包含文本分类、用户名单和话题名单。

## 使用

在支持内容过滤的客户端中，进入 **设置 → 浏览与隐私 → 屏蔽傻逼内容**，点击“检查规则更新”。可按类别开启或关闭过滤，也可添加个人规则和例外。

- [规则文件](rules.json)
- [订阅地址](https://raw.githubusercontent.com/TG-Twilight/c001apk/filters/rules.json)

## 更新与隐私

`rules.json` 是版本化的完整规则集，包含 `schemaVersion`、`revision`、`publishedAt` 和 `rules`。规则更新时递增版本，客户端校验成功后整体替换；更新失败继续使用已有规则，个人设置与例外保留。

过滤只改变本机展示，不执行账号拉黑或举报，不上传浏览内容及个人名单。规则按阅读偏好维护，可能存在漏判或误判，可通过分类开关、例外和临时查看调整。

[返回主项目](https://github.com/TG-Twilight/c001apk)
