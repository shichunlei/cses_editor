import 'dart:async';

import 'package:cses_offline_example/daily_guidance/ui/journal_bottom_sheet.dart';
import 'package:cses_offline_example/daily_guidance/ui/journal_modal.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// 今日导向引用的真实人员或部门快照；部门引用不会自动展开为所有成员。
///
/// ```dart
/// import 'package:cses_offline_example/daily_guidance/guidance_people.dart';
/// const person = GuidancePerson(id: 'u1', name: '张三');
/// final restored = GuidancePerson.fromJson(person.toJson());
/// ```
@immutable
class GuidancePerson {
  /// 创建快照；[id] 为真实稳定标识，[name] 为显示名称，[type] 仅接受
  /// `user` 或 `department`，默认人员；[department] 为可选部门名称。
  /// [children] 用于目录树，默认空列表；调用方不得修改传入列表。
  const GuidancePerson({
    required this.id,
    required this.name,
    this.type = 'user',
    this.department,
    this.children = const [],
  }) : assert(id != ''),
       assert(name != ''),
       assert(type == 'user' || type == 'department');

  /// 服务端提供的真实稳定标识，同名人员以此区分。
  final String id;

  /// 选中时的显示名称快照，不参与身份去重。
  final String name;

  /// 引用种类：`user` 或 `department`。
  final String type;

  /// 可选部门显示名称，不用作身份或权限依据。
  final String? department;

  /// 目录树子节点；选人结果只返回引用快照，不携带整个子树。
  final List<GuidancePerson> children;

  /// 跨人员与部门命名空间的唯一身份键。
  String get identity => '$type:$id';

  /// 将当前快照和子树转换为可持久化的 JSON 数据，不含认证信息。
  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'type': type,
    if (department != null) 'department': department,
    if (children.isNotEmpty)
      'children': children.map((child) => child.toJson()).toList(),
  };

  /// 从 [json] 恢复快照；缺省类型按人员处理，身份、类型或子树非法时抛出
  /// [FormatException]，不生成占位身份或静默丢弃引用。
  factory GuidancePerson.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final name = json['name'];
    final type = json['type'] ?? 'user';
    final department = json['department'];
    final children = json['children'];
    if (id is! String ||
        id.trim().isEmpty ||
        name is! String ||
        name.trim().isEmpty ||
        (type != 'user' && type != 'department') ||
        (department != null && department is! String) ||
        (children != null && children is! List)) {
      throw const FormatException('人员或部门引用格式错误');
    }
    return GuidancePerson(
      id: id,
      name: name,
      type: type as String,
      department: department as String?,
      children: List.unmodifiable(
        (children as List? ?? const []).map((child) {
          if (child is! Map) throw const FormatException('组织子节点格式错误');
          return GuidancePerson.fromJson(Map<String, Object?>.from(child));
        }),
      ),
    );
  }
}

/// 宿主拥有的组织目录端口；加载失败应抛出异常，调用方可显式重试。
///
/// ```dart
/// import 'package:cses_offline_example/daily_guidance/guidance_people.dart';
/// Future<void> loadCurrentCompany(GuidanceDirectory directory) async {
///   // directory由接入App实现并注入。
///   await directory.load();
/// }
/// ```
abstract interface class GuidanceDirectory {
  /// 加载真实组织根节点；实现须阻止身份变化后的迟到数据泄露到新账号。
  Future<List<GuidancePerson>> load();
}

/// 在借用 [context] 中打开今日导向选人，支持搜索、组织钻取和人员/部门多选。
/// [directory] 由宿主拥有，不被释放；[canEdit] 在打开、确认和退场完成时校验，
/// 面板存活期间也检查权限撤销。取消、会话切换或权限失效返回 null。
/// 等待弹窗退场完成后返回去重的引用快照，不写编辑器，不展开部门成员。
///
/// ```dart
/// import 'package:flutter/material.dart';
/// import 'package:cses_offline_example/daily_guidance/guidance_people.dart';
/// Future<List<GuidancePerson>?> choose(BuildContext context, GuidanceDirectory directory) =>
///   showGuidancePeoplePicker(context,
///     directory: directory, canEdit: () => true);
/// ```
Future<List<GuidancePerson>?> showGuidancePeoplePicker(
  BuildContext context, {
  required GuidanceDirectory directory,
  required bool Function() canEdit,
}) async {
  if (!canEdit()) return null;
  var revoked = false;

  /// 保持撤销不可逆，防止旧弹窗在权限恢复后写回原请求。
  bool allowed() {
    if (!canEdit()) revoked = true;
    return !revoked;
  }

  final result = await showJournalSheet<List<GuidancePerson>>(
    context: context,
    builder: (context) =>
        _GuidancePeoplePicker(directory: directory, canEdit: allowed),
  );
  return allowed() ? result : null;
}

