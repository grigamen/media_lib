part of "profile_screen.dart";

/// После закрытия диалога и анимации клавиатуры, чтобы не ловить кадр с
/// полуснятым деревом при notifyListeners с других подписчиков AppState.
Future<void> _afterDialogUiSettled() async {
  await SchedulerBinding.instance.endOfFrame;
  await Future<void>.delayed(const Duration(milliseconds: 80));
}

/// `showDialog` completes when [Navigator.pop] runs, but the route can still
/// rebuild [TextField]s during the pop transition; disposing the controller
/// immediately triggers "used after being disposed".
void _scheduleDisposeTextControllers(List<TextEditingController> controllers) {
  Future<void>.delayed(const Duration(milliseconds: 400), () {
    for (final c in controllers) {
      c.dispose();
    }
  });
}

void _postFrameSnackBar(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) {
    return;
  }
  final text = message;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    messenger.showSnackBar(SnackBar(content: Text(text)));
  });
}
