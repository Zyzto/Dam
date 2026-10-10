import 'package:blood_pressure_app/features/export_import/model/export_preset.dart';
import 'package:blood_pressure_app/model/storage/convert_util.dart';
import 'package:blood_pressure_app/model/storage/persistable_settings.dart';

class PdfExportSettings extends PersistableSettings {
  PdfExportSettings({
    bool? exportTitle,
    bool? exportStatistics,
    bool? exportData,
    bool? separateWeightMedicineTables,
    double? headerHeight,
    double? cellHeight,
    double? headerFontSize,
    double? cellFontSize,
    String? activePreset,
  })  : _exportTitle = exportTitle ?? true,
        _exportStatistics = exportStatistics ?? true,
        _exportData = exportData ?? true,
        _separateWeightMedicineTables = separateWeightMedicineTables ?? true,
        _headerHeight = headerHeight ?? 20,
        _cellHeight = cellHeight ?? 15,
        _headerFontSize = headerFontSize ?? 10,
        _cellFontSize = cellFontSize ?? 8,
        _activePreset = activePreset ?? ExportPreset.appPdf.id;

  /// Create a instance from a map created by [toMap].
  factory PdfExportSettings.fromMap(Map<String, dynamic> map) {
    final n = PdfExportSettings();
    n._applyMap(map);
    return n;
  }

  /// Create a instance from a [String] created by [toJson].
  factory PdfExportSettings.fromJson(String json) {
    final map = decodeSettingsMap(json);
    if (map == null) return PdfExportSettings();
    return PdfExportSettings.fromMap(map);
  }

  bool _exportTitle;
  bool _exportStatistics;
  bool _exportData;
  bool _separateWeightMedicineTables;
  double _headerHeight;
  double _cellHeight;
  double _headerFontSize;
  double _cellFontSize;
  String _activePreset;

  bool get exportTitle => _exportTitle;
  set exportTitle(bool v) {
    _exportTitle = v;
    notifyListeners();
  }

  bool get exportStatistics => _exportStatistics;
  set exportStatistics(bool v) {
    _exportStatistics = v;
    notifyListeners();
  }

  bool get exportData => _exportData;
  set exportData(bool v) {
    _exportData = v;
    notifyListeners();
  }

  /// Weight and medicine each get a table, instead of columns in the reading log.
  bool get separateWeightMedicineTables => _separateWeightMedicineTables;
  set separateWeightMedicineTables(bool v) {
    _separateWeightMedicineTables = v;
    notifyListeners();
  }

  double get headerHeight => _headerHeight;
  set headerHeight(double v) {
    _headerHeight = v;
    notifyListeners();
  }

  double get cellHeight => _cellHeight;
  set cellHeight(double v) {
    _cellHeight = v;
    notifyListeners();
  }

  double get headerFontSize => _headerFontSize;
  set headerFontSize(double v) {
    _headerFontSize = v;
    notifyListeners();
  }

  double get cellFontSize => _cellFontSize;
  set cellFontSize(double v) {
    _cellFontSize = v;
    notifyListeners();
  }

  String get activePreset => _activePreset;
  set activePreset(String v) {
    _activePreset = v;
    notifyListeners();
  }

  @override
  Map<String, dynamic> toMap() => <String, dynamic>{
    'exportTitle': _exportTitle,
    'exportStatistics': _exportStatistics,
    'exportData': _exportData,
    'separateWeightMedicineTables': _separateWeightMedicineTables,
    'headerHeight': _headerHeight,
    'cellHeight': _cellHeight,
    'headerFontSize': _headerFontSize,
    'cellFontSize': _cellFontSize,
    'activePreset': _activePreset,
  };

  void copyFrom(PdfExportSettings other) {
    _exportTitle = other._exportTitle;
    _exportStatistics = other._exportStatistics;
    _exportData = other._exportData;
    _separateWeightMedicineTables = other._separateWeightMedicineTables;
    _headerHeight = other._headerHeight;
    _cellHeight = other._cellHeight;
    _headerFontSize = other._headerFontSize;
    _cellFontSize = other._cellFontSize;
    _activePreset = other._activePreset;
    notifyListeners();
  }

  bool copyFromJson(String json) {
    final map = decodeSettingsMap(json);
    if (map == null) return false;
    copyFrom(PdfExportSettings.fromMap(map));
    return true;
  }

  @override
  void reset() => copyFrom(PdfExportSettings());

  void _applyMap(Map<String, dynamic> map) {
    final title = ConvertUtil.parseBool(map['exportTitle']);
    if (title != null) _exportTitle = title;
    final stats = ConvertUtil.parseBool(map['exportStatistics']);
    if (stats != null) _exportStatistics = stats;
    final data = ConvertUtil.parseBool(map['exportData']);
    if (data != null) _exportData = data;
    final separate = ConvertUtil.parseBool(map['separateWeightMedicineTables']);
    if (separate != null) _separateWeightMedicineTables = separate;
    final headerH = ConvertUtil.parseDouble(map['headerHeight']);
    if (headerH != null) _headerHeight = headerH;
    final cellH = ConvertUtil.parseDouble(map['cellHeight']);
    if (cellH != null) _cellHeight = cellH;
    final headerF = ConvertUtil.parseDouble(map['headerFontSize']);
    if (headerF != null) _headerFontSize = headerF;
    final cellF = ConvertUtil.parseDouble(map['cellFontSize']);
    if (cellF != null) _cellFontSize = cellF;
    final preset = map['activePreset'];
    if (preset is String) _activePreset = preset;
  }
}