/// 拥有目录查询、搜索输入和选择状态，借用目录和权限检查器。
class _GuidancePeoplePicker extends StatefulWidget {
  /// [directory] 提供当前身份组织树，[canEdit] 判定原编辑请求是否仍有效。
  const _GuidancePeoplePicker({required this.directory, required this.canEdit});

  /// 借用的目录，组件不释放。
  final GuidanceDirectory directory;

  /// 失效后永久拒绝返回旧请求的检查器。
  final bool Function() canEdit;

  /// 为本次弹窗创建独立输入和异步结果代次。
  @override
  State<_GuidancePeoplePicker> createState() => _GuidancePeoplePickerState();
}

/// 关闭、重试或搜索变化后废弃迟到结果；不拥有业务编辑器。
class _GuidancePeoplePickerState extends State<_GuidancePeoplePicker> {
  /// 本状态创建和释放的搜索输入。
  final _input = TextEditingController();

  /// 本状态拥有的权限轮询和搜索去抖，退出时均取消。
  Timer? _permissionTimer, _debounce;

  /// 组织加载和搜索各自的代次，防止旧查询覆盖新结果。
  int _loadGeneration = 0, _searchGeneration = 0;

  /// 根节点与扁平搜索索引只属于当前请求。
  List<GuidancePerson> _roots = const [], _all = const [], _visible = const [];

  /// 已钻取的部门链，根层为空。
  final _path = <GuidancePerson>[];

  /// 按确认顺序和真实身份保留多选，不按名称去重。
  final _selected = <String, GuidancePerson>{};

  /// 加载/搜索标记及供重试的错误，失败不会伪造人员。
  bool _loading = true, _searching = false, _revoked = false;
  String? _error;

