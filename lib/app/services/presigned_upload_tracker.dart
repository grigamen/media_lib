import "package:flutter/foundation.dart";

/// Прогресс PUT в S3 по presigned URL и флаг «скрыть оверлей».
final class PresignedUploadTracker {
  PresignedUploadTracker({required VoidCallback onChanged})
    : _onChanged = onChanged;

  final VoidCallback _onChanged;

  double? _progress;
  bool _dismissed = false;

  /// Для UI: `null`, если нет активной загрузки или пользователь скрыл оверлей.
  double? get displayProgress => _dismissed ? null : _progress;

  void dismiss() {
    if (_progress == null) {
      return;
    }
    _dismissed = true;
    _onChanged();
  }

  void reportProgress(int uploaded, int total) {
    if (total <= 0) {
      return;
    }
    _progress = (uploaded / total).clamp(0.0, 1.0);
    if (!_dismissed) {
      _onChanged();
    }
  }

  void begin() {
    _dismissed = false;
    _progress = 0.0;
    _onChanged();
  }

  void end() {
    _dismissed = false;
    _progress = null;
    _onChanged();
  }
}
