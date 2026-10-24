import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../logic/szlm_identity_service.dart';
import '../../utils/official_device_identity.dart';
import '../../utils/storage_util.dart';
import '../../utils/szlm_duid_client.dart';
import '../../utils/utils.dart';

class DeviceIdentityPage extends StatefulWidget {
  const DeviceIdentityPage({super.key});

  @override
  State<DeviceIdentityPage> createState() => _DeviceIdentityPageState();
}

class _DeviceIdentityPageState extends State<DeviceIdentityPage> {
  final _text = TextEditingController();
  String? _pending, _error;
  String? _autoMessage;
  bool _saving = false, _saved = false, _fetching = false, _autoFailed = false;

  @override
  void dispose() {
    _text.dispose();
    _pending = null;
    super.dispose();
  }

  void _recognize(String text) {
    try {
      final id = OfficialDeviceIdentity.parse(text);
      _text.clear();
      setState(() {
        _pending = 'ShuzlmID: $id';
        _error = null;
        _saved = false;
      });
    } on FormatException catch (error) {
      setState(() {
        _pending = null;
        _error = text.isEmpty ? null : error.message.toString();
        _saved = false;
      });
    }
  }

  Future<void> _paste() async {
    setState(() {
      _pending = null;
      _saved = false;
      _error = null;
    });
    try {
      final value = await Clipboard.getData(Clipboard.kTextPlain);
      if (!mounted) return;
      if (value?.text?.trim().isNotEmpty != true) {
        setState(() => _error = '剪贴板没有文本，请先在官方酷安完成复制');
        return;
      }
      _recognize(value!.text!);
    } catch (_) {
      if (mounted) setState(() => _error = '无法读取剪贴板，请长按输入框手动粘贴');
    }
  }

  Future<void> _save() async {
    final value = _pending;
    if (value == null || _saving) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      await GStorage.importOfficialDeviceIdentity(value);
      if (!mounted) return;
      setState(() {
        _pending = null;
        _saved = true;
        _error = null;
        _autoMessage = null;
      });
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message.toString());
    } catch (_) {
      if (mounted) setState(() => _error = '保存失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _autoFetch() async {
    if (_fetching) return;
    setState(() {
      _fetching = true;
      _autoMessage = null;
      _autoFailed = false;
      _saved = false;
    });
    try {
      await SzlmIdentityService.instance.renewNow();
      if (!mounted) return;
      setState(() {
        _pending = null;
        _error = null;
        _autoMessage = '已获取新的设备标识并立即生效。返回内容页刷新即可。';
      });
    } on SzlmDuidException catch (error) {
      if (mounted) {
        setState(() {
          _autoFailed = true;
          _autoMessage = error.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _autoFailed = true;
          _autoMessage = '自动获取失败，请检查网络后重试，或使用下方手动导入。';
        });
      }
    } finally {
      if (mounted) setState(() => _fetching = false);
    }
  }

  Future<void> _openOfficial() async {
    try {
      final opened =
          await Utils.platform.invokeMethod<bool>('openOfficialIdSettings');
      if (opened != true) _showOfficialError(false);
    } on PlatformException catch (error) {
      _showOfficialError(error.code == 'official_client_not_installed');
    } catch (_) {
      _showOfficialError(false);
    }
  }

  void _showOfficialError(bool notInstalled) {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(notInstalled ? '尚未安装官方酷安' : '无法打开酷安 OAID 界面'),
        content: Text(notInstalled
            ? '请先安装官方酷安，再点击“酷安 OAID 界面”复制设备标识。'
            : '请确认官方酷安已启用，并更新至支持此入口的版本后重试。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  TextStyle get _sectionStyle =>
      const TextStyle(fontSize: 16, fontWeight: FontWeight.w600);

  @override
  Widget build(BuildContext context) {
    final hasIdentity = GStorage.szlmId.trim().isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('设备标识')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('减少重复人机验证',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              const Text('设备标识（数盟 ShuzlmID）是每个请求的首字段。它缺失或失效时，'
                  '酷安会反复要求人机验证。'),
              const SizedBox(height: 20),
              Text('自动获取', style: _sectionStyle),
              const SizedBox(height: 8),
              const Text('点击后注册一个新的设备标识并立即应用。已保存的标识会一直沿用，'
                  '不会自行更换；只有出现人机验证且冷却时间已过时，才会在下次请求前自动更换。'),
              const SizedBox(height: 12),
              Wrap(spacing: 12, runSpacing: 8, children: [
                FilledButton.icon(
                  onPressed: _fetching ? null : _autoFetch,
                  icon: const Icon(Icons.autorenew),
                  label: Text(_fetching ? '正在获取…' : '自动获取并应用'),
                ),
              ]),
              if (_autoMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _autoMessage!,
                  style: TextStyle(
                    color: _autoFailed
                        ? Theme.of(context).colorScheme.error
                        : Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 8),
              Text('手动导入（兜底）', style: _sectionStyle),
              const SizedBox(height: 8),
              const Text('自动获取不可用时，可从官方酷安手动导入：'
                  '1. 进入官方酷安的 OAID 界面（“检查日志和测试”页）。'
                  '2. 向下找到“复制 OAID”，在同一页面累计点击 5 次。'
                  '3. 返回这里，粘贴完整内容，识别后保存。'),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                if (defaultTargetPlatform == TargetPlatform.android)
                  OutlinedButton.icon(
                    onPressed: _openOfficial,
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('酷安 OAID 界面'),
                  ),
                TextButton.icon(
                  onPressed: () =>
                      Utils.launchURL(OfficialDeviceIdentity.guideUrl),
                  icon: const Icon(Icons.help_outline),
                  label: const Text('仓库图文说明'),
                ),
              ]),
              const SizedBox(height: 12),
              const Text('虽然官方按钮叫“复制 OAID”，这里实际使用其中的 ShuzlmID（数盟 ID）。'
                  '其余字段会被忽略，不会保存 AndroidID、UUID 等复制内容。'),
              const SizedBox(height: 16),
              TextField(
                controller: _text,
                minLines: 2,
                maxLines: 4,
                enabled: !_saving,
                autocorrect: false,
                enableSuggestions: false,
                onChanged: _recognize,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: '粘贴官方复制的完整文本',
                  hintText: '需包含 ShuzlmID 字段；识别成功后自动隐藏内容',
                ),
              ),
              const SizedBox(height: 8),
              if (_pending != null)
                const Text('已识别数盟 ID，复制内容已隐藏。点击保存后生效。'),
              if (_saved) const Text('已保存。返回内容页后刷新即可，机型及其他设备参数已保留。'),
              if (_error != null)
                Text(_error!,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error)),
              const SizedBox(height: 12),
              Wrap(spacing: 12, runSpacing: 8, children: [
                OutlinedButton.icon(
                  onPressed: _saving ? null : _paste,
                  icon: const Icon(Icons.content_paste),
                  label: const Text('粘贴并识别'),
                ),
                FilledButton(
                  onPressed: _pending == null || _saving ? null : _save,
                  child: Text(_saving ? '正在保存…' : '保存并应用'),
                ),
              ]),
              const SizedBox(height: 16),
              Text(hasIdentity ? '本机已有设备标识，可重新自动获取或手动替换。' : '本机尚未保存设备标识。'),
              const SizedBox(height: 8),
              const Text('标识保存在本机，只用于酷安请求；自动获取会向数字联盟上报一份'
                  '不含账号信息的设备报文。请勿将复制内容或真实标识公开。'),
            ],
          ),
        ),
      ),
    );
  }
}