  /// 加载真实组织并检查借用权限；异步失败由加载函数转换为可重试状态。
  @override
  void initState() {
    super.initState();
    _permissionTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted || _revoked || widget.canEdit()) return;
      ++_loadGeneration;
      ++_searchGeneration;
      _debounce?.cancel();
      setState(() {
        _revoked = true;
        _selected.clear();
      });
    });
    unawaited(_load());
  }

  /// 加载目录并建立搜索索引；异常只显示失败文案，重试创建新代次。
  Future<void> _load() async {
    final generation = ++_loadGeneration;
    ++_searchGeneration;
    try {
      final roots = await widget.directory.load();
      if (!mounted || generation != _loadGeneration || !widget.canEdit()) {
        return;
      }
      final all = _hasLargeTree(roots)
          ? await compute(_flattenPeople, roots)
          : _flattenPeople(roots);
      if (!mounted || generation != _loadGeneration || !widget.canEdit()) {
        return;
      }
      setState(() {
        _roots = roots;
        _all = all;
        _path.clear();
        _loading = false;
        _error = null;
      });
      await _search(++_searchGeneration);
    } catch (_) {
      if (!mounted || generation != _loadGeneration || !widget.canEdit()) {
        return;
      }
      setState(() {
        _loading = false;
        _searching = false;
        _error = '组织加载失败，请重试';
      });
    }
  }

  /// 输入 [value] 变化时立即隐藏旧结果，200 毫秒后查询当前索引。
  void _changed(String value) {
    _debounce?.cancel();
    final generation = ++_searchGeneration;
    setState(() => _searching = true);
    _debounce = Timer(
      const Duration(milliseconds: 200),
      () => unawaited(_search(generation)),
    );
  }

  /// 查询 [generation] 的关键词；大型索引在后台搜索，迟到结果不覆盖新输入。
  Future<void> _search(int generation) async {
    try {
      final keyword = _input.text.trim();
      final candidates = keyword.isEmpty
          ? (_path.isEmpty ? _roots : _path.last.children)
          : _all;
      final results = candidates.length >= 300
          ? await compute(_searchPeople, (candidates, keyword))
          : _searchPeople((candidates, keyword));
      if (!mounted || generation != _searchGeneration || !widget.canEdit()) {
        return;
      }
      setState(() {
        _visible = results;
        _searching = false;
      });
    } catch (_) {
      if (!mounted || generation != _searchGeneration || !widget.canEdit()) {
        return;
      }
      setState(() {
        _searching = false;
        _error = '组织搜索失败，请重试';
      });
    }
  }

  /// 进入 [person] 部门，或在 [person] 为 null 时回到 [depth] 指定的面包屑层。
  void _navigate(GuidancePerson? person, {int depth = 0}) {
    if (!widget.canEdit()) return;
    _debounce?.cancel();
    _input.clear();
    setState(() {
      if (person != null) {
        _path
          ..clear()
          ..addAll(_organizationPath(_roots, person.identity) ?? [person]);
      } else {
        _path.removeRange(depth, _path.length);
      }
      _visible = _searchPeople((
        _path.isEmpty ? _roots : _path.last.children,
        '',
      ));
      _searching = false;
      ++_searchGeneration;
    });
  }

  /// 切换 [person] 的单一引用，不展开部门，不保留其组织子树。
  void _toggle(GuidancePerson person) {
    if (!widget.canEdit()) return;
    setState(() {
      if (_selected.containsKey(person.identity)) {
        _selected.remove(person.identity);
      } else {
        _selected[person.identity] = GuidancePerson(
          id: person.id,
          name: person.name,
          type: person.type,
          department: person.department,
        );
      }
    });
  }

  /// 仅在权限和当前选择仍有效时确认，一次返回多个引用。
  void _confirm() {
    if (_revoked || !widget.canEdit() || _selected.isEmpty) return;
    Navigator.pop(context, List<GuidancePerson>.unmodifiable(_selected.values));
  }

  /// 取消定时器并使全部迟到请求失效，再释放本状态拥有的输入。
  @override
  void dispose() {
    ++_loadGeneration;
    ++_searchGeneration;
    _permissionTimer?.cancel();
    _debounce?.cancel();
    _input.dispose();
    super.dispose();
  }

  /// 在借用 [context] 内按可用高度布局；标题、搜索和确认固定，仅目录内容在键盘上方滚动。
  @override
  Widget build(BuildContext context) {
    final enabled = !_revoked && widget.canEdit();
    return JournalBottomSheet(
      title: '用户和部门',
      icon: LucideIcons.users,
      closeKey: const ValueKey('guidance-people-close'),
      expand: true,
      scrollBody: false,
      header: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: TextField(
          key: const ValueKey('guidance-people-search'),
          controller: _input,
          enabled: enabled,
          onChanged: _changed,
          decoration: const InputDecoration(
            labelText: '搜索用户或部门',
            prefixIcon: Icon(LucideIcons.search),
          ),
        ),
      ),
      footer: Text('已选 ${_selected.length} 项'),
      actions: [
        FilledButton(
          key: const ValueKey('guidance-people-confirm'),
          onPressed: enabled && _selected.isNotEmpty ? _confirm : null,
          child: const Text('确认'),
        ),
      ],
      child: CustomScrollView(
        key: const PageStorageKey('guidance-people-list'),
        slivers: [
          if (_selected.isNotEmpty)
            SliverToBoxAdapter(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: _selected.values
                      .map(
                        (person) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: InputChip(
                            label: Text(person.name),
                            onDeleted: enabled ? () => _toggle(person) : null,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  TextButton(
                    onPressed: enabled ? () => _navigate(null) : null,
                    child: const Text('全部组织'),
                  ),
                  for (var i = 0; i < _path.length; i++) ...[
                    const Icon(LucideIcons.chevronRight, size: 16),
                    TextButton(
                      onPressed: enabled
                          ? () => _navigate(null, depth: i + 1)
                          : null,
                      child: Text(_path[i].name),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (!enabled ||
              _error != null ||
              _loading ||
              _searching ||
              _visible.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: !enabled
                      ? const Text('当前不可编辑，请关闭后重新打开')
                      : _error != null
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_error!),
                            TextButton(
                              key: const ValueKey('guidance-people-retry'),
                              onPressed: () {
                                setState(() {
                                  _loading = true;
                                  _error = null;
                                });
                                unawaited(_load());
                              },
                              child: const Text('重试'),
                            ),
                          ],
                        )
                      : _loading || _searching
                      ? const CircularProgressIndicator()
                      : Text(
                          _input.text.trim().isEmpty
                              ? '当前组织暂无成员'
                              : '没有匹配的用户或部门',
                        ),
                ),
              ),
            )
          else
            SliverList.builder(
              itemCount: _visible.length,
              itemBuilder: (context, index) => _personRow(_visible[index]),
            ),
        ],
      ),
    );
  }

  /// 构建 [person] 的勾选/钻取行，长名称可换行，部门整体选择与进入分开。
  Widget _personRow(GuidancePerson person) => Container(
    constraints: const BoxConstraints(minHeight: 51),
    key: ValueKey('guidance-person-${person.identity}'),
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: Row(
      children: [
        Semantics(
          label: '选择${person.name}',
          child: Checkbox(
            key: ValueKey('guidance-select-${person.identity}'),
            value: _selected.containsKey(person.identity),
            onChanged: _revoked || !widget.canEdit()
                ? null
                : (_) => _toggle(person),
          ),
        ),
        Expanded(
          child: InkWell(
            onTap: _revoked || !widget.canEdit()
                ? null
                : () => person.type == 'department'
                      ? _navigate(person)
                      : _toggle(person),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(person.name),
                  if (person.department != null &&
                      person.department!.isNotEmpty)
                    Text(
                      person.department!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ),
        ),
        if (person.type == 'department')
          IconButton(
            key: ValueKey('guidance-open-${person.identity}'),
            tooltip: '进入${person.name}',
            onPressed: _revoked || !widget.canEdit()
                ? null
                : () => _navigate(person),
            icon: const Icon(LucideIcons.chevronRight),
          ),
      ],
    ),
  );
}

