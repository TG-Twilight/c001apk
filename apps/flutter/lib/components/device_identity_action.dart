import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../logic/szlm_identity_service.dart';
import '../utils/storage_util.dart';
import '../utils/szlm_duid_client.dart';

/// Explicit acquisition shared by onboarding and the device settings page.
class DeviceIdentityAction extends StatefulWidget {
  const DeviceIdentityAction({super.key, this.service, this.onAcquired});

  final SzlmIdentityService? service;
  final VoidCallback? onAcquired;

  @override
  State<DeviceIdentityAction> createState() => _DeviceIdentityActionState();
}

class _DeviceIdentityActionState extends State<DeviceIdentityAction> {
  SzlmIdentityService get _service =>
      widget.service ?? SzlmIdentityService.instance;
  Timer? _refresh;
  String? _message;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _service.addListener(_changed);
    _scheduleRefresh();
  }

  @override
  void didUpdateWidget(DeviceIdentityAction oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service != widget.service) {
      (oldWidget.service ?? SzlmIdentityService.instance)
          .removeListener(_changed);
      _service.addListener(_changed);
      _scheduleRefresh();
    }
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
    _scheduleRefresh();
  }

  void _scheduleRefresh() {
    _refresh?.cancel();
    final next = _service.nextAllowedAt;
    if (next == null) return;
    final remaining = next.difference(DateTime.now());
    final delay = remaining > const Duration(minutes: 1) || remaining.isNegative
        ? const Duration(minutes: 1)
        : remaining + const Duration(milliseconds: 100);
    _refresh = Timer(delay, _changed);
  }

  @override
  void dispose() {
    _refresh?.cancel();
    _service.removeListener(_changed);
    super.dispose();
  }

  Future<void> _acquire() async {
    if (_service.isFetching || _service.unavailableReason != null) return;
    setState(() {
      _message = null;
      _failed = false;
    });
    try {
      await _service.renewNow();
      if (!mounted) return;
      setState(() => _message = '已获取并保存设备标识，返回内容页刷新即可。');
      widget.onAcquired?.call();
    } on SzlmDuidException catch (error) {
      if (mounted) {
        setState(() {
          _failed = true;
          _message = error.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _failed = true;
          _message = '获取或保存失败，请稍后重试，也可使用手动导入。';
        });
      }
    } finally {
      if (mounted) _changed();
    }
  }

  String _date(DateTime value) {
    final local = value.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
      valueListenable:
          GStorage.settings.listenable(keys: [SettingsBoxKey.szlmId]),
      builder: (context, _, __) {
        final hasIdentity = GStorage.szlmId.trim().isNotEmpty;
        final reason = _service.unavailableReason;
        final next = _service.nextAllowedAt;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(hasIdentity ? '已保存设备标识，将继续使用' : '本机尚未保存设备标识'),
            const SizedBox(height: 12),
            const Text('点击获取会向数字联盟发送不含账号信息的设备报文。'
                '成功后标识立即保存在本机，即使取消引导也会保留。'),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed:
                  _service.isFetching || reason != null ? null : _acquire,
              icon: const Icon(Icons.key_outlined),
              label: Text(_service.isFetching
                  ? '正在获取…'
                  : hasIdentity
                      ? '重新获取数盟 ID'
                      : '获取数盟 ID'),
            ),
            if (_message != null) ...[
              const SizedBox(height: 8),
              Semantics(
                liveRegion: true,
                child: Text(_message!,
                    style: TextStyle(
                        color: _failed
                            ? Theme.of(context).colorScheme.error
                            : Theme.of(context).colorScheme.primary)),
              ),
            ],
            if (reason != null || next != null) ...[
              const SizedBox(height: 8),
              Text(next == null ? reason! : '可再次获取时间：${_date(next)}'),
            ],
            const SizedBox(height: 8),
            const Text('仅主动点击时获取，不会自动更换。成功获取后需间隔 7 天；'
                '这是再次获取间隔，并非标识有效期。失败后也有冷却与次数限制。'),
          ],
        );
      });
}