/// 将 [roots] 按深度优先顺序建立去重搜索索引，不展开为选择结果。
List<GuidancePerson> _flattenPeople(List<GuidancePerson> roots) {
  final result = <String, GuidancePerson>{};
  final pending = roots.reversed.toList();
  while (pending.isNotEmpty) {
    final person = pending.removeLast();
    if (result.containsKey(person.identity)) continue;
    result[person.identity] = person;
    pending.addAll(person.children.reversed);
  }
  return List.unmodifiable(result.values);
}

/// 使用 [request] 的姓名/部门关键词过滤索引；空关键词保留当前层且去重。
List<GuidancePerson> _searchPeople((List<GuidancePerson>, String) request) {
  final keyword = request.$2.trim().toLowerCase();
  final matches = <String, GuidancePerson>{};
  for (final person in request.$1) {
    if ('${person.name} ${person.department ?? ''}'.toLowerCase().contains(
      keyword,
    )) {
      matches[person.identity] = person;
    }
  }
  return List.unmodifiable(matches.values);
}

/// 有界检查 [roots] 是否超过 300 节点，将可能耗时的完整索引放到后台执行。
bool _hasLargeTree(List<GuidancePerson> roots) {
  final pending = roots.toList();
  final seen = <String>{};
  while (pending.isNotEmpty) {
    final person = pending.removeLast();
    if (!seen.add(person.identity)) continue;
    if (seen.length >= 300) return true;
    pending.addAll(person.children);
  }
  return false;
}

/// 查找 [roots] 中 [identity] 所在部门链，用于从搜索结果钻取后恢复真实面包屑。
List<GuidancePerson>? _organizationPath(
  List<GuidancePerson> roots,
  String identity,
) {
  final pending = roots.map((person) => [person]).toList();
  final seen = <String>{};
  while (pending.isNotEmpty) {
    final path = pending.removeLast();
    final person = path.last;
    if (!seen.add(person.identity)) continue;
    if (person.identity == identity) return path;
    pending.addAll(person.children.map((child) => [...path, child]));
  }
  return null;
}
